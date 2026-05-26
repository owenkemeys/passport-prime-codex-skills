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

Do not trust automated VirtualBox screenshots alone. In this run they showed a black simulator area until the user clicked through a VirtualBox input/unlock overlay in the live VM window; the app UI was visible to the user.
