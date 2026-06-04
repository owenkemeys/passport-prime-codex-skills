---
name: keyos-secure-app-architecture
description: Design, review, or harden security-sensitive KeyOS or Passport Prime apps that store secrets, import/export sensitive data, derive keys, persist encrypted state, expose host/device protocols, require on-device approval, or need host-testable Rust logic.
metadata:
  short-description: Secure KeyOS app architecture
---

# KeyOS Secure App Architecture

Use this skill for KeyOS/Passport Prime apps that handle passwords, notes, seeds, keys, identity data, payment data, imported secrets, host communication, or any record that a user expects to stay private and recover safely.

## Architectural Shape

- Put security-critical logic in one or more KeyOS-free Rust crates wherever possible. Keep parsing, record schemas, origin/scope rules, crypto/session logic, duplicate handling, and store traits host-testable with `cargo test`.
- Keep the KeyOS app shell thin: UI, platform API wiring, persistence adapter, device-key adapter, and transport adapter.
- If the app has a host-side companion, define a typed protocol crate or schema that both sides implement. Do not let the UI or transport invent ad hoc message shapes.
- Treat simulator and hardware as separate proofs. Host tests prove logic; simulator proves UI/platform glue; hardware proves real device APIs and transport.

## Secret Handling

- Derive app-specific storage keys from KeyOS hardware-backed app material when available. Add HKDF domain-separation info strings for each key use.
- Encrypt secrets at rest with an authenticated cipher such as AES-256-GCM. Store nonce plus ciphertext/tag, and reject short or corrupt blobs.
- Zeroize in-memory keys and plaintext secret copies where practical. Use `Zeroizing<T>`, `Zeroize`, or redacted wrapper types for passwords, seeds, and sensitive notes.
- Do not derive `Debug` for secret-bearing record types unless every sensitive field is deliberately redacted.
- Apply input length caps at protocol/import boundaries so hostile files or hosts cannot force unbounded storage growth.
- Return fixed, non-leaky public error messages to host or UI surfaces. Keep detailed errors only in trusted logs.

## Persistence And Data Safety

- On device, prefer the platform's app-data persistence primitive that already provides atomic write semantics.
- For simulator or host fallback persistence, mirror atomic behavior: write a temporary file, flush/fsync it, then rename into place.
- A mutation is not successful until persistence succeeds. Do not report "saved", "imported", or "updated" before the encrypted write commits.
- For batch mutation, snapshot state before applying changes and restore on persistence failure.
- Keep archived/soft-deleted records separate from live records in lookup paths. Host-facing release/search APIs must not expose archived records unless the user is in an explicit archive workflow.
- Add corrupted-data, wrong-key, empty-store, and interrupted-write tests before calling storage robust.

## Import Handling

- Parse sensitive exports on device when possible. Avoid sending plaintext imports over USB or network to helper tooling unless the user explicitly chose that architecture.
- Reject encrypted export formats clearly if the app cannot decrypt them.
- Auto-detect import sources by header/schema signatures, not just file extension.
- Handle BOM, UTF-8 failures, CRLF/LF, quoted delimiters, embedded newlines, doubled quotes, non-ASCII text, and empty rows.
- Cap import file size before parsing.
- Keep imported plaintext in a narrow scope and zeroize it after commit where practical.
- Separate parsing from committing. The UI should preview source, usable count, invalid count, duplicate/conflict count, and user-selected conflict policy before mutation.
- Give conflict policies explicit semantics: skip, replace existing, or keep both. If fuzzy matching is used, make the default conservative and let the user override.
- Add source-specific tests for every supported import format plus a generic fallback test.

## Host Protocols And Approval Gates

- Never release secrets silently. Host-triggered release, save, update, import, or generate operations should route through an on-device approval request when user trust is at stake.
- Approval requests should contain a clear action verb, the requesting scope, and the affected account/record label, with secret fields redacted.
- Include a cancel path for in-flight approvals.
- Use monotonic nonces or equivalent replay protection for host requests.
- If secrets cross a host transport, establish an encrypted session first. Prefer native browser/device crypto primitives on the host side where possible.
- Expire idle sessions and require a fresh handshake after expiry.
- For host-provided scope such as website origin, derive the trusted value from the platform/browser context. Do not trust a content script, iframe, page-world API, or user-editable field to assert privileged scope.
- Reject cross-frame or cross-origin attempts when the request scope does not match the trusted caller context.

## Origin And Scope Rules

- Normalize scopes before comparison: lowercase scheme/host, remove default ports, reject userinfo, and discard path/query/fragment when the app's model is origin-based.
- Keep exact-match semantics for save/update/probe unless there is an explicit, tested fuzzy policy.
- If fuzzy matching subdomains or registrable domains, account for multi-label public suffixes and suffix-injection attacks.
- Preserve port distinctions for localhost and IP literals.
- Add tests for IDN/punycode, default ports, explicit non-default ports, unsupported schemes, userinfo rejection, localhost, IP literals, and evil suffixes.

## UI And Workflow Expectations

- Sensitive details should default hidden or require a deliberate reveal/approval step when shoulder-surfing matters.
- Destructive delete should require archive/soft-delete first or a clear confirmation step.
- Import summaries should distinguish imported, skipped, replaced, failed, and invalid records.
- Empty states, archive states, and no-match states should be first-class UI states, not incidental blank screens.
- For text-entry screens, use the `keyos-keyboard-management` skill.

## Skill Maintenance Notes

- Do not bake personal signing identities, local file paths, private repo names, or user-specific policies into reusable guidance.
- If a pattern came from one app, generalize the principle and preserve caveats. Do not cargo-cult transport choices such as WebUSB, WebSocket, or a browser extension into apps that do not need them.
