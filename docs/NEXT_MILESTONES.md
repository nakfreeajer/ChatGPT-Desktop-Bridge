# Next milestones and decision gates

**BRIDGE.M02-D.15P update (2026-10-16):** The supervised launcher completed one human-run controlled integrated qualification with `PASS_CONTROLLED_INTEGRATED`. The existing ARM browser tab was activated and verified. This does not establish durable main-Desktop identity binding; message submission remains unimplemented and unauthorized.

**Initial evidence date:** 2026-10-15. **Updated:** 2026-10-16 (M02-D.13 offline qualification). **Authority:** owner approved M00 documentation and separately approved **BRIDGE.M02-A navigation-only implementation**. No message insertion/submission, unattended release, other-repository changes, credentials, CDP or API integration is approved.

| Milestone | Current status | Scope / exit condition |
|---|---|---|
| BRIDGE.M00 — Preserve findings | COMPLETE — documentation-only bootstrap committed and GitHub file listing verified on 2026-10-15 | Store project objective, tested findings, corrected diagnostic reference, limits, and roadmap |
| BRIDGE.M01 — Stable identity | Browser-route experiments PASS (2026-10-16); native Desktop binding unresolved | URL extraction, URL injection, focused suggestion + Enter navigation (human-observed), post-navigation expected URL check, and editor's RootWebArea ancestry were demonstrated. These findings apply to the **embedded browser** only |
| BRIDGE.M02-A — Navigation-only prototype | PASS_CONTROLLED_HAPPY_PATH (human-run) | 18/18 offline assertions; home-screen inspection mismatch reported without navigation; controlled opt-in home-to-CDLD navigation reported NavigationAttempted=true and verified expected browser URL/editor. Not unattended-qualified |
| BRIDGE.M02-B — Read-only browser tab discovery | PASS_OBSERVED_SCOPE (human-run) | TabItem discovery/selection for one then two tabs, blank second-tab address EMPTY, selected CDLD tab conversation URL length 58, and inspection-only mismatch on blank tab; main Desktop immutable identity remains unresolved |
| BRIDGE.M02-C — Selected-tab stability guard | PASS_CONTROLLED_SINGLE_TAB_NAVIGATION and PASS_TWO_TAB_NEGATIVE (human-run) | 20/20 new offline tests, supervised single-tab ID/editor/tab checks, home-to-CDLD navigation with selected-tab stability, two-tab wrong-ID rejection; no deliberate mid-navigation tab switch |
| BRIDGE.M02-D.1–12 — Manual to automated menu path | PASS_CONTROLLED_OBSERVATION (human-run) | ARM main-panel title and browser title both visible; manual ARM URL baseline captured; CDLD browser ID mismatch rejected; sidebar Chat actions ExpandCollapse and Open on chatgpt.com Invoke verified; browser ID matched ARM baseline in selected tab |
| BRIDGE.M02-D.13 — Integrated menu-to-browser-ID verifier | PASS_CONTROLLED_INTEGRATED via M02-D.15P; current offline regression suites 167/167 | One supervised run verified the unique sidebar action, expected browser ID, document and stable selected tab. The existing tab was activated; no message was sent. General repeatability and permanent main-Desktop binding remain unqualified |
| BRIDGE.M02-D.15E — Associated menu verification regression | OFFLINE_QUALIFIED (54/54 Resolve; 127/127 all suites); LIVE INVOCATION NOT RUN | Single Expand preserved; document-scoped Chat actions ancestry, unique visible/enabled/invokable item, and fresh target/item validation before invocation |
| BRIDGE.M02-D.15I — Delayed browser-address availability | OFFLINE_QUALIFIED (151/151; 24 added; prior 127 preserved); LIVE NOT RUN | Shared two-second/125 ms ValuePattern poll; one focus per operation; selected-tab RuntimeId/count checked around each read; URL parsing and expected-ID comparison remain separate |
| BRIDGE.M02-D.15N — Browser-document geometry | OFFLINE_QUALIFIED (167/167 all suites); commit `8231d97` | Horizontal address-bar containment replaces the disproven left-edge tolerance; title, visibility, placement, width, uniqueness, UUID and tab safeguards retained |
| BRIDGE.M02-D.15O — Live document verification | LIVE_DOCUMENT_VERIFIED | Exactly one qualifying ARM embedded-browser document; selected tab stable; read-only diagnostic |
| BRIDGE.M02-D.15P — Integrated supervised qualification | PASS_CONTROLLED_INTEGRATED (human-run, Architect accepted) | Existing ARM browser tab activated; expected browser identity/document and tab stability verified; `MainDesktopBound=false`; no composer write or Send |
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
- **Validation evidence:** M02-D.15P is accepted as one `PASS_CONTROLLED_INTEGRATED` supervised run; all current offline suites passed **167/167**. This controlled scenario is not unattended qualification. Multiple windows, duplicate/renamed conversations, app/session lifecycle changes, focus/tab races and message-delivery semantics remain unqualified or unimplemented.
- **Blocking for production:** automatic durable target binding, ambiguity/race controls, delivery-result semantics, duplicate protection, lifecycle tests.

## Next human/Architect checkpoint

Review the M02-D.15P controlled evidence and remaining identity-binding limitations. This record authorizes no additional live test or message submission.
