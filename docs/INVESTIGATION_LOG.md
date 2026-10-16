# Investigation log

**Evidence date:** 2026-10-15. **Evidence source:** human-run Windows PowerShell console output and visual confirmations, plus a handover from earlier investigation. Items below record what was *observed or reported*; no repository-hosted automatic test suite exists.

## Earlier handover tests (01-08)

| Test | Reported result | Important qualification |
|---|---|---|
| 01. Detect Desktop window | PASS | ChatGPT process/top-level window accessible through UIA |
| 02. Inspect accessibility tree | PASS | Document, Edit, Button, ListItem, Group, MenuBar observed |
| 03. Find active composer | PASS | Visible, enabled Edit was correct; offscreen same-named element was wrong |
| 04. Insert text | PASS | Human observed UIA ValuePattern.SetValue in composer |
| 05. Invoke Send | PASS, human-confirmed | Harmless message sent in already-open conversation; no server-side acknowledgement qualification |
| 06. Discover pinned conversations | PASS | Sidebar accessible via UIA |
| 07. Inspect navigation descendants | PASS | ListItem had child Invoke-capable Button |
| 08. Switch pinned conversation | PASS, human-confirmed | Title-based target worked; no immutable ID verification |

These were proof-of-concept tests, not unattended reliability or production routing tests.

## M01 — conversation identity investigations

1. **Sandbox discovery:** exact match for a proposed disposable test title returned 0. Do not infer it existed or that navigation failed.
2. **Window/tree enumeration:** an existing ChatGPT Desktop window exposed approximately 1,077 elements and 30 ListItems; three known sidebar titles were discoverable. Five partial `Bridge|Sandbox` matches were offscreen non-navigation elements.
3. **Sidebar controls:** for each known title, a ListItem and sidebar Button existed. The active title also appeared separately as a Document/header Button. This demonstrated why names alone are ambiguous.
4. **Sidebar metadata:** AutomationId, HelpText, ItemStatus, ItemType, AccessKey and LabeledBy were blank for three inspected sidebar buttons. Class names largely described shared UI styling. RuntimeIds differed between elements but are **session-scoped UIA identities, not validated durable conversation IDs**.
5. **Container descendants:** an inspected conversation ListItem had four descendants: an Invoke/ScrollItem Button, an ExpandCollapse/ScrollItem Button with a `radix-...` AutomationId, an Invoke/ScrollItem Group and another Invoke/ScrollItem Button. No hyperlink/durable conversation ID was observed.
6. **Built-in browser path:** the Desktop conversation menu displayed **Open on chatgpt.com**. It opened a browser surface inside ChatGPT Desktop. Manually opening the chosen web conversation revealed a `https://chatgpt.com/c/<id>` URL.
7. **Address-control discovery:** with the embedded browser open, a UIA ComboBox named **Search or enter a URL** was discovered. It exposed ValuePattern, TextPattern, ExpandCollapsePattern and ScrollItemPattern, with 0 descendants.
8. **Unfocused address bar:** both ValuePattern and TextPattern returned only `chatgpt.com` (length 11); no conversation ID was present.
9. **Focused address bar:** invoking `SetFocus()` on that ComboBox and reading its ValuePattern and TextPattern produced 58-character values containing a conversation-path identifier (both True).
10. **Known-ID comparison:** extracting the ID from the now-accessible URL and comparing it with the manually captured identifier for the chosen browser conversation returned: `URLDetected=True`, `MatchesKnownCDLD=True`, `URLLength=58`.

**Result:** M01-E focused extraction and M01-F comparison passed as bounded, human-run diagnostics. This does **not** bind the embedded browser to the main ChatGPT Desktop active conversation or prove persistence across restarts.

## Investigation mistakes and corrections

- Avoid selecting by `Name` alone: there were multiple `Ask ChatGPT` controls; choose visible enabled Edit.
- Sidebar ListItem did not expose InvokePattern itself; invoke an identified child Button.
- Avoid malformed PowerShell pipelines directly after `foreach`; two attempts generated `EmptyPipeElement` parser errors and made no UI change.
- Do not name a result array `$matches`: PowerShell's automatic `$Matches` variable is overwritten by `-match`. One apparent URL count was invalid until re-tested with an independent variable and regex Match.
- A metadata command originally labeled `ToString()` as RuntimeId; it was corrected using `GetRuntimeId()`.
- Address-bar ValuePattern and TextPattern must be read independently; treating one as a fallback concealed evidence initially.
- Initial exploratory PowerShell multi-line paste and Point-constructor attempts caused errors. Prefer bounded single-line interactive commands, properly validated before use.

## Environment observed in handover

- Windows desktop application: ChatGPT.exe; package reported as OpenAI.Codex_26.1007.2314.0_x64.
- WebView2 component reported as 155.0.4283.45.
- Win32 process ID and window handles varied by session and must never be hardcoded.
- No CDP remote-debugging arguments were found in the inspected processes. Do not generalize this into a universal assertion about all available interfaces.

## Unresolved

Automatic ID-to-sidebar binding, duplicate titles, multiple windows, selection/read race, application restarts, lifecycle robustness, locked Windows session, safe delivery acknowledgement, idempotency, unattended reliability, and supported integration/terms status.

## M01-H through M01-J — subsequent human-run diagnostics, 2026-10-16

1. **Navigation experiment initial attempts:** UIA `ValuePattern.SetValue()` populated a target conversation URL, but did not itself navigate. Focus moved from the address ComboBox to an autocomplete ListItem after approximately 300ms. Attempts requiring the ComboBox to retain focus correctly stopped before Enter.
2. **Focused suggestion:** A ListItem adjacent to the address bar exposed a name containing the expected URL and supported InvokePattern/SelectionItemPattern/ScrollItemPattern. Invoking this ListItem through InvokePattern did **not** navigate; the embedded browser remained at home.
3. **Foreground activation:** `SetForegroundWindow()` successfully brought ChatGPT Desktop to the foreground. A later controlled attempt inserted the target URL, verified the autocomplete ListItem and stable focus, and sent Enter automatically. The human visually confirmed that the embedded browser then loaded the expected conversation without manual intervention. **M01-H experimental navigation PASS**, not production qualification.
4. **Independent post-navigation identity check:** The focused browser address bar yielded a 58-character conversation URL; extracted identifier matched expected ID; the geometry check found one browser-editor candidate. **M01-I URL identity check PASS.**
5. **Editor/document ancestry:** The detected enabled, focusable browser editor had a Document ancestor at depth 23 with `AutomationId=RootWebArea`; its document name contained the human-known conversation title; ValuePattern and TextPattern supported. **M01-J structural discovery PASS.**
6. **Remaining:** Browser route is **not** immutable binding to the separate main Desktop conversation. UIA and SendKeys focus races remain; no automated qualification has established reliable navigation across multiple app versions or lifecycles.

## M02-A prototype source, 2026-10-16

Owner separately approved navigation-only implementation. Repository now contains `src/Bridge.Navigate.ps1`, `src/Bridge.Identity.ps1`, and `tests/Identity.Offline.Tests.ps1`. These are **committed source and proposed offline checks**, not a claim that Windows runtime or offline tests have been executed. Message insertion/submission remains disabled and unapproved.

## M02-A through M02-B human qualification results (2026-10-16)

- M02-A offline Windows PowerShell tests: `PASS`, 18 assertions. Local clone branch `main`, clean.
- M02-A read-only browser inspection when CDLD open: `VERIFIED_BROWSER_ROUTE`, `NavigationAttempted=false`, `UrlIdentityVerified=true`, `EditorVerified=true`.
- M02-A read-only browser inspection from ChatGPT home: `IDENTITY_MISMATCH`, no navigation. Controlled opt-in navigation then opened CDLD and reported `VERIFIED_BROWSER_ROUTE`, `NavigationAttempted=true`, URL/editor both verified. **Controlled happy path only.**
- M02-B sidebar ListItems for ARM, Statement Strutcture Lab and CDLD: all exposed `SelectionItemPattern=UNSUPPORTED`; visible editors' `RootWebArea` document titles could be inspected. Two independent regions were observed: main Desktop conversation `Artifact Relay Manager` and embedded browser `CDLD`; geometry is not durable binding.
- Browser in a ChatGPT Desktop window supports separate tabs, observed via two visible `TabItem` elements. One selected at a time. Selected new blank tab: one address bar, address EMPTY. Selected CDLD tab: one bar, conversation-shaped URL length 58. With blank tab active, M02-A read-only identity test rejected CDLD as `IDENTITY_MISMATCH`, no navigation.
- **Unresolved:** multiple independent Desktop-window discovery, sidebar selection's immutable ID, focus races, and keyboard-tab stability across updates.

## M02-C source update (2026-10-16)

Added a read-only selected-tab stability gate to the navigation-only prototype. It rejects ambiguity and changed ephemeral selected-tab RuntimeId/tab count across navigation. Added negative offline snapshot tests. **Source committed; offline tests and Windows live qualification have not been reported by the human.**

## M02-C controlled qualification and M02-D manual probes (2026-10-16)

- M02-C user reported 18/18 identity and 20/20 tab-guard offline assertions PASS.
- M02-C live single-tab wrong-ID inspection returned `IDENTITY_MISMATCH`, `NavigationAttempted=false`; actual visible tab count 1 because the second tab had been closed.
- M02-C single-tab CDLD positive inspection returned `VERIFIED_BROWSER_ROUTE`, `SelectedTabVerified=true`, `TabSelectionStable=true`, `VisibleBrowserTabs=1`.
- M02-C controlled home-to-CDLD navigation returned `VERIFIED_BROWSER_ROUTE`, `NavigationAttempted=true`, stable tab and URL/editor identity. Two-tab blank-selected inspection returned `IDENTITY_MISMATCH`, `VisibleBrowserTabs=2`, no navigation.
- M02-D in ARM: manual `Open on chatgpt.com` exposed a selected embedded browser conversation URL of length 58 and both ARM main/browser documents. User captured ARM ID privately in PowerShell, then opened CDLD in browser while ARM remained the main document. Browser identity check against ARM baseline rejected it with `IDENTITY_MISMATCH`.
- User manually reopened ARM via its sidebar menu: browser identity matched private ARM baseline, two tabs visible.
- UIA discovery of the ARM sidebar `Chat actions` control showed ExpandCollapsePattern supported; automated `Expand()` produced `Expanded` and exactly one visible `Open on chatgpt.com` MenuItem. InvokePattern for that unique menu item was exercised with `MENU_ITEM_INVOKED`, followed by a browser ID check matching ARM baseline. The menu-item invocation experiment reports no messaging. Whether it created a new tab or activated an existing tab was not conclusively stated by the user.
- **Important:** This is a controlled title-anchored menu-to-ID correlation, not a general durable main-Desktop identity binding.

## M02-D.13 repository change (2026-10-16)

Added `src/Bridge.Resolve.ps1` plus `src/Bridge.Resolve.Helpers.ps1` and `tests/Resolve.Offline.Tests.ps1`. The default is preflight only; `-OpenInBrowser` explicitly invokes the sidebar menu item. The script verifies main document/title, unique sidebar action and menu item, expected browser conversation ID, browser document, tab identity, and tab-transition category. It cannot submit chat messages. **No Windows offline or runtime test results have yet been received for M02-D.13.**

## M02-D.13 Windows offline qualification — human report (2026-10-16)

After fast-forwarding local `main` from `0454215` to `cfbf37f`, the human ran all three shipped offline test scripts from the repository root. Actual reported JSON:

| Suite | Reported result | Assertions |
|---|---|---:|
| M02-A `Identity.Offline.Tests.ps1` | `PASS` | 18 |
| M02-C `TabGuard.Offline.Tests.ps1` | `PASS` | 20 |
| M02-D.13 `Resolve.Offline.Tests.ps1` | `PASS` | 33 |
| **Total** | **3 suites PASS** | **71 / 71** |

Evidence level: human-provided Windows PowerShell console output, not independently rerun in this repository. These are syntax/pure-helper and source-guard checks, **not** a live execution of the integrated M02-D.13 resolver.

**Next unresolved test:** M02-D.13 live **preflight only** (`Bridge.Resolve.ps1` without `-OpenInBrowser`). After that passes, a separately bounded supervised `-OpenInBrowser` test can qualify the integrated menu-to-browser-ID verification sequence. Both are **PENDING**. No message submission is approved or implemented.

## BRIDGE.CODEX.BASELINE.1B launcher qualification (2026-10-16)

Added `src/Bridge.Resolve.Supervised.ps1` as an interactive in-process wrapper, plus offline source/syntax guards. The independently verified UUID is accepted only through `Read-Host -AsSecureString`, validated in memory, passed directly to `Bridge.Resolve.ps1`, and omitted from sanitized JSON. Preflight-only and separately confirmed invocation modes are available. Invocation mode requires a unique existing selected browser conversation different from the expected ID, confirms again after the operator types `OPEN`, and makes one live resolver call. The existing resolver was strengthened to fail closed when its browser baseline is missing or unreadable.

Offline Windows PowerShell 5.1 evidence: `SupervisedLauncher.Offline.Tests.ps1` PASS (35 assertions); Identity PASS (18); TabGuard PASS (20); Resolve PASS (34); **107/107 assertions PASS across four suites**. `git diff --check` passed. The launcher has not been run interactively, and no UIA or menu invocation was performed. Await Architect review before BRIDGE.M02-D.15.

## Evidence reconciliation: prior versus integrated behavior

- M02-D.6 direct menu-name search returned `Matches=0` when menu visibility/focus was not secured; this was **inconclusive**, not proof that UIA cannot find the menu item.
- M02-D.7 delayed inspection with sidebar three-dot menu open returned one enabled visible `ControlType.MenuItem` named `Open on chatgpt.com`, `HasInvoke=true`.
- M02-D.8 the target sidebar `ListItem` was unique; it contained an invoke-capable title button, a `Chat actions` button without InvokePattern, and an invoke-capable `Unpin chat` control. **Unpin was not invoked.**
- M02-D.9 `Chat actions` exposed ExpandCollapsePattern and ScrollItemPattern, no InvokePattern.
- M02-D.10 UIA `Expand()` moved `Collapsed` to `Expanded`; exactly one `Open on chatgpt.com` menu item appeared; navigation was not attempted.
- M02-D.11 unique matching menu item's InvokePattern was exercised; diagnostic returned `MENU_ITEM_INVOKED`. That alone was **not** proof of browser destination identity.
- M02-D.12 separate inspection of selected embedded browser tab reported `VERIFIED_BROWSER_ROUTE`, matching the independently captured expected conversation ID, stable selected tab, and two visible tabs. It did **not** indicate whether a new tab was created by M02-D.11.
- M02-D.13 source integrates this chain but its live operation is **not** yet observed. Its `MainDesktopBound=false` designation remains correct.

## M02-D.15D popup association and M02-D.15E correction (2026-10-16)

- Human manually opened the ARM `Chat actions` popup; a read-only observer captured it after 460 ms. Exactly one ChatGPT window, ARM sidebar row, and ARM `Chat actions` button were present. The target button reported `Expanded`, and exactly one visible enabled `Open on chatgpt.com` MenuItem was found.
- Captured ancestry was `MenuItem → Menu "Chat actions" → Group → Group → Document "Artifact Relay Manager" → panes → ChatGPT window`. This establishes a document-scoped association in that observed UIA tree. It does **not** prove a permanent or direct button-to-popup ownership property; RuntimeIds remain ephemeral.
- M02-D.15E keeps the single existing `Expand()` operation, then finds the menu candidate only within the verified ARM document and requires the `Chat actions` Menu ancestry. It requires one popup container and one visible, enabled, InvokePattern-capable item. The fresh document, target row/button RuntimeIds, and associated item are rechecked immediately before invocation; missing target RuntimeIds fail closed.
- A verified visible-menu postcondition is accepted if ExpandCollapseState does not report `Expanded`; `MenuStateMismatch` records this sanitized discrepancy. Missing, duplicate, stale, unrelated-document, wrong-ancestry, disabled, offscreen, or non-invokable controls fail closed.
- Offline Windows PowerShell 5.1 results: Identity 18/18, TabGuard 20/20, Resolve 54/54, SupervisedLauncher 35/35; **127/127 assertions PASS**. These are parser, helper, and source-guard checks. No live expansion or invocation was performed for M02-D.15E.

## M02-D.15H-R1 address timing and M02-D.15I correction (2026-10-16)

- One supervised read-only UIA experiment observed `ORIGIN_ONLY` before focus and immediately after the one `SetFocus()` call, then `CONVERSATION_URL` at approximately 250 ms and 750 ms. The UUID parser failed on the first two samples and succeeded on the latter two. The selected browser tab RuntimeId and visible tab count remained stable; no navigation or menu action occurred.
- This supports delayed ValuePattern availability as the cause of intermittent baseline parsing failure. The failed historical run's exact post-focus value remains unknown.
- M02-D.15I replaces one-shot post-focus reads in the supervised launcher and integrated resolver with shared `Get-BridgeConversationAddress`: it polls for up to 2 seconds at 125 ms intervals, reads only in memory, checks the same selected tab and tab count before and after every read, returns as soon as the existing UUID parser succeeds, and stops immediately on tab/UIA/address-control failure. The caller performs one `SetFocus()` per address-reading operation; the polling helper never changes focus.
- A timeout returns sanitized `BROWSER_CONVERSATION_URL_TIMEOUT`; expected-ID comparison remains a separate mandatory check. No menu invocation can follow a failed baseline. Windows PowerShell 5.1 offline results: Identity 18/18, TabGuard 20/20, Resolve 71/71, SupervisedLauncher 42/42; **151/151 assertions PASS**, retaining the prior 127 and adding 24 address-read regression assertions. The modified live path was not exercised.

## M02-D.15M/N browser document geometry correction (2026-10-16)

- M02-D.15M read-only UIA inspection found one ChatGPT window, one ARM main document, one address bar, and two visible browser tabs with exactly one selected ARM tab. The bounded address reader parsed a conversation URL and the selected-tab snapshot stayed stable.
- Two visible `RootWebArea` Documents had the ARM title. The main document rectangle was `(4,53,1881,1051)`; the embedded-browser document was `(1028,233,1877,1046)`. The address-bar rectangle was `(1256,185,1647,221)` and the window rectangle was `(4,53,1880,1050)`.
- The embedded document passed the existing title, visibility, below-address-bar, right-edge, minimum-width and maximum-width checks, but failed the left-edge tolerance (`document.Left >= addressBar.Left - 60`). Its observed left edge was 228 px left of the address bar. No document passed the complete predicate, establishing a geometry false negative in the observed layout.
- M02-D.15N replaces that left-edge tolerance with horizontal containment: the document's left edge must be at or left of the address bar's left edge, and its right edge at or right of the address bar's right edge. The below-bar and width safeguards remain. Exact title, visible `Document`/`RootWebArea`, and exactly-one qualifying document checks remain mandatory. Expected UUID and selected-tab checks are unchanged.
- The geometry and candidate checks are pure offline helpers. Synthetic regressions cover the observed browser and main-document rectangles, left extension, failed containment, vertical placement, title, visibility, duplicate qualifying documents, and missing/empty/inconsistent/non-finite geometry. Offline Windows PowerShell 5.1 results: Identity 18/18, TabGuard 20/20, Resolve 87/87, SupervisedLauncher 42/42; **167/167 assertions PASS**, preserving all 151 prior assertions. No live UIA run was performed for M02-D.15N.
