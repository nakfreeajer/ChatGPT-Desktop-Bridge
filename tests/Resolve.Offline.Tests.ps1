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
. (Join-Path $root 'src/Bridge.Identity.ps1')
. (Join-Path $root 'src/Bridge.TabGuard.ps1')
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
$windowRect=[pscustomobject]@{Left=4;Top=53;Right=1880;Bottom=1050;Width=1876;Height=997}
$addressRect=[pscustomobject]@{Left=1256;Top=185;Right=1647;Bottom=221;Width=391;Height=36}
$observedBrowserRect=[pscustomobject]@{Left=1028;Top=233;Right=1877;Bottom=1046;Width=849;Height=813}
$observedMainRect=[pscustomobject]@{Left=4;Top=53;Right=1881;Bottom=1051;Width=1877;Height=998}
Assert-ResolveTest (Test-BridgeBrowserDocumentCandidate -DocumentTitle 'Artifact Relay Manager' -ExpectedTitle 'Artifact Relay Manager' -IsVisible $true -IsDocument $true -IsRootWebArea $true -DocumentRect $observedBrowserRect -AddressBarRect $addressRect -WindowRect $windowRect) 'observed ARM browser document contains address bar and passes candidate checks'
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $observedMainRect $addressRect $windowRect)) 'observed main Desktop document rejected by browser geometry'
$extendsLeftRect=[pscustomobject]@{Left=900;Top=230;Right=1700;Bottom=900;Width=800;Height=670}
Assert-ResolveTest (Test-BridgeBrowserDocumentGeometry $extendsLeftRect $addressRect $windowRect) 'browser document may extend left when it contains address bar bounds'
$notContainingRect=[pscustomobject]@{Left=1300;Top=230;Right=1700;Bottom=900;Width=400;Height=670}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $notContainingRect $addressRect $windowRect)) 'document not containing address bar horizontally rejected'
$aboveAddressRect=[pscustomobject]@{Left=900;Top=100;Right=1700;Bottom=180;Width=800;Height=80}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $aboveAddressRect $addressRect $windowRect)) 'document above address bar rejected'
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentCandidate -DocumentTitle 'Other title' -ExpectedTitle 'Artifact Relay Manager' -IsVisible $true -IsDocument $true -IsRootWebArea $true -DocumentRect $observedBrowserRect -AddressBarRect $addressRect -WindowRect $windowRect)) 'incorrect document title rejected'
$offscreenRect=[pscustomobject]@{Left=900;Top=230;Right=1700;Bottom=900;Width=800;Height=670;IsOffscreen=$true}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentCandidate -DocumentTitle 'Artifact Relay Manager' -ExpectedTitle 'Artifact Relay Manager' -IsVisible $false -IsDocument $true -IsRootWebArea $true -DocumentRect $offscreenRect -AddressBarRect $addressRect -WindowRect $windowRect)) 'offscreen document rejected'
$duplicateQualifiers=@(
    (Test-BridgeBrowserDocumentGeometry $observedBrowserRect $addressRect $windowRect),
    (Test-BridgeBrowserDocumentGeometry $extendsLeftRect $addressRect $windowRect)
)
Assert-ResolveTest (@($duplicateQualifiers | Where-Object {$_}).Count -ne 1) 'duplicate qualifying browser documents remain ambiguous'
$invalidRect=[pscustomobject]@{Left=10;Top=10;Right=10;Bottom=20;Width=0;Height=10}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $invalidRect $addressRect $windowRect)) 'empty or invalid rectangle rejected'
$inconsistentRect=[pscustomobject]@{Left=0;Top=0;Right=100;Bottom=100;Width=99;Height=100}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $inconsistentRect $addressRect $windowRect)) 'inconsistent rectangle bounds rejected'
$missingRect=[pscustomobject]@{Left=0;Top=0;Right=100;Bottom=100;Width=100}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $missingRect $addressRect $windowRect)) 'missing rectangle dimension rejected'
$nanRect=[pscustomobject]@{Left=[double]::NaN;Top=0;Right=100;Bottom=100;Width=100;Height=100}
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentGeometry $nanRect $addressRect $windowRect)) 'non-finite rectangle rejected'
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentCandidate -DocumentTitle 'Artifact Relay Manager' -ExpectedTitle 'Artifact Relay Manager' -IsVisible $true -IsDocument $false -IsRootWebArea $true -DocumentRect $observedBrowserRect -AddressBarRect $addressRect -WindowRect $windowRect)) 'non-Document control rejected'
Assert-ResolveTest (-not (Test-BridgeBrowserDocumentCandidate -DocumentTitle 'Artifact Relay Manager' -ExpectedTitle 'Artifact Relay Manager' -IsVisible $true -IsDocument $true -IsRootWebArea $false -DocumentRect $observedBrowserRect -AddressBarRect $addressRect -WindowRect $windowRect)) 'non-RootWebArea document rejected'
$tabBase=[pscustomobject]@{Status='OK';RuntimeKey='offline:tab:1';VisibleCount=2}
$conversationUrl='https://chatgpt.com/c/11111111-2222-3333-4444-555555555555'
$script:addressReads=0
$immediateReader={ [void]($script:addressReads++); $conversationUrl }
$stableReader={ [pscustomobject]@{Status='OK';RuntimeKey='offline:tab:1';VisibleCount=2} }
$read=Get-BridgeConversationAddress -ReadAddress $immediateReader -ReadTab $stableReader -Baseline $tabBase -TimeoutMilliseconds 100 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'OK' -and $script:addressReads -eq 1) 'conversation URL available immediately'
$script:addressReads=0
$script:addressSequence=@('https://chatgpt.com/',$conversationUrl)
$delayedReader={ $i=[Math]::Min($script:addressReads,$script:addressSequence.Count-1); [void]($script:addressReads++); $script:addressSequence[$i] }
$read=Get-BridgeConversationAddress -ReadAddress $delayedReader -ReadTab $stableReader -Baseline $tabBase -TimeoutMilliseconds 250 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'OK' -and $script:addressReads -eq 2) 'origin-only value then delayed conversation URL'
Assert-ResolveTest ((Test-BridgeConversationId $read.ConversationId) -and -not [string]::Equals($read.ConversationId,'22222222-3333-4444-5555-666666666666',[System.StringComparison]::OrdinalIgnoreCase)) 'parseable different conversation remains distinguishable from expected ID'
$script:addressReads=0
$originReader={ [void]($script:addressReads++); 'https://chatgpt.com/' }
$read=Get-BridgeConversationAddress -ReadAddress $originReader -ReadTab $stableReader -Baseline $tabBase -TimeoutMilliseconds 30 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'BROWSER_CONVERSATION_URL_TIMEOUT' -and $script:addressReads -gt 1) 'origin-only value times out boundedly'
foreach($badAddress in @('', 'not-a-url')){
    $script:badValue=$badAddress
    $badReader={ [string]$script:badValue }
    $read=Get-BridgeConversationAddress -ReadAddress $badReader -ReadTab $stableReader -Baseline $tabBase -TimeoutMilliseconds 15 -PollIntervalMilliseconds 5
    Assert-ResolveTest ($read.Status -eq 'BROWSER_CONVERSATION_URL_TIMEOUT') 'empty or invalid address rejected at timeout'
}
$script:tabCalls=0
$changingTabReader={
    [void]($script:tabCalls++)
    if($script:tabCalls -ge 2){[pscustomobject]@{Status='OK';RuntimeKey='offline:tab:changed';VisibleCount=2}}
    else{[pscustomobject]@{Status='OK';RuntimeKey='offline:tab:1';VisibleCount=2}}
}
$read=Get-BridgeConversationAddress -ReadAddress $immediateReader -ReadTab $changingTabReader -Baseline $tabBase -TimeoutMilliseconds 100 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'TAB_CHANGED_DURING_ADDRESS_READ') 'selected tab RuntimeId change fails immediately'
$script:tabCalls=0
$countChangingReader={
    [void]($script:tabCalls++)
    if($script:tabCalls -ge 2){[pscustomobject]@{Status='OK';RuntimeKey='offline:tab:1';VisibleCount=3}}
    else{[pscustomobject]@{Status='OK';RuntimeKey='offline:tab:1';VisibleCount=2}}
}
$read=Get-BridgeConversationAddress -ReadAddress $immediateReader -ReadTab $countChangingReader -Baseline $tabBase -TimeoutMilliseconds 100 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'TAB_CHANGED_DURING_ADDRESS_READ') 'visible tab count change fails immediately'
$unavailableReader={ throw 'stale address control' }
$read=Get-BridgeConversationAddress -ReadAddress $unavailableReader -ReadTab $stableReader -Baseline $tabBase -TimeoutMilliseconds 100 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'BROWSER_ADDRESS_UNAVAILABLE') 'unavailable address control fails immediately'
$read=Get-BridgeConversationAddress -ReadAddress $immediateReader -ReadTab $stableReader -Baseline $tabBase -TimeoutMilliseconds 100 -PollIntervalMilliseconds 5
Assert-ResolveTest ($read.Status -eq 'OK' -and $read.Tab.VisibleCount -eq 2) 'stable tab metadata returned with parsed address'
$helpers=[System.IO.File]::ReadAllText((Join-Path $root 'src/Bridge.Resolve.Helpers.ps1'))
$pollStart=$helpers.IndexOf('function Get-BridgeConversationAddress')
$pollSource=$helpers.Substring($pollStart)
Assert-ResolveTest (-not $pollSource.Contains('SetFocus')) 'bounded address polling never changes focus'
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
Assert-ResolveTest ($source.Contains('Test-BridgeBrowserDocumentCandidate -DocumentTitle ([string]$d.Current.Name)')) 'browser document uses tested candidate predicate'
Assert-ResolveTest ($source.Contains('return ($found -eq 1)')) 'exactly one qualifying browser document required'
Assert-ResolveTest ($source.Contains('Get-BridgeConversationAddress -ReadAddress $addressReader -ReadTab $tabReader')) 'resolver uses bounded stable-tab address reader'
Assert-ResolveTest ($source.Contains("-TimeoutMilliseconds 2000 -PollIntervalMilliseconds 125")) 'resolver address polling bounded to two seconds'
Assert-ResolveTest ($source.Contains('Get-ResolveBrowserObservation -Handle $handle -Root $root -FocusAddress')) 'resolver explicitly focuses once before baseline address read'
Assert-ResolveTest ($source.Contains('if($null -ne $obs){$focusBrowserAddress=$false}')) 'resolver retains pending focus until browser address bar is found'
$observationStart=$source.IndexOf('function Get-ResolveBrowserObservation')
$observationEnd=$source.IndexOf('function Test-ResolveBrowserDocument',$observationStart)
$observationSource=$source.Substring($observationStart,$observationEnd-$observationStart)
Assert-ResolveTest ([regex]::Matches($observationSource,'\.SetFocus\(').Count -eq 1) 'resolver address observation has one focus site'
Assert-ResolveTest ($source.Contains("Stop-Resolve ([string]`$read.Status) 'TAB_OBSERVATION'")) 'resolver propagates bounded reader failure before menu action'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'TAB_CHANGED_DURING_VERIFICATION'")) 'tab stability check present'
Assert-ResolveTest ($source.Contains("Stop-Resolve 'BROWSER_DESTINATION_CHANGED'")) 'final URL/tab check present'
Assert-ResolveTest ($source.Contains('MainDesktopBound          = $false')) 'cannot claim durable main identity'
Assert-ResolveTest ($source.Contains('MenuItemInvoked           = $false')) 'invocation status starts false'
Assert-ResolveTest ($source.Contains("MessageDeliveryStatus     = 'NOT_ASSESSED'")) 'no acknowledgement invented'
Assert-ResolveTest (-not $source.Contains('SendKeys')) 'no keyboard injection'
Assert-ResolveTest (-not $source.Contains('SetValue(')) 'no composer writing'
[pscustomobject]@{Milestone='BRIDGE.M02-D.13';Test='OfflineResolveAndSyntax';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
