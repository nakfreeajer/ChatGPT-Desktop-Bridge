# BRIDGE.M02-D.13 offline guards. No application, UIA, menu, tab, browser or chat actions.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$files=@(
    (Join-Path $root 'src/Bridge.Identity.ps1'),
    (Join-Path $root 'src/Bridge.TabGuard.ps1'),
    (Join-Path $root 'src/Bridge.Resolve.Helpers.ps1'),
    (Join-Path $root 'src/Bridge.Resolve.ps1'),
    $PSCommandPath
)
$checks=0
foreach($file in $files){
    $tokens=$null
    $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if($null -ne $errors -and @($errors).Count -gt 0){
        throw ('PARSE_FAILED: '+(Split-Path $file -Leaf)+' '+$errors[0].Message)
    }
    $checks++
}
. (Join-Path $root 'src/Bridge.Resolve.Helpers.ps1')
function Assert-ResolveTest {
    param([bool]$IsTrue,[string]$Description)
    $script:checks++
    if(-not $IsTrue){throw ('ASSERTION_FAILED: '+$Description)}
}
$old=[pscustomobject]@{RuntimeKey='1:2:3';VisibleCount=2}
$same=[pscustomobject]@{RuntimeKey='1:2:3';VisibleCount=2}
$new=[pscustomobject]@{RuntimeKey='1:2:4';VisibleCount=3}
$existing=[pscustomobject]@{RuntimeKey='1:2:4';VisibleCount=2}
$closed=[pscustomobject]@{RuntimeKey='1:2:4';VisibleCount=1}
$extra=[pscustomobject]@{RuntimeKey='1:2:4';VisibleCount=4}
$invalid=[pscustomobject]@{RuntimeKey='';VisibleCount=2}
Assert-ResolveTest ((Get-BridgeTabTransition $old $same) -eq 'REUSED_SELECTED_TAB') 'same tab'
Assert-ResolveTest ((Get-BridgeTabTransition $old $new) -eq 'NEW_TAB') 'new tab'
Assert-ResolveTest ((Get-BridgeTabTransition $old $existing) -eq 'EXISTING_TAB_ACTIVATED') 'previously existing tab selected'
Assert-ResolveTest ((Get-BridgeTabTransition $null $same) -eq 'BROWSER_OPENED') 'no initial browser'
Assert-ResolveTest ((Get-BridgeTabTransition $old $closed) -eq 'AMBIGUOUS_TAB_TRANSITION') 'tab closure rejected'
Assert-ResolveTest ((Get-BridgeTabTransition $old $extra) -eq 'AMBIGUOUS_TAB_TRANSITION') 'two new tabs rejected'
Assert-ResolveTest ((Get-BridgeTabTransition $old $null) -eq 'POST_TAB_UNVERIFIED') 'missing post tab rejected'
Assert-ResolveTest ((Get-BridgeTabTransition $old $invalid) -eq 'POST_TAB_UNVERIFIED') 'invalid post tab rejected'
Assert-ResolveTest ((Get-BridgeTabTransition $invalid $same) -eq 'BASELINE_TAB_UNVERIFIED') 'invalid baseline rejected'
Assert-ResolveTest ((Get-BridgeTabTransition $old ([pscustomobject]@{RuntimeKey='1:2:3';VisibleCount=3})) -eq 'AMBIGUOUS_TAB_TRANSITION') 'new count but old key rejected'
Assert-ResolveTest (Test-BridgeTitleInput 'Artifact Relay Manager') 'valid title'
Assert-ResolveTest (-not (Test-BridgeTitleInput '')) 'blank title'
Assert-ResolveTest (-not (Test-BridgeTitleInput '  ')) 'whitespace title'
Assert-ResolveTest (-not (Test-BridgeTitleInput ("Bad"+[char]10+"Title"))) 'newline rejected'
Assert-ResolveTest (-not (Test-BridgeTitleInput ('x'*121))) 'overlength title'
$menuSnapshot=[pscustomobject]@{
    DocumentVerified=$true;ExpandCollapseState='Expanded';TargetRowCount=1;ActionButtonCount=1;TargetStable=$true;ControlsFresh=$true
    MenuContainerCount=1;MenuCandidateCount=1;CorrectMenuAncestry=$true
    ItemVisible=$true;ItemEnabled=$true;ItemInvokable=$true
}
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $menuSnapshot) -eq 'OK') 'expanded state permits valid associated menu'
$collapsedSnapshot=$menuSnapshot | Select-Object *
$collapsedSnapshot.ExpandCollapseState='Collapsed'
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $collapsedSnapshot) -eq 'OK') 'collapsed state permits verified visible-menu postcondition'
$case=$menuSnapshot | Select-Object *; $case.MenuCandidateCount=0
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_OWNERSHIP_UNVERIFIED') 'no associated item fails closed'
$case=$menuSnapshot | Select-Object *; $case.DocumentVerified=$false
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_DOCUMENT_MISMATCH') 'item under unrelated document rejected'
$case=$menuSnapshot | Select-Object *; $case.CorrectMenuAncestry=$false
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_OWNERSHIP_UNVERIFIED') 'wrong Chat actions ancestry rejected'
$case=$menuSnapshot | Select-Object *; $case.MenuCandidateCount=2
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_ITEM_AMBIGUOUS') 'duplicate menu candidates rejected'
foreach($field in @('ItemEnabled','ItemVisible','ItemInvokable')){
    $case=$menuSnapshot | Select-Object *; $case.$field=$false
    Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_ITEM_UNAVAILABLE') ($field+' failure rejected')
}
$case=$menuSnapshot | Select-Object *; $case.TargetRowCount=2
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'SIDEBAR_TARGET_AMBIGUOUS') 'duplicate ARM sidebar rows rejected'
$case=$menuSnapshot | Select-Object *; $case.ActionButtonCount=2
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'CHAT_ACTIONS_AMBIGUOUS') 'ambiguous action buttons rejected'
$case=$menuSnapshot | Select-Object *; $case.TargetStable=$false
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_TARGET_CHANGED') 'changed target rejected before invocation'
$case=$menuSnapshot | Select-Object *; $case.ControlsFresh=$false
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_CONTROLS_STALE') 'stale controls rejected before invocation'
$case=$menuSnapshot | Select-Object *; $case.MenuContainerCount=2
Assert-ResolveTest ((Test-BridgeAssociatedMenuSnapshot $case) -eq 'MENU_POPUP_AMBIGUOUS') 'duplicate popup containers rejected'
$source=[System.IO.File]::ReadAllText((Join-Path $root 'src/Bridge.Resolve.ps1'))
Assert-ResolveTest ($source.Contains('if(-not $OpenInBrowser)')) 'preflight-by-default present'
Assert-ResolveTest ($source.Contains("Status='PREFLIGHT_PASS'")) 'preflight terminal status present'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'SIDEBAR_TARGET_AMBIGUOUS'")) 'duplicate titles rejected'
Assert-ResolveTest ($source.Contains('if($menuStatus -ne ''OK'')')) 'associated-menu decision must pass before invocation'
Assert-ResolveTest ($source.Contains('Get-ResolveAssociatedMenu $document')) 'menu item search is scoped to verified main document'
Assert-ResolveTest ($source.Contains('$parent.Current.Name -ceq ''Chat actions''')) 'menu ancestry must include Chat actions'
Assert-ResolveTest ($source.Contains('Get-ResolveAssociatedMenu $freshDocument')) 'menu and target revalidated immediately before invocation'
Assert-ResolveTest ($source.Contains('GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()')) 'only freshly revalidated item is invoked'
Assert-ResolveTest ($source.Contains('MenuStateMismatch         = $false')) 'sanitized state mismatch field is present'
$freshGateAt=$source.IndexOf("if(`$freshStatus -ne 'OK')")
$invokeAt=$source.IndexOf('$freshMenu.Item.GetCurrentPattern')
Assert-ResolveTest ($freshGateAt -ge 0 -and $invokeAt -gt $freshGateAt) 'failed ownership or identity checks precede and prevent invocation'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'BROWSER_ALREADY_ON_EXPECTED_ID'")) 'initial match must not imply action evidence'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'BROWSER_BASELINE_NOT_VERIFIED' 'BROWSER_BASELINE'")) 'invocation requires a verified existing browser conversation'
Assert-ResolveTest ($source.Contains('if($obs.ConversationId -ne $expected){continue}')) 'expected ID comparison mandatory'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'TAB_CHANGED_DURING_VERIFICATION'")) 'tab stability check present'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'BROWSER_DESTINATION_CHANGED'")) 'final URL/tab check present'
Assert-ResolveTest ($source.Contains('MainDesktopBound          = $false')) 'cannot claim durable main identity'
Assert-ResolveTest ($source.Contains('MenuItemInvoked           = $false')) 'invocation status starts false'
Assert-ResolveTest ($source.Contains("MessageDeliveryStatus     = 'NOT_ASSESSED'")) 'no acknowledgement invented'
Assert-ResolveTest (-not $source.Contains('SendKeys')) 'no keyboard injection'
Assert-ResolveTest (-not $source.Contains('SetValue(')) 'no composer writing'
[pscustomobject]@{Milestone='BRIDGE.M02-D.13';Test='OfflineResolveAndSyntax';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
