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
$source=[System.IO.File]::ReadAllText((Join-Path $root 'src/Bridge.Resolve.ps1'))
Assert-ResolveTest ($source.Contains('if(-not $OpenInBrowser)')) 'preflight-by-default present'
Assert-ResolveTest ($source.Contains("Status='PREFLIGHT_PASS'")) 'preflight terminal status present'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'SIDEBAR_TARGET_AMBIGUOUS'")) 'duplicate titles rejected'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'MENU_ITEM_AMBIGUOUS'")) 'menu ambiguity rejected'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'BROWSER_ALREADY_ON_EXPECTED_ID'")) 'initial match must not imply action evidence'
Assert-ResolveTest ($source.Contains('if($obs.ConversationId -ne $expected){continue}')) 'expected ID comparison mandatory'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'TAB_CHANGED_DURING_VERIFICATION'")) 'tab stability check present'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'BROWSER_DESTINATION_CHANGED'")) 'final URL/tab check present'
Assert-ResolveTest ($source.Contains('MainDesktopBound          = $false')) 'cannot claim durable main identity'
Assert-ResolveTest ($source.Contains('MenuItemInvoked           = $false')) 'invocation status starts false'
Assert-ResolveTest ($source.Contains("MessageDeliveryStatus     = 'NOT_ASSESSED'")) 'no acknowledgement invented'
Assert-ResolveTest (-not $source.Contains('SendKeys')) 'no keyboard injection'
Assert-ResolveTest (-not $source.Contains('SetValue(')) 'no composer writing'
[pscustomobject]@{Milestone='BRIDGE.M02-D.13';Test='OfflineResolveAndSyntax';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
