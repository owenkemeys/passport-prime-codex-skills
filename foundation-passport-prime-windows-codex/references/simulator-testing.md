# Simulator Testing Reference

Use this when making Passport Prime simulator testing visible and repeatable from Windows/Codex.

## GUI Stack That Worked

Install a small display stack in Ubuntu:

```bash
sudo apt-get install -y xorg openbox xterm x11-apps x11-xserver-utils dbus-x11 xvfb weston xdotool scrot
sudo sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config
echo needs_root_rights=yes | sudo tee -a /etc/X11/Xwrapper.config
nohup startx /usr/bin/openbox-session -- :0 > ~/xsession.log 2>&1 &
```

Start nested Weston on X11:

```bash
DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 nohup weston \
  --backend=x11-backend.so \
  --socket=wayland-1 \
  --width=900 \
  --height=700 \
  --idle-time=0 \
  > ~/weston.log 2>&1 &
```

## Stable Nix GUI Libraries

Do not mix Ubuntu system GUI libraries into the Nix-built simulator. Build compatible libraries from the SDK's nixpkgs revision and create stable out-links:

```bash
mkdir -p ~/sim-libs
cd ~/sim-libs
nix build github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#wayland --out-link wayland
nix build github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#libxkbcommon --out-link libxkbcommon
nix build github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#fontconfig --out-link fontconfig
nix build github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#libffi --out-link libffi
ln -sfn "$(find /nix/store -maxdepth 1 -type d -name '*fontconfig-*-lib' | head -1)" fontconfig-lib
ln -sfn "$(find /nix/store -maxdepth 1 -type d -name '*xkeyboard-config-*' | head -1)" xkeyboard-config
```

Simulator wrapper:

```bash
#!/usr/bin/env bash
set -euo pipefail
SIM_LIBS="$HOME/sim-libs"
unset DISPLAY
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export WINIT_UNIX_BACKEND=wayland
export RUST_BACKTRACE=1
export XKB_CONFIG_ROOT="$SIM_LIBS/xkeyboard-config/share/X11/xkb"
export FONTCONFIG_FILE="$SIM_LIBS/fontconfig/etc/fonts/fonts.conf"
export LD_LIBRARY_PATH="$SIM_LIBS/wayland/lib:$SIM_LIBS/libxkbcommon/lib:$SIM_LIBS/libffi/lib:$SIM_LIBS/fontconfig-lib/lib:${LD_LIBRARY_PATH:-}"
export PATH="$HOME/.foundation/sdk/current/bin:$HOME/.foundation/sdk/bin:$PATH"
cd "$HOME/path/to/app"
exec "$HOME/.foundation/sdk/current/bin/foundation" sim
```

## Clean Restart Wrapper

Put this in the VM and run it from SSH:

```bash
#!/usr/bin/env bash
set -euo pipefail
pkill -f "foundation sim" 2>/dev/null || true
pkill -f "/keyos/simulator/" 2>/dev/null || true
pkill -f "target/apps/<app-id>/app.elf" 2>/dev/null || true
pkill -f "weston --backend=x11-backend.so" 2>/dev/null || true
sleep 1

mkdir -p "$HOME/.config"
cat > "$HOME/.config/weston.ini" <<'CFG'
[core]
idle-time=0

[shell]
locking=false
CFG

DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 nohup weston \
  --backend=x11-backend.so \
  --socket=wayland-1 \
  --width=900 \
  --height=700 \
  --idle-time=0 \
  > "$HOME/weston.log" 2>&1 &
sleep 2

rm -f "$HOME/foundation-sim.log"
source /etc/profile.d/nix.sh
cd "$HOME/.foundation/sdk/current"
nohup nix develop --command "$HOME/run-sim-visible.sh" \
  > "$HOME/foundation-sim.log" 2>&1 &
echo "$!" > "$HOME/foundation-sim.pid"
```

## Visual Test Loop

Make the app testable without camera hardware:

- Add a button such as `Sample QR` that cycles deterministic payloads.
- Keep `Scan QR` for real scanner integration, but expect VM camera failure unless `/dev/video0` exists.
- Before handing the VM back to a user for review, maximize or enlarge the visible Weston/simulator window so the full Passport Prime screen is visible.
- Set the simulator control panel to `0.5x` scale so app buttons are clickable.
- Use `xdotool` to click app buttons.
- Use the simulator control panel's own Screenshot button for clean Passport Prime screen PNGs.

Example routine:

```bash
# click Sample QR, then simulator Screenshot
DISPLAY=:0 xdotool mousemove <sample-x> <sample-y> click 1
sleep 1
DISPLAY=:0 xdotool mousemove <screenshot-x> <screenshot-y> click 1
sleep 1
ls -lt ~/path/to/app/screenshots/*.png | head
```

Copy newest screenshot to a single host file, usually `latest.png`, then clean numbered VM screenshots:

```bash
find ~/path/to/app/screenshots -type f -name 'screenshot_*.png' -delete
```

For full-desktop debugging with `scrot`, remove the target first; observed `scrot` did not reliably overwrite existing PNGs.

```bash
rm -f /tmp/prime-desktop.png
DISPLAY=:0 scrot -q 90 /tmp/prime-desktop.png
```

## Non-Technical Capture Review

For users who will take many screenshots or recordings, do not make them ask for each file. Set up both:

- A visible VM-side shortcut or watcher that shows the simulator capture directory, typically `<app>/screenshots`.
- A Windows-side review folder populated by background sync, so captures can be opened, sorted, deleted, or moved from Explorer.

VM-side helper pattern:

```bash
capture_dir="$HOME/path/to/app/screenshots"
mkdir -p "$capture_dir" "$HOME/Desktop" "$HOME/bin"
ln -sfn "$capture_dir" "$HOME/Desktop/<App> Simulator Captures"
cat > "$HOME/bin/open-app-captures.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
capture_dir="$HOME/path/to/app/screenshots"
mkdir -p "$capture_dir"
xterm -T "Simulator Captures" -geometry 120x32 \
  -e "watch -n 1 'printf \"Simulator captures\n%s\n\n\" \"$capture_dir\"; ls -lhtr \"$capture_dir\" | tail -40'" &
SCRIPT
chmod +x "$HOME/bin/open-app-captures.sh"
```

Windows-side sync pattern:

- Use `scp` over the VM SSH port to pull `*.png`, `*.gif`, `*.mp4`, and `*.webm`.
- Track copied filename/size in a hidden state file so Windows deletions are respected. Without this, deleted rejects reappear on the next poll.
- Create a `keepers/` folder in the Windows review folder for selected captures.
- Avoid repeatedly recopying large recordings; copy only files that are new or changed by size.

Keep simulator captures until the user has reviewed them, then clean VM-side rejects or archive only the keepers. For quick rough captures, Windows `Win+Shift+S` is acceptable, but the simulator Screenshot button produces cleaner device-only images.

## Expected Noisy Logs

These may be unrelated to the app under test:

- `V4L2 Error: No such file or directory`: no VM camera device.
- Bitcoin/onboarding seed errors: hosted simulator has no initialized seed/onboarding state.
- repeated `xous_names` `ServerNotFound`: often seen during hosted startup/noisy background services.
