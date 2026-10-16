# BRIDGE.M02-D.13: bounded sidebar-menu -> embedded-browser conversation ID verifier.
# Inspect-only by default. -OpenInBrowser explicitly invokes "Open on chatgpt.com".
# No chat composer writes, chat Send, CDP, external browser control, or API usage.
# This DOES NOT establish a durable ID for the main Desktop panel.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ConversationTitle,
    [Parameter(Mandatory=$true)][string]$ExpectedConversationId,
    [switch]$OpenInBrowser,
    [ValidateRange(3,30)][int]$TimeoutSeconds = 12
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Bridge.Identity.ps1')
. (Join-Path $PSScriptRoot 'Bridge.TabGuard.ps1')
. (Join-Path $PSScriptRoot 'Bridge.Resolve.Helpers.ps1')

$result = [ordered]@{
    Milestone                 = 'BRIDGE.M02-D.13'
    Status                    = 'UNVERIFIED'
    Stage                     = 'PREFLIGHT'
    MainTitleVerified         = $false
    SidebarCandidateUnique    = $false
    MenuStateMismatch         = $false
    MenuItemInvoked           = $false
    BrowserIdentityVerified   = $false
    BrowserDocumentVerified   = $false
    SelectedTabVerified       = $false
    TabSelectionStable        = $false
    BrowserTabTransition      = 'NOT_ASSESSED'
    VisibleBrowserTabs        = 0
    MainDesktopBound          = $false
    ComposerWriteAttempted    = $false
    ChatSendButtonInvoked     = $false
    MessageDeliveryStatus     = 'NOT_ASSESSED'
}
function Stop-Resolve {
    param([string]$Code,[string]$At)
    $script:result.Status = $Code
    $script:result.Stage = $At
    throw [System.InvalidOperationException]::new($Code)
}
function Get-ResolveWindow {
    $processes = @(Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })
    if ($processes.Count -eq 0) { Stop-Resolve 'WINDOW_NOT_FOUND' 'WINDOW' }
    if ($processes.Count -ne 1) { Stop-Resolve 'AMBIGUOUS_WINDOW' 'WINDOW' }
    return [IntPtr]$processes[0].MainWindowHandle
}
function Get-ResolveRoot {
    param([IntPtr]$Handle)
    $r = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    if ($null -eq $r) { Stop-Resolve 'WINDOW_UNAVAILABLE' 'WINDOW' }
    return $r
}
function Assert-ResolveMainDocument {
    param($Root,[string]$Title)
    $w = $Root.Current.BoundingRectangle
    $condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,'RootWebArea'
    )
    $all = $Root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
    $main = @()
    for($i=0;$i -lt $all.Count;$i++) {
        try {
            $x=$all.Item($i)
            if ($x.Current.IsOffscreen -or $x.Current.ControlType -ne [System.Windows.Automation.ControlType]::Document) { continue }
            $b=$x.Current.BoundingRectangle
            if ($w.Width -gt 0 -and $w.Height -gt 0 -and
                $b.Width -ge (0.8 * $w.Width) -and $b.Height -ge (0.6 * $w.Height) -and
                $b.Left -le ($w.Left + 60)) { $main += $x }
        } catch { }
    }
    if ($main.Count -ne 1) { Stop-Resolve 'MAIN_DOCUMENT_AMBIGUOUS' 'MAIN_DOCUMENT' }
    if (-not [string]::Equals([string]$main[0].Current.Name, $Title,[System.StringComparison]::Ordinal)) {
        Stop-Resolve 'MAIN_TITLE_MISMATCH' 'MAIN_DOCUMENT'
    }
    return $main[0]
}
function Get-ResolveRuntimeKey {
    param($Element)
    try {
        $ids=$Element.GetRuntimeId()
        if($null -eq $ids -or $ids.Length -eq 0){return ''}
        return [string]::Join(':',[string[]]$ids)
    } catch { return '' }
}
function Get-ResolveSidebarActions {
    param($Root,[string]$Title)
    $cond=[System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,$Title
    )
    $all=$Root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$cond)
    $items=@()
    for($i=0;$i -lt $all.Count;$i++){
        $x=$all.Item($i)
        if($x.Current.ControlType -eq [System.Windows.Automation.ControlType]::ListItem -and
            $x.Current.IsEnabled -and -not $x.Current.IsOffscreen){ $items += $x }
    }
    if($items.Count -ne 1){Stop-Resolve 'SIDEBAR_TARGET_AMBIGUOUS' 'SIDEBAR'}
    $script:result.SidebarCandidateUnique = $true
    $bc=[System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,'Chat actions'
    )
    $buttons=$items[0].FindAll([System.Windows.Automation.TreeScope]::Descendants,$bc)
    $usable=@()
    for($j=0;$j -lt $buttons.Count;$j++){
        $b=$buttons.Item($j)
        if($b.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -and
            $b.Current.IsEnabled -and -not $b.Current.IsOffscreen -and
            $b.GetSupportedPatterns() -contains [System.Windows.Automation.ExpandCollapsePattern]::Pattern){
            $usable += $b
        }
    }
    if($usable.Count -ne 1){Stop-Resolve 'CHAT_ACTIONS_AMBIGUOUS' 'SIDEBAR'}
    return [pscustomobject]@{Row=$items[0];Button=$usable[0]}
}
function Get-ResolveAssociatedMenu {
    param($Document)
    try {
        $menuType=[System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Menu
        )
        $menuName=[System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::NameProperty,'Chat actions'
        )
        $menuCondition=[System.Windows.Automation.AndCondition]::new($menuType,$menuName)
        $menus=$Document.FindAll([System.Windows.Automation.TreeScope]::Descendants,$menuCondition)
        $validMenus=@()
        for($i=0;$i -lt $menus.Count;$i++){
            $m=$menus.Item($i)
            if(-not $m.Current.IsOffscreen -and $m.Current.IsEnabled){$validMenus+=,$m}
        }
        $itemName=[System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::NameProperty,'Open on chatgpt.com'
        )
        $items=$Document.FindAll([System.Windows.Automation.TreeScope]::Descendants,$itemName)
        $candidates=@()
        for($i=0;$i -lt $items.Count;$i++){
            $item=$items.Item($i)
            if($item.Current.ControlType -eq [System.Windows.Automation.ControlType]::MenuItem){$candidates+=,$item}
        }
        $associated=@()
        foreach($item in $candidates){
            $parent=[System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($item)
            $ownerMenu=$null
            for($depth=0;$depth -lt 32 -and $null -ne $parent;$depth++){
                if((Get-ResolveRuntimeKey $parent) -ceq (Get-ResolveRuntimeKey $Document)){break}
                if($parent.Current.ControlType -eq [System.Windows.Automation.ControlType]::Menu -and
                    $parent.Current.Name -ceq 'Chat actions'){$ownerMenu=$parent;break}
                $parent=[System.Windows.Automation.TreeWalker]::ControlViewWalker.GetParent($parent)
            }
            if($null -ne $ownerMenu -and $validMenus.Count -eq 1){
                $ownerKey=Get-ResolveRuntimeKey $ownerMenu
                $containerKey=Get-ResolveRuntimeKey $validMenus[0]
                if(-not [string]::IsNullOrWhiteSpace($ownerKey) -and $ownerKey -ceq $containerKey){$associated+=,$item}
            }
        }
        $usable=@()
        foreach($item in $associated){
            if(-not $item.Current.IsOffscreen -and $item.Current.IsEnabled -and
                $item.GetSupportedPatterns() -contains [System.Windows.Automation.InvokePattern]::Pattern){$usable+=,$item}
        }
        return [pscustomobject]@{
            DocumentKey=(Get-ResolveRuntimeKey $Document)
            MenuContainerCount=$validMenus.Count
            MenuCandidateCount=$candidates.Count
            AssociatedCount=$associated.Count
            UsableCount=$usable.Count
            Item=if($usable.Count -eq 1){$usable[0]}else{$null}
            ItemKey=if($usable.Count -eq 1){Get-ResolveRuntimeKey $usable[0]}else{''}
        }
    } catch { return $null }
}
function Get-ResolveBrowserBar {
    param($Root)
    $cond=[System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,'Search or enter a URL'
    )
    $all=$Root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$cond)
    $bars=@()
    for($i=0;$i -lt $all.Count;$i++){
        $x=$all.Item($i)
        if($x.Current.ControlType -eq [System.Windows.Automation.ControlType]::ComboBox -and
            -not $x.Current.IsOffscreen -and $x.Current.IsEnabled -and
            $x.GetSupportedPatterns() -contains [System.Windows.Automation.ValuePattern]::Pattern) {
            $bars += $x
        }
    }
    if($bars.Count -gt 1){Stop-Resolve 'AMBIGUOUS_BROWSER_ADDRESS_BARS' 'BROWSER'}
    if($bars.Count -eq 0){return $null}
    return $bars[0]
}
function Get-ResolveBrowserObservation {
    param([IntPtr]$Handle,$Root)
    $bar=Get-ResolveBrowserBar $Root
    if($null -eq $bar){return $null}
    $before=Get-BridgeSelectedBrowserTab -Handle $Handle -Bar $bar -Stage 'TAB_OBSERVATION'
    if($before.Status -ne 'OK'){Stop-Resolve $before.Status 'TAB_OBSERVATION'}
    $bar.SetFocus()
    Start-Sleep -Milliseconds 250
    $url=[string]$bar.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
    $after=Get-BridgeSelectedBrowserTab -Handle $Handle -Bar $bar -Stage 'TAB_OBSERVATION'
    if(-not (Test-BridgeTabSnapshotStable $before $after)){
        Stop-Resolve 'TAB_CHANGED_DURING_READ' 'TAB_OBSERVATION'
    }
    return [pscustomobject]@{Tab=$after;ConversationId=(Get-BridgeConversationIdFromUrl $url)}
}
function Test-ResolveBrowserDocument {
    param($Root,[string]$Title)
    $bar=Get-ResolveBrowserBar $Root
    if($null -eq $bar){return $false}
    $rect=$bar.Current.BoundingRectangle
    $cond=[System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty,'RootWebArea'
    )
    $all=$Root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$cond)
    $found=0
    for($i=0;$i -lt $all.Count;$i++){
        try {
            $d=$all.Item($i)
            if($d.Current.ControlType -ne [System.Windows.Automation.ControlType]::Document -or
               $d.Current.IsOffscreen -or
               -not [string]::Equals([string]$d.Current.Name,$Title,[System.StringComparison]::Ordinal)){continue}
            $b=$d.Current.BoundingRectangle
            if($b.Top -gt $rect.Top -and $b.Left -ge ($rect.Left - 60) -and
               $b.Right -gt $rect.Left -and $b.Width -gt 150 -and
               $b.Width -lt (0.8 * $Root.Current.BoundingRectangle.Width)){ $found++ }
        }catch{}
    }
    return ($found -eq 1)
}
try {
    if(-not (Test-BridgeTitleInput $ConversationTitle)){Stop-Resolve 'INVALID_TITLE' 'INPUT'}
    if(-not (Test-BridgeConversationId $ExpectedConversationId)){Stop-Resolve 'INVALID_CONVERSATION_ID' 'INPUT'}
    if(-not [Environment]::OSVersion.Platform.ToString().StartsWith('Win')){
        Stop-Resolve 'WINDOWS_REQUIRED' 'PLATFORM'
    }
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $expected=$ExpectedConversationId.ToLowerInvariant()
    $handle=Get-ResolveWindow
    $root=Get-ResolveRoot $handle
    $result.Stage='MAIN_DOCUMENT'
    [void](Assert-ResolveMainDocument $root $ConversationTitle)
    $result.MainTitleVerified=$true
    $result.Stage='SIDEBAR'
    $target=Get-ResolveSidebarActions $root $ConversationTitle

    if(-not $OpenInBrowser){
        $result.Status='PREFLIGHT_PASS'
        $result.Stage='COMPLETE'
    }else{
        $result.Stage='BROWSER_BASELINE'
        $baseline=Get-ResolveBrowserObservation -Handle $handle -Root $root
        if($null -eq $baseline -or [string]::IsNullOrWhiteSpace([string]$baseline.ConversationId)){
            Stop-Resolve 'BROWSER_BASELINE_NOT_VERIFIED' 'BROWSER_BASELINE'
        }
        if($null -ne $baseline -and $baseline.ConversationId -eq $expected){
            Stop-Resolve 'BROWSER_ALREADY_ON_EXPECTED_ID' 'BROWSER_BASELINE'
        }

        $result.Stage='EXPAND_MENU'
        # Reconfirm main document and target sidebar entry immediately before mutation.
        [void](Assert-ResolveMainDocument $root $ConversationTitle)
        $target=Get-ResolveSidebarActions $root $ConversationTitle
        $button=$target.Button
        $targetRowKey=Get-ResolveRuntimeKey $target.Row
        $targetButtonKey=Get-ResolveRuntimeKey $button
        if([string]::IsNullOrWhiteSpace($targetRowKey) -or [string]::IsNullOrWhiteSpace($targetButtonKey)){
            Stop-Resolve 'MENU_CONTROLS_STALE' 'EXPAND_MENU'
        }
        $ep=$button.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        if($ep.Current.ExpandCollapseState -eq [System.Windows.Automation.ExpandCollapseState]::Collapsed){
            $button.SetFocus()
            $ep.Expand()
            Start-Sleep -Milliseconds 350
        }
        $expandStateAfter=$ep.Current.ExpandCollapseState
        $document=Assert-ResolveMainDocument $root $ConversationTitle
        $menu=Get-ResolveAssociatedMenu $document
        if($null -eq $menu){Stop-Resolve 'MENU_CONTROLS_STALE' 'EXPAND_MENU'}
        $snapshot=[pscustomobject]@{
            DocumentVerified=($menu.DocumentKey -ne '')
            TargetRowCount=1
            ActionButtonCount=1
            TargetStable=$true
            ControlsFresh=$true
            MenuContainerCount=$menu.MenuContainerCount
            MenuCandidateCount=$menu.MenuCandidateCount
            CorrectMenuAncestry=($menu.AssociatedCount -eq 1)
            ItemVisible=($menu.UsableCount -eq 1)
            ItemEnabled=($menu.UsableCount -eq 1)
            ItemInvokable=($menu.UsableCount -eq 1)
        }
        $menuStatus=Test-BridgeAssociatedMenuSnapshot $snapshot
        if($menuStatus -ne 'OK'){
            if($menuStatus -eq 'MENU_ITEM_AMBIGUOUS' -and $menu.AssociatedCount -eq 0){$menuStatus='MENU_OWNERSHIP_UNVERIFIED'}
            Stop-Resolve $menuStatus 'EXPAND_MENU'
        }
        if($expandStateAfter -ne [System.Windows.Automation.ExpandCollapseState]::Expanded){
            $result.MenuStateMismatch=$true
        }
        $result.Stage='INVOKE_MENU_ITEM'
        $freshRoot=Get-ResolveRoot $handle
        $freshDocument=Assert-ResolveMainDocument $freshRoot $ConversationTitle
        $freshTarget=Get-ResolveSidebarActions $freshRoot $ConversationTitle
        $freshRowKey=Get-ResolveRuntimeKey $freshTarget.Row
        $freshButtonKey=Get-ResolveRuntimeKey $freshTarget.Button
        if([string]::IsNullOrWhiteSpace($freshRowKey) -or [string]::IsNullOrWhiteSpace($freshButtonKey) -or
            $freshRowKey -cne $targetRowKey -or $freshButtonKey -cne $targetButtonKey){
            Stop-Resolve 'MENU_TARGET_CHANGED' 'INVOKE_MENU_ITEM'
        }
        $freshMenu=Get-ResolveAssociatedMenu $freshDocument
        if($null -eq $freshMenu){Stop-Resolve 'MENU_CONTROLS_STALE' 'INVOKE_MENU_ITEM'}
        $freshSnapshot=[pscustomobject]@{
            DocumentVerified=($freshMenu.DocumentKey -ne '')
            TargetRowCount=1
            ActionButtonCount=1
            TargetStable=$true
            ControlsFresh=($freshMenu.ItemKey -ne '' -and $freshMenu.ItemKey -ceq $menu.ItemKey)
            MenuContainerCount=$freshMenu.MenuContainerCount
            MenuCandidateCount=$freshMenu.MenuCandidateCount
            CorrectMenuAncestry=($freshMenu.AssociatedCount -eq 1)
            ItemVisible=($freshMenu.UsableCount -eq 1)
            ItemEnabled=($freshMenu.UsableCount -eq 1)
            ItemInvokable=($freshMenu.UsableCount -eq 1)
        }
        $freshStatus=Test-BridgeAssociatedMenuSnapshot $freshSnapshot
        if($freshStatus -ne 'OK'){Stop-Resolve $freshStatus 'INVOKE_MENU_ITEM'}
        $result.MenuItemInvoked=$true
        $freshMenu.Item.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()

        $result.Stage='VERIFY_BROWSER_ID'
        $watch=[System.Diagnostics.Stopwatch]::StartNew()
        $success=$false
        do {
            Start-Sleep -Milliseconds 350
            try {
                $root=Get-ResolveRoot $handle
                [void](Assert-ResolveMainDocument $root $ConversationTitle)
                $obs=Get-ResolveBrowserObservation -Handle $handle -Root $root
                if($null -eq $obs){continue}
                if($obs.ConversationId -ne $expected){continue}
                $priorTab=$null
                if($null -ne $baseline){$priorTab=$baseline.Tab}
                $transition=Get-BridgeTabTransition -Before $priorTab -After $obs.Tab
                if($transition -in @('AMBIGUOUS_TAB_TRANSITION','BASELINE_TAB_UNVERIFIED','POST_TAB_UNVERIFIED')){
                    Stop-Resolve $transition 'VERIFY_BROWSER_ID'
                }
                if(-not (Test-ResolveBrowserDocument -Root $root -Title $ConversationTitle)){continue}
                $bar=Get-ResolveBrowserBar $root
                $confirm=Get-BridgeSelectedBrowserTab -Handle $handle -Bar $bar -Stage 'VERIFY_BROWSER_ID'
                if(-not (Test-BridgeTabSnapshotStable $obs.Tab $confirm)){
                    Stop-Resolve 'TAB_CHANGED_DURING_VERIFICATION' 'VERIFY_BROWSER_ID'
                }
                # The address read must remain bound to the verified selected tab.
                $confirmObs=Get-ResolveBrowserObservation -Handle $handle -Root $root
                if($null -eq $confirmObs -or
                    -not (Test-BridgeTabSnapshotStable $obs.Tab $confirmObs.Tab) -or
                    $confirmObs.ConversationId -ne $expected){
                    Stop-Resolve 'BROWSER_DESTINATION_CHANGED' 'VERIFY_BROWSER_ID'
                }
                $result.VisibleBrowserTabs=$obs.Tab.VisibleCount
                $result.BrowserTabTransition=$transition
                $result.SelectedTabVerified=$true
                $result.TabSelectionStable=$true
                $result.BrowserIdentityVerified=$true
                $result.BrowserDocumentVerified=$true
                $success=$true
                break
            }catch{
                if($result.Status -ne 'UNVERIFIED'){throw}
                # During page load some UIA elements vanish. Retry until timeout.
            }
        }while($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds)
        if(-not $success){Stop-Resolve 'BROWSER_DESTINATION_UNVERIFIED' 'VERIFY_BROWSER_ID'}
        $result.Status='MENU_TO_BROWSER_ID_VERIFIED'
        $result.Stage='COMPLETE'
    }
}catch{
    if($result.Status -eq 'UNVERIFIED'){$result.Status='UIA_OR_RUNTIME_ERROR'}
}
# Privacy: no titles, private IDs, URLs, RuntimeIds or message content in output.
[pscustomobject]$result | ConvertTo-Json -Compress
