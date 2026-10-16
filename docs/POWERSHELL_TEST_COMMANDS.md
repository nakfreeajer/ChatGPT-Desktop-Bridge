# PowerShell diagnostics — evidence and safe references

## BRIDGE.CODEX.BASELINE.1B launcher (offline qualification only)

From the repository root, run the offline suite:

~~~powershell
.\tests\Identity.Offline.Tests.ps1
.\tests\TabGuard.Offline.Tests.ps1
.\tests\Resolve.Offline.Tests.ps1
.\tests\SupervisedLauncher.Offline.Tests.ps1
~~~

The supervised launcher has two entry modes, each requiring an interactive terminal and a hidden UUID prompt. Preflight only:

~~~powershell
.\src\Bridge.Resolve.Supervised.ps1 -PreflightOnly
~~~

Separately confirmed menu invocation (not run as part of offline qualification):

~~~powershell
.\src\Bridge.Resolve.Supervised.ps1 -ConfirmOpenInBrowser
~~~

The second mode performs a read-only resolver preflight and a selected-browser ID mismatch check before prompting for exact confirmation `OPEN`. It invokes the menu once only after that confirmation. Stop if any precondition or verification fails. The UUID is entered with `Read-Host -AsSecureString`; do not paste it into a command line or save it in a file, environment variable, transcript, or log.

**Documentation only.** The diagnostics below are reference commands from the 2026-10-15 investigation, not Bridge source code or an unattended runner. No code there is executed by the repository.

## Preconditions

- Windows PowerShell 5.1 with UIAutomationClient and UIAutomationTypes available.
- Exactly one ChatGPT process with a nonzero MainWindowHandle for these narrow tests.
- Main ChatGPT Desktop window and, for the URL tests, its embedded browser with the intended conversation already opened by a human.
- A **disposable** test conversation if any future interaction experiment is approved. The commands below do not send messages.
- Do not print, paste into logs, or commit private conversation IDs, URLs, tokens, cookies, or message contents.
- For multi-window or uncertain targets, **stop**. These examples intentionally do not handle that condition.

## 1. Read-only: discover navigation element metadata

The observed tests searched UIA descendants, matched existing sidebar titles, and printed ControlType, AutomationId, ClassName, FrameworkId, IsOffscreen, and GetRuntimeId(). Names may also appear outside the sidebar, so constrain to a known ListItem/descendant Button and never equate a title or RuntimeId with a permanent conversation key.

Representative diagnostic (sanitized titles and formatting; not separately re-executed from this document):

~~~powershell
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; $p=@(Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0}); if($p.Count -ne 1){throw "Expected exactly one main window"}; $r=[System.Windows.Automation.AutomationElement]::FromHandle($p[0].MainWindowHandle); $items=$r.FindAll([System.Windows.Automation.TreeScope]::Descendants,[System.Windows.Automation.Condition]::TrueCondition); Write-Host "TOTAL ELEMENTS:" $items.Count; $list=@($items | Where-Object {$_.Current.ControlType -eq [System.Windows.Automation.ControlType]::ListItem}); Write-Host "LIST ITEMS:" $list.Count
~~~

## 2. Read-only except keyboard focus: focused address-bar pattern comparison

**Observed PASS.** In the experiment, a UIA ComboBox named `Search or enter a URL` in the embedded browser exposed only `chatgpt.com` (11 characters) through ValuePattern and TextPattern when unfocused. After `SetFocus()`, both returned a 58-character full conversation URL. The following is the corrected, successfully run one-line form from the investigation. It prints *only* length and whether an ID-shaped path was found:

~~~powershell
Add-Type -AssemblyName UIAutomationClient; Add-Type -AssemblyName UIAutomationTypes; $p=@(Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0}); if($p.Count -ne 1){throw "Expected one main window; found $($p.Count)"}; $r=[System.Windows.Automation.AutomationElement]::FromHandle($p[0].MainWindowHandle); $c=New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty,[System.Windows.Automation.ControlType]::ComboBox); $a=$r.FindAll([System.Windows.Automation.TreeScope]::Descendants,$c); $m=@($a | Where-Object {$_.Current.Name -eq 'Search or enter a URL'}); if($m.Count -ne 1){throw "Expected one address bar; found $($m.Count)"}; $e=$m[0]; $before=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value; if($before -ne 'chatgpt.com'){throw "Unexpected address value; test stopped"}; $e.SetFocus(); Start-Sleep -Milliseconds 300; $results=@(); foreach($mode in @('Value','Text')){$s=''; if($mode -eq 'Value'){$s=$e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value}else{$s=$e.GetCurrentPattern([System.Windows.Automation.TextPattern]::Pattern).DocumentRange.GetText(-1)}; $results += [pscustomobject]@{Pattern=$mode;Length=([string]$s).Length;HasConversationID=[regex]::IsMatch([string]$s,'(?i)chatgpt\.com/c/[0-9a-f-]{36}')}}; $results | Format-Table -AutoSize
~~~

Expected *observed* result from the 2026-10-15 run:

~~~text
Pattern Length HasConversationID
Value       58              True
Text        58              True
~~~

## 3. Known-ID comparison (sanitized reproducibility note)

The subsequent experiment read the focused ComboBox's ValuePattern, regex-extracted an ID from `/c/<uuid>`, and compared it to a previously manually recorded identifier for the **embedded-browser** conversation. It reported:

~~~text
URLDetected      : True
MatchesKnownCDLD : True
URLLength        : 58
~~~

The actual identifier and exact unredacted validation command are intentionally **not** committed to this public repository. A safe future diagnostic should take an expected ID from a local, non-logged test input, normalize the URL, reject malformed or multiple matches, and display only a boolean match result.

**This comparison is not identity binding to the main Desktop sidebar.** Web browser tab selection and Desktop conversation selection can diverge.

## Known errors to avoid

- Never use `$matches` as an accumulation array while using PowerShell `-match`; it collides with automatic `$Matches`.
- Do not pipe directly from a `foreach` language statement; collect into `$results` and pipe *that* to `Format-Table`.
- Do not label `$element.ToString()` as `RuntimeId`; obtain it with `GetRuntimeId()`.
- Do not select the first `Ask ChatGPT` by name; the correct composer was a visible, enabled Edit.
- Do not assume an inactive address bar exposes the full path.
- Do not infer server-side acknowledgement from a successful button Invoke.
