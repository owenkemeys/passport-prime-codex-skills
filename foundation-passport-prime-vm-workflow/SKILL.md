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
export PATH="/home/<vm-user>/.foundation/sdk/current/bin:/home/<vm-user>/.foundation/sdk/bin:$PATH"
cd /home/<vm-user>/path/to/app
exec /home/<vm-user>/.foundation/sdk/current/bin/foundation build
```

Run it:

```bash
source /etc/profile.d/nix.sh
cd /home/<vm-user>/.foundation/sdk/current
nix develop --command /home/<vm-user>/wrapper.sh
```

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

## Simulator In VirtualBox

If `foundation sim` is the next test path, first make a real display available. A minimal path that worked:

```bash
sudo apt-get install -y xorg openbox xterm x11-apps x11-xserver-utils dbus-x11 xvfb weston
sudo sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config
echo needs_root_rights=yes | sudo tee -a /etc/X11/Xwrapper.config
nohup startx /usr/bin/openbox-session -- :0 > ~/xsession.log 2>&1 &
DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 weston --backend=x11-backend.so --socket=wayland-1 --width=900 --height=700
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

- Leave the visible Weston/simulator window maximized or reviewer-friendly before handing the VM back to the user; do not leave it tiny after automation.
- Start the simulator at `0.5x` scale if the Passport Prime buttons are partly off-screen.
- Use the simulator control panel's own `Screenshot` button for clean Passport Prime screen captures; it writes numbered PNG files under the app's `screenshots/` directory.
- For one-off checks, copy the newest screenshot to the host as a single overwritten `latest.png`.
- For review sessions where a user may take many captures, create a VM-visible shortcut/watcher for the app `screenshots/` folder and a Windows-side sync folder. Make the sync deletion-friendly so rejects deleted in Windows do not reappear from the VM.
- If using `scrot` for full-desktop debugging, delete the target PNG first; observed `scrot` did not reliably overwrite an existing file.

Keep VM disk hygiene in the loop. Nix and Rust `target/` directories can consume tens of GB after repeated builds and experiments, and disk exhaustion can look like a simulator or memory crash. Check `df -h /` and `free -h` before and after long build/simulator sessions. Safe cleanup candidates are reproducible app `target/` directories, `nix-collect-garbage -d`, and apt cache. Preserve a small runnable bundle first if useful, path-check cleanup targets before `rm -rf`, and expect the first build after cleanup to redownload/rebuild toolchain pieces. If free disk drops below 10 GB, clean build/cache output before continuing.

Known VM simulator signals:

- `NoWaylandLib`: Wayland client library is not visible inside the SDK process.
- `libfontconfig.so.1` missing: add compatible Nix fontconfig libs.
- `V4L2 Error: No such file or directory`: the VM has no camera device; use webcam passthrough or a mock/test path.
- Black automated screenshots may be misleading if the live VirtualBox window has an input/unlock overlay. Ask the user to inspect the live VM window too.
