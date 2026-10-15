# ChatGPT Desktop Bridge

**Status:** Experimental proof of concept; **BRIDGE.M02-A source committed but not runtime-qualified**.  
**Scope:** Lightweight Windows UI Automation (UIA) adapter for interacting with existing ChatGPT Desktop conversations, without Chrome DevTools Protocol (CDP) or the OpenAI API.  
**Evidence date:** 2026-10-15.  
**Platform observed:** Windows; ChatGPT Desktop using a Chromium/WebView2-based accessibility tree.

## Purpose

Provide a reusable local component that an **external, separately authorized caller** can ask to identify a specified existing ChatGPT Desktop conversation, verify destination identity, submit an authorized message, and report an unambiguous delivery status. It must remain a transport component, **not** an Orchestrator.

## Current evidence

Human-run PowerShell experiments reported successful window discovery, sidebar conversation enumeration, title-based navigation, composer insertion, and Send invocation. Later diagnostics identified an embedded browser address bar accessible as a UIA `ComboBox`, named `Search or enter a URL`. While unfocused, both `ValuePattern` and `TextPattern` returned only `chatgpt.com` (11 characters). After `SetFocus()`, both exposed a 58-character conversation URL. A subsequent extraction matched a known, manually observed conversation ID.

**This verifies extraction and comparison for the opened embedded-browser conversation only.** It does **not** prove that the embedded browser and the main Desktop panel display the same conversation, nor establish safe automatic binding between a sidebar element and a durable conversation ID. No unattended delivery or production routing is approved.

The repository was empty before this documentation initialization. The findings below are records of user-reported diagnostics and handover evidence; they are not independent automated qualification of a production component.

## Documentation

- [Project objective and boundaries](docs/PROJECT_OBJECTIVE.md)
- [Investigation log](docs/INVESTIGATION_LOG.md)
- [Evidence and verified findings](docs/VERIFIED_FINDINGS.md)
- [PowerShell diagnostic references](docs/POWERSHELL_TEST_COMMANDS.md)
- [Proposed architecture](docs/ARCHITECTURE.md)
- [Security and limitations](docs/SECURITY_AND_LIMITATIONS.md)
- [Next milestones and gates](docs/NEXT_MILESTONES.md)

## Non-negotiable controls

- **Fail closed** when destination identity or delivery state is ambiguous.
- Do not treat a title, UIA `RuntimeId`, CSS class, or ephemeral `AutomationId` as a durable conversation identity.
- No unapproved live sends to production Architect conversations; use explicitly designated disposable test conversations.
- Never log credentials, cookies, message bodies, private conversation IDs/URLs, or other sensitive content by default.
- No CDP ports, OpenAI API dependency, workflow orchestration, Drive polling, or credential-handling built into this component.
- Do not silently retry a send after an uncertain outcome.

## Navigation-only prototype — BRIDGE.M02-A

The new Windows PowerShell 5.1 prototype lives in [src/Bridge.Navigate.ps1](src/Bridge.Navigate.ps1), with [side-effect-free identity helpers](src/Bridge.Identity.ps1) and [offline syntax/identity regression tests](tests/Identity.Offline.Tests.ps1).

**This is not a production integration.** Code has been committed but has **not** been run or qualified against a Windows ChatGPT Desktop session from this repository. It uses the experimentally observed embedded-browser UIA controls and returns JSON status data without printing any conversation URL/ID or message text.

From the repository root in Windows PowerShell 5.1:

~~~powershell
# Observe/verify only: may change address-bar keyboard focus but does not navigate.
.\src\Bridge.Navigate.ps1 -ConversationId '<EXPECTED-CONVERSATION-UUID>'

# Explicitly opt in to navigation by focused autocomplete suggestion + Enter.
# CAUTION: global keyboard input has a residual focus race; use only in a controlled test
# session with empty drafts in both composers.
.\src\Bridge.Navigate.ps1 -ConversationId '<EXPECTED-CONVERSATION-UUID>' -Navigate -AcceptKeyboardRisk

# Offline tests: code parser checks and identity-validation regressions, no UI automation.
.\tests\Identity.Offline.Tests.ps1
~~~

Navigation deliberately refuses to leave a different conversation unless the embedded browser is at the ChatGPT home screen. The browser must already be open. All ambiguous windows, address bars, suggestions, destination URLs, or editor candidates must fail closed. The returned `VERIFIED_BROWSER_ROUTE` status means **only** the embedded-browser URL and a candidate editor/document were verified; it does not verify the separate main Desktop conversation, nor prove server acknowledgement or safe unattended send. There is **no message-sending function** in this prototype.

## Release status

**M00 documentation and M02-A experimental navigation-only prototype.** No background service, installer, message delivery, integration, or production release is included. Milestones are proposed unless explicitly recorded as approved, and prior experimental PASS results are not production acceptance results.
