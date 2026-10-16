# Investigation log

This is the chronological index of project evidence through BRIDGE.M02-D.15P.CLOSE. The canonical failure → diagnosis → correction register is [FAILURE_AND_RECOVERY_REGISTER.md](FAILURE_AND_RECOVERY_REGISTER.md); this file keeps the timeline and current status concise to avoid duplicating that register.

## Chronology

| Milestone | Outcome and evidence | Register |
|---|---|---|
| M01 / M02-A | Focus-dependent browser address reads, autocomplete behavior, browser-only URL/editor checks, and an explicit keyboard-navigation race were observed. Identity tests passed 18/18. | [Early UIA and navigation](FAILURE_AND_RECOVERY_REGISTER.md#1-early-uia-and-browser-route-discoveries) |
| M02-B / M02-C | Main Desktop and embedded browser can show different conversations. Selected `TabItem` state, ephemeral RuntimeId and visible tab count were verified. TabGuard tests passed 20/20; controlled positive and negative browser cases passed. | [Surface separation and tab guard](FAILURE_AND_RECOVERY_REGISTER.md#2-surface-separation-and-selected-tab-guard) |
| M02-D.1–12 | The sidebar `Chat actions` control uses `ExpandCollapsePattern`; the associated `Open on chatgpt.com` menu item uses `InvokePattern`. Early manual and UIA checks established browser-route correlation, not permanent binding. | [Menu mechanism](FAILURE_AND_RECOVERY_REGISTER.md#3-sidebar-menu-discovery-and-integrated-resolver) |
| M02-D.13 / D.14 | Resolver source and offline checks were added; a human-reported read-only preflight passed. Invocation remained separately supervised. | [Integrated resolver](FAILURE_AND_RECOVERY_REGISTER.md#3-sidebar-menu-discovery-and-integrated-resolver) |
| CODEX.ACCESS.1A / BASELINE.1B | Native Windows UIA was available. A separate PowerShell process could not inherit the private baseline ID; the secure in-process launcher replaced manual transfer. | [Executor and secure baseline recovery](FAILURE_AND_RECOVERY_REGISTER.md#4-executor-and-secure-baseline-recovery) |
| M02-D.15 / 15A–15E | UI state and menu-state false negatives were investigated. A document-scoped popup relationship was observed; resolver keeps one `Expand()`, requires the associated visible menu item, and revalidates before its single invocation. Offline suite total reached 127. | [Menu false negative and correction](FAILURE_AND_RECOVERY_REGISTER.md#5-menu-verification-false-negative-and-correction) |
| M02-D.15F–15I | Address-read failures, missing helper dependency and an unexplained blank `ResolverStatus` were investigated. A controlled timing read established delayed URL availability; bounded polling was added. Offline total reached 151. | [Address-read failure and recovery](FAILURE_AND_RECOVERY_REGISTER.md#6-browser-address-read-failure-and-bounded-recovery) |
| M02-D.15J–15K | The resolver returned `BROWSER_DESTINATION_UNVERIFIED`; Cloudflare was reported during page loading. Source review found multiple pending/error paths, but did not establish Cloudflare as the cause. | [Post-invocation readiness](FAILURE_AND_RECOVERY_REGISTER.md#7-post-invocation-readiness-and-cloudflare-hypothesis) |
| M02-D.15L–15N | A loaded ARM page failed the prior document geometry predicate. UIA measurements isolated the 60 px left-edge tolerance as the defect; horizontal containment replaced it. Offline total reached 167. | [Document geometry false negative](FAILURE_AND_RECOVERY_REGISTER.md#8-browser-document-geometry-false-negative-and-fix) |
| M02-D.15O / 15P | Corrected document recognition passed a live read-only UIA check. One human-run supervised integrated qualification passed and activated an existing ARM browser tab. | [Live verification and integrated qualification](FAILURE_AND_RECOVERY_REGISTER.md#9-live-verification-and-integrated-qualification) |

## Current qualification

- Offline Windows PowerShell 5.1 suites: Identity **18/18**, TabGuard **20/20**, Resolve **87/87**, SupervisedLauncher **42/42**; **167/167** total.
- M02-D.15P: `PASS_CONTROLLED_INTEGRATED` for one supervised run. The reported tab transition was `EXISTING_TAB_ACTIVATED`; two tabs were visible. The existing ARM tab became selected.
- `MainDesktopBound=false`. The result is controlled browser identity correlation, not durable identity binding for the separate main Desktop panel.
- Chat message insertion/submission is not implemented in the Bridge and was not authorized. Delivery remains `NOT_ASSESSED`.
- Multiple-window routing, duplicate or renamed conversations, lifecycle changes, focus/tab races, and delivery semantics remain unqualified or unimplemented. Cloudflare causality remains unproven.

See [verified findings](VERIFIED_FINDINGS.md), [architecture](ARCHITECTURE.md), and [security limits](SECURITY_AND_LIMITATIONS.md) for current interpretation.
