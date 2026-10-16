# Security, privacy and qualification limits

## Current status

This is an experimental UI Automation proof of concept for a logged-in interactive Windows session. One human-supervised M02-D.15P menu-to-browser-ID run passed; this does not qualify unattended operation, a supported product integration, or production message transport. See the [failure/recovery register](FAILURE_AND_RECOVERY_REGISTER.md) for the evidence chronology.

## Identity and UIA safeguards

- The resolver requires an independently supplied expected conversation UUID and exact visible main/sidebar title checks. The title is mutable and may be duplicated; it is not a durable ID.
- The main Desktop document and embedded browser document are separate surfaces. A browser URL proves only the browser route. `MainDesktopBound=false` must remain in all results unless separate durable binding evidence is established.
- The menu path preserves one `Expand()` on the verified `Chat actions` button. The `Open on chatgpt.com` item is scoped to the verified document and `Chat actions` Menu ancestry, required to be unique/visible/enabled/invokable, and refreshed with the target before its single invocation.
- The browser tab RuntimeId/window handle are ephemeral in-memory tokens only. The resolver checks one selected tab and visible-tab count around address reads and before success; they are not persistent identity.
- The resolver enumerates top-level windows and accepts only a visible, enabled, ownerless ChatGPT window that is not a tool, child or popup window. It rejects incomplete enumeration and rechecks the chosen HWND/process before expansion and invocation. HWND/process evidence remains operation-local and is not conversation identity.
- A parsed conversation URL must equal the independently supplied expected UUID. A title or parseable URL alone does not pass identity verification.
- The corrected browser-document geometry requires a visible exact-title RootWebArea Document that contains the address bar horizontally, lies below it, and passes width bounds; exactly one must qualify. Geometry and title remain supporting UI evidence, not permanent main-panel binding.

## Private baseline handling

`Bridge.Resolve.Supervised.ps1` requests the expected ARM UUID with `Read-Host -AsSecureString`, validates it in the current Windows PowerShell process, clears its temporary BSTR and calls the resolver in-process. It provides separate preflight-only and invocation modes; invocation requires a different selected-browser baseline and exact human confirmation `OPEN` before one resolver call. Its sanitized report omits UUIDs and URLs.

Do not put private UUIDs or conversation URLs in source, arguments, environment variables, temporary files, transcripts, logs, test fixtures or reports. Never copy chat content, credentials, cookies or other private content into this repository. Do not broaden permissions, elevate, enable CDP, use Playwright or call the OpenAI API to work around a UIA limit.

## UI actions, focus and page readiness

- `-OpenInBrowser` is a browser/navigation UI mutation, though it does not send a chat message. Obtain explicit human approval for each supervised run and stop on any unexpected condition. Do not automatically retry.
- Reading the complete address may require `SetFocus()`. This changes UI focus. The bounded reader polls without further focus changes and fails closed on tab change, stale/invalid controls or ambiguity.
- `Bridge.Navigate.ps1` is a separate legacy browser-navigation experiment. Its opt-in Enter action has a time-of-check/time-of-use global focus race. It does not insert or send chat text.
- The post-invocation loop uses a finite timeout and checks URL identity, document and tab state. Some pending/error paths have different timeout behavior and can converge on a generic failure result; do not infer a particular cause from `BROWSER_DESTINATION_UNVERIFIED` alone.
- Cloudflare was reported during one page load, but its causal role in that failure is **unproven**. The Bridge does not detect, automate, bypass or interfere with security challenges.

## Not qualified or not implemented

- Live qualification of the top-level window enumerator; duplicate, renamed, reordered, hidden or stale sidebar targets; app/session lifecycle changes.
- Restarts, updates, session lock/unlock, app lifecycle changes, accessibility tree changes and browser tab/focus races between checks.
- General reliability or unattended operation beyond the one controlled M02-D.15P scenario.
- Durable binding from the main Desktop panel/sidebar element to an immutable conversation ID.
- Chat message insertion/submission, server receipt, delivery acknowledgement, request idempotency, duplicate prevention or uncertain-send recovery. Message delivery remains `NOT_ASSESSED`; no message submission is authorized.

Prefer a visible failure to acting on an uncertain destination. An invoked UIA control is not proof of server-side success. Do not blindly retry an ambiguous operation.
