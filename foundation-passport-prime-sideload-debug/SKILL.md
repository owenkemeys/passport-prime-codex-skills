---
name: foundation-passport-prime-sideload-debug
description: Sideload and debug Passport Prime app bundles. Use when Codex needs to attach a physical Passport Prime, inspect AIRLOCK storage, run foundation sideload/logs, use --mount-path or --no-run, verify the keyos apps folder contains app.elf and manifest.json, distinguish copy success from firmware launch/install support, or prepare concise failure reports for Foundation.
---

# Foundation Passport Prime Sideload Debug

Use this skill when a built Passport Prime app needs to reach real hardware, or when a tester needs clear evidence about what failed. For Windows/Codex setup before hardware testing, use `foundation-passport-prime-windows-codex`.

## Safety Rules

- Never assume copying `app.elf` means the app can launch.
- Never claim hardware install works unless the firmware exposes the needed app/developer UI or `foundation sideload` successfully launches it.
- Use `--no-run` when only validating USB storage copy.
- Unmount/eject after writes before asking the user to inspect the device.
- Keep reports concrete: exact command, exact destination path, exact device-visible result.

## Inspect SDK Sideload Options

Always prefer installed SDK help:

```bash
foundation sideload --help
```

Known options from SDK v0.4:

```text
--release
--no-run
--mount-path <PATH>
--serial-port <PATH>
```

## Copy-Only Sideload

Use this when firmware launch support is unknown or unavailable:

```bash
foundation sideload --mount-path /mnt/prime --no-run
```

Expected success output:

```text
Build complete
Resolving Passport Prime USB storage mount...
Using device mount: /mnt/prime
Copying signed app bundle to the device...
Copied app bundle to /mnt/prime/keyos/apps/<app-id>
Skipping automatic launch (--no-run).
Sideload complete!
```

Verify files:

```bash
find /mnt/prime/keyos/apps/<app-id> -maxdepth 2 -type f -print
sync
sudo umount /mnt/prime
```

On Windows after detach, verify:

```powershell
Get-ChildItem -LiteralPath 'F:\keyos\apps\<app-id>' -Recurse -File
```

Expected files:

```text
app.elf
manifest.json
```

## Interpreting Outcomes

Copy succeeded, app does not appear on device:

- Report as a firmware/install path question, not a build failure.
- Ask Foundation what firmware/app-menu/dev-certificate flow should consume `/keyos/apps/<app-id>`.

Copy fails before build:

- Use `foundation-passport-prime-sdk` to diagnose SDK shell, app-config, Cargo paths, or signing.

Copy fails resolving mount:

- Confirm Passport Prime appears as `AIRLOCK`.
- Mount explicitly and pass `--mount-path`.
- If using a VM, use `foundation-passport-prime-vm-workflow` for USB attach/mount.

Automatic launch fails:

- Try copy-only `--no-run`.
- Then check whether the public firmware supports developer app launch.
- Capture any serial/log error only if the debug channel is available.

## Known Beta Limitation

Foundation reported that SDK v0.4 cannot install on hardware. Newer internal SDK/firmware has an apps menu, developer certificate installation, and sideload support. Therefore a successful copy into `/keyos/apps/<app-id>` may be the furthest possible public-SDK result until the user has the newer firmware/SDK path.

## Foundation Report Template

Use this concise structure:

```text
SDK version:
Firmware version:
Command run:
Mount path:
Copied files present:
Device UI result:
Question/blocker:
```
