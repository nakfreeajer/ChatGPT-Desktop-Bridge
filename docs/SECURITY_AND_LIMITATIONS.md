# Security, privacy and limitations

## Status

Experimental UI Automation research on a live Windows desktop session; **not an officially supported integration or a production transport**. Application terms/support status was not established by the investigation.

## Security controls

1. **Fail closed.** Stop on multiple candidate windows, missing or ambiguous conversation, mismatched expected identifier, inaccessible UI, or uncertain delivery outcome.
2. **No title-only delivery.** Visible titles are mutable and non-unique; UIA RuntimeId and CSS classes do not substitute for persistent identity.
3. **Separate approval boundary.** External caller grants and records authorization. The Bridge must never infer broad consent from its ability to invoke controls.
4. **Disposable test targets.** No automatic test messages to production Architect conversations without explicit human approval.
5. **Least information.** Default logs: result code, sanitized stage, timestamp, elapsed time, and request-correlation token. Do not log message contents, personal labels, full URLs/IDs, cookies, auth tokens, browser page text, or other sensitive data.
6. **No debugging security reduction.** Do not enable CDP remote-debugging ports/pipes or weaken app settings just to route messages.
7. **No automatic retries on uncertainty.** A successful UIA Invoke is not a guaranteed completed server transaction; retries can duplicate messages.
8. **App state constraints.** UIA relies on a usable interactive Windows session and valid accessibility controls. Locked screen, minimized/unrendered surfaces, app updates, accessibility-tree churn, and multiple windows remain unqualified.
9. **Focus is a state change.** Calling SetFocus on the embedded browser's address bar changes keyboard focus; no navigation/send was performed in this diagnostic, but it is not perfectly passive observation.
10. **No public share-link assumption.** The browser's private `/c/<id>` address is distinct from creating a share link. Do not invoke Share or publish conversations as an identity workaround.

## Residual threats

- Wrong conversation selected due to same name, reordered sidebar, hidden item, or stale element.
- Address bar describes embedded-browser tab while the main Desktop composer belongs to a different conversation.
- Time-of-check/time-of-use race: window or conversation changes after verification but before Send.
- UIA hierarchy, app package, CSS classes, or focus behavior changes across updates.
- Submission attempted but delivery acknowledgement unclear, leading to duplicates if retried.
- Overcollection of private data during accessibility scanning or diagnostic logging.
- Session lock, disconnect or crash during interaction.

## Explicit limitations of observed proof of concept

- Successful manual known-ID comparison covers the **browser-selected** conversation only.
- No tested automatic, immutable, end-to-end binding from sidebar target to browser URL.
- No verified stable ID across restart, rename or platform update.
- No qualified unattended operation, request ledger, deduplication, server-side receipt confirmation, or recovery.
- No statement that every Windows/ChatGPT version exposes the same UIA properties.

## Operating principle

**Prefer a visible failure over a wrong-destination send.** Preserve evidence but do not inflate experimental PASS into production readiness.

## M02-A implementation-specific qualifications (2026-10-16)

- The navigation-only prototype requires explicit `-Navigate -AcceptKeyboardRisk` opt-in. Its default invocation does not navigate or write any URL, but may change focus to read the complete address.
- To navigate, it uses `SendKeys('{ENTER}')` only while a focused, visible ListItem matches the expected target URL and adjacent address control, and only with a verified foreground window. **This is still vulnerable to time-of-check/time-of-use focus races.**
- Before any controlled test, both message composers must have empty drafts; never run an unqualified keyboard-navigation prototype unattended or against valuable unsent content.
- A successful `VERIFIED_BROWSER_ROUTE` means the **embedded browser** URL and a candidate document/editor were observed; it is not a server acknowledgement, a full page-readiness proof, or a guarantee about the separate main Desktop panel.
- No messaging capability is implemented. M02-A passed supervised browser inspection and navigation; unattended operation is not qualified. No sensitive IDs should be committed to the public repo or printed as logs.

## M02-C selected-tab guard (2026-10-16)

- Positive experimental evidence: two visible browser tabs had exactly one selected `TabItem`; the selected blank tab gave an empty address; switching back to CDLD produced a 58-character conversation-shaped address.
- `Bridge.TabGuard.ps1` checks exactly one selected tab, using relative position to the browser address control plus UIA selection state. It records only an ephemeral RuntimeId **in memory**, never in output or committed fixtures.
- The selected tab and tab count must remain stable before address insertion, during autocomplete, just before global Enter, during post-navigation verification, and on the final check. Ambiguous/missing/changed selection fails closed.
- The guard cannot prevent a focus switch in the fraction of time between final check and the global Enter. It also cannot infer the main Desktop conversation's immutable ID, guarantee active window routing across multiple Desktop windows, or prove that a rendered page's content is fresh.
- M02-C received human-run Windows results: 20/20 offline checks, supervised one-tab inspection/navigation, and a two-tab blank-selected mismatch rejection all PASS. Deliberate tab switching mid-navigation remains unqualified; use supervised tests with empty drafts only.

## M02-D.13 identity correlation limitations

- `Bridge.Resolve.ps1` requires both an exact main-sidebar title and a caller-supplied expected conversation UUID. A duplicate visible sidebar title or ambiguous main document/menu item is an error, never an implicit choice. Titles are mutable and therefore are NOT durable identity keys.
- `-OpenInBrowser` is an explicit user action that invokes only the `Open on chatgpt.com` menu option. It may create or select an embedded-browser tab. This is a navigation/UI-state mutation, even though no chat message is submitted.
- If the current selected browser tab already matches the expected ID before menu invocation, the script returns `BROWSER_ALREADY_ON_EXPECTED_ID` rather than claiming causal identity evidence.
- The script rechecks the selected tab, URL, and browser document after menu invocation, reports a transition category, and returns `MainDesktopBound=false`. It does not control external browsers or equate a name match with permanent main-Desktop identity binding.
- A UIA race or unexpected ChatGPT Desktop update may cause false negatives or unforeseen menu behavior; no unattended or production use is qualified. Browser tab transitions during UIA polling are not guaranteed detectable between snapshots.
- The browser URL and ID are compared only in memory; output omits titles, private IDs, URLs, and UIA RuntimeIds. No composer writes, keyboard SendKeys or chat Send invocation is implemented.

## BRIDGE.CODEX.BASELINE.1B supervised launcher

- `src/Bridge.Resolve.Supervised.ps1` requests the independently verified ARM UUID with `Read-Host -AsSecureString`, rejects redirected/noninteractive input, validates with the existing UUID helper, and converts the secure value only in the current Windows PowerShell process. The temporary BSTR is zeroed and the SecureString disposed.
- The wrapper invokes `Bridge.Resolve.ps1` in-process. `-PreflightOnly` runs the existing read-only resolver preflight. `-ConfirmOpenInBrowser` runs that preflight, verifies a unique selected browser tab whose address resolves to a different conversation ID, then requires the human to type `OPEN` and repeats the baseline check before one resolver `-OpenInBrowser` call. The resolver now fails closed if no existing browser-conversation baseline can be read.
- The selected browser address is read through UIA ValuePattern after focusing its embedded-browser address control; this changes keyboard focus. The wrapper never prints or persists the address or either conversation ID. Its result contains only sanitized status and verification fields and keeps `MainDesktopBound=false`.
- The launcher has offline syntax/source-guard qualification only. It has not been qualified against live input, UIA, or menu invocation. Do not treat offline checks as evidence that the live path works.

## M02-D.13 qualification update (2026-10-16)

Human-provided Windows PowerShell output confirms offline suites `18/18`, `20/20`, and `33/33`, **71/71 assertions PASS** across M02-A, M02-C and M02-D.13. These offline checks test parser/pure helper/source invariants, **not runtime proof** of `Bridge.Resolve.ps1`.

The integrated resolver's actual live preflight and opt-in menu invocation have **not** yet been executed. Distinguish previously successful manually assembled UIA commands from the new integrated script. Continue to report `MainDesktopBound=false`, do not infer browser tab creation behavior without evidence, and never promote URL/title correlation to unattended identity assurance.
