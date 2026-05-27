---
name: foundation-passport-prime-windows-codex
description: Help Windows-based Codex users build and test Passport Prime apps despite Foundation Passport Prime SDK on Windows being unsupported. Use when setting up VirtualBox/Ubuntu for the Passport Prime SDK, recovering from WSL/Wayland/USB/simulator issues, running foundation build/sim from Windows through SSH, creating a reliable simulator screenshot/click loop, handling Nix disk growth, or explaining hardware sideload limits in SDK v0.4.
---

# Foundation Passport Prime Windows Codex

Use this skill when a user on Windows wants Codex to start building Passport Prime apps. Foundation's beta Passport Prime SDK is Linux/Mac-first; treat Windows/WSL as unsupported unless current Foundation docs say otherwise.

## Operating Stance

- Browse fresh Foundation docs if the task depends on current SDK behavior.
- Prefer a Linux VM over WSL for simulator, USB, and repeatable SDK work.
- Keep non-technical users out of terminal details where possible. Produce visible artifacts: a visible VM/simulator window, Windows-accessible simulator captures, app builds, concise status docs.
- Do not assume blanket permission to operate a user's VM. If the user grants it for the session, proceed without repeated permission chatter; otherwise keep VM operations explicit and reversible.
- Do not claim hardware install works unless the public SDK/firmware path has been verified.
- Keep local paths, usernames, SSH keys, and device-specific details out of reusable reports.

## Recommended Path

1. Use Windows only as the Codex host/controller.
2. Create or reuse a Linux VM, preferably VirtualBox + Ubuntu 24.04 LTS.
3. SSH from Windows/Codex into the VM.
4. Install Nix and Foundation Passport Prime SDK inside the VM as the normal VM user.
5. Run Foundation commands through the SDK Nix shell.
6. Build the app in the VM.
7. Use simulator testing first; hardware install may be unavailable on public SDK/firmware.

Read references as needed:

- `references/vm-setup.md` for VM shape, SSH, SDK install, wrappers, and disk hygiene.
- `references/simulator-testing.md` for the working visual test loop and screenshots.
- `references/hardware-sideload.md` for AIRLOCK copy-only sideload and SDK v0.4 limits.

## Fast Triage

If `foundation sim` fails in WSL:

- Do not assume app code is broken.
- Move to the VM flow.

If simulator launches but QR scanning fails:

- Check for `V4L2 Error: No such file or directory`.
- The VM likely has no camera device. Add app-level sample/test payload buttons or pass through a webcam.

If hardware copy works but tapping `app.elf` does nothing:

- Treat as expected for SDK v0.4/public firmware unless Foundation has provided newer sideload firmware.
- AIRLOCK/filesystem copy is not an app launcher.

If Nix fills the VM disk:

- Confirm with `df -h /` and `free -h`; apparent "memory" slowdowns are often disk exhaustion.
- Preserve any needed small app bundle, then clean reproducible app `target/` directories.
- Run `nix-collect-garbage -d`.
- Expect the next build/simulator launch to redownload or rebuild toolchain pieces.

## Known Good Signals

SDK:

```bash
source /etc/profile.d/nix.sh
cd ~/.foundation/sdk/current
nix develop --command foundation doctor
```

Build:

```bash
foundation build
# Build complete
# app.elf (signed)
# manifest.json
```

Simulator log:

```text
app_manager_server::launch: launched app <app-id>
gui_server: Switching to initial window, PID=<pid>
```

Clean simulator screenshot:

```text
Screenshot saved to <app>/screenshots/screenshot_N.png
```

## Avoid These Traps

- Do not accept the Oracle VirtualBox Extension Pack license on the user's behalf.
- Do not hard-code `/nix/store/...` GUI library paths without stable out-links; garbage collection can remove them.
- Do not rely on full-desktop screenshots alone; use the simulator's Screenshot button for clean Passport Prime screen captures.
- For screenshot-heavy review, mirror simulator captures to a normal Windows folder and make deletion-friendly sync state; do not leave hundreds of numbered captures only inside the VM.
- Avoid complex PowerShell-to-SSH quoting. Put shell wrappers in the VM.
