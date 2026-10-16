# ChatGPT Desktop Bridge

**Status:** Experimental Windows PowerShell 5.1 / UI Automation proof of concept. One human-supervised integrated resolver scenario passed (`BRIDGE.M02-D.15P`, `PASS_CONTROLLED_INTEGRATED`). This does not qualify unattended operation or message delivery.

## What is implemented

- Pure identity helpers and a selected embedded-browser tab stability guard.
- A top-level window guard that selects one visible, enabled, ownerless, non-tool, non-child, non-popup ChatGPT conversation window and rechecks it before resolver actions.
- An earlier browser-only navigation experiment with an explicit keyboard-risk opt-in.
- A resolver that defaults to read-only preflight. Its separate `-OpenInBrowser` path uses the verified Desktop sidebar menu and checks the embedded-browser conversation UUID, document, tab stability and observed tab transition.
- An interactive wrapper that reads the expected UUID through a hidden secure prompt, calls the resolver in-process, and requires explicit `OPEN` before the single menu invocation.
- An offline main-panel composer and Send-control locator using a human-anchored Document, `Main` landmark and `Conversation` region. It returns metadata only and performs a fresh bounded uniqueness check before success; it does not write or invoke either control.

The latest controlled run activated an **existing** ARM browser tab (`EXISTING_TAB_ACTIVATED`, two tabs visible). The result verifies the expected embedded-browser destination for that supervised scenario. It does not permanently bind the separate main Desktop conversation to an immutable ID; `MainDesktopBound=false` is intentional.

**No current Bridge code inserts or submits chat messages.** Delivery is `NOT_ASSESSED`. CDP, Playwright, OpenAI API access, unattended orchestration and automatic retry are outside the implementation.

## Offline tests

Run from Windows PowerShell 5.1 at the repository root:

~~~powershell
.\tests\Identity.Offline.Tests.ps1
.\tests\TabGuard.Offline.Tests.ps1
.\tests\Resolve.Offline.Tests.ps1
.\tests\SupervisedLauncher.Offline.Tests.ps1
.\tests\WindowGuard.Offline.Tests.ps1
.\tests\MainComposer.Predicate.Offline.Tests.ps1
.\tests\MainPanel.Locator.Offline.Tests.ps1
~~~

Latest offline qualification: Identity 18/18, TabGuard 20/20, Resolve 97/97, SupervisedLauncher 44/44, WindowGuard 17/17, MainComposer.Predicate 22/22, MainPanel.Locator 43/43 — **261/261 assertions PASS**. Separately, M02-E.1C-R1 verified the native window selector in one observed Windows 10 configuration; this did not run the resolver or UIA workflow.

## Documentation

- [Failure and recovery register](docs/FAILURE_AND_RECOVERY_REGISTER.md) - canonical detailed chronology through BRIDGE.MAIN.1E.FIX1, including failures, corrections and evidence limits.
- [Investigation log](docs/INVESTIGATION_LOG.md) — concise timeline index.
- [Verified findings](docs/VERIFIED_FINDINGS.md) — evidence classifications and current status.
- [Architecture](docs/ARCHITECTURE.md) — current components and resolver control flow.
- [Security and limitations](docs/SECURITY_AND_LIMITATIONS.md) — identity, privacy and remaining qualification gates.
- [PowerShell test commands](docs/POWERSHELL_TEST_COMMANDS.md) — offline suites and separately supervised launcher modes.
- [Next milestones](docs/NEXT_MILESTONES.md) — current status and approval gates.
- [Project objective](docs/PROJECT_OBJECTIVE.md) — project boundary and eventual objectives.

## Safety boundary

The main-panel locator requires Document-specific, human-anchored evidence checked against the selected window root and Main / Conversation ancestry. This does not independently prove the anchor came from the main panel if a similar browser surface was mistakenly selected; automatic main Document identification and immutable conversation identity remain unresolved. MainDesktopBound=false.

The main Desktop UI and embedded browser are separate surfaces. Titles are mutable and may be duplicated; RuntimeIds and window handles are ephemeral. The top-level window selector passed offline decision coverage and a bounded native qualification in one observed Windows 10 configuration; this is not full resolver/UIA or general multi-window qualification. A parsed browser URL is not proof of permanent main-panel identity. Duplicate or renamed conversations, lifecycle changes and focus/tab races remain unqualified. Cloudflare was reported during one earlier run, but its role was not established; the Bridge does not detect, bypass or automate challenge verification.

Do not submit a message or run a live launcher mode without separate human authorization and supervision. Never put private IDs, conversation URLs, credentials or chat content in source, command lines, environment variables, logs, tests or reports.
