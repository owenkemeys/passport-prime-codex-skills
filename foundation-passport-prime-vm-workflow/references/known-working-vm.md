# Known Working VM Shape

This project successfully used:

```text
VirtualBox 7.2.x
Ubuntu Server 24.04 LTS
NAT SSH forwarding: host 127.0.0.1:2222 to guest 22
Nix multi-user install with flakes enabled
Foundation Passport Prime SDK 0.4.0 installed as the VM user
Passport Prime USB attached through VirtualBox
Passport Prime mounted in Linux as AIRLOCK
```

The VM could run:

```bash
foundation doctor
foundation build
foundation sideload --mount-path /mnt/prime --no-run
```

VirtualBox Extension Pack was not installed in this run; basic USB storage passthrough still worked.

Hosted simulator display path that worked:

```text
Install Xorg/Openbox/Xvfb tooling.
Start Openbox on the VirtualBox console.
Start Weston nested inside X11 with --backend=x11-backend.so --socket=wayland-1.
Run foundation sim with WAYLAND_DISPLAY=wayland-1 and WINIT_UNIX_BACKEND=wayland.
Expose Wayland, libxkbcommon, fontconfig, and xkeyboard-config from the SDK's nixos-24.11 nixpkgs revision, not Ubuntu system libraries.
```

Weston window trap:

```text
Weston is an X11/Openbox window inside the VM, separate from VirtualBox and separate from the Passport simulator's own controls.
If it appears partially off-screen, or the VM shows a large black unused area, fix/maximize the Weston host window first.
Do not "solve" this by changing simulator scale/settings.
Avoid weston --fullscreen in this stack; it can create a full-size X11 window with a stale smaller Weston viewport.
Start Weston with explicit dimensions such as --width=1600 --height=900, then maximize the Weston host window through Openbox/xdotool.
Verify with xprop that _NET_WM_STATE_MAXIMIZED_VERT and _NET_WM_STATE_MAXIMIZED_HORZ are set.
If a helper window should stay visible, lower Weston or mark it below after maximizing; do not leave Weston floating small just to reveal controls.
```

Do not trust automated VirtualBox screenshots alone. In this run they showed a black simulator area until the user clicked through a VirtualBox input/unlock overlay in the live VM window; the app UI was visible to the user.

Iteration workflow:

```text
For UI/product iteration, edit first and report what is ready to build/test unless the user explicitly asked for the full build/restart/test loop.
Before starting a new build, check disk space and run path-checked cleanup of rebuildable target directories when space is low.
Preserve small signed bundles before pre-build cleanup when they may be needed.
During active simulator review, keep the successful build output warm for restart-only tasks.
Run broad Nix garbage collection only when disk is trending low and no other build/simulator lane is active; otherwise avoid forcing every later run into a cold rebuild.
```
