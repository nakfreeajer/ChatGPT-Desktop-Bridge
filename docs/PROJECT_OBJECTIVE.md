# Project objective and boundary

**Project:** ChatGPT Desktop Bridge  
**Evidence date:** 2026-10-16
**Stage:** Experimental proof of concept; one supervised integrated browser-identity run passed, but durable main Desktop identity binding and message delivery remain unqualified.

## Objective

Build a small, reusable, Windows-local automation bridge that can interact with *existing* ChatGPT Desktop conversations through Microsoft Windows UI Automation (UIA), without depending on Chrome DevTools Protocol (CDP) or OpenAI API calls.

The eventual interface may: discover running ChatGPT Desktop windows; enumerate existing conversations; select a designated conversation; verify the destination using a durable binding; insert and submit an explicitly authorized message; prevent duplicate submissions; and return deterministic results to an external caller.

These are **desired future capabilities**, not an assertion of implementation or production qualification.

## Responsibility split

| Component | Responsibility |
|---|---|
| ChatGPT Desktop Bridge | Window/conversation discovery, verified destination selection, authorized UI interaction, transport result |
| External Orchestrator | Workflow instructions, approval/authorization policy, task routing, task state |
| Artifact Relay Manager | Google Drive artifact-change monitoring and notifications |
| Human owner / Architect | Approval of scope; assessment of experimental evidence and release gates |

**Not in scope:** implementation or modification of other projects, workflow policy engines, Google Drive polling, AI decision logic, CDP port configuration, OpenAI API integration, credentials, or unattended execution before qualification.

## Required behavior for eventual bridge

1. **Select one intended destination** using something stronger than a displayed title alone.
2. **Verify identity** close to the moment of any Send invocation; detect ambiguity and fail closed.
3. Perform only the **authorized interaction**; no unsolicited submission.
4. **Report status honestly**, separating UI action attempted, UI-visible evidence, and server-side acknowledgement. Do not claim stronger delivery than observed.
5. Support caller-provided request IDs and **safe duplicate protection**; an ambiguous result must not trigger a blind retry.
6. Treat multiple windows, renamed titles, inaccessible sessions, UI changes, and app restarts as explicit failure cases until qualified.

## Minimum future acceptance gates

- A conversation ID can be bound to the correct Desktop navigation target without relying solely on a title.
- Negative tests reject duplicate names, wrong active window, missing target, and mismatched browser/Desktop conversation.
- Authorized controlled sends use a disposable conversation and have independently reviewed evidence.
- Duplicate-request and ambiguous-result behavior is characterized without producing duplicate messages.
- Supported app versions, interactive-session requirements, restart behavior, and terms/security limitations are documented.

The M02-D.15P controlled browser-verification run does not satisfy these production acceptance gates: it does not establish permanent main Desktop identity binding, race/lifecycle reliability, or message-delivery semantics.
