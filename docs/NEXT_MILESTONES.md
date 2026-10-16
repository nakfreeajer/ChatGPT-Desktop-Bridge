# Next milestones and decision gates

**BRIDGE.CODEX.BASELINE.1B update (2026-10-16):** The secure supervised launcher passed offline qualification (35 assertions) and is awaiting Architect review. Its secure prompt, UIA baseline and live menu path were not executed. BRIDGE.M02-D.15 remains not started; this milestone does not authorize live invocation.

**Initial evidence date:** 2026-10-15. **Updated:** 2026-10-16 (M02-D.13 offline qualification). **Authority:** owner approved M00 documentation and separately approved **BRIDGE.M02-A navigation-only implementation**. No message insertion/submission, unattended release, other-repository changes, credentials, CDP or API integration is approved.

| Milestone | Current status | Scope / exit condition |
|---|---|---|
| BRIDGE.M00 — Preserve findings | COMPLETE — documentation-only bootstrap committed and GitHub file listing verified on 2026-10-15 | Store project objective, tested findings, corrected diagnostic reference, limits, and roadmap |
| BRIDGE.M01 — Stable identity | Browser-route experiments PASS (2026-10-16); native Desktop binding unresolved | URL extraction, URL injection, focused suggestion + Enter navigation (human-observed), post-navigation expected URL check, and editor's RootWebArea ancestry were demonstrated. These findings apply to the **embedded browser** only |
| BRIDGE.M02-A — Navigation-only prototype | PASS_CONTROLLED_HAPPY_PATH (human-run) | 18/18 offline assertions; home-screen inspection mismatch reported without navigation; controlled opt-in home-to-CDLD navigation reported NavigationAttempted=true and verified expected browser URL/editor. Not unattended-qualified |
| BRIDGE.M02-B — Read-only browser tab discovery | PASS_OBSERVED_SCOPE (human-run) | TabItem discovery/selection for one then two tabs, blank second-tab address EMPTY, selected CDLD tab conversation URL length 58, and inspection-only mismatch on blank tab; main Desktop immutable identity remains unresolved |
| BRIDGE.M02-C — Selected-tab stability guard | PASS_CONTROLLED_SINGLE_TAB_NAVIGATION and PASS_TWO_TAB_NEGATIVE (human-run) | 20/20 new offline tests, supervised single-tab ID/editor/tab checks, home-to-CDLD navigation with selected-tab stability, two-tab wrong-ID rejection; no deliberate mid-navigation tab switch |
| BRIDGE.M02-D.1–12 — Manual to automated menu path | PASS_CONTROLLED_OBSERVATION (human-run) | ARM main-panel title and browser title both visible; manual ARM URL baseline captured; CDLD browser ID mismatch rejected; sidebar Chat actions ExpandCollapse and Open on chatgpt.com Invoke verified; browser ID matched ARM baseline in selected tab |
| BRIDGE.M02-D.13 — Integrated menu-to-browser-ID verifier | OFFLINE_QUALIFIED (33/33); LIVE PREFLIGHT PENDING | Fail-closed separate script: main document/title and unique sidebar action preflight, explicit menu invocation, expected browser ID/selected-tab/document revalidation; no sending and no permanent main Desktop binding |
| BRIDGE.M02-D.15E — Associated menu verification regression | OFFLINE_QUALIFIED (54/54 Resolve; 127/127 all suites); LIVE INVOCATION NOT RUN | Single Expand preserved; document-scoped Chat actions ancestry, unique visible/enabled/invokable item, and fresh target/item validation before invocation |
| BRIDGE.M02-D.15I — Delayed browser-address availability | OFFLINE_QUALIFIED (151/151; 24 added; prior 127 preserved); LIVE NOT RUN | Shared two-second/125 ms ValuePattern poll; one focus per operation; selected-tab RuntimeId/count checked around each read; URL parsing and expected-ID comparison remain separate |
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

- **Approved:** M00 documentation bootstrap; M02-A navigation-only prototype; M02-C selected-tab safety; M02-D.13 bounded menu-to-browser-ID integration without message submission.
- **Not approved:** automatic message submission, full production routing, background monitoring, other-repository changes, provisioning, or security-setting changes.
- **Validation evidence:** Human reports M02-A 18/18, M02-C 20/20, M02-D.13 33/33 offline test assertions PASS (**71/71 total**). M02-C passed supervised positive/negative scenarios, not race/lifecycle qualification. **Still needed:** M02-D.13 integrated live preflight, then separately supervised menu invocation and ID verification.
- **Blocking for production:** automatic durable target binding, ambiguity/race controls, delivery-result semantics, duplicate protection, lifecycle tests.

## Next human/Architect checkpoint

1. M02-D.13 `Resolve.Offline.Tests.ps1` already returned `PASS` with 33 assertions; retain the full 71/71 offline result in the record.
2. Run `src/Bridge.Resolve.ps1` with exact ARM title and the privately captured expected ARM ID, without `-OpenInBrowser`; expect `PREFLIGHT_PASS`.
3. Before explicit invocation, manually select a different browser conversation (e.g., CDLD) in the ARM window. Use `-OpenInBrowser` once; check `MENU_TO_BROWSER_ID_VERIFIED`, record the tab transition. Stop at an unexpected outcome. No chat message sends.
