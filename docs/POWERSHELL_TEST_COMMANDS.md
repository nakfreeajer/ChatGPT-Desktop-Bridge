# PowerShell test and supervised-run instructions

## Offline qualification

Use **Windows PowerShell 5.1** from the repository root. These seven scripts exercise syntax, pure helpers and source guards; they do not access or change the ChatGPT Desktop UI.

~~~powershell
.\tests\Identity.Offline.Tests.ps1
.\tests\TabGuard.Offline.Tests.ps1
.\tests\Resolve.Offline.Tests.ps1
.\tests\SupervisedLauncher.Offline.Tests.ps1
.\tests\WindowGuard.Offline.Tests.ps1
.\tests\MainComposer.Predicate.Offline.Tests.ps1
.\tests\MainPanel.Locator.Offline.Tests.ps1
git diff --check
~~~

Latest verified output: Identity **18/18**, TabGuard **20/20**, Resolve **97/97**, SupervisedLauncher **44/44**, WindowGuard **17/17**, MainComposer.Predicate **22/22**, MainPanel.Locator **43/43**; **261/261 assertions PASS**. Window decision tests are offline. A separate M02-E.1C-R1 diagnostic live-qualified native selector behavior in one observed Windows 10 configuration; offline suites do not exercise native enumeration, the full resolver or live UIA.

The two main-panel suites qualify pure selection and synthetic ownership/final-snapshot decisions only. They do not qualify the runtime locator against live UIA.

## Supervised resolver launcher

These commands are **live UIA operations**, not offline tests. Run them only when a separate supervised test is authorized and the human is present at the Windows desktop.

Read-only preflight:

~~~powershell
.\src\Bridge.Resolve.Supervised.ps1 -PreflightOnly
~~~

One separately confirmed menu-to-browser-ID invocation:

~~~powershell
.\src\Bridge.Resolve.Supervised.ps1 -ConfirmOpenInBrowser
~~~

The launcher requires an interactive terminal. The human enters the independently verified expected ARM UUID at its hidden `Read-Host -AsSecureString` prompt; it is not supplied as a command-line argument. Invocation mode verifies a different existing browser baseline, asks the human to type the exact confirmation `OPEN`, rechecks the baseline, then invokes the menu once. The menu action can change the embedded-browser tab. Do not run it as an offline test; stop on any blocked, failed, ambiguous or unexpected state. Never retry automatically.

No launcher mode inserts or submits a chat message. `MessageDeliveryStatus` remains `NOT_ASSESSED`.

## Separate experimental navigation prototype

`src/Bridge.Navigate.ps1` is an earlier browser-only prototype. Its explicit `-Navigate -AcceptKeyboardRisk` path changes the address and sends Enter to a verified autocomplete suggestion; it has a global focus race. It is not needed for the integrated resolver and is not an offline test. Do not use it without a separately approved, supervised navigation-only experiment.

## Evidence and troubleshooting

For exact test milestones and source behavior, see [verified findings](VERIFIED_FINDINGS.md). For observed failures, diagnoses, fixes and boundaries, see the [failure/recovery register](FAILURE_AND_RECOVERY_REGISTER.md). No example in this file contains a real conversation UUID or URL.
