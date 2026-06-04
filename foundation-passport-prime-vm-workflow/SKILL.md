---
name: foundation-passport-prime-vm-workflow
description: Run Foundation Passport Prime SDK work from Windows using a Linux virtual machine. Use when Codex needs to set up, inspect, or operate a VirtualBox/Ubuntu VM for the Passport Prime SDK, SSH into the VM, install Nix/Foundation SDK, copy app sources into the VM, fix moved-project SDK paths, attach Passport Prime USB storage, or run Foundation commands inside the VM.
---

# Foundation Passport Prime VM Workflow

Use this skill when Windows/WSL is getting in the way and Foundation Passport Prime SDK work needs a supported Linux environment. For a full Windows/Codex starter path, use `foundation-passport-prime-windows-codex`. Use `foundation-passport-prime-sdk` for general SDK behavior and `foundation-passport-prime-sideload-debug` for hardware copy/log loops.

## Proven Shape

The workflow that worked:

- VirtualBox 7.2.x
- Ubuntu Server 24.04 LTS VM
- VM user: ordinary sudo-capable user
- NAT SSH forwarding from host `127.0.0.1:2222` to guest `22`
- Nix multi-user install with flakes enabled
- Foundation Passport Prime SDK installed as the VM user, not root
- Foundation commands run through `nix develop` from `~/.foundation/sdk/current`

Do not assume WSL is enough for simulator or USB. WSL may build code, but Foundation does not currently treat Windows/WSL as supported SDK targets.

## Default Iteration Contract

Foundation simulator launches are expensive: a small UI edit can be faster than the build/restart/test loop. Unless the user explicitly asks to do the whole loop, prefer:

1. Inspect and edit the source.
2. Report the implemented changes and any uncertainties.
3. Ask whether to continue with VM copy, `foundation build`, simulator restart, and visual testing.

If the user already asked to build, run, test, or hand them a live simulator, continue through the full loop without an extra checkpoint. Keep this as a workflow default, not a permission rule.

Treat VM builds as part of the same long-running-cost gate. Do not start `foundation build` merely because there is an available VM or because investigation has reached a possible candidate. Proceed only when the user explicitly asked for a build, or when the build answers a clear feasibility question worth the time and disk churn. If the core app capability is still unproven, stop first and report that status before proposing any build probe.

After a build/deploy handoff, include a compact "what changed / what to test" summary. The user may test hours after the original request and needs the recent change list repeated alongside the simulator-ready status.

If the user says they will do the testing and only wants the simulator visible, keep the handoff bar narrow: build/run, confirm the app is visibly rendered, and stop. Do not click through app flows, close simulator overlays, change scale/theme, or try to "tidy" the simulator window after the app is visible unless the user asks.

Do not stop or kill a live simulator during a user review session just to copy files, inspect state, or do maintenance unless the current instruction includes build/run/deploy/restart work or the user explicitly permits stopping it. If a helper must stop the simulator to edit `disk.dat`, make that requirement visible through a flag such as `-AllowStopSimulator` / `ALLOW_STOP_SIM=1` so accidental interruptions fail fast.

## Build And Simulator Lanes

Separate build-only work from simulator ownership.

Build-only actions can usually run in parallel when each project has its own app directory and helpers do not touch another app's `target/`:

- editing source
- copying source into a project-specific VM folder
- running `foundation build`
- reading SDK help output
- inspecting build artifacts

Simulator-lane actions should have a single owner per VM:

- `foundation sim`
- stopping or restarting simulator processes
- editing simulator `disk.dat`
- changing Weston/Openbox geometry
- taking over visible simulator review
- cleaning the build output for the app currently running in the simulator

Treat one VM as one simulator lane unless the installed SDK exposes and verifies separate simulator profiles, storage, display, and process ownership. Do not default to one VM per project; prefer one primary VM with separate project folders. Add a second fixed VM lane only when independent concurrent simulator review is actually needed.

## Build Artifact Cleanup Policy

Foundation SDK builds can consume many gigabytes in `target/` folders and the Nix store. Agents should manage this proactively, but only within clear safety bounds.

Before any long Foundation build or simulator launch, check free space with `df -h /`. If root free space is low, inspect the largest build directories with `du -sh` before starting the build.

Safe to remove without additional user input when no matching app, `foundation sim`, `cargo`, or `rustc` process is running:

- inactive app `target/` directories in VM staging or old app worktrees
- obsolete failed-probe `target/` directories
- old simulator screenshots and logs in Codex-owned staging folders

Ask before removing:

- source folders
- signed bundles or release artifacts
- simulator `disk.dat`
- the `target/` directory for the app currently running in the simulator
- whole project or staging folders where source edits might exist only in the VM

Nix garbage collection may be used when disk pressure remains after stale app targets are removed and no build is running. Say plainly that the next build may be slower because some cached dependencies may need to be restored.

Use path allowlists and process checks in cleanup helpers. A cleanup command should verify the exact intended paths before deleting, and should fail closed if an unexpected path is computed.

## VM Health Checks

From Windows, check VM and SSH access:

```powershell
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' list runningvms
ssh -i "$env:USERPROFILE\.ssh\<vm-key>" -p 2222 <vm-user>@127.0.0.1 'uname -a && lsb_release -a'
```

Inside the VM, verify SDK:

```bash
source /etc/profile.d/nix.sh
cd ~/.foundation/sdk/current
nix develop --command foundation doctor
```

## Source Transfer

When moving a Passport Prime app into the VM, prefer tar/scp or rsync and exclude build outputs:

```bash
tar --exclude='*/target' -czf project.tar.gz <app-dir> <core-dir>
scp -P 2222 project.tar.gz <vm-user>@127.0.0.1:/home/<vm-user>/
```

After extraction, search for stale paths:

```bash
grep -R "/home/.*/.foundation/sdk/current" -n Cargo.toml */Cargo.toml
```

If a scaffolded app moved between users/machines, patch absolute SDK paths in `Cargo.toml` to the VM SDK path or regenerate the scaffold.

## Robust Command Wrapper

Avoid deep PowerShell-to-SSH-to-Nix quoting when possible. Put wrapper scripts in the VM:

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:?app dir required}"
SDK_ROOT="${FOUNDATION_SDK_ROOT:-$HOME/.foundation/sdk/current}"

source /etc/profile.d/nix.sh

if [ ! -f "$APP_DIR/app-config.toml" ]; then
  echo "Missing app-config.toml in $APP_DIR" >&2
  exit 1
fi

cd "$SDK_ROOT"
nix develop --command bash -c "cd '$APP_DIR' && foundation build"
```

Run it:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 <vm> "timeout 30m bash /path/to/build-wrapper.sh /path/to/app"
```

For build-only wrappers, do not call `foundation sim`, stop simulator processes, edit `disk.dat`, resize Weston, or run cleanup outside the requested app directory.

For VM file-copy or simulator-disk tasks, keep the operation bounded and non-interactive:

- Do not pipe heredocs or large inline scripts into `ssh` from PowerShell; create a checked-in `.sh`/`.ps1` helper, copy it with `scp`, then run the remote helper.
- Add `-o BatchMode=yes`, `-o ConnectTimeout=5`, and short server-alive settings to SSH/SCP commands so a bad key, password prompt, or stale NAT forward fails immediately instead of hanging.
- Wrap remote helper execution in `timeout` with a task-sized limit, for example `timeout 45s bash /home/<vm-user>/sim-import-copy/copy_imports_to_sim_disk.sh`.
- Print checkpoint lines before every risky step: SSH check, remote staging, file copy, simulator stop, disk write, restart/handoff.
- If a helper hits its timeout, stop and report that exact step; do not keep trying alternate pathways in the same turn unless the user asked for investigation.
- Avoid command substitutions and environment assignments embedded directly inside a PowerShell-quoted `ssh` command, for example `weston_id=$(...)` or `DISPLAY=:0 ...` inside double quotes. PowerShell may evaluate or split them locally. Put that logic in a VM-side helper script, or run one simple remote command per `ssh` call.

For copying test files into the simulator's internal storage, prefer a purpose-built FAT32 image writer over Linux `mount`/`sudo` loops. Stop the simulator, write the small files directly into `~/.foundation/sdk/current/lib/keyos/simulator/xous/kernel/disk.dat`, sync, and then restart only if the user asked for a live simulator. Mounting `disk.dat` is a fallback investigation path, not the default quick-copy path. The OS file picker for "Internal" sees the FAT `user/` directory, not arbitrary files written at the image root. Put user-importable test files under paths like `user/TEST1.JSON`; root-level files may not appear in the picker. Be careful with long FAT names and `.JSON`'s four-letter extension: generated short aliases can collide or stale long-name slots can confuse listings. Prefer a few known-good, unique `user/TEST1.JSON`, `user/TEST2.JSON` style names over clever long names.

If a FAT writer supports long filenames, make repeated writes idempotent: when replacing an existing long-name file, delete/free the short entry and its preceding LFN entries before allocating the replacement entries. Rewriting only the short entry slot can orphan LFN entries and make later files look corrupted or disappear from the picker. After staging files, verify with a FAT lister that `user/TEST1.JSON`, `user/TEST2.JSON`, etc. appear under `user/`, not just as strings somewhere in `disk.dat`.

## USB Passport Prime Attach

From Windows:

```powershell
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' list usbhost
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' controlvm <vm-name> usbattach <usb-uuid>
```

Passport Prime observed identifiers:

```text
VendorId: 0x1307
ProductId: 0x0165
Manufacturer: Foundation Devices, Inc.
Product: Passport Prime
Label in Linux: AIRLOCK
```

Inside Ubuntu:

```bash
lsusb
lsblk -f
sudo mkdir -p /mnt/prime
sudo mount -t vfat -o uid=$(id -u),gid=$(id -g) /dev/sdX /mnt/prime
```

Unmount and detach cleanly after writes:

```bash
sync
sudo umount /mnt/prime
```

```powershell
& 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe' controlvm <vm-name> usbdetach <usb-uuid>
```

## Extension Pack Boundary

VirtualBox Extension Pack may be needed for some USB behavior. Its installer presents an Oracle license. Do not accept that license on the user's behalf; ask the user to review/accept it or install it manually.


## VM Window Access

For interactive simulator review, prefer a normal VirtualBox GUI window over VirtualBox Remote Display/RDP. The GUI frontend is usually less laggy and closer to the user's prior working setup.

If the VM is already running headless and a simulator or build is active, do not restart it just to get a GUI window. In that case, either:

- enable VirtualBox Remote Display as a temporary non-disruptive fallback, or
- ask whether to save state/restart the VM with the GUI frontend, making clear that this may interrupt the current simulator/build session.

Remote Desktop Connection is a fallback for already-running headless VMs, not the preferred review surface.
## Simulator In VirtualBox

If `foundation sim` is the next test path, first make a real display available. A minimal path that worked:

```bash
sudo apt-get install -y xorg openbox xterm x11-apps x11-xserver-utils dbus-x11 xvfb weston xdotool scrot
sudo sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config
echo needs_root_rights=yes | sudo tee -a /etc/X11/Xwrapper.config
nohup startx /usr/bin/openbox-session -- :0 > ~/xsession.log 2>&1 &
DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 weston --backend=x11-backend.so --socket=wayland-1 --width=1600 --height=900
```

Before launching Weston, verify that X is really available. If `DISPLAY=:0 xdpyinfo` fails, start Openbox with `startx` and poll `xdpyinfo` before trying Weston. After starting Weston, poll for `/run/user/1000/wayland-1` before invoking `foundation sim`; if the socket is missing, inspect `~/weston.log` first. A VM can be reachable over SSH while its GUI session is absent after a reboot or forced shutdown.

Weston is itself an Openbox window inside the VM. If the user says the simulator is "off-screen" or the VirtualBox view has a large black unused area, diagnose the Weston host window before changing simulator settings. In this stack, `weston --fullscreen` can produce a stale internal viewport where the compositor window is full-size but content only occupies the upper-left area. Prefer starting Weston as a large normal X11 window, then ask Openbox to maximize that host window, matching the user's manual maximize button:

```bash
weston_id="$(DISPLAY=:0 xdotool search --onlyvisible --class "Weston Compositor" | head -n 1 || true)"
if [ -n "$weston_id" ]; then
  eval "$(DISPLAY=:0 xdotool getwindowgeometry --shell "$weston_id")"
  title_x=$((X + WIDTH / 2))
  title_y=$((Y - 30))
  [ "$title_y" -lt 10 ] && title_y=10
  DISPLAY=:0 xdotool mousemove "$title_x" "$title_y" click --repeat 2 --delay 100 1
  DISPLAY=:0 xprop -id "$weston_id" _NET_WM_STATE
fi
```

Run the simulator under Weston/Wayland. Do not mix Ubuntu system libraries into the Nix-built simulator; use the SDK's nixpkgs revision for dynamic GUI libraries:

```bash
nix build github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#wayland github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#libxkbcommon github:NixOS/nixpkgs/<sdk-nixpkgs-rev>#fontconfig --print-out-paths --no-link
```

Then set:

```bash
unset DISPLAY
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export WINIT_UNIX_BACKEND=wayland
export XKB_CONFIG_ROOT=<xkeyboard-config>/share/X11/xkb
export FONTCONFIG_FILE=<fontconfig>/etc/fonts/fonts.conf
export LD_LIBRARY_PATH=<wayland>/lib:<libxkbcommon>/lib:<libffi>/lib:<fontconfig-lib>/lib:${LD_LIBRARY_PATH:-}
```

Prefer stable out-links for these GUI libraries, for example under `~/sim-libs`, instead of hard-coded `/nix/store/...` paths. After `nix-collect-garbage`, hard-coded store paths may disappear.

For repeatable visual checks:

- Leave the visible Weston host window maximized through Openbox before handing the VM back to the user; do not use Weston fullscreen as a substitute.
- If Weston is floating, partly off-screen, or surrounded by unused black VM space, treat Weston placement as the bug. Do not change Passport simulator scale/settings until the Weston host window is maximized or manually sized correctly.
- After maximizing Weston, lower it or mark it below controls when a visible helper/control window must remain accessible.
- Start the simulator at `0.5x` scale if the Passport Prime buttons are partly off-screen.
- If the app is visible but the simulator control overlay is open, usually leave it alone. Closing or manipulating the control overlay can hide or disrupt the simulator surface on some VM/display stacks. Tell the user it is visible with the overlay rather than risking a crash during handoff.
- Use the simulator control panel's own `Screenshot` button for clean Passport Prime screen captures; it writes numbered PNG files under the app's `screenshots/` directory.
- For one-off checks, copy the newest screenshot to the host as a single overwritten `latest.png`.
- For review sessions where a user may take many captures, create a VM-visible shortcut/watcher for the app `screenshots/` folder and a Windows-side sync folder. Make the sync deletion-friendly so rejects deleted in Windows do not reappear from the VM.
- If using `scrot` for full-desktop debugging, delete the target PNG first; observed `scrot` did not reliably overwrite an existing file.
- A live app process is not enough for user handoff if the Weston/simulator surface is blank. Conversely, a screenshot tool failure is not proof the app crashed. Check both: process/log evidence and the visible window or a fresh screenshot. If those disagree repeatedly, stop and report the simulator/display instability instead of cycling restarts.

## Relaunching A Staged Simulator App

`foundation sim` performs a hosted simulator build, copies the app into the SDK simulator tree, starts KeyOS, then sends a simulator control-channel `run <app-id>` command. In SDK versions where `foundation sim --help` has no no-build/reuse flag, rerunning it after the app is already staged can waste time and refill the VM disk.

When no source changes require a new hosted simulator build and the app is already staged at:

```bash
$SDK_ROOT/lib/keyos/simulator/target/apps/<app-name>/app.elf
$SDK_ROOT/lib/keyos/simulator/target/apps/<app-name>/manifest.json
```

prefer a staged relaunch over another `foundation sim`, especially under disk pressure. Preconditions:

- no active `foundation sim`, `foundation-simulator`, `keyos-kernel`, app, `cargo`, or `rustc` process
- the staged `app.elf` and `manifest.json` are present
- the `app-id` is known from `manifest.json` or `app-config.toml`
- Weston/Wayland is running and visible

`foundation-simulator` by itself starts KeyOS but does not launch the staged app. Send control commands on stdin:

```bash
#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="${FOUNDATION_SDK_ROOT:-$HOME/.foundation/sdk/current}"
APP_ID="${1:?app id required, for example 0x...}"
LOG_PATH="${2:-$HOME/staged-simulator.log}"

unset DISPLAY
export XDG_RUNTIME_DIR=/run/user/1000
export WAYLAND_DISPLAY=wayland-1
export WINIT_UNIX_BACKEND=wayland
export XKB_CONFIG_ROOT="$HOME/sim-libs/xkeyboard-config/share/X11/xkb"
export LD_LIBRARY_PATH="$HOME/sim-libs/wayland/lib:$HOME/sim-libs/libxkbcommon/lib:$HOME/sim-libs/fontconfig-lib/lib:$HOME/sim-libs/libffi/lib:${LD_LIBRARY_PATH:-}"

{
  sleep 2
  printf 'ping\n'
  sleep 1
  printf 'run %s\n' "$APP_ID"
  sleep 86400
} | "$SDK_ROOT/bin/foundation-simulator" >"$LOG_PATH" 2>&1
```

Run that helper from the VM with `setsid -f ... >/dev/null 2>&1 < /dev/null &`, not through deeply nested PowerShell/SSH quoting. Verify the log contains both `ok ping` and `ok run launched pid=...`, then verify the app process and visible surface.

Treat this as a version-sensitive SDK workaround. If the control-channel response changes, do not keep guessing commands; report that the installed SDK needs a supported no-rebuild simulator launch path or a larger VM disk.

Keep VM disk hygiene in the loop. Nix and Rust `target/` directories can consume tens of GB after repeated builds and experiments, and disk exhaustion can look like a simulator or memory crash. Check `df -h /` and `free -h` before and after long build/simulator sessions.

Nix garbage collection is shared VM maintenance, not ordinary project cleanup. It can free tens of GB, but it may remove SDK/toolchain paths that the next `nix develop`, `foundation build`, or `foundation sim` must fetch or rebuild. After garbage collection, expect the first build to be slower and potentially network-dependent.

If the post-cleanup restore fails on a Foundation or GitHub release asset with an HTTP 5xx, do one direct URL check and retry before escalating. A transient `502` during toolchain rehydration is different from a missing SDK artifact.

Treat cleanup as a coordinated VM action, not an automatic pre-build step. Before deleting anything, check for active `foundation`, `cargo`, `rustc`, `nix`, and simulator processes, and ask the user whether another thread or alternating project may be using the VM. Propose the exact path, size, and reason for each cleanup target. Do not delete shared SDK, Nix store, cache, or another project's build output while another build may be active.

Safe cleanup candidates are reproducible app `target/` directories for the specific project being rebuilt, `nix-collect-garbage -d` only when no other Nix/build work is active and the user approves it, and apt cache. Preserve a small runnable bundle first if useful, path-check cleanup targets before `rm -rf`, and expect the first build after cleanup to redownload/rebuild toolchain pieces.

During active user review loops, do not delete the app's current `target/` output after a successful simulator launch. Keeping the successful build warm makes restart-only tasks, file-picker checks, and small handoffs fast. After app process detection, do cheap hygiene only: log disk/memory state, preserve any small bundle if needed, and warn if free space is low.

Run the riskier cleanup just before starting a new build, after the user has approved both the build and the cleanup scope. The old 10 GiB threshold is too low: a successful device `foundation build` can still be followed by a separate hosted `foundation sim` build that needs tens of GiB and can fail mid-compile with `No space left on device`. For a full build+sim handoff, prefer preserving the small signed bundle if needed, then path-checking and removing that app's reproducible `target/` before the simulator build. Use about 25-30 GiB free as the practical low-water mark; if free space is below that before any build that may compile Rust/Slint, propose cleaning the known project `target/` directory first. If free space is still below that after target cleanup, propose `nix-collect-garbage -d` only if no other build is active. Keeping `target/` warm is useful for restart-only tasks, alternating-project workflows, or very small checks where no rebuild is expected.

Known VM simulator signals:

- `NoWaylandLib`: Wayland client library is not visible inside the SDK process.
- `libfontconfig.so.1` missing: add compatible Nix fontconfig libs.
- `WaylandError(Connection(NoCompositor))` or `Could not find wayland compositor`: the simulator started before Weston's Wayland socket existed, or Weston failed to attach to X. Check `DISPLAY=:0 xdpyinfo`, `~/weston.log`, and `/run/user/1000/wayland-1`; fix the display layer before debugging app code.
- `V4L2 Error: No such file or directory`: the VM has no camera device; use webcam passthrough or a mock/test path.
- Black automated screenshots may be misleading if the live VirtualBox window has an input/unlock overlay. Ask the user to inspect the live VM window too.
