# VM Setup Reference

Use this when Windows/WSL is blocking Passport Prime SDK development.

## Proven Shape

- VirtualBox 7.2.x
- Ubuntu Server/Desktop 24.04 LTS
- 4 CPUs, 8 GB RAM, 80 GB disk minimum; 120 GB is more comfortable
- Normal sudo-capable VM user
- NAT SSH forwarding from `127.0.0.1:2222` to guest `22`
- Nix multi-user install with flakes enabled
- Foundation Passport Prime SDK installed as the normal VM user

Windows/Codex controls the VM over SSH:

```powershell
ssh -i "$env:USERPROFILE\.ssh\<vm-key>" -p 2222 <vm-user>@127.0.0.1 'uname -a && lsb_release -a'
```

## SDK Commands

Run Foundation commands through the SDK Nix shell:

```bash
source /etc/profile.d/nix.sh
cd ~/.foundation/sdk/current
nix develop --command foundation doctor
```

For project work, avoid nested quoting by creating VM wrapper scripts:

```bash
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.foundation/sdk/current/bin:$HOME/.foundation/sdk/bin:$PATH"
cd "$HOME/path/to/app"
exec "$HOME/.foundation/sdk/current/bin/foundation" build
```

Run:

```bash
source /etc/profile.d/nix.sh
cd ~/.foundation/sdk/current
nix develop --command "$HOME/build-app.sh"
```

## Moving Source Into The VM

Use tar/scp or rsync and exclude build outputs:

```bash
tar --exclude='*/target' -czf project.tar.gz <app-dir> <core-dir>
scp -P 2222 project.tar.gz <vm-user>@127.0.0.1:/home/<vm-user>/
```

After extraction, search for stale absolute SDK paths:

```bash
grep -R "/home/.*/.foundation/sdk/current" -n Cargo.toml */Cargo.toml
```

If present, patch to the VM SDK path or regenerate the app scaffold.

## Disk Hygiene

Nix and Rust build outputs can consume tens of GB after repeated SDK/simulator work. In one observed VM, the user experienced simulator crashes and "memory-like" slowdown while `/` had only ~244 MB free; after removing reproducible build output, free space recovered to ~64 GB. Check disk before assuming an app or simulator memory leak.

Routine health check:

```bash
df -h /
free -h
find "$HOME" -maxdepth 5 -type d -name target -prune -exec du -sh {} + 2>/dev/null | sort -h
```

Safe cleanup candidates are reproducible build outputs and package caches, not source files or app data:

```bash
# Preserve a small runnable bundle first if it is useful for review/sideload.
mkdir -p ~/project/bundles
[ -d ~/project/app/target/keyos/<app-id> ] && cp -a ~/project/app/target/keyos/<app-id> ~/project/bundles/<app-id>-latest

# Remove only path-checked target directories.
for p in ~/project/app/target ~/project/core/target; do
  resolved="$(realpath -m "$p")"
  case "$resolved" in
    "$HOME"/*/target|"$HOME"/*/*/target) [ -d "$resolved" ] && rm -rf -- "$resolved" ;;
    *) echo "Refusing unsafe cleanup path: $resolved" >&2; exit 2 ;;
  esac
done

nix-collect-garbage -d
sudo apt-get clean || true
df -h /
```

After cleanup, the next build may redownload/rebuild Rust, cross-compile, and simulator dependencies. Keep stable out-links for simulator GUI libraries before garbage collection. While actively reviewing a prototype, leave the fresh `target/` directory in place unless disk is low; deleting it after every build makes the next simulator launch slow.

Recommended threshold: if free VM disk space drops below 10 GB, stop feature work and clean build/cache output first.

## VirtualBox Notes

- USB passthrough may work without Extension Pack for some devices.
- If installing Extension Pack, Oracle presents a license. The user must review/accept it manually.
- If Windows shows WSL I/O performance warnings for projects stored on Windows drives, prefer keeping active SDK work inside the Linux filesystem/VM.
- If the visible simulator view is tiny, floating, partly off-screen, or surrounded by black unused VM space, fix the nested Weston/Openbox window first. VirtualBox does not position the Passport simulator directly; the stack is VirtualBox -> Ubuntu X/Openbox -> Weston -> Foundation simulator. Avoid `weston --fullscreen`; start Weston as a large normal window and maximize the Weston host window through Openbox/xdotool.
