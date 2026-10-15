# Next milestones and decision gates

**Date:** 2026-10-15. **Authority:** owner approved **documentation-only repository initialization**. This approval does **not** approve implementation, live sends, app/system changes, credentials, CDP, or production integration.

| Milestone | Current status | Scope / exit condition |
|---|---|---|
| BRIDGE.M00 — Preserve findings | COMPLETE — documentation-only bootstrap committed and GitHub file listing verified on 2026-10-15 | Store project objective, tested findings, corrected diagnostic reference, limits, and roadmap |
| BRIDGE.M01 — Stable identity | Partial experimental progress | UIA native metadata not found; focused embedded-browser URL extraction and known-ID comparison passed; **automatic sidebar-to-ID binding unresolved** |
| BRIDGE.M02 — Verified selection | Proposed, not approved | Select intended conversation and prove it matches expected durable ID, including negative cases |
| BRIDGE.M03 — Guarded delivery | Proposed, not approved | Authorized disposable-target send only after identity gate qualified |
| BRIDGE.M04 — Results / duplicates | Proposed, not approved | Defined acknowledgement levels, request IDs, idempotency and ambiguous-outcome recovery |
| BRIDGE.M05 — Lifecycle qualification | Proposed, not approved | App restarts, updates, multiple windows, locked session, renamed/missing targets |
| BRIDGE.M06 — Minimal local interface | Proposed, not approved | Thin callable library or executable; no orchestration |
| BRIDGE.M07 — Release documentation | Proposed, not approved | Reproducible compatibility and security evidence, qualified PoC release |

## Immediate recommended investigation (requires separate approval if it changes live UI)

Design a **bounded, read-first experiment** that tests automatic binding between a chosen Desktop conversation and its actual conversation ID. Use a disposable conversation and prove mismatch rejection. The embedded browser and main Desktop can diverge; simply reading a URL and matching a title is insufficient.

Start with evidence design, not a coding sprint. Desired negative tests include:
- Browser tab is on conversation B while Desktop composer is on conversation A.
- Duplicate sidebar titles exist.
- Conversation gets renamed or hidden after discovery.
- More than one ChatGPT Desktop main window is present.
- Focus, navigation, or accessibility control becomes stale between verify and Send.

## Decision register

- **Approved:** M00 documentation-only repository bootstrap, on 2026-10-15.
- **Not approved:** executable automation implementation, automatic message submission, background monitoring, other-repository changes, provisioning, security-setting changes.
- **Blocking for production:** automatic durable target binding, ambiguity/race controls, delivery-result semantics, duplicate protection, lifecycle tests.

## Next human/Architect checkpoint

1. Review the committed docs for fidelity to the handover and the reported 2026-10-15 PowerShell outputs.
2. Confirm intended disposable conversation and identity-binding test design.
3. Request bounded authorization before any fresh interactive experiment or source-code implementation.
