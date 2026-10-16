# Failure and recovery register

**Scope:** ChatGPT Desktop Bridge, Windows PowerShell 5.1, native Windows UI Automation, through BRIDGE.M02-D.15P.CLOSE and documentation consolidation. Only this repository is in scope.

This is the canonical detailed chronology of the observed failures, source diagnoses, corrections and qualification boundaries. The [GitHub curator issue](https://github.com/nakfreeajer/ChatGPT-Desktop-Bridge/issues/1) is the originating handover. The [investigation log](INVESTIGATION_LOG.md) is a short index; other documents summarize current behavior rather than repeat this register.

## Evidence classifications

- **OBSERVED — HUMAN:** reported by the human from a controlled live UI or terminal run; not independently reproduced here.
- **OBSERVED — EXECUTOR:** read-only UIA observation performed by Codex in the Windows session.
- **SOURCE-VERIFIED:** established by inspection of the committed source; source behavior is not itself live runtime proof.
- **OFFLINE-QUALIFIED:** the named PowerShell offline assertions passed; these tests do not interact with ChatGPT Desktop.
- **LIVE-QUALIFIED — CONTROLLED:** the complete named UIA scenario returned its expected result under supervision; this is limited to that scenario.
- **INCONCLUSIVE:** evidence did not establish success, failure, or the suspected cause.
- **HYPOTHESIS:** plausible explanation not established by evidence.
- **UNRESOLVED:** no reliable answer is available.

Titles classify visible UIA elements; they are not immutable conversation identifiers. RuntimeIds and window handles are ephemeral. The main Desktop panel and embedded browser are independent UI surfaces.

## 1. Early UIA and browser-route discoveries

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| The embedded browser address displayed only `chatgpt.com` while unfocused. | A visible enabled `Search or enter a URL` ComboBox exposes ValuePattern; after `SetFocus()`, the full conversation route became available. Focusing changes UI focus. | **OBSERVED — HUMAN.** One observed browser state; not a guarantee for every state. |
| `ValuePattern.SetValue()` did not navigate; invoking the autocomplete suggestion did not navigate. | The observed route required a focused, matching suggestion and Enter. `Bridge.Navigate.ps1` contains an explicit `-Navigate -AcceptKeyboardRisk` path with foreground, suggestion, and selected-tab guards. | **OBSERVED — HUMAN / SOURCE-VERIFIED.** Global Enter has a residual focus race; it is not unattended-qualified. |
| Browser URL/title was assumed to identify the main Desktop conversation. | Main Desktop and embedded browser can show different conversations simultaneously. Treat browser URL as evidence about the browser only. | **OBSERVED — HUMAN.** ARM main / CDLD browser divergence was observed. Permanent Desktop binding remains unavailable. |
| Multiple Edit controls made the browser editor unclear. | The experimental browser-route check constrained a plausible enabled editor to the browser address region and a `RootWebArea` Document ancestor. | **OBSERVED — HUMAN.** Structural evidence from one UI; not identity binding. |

## 2. Surface separation and selected-tab guard

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| A browser tab could be blank or differ from the Desktop conversation. | `Bridge.TabGuard.ps1` identifies visible TabItems near the address bar, requires supported SelectionItemPattern and exactly one selected tab, and retains RuntimeId plus visible tab count only in memory for within-operation stability. | **OBSERVED — HUMAN / SOURCE-VERIFIED.** RuntimeId is not durable identity. |
| A selected blank tab yielded no conversation address; another selected tab yielded a conversation route. | Re-read selected state and count around operations; do not infer identity from title or tab ordering. | **OBSERVED — HUMAN.** M02-C positive and negative scenarios passed; a deliberate mid-navigation switch race remains unqualified. |
| Tab count was previously treated as if one tab must always exist. | Two visible tabs are valid when exactly one is selected and snapshots remain stable. Report actual count; do not assume a new tab was created. | **OBSERVED — HUMAN.** A selected browser with two tabs was repeatedly observed. |
| M02-C tests | Identity suite **18/18**; TabGuard suite **20/20**. Controlled one-tab positive navigation and two-tab wrong/blank selection rejection passed. | **OFFLINE-QUALIFIED** for helpers/source guards; **LIVE-QUALIFIED — CONTROLLED** for those specific browser scenarios only. |

## 3. Sidebar menu discovery and integrated resolver

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| Sidebar ListItem did not expose SelectionItemPattern. | Find one visible exact-title ListItem, then its one enabled `Chat actions` Button with ExpandCollapsePattern. Do not select by row order or treat title as identity. | **OBSERVED — HUMAN.** |
| Initial search for `Open on chatgpt.com` returned no candidate. | The popup was not reliably open when searched. A human-opened menu exposed the item. A global name match alone does not establish ownership. | **OBSERVED — HUMAN.** |
| `Chat actions` had no InvokePattern. | Use the observed ExpandCollapsePattern. M02-D.10 performed a single `Expand()`, state changed `Collapsed` → `Expanded`, one menu item appeared; no navigation was performed. | **OBSERVED — HUMAN.** |
| Menu item invocation was tried separately. | A unique visible `Open on chatgpt.com` MenuItem supported InvokePattern. M02-D.11 invoked it; a later separate browser inspection matched the expected ARM route. | **OBSERVED — HUMAN.** Menu invocation alone did not prove browser identity or whether a new tab was created. |
| M02-D.13 integrated resolver added. | Inspect-only by default; explicit `-OpenInBrowser` invokes the sidebar menu after preflight. It requires independently supplied expected UUID, checks browser route, selected tab, document and tab transition; it reports `MainDesktopBound=false`. | **SOURCE-VERIFIED.** Early offline tests passed 71/71 across three suites; this was not live integrated proof. |
| M02-D.14 read-only preflight. | Human reported `PREFLIGHT_PASS`, title verified, unique sidebar target present; no menu item invoked. | **OBSERVED — HUMAN.** |

## 4. Executor and secure baseline recovery

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| `BRIDGE.CODEX.ACCESS.1A` asked whether the VS Code Codex process could use native Windows UIA. | The Windows PowerShell 5.1/UIA environment and offline tests were reported accessible. | **OBSERVED — HUMAN.** 71/71 offline assertions at that point. |
| `BLOCKED_BASELINE_NOT_AVAILABLE`: a private UUID in another PowerShell session was not available in the launcher process. | No guessing, title-derived ID, environment transfer or command-line transfer. `Bridge.Resolve.Supervised.ps1` asks for the independently verified UUID with `Read-Host -AsSecureString`, converts it only in process memory and calls the resolver in-process. | **SOURCE-VERIFIED / OFFLINE-QUALIFIED.** Launcher implementation commit `5eb2803c5bf384b07dcb9eccf00cc53edfcbf58a`; early launcher suite 35 assertions, later totals supersede. |
| BRIDGE.CODEX.BASELINE.1B initial regression run. | Identity 18/18 + TabGuard 20/20 + Resolve 34/34 + SupervisedLauncher 35/35 = **107/107**. | **OFFLINE-QUALIFIED.** Later menu, address and geometry regressions supersede this total. |
| `BASELINE_FORMAT_INVALID`. | The prompt expects the UUID value, not the full conversation URL. This was a format error, not identity evidence. | **OBSERVED — HUMAN.** No ID was recorded in the repository. |
| `BROWSER_ALREADY_ON_EXPECTED_ID` occurred on repeated attempts. | The selected browser already matched the expected ID; the fail-closed guard worked. The human clarified the baseline had been copied from the ARM browser. | **OBSERVED — HUMAN.** No menu invocation occurred on blocked attempts. |
| `BRIDGE.UIA.DISCOVERY.RECOVERY.1A` saw one main document classified OTHER and no browser address/tab controls. | Required browser surface was absent in that UI state. Restore the intended UI manually; do not infer a production code defect from missing controls. | **OBSERVED — EXECUTOR.** Read-only; no UI action. |
| Recovery state check found ARM main, one ARM sidebar row, address bar and selected CDLD browser tab. | Tab title is useful for human state confirmation, but it is not UUID verification. | **OBSERVED — EXECUTOR.** `READY_FOR_M02_D15` only when all visible preconditions were established. |

## 5. Menu verification false negative and correction

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| M02-D.15 returned `MENU_NOT_EXPANDED`, `MenuItemInvoked=false`, while the human saw the menu visually expand. | Source called `Expand()` once and treated ExpandCollapseState as the only postcondition before looking for the menu item. A visually open popup could be rejected by this state check. | **OBSERVED — HUMAN + SOURCE-VERIFIED.** Not evidence that expansion itself failed. |
| M02-D.15B source analysis. | The resolver waited about 350 ms after `Expand()`, checked ExpandCollapseState and stopped before querying the menu item if the state was not Expanded. The global-name lookup did not establish row ownership. | **SOURCE-VERIFIED.** Preserve the single expansion; verify an associated visible-menu postcondition instead of relying on state alone. |
| M02-D.15C timed inspection. | One observation found no popup and reported Collapsed. | **INCONCLUSIVE.** It did not establish whether the human-opened popup could be associated; the later supervised capture did. |
| Ownership relation was unclear. | M02-D.15D captured ancestry `MenuItem → Menu "Chat actions" → groups → ARM Document → panes → ChatGPT window`. | **OBSERVED — HUMAN.** Supports document-scoped association in that tree, not permanent/direct button ownership. |
| M02-D.15D popup capture details. | The first timed observer poll captured the popup after about 460 ms; ExpandCollapseState was `Expanded`, with exactly one visible, enabled `Open on chatgpt.com` MenuItem. | **OBSERVED — HUMAN.** This was a manually opened popup; Codex did not invoke or expand it during the diagnostic. |
| M02-D.15E correction. | Preserve the single `Expand()`. Search within the title-verified ARM document; require one visible enabled invokable item with `Chat actions` Menu ancestry and one popup container. Revalidate row/button/menu before invoking. Accept the visible-menu postcondition if state says Collapsed and record a sanitized mismatch. | **SOURCE-VERIFIED / OFFLINE-QUALIFIED.** Commit `830466f333bf06459c304e17533d536ff1f64dd6`; 127/127 total at that milestone. No ownership inference from global uniqueness alone. |

## 6. Browser address-read failure and bounded recovery

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| `BROWSER_CONVERSATION_NOT_VERIFIED` blocked before menu action. | The browser ID could not be parsed from the current address. A browser tab title such as CDLD is not an immutable ID. | **OBSERVED — HUMAN / SOURCE-VERIFIED.** The exact earlier URL value is unknown. |
| M02-D.15G sanitized launcher result. | Main title verified, browser baseline did not differ from expected, menu item not invoked; reported `ResolverStatus` was empty. Source inspection showed current initialization/assignment should not produce that empty field. | **OBSERVED — HUMAN / UNRESOLVED.** The previous execution path/revision or other cause was not established; see the source hash record below. |
| One diagnostic failed with a missing helper function. | It had not loaded `Bridge.TabGuard.ps1` before calling its functions. This was a diagnostic harness dependency error, not a production Bridge defect. | **SOURCE-VERIFIED.** Fix the harness dependency before any future diagnostic. |
| Prior `ResolverStatus=""` conflicted with inspected launcher initialization and preflight assignment. | The inspected launcher source SHA-256 was `4809284A7484305EC6B4FD9FDE18EECF04A7F0621514E21452D3F4B4FB3DADD8`; it initialized `NOT_RUN` and assigned preflight status. Prior execution provenance could not be established. | **UNRESOLVED.** Do not invent a source-path or revision explanation. |
| Address read initially remained `ORIGIN_ONLY` after focus. | A controlled M02-D.15H-R1 read was `ORIGIN_ONLY` before and immediately after one `SetFocus()`, then `CONVERSATION_URL` around 250 ms and 750 ms. Tab RuntimeId and count were stable; parser succeeded only after the route appeared. | **OBSERVED — HUMAN.** Supports delayed ValuePattern availability, not exact cause of the earlier failed run. |
| M02-D.15I correction. | Shared `Get-BridgeConversationAddress` polls up to 2 seconds at about 125 ms intervals after one focus operation; checks selected tab/count before and after reads; stops immediately on invalid UIA state or tab change. Parseability remains separate from expected UUID equality. | **SOURCE-VERIFIED / OFFLINE-QUALIFIED.** Commit `1fdc957a6dddea9a98b007409759e4a96c1bcd9e`; offline totals advanced to 151/151. No automatic retry of a live invocation. |

## 7. Post-invocation readiness and Cloudflare hypothesis

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| M02-D.15J invoked the menu and returned `BROWSER_DESTINATION_UNVERIFIED`; the human saw a browser tab eventually load ARM. | The result did not establish that navigation failed; page readiness or another UIA/document condition could be pending. | **OBSERVED — HUMAN.** Exact loop state at failure is unavailable. |
| A Cloudflare verification interstitial was visible for several seconds before ARM appeared. | It is a plausible intermediate loading/challenge state only. No source or runtime evidence established it caused the failure. | **HYPOTHESIS.** Bridge must not bypass, automate or interact with challenge verification. |
| Source review of post-invocation loop. | Default overall timeout is 12 seconds (configurable 3–30). Some absent/wrong/pending URL or document checks retry; address helper has a separate 2-second timeout; some explicit UIA failures propagate; generic exceptions while status remains UNVERIFIED are retried; final status can collapse pending causes into `BROWSER_DESTINATION_UNVERIFIED`. | **SOURCE-VERIFIED.** These paths describe behavior, not which path M02-D.15J took. No timeout change was made during this recovery. |

## 8. Browser-document geometry false negative and fix

| Finding or failure | Diagnosis / retained mechanism | Evidence and limit |
|---|---|---|
| M02-D.15L saw ARM main document, selected ARM browser tab, unique address bar, parseable browser route and stable tab, but `Test-ResolveBrowserDocument` returned false. | Phase gate stopped timeout work until the static document predicate was understood. | **OBSERVED — EXECUTOR.** |
| M02-D.15M enumerated two visible ARM-titled `RootWebArea` Documents. | Main rect `(4,53,1881,1051)`; browser rect `(1028,233,1877,1046)`; bar rect `(1256,185,1647,221)`; window rect `(4,53,1880,1050)`. Browser document passed title, visibility, below-bar, right-edge, min/max width checks; only `Left >= addressBar.Left - 60` failed (minimum 1196, actual 1028). | **OBSERVED — EXECUTOR.** Root cause of this observed false negative is verified geometry, not title, absence, duplication or tab instability. |
| M02-D.15N correction. | Require the document's horizontal bounds to contain the address bar: `document.Left <= addressBar.Left` and `document.Right >= addressBar.Right`. Keep exact title, visible `Document`/`RootWebArea`, below-bar and width checks, valid rectangle checks and exactly one qualifying document. Expected UUID and tab checks are unchanged. | **SOURCE-VERIFIED / OFFLINE-QUALIFIED.** Commit `8231d97f1cd276b76d0fd2a70bdc5133995d3277`; 167/167 total. |
| M02-D.15O read-only live check. | One ChatGPT window, one address bar, two visible tabs with one selected ARM tab, address parser success, stable selected-tab snapshot, two visible `RootWebArea` Documents and exactly one qualifying browser document. | **OBSERVED — EXECUTOR.** `LIVE_DOCUMENT_VERIFIED`; no menu action/navigation. |

## 9. Live verification and integrated qualification

| Milestone | Result | Evidence classification and boundary |
|---|---|---|
| M02-D.15P | Sanitized launcher result: `PASS`, `COMPLETE`; main title and different browser baseline verified; menu item invoked; browser identity/document and selected tab verified; tab stable; `BrowserTabTransition=EXISTING_TAB_ACTIVATED`; `VisibleBrowserTabs=2`; resolver `MENU_TO_BROWSER_ID_VERIFIED`; `MainDesktopBound=false`; composer write and chat Send false; delivery `NOT_ASSESSED`. Human observed an existing ARM browser tab become active without manual navigation. | **LIVE-QUALIFIED — CONTROLLED, HUMAN-REPORTED.** One supervised configuration only. No new-tab assumption. No message submission. |
| M02-D.15P.CLOSE | All four Windows PowerShell offline suites passed: Identity 18, TabGuard 20, Resolve 87, SupervisedLauncher 42; **167/167**; `git diff --check` passed. Local doc close commit was `3aa67bdb84c5fd8ca238f6870f1196aef8aaa0ea` (unpublished at that report). | **OFFLINE-QUALIFIED.** This later documentation consolidation is a separate repository change. |

## Mechanisms to preserve

1. Identify exactly one ChatGPT window by the supported process/window check; stop on ambiguity.
2. Separate main Desktop RootWebArea from the browser RootWebArea using region/geometry plus exact visible title; neither title nor region is immutable identity.
3. Find the unique sidebar ListItem and descendant `Chat actions` button. Expand exactly once through ExpandCollapsePattern.
4. Associate `Open on chatgpt.com` only through the verified document subtree and `Chat actions` Menu ancestry; require unique visible/enabled/invokable controls and fresh target/menu validation immediately before invocation.
5. Require a different pre-invocation browser ID; after human `OPEN`, invoke once. Never automatically retry a failed live run.
6. Focus the unique browser address bar once per address-reading operation. Use the bounded reader and fail on tab RuntimeId/count change or invalid controls.
7. Compare the parsed browser conversation UUID with the independently supplied expected UUID. Then require one qualifying browser document and recheck selected-tab/address stability.
8. Report the observed transition (`NEW_TAB`, `EXISTING_TAB_ACTIVATED`, `REUSED_SELECTED_TAB`, or related fail-closed status); never assume a new tab.

## Remaining limits and gates

- `MainDesktopBound=false` remains mandatory. The observed result is a controlled browser identity correlation, not durable main-panel identity binding.
- Duplicate/renamed/hidden targets, multiple Desktop windows, app/session lifecycle changes, stale controls, locked sessions, and mid-operation focus/tab races remain unqualified.
- Cloudflare was reported in one run but was not established as the cause. No challenge detection or bypass is implemented.
- No message insertion or submission is implemented or authorized. There is no delivery acknowledgement, idempotency ledger, duplicate prevention or ambiguous-send recovery.
- No unattended operation, repeated-cycle reliability, universal Windows/app-version compatibility, or production release is qualified.
- Never place private UUIDs, conversation URLs, chat content, credentials, cookies or ephemeral RuntimeIds in documentation, command lines, environment variables, logs or tests.
