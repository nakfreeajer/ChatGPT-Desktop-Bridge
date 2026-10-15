# Evidence and verified findings

**Evidence grading:** “Observed” means user-provided command output or visual confirmation on 2026-10-15; “handover” means earlier session evidence described in the uploaded handover; “unverified” means not established by either. The repository's documentation does not independently execute tests.

| Finding | Evidence | Boundary |
|---|---|---|
| UIA exposed top-level ChatGPT window and web-view accessibility tree | Handover + observed later enumerations | Live session only; PID/window handle ephemeral |
| Sidebar ListItem/child Button representation supports invoking navigation | Handover, observed metadata | No durable target ID found |
| Visible Edit composer supports insertion; Send Button InvokePattern can submit | Handover, human-confirmed | Already-open destination only; no production-safe routing |
| Three known pinned conversations appeared as ListItem and Button, with active title elsewhere too | Observed | Title matching alone ambiguous |
| Sidebar Button AutomationId/HelpText/ItemStatus/ItemType/AccessKey/LabeledBy were empty | Observed | Applies to three inspected buttons, not all versions |
| UIA RuntimeId values differed | Observed | Not proven stable across controls, navigation, restart, or updates |
| Embedded browser could show a conversation-specific `/c/<uuid-style-id>` path | Observed manually | Opening web view can be independent of main Desktop conversation |
| Embedded address ComboBox supported ValuePattern and TextPattern | Observed | Not proof of address value completeness until focused |
| Address value while unfocused was `chatgpt.com` (11 chars) in both patterns | Observed | Specific inspected browser state |
| Address value after UIA SetFocus was 58 chars, both patterns matching conversation URL | Observed | Focus changes UI state; not a permanently readable background value |
| Extracted browser ID matched previously manually captured ID | Observed | Verifies known browser conversation only; not sidebar identity binding |

## Confidence rules

- **PASS — experimental:** A specific human-run diagnostic produced the expected result in the observed session.
- **NOT FOUND:** A property or identifier was not exposed in the inspected controls; this is not proof no other possible identity mechanism exists.
- **BLOCKED:** Production routing cannot proceed without destination verification.
- **UNVERIFIED:** Neither a successful nor failed qualification was performed.

## Explicitly not verified

- That the main Desktop conversation and embedded browser conversation are the same.
- That the embedded browser can always be opened, controlled, or trusted unattended.
- That a title, CSS class, UIA RuntimeId, radial-generated AutomationId, or inferred sidebar order is a durable conversation key.
- That a conversation-specific URL remains stable across session termination, app restart, rename, or platform changes; the format and one same-session known-ID comparison were demonstrated, not lifecycle persistence.
- That a UIA Send invocation proves receipt by ChatGPT services or ensures no duplicates.
- That using UIA for this purpose is officially supported or permitted under every relevant application term.

## Privacy in evidence

The actual manually observed conversation identifier, user-specific project names, full UI content, message bodies, and personal data are deliberately omitted from public source-controlled logs. Use placeholders in reproducibility examples.
