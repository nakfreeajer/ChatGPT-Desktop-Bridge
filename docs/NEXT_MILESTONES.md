# Next milestones and decision gates

**Initial evidence date:** 2026-10-15. **Updated:** 2026-10-16. **Authority:** owner approved M00 documentation and separately approved **BRIDGE.M02-A navigation-only implementation**. No message insertion/submission, unattended release, other-repository changes, credentials, CDP or API integration is approved.

| Milestone | Current status | Scope / exit condition |
|---|---|---|
| BRIDGE.M00 — Preserve findings | COMPLETE — documentation-only bootstrap committed and GitHub file listing verified on 2026-10-15 | Store project objective, tested findings, corrected diagnostic reference, limits, and roadmap |
| BRIDGE.M01 — Stable identity | Browser-route experiments PASS (2026-10-16); native Desktop binding unresolved | URL extraction, URL injection, focused suggestion + Enter navigation (human-observed), post-navigation expected URL check, and editor's RootWebArea ancestry were demonstrated. These findings apply to the **embedded browser** only |
| BRIDGE.M02-A — Navigation-only prototype | Source committed; Windows qualification PENDING | Accept expected UUID, optional home-to-conversation browser navigation, verify browser URL + document/editor candidate, return JSON codes. No sends or main-Desktop-to-ID binding |
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

- **Approved:** M00 documentation-only bootstrap (2026-10-15); M02-A **navigation-only** prototype source implementation (2026-10-16).
- **Not approved:** automatic message submission, full production routing, background monitoring, other-repository changes, provisioning, or security-setting changes.
- **Validation needed:** Windows PowerShell parser/offline tests and controlled actual navigation before marking M02-A runtime PASS; do not infer this from source commit.
- **Blocking for production:** automatic durable target binding, ambiguity/race controls, delivery-result semantics, duplicate protection, lifecycle tests.

## Next human/Architect checkpoint

1. Run `tests/Identity.Offline.Tests.ps1` on Windows PowerShell 5.1 and report actual result.
2. Review and perform one authorized navigation-only qualification from ChatGPT home with empty drafts; capture JSON status and visually verify the embedded browser destination.
3. Preserve the main Desktop vs. embedded-browser identity distinction. Do not initiate any message-sending implementation without separate approval.
