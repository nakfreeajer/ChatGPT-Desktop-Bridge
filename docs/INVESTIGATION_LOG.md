# Investigation log

**Evidence date:** 2026-10-15. **Evidence source:** human-run Windows PowerShell console output and visual confirmations, plus a handover from earlier investigation. Items below record what was *observed or reported*; no repository-hosted automatic test suite exists.

## Earlier handover tests (01-08)

| Test | Reported result | Important qualification |
|---|---|---|
| 01. Detect Desktop window | PASS | ChatGPT process/top-level window accessible through UIA |
| 02. Inspect accessibility tree | PASS | Document, Edit, Button, ListItem, Group, MenuBar observed |
| 03. Find active composer | PASS | Visible, enabled Edit was correct; offscreen same-named element was wrong |
| 04. Insert text | PASS | Human observed UIA ValuePattern.SetValue in composer |
| 05. Invoke Send | PASS, human-confirmed | Harmless message sent in already-open conversation; no server-side acknowledgement qualification |
| 06. Discover pinned conversations | PASS | Sidebar accessible via UIA |
| 07. Inspect navigation descendants | PASS | ListItem had child Invoke-capable Button |
| 08. Switch pinned conversation | PASS, human-confirmed | Title-based target worked; no immutable ID verification |

These were proof-of-concept tests, not unattended reliability or production routing tests.

## M01 — conversation identity investigations

1. **Sandbox discovery:** exact match for a proposed disposable test title returned 0. Do not infer it existed or that navigation failed.
2. **Window/tree enumeration:** an existing ChatGPT Desktop window exposed approximately 1,077 elements and 30 ListItems; three known sidebar titles were discoverable. Five partial `Bridge|Sandbox` matches were offscreen non-navigation elements.
3. **Sidebar controls:** for each known title, a ListItem and sidebar Button existed. The active title also appeared separately as a Document/header Button. This demonstrated why names alone are ambiguous.
4. **Sidebar metadata:** AutomationId, HelpText, ItemStatus, ItemType, AccessKey and LabeledBy were blank for three inspected sidebar buttons. Class names largely described shared UI styling. RuntimeIds differed between elements but are **session-scoped UIA identities, not validated durable conversation IDs**.
5. **Container descendants:** an inspected conversation ListItem had four descendants: an Invoke/ScrollItem Button, an ExpandCollapse/ScrollItem Button with a `radix-...` AutomationId, an Invoke/ScrollItem Group and another Invoke/ScrollItem Button. No hyperlink/durable conversation ID was observed.
6. **Built-in browser path:** the Desktop conversation menu displayed **Open on chatgpt.com**. It opened a browser surface inside ChatGPT Desktop. Manually opening the chosen web conversation revealed a `https://chatgpt.com/c/<id>` URL.
7. **Address-control discovery:** with the embedded browser open, a UIA ComboBox named **Search or enter a URL** was discovered. It exposed ValuePattern, TextPattern, ExpandCollapsePattern and ScrollItemPattern, with 0 descendants.
8. **Unfocused address bar:** both ValuePattern and TextPattern returned only `chatgpt.com` (length 11); no conversation ID was present.
9. **Focused address bar:** invoking `SetFocus()` on that ComboBox and reading its ValuePattern and TextPattern produced 58-character values containing a conversation-path identifier (both True).
10. **Known-ID comparison:** extracting the ID from the now-accessible URL and comparing it with the manually captured identifier for the chosen browser conversation returned: `URLDetected=True`, `MatchesKnownCDLD=True`, `URLLength=58`.

**Result:** M01-E focused extraction and M01-F comparison passed as bounded, human-run diagnostics. This does **not** bind the embedded browser to the main ChatGPT Desktop active conversation or prove persistence across restarts.

## Investigation mistakes and corrections

- Avoid selecting by `Name` alone: there were multiple `Ask ChatGPT` controls; choose visible enabled Edit.
- Sidebar ListItem did not expose InvokePattern itself; invoke an identified child Button.
- Avoid malformed PowerShell pipelines directly after `foreach`; two attempts generated `EmptyPipeElement` parser errors and made no UI change.
- Do not name a result array `$matches`: PowerShell's automatic `$Matches` variable is overwritten by `-match`. One apparent URL count was invalid until re-tested with an independent variable and regex Match.
- A metadata command originally labeled `ToString()` as RuntimeId; it was corrected using `GetRuntimeId()`.
- Address-bar ValuePattern and TextPattern must be read independently; treating one as a fallback concealed evidence initially.
- Initial exploratory PowerShell multi-line paste and Point-constructor attempts caused errors. Prefer bounded single-line interactive commands, properly validated before use.

## Environment observed in handover

- Windows desktop application: ChatGPT.exe; package reported as OpenAI.Codex_26.1007.2314.0_x64.
- WebView2 component reported as 155.0.4283.45.
- Win32 process ID and window handles varied by session and must never be hardcoded.
- No CDP remote-debugging arguments were found in the inspected processes. Do not generalize this into a universal assertion about all available interfaces.

## Unresolved

Automatic ID-to-sidebar binding, duplicate titles, multiple windows, selection/read race, application restarts, lifecycle robustness, locked Windows session, safe delivery acknowledgement, idempotency, unattended reliability, and supported integration/terms status.
