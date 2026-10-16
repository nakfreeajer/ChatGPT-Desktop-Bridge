# Architecture and current control flow

## Boundary

ChatGPT Desktop Bridge is an experimental Windows PowerShell 5.1 / Windows UI Automation component. Its current code can inspect a browser route and, through a human-confirmed resolver path, invoke the Desktop sidebar action that opens the selected conversation in the embedded browser and verify that browser destination.

It is **not** an Orchestrator, a messaging integration, or a production transport. No current source writes chat content or invokes the chat Send control. `MainDesktopBound=false` remains mandatory: main Desktop and embedded browser are separate surfaces, and current checks do not establish a durable immutable ID binding for the main conversation.

## Components

| Component | Current responsibility |
|---|---|
| `src/Bridge.Identity.ps1` | Pure UUID, URL, home-page and suggestion-target helpers. |
| `src/Bridge.TabGuard.ps1` | Find exactly one selected browser TabItem near the address bar; use RuntimeId and visible-tab count as ephemeral within-run stability evidence. |
| `src/Bridge.Navigate.ps1` | Earlier experimental browser-only navigation prototype. Its optional path changes the URL and sends Enter to a verified autocomplete suggestion; global keyboard focus race remains. It does not write or submit a chat message. |
| `src/Bridge.Resolve.Helpers.ps1` | Pure transition, menu snapshot, address polling and document-geometry helpers. |
| `src/Bridge.Resolve.ps1` | Preflight by default; explicit `-OpenInBrowser` invokes one sidebar menu item and verifies the resulting browser route/document/tab. |
| `src/Bridge.Resolve.Supervised.ps1` | Interactive secure wrapper: hidden expected-ID input, read-only preflight, selected-browser mismatch check, literal human `OPEN`, one in-process resolver invocation, sanitized result. |

## Resolver sequence

1. Require one ChatGPT process window; identify one visible main `RootWebArea` Document with the exact requested title and one visible matching sidebar ListItem with one enabled `Chat actions` button. Duplicate/ambiguous targets fail closed.
2. Without `-OpenInBrowser`, return `PREFLIGHT_PASS`; no menu item is invoked.
3. For the explicit path, read the currently selected browser conversation and retain a within-operation tab RuntimeId/count snapshot. Reject a baseline already matching the supplied expected UUID.
4. Reconfirm the main document and sidebar target. Call `ExpandCollapsePattern.Expand()` once. Locate `Open on chatgpt.com` only within the verified document and require ancestry through a `Menu` named `Chat actions`; require one visible, enabled, invokable item and one popup container. Revalidate the row, button and item immediately before the one invocation.
5. After invocation, inspect the selected embedded-browser tab and address. Focus the unique address control once per read operation; `Get-BridgeConversationAddress` polls ValuePattern for up to 2 seconds at about 125 ms intervals, checking the selected-tab RuntimeId/count before and after each read. Compare the parsed UUID with the independently supplied expected UUID; parseability alone is insufficient.
6. Require exactly one visible browser `RootWebArea` Document with exact title `Artifact Relay Manager`, horizontal bounds containing the address-bar bounds, below-address-bar placement and the existing width bounds. Invalid/empty rectangles fail; multiple qualifying documents fail.
7. Recheck selected-tab/address stability, report the observed transition (`NEW_TAB`, `EXISTING_TAB_ACTIVATED`, `REUSED_SELECTED_TAB`, or a fail-closed status), and return sanitized JSON. The resolver's post-invocation readiness loop has a default 12-second timeout (allowed 3–30 seconds); it does not identify or bypass Cloudflare.

The menu ancestry proves a document-scoped popup association in the observed UIA tree, not a permanent/direct ownership link from a particular sidebar button to a popup across app lifetimes. Geometry helps separate the main and embedded browser documents; it is not a standalone identity proof.

## Qualification state

- M02-D.15P is **PASS_CONTROLLED_INTEGRATED** for one human-supervised run. The human-reported transition was `EXISTING_TAB_ACTIVATED` with two visible tabs; no new-tab behavior is assumed.
- M02-D.15O separately verified the corrected browser-document predicate with read-only UIA.
- Offline suites pass 167/167 assertions. Offline tests check helpers, syntax and source guards; they do not establish live reliability.
- Multiple windows, duplicate/renamed/hidden conversations, lifecycle changes and focus/tab races remain unqualified.

## Future delivery boundary

The long-term goal may include explicitly authorized message insertion and submission by a separate, approved design. Those capabilities are **not implemented or authorized** by the current Bridge. Any future interface must revalidate destination identity close to the action, distinguish UI action from server acknowledgement, carry caller authorization, define request IDs/idempotency, and fail closed on uncertainty. No blind retry after an ambiguous send is acceptable.

See [security and limitations](SECURITY_AND_LIMITATIONS.md), [verified findings](VERIFIED_FINDINGS.md), and the [failure/recovery register](FAILURE_AND_RECOVERY_REGISTER.md).
