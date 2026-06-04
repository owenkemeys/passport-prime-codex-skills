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
- When reporting build or runtime blockers, explain user impact before toolchain detail. Say what works, what does not work, and whether the user can test anything useful now. Do not lead with crate names, target triples, or compiler internals when the key point is that a core app feature is still missing.
- Do not assume blanket permission to operate a user's VM. If the user grants it for the session, proceed without repeated permission chatter; otherwise keep VM operations explicit and reversible.
- For iterative app work, avoid spending a long build/restart/test cycle before the user has seen the edit scope. Unless the prompt explicitly asks for the full loop, make the source edits first, summarize what is ready to build/test, and ask whether to continue.
- Treat `foundation build` as a long-running action that needs user value. Run it only when explicitly requested, or when it is a targeted feasibility probe that answers a clear user-relevant question. If the intended core capability is still unproven, brief the user first instead of launching a build.
- During active simulator review, do not stop/kill the simulator unless the current request includes build/run/deploy/restart work or the user explicitly permits it. File-copy helpers that edit simulator `disk.dat` should require an explicit stop flag and fail fast without it.
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

If an app builds only after stubbing or removing the feature it was created to provide:

- Say that the build is only a shell or partial prototype.
- Say that the intended capability is still blocked.
- Ask whether to test launch/UI basics anyway or continue investigating the core blocker.
- Include the technical failure after the plain-English product status.

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
- Check for active `foundation`, `cargo`, `rustc`, `nix`, and simulator processes, and ask whether another thread or alternating project is using the VM.
- Preserve any needed small app bundle, then propose the exact reproducible app `target/` directory to clean, including path and size.
- Do not clean shared SDK/Nix state, another project's build output, or the app currently under simulator review unless the user explicitly approves that scope.
- Run `nix-collect-garbage -d` only when target cleanup is not enough or free space is critically low, no other Nix/build work is active, and the user approves it.
- Expect the next build/simulator launch to redownload or rebuild toolchain pieces.
- A successful device build can still be followed by a separate hosted/simulator build that needs tens of GiB. If `foundation sim` may rebuild and free space is below about 25-30 GiB, preserve any needed bundle and ask before removing the reproducible app `target/` before simulator launch, not after launch.

If another thread or user is actively testing in the simulator:

- Continue build-only work only if the project has its own VM app directory.
- Do not run `foundation sim`.
- Do not stop or restart simulator processes.
- Do not edit simulator `disk.dat`.
- Do not resize Weston/Openbox or take over the visible simulator window.
- Avoid cleanup commands that can affect the running app, shared SDK state, Nix store/cache, or another project's active `target/` directory.

After a successful simulator launch:

- Treat app process detection as proof the current build is worth keeping warm during the review loop.
- Preserve the small signed bundle if needed, and log disk/memory state.
- Do not remove the app's current `target/` output after launch; doing that makes restart-only tasks rebuild.
- Run the riskier cleanup just before a new build. For full build+sim handoffs, it is usually better to pay the cold-build cost intentionally before launch than to fail mid-simulator build with `No space left on device`. Keeping `target/` warm is mainly for restart-only tasks where no compile is expected.

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

Display readiness before simulator launch:

```text
DISPLAY=:0 xdpyinfo
test -S /run/user/1000/wayland-1
```

Clean simulator screenshot:

```text
Screenshot saved to <app>/screenshots/screenshot_N.png
```

## Avoid These Traps

- Do not accept the Oracle VirtualBox Extension Pack license on the user's behalf.
- Do not hard-code `/nix/store/...` GUI library paths without stable out-links; garbage collection can remove them.
- Do not pipe ad hoc heredocs or inline scripts into `ssh` from PowerShell for VM/simulator operations. Create a reusable helper script, copy it with `scp`, then run it with `ssh -o BatchMode=yes -o ConnectTimeout=5 ... "timeout <seconds> bash <helper>"` so bad keys, password prompts, stale NAT, and hung remote commands fail fast.
- Do not use `sudo mount` as the first choice for placing small files into the simulator's internal storage. Prefer a purpose-built FAT32 image writer against `~/.foundation/sdk/current/lib/keyos/simulator/xous/kernel/disk.dat` after stopping the simulator; mounting the disk image is a fallback investigation path. The "Internal" file picker displays the FAT `user` directory, so write import-test files to `user/<name>.JSON` rather than the disk-image root. Use simple unique names like `user/TEST1.JSON`, `user/TEST2.JSON`; long FAT names and `.JSON` aliases can collide if the writer does not handle long-name entries perfectly.
- For repeated simulator-file staging, verify the actual FAT directory after writing. A long-filename writer must remove the old short entry and its LFN slots before replacing an existing `.JSON`; otherwise re-runs can leave orphan LFN entries where strings exist in `disk.dat` but the OS picker cannot see the files.
- Do not use `weston --fullscreen` as the handoff fix for a small/off-screen simulator view. Weston is the host window inside Openbox; start it as a large normal window and maximize that Weston window through Openbox/xdotool.
- If the VirtualBox view has a large black unused area, fix the Weston host window position/size first. Do not tweak Passport simulator settings until Weston itself is maximized or otherwise large enough.
- Do not assume the VM GUI session exists after a reboot or forced shutdown. If `foundation sim` fails with `NoCompositor` / `Could not find wayland compositor`, check `DISPLAY=:0 xdpyinfo`, start Openbox with `startx` if needed, then start Weston and wait for `/run/user/1000/wayland-1` before launching the simulator.
- Do not rely on full-desktop screenshots alone; use the simulator's Screenshot button for clean Passport Prime screen captures.
- For screenshot-heavy review, mirror simulator captures to a normal Windows folder and make deletion-friendly sync state; do not leave hundreds of numbered captures only inside the VM.
- Avoid complex PowerShell-to-SSH quoting, especially remote `$()` substitutions or inline `DISPLAY=:0` assignments inside double-quoted remote commands. Put shell wrappers in the VM.
