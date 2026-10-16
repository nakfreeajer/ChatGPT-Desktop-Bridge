# Next milestones and decision gates

**Updated:** 2026-10-16, after BRIDGE.M02-E.1B offline safety hardening.

## Current milestone status

| Milestone | Status | Evidence and boundary |
|---|---|---|
| BRIDGE.M00 | COMPLETE | Project boundary and initial records established. |
| BRIDGE.M01 | Browser-route experiments passed for observed embedded-browser scenarios; durable main Desktop binding unresolved. | Browser URL/editor evidence does not bind the main panel. |
| BRIDGE.M02-A | `PASS_CONTROLLED_HAPPY_PATH` | Offline Identity suite 18/18 and supervised inspection/navigation for the specific test state; not unattended-qualified. |
| BRIDGE.M02-B | `PASS_OBSERVED_SCOPE` | Embedded browser tab selection, blank-tab behavior and address association observed. |
| BRIDGE.M02-C | `PASS_CONTROLLED_SINGLE_TAB_NAVIGATION` and `PASS_TWO_TAB_NEGATIVE` | TabGuard offline suite 20/20 and controlled positive/negative browser scenarios. Mid-action race remains unqualified. |
| BRIDGE.M02-D.1–12 | `PASS_CONTROLLED_OBSERVATION` | Menu mechanisms and browser ID comparison observed separately; no permanent main Desktop binding. |
| BRIDGE.M02-D.13 | `PASS_CONTROLLED_INTEGRATED` through M02-D.15P | One supervised launcher run verified menu invocation, expected browser ID/document and stable selected tab. The observed transition activated an existing tab. |
| BRIDGE.M02-D.15E | Offline-qualified at that milestone; its corrected menu path was included in later supervised M02-D.15P. | Single Expand, document-scoped `Chat actions` ancestry, unique visible/invokable item and fresh target checks. |
| BRIDGE.M02-D.15I | Offline-qualified at that milestone; shared bounded address reader was exercised by later M02-D.15P. | One focus per read, bounded poll, selected-tab snapshots and separate expected-ID comparison. |
| BRIDGE.M02-D.15N | `OFFLINE_QUALIFIED`; commit `8231d97f1cd276b76d0fd2a70bdc5133995d3277`. | Corrected browser-document horizontal containment while preserving identity, title, visibility, placement, width and uniqueness checks. |
| BRIDGE.M02-D.15O | `LIVE_DOCUMENT_VERIFIED` | Read-only live UIA check found exactly one qualifying ARM browser document and stable selected tab. |
| BRIDGE.M02-D.15P | `PASS_CONTROLLED_INTEGRATED` (human-run, Architect accepted) | Existing ARM browser tab activated; expected browser identity/document and tab stability verified. `MainDesktopBound=false`; no chat message submitted. |
| BRIDGE.M02-E.1B | IMPLEMENTED_OFFLINE_QUALIFIED | Top-level ChatGPT window enumeration/selection, operation-local HWND/process revalidation, and ambiguity/change regressions passed offline. Native enumeration and all live UIA behavior remain unqualified. |

Current offline regression baseline: Identity 18/18, TabGuard 20/20, Resolve 97/97, SupervisedLauncher 44/44, WindowGuard 17/17; **196/196**.

## Remaining gates

- Durable binding from a chosen main Desktop conversation to its immutable ID; current status **UNRESOLVED**.
- Live qualification of multiple-window routing; duplicate, renamed, reordered, hidden or stale sidebar targets;
- Focus and selected-tab races between verification points; repeated-run and unattended reliability.
- Post-navigation page-readiness status specificity. Cloudflare was reported during one failed run, but its causal role is **unproven**; no challenge detection or bypass is implemented.
- Any future chat-message insertion/submission requires separate approval, disposable targets, identity and authorization review, delivery semantics, duplicate protection, and ambiguous-outcome recovery. Message submission is not implemented or authorized.

## Proposed future work

M03 guarded delivery, M04 result/duplicate handling, M05 lifecycle qualification, M06 a minimal local interface and M07 release documentation remain **proposed, not approved**. This document creates no implementation or live-test authorization.

## Decision register

- **Approved to date:** documentation bootstrap, M02-A navigation-only prototype, M02-C selected-tab safety, and bounded M02-D menu-to-browser-ID integration without message submission.
- **Not approved:** chat-message submission, full production routing, unattended operation, background monitoring, other repositories, provisioning or security-setting changes.
- **Next checkpoint:** Architect review of the consolidated evidence and the remaining identity-binding limitations. No further live UI operation is scheduled by this record.

For the complete chronology and source-specific failure diagnoses, see [FAILURE_AND_RECOVERY_REGISTER.md](FAILURE_AND_RECOVERY_REGISTER.md).
