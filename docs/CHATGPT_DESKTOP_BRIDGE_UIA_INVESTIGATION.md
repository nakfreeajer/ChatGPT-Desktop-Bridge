# ChatGPT Desktop Bridge — UI Automation Investigation and External AI Review

**Prepared:** 2026-10-18 (Malaysia time)  
**Purpose:** self-contained technical evidence dossier for other AI models, engineers, and maintainers.  
**Status:** controlled prototype, **not** an unattended or production-qualified message transport.

> **Source/provenance warning:** GitHub \`main\` at preparation was **\`15f5baebb6158c773e252400cf6a8b5058a152b1\`**. The Windows Executor most recently reported a **clean local \`main\` at \`dc52eb333c2de13118adadcbaf9649520d311324\`**, whose intervening commits were **not pushed to GitHub**. The recent source interfaces, commits, tests, and live JSON below are drawn from Human-supplied local Executor reports and screenshots, **not independently reviewed against that unpublished local source**. Historical repository records through \`15f5bae\` were read directly from GitHub. Do not silently treat those two versions as identical. Before changing implementation, obtain the actual local HEAD, diff/history, source files, and most recent Executor result.

## 1. Executive summary and exact question

The project is intended to let an **Orchestrator** use the **existing ChatGPT Windows Desktop application** to reach a designated Architect conversation, initially by delivering a very short “Executor report ready” notification. Full task prompts and Executor reports live in Google Drive. **Artifact Relay Manager (ARM)** watches Drive for new artifacts and emits events; it does **not** operate ChatGPT Desktop. The Orchestrator controls relay state, scheduling, priorities, and Executor interactions. A more capable two-way Desktop transport (compose, submit, read response) is a possible later extension.

**Desktop application is mandatory.** The separate ChatGPT *embedded-browser* surface must **not** be used as the shortcut to the main Desktop conversation. Earlier historical, separately authorized browser-menu experiments exist in the repository; they are **not** proof of main-conversation identity or a replacement transport. No CDP, Playwright, OpenAI API, browser DOM injection, or URL-only identity shortcut is approved for the main Bridge.

**Most important verified recent success:** a Human entered exactly \`test\` in the main Desktop composer. FlaUInspect displayed \`ValuePattern.Value = test\`. A separate **live PowerShell 5.1** supervised read returned:

\`\`\`json
{"Status":"COMPOSER_READ_VERIFIED","WindowVerified":true,"ForegroundWindowVerified":true,"FocusedComposerAcquired":true,"ControlTypeVerified":true,"ValuePatternSupported":true,"ReadAttempted":true,"ValueMatchesExpectedTest":true,"ErrorCategory":"NONE"}
\`\`\`

**Most important limitation:** as of the last report available at preparation, **no \`ValuePattern.SetValue()\` call had reached the live composer**, and **no chat message was sent or assistant response read by Bridge**. Precondition/acquisition checks, not an observed SetValue rejection, blocked the write tests. The separately approved \`BRIDGE.COMPOSER.REPLACE.LAB.1A\` (known input \`test\` replaced with \`BRIDGE TEST - DO NOT SEND\`) had **no reported live result yet**; verify that status with the Executor before asserting otherwise.

**Core engineering blockers:**
1. Reliably acquire a *main Desktop* Document without accidentally entering an embedded-browser Document. Human-anchored ownership sometimes works; pointer-free shell acquisition is **unqualified**.
2. The guarded Doorbell session-arm path historically failed in \`CONTROL_IDENTITY_COMPARISON\` with \`PropertyNotFoundException\`. Exact offending property and live root cause are **unresolved**. Contract hardening was committed locally.
3. Chromium/ProseMirror UIA editor accessibility values are not always the visible empty-editor state. Existing safe-to-overwrite checks became overcomplicated and blocked otherwise viable laboratory write attempts.
4. Actual write, submit, completed-response extraction, idempotency, and unattended lifecycle recovery remain unqualified.

**Ask to independent reviewers:** identify the smallest *falsifiable* way to establish safe, operation-local main Desktop composer acquisition and to prove a controlled \`SetValue\` insertion (or documented alternative) without weakening production destination verification. Analyze the real PowerShell 5.1 source and its UIA object contracts before proposing implementation.

## 2. Evidence taxonomy and strict boundaries

| Label | Meaning |
|---|---|
| **LIVE / HUMAN-REPORTED** | Human provided UI screenshots, terminal JSON, or a live run report. It supports that observed scenario only. |
| **LIVE / EXECUTOR-REPORTED** | Local Codex reported performing one bounded Windows UIA/Win32 run. |
| **OFFLINE** | Synthetic PowerShell suite or syntax validation; no actual Desktop control was exercised. |
| **SOURCE / PUBLISHED** | Present in GitHub \`main\` at \`15f5bae\`. |
| **SOURCE / LOCAL-REPORTED** | Local-only source or commit described by Executor; must be checked against local HEAD. |
| **PREPARED ONLY** | Temporary script made/validated but never run against Desktop. |
| **BLOCKED / INCONCLUSIVE** | A prerequisite or guard failed, or evidence insufficient. Not proof the intended UIA operation is impossible. |
| **HYPOTHESIS** | Plausible explanation without a reproducible live cause. |

Safety and architectural controls: distinguish Desktop main conversation from embedded browser; do not traverse unrelated Documents, read private conversation content, or use browser URL as main-panel identity; duplicate titles are possible; HWND and UIA RuntimeId are ephemeral; consent/authorization is scoped and single-use; distinguish UI attempt, UI-observed result, and server-side delivery; never blind-retry an ambiguous Send. \`MainDesktopBound=false\`, \`MainConversationIdentity=UNRESOLVED\`, and \`SendActionAuthorized=false\` remain accurate for the tested Doorbell flow.

## 3. Platform and tooling

- **Observed machine:** Windows 10 Home Single Language, build **19045**, x64; Windows PowerShell **5.1.19041.6456**; .NET **6.0.36** and **8.0.20** reported installed.
- **Repository:** \`nakfreeajer/ChatGPT-Desktop-Bridge\`; local working directory \`%USERPROFILE%\ChatGPT-Desktop-Bridge\` as reported.
- **Accessibility Insights for Windows:** Human identified the main panel hierarchy and control patterns.
- **FlaUInspect v3.1.0:** portable install \`%USERPROFILE%\Tools\FlaUInspect\FlaUInspect.exe\`; launched successfully. Official release ZIP digest matched published SHA-256; binary was reported unsigned. UIA2/UIA3 available; UIA3 was used for manual examination. [Project](https://github.com/FlaUI/FlaUInspect), [release](https://github.com/FlaUI/FlaUInspect/releases/tag/v.3.1.0).
- **Microsoft WinApp CLI v0.7.1:** installed via official WinGet; \`winapp --help\`, \`winapp ui --help\`, \`winapp ui inspect --help\` succeeded. [Official UI automation docs](https://learn.microsoft.com/en-us/windows/apps/dev-tools/winapp-cli/), [v0.7.1 UI JSON envelope](https://github.com/microsoft/winappCli/blob/v0.7.1/plugins/winapp/skills/winapp-ui-automation/references/ui-json-envelope.md).
- Codex's then-current CUA runtime did **not** provide usable Windows GUI \`getApp\`/\`listWindows\` methods, so it could launch FlaUInspect but **not** automate its Windows interface. This is a tooling limitation, not a FlaUInspect defect.

### Direct human screenshots of main composer (2026-10-18)

The observed composer metadata, as read from Accessibility Insights / FlaUInspect screenshots provided in conversation:

| Attribute | Observed |
|---|---|
| Accessible name | \`Ask ChatGPT\` |
| \`ControlType\` | \`Edit\` (UIA 50004) |
| \`ClassName\` | \`ProseMirror\` / \`ProseMirror ProseMirror-focused\` (focus-dependent) |
| \`FrameworkId\` | \`Chrome\` |
| \`IsEnabled\` / \`IsOffscreen\` | \`True\` / \`False\` in inspected state |
| \`AutomationId\` | Empty in the inspected control |
| \`NativeWindowHandle\` | Not supported for the Edit in FlaUInspect |
| \`ValuePattern\` | Supported, \`IsReadOnly=False\` |
| \`TextPattern\`, \`TextEditPattern\` | Supported |
| Other patterns | ScrollItem and legacy accessibility support observed |
| Empty-looking editor value | At least one screenshot showed \`Ask ChatGPT\` exposed by ValuePattern |
| After Human typed \`test\` | FlaUInspect showed \`ValuePattern.Value = test\`; separately read by PowerShell |

These observations establish that an accessibility provider exposes readable, **writable-reported** editor semantics. They do **not** prove \`SetValue()\` changes ProseMirror state, triggers the app's internal input handlers, submits a message, or survives a renderer reload.

A simplified *observed* hierarchy was \`main Desktop Document -> Main -> Conversation region -> Group -> Edit "Ask ChatGPT"\`, with a separate \`Send\` button in the conversation UI. The hierarchy should not be assumed stable for all application versions.

## 4. Code / component map and contracts

**Published GitHub source (older main):**

| File | Responsibility |
|---|---|
| [Bridge.WindowGuard.ps1](../src/Bridge.WindowGuard.ps1) | Select/recheck a unique qualifying top-level ChatGPT window. |
| [Bridge.MainPanel.Locator.ps1](../src/Bridge.MainPanel.Locator.ps1) | Main Document, \`Main\` and \`Conversation\` region composer/Send discovery with human-anchored ownership and final uniqueness checks. |
| [Bridge.MainComposer.Predicate.ps1](../src/Bridge.MainComposer.Predicate.ps1) | Composer/control predicates. |
| [Bridge.Resolve.ps1](../src/Bridge.Resolve.ps1) | Historical, separately authorized menu-to-embedded-browser resolver; **not** main Desktop composer ownership. |
| [Bridge.TabGuard.ps1](../src/Bridge.TabGuard.ps1) | Historical embedded-browser selected-tab checks. |
| [Bridge.Resolve.Supervised.ps1](../src/Bridge.Resolve.Supervised.ps1) | Historical interactive resolver launcher. |

**Local later modules, Executor-reported but not yet present on GitHub main:** \`src/Bridge.MainSidebar.Selector.ps1\`, \`src/Bridge.MainSidebar.Navigation.ps1\`, \`src/Bridge.Doorbell.ps1\`, \`tests/Doorbell.Offline.Tests.ps1\`. Any relative GitHub links to these files require publishing/syncing local history first.

Reported interface relationships:
- \`New-BridgeMainPanelOwnershipEvidence\` creates operation-local \`Evidence.DocumentElement\` and \`OwnershipEvidence\` from a validated human anchor.
- The **same exact** \`-DocumentElement\` and \`-OwnershipEvidence\` references may be passed to \`Get-BridgeMainSidebarCandidate\` and \`Get-BridgeMainPanelControls\` **within one valid operation**. The sidebar locator verifies the \`Complementary -> Navigation(Home) -> List/ListItem/Button\` path; composer locator verifies \`Main -> Conversation -> Edit/Send\`. This is **SOURCE / LOCAL-REPORTED structural reuse**, not automatic initial Document acquisition.
- \`Get-BridgeDoorbellControlSnapshot\` also takes those objects. Doorbell's extra control snapshot comparison is not necessary just to locate a composer once a trusted Document exists.
- \`Test-BridgeDoorbellSameControls\` checks selected snapshots, same Document/evidence reference, present typed \`Composer.Identity\` and \`SendButton.Identity\`, and compares composer + Send separately. \`Identity\` fields were reported to hold **raw \`System.Windows.Automation.AutomationElement\` instances**, not independent identity snapshots. \`Test-BridgeMainPanelControlIdentityEqual\` uses \`$First.Equals($Second)\` (exception -> non-match); this is not itself proof of the live \`PropertyNotFoundException\` cause.
- \`New-BridgeDoorbellArmAuthorization\` requires exact \`ARM\` confirmation early, with a per-process, project/session-bound, five-minute, one-use authorization registry. \`New-BridgeDoorbellSessionArm\` consumes it, with one-hour arm validity. A destination proof is one-use. The dry-run request includes \`ProjectId\`, \`RelayEventId\`, \`SessionAlias\`, and a single-line notification capped at 280 characters. No send/write path was added by that milestone.

**Boundary:** success from a currently verified Document can be reused only while evidence/window/control freshness holds. Changes across navigation, reload or restart cannot be assumed safe.

## 5. Chronological evidence — early published repository

The published [failure/recovery register](FAILURE_AND_RECOVERY_REGISTER.md), [investigation log](INVESTIGATION_LOG.md), and [verified findings](VERIFIED_FINDINGS.md) are the detailed authoritative *historical* records through \`15f5bae\`. These early experiments included an embedded-browser identity comparison but **never established immutable main Desktop identity**.

| Milestone | Evidence and result | Scope limit |
|---|---|---|
| M01/M02-A | Early UIA address, browser editor and keyboard navigation experiments; Identity **18/18** OFFLINE. | Browser behavior; a global Enter focus race was identified. |
| M02-B/C | Main Desktop and embedded browser could display different conversations; selected-tab checks and TabGuard **20/20** OFFLINE; controlled positive/negative tab cases. | Browser route is not main conversation ID. |
| M02-D.1–12 | Sidebar \`Chat actions\` has \`ExpandCollapsePattern\`; \`Open on chatgpt.com\` menu item has \`InvokePattern\`. Human observed manual navigation and correlations. | Menu/button association and browser destination not permanent Desktop identity. |
| M02-D.13–15I | Read-only preflight, supervised \`OPEN\` authorization, menu postcondition correction, address-read timing/polling corrections. | Various temporary failures; guarded embedded-browser experiment. |
| M02-D.15J/K | \`BROWSER_DESTINATION_UNVERIFIED\`; Cloudflare appeared during page loading. | **No proven causal link** between Cloudflare and failure. |
| M02-D.15L–N | Browser Document geometry had 60-px left-edge false rejection; corrected horizontal containment; offline total reached **167**. | Browser Document only. |
| M02-D.15O/15P | One controlled browser-document observer PASS; one human-run integrated **\`PASS_CONTROLLED_INTEGRATED\`**, \`EXISTING_TAB_ACTIVATED\`, two tabs visible. | **Not** automatic main session switching; not message delivery. |
| M02-E.1C/R1 | First temp observer hit read-only PowerShell \`$PID\` assignment; later two native snapshots found one qualifying main window and 15 excluded ChatGPT-owned auxiliary windows. | Qualifies one native-window scenario, not all app lifecycles. |
| BRIDGE.MAIN.1A–1E.FIX1 | Accessibility Insights Main/Conversation/Edit path; offline predicate + ownership locator; seven suites **261/261** PASS on published main. | At that snapshot main-panel production locator not yet live-qualified. Later local work supersedes some status. |

## 6. Chronological evidence — later local milestones (Executor/Human-reported)

Dates are primarily within 2026-10-17/18; exact timestamps unavailable for most. Rows distinguish **performed live actions** from **prepared-only tests**.

### 6A. Main panel, sidebar, navigation, initial ownership

| Milestone / stage | Evidence | Outcome / correction |
|---|---|---|
| Main-panel locator and sidebar candidate work | Human-verified main Document ownership, exact \`Ask ChatGPT\` and \`Send\` metadata, one named session button under \`Complementary -> Navigation(Home)\` | **LIVE selected/discovery observations passed**. Send could legitimately be disabled in empty state. |
| \`BRIDGE.PINNED.1H\` guarded navigation | Read-only \`PREFLIGHT_READY\`, single eligible session button, \`ALREADY_ACTIVE\` no invocation. Human had independently demonstrated a named button could navigate. | **Live guarded switching not successfully qualified**. An earlier outer catch masked whether invocation occurred during one failure. |
| \`BRIDGE.PINNED.1H.R11\` | \`HIT_ANCHOR_NOT_RECOVERABLE\` at initial human composer anchor; no navigation | **BLOCKED**, repeated pointer-based failures. |
| Separate anchor diagnostic | \`HIT_ANCHOR_VERIFIED\`, Edit name matched \`Ask ChatGPT\`, qualifying ancestor and root reached | **LIVE observation positive** for that capture only. |
| \`BRIDGE.MAIN.AUTOANCHOR.1A\` | A verified supplied main Document is searchable internally, but a safe application-window-to-Document root selector was not established without risking an embedded-browser subtree | **\`IDENTITY_BOUNDARY_INSUFFICIENT\`**, no change. |
| \`BRIDGE.MAIN.SHELL.1A/1B\` | Supervised ancestor/sibling read-only script prepared; live failed \`HUMAN_DOCUMENT_ANCHOR\` / \`RuntimeException\` before structural observation | **INCONCLUSIVE**; no unique shell path. |
| \`BRIDGE.MAIN.SHELL.1B.FIX1\` | RuntimeException might be thrown explicit status string, and catch masked exact anchor status | **\`STOP_SHELL_PATH_INVESTIGATION\`**; no speculative production correction. |
| Subsequent focused attempt | \`FocusedElementAcquired=true\` with \`HIT_ANCHOR_NOT_RECOVERABLE\` and \`DocumentOwnershipVerified=false\` | Acquired *an element*, not a verified main-Document composer. Distinct from parent chain ending without window root. |
| Cursor-based first write attempt | \`HIT_ANCHOR_WINDOW_UNRESOLVED\` after FromPoint; Control View parent chain ended at null before selected window root | **Failed closed**, no SetValue; cause not established. |
| \`BRIDGE.COMPOSER.STRUCTURE.1A\` | Existing sidebar and main composer locators can consume the same verified \`DocumentElement\`/\`OwnershipEvidence\` | **\`EXISTING_DOCUMENT_REUSE_FEASIBLE\` SOURCE / LOCAL-REPORTED**, but initial acquisition remains human-anchored. |

### 6B. Doorbell dry run and identity comparison

| Milestone / run | Exact result | Evidence / correction |
|---|---|---|
| \`BRIDGE.DOORBELL.1A\` | \`IMPLEMENTED_OFFLINE_QUALIFIED\`, 10 suites **368/368**; Doorbell new suite 30/30 | In-memory human-arm and dry-run decision only; local commit \`26532989\`. |
| \`BRIDGE.DOORBELL.1B\` | \`QUALIFICATION_PREPARED\`, 10 suites **377/377** | Exact \`ARM\` before countdown, five-minute single-use project/session authorization. Local commit \`3688e1b8\`. |
| First supervised dry run | \`HIT_ANCHOR_NOT_RECOVERABLE\` at \`INITIAL_HUMAN_ANCHOR\` | No arming, no delivery. |
| \`BRIDGE.DOORBELL.1C.FIX1\` | Temporary script expected \`HIT_ANCHOR_VERIFIED\` from ownership function which actually returns \`HUMAN_ANCHOR_VERIFIED\` | **Concrete script status-contract defect corrected**; 6/6 synthetic cases; no production change. |
| R2 live | \`HUMAN_ANCHOR_VERIFIED\`, \`ArmStatus=ARM_CREATION_FAILED\` | Initial anchor and ownership passed; destination/test not reached. |
| R2.FIX1 | Script had discarded production \`ErrorCategory\`; corrected temporary forwarding | 377/377 offline; underlying cause not yet known. |
| R3 live | \`ArmErrorCategory=PropertyNotFoundException\` | Still generic final revalidation/arm creation catch. |
| R3.FIX1 | Sanitized \`FailureStage\` instrumentation added to production catch | 10 suites **378/378**; local commit \`9cfcace\`; synthetic malformed title can reproduce same exception but **not** proven live cause. |
| R4 live | \`ArmFailureStage=CONTROL_COMPARISON\`; \`ArmErrorCategory=PropertyNotFoundException\` | Narrows failure, does not identify property. |
| R4.FIX1 | \`FailureStep\` instrumentation | 10 suites **379/379**; local commit \`bb0837da\`. |
| R5 live | \`ArmFailureStage=CONTROL_COMPARISON\`, \`ArmFailureStep=CONTROL_IDENTITY_COMPARISON\`, \`ArmErrorCategory=PropertyNotFoundException\` | Still unknown nested property. No Send. |
| R5.FIX1 | Source traces to \`Test-BridgeDoorbellSameControls\` and nested \`.Identity\` operands; synthetic throwing getter reproduced possible failure only | **\`BLOCKED_ROOT_CAUSE_UNRESOLVED\`**. Do not attribute live cause to that synthetic getter. |
| \`BRIDGE.DOORBELL.IDENTITYCONTRACT.1A\` | Added checks for missing/wrong-type/throwing control identities with explicit failure handling | **SOURCE / LOCAL-REPORTED** commit \`dc52eb3\` (“Harden Doorbell control identity contract”). No subsequent proven live resolution. |

The reported offline full-suite totals \`338/338\`, \`368/368\`, \`377/377\`, \`378/378\`, and \`379/379\` are **different revision checkpoints**, not additive test counts. Earlier published remote main had \`261/261\`. Recent tests frequently used synthetic PowerShell objects rather than actual live \`AutomationElement\` references; green offline results do not imply live compatibility.

### 6C. External inspectors and focused acquisition

| Event | Observation | Result / limit |
|---|---|---|
| FlaUInspect + WinApp CLI install | FlaUInspect v3.1.0 opened; WinApp CLI v0.7.1 help passed | **TOOLS INSTALLED**. |
| Automated FlaUInspect attempt | Codex CUA methods for Windows app window control unavailable | **BLOCKED**; inspector not attached; no live metadata from Codex. |
| First WinApp \`get-focused -w ... --json\` | Valid JSON; parser looked for \`controlType\` instead of \`element.type\` and did not inspect \`hasFocus\` | **Parser defect confirmed offline**, result inconclusive. |
| WinApp JSON correction | Correct v0.7.1 envelope \`hasFocus\` and nested \`element.type\`, \`element.name\`, \`element.isEnabled\`; \`AutomationId\` optional | 7/7 synthetic parser cases; no raw UIA content logged. |
| Corrected focused query | \`{"Status":"NO_VERIFIED_FOCUS","WindowVerified":true,"HasFocus":false,"CommandExitStatus":"ZERO"}\` | Query executed but **no focused element verified** in specified window. Investigation closed. |
| FlaUInspect Human observation | Main composer UIA3 \`Edit/Ask ChatGPT\`, \`ProseMirror\`, Value/Text/TextEdit patterns, writable-reported Value | **CONFIRMED SCREENSHOT OBSERVATION**. |
| Manual \`test\` observation | \`ValuePattern.Value=test\` shown in FlaUInspect | **LIVE / HUMAN-REPORTED**. |
| \`BRIDGE.COMPOSER.READ.1A\` first run | \`FOREGROUND_WINDOW_MISMATCH\` before countdown; separate explanatory JSON mistakenly contained WRITE-test fields | **Script sequencing/reporting defect**; not a read failure. |
| \`BRIDGE.COMPOSER.READ.1A.FIX1\` | Moved foreground check after countdown; 8/8 synthetic cases | **OFFLINE PASS**. |
| \`BRIDGE.COMPOSER.READ.1B\` | \`COMPOSER_READ_VERIFIED\`, focused composer obtained, exact ValuePattern match to \`test\` | **LIVE PASS**, read-only. No assistant-response read. |

### 6D. Unsent write feasibility and empty-state troubleshooting

| Event | Exact outcome | Correct interpretation |
|---|---|---|
| First guarded \`BRIDGE.COMPOSER.WRITE.1A\` | \`HIT_ANCHOR_WINDOW_UNRESOLVED\` | No \`SetValue\` attempt; control ancestry failed. |
| \`BRIDGE.COMPOSER.WRITE.LAB.1A\` | Reduced supervised contract approved; subsequent local inspection rejected safe distinction from embedded browser | **Prepared/proposed**, no write. |
| \`BRIDGE.COMPOSER.WRITE.LAB.1B\` initial script | 13/13 synthetic, focused acquisition + one \`SetValue\` call site | **PREPARED ONLY**. |
| Initial LAB.1B live | \`COMPOSER_NOT_EMPTY\`, \`SetValueAttempted=false\`, \`IsReadOnly=false\` | Composer reached; empty-state check failed. |
| Placeholder FIX1 | Previous script required \`ValuePattern.Value.Length -eq 0\`; empty-looking screenshot could expose \`Ask ChatGPT\` | **Concrete classifier defect**; temporary script 21 synthetic cases, no live write. |
| Second LAB.1B live | \`COMPOSER_NOT_EMPTY\`, \`ComposerEmptyStatus=ACTUAL_NONEMPTY_DRAFT\`, \`FocusedComposerVerified=true\`, \`ComposerVerified=true\`, \`ValuePatternSupported=true\`, \`IsReadOnly=false\`, \`SetValueAttempted=false\` | Classifier asserted nonempty; not independent proof of a visible draft. |
| Empty contract correction | Prior \`ACTUAL_NONEMPTY_DRAFT\` branch treated any nonempty non-placeholder Value as draft without comparing TextPattern | **Concrete logic defect**; 25 synthetic cases; actual prior value not captured. |
| \`BRIDGE.COMPOSER.EMPTY.OBSERVE.1A\` offline | 13/13 synthetic; single Value and Text read; no mutation | **PREPARED**. |
| Empty observation live | \`OBSERVATION_COMPLETE\`, \`ValuePatternCategory=VISIBLE_NONPLACEHOLDER\`, \`TextPatternCategory=VISIBLE_NONPLACEHOLDER\`, \`SignalAgreement=AGREE\`, \`EmptyStateClassification=AMBIGUOUS\` | Both APIs exposed some visible non-placeholder content, but sanitized categories cannot establish whether it was a user draft, app-generated editor text, or changed state. No write. |
| \`BRIDGE.COMPOSER.REPLACE.LAB.1A\` | Human **approved** known-text replacement: require exact \`test\` before replacing with \`BRIDGE TEST - DO NOT SEND\` | **APPROVED / RESULT NOT YET REPORTED** at preparation. Verify newer activity before re-running. |

**Readback success ≠ SetValue success.** UIA \`ValuePattern.IsReadOnly=false\` is a candidate capability, not proof the ProseMirror editor updates internal state when \`SetValue()\` is invoked.

## 7. Exact sanitized failures / results for reproductions

The following compact outputs were supplied by the Human; omitted keys were not pertinent. No private conversation text is included.

\`\`\`json
{"Status":"ARM_CREATION_FAILED","Stage":"SESSION_ARM","HumanAnchorStatus":"HUMAN_ANCHOR_VERIFIED","ArmFailureStage":"CONTROL_COMPARISON","ArmFailureStep":"CONTROL_IDENTITY_COMPARISON","ArmErrorCategory":"PropertyNotFoundException","SendInvoked":false}
{"Status":"HIT_ANCHOR_WINDOW_UNRESOLVED","Stage":"HIT_TEST","SetValueAttempted":false,"SendInvoked":false}
{"Status":"HIT_ANCHOR_NOT_RECOVERABLE","Stage":"FOCUSED_ELEMENT_ACQUISITION","FocusedElementAcquired":true,"ComposerVerified":false,"DocumentOwnershipVerified":false}
{"Status":"NO_VERIFIED_FOCUS","WindowVerified":true,"HasFocus":false,"CommandExitStatus":"ZERO"}
{"Status":"COMPOSER_READ_VERIFIED","WindowVerified":true,"ForegroundWindowVerified":true,"FocusedComposerAcquired":true,"ControlTypeVerified":true,"ValuePatternSupported":true,"ReadAttempted":true,"ValueMatchesExpectedTest":true}
{"Status":"COMPOSER_NOT_EMPTY","ForegroundWindowVerified":true,"FocusedComposerVerified":true,"ComposerVerified":true,"ValuePatternSupported":true,"IsReadOnly":false,"ComposerEmptyStatus":"ACTUAL_NONEMPTY_DRAFT","SetValueAttempted":false,"SendInvoked":false}
{"Status":"OBSERVATION_COMPLETE","WindowVerified":true,"FocusedComposerVerified":true,"ValuePatternCategory":"VISIBLE_NONPLACEHOLDER","TextPatternCategory":"VISIBLE_NONPLACEHOLDER","SignalAgreement":"AGREE","EmptyStateClassification":"AMBIGUOUS","WriteAttempted":false}
\`\`\`

### Temporary local scripts reported (not committed to GitHub)

These are example *locations*, not portable source artifacts. Availability and exact contents must be verified in the Windows Executor's current session:

\`\`\`text
%TEMP%\Bridge-Pinned-Navigation-R2-Qualification.ps1
%TEMP%\Bridge-MainShellPath-Qualification.ps1
%TEMP%\Bridge-Doorbell-DryRun-Qualification.ps1
%TEMP%\Bridge-Composer-Write-Test.ps1
%TEMP%\Bridge-Focused-Composer-Qualification.ps1
%TEMP%\Bridge-Composer-Read-Test.ps1
%TEMP%\Bridge-Composer-Write-Lab-1B.ps1
%TEMP%\Bridge-Composer-Empty-Observe-1A.ps1
\`\`\`

For a **read-only** known-\`test\` qualification, the reported invocation was:

\`\`\`powershell
powershell.exe -NoProfile -File "$env:TEMP\Bridge-Composer-Read-Test.ps1"
\`\`\`

Human opened the intended test conversation, entered \`test\`, confirmed the read-only check, and focused the composer. **Do not execute these temporary scripts blindly**: inspect their actual current contents, exact permissions, current conversation, and remaining authorization before any run. The last known proposed **write** is a separate one-time test; no Send is authorized.

## 8. Confirmed defects versus unresolved hypotheses

**Confirmed source/script defects (historical):**
- Temp navigation authorization registry initially not initialized under strict mode; local commit \`f7a1307a\`.
- Shell and Doorbell temp catch handling obscured actual error status; improved sanitized reporting. This alone did **not** fix UIA root cause.
- Doorbell temp script compared ownership status to hit-test statuses rather than \`HUMAN_ANCHOR_VERIFIED\`.
- READ test checked foreground before countdown; corrected after countdown.
- WinApp CLI parser missed \`hasFocus\` and looked for \`controlType\` instead of \`element.type\`.
- First WRITE script treated nonempty placeholder \`Ask ChatGPT\` as a real draft.
- Later WRITE script asserted \`ACTUAL_NONEMPTY_DRAFT\` based on non-placeholder Value alone without TextPattern corroboration.
- A temporary observer once assigned to PowerShell's read-only \`$PID\`.

**Not proven — do not elevate to fact:**
- That live \`PropertyNotFoundException\` was raised by \`.Equals()\`, \`Identity\`, a particular missing PSCustomObject field, or a UIA getter.
- That Chromium's provider changes Control View ancestry, or that UIA elements are invalidated across captures. Plausible; needs discriminating evidence.
- That same-title pinned session selection gives an immutable conversation identity.
- That \`SetValue()\` will produce visible ProseMirror text, trigger input events, or work without keyboard/clipboard fallback.
- That a visually empty ProseMirror composer has an intrinsically empty \`ValuePattern\` or \`TextPattern\` value.
- That WinApp \`hasFocus=false\` proves no composer existed.
- That an embedded-browser route can identify the current main Desktop conversation.

## 9. Practical next experiments — proposed, **not** performed/approved here

**Preferred immediate test (pending confirmation of any newer local result): known-text replacement.** Human manually selects a **disposable test conversation in the main Desktop**, types exactly \`test\` and leaves it unsent. In one PowerShell 5.1 operation: verify unique foreground ChatGPT window, expected focused enabled \`Edit\` named \`Ask ChatGPT\` belonging to selected process, supported writable ValuePattern, and **exact ordinal Value == \`test\`**; immediately revalidate, then (only with separate explicit authorization) call \`SetValue("BRIDGE TEST - DO NOT SEND")\` **once**, read back exact replacement, and stop. No Send, Enter, draft clearing, retries, or keyboard/clipboard fallback. This deliberately tests a **supervised laboratory feasibility contract**, not production-safe destination binding.

**Separate higher-assurance research:**
- Inspect real local \`Bridge.Doorbell.ps1\` \`Test-BridgeDoorbellSameControls\` call and strict-mode property access inside comparison, especially **actual success and rejected locator result shapes**. A source-review finding must be demonstrated before claiming it fixes live \`PropertyNotFoundException\`.
- Investigate a bounded **C# FlaUI/UIA3** adapter that operates on a *human-selected, already confirmed* element (with explicit foreground and UIA surface checks), as a replacement for fragile PowerShell UIA object interop *only if measured superior*. This is a hypothesis, not a demonstrated fix.
- Evaluate reliable main Document origin independently from pinned-session title and embedded-browser URL; fail closed when main/embedded boundary cannot be proven.
- Only after read/write feasibility: separately authorize controlled Send and response extraction/completion detection, with request IDs, no duplicate Send, ambiguous-result handling and server-ack uncertainty.
- Do not implement a full unattended notification loop or a new automation framework as a prerequisite to a single safe supervised input test.

## 10. Questions for independent AI reviewers

Please answer with **source-evidence references**, **specific reproduction plans**, and **clear fail conditions**. Do not reinterpret a synthetic PASS as live proof.

1. **Why might** \`Test-BridgeDoorbellSameControls\` throw \`PropertyNotFoundException\` while comparing two locator-returned raw \`AutomationElement\` identities under PowerShell 5.1 StrictMode? Which exact statement/property cases should be reproduced with real Windows UIA objects, and how can we distinguish a PowerShell wrapper bug from UIA provider behavior without broad inspection?
2. Can the exact verified \`DocumentElement\`/\`OwnershipEvidence\` created by the successful sidebar selector be handed to the composer locator within **one operation**, and what minimal freshness proof is sufficient before an unsent draft?
3. Which Windows UIA paths can **positively prove main Desktop vs embedded-browser Document ownership** without inspecting sibling browser subtrees? If impossible with current evidence, say so.
4. What exactly does **Chromium ProseMirror** expose through \`ValuePattern\`, \`TextPattern\`, and \`TextEditPattern\`? Under what provider behavior might \`IsReadOnly=false\` coexist with rejected/no-op \`SetValue()\`?
5. How should the experimental *known-\`test\` replacement* classify success? Distinguish successful COM call, exact UIA readback, visual state change, app state synchronization and eventual message submission.
6. Would a small C# FlaUI/UIA3 helper avoid the observed PowerShell 5.1 property failures? What is the **smallest one-shot controlled A/B test**, and what would falsify that explanation?
7. Is there a practical method for **read-only assistant response detection** from the **main Desktop conversation's** accessibility structure without traversing embedded-browser content, and for determining generation completion? Do not assume it has already been tested.
8. How can eventual autonomous notification transport preserve destination correctness under mutable titles, reloads, multi-window state and UIA element invalidation, without relying on the browser URL or an unproven immutable ID?

**Requested response format from other models:**

\`\`\`text
Claim / root-cause hypothesis:
Evidence in this report or linked source:
Unknown information required:
Smallest safe verification experiment:
Expected PASS and FAIL observations:
What must NOT be inferred from PASS:
Windows 10 / PowerShell 5.1 compatibility:
Safety impact / main-vs-embedded-browser constraint:
Concrete code-level proposal (only if evidence supports it):
\`\`\`

## 11. Local commit / offline validation checkpoints

| Reported local commit | Meaning | Publication caveat |
|---|---|---|
| \`d4d5b715\` | Main-sidebar candidate selector | Local-only |
| \`026fec25\`, \`e8ffb21a\`, \`85d3ad58\` | Guarded navigation and revalidation/order corrections | Local-only |
| \`f7a1307a\` | Authorization registry StrictMode initialization | Local-only |
| \`26532989\` | Doorbell dry-run implementation | Local-only |
| \`3688e1b8\` | Early \`ARM\` authorization workflow | Local-only |
| \`9cfcace\` | \`FailureStage\` instrumentation | Local-only |
| \`bb0837da\` | \`FailureStep\` instrumentation | Local-only |
| \`dc52eb3\` | Doorbell control identity-contract hardening; most recently reported clean local HEAD | Local-only |

Full SHAs for two late milestones were reported as \`bb0837da5aa122b69e657866f929e84577f19105\` and \`dc52eb333c2de13118adadcbaf9649520d311324\`. Early README and docs in GitHub main are accurate for their *historical published snapshot*, not current local implementation or live tests. Reported offline suite totals: **261**, **338**, **368**, **377**, **378**, **379** successful assertions at successive checkpoints; later focused temporary scripts passed 6, 7, 8, 9, 13, 21 and 25 synthetic cases in various milestones. Numbers are not aggregated.

## 12. Publication and follow-up

This report was added on a **documentation-only remote branch** to avoid rewriting GitHub \`main\` or colliding with the unpublished local branch. It is a chronological external-review attachment, **not** a claim that the remote code contains late October local modules. Preserve local history and reconcile any newer pending Executor work before merging or backporting. No UI Automation was run and no ChatGPT message was submitted by preparing this report.

**Related historical documents:**
- [Project objective](PROJECT_OBJECTIVE.md)
- [Architecture](ARCHITECTURE.md)
- [Failure and recovery register](FAILURE_AND_RECOVERY_REGISTER.md)
- [Investigation log](INVESTIGATION_LOG.md)
- [Verified findings](VERIFIED_FINDINGS.md)
- [Security and limitations](SECURITY_AND_LIMITATIONS.md)
- [Next milestones](NEXT_MILESTONES.md)
