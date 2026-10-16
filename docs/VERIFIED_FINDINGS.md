# Evidence and verified findings

This is a concise current evidence summary. The detailed chronological failure, recovery, and correction record is [FAILURE_AND_RECOVERY_REGISTER.md](FAILURE_AND_RECOVERY_REGISTER.md); the [investigation log](INVESTIGATION_LOG.md) is its timeline index.

## Evidence labels

- **OBSERVED:** a specific human-reported or executor-observed UI state/result; does not imply general reliability.
- **SOURCE-VERIFIED:** confirmed in current local source; not runtime evidence by itself.
- **OFFLINE-QUALIFIED:** shipped offline assertions pass; they do not interact with ChatGPT Desktop.
- **LIVE-QUALIFIED — CONTROLLED:** one specified supervised UIA or native Win32 scenario completed as reported; not unattended, general-configuration or repeated-cycle qualification.
- **INCONCLUSIVE / HYPOTHESIS:** available evidence does not establish the cause or outcome.
- **UNRESOLVED:** no durable or trustworthy answer is established.

## Current implementation and test evidence

| Claim | Classification | Evidence / boundary |
|---|---|---|
| Identity, TabGuard, resolver, launcher and window-guard offline suites pass. | **OFFLINE-QUALIFIED** | Windows PowerShell 5.1: Identity 18/18, TabGuard 20/20, Resolve 97/97, SupervisedLauncher 44/44, WindowGuard 17/17; **196/196 total**. Synthetic window decisions are covered offline; separate live native enumeration was qualified in one observed Windows 10 configuration. See [PowerShell test commands](POWERSHELL_TEST_COMMANDS.md). |
| The resolver is inspect-only by default; `-OpenInBrowser` is an explicit one-menu-invocation path with title/sidebar/menu ownership checks, supplied expected UUID comparison, selected-tab verification, document verification and transition reporting. | **SOURCE-VERIFIED** | One bounded `Expand()`, document-scoped `Chat actions` menu ancestry, fresh target/menu validation, bounded address reader and corrected horizontal document containment. See [architecture](ARCHITECTURE.md). |
| One human-run M02-D.15P supervised run returned `PASS` / `COMPLETE` / `MENU_TO_BROWSER_ID_VERIFIED`; browser ID/document and tab stability passed. | **LIVE-QUALIFIED — CONTROLLED** | Human-reported; `BrowserTabTransition=EXISTING_TAB_ACTIVATED`, two tabs visible. No new-tab assumption; `MainDesktopBound=false`; no composer write or Send; delivery not assessed. |
| M02-D.15O read-only inspection recognized exactly one qualifying loaded ARM browser document after the geometry correction. | **OBSERVED — EXECUTOR** | One window and address bar, one selected ARM tab among two visible tabs, parser success, stable tab snapshot, and one qualifying browser document. No menu action or navigation. |
| The corrected document geometry handles the observed 228 px left offset without dropping the title, containment, placement, visibility, width or unique-match checks. | **OBSERVED + OFFLINE-QUALIFIED** | M02-D.15M geometry diagnosis and M02-D.15N synthetic regressions; offline aggregate 167/167. The correction was subsequently exercised by M02-D.15O. |
| The top-level window guard and its production selector work for the observed Windows 10 application configuration. | **SOURCE-VERIFIED + OFFLINE-QUALIFIED + LIVE-QUALIFIED — CONTROLLED** | Two complete native snapshots each found 16 ChatGPT-owned top-level windows and exactly one qualifying visible, enabled, ownerless, non-tool, non-child, non-popup candidate; the production selector returned `OK` twice and candidate/process sets were stable. Fifteen auxiliary windows were excluded. The qualifying window had `WS_POPUP=false`, confirming that exclusion is compatible with this observed main window. This is not full resolver/UIA qualification. |

## Historical observations with limits

- The address bar can expose only the origin before focus. A controlled timing run saw the conversation route appear by about 250 ms after one focus operation; the selected tab/count stayed stable. The bounded 2 s / 125 ms reader is **SOURCE-VERIFIED / OFFLINE-QUALIFIED**. Historical failure causality remains unknown.
- A human-opened `Chat actions` popup was observed under a `Menu` named `Chat actions` and the ARM document. This supports document-scoped association in that UI tree; a permanent/direct button-to-popup ownership property was not established.
- A menu that visually opened once was rejected by a state-only resolver check; a later UIA observation established `Expanded` and one valid menu item. The visible-menu postcondition correction preserves the single expansion and fails closed on ambiguous association.
- A loaded ARM browser document once failed the old left-edge tolerance. UIA measurements established that predicate as the cause of that particular false negative. The earlier M02-D.15J `BROWSER_DESTINATION_UNVERIFIED` cause remains unestablished.

## Unresolved and unqualified

- Permanent binding of the separate main Desktop conversation to the expected immutable ID: **UNRESOLVED**. `MainDesktopBound=false` is required.
- Cloudflare as cause of M02-D.15J: **HYPOTHESIS**, not proven. No challenge bypass/automation is implemented.
- General multi-window routing, duplicate, renamed, reordered, hidden or stale sidebar targets; lifecycle, HWND-reuse and timing/race behavior beyond the one live native window configuration. The two snapshots do not establish safety for all changes between resolver stages.
- Message insertion/submission, server receipt, delivery acknowledgement, idempotency, duplicate prevention and uncertain-result recovery: **NOT IMPLEMENTED / NOT QUALIFIED**. No current milestone authorizes message submission.

Never treat offline assertions, a title match, UIA RuntimeId, URL parseability alone, or a one-run controlled PASS as production identity or delivery proof. See the [full register](FAILURE_AND_RECOVERY_REGISTER.md) for the chronology and evidence source for each milestone.
