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
- No messaging capability is implemented, and runtime qualification remains pending. No sensitive IDs should be committed to the public repo or printed as logs.
