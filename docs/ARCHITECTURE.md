# Proposed architecture (not implemented)

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

## Release gate

No unattended message submission until automatic identity binding, race handling, duplicate prevention, lifecycle behavior, and controlled delivery tests are approved and demonstrated.
