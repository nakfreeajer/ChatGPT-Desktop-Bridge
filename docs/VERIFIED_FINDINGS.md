# Evidence and verified findings

**Evidence grading:** “Observed” means user-provided command output or visual confirmation on 2026-10-15; “handover” means earlier session evidence described in the uploaded handover; “unverified” means not established by either. The repository's documentation does not independently execute tests.

| Finding | Evidence | Boundary |
|---|---|---|
| UIA exposed top-level ChatGPT window and web-view accessibility tree | Handover + observed later enumerations | Live session only; PID/window handle ephemeral |
| Sidebar ListItem/child Button representation supports invoking navigation | Handover, observed metadata | No durable target ID found |
| Visible Edit composer supports insertion; Send Button InvokePattern can submit | Handover, human-confirmed | Already-open destination only; no production-safe routing |
| Three known pinned conversations appeared as ListItem and Button, with active title elsewhere too | Observed | Title matching alone ambiguous |
| Sidebar Button AutomationId/HelpText/ItemStatus/ItemType/AccessKey/LabeledBy were empty | Observed | Applies to three inspected buttons, not all versions |
| UIA RuntimeId values differed | Observed | Not proven stable across controls, navigation, restart, or updates |
| Embedded browser could show a conversation-specific `/c/<uuid-style-id>` path | Observed manually | Opening web view can be independent of main Desktop conversation |
| Embedded address ComboBox supported ValuePattern and TextPattern | Observed | Not proof of address value completeness until focused |
| Address value while unfocused was `chatgpt.com` (11 chars) in both patterns | Observed | Specific inspected browser state |
| Address value after UIA SetFocus was 58 chars, both patterns matching conversation URL | Observed | Focus changes UI state; not a permanently readable background value |
| Extracted browser ID matched previously manually captured ID | Observed | Verifies known browser conversation only; not sidebar identity binding |


## Subsequent human-observed controlled findings — 2026-10-16

These observations extend the 2026-10-15 initial findings above; their PASS classifications apply **only to the specific human-run scenario**, not to reliability across installations, app versions, or unattended operation.

| Milestone / test | Human-observed evidence | Qualification boundary |
|---|---|---|
| M01-H–J | Browser autocomplete required a focused suggestion ListItem plus verified foreground before Enter; post-navigation expected URL and `RootWebArea` editor ancestry matched | Browser-only navigation, not immutable main Desktop identity |
| M02-A | 18/18 offline tests; read-only home mismatch rejected; opt-in navigation returned `NavigationAttempted=true`, expected URL and editor verified | Single controlled browser navigation happy path |
| M02-B | Sidebar conversation ListItems did not expose SelectionItemPattern; two separately named `RootWebArea` documents could appear in one UIA top-level window | Document titles/geometries identify regions, not immutable IDs |
| M02-B | Embedded browser supported two TabItem controls with exactly one selected; selected blank tab yielded empty address, selected known conversation yielded 58-character URL | Selected-tab-to-address correlation under observed UI |
| M02-C | 20/20 offline tests; single-tab positive inspection and opt-in navigation PASS; selected blank second tab returned ID mismatch without navigation and reported `VisibleBrowserTabs=2` | No deliberate mid-navigation tab-switch race qualification |
| M02-D.1–5 | Desktop sidebar `Open on chatgpt.com` manual action produced a browser URL; private baseline ID matched on recovery after deliberate browser mismatch | Manual title-anchored identity recovery, not general permanent binding |
| M02-D.6–10 | First query without assured menu visibility found 0; delayed query found 1 visible enabled Invoke-capable menu item; target `Chat actions` had ExpandCollapsePattern; opening menu exposed unique menu item | Menu discovery and expansion only |
| M02-D.11–12 | UIA invoked unique `Open on chatgpt.com` MenuItem; separate browser inspection verified expected saved ID and stable selected tab, with two tabs visible | Menu invocation and subsequent ID check were separate experiments |
| M02-D.13 offline | Windows PowerShell: `Identity` 18/18 PASS; `TabGuard` 20/20 PASS; `Resolve` 33/33 PASS; **71/71 total** | Script syntax/pure helper/source guards only; integrated live preflight/invocation not yet run |

### Current outstanding verification

- Integrated `Bridge.Resolve.ps1` live preflight and explicit `-OpenInBrowser` runtime outcomes: **PENDING**.
- Linking the main Desktop conversation to a durable immutable ID independently of a mutable sidebar title: **UNRESOLVED**.
- Multiple-window routing, duplicate titles, renames, app restarts/updates, selected-tab focus races and lifecycle failures: **UNQUALIFIED**.
- Safe delivery/acknowledgement/deduplication: **NOT IMPLEMENTED**. No messages were submitted in M02-A–D qualification.

## Confidence rules

- **PASS — experimental:** A specific human-run diagnostic produced the expected result in the observed session.
- **NOT FOUND:** A property or identifier was not exposed in the inspected controls; this is not proof no other possible identity mechanism exists.
- **BLOCKED:** Production routing cannot proceed without destination verification.
- **UNVERIFIED:** Neither a successful nor failed qualification was performed.

## Explicitly not verified

- That the main Desktop conversation and embedded browser conversation are the same.
- That the embedded browser can always be opened, controlled, or trusted unattended.
- That a title, CSS class, UIA RuntimeId, radial-generated AutomationId, or inferred sidebar order is a durable conversation key.
- That a conversation-specific URL remains stable across session termination, app restart, rename, or platform changes; the format and one same-session known-ID comparison were demonstrated, not lifecycle persistence.
- That a UIA Send invocation proves receipt by ChatGPT services or ensures no duplicates.
- That using UIA for this purpose is officially supported or permitted under every relevant application term.

## Privacy in evidence

The actual manually observed conversation identifier, user-specific project names, full UI content, message bodies, and personal data are deliberately omitted from public source-controlled logs. Use placeholders in reproducibility examples.
