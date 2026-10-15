# Architecture and experimental browser-route prototype

## Design goal

A minimal local Windows UI Automation transport boundary for existing ChatGPT Desktop conversations. No CDP port, OpenAI API, Drive polling, autonomous AI decisions, or embedded Orchestrator.

## Logical boundary

~~~text
External caller / Orchestrator
  |  Authorized request (requestId, expectedConversationId, payload)
  v
Desktop Bridge — local, deterministic transport component
  |  (A) Discover one Desktop window / fail if ambiguous
  |  (B) Resolve candidate conversation UI element
  |  (C) VERIFY: bind that element / selected Desktop conversation to expected durable ID
  |      using separately qualified evidence (NOT AVAILABLE YET)
  |  (D) Check current active target immediately before delivery
  |  (E) Insert authorized content and invoke Send (future controlled mode)
  |  (F) Observe outcome without inventing server acknowledgement
  v
Deterministic result returned to caller
~~~

## Observed technology surfaces

- **Main ChatGPT Desktop UI:** window and sidebar elements accessible through Windows UIA. Sidebar ListItem contains Invoke-capable navigation button. Text composer is a visible, enabled Edit.
- **Embedded browser opened via Desktop conversation menu:** browser URL is represented by a UIA ComboBox named `Search or enter a URL`.
- **Address-bar focus behavior:** browser URL was domain-only when unfocused; after UIA SetFocus, ValuePattern and TextPattern yielded full conversation URL for the browser-selected conversation.

**Critical unresolved gap:** The embedded browser and the main Desktop interface can show different conversations. The extracted browser ID is **not automatically associated with the main Desktop sidebar element**. Manual URL capture and title matching must not be promoted to production identity assurance.

## Identity tiers

1. **Visible title:** informational; duplicates and renames allowed.
2. **UIA RuntimeId:** an accessibility-control lifetime identifier, not a durable chat identity.
3. **Browser conversation ID:** promising durable reference candidate in `chatgpt.com/c/<id>`; stability across restarts and automatic binding not yet qualified.
4. **Trusted binding:** future evidence that chosen Desktop navigation target and expected conversation ID refer to the same conversation. **Unimplemented.**

## Future interface sketch — design only

Input: `requestId`, `expectedConversationId`, operation, payload, caller-authorization evidence and optional timeout.

Output: `NOT_FOUND`, `AMBIGUOUS_WINDOW`, `AMBIGUOUS_DESTINATION`, `IDENTITY_UNVERIFIED`, `AUTHORIZATION_REQUIRED`, `NOT_ATTEMPTED`, `UI_ACTION_ATTEMPTED_UNCONFIRMED`, or `CONFIRMED_BY_DEFINED_EVIDENCE` (only after that level of evidence exists). These are proposed names, not implemented APIs.

No blind resubmission after `UI_ACTION_ATTEMPTED_UNCONFIRMED`; caller must reconcile state. Idempotency requires durable request tracking outside arbitrary UI retries.

## Scope enforcement

Authorization and workflow decisions remain with the external Orchestrator. Artifact Relay Manager remains responsible for artifact monitoring. Desktop Bridge only performs verified, explicitly authorized transport actions and returns honest status.

## Implemented prototype boundary — M02-A (not yet runtime-qualified)

`src/Bridge.Navigate.ps1` implements a **browser-only** route-checking experiment using Windows PowerShell 5.1 and UIA. The script defaults to inspection; `-Navigate -AcceptKeyboardRisk` is required to insert an expected URL and use Enter on a verified focused Chromium autocomplete ListItem. That combination is not race-free: focus can change immediately before global SendKeys.

The browser route must start from home if not already on the target. Source only: no live Windows qualification was conducted when committing this implementation. After navigation, the script reacquires the address control, focuses it, verifies `https://chatgpt.com/c/<expected-id>`, and requires exactly one plausible enabled editor beneath the browser address region with a RootWebArea Document ancestor. Geometry is supporting evidence only.

The return value is one JSON object with `Status`, `Stage`, `NavigationAttempted`, `UrlIdentityVerified`, `EditorVerified`, `MainDesktopBound=false`, `ComposerWriteAttempted=false`, `ChatSendButtonInvoked=false` and `MessageDeliveryStatus=NOT_ASSESSED`. No chat composer is written to; no Send button is exposed or invoked.

This does **not** implement the previously proposed automatic binding from the main Desktop sidebar selection to the browser URL. Browser-only and main Desktop modes must not be conflated.

## Release gate

No unattended message submission until automatic identity binding, race handling, duplicate prevention, lifecycle behavior, and controlled delivery tests are approved and demonstrated.

## M02-C selected-tab safety gate (source committed; not Windows qualified)

Observed in M02-B: the embedded browser exposes visible `TabItem` controls and `SelectionItemPattern.IsSelected` can identify exactly one active tab. With two tabs open, the selected blank tab exposed an empty address, while selecting the CDLD tab exposed a conversation-shaped address of length 58. Inspection-only identity matching rejected the blank tab.

M02-C requires one selected tab near the embedded-browser address-bar region and uses that selected tab's ephemeral UIA RuntimeId plus visible tab count as a within-run snapshot. Re-query at every critical navigation boundary. It does **not** persist that ID or equate a browser tab with the main Desktop conversation.

After any ambiguous selection, vanished tab, altered tab count, unsupported selection pattern, or changed RuntimeId, the operation returns a fail-closed status. Global `SendKeys('{ENTER}')` still has a residual focus race even with these checks. The selected-tab guard does not solve durable conversation binding, session/window discovery, or server-confirmed message delivery.

## M02-D.13 integration experiment — menu-to-ID, not permanent binding

The owner observed the ARM sidebar three-dot menu exposing a unique `Open on chatgpt.com` MenuItem with InvokePattern, and its owning `Chat actions` button exposing ExpandCollapsePattern. Invoking the UIA menu action was followed by a successful check that the selected embedded-browser URL matched a previously captured ARM ID.

`Bridge.Resolve.ps1` encodes a bounded version with explicit `-OpenInBrowser` opt-in. It first checks the large main `RootWebArea` document has the exact expected display title and there is exactly one visible sidebar ListItem with that exact title and one `Chat actions` control. It can stop there without mutation. When opted in, it takes an optional baseline of the selected embedded-browser tab and ID, refuses an already-matching baseline, expands the correct menu, invokes the unique menu item, and verifies a selected browser tab's expected URL ID, document title/region, and stable tab selection.

A browser may add a tab, reuse the selected tab, activate an existing tab, or open for the first time. The script reports the observed transition rather than assuming a particular case. The resulting `MENU_TO_BROWSER_ID_VERIFIED` is only a controlled correlation for the supplied title and expected ID. `MainDesktopBound=false` remains because duplicate/renamed chat titles, independent windows, long-term ID stability and lifecycle races remain unresolved.
