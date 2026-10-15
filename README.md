# ChatGPT Desktop Bridge

**Status:** Experimental proof of concept; M02-A controlled navigation PASS (human-run); M02-C controlled single-tab navigation and two-tab negative tests PASS (human-run); M02-D.13 source implemented, Windows runtime pending.  
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

**This is not a production integration.** Human-run Windows tests confirmed M02-A inspection-only mismatch rejection and controlled home-to-CDLD navigation with post-navigation URL/editor verification. Those tests did not qualify unattended navigation. It uses the experimentally observed embedded-browser UIA controls and returns JSON status data without printing any conversation URL/ID or message text.

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

## Selected-tab stability guard — BRIDGE.M02-C

The navigation prototype now loads [src/Bridge.TabGuard.ps1](src/Bridge.TabGuard.ps1) and requires **exactly one visible selected browser tab** in the region above the browser address bar. It captures the tab's UIA RuntimeId **as an ephemeral within-run token only**, not a persistent conversation ID. It fails closed when tab discovery is unavailable, selection ambiguous or unsupported, or the selected tab/tab count changes between checks. This check occurs before URL injection, during suggestion verification, immediately before Enter, and throughout destination verification.

The added [tests/TabGuard.Offline.Tests.ps1](tests/TabGuard.Offline.Tests.ps1) covers syntax, tab snapshots and critical call sites. Run:

~~~powershell
git pull origin main
.\tests\Identity.Offline.Tests.ps1
.\tests\TabGuard.Offline.Tests.ps1
~~~

**M02-C passed supervised Windows single-tab positive inspection/navigation and two-tab negative rejection.** Tab switching during navigation remains unqualified, and offline tests alone cannot demonstrate live compatibility. The guard reduces accidental wrong-tab targeting but cannot eliminate a time-of-check/time-of-use keyboard focus race, and it does not bind the main Desktop panel to a durable conversation ID.

## Main-sidebar menu to browser-ID verifier — BRIDGE.M02-D.13

[Bridge.Resolve.ps1](src/Bridge.Resolve.ps1) is a separate bounded Windows PowerShell 5.1 prototype. It requires both a human-known exact sidebar title and an independently expected conversation UUID. It does **not** treat the title or UIA RuntimeId as the durable conversation ID.

- Without `-OpenInBrowser`: inspect only. Require one matching main `RootWebArea` document and one unique matching sidebar `ListItem` with its `Chat actions` button; return `PREFLIGHT_PASS` without opening anything.
- With `-OpenInBrowser`: require the browser not already on the expected ID; expand the target sidebar menu through `ExpandCollapsePattern`; require exactly one visible `Open on chatgpt.com` `MenuItem`; invoke it through `InvokePattern`; verify the selected embedded-browser tab, full URL ID, browser document, and stable tab identity. Tab-opening may create a tab, reuse the selected tab, or activate a different existing tab; this is identified *after* invocation rather than assumed.
- The returned `MENU_TO_BROWSER_ID_VERIFIED` is a **controlled correlation**, not durable main-Desktop identity binding; `MainDesktopBound=false` remains. No keyboard injection, message insertion, or Send exists in this script.

From the repository root:

~~~powershell
# Offline checks; these do not touch ChatGPT Desktop.
.\tests\Resolve.Offline.Tests.ps1

# Preflight only: no menu invocation.
.\src\Bridge.Resolve.ps1 -ConversationTitle 'Artifact Relay Manager' -ExpectedConversationId $global:BridgeArmExpectedId

# Explicitly invoke the sidebar menu after preparing a different selected browser tab.
.\src\Bridge.Resolve.ps1 -ConversationTitle 'Artifact Relay Manager' -ExpectedConversationId $global:BridgeArmExpectedId -OpenInBrowser
~~~

The `$global:BridgeArmExpectedId` example assumes the user previously captured the ARM ID in the **same PowerShell session**; it is not saved by the script. Do not commit or print private conversation IDs/URLs. M02-D.13 **Windows runtime qualification is pending**.

## Release status

**M00 documentation, M02-A/M02-C supervised navigation evidence and M02-D.13 unqualified integrated menu-to-ID prototype.** No background service, installer, message delivery, integration, or production release is included. Milestones are proposed unless explicitly recorded as approved, and prior experimental PASS results are not production acceptance results.
