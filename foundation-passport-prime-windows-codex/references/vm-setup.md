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

Nix can consume tens of GB after repeated SDK/simulator work. In one observed VM, `/nix/store` reached about 63 GB.

Safe cleanup candidates:

```bash
rm -rf ~/path/to/app/target ~/path/to/core/target
nix-collect-garbage -d
echo '<sudo-password>' | sudo -S apt-get clean
df -h /
```

After cleanup, the next build may redownload/rebuild Rust, cross-compile, and simulator dependencies. Keep stable out-links for simulator GUI libraries before garbage collection.

## VirtualBox Notes

- USB passthrough may work without Extension Pack for some devices.
- If installing Extension Pack, Oracle presents a license. The user must review/accept it manually.
- If Windows shows WSL I/O performance warnings for projects stored on Windows drives, prefer keeping active SDK work inside the Linux filesystem/VM.
