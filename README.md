# ChatGPT Desktop Bridge

**Status:** Experimental Windows PowerShell 5.1 / UI Automation proof of concept. One human-supervised integrated resolver scenario passed (`BRIDGE.M02-D.15P`, `PASS_CONTROLLED_INTEGRATED`). This does not qualify unattended operation or message delivery.

## What is implemented

- Pure identity helpers and a selected embedded-browser tab stability guard.
- An earlier browser-only navigation experiment with an explicit keyboard-risk opt-in.
- A resolver that defaults to read-only preflight. Its separate `-OpenInBrowser` path uses the verified Desktop sidebar menu and checks the embedded-browser conversation UUID, document, tab stability and observed tab transition.
- An interactive wrapper that reads the expected UUID through a hidden secure prompt, calls the resolver in-process, and requires explicit `OPEN` before the single menu invocation.

The latest controlled run activated an **existing** ARM browser tab (`EXISTING_TAB_ACTIVATED`, two tabs visible). The result verifies the expected embedded-browser destination for that supervised scenario. It does not permanently bind the separate main Desktop conversation to an immutable ID; `MainDesktopBound=false` is intentional.

**No current Bridge code inserts or submits chat messages.** Delivery is `NOT_ASSESSED`. CDP, Playwright, OpenAI API access, unattended orchestration and automatic retry are outside the implementation.

## Offline tests

Run from Windows PowerShell 5.1 at the repository root:

~~~powershell
.\tests\Identity.Offline.Tests.ps1
.\tests\TabGuard.Offline.Tests.ps1
.\tests\Resolve.Offline.Tests.ps1
.\tests\SupervisedLauncher.Offline.Tests.ps1
~~~

Latest baseline: Identity 18/18, TabGuard 20/20, Resolve 87/87, SupervisedLauncher 42/42 — **167/167 assertions PASS**. Offline tests do not interact with ChatGPT Desktop.

## Documentation

- [Failure and recovery register](docs/FAILURE_AND_RECOVERY_REGISTER.md) — canonical detailed chronology through M02-D.15P, including failed experiments, causes, corrections and evidence limits.
- [Investigation log](docs/INVESTIGATION_LOG.md) — concise timeline index.
- [Verified findings](docs/VERIFIED_FINDINGS.md) — evidence classifications and current status.
- [Architecture](docs/ARCHITECTURE.md) — current components and resolver control flow.
- [Security and limitations](docs/SECURITY_AND_LIMITATIONS.md) — identity, privacy and remaining qualification gates.
- [PowerShell test commands](docs/POWERSHELL_TEST_COMMANDS.md) — offline suites and separately supervised launcher modes.
- [Next milestones](docs/NEXT_MILESTONES.md) — current status and approval gates.
- [Project objective](docs/PROJECT_OBJECTIVE.md) — project boundary and eventual objectives.

## Safety boundary

The main Desktop UI and embedded browser are separate surfaces. Titles are mutable and may be duplicated; RuntimeIds and window handles are ephemeral. A parsed browser URL is not proof of permanent main-panel identity. Multiple windows, duplicate or renamed conversations, lifecycle changes and focus/tab races remain unqualified. Cloudflare was reported during one earlier run, but its role was not established; the Bridge does not detect, bypass or automate challenge verification.

Do not submit a message or run a live launcher mode without separate human authorization and supervision. Never put private IDs, conversation URLs, credentials or chat content in source, command lines, environment variables, logs, tests or reports.
