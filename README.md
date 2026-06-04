# Passport Prime Codex Skills

Community Codex skills for building and testing Foundation Passport Prime apps, especially from Windows where the Passport Prime SDK is not currently a supported target.

These are not official Foundation docs or official Foundation support. They are a practical workflow bundle from one early app-building session.

## Authorship

Written by Codex: This repository was prepared from real AI-assisted Passport Prime app development sessions. It is assistant-produced working material, not an official Foundation resource and not a statement that any individual user personally verified every command or recommendation.

Treat it as community starter material: useful, practical, and worth checking against current Foundation docs before relying on it.

## Included Skills

- `foundation-passport-prime-sdk` - general Passport Prime SDK workflow: docs, install, doctor, build, sim, signing, beta caveats.
- `foundation-passport-prime-windows-codex` - Windows-to-Linux-VM workflow for Codex users, including simulator screenshots, WSL pitfalls, and Nix disk hygiene.
- `foundation-passport-prime-vm-workflow` - VirtualBox/Ubuntu setup and operation for running Foundation SDK commands from Windows.
- `foundation-passport-prime-sideload-debug` - physical Passport Prime copy/debug workflow, AIRLOCK checks, and SDK v0.4 hardware-install limitations.
- `keyos-keyboard-management` - keyboard-safe KeyOS form behavior: focus, dismissal, avoidance, modals, and bottom action bars.
- `keyos-secure-app-architecture` - secure storage, import, host-protocol, and data-loss-resistance architecture for sensitive KeyOS apps.

## Install

Copy the skill folders into your Codex skills directory, then restart Codex.

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.codex\skills"
Copy-Item -Recurse .\foundation-passport-prime-* "$env:USERPROFILE\.codex\skills\"
Copy-Item -Recurse .\keyos-* "$env:USERPROFILE\.codex\skills\"
```

macOS/Linux:

```bash
mkdir -p ~/.codex/skills
cp -R foundation-passport-prime-* keyos-* ~/.codex/skills/
```

## Suggested Prompt

```text
Use the Passport Prime Windows/Codex skill to help me set up a Windows workflow for building and simulator-testing a Foundation Passport Prime app.
```

## Notes

- Foundation's beta Passport Prime SDK has been reported as Linux/Mac-first. Treat Windows/WSL as unsupported unless current Foundation docs say otherwise.
- The VM workflow is written for VirtualBox + Ubuntu, controlled from Codex on Windows.
- The simulator workflow includes the Weston/Openbox window trap: avoid `weston --fullscreen`, start Weston as a large normal window, and maximize the Weston host window before handing the VM back to a reviewer.
- SDK v0.4 could build and copy app files during our project, but did not support installing/launched apps on hardware without newer internal SDK/firmware support.
- Verify current Foundation docs before acting on anything SDK-version-sensitive.
