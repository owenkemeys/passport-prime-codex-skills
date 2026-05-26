---
name: foundation-passport-prime-sdk
description: Develop Passport Prime apps with Foundation's SDK. Use when Codex needs to find current Foundation developer docs, install or verify the Passport Prime SDK, scaffold or inspect a Passport Prime app, run foundation doctor/build/sim, create signing identities, diagnose app-config/Cargo SDK path issues, or explain known SDK beta limitations.
---

# Foundation Passport Prime SDK

Use this skill for the general Passport Prime SDK loop. For Windows/Codex newcomers, start with `foundation-passport-prime-windows-codex`. For Windows or VM-specific work, also use `foundation-passport-prime-vm-workflow`. For physical-device copy/install/log work, also use `foundation-passport-prime-sideload-debug`.

## Fresh Docs First

If the task depends on current Foundation SDK behavior, browse fresh public docs before acting. Known entry points:

- `https://foundation.xyz/developers`
- `https://docs.foundation.xyz/developers/home/`
- `https://foundation.xyz/llms.txt`

Treat SDK beta behavior as changeable. Verify commands before telling the user they are blocked.

## Baseline Flow

Prefer this order:

1. Verify host platform support. SDK beta has been confirmed by Foundation to support Linux and Mac; Windows/WSL is not a supported target unless Foundation changes this.
2. Install prerequisites: Nix with flakes, Git, Unix-like shell.
3. Install SDK using the current Foundation installer from the docs.
4. Run `foundation doctor` inside the SDK Nix shell.
5. Scaffold or inspect app with `foundation new <app>`.
6. Generate or verify signing identity.
7. Build with `foundation build`.
8. Only then attempt simulator, sideload, logs, or hardware test.

## Command Patterns

Use the SDK Nix shell when running Foundation commands:

```bash
source /etc/profile.d/nix.sh
cd ~/.foundation/sdk/current
nix develop --command foundation doctor
```

For project commands:

```bash
source /etc/profile.d/nix.sh
cd ~/.foundation/sdk/current
nix develop --command bash -c 'cd /path/to/app && foundation build'
```

If nested shell quoting is fragile, create a tiny wrapper script in the target environment and run that through `nix develop`.

## App Config And Signing

Check `app-config.toml` early. It controls app name, version, permissions/capabilities, and signing identity expectations.

Known useful commands from the SDK docs/session:

```bash
foundation doctor
foundation build
foundation sim
foundation sideload --help
foundation cert --help
```

Use the actual installed SDK help output as authority when available.

## Common Failure Modes

- `foundation` not found: SDK bin path is not in `PATH`, or command is outside the SDK Nix shell.
- Dynamic loader or missing library errors: direct binary execution may fail outside `nix develop`.
- `app-config.toml not found`: command is not running from the app directory.
- Cargo dependency paths point to another user's SDK: scaffolded app may contain absolute SDK paths in `Cargo.toml`; patch or regenerate them when moving projects between machines/users.
- Simulator GUI/camera issues under WSL are not reliable evidence that app code is broken.

## Version Caveat

As reported by Foundation during this project, SDK v0.4 can build signed apps but cannot install them on hardware by itself. Hardware install/sideload-launch requires newer SDK/firmware with app menu and developer certificate support.
