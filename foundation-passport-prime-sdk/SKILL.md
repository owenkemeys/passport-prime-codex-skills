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

## Build Value Gate

Treat `foundation build` as a potentially long-running, resource-heavy action. Run it only when the user explicitly asked for a build/run/test/simulator handoff, or when you can state a narrow user-relevant question the build will answer.

Before starting a speculative or feasibility build, brief the user in plain English on what is known, what is unproven, and what decision the build result would support. Do not start a build just to keep moving when the core product capability is still unproven. In that situation, report the feasibility status first and ask whether to continue investigating, try another approach, or run a targeted build probe.

## Functional Status Reporting

When reporting build results, lead with what the app can and cannot do from the user's point of view. A signed build is not a working product if the core capability is stubbed, mocked, or blocked.

If a workaround, shim, placeholder, or disabled subsystem was used to make a build pass, say that before the technical detail. Explain:

- what works now
- what still does not work
- whether the user can test packaging/UI anyway
- what decision or next milestone is needed

For technical blockers, translate toolchain details into user impact before naming crates, target triples, or compiler errors. Example shape:

```text
The app can now be packaged, but the part that runs user scripts is not working yet. One lower-level dependency of the attempted JavaScript engine is not compatible with the Prime app environment, so I removed that engine to prove the app shell can build. Testing now would only validate launch/UI basics, not the intended scripting feature.

Technical detail: <engine/dependency/target error here>.
```

Do not describe a prototype as "built" without also saying when it is only a buildable shell.

## Runtime And Dependency Feasibility

For embedded runtimes or other core engines, prove target compatibility before building substantial UI around them:

1. Identify a candidate runtime and explain what evidence is still missing.
2. If a target build is the only practical proof, brief the user before running it and frame it as a feasibility probe.
3. Build the app with the runtime dependency for the KeyOS target.
4. Execute the smallest useful program, such as `1 + 1`.
5. Expose one host function.
6. Only then add file input/output and UI workflows.

Treat target-specific dependency failures as product blockers when they prevent the core capability. For example, if a JavaScript engine pulls in unsupported random, SIMD, OS, networking, thread, or filesystem dependencies for `armv7a-unknown-xous-elf`, report that as "the scripting/runtime engine does not yet build for Prime", not as a minor dependency cleanup.

## Security-Sensitive Apps

For apps that store or release passwords, notes, keys, identity data, payment data, imported secrets, or other private records, use the `keyos-secure-app-architecture` skill before designing storage, import/export, host protocols, approval flows, or data-loss handling.


## Runtime Proof And Error Visibility

For embedded script runtimes, treat the useful proof as a visible end-to-end run, not just a dependency compile:

1. The app launches in the simulator.
2. A bundled minimal script executes.
3. At least one host function reads input.
4. At least one host function records a log or writes an output.
5. The UI shows the result or the actual error clearly enough to diagnose.

For simulator handoff, "the process is alive" is not the same as "ready for the user to test." Confirm the app is visibly rendered in the simulator window, or clearly say that only process/log evidence was obtained. If the app process is alive but Weston/the simulator surface is blank, treat that as a simulator/display problem and report it plainly instead of calling the handoff ready.

If the app only says `Script failed`, fix observability before changing engines or guessing at dependencies. Small-screen tool apps should keep logs and outputs scrollable, selectable, or otherwise inspectable; a clipped error message is effectively missing test evidence.

When simulator testing reveals a runtime fix, say whether the signed Prime target bundle was rebuilt after that fix. A simulator build and a signed device-target build are separate proofs.
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

When `foundation build` reports confusing config errors, compare `app-config.toml` against a known-good scaffold or existing working app before deeper debugging. Check app id format, minimum KeyOS version, permission template names, explicit extra permissions, icon path, and signing identity fields. Do not hard-code personal signing identity names in reusable docs or templates.

Known useful commands from the SDK docs/session:

```bash
foundation doctor
foundation build
foundation sim
foundation sideload --help
foundation cert --help
```

Use the actual installed SDK help output as authority when available.

## Slint UI And SVG Assets

For small icons in Passport Prime Slint UIs, treat SVGs as source vectors but verify how the SDK renderer displays them. Some rendering paths may rasterize or cache a small SVG near its declared intrinsic size before layout scaling, so scaling a 24px icon up in Slint can produce pixelation or edge clipping even though SVG is vector data. Prefer:

- Use designer-provided SVGs on transparent backgrounds, not PNG screenshots of icons.
- Keep a source manifest for imported design assets, such as icon name, Figma/design-system URL, local filename, and any deliberate divergence.
- First solve placement with Slint containers: fixed touch target, fixed icon slot, explicit `x`/`y` centering, and padding in the parent layout.
- Render small UI icons near their intended native size inside larger touch targets. Use a larger source/export for larger rendered icons rather than scaling a tiny master aggressively.
- Do not manually edit a designer SVG by default. If the exact exported SVG is unusable in the SDK renderer and direct SVG adjustment is needed, tell the user, preserve the original when practical, and record which asset diverged from spec and why.
- Hero or large illustrative SVGs may behave differently from tiny controls; validate both classes separately.

## Form And Overlay Behavior

Small-screen form polish matters because the on-screen keyboard can cover most of the viewport:

- For detailed text-field focus, keyboard avoidance, tap-outside dismissal, modal keyboard behavior, and simulator regression cases, use the `keyos-keyboard-management` skill.
- Keyboard avoidance should activate only for text entry controls. Do not run text-field scroll/avoidance logic for toggles, checkboxes, pickers, or buttons.
- When a modal must move above the keyboard, move the whole modal; do not shrink or scale the modal unless every internal row is explicitly responsive. Shrinking a fixed-layout modal often pushes buttons outside the card.
- For icon buttons in rows and menus, use a fixed wrapper and center the icon explicitly. Do not rely on a text-and-icon layout to place a small icon correctly without checking the actual simulator.
- Keep lockscreen or PIN prompt header text short enough that it cannot collide with back or navigation affordances. If dynamic headers can be long, truncate, wrap safely, or use a fixed short fallback label. This is a layout constraint only.
- Use stable heights and padding for repeated row components so edited text, labels, toggles, and action icons cannot shift or overlap.

## Common Failure Modes

- `foundation` not found: SDK bin path is not in `PATH`, or command is outside the SDK Nix shell.
- Dynamic loader or missing library errors: direct binary execution may fail outside `nix develop`.
- `app-config.toml not found`: command is not running from the app directory.
- Cargo dependency paths point to another user's SDK: scaffolded app may contain absolute SDK paths in `Cargo.toml`; patch or regenerate them when moving projects between machines/users.
- Simulator GUI/camera issues under WSL are not reliable evidence that app code is broken.

## Version Caveat

As reported by Foundation during this project, SDK v0.4 can build signed apps but cannot install them on hardware by itself. Hardware install/sideload-launch requires newer SDK/firmware with app menu and developer certificate support.
