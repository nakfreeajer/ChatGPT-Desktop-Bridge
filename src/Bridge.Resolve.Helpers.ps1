# BRIDGE.M02-D.13/15I: decision and coordination helpers for menu/browser identity.
# UIA is accessed only through caller-supplied callbacks; RuntimeIds remain ephemeral.

function New-BridgeResolveResult {
    return [ordered]@{
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
}

function Get-BridgeSidebarTargetStatus {
    param(
        [int]$TargetRowCount,[int]$ActionButtonCount,[bool]$TitleMatches,
        [string]$ExpectedRowKey,[string]$CurrentRowKey,
        [string]$ExpectedButtonKey,[string]$CurrentButtonKey,
        [switch]$RequireStableKeys
    )
    if($TargetRowCount -ne 1){return 'SIDEBAR_TARGET_AMBIGUOUS'}
    if($ActionButtonCount -ne 1){return 'CHAT_ACTIONS_AMBIGUOUS'}
    if(-not $TitleMatches){return 'SIDEBAR_TARGET_CHANGED'}
    if($RequireStableKeys){
        if([string]::IsNullOrWhiteSpace($ExpectedRowKey) -or [string]::IsNullOrWhiteSpace($CurrentRowKey) -or
            [string]::IsNullOrWhiteSpace($ExpectedButtonKey) -or [string]::IsNullOrWhiteSpace($CurrentButtonKey)){
            return 'MENU_CONTROLS_STALE'
        }
        if($ExpectedRowKey -cne $CurrentRowKey -or $ExpectedButtonKey -cne $CurrentButtonKey){return 'MENU_TARGET_CHANGED'}
    }
    return 'OK'
}

function Get-BridgeTabTransition {
    param($Before, $After)
    if ($null -eq $After -or [string]::IsNullOrWhiteSpace([string]$After.RuntimeKey)) {
        return 'POST_TAB_UNVERIFIED'
    }
    if ($null -eq $Before) { return 'BROWSER_OPENED' }
    if ([string]::IsNullOrWhiteSpace([string]$Before.RuntimeKey)) {
        return 'BASELINE_TAB_UNVERIFIED'
    }
    $delta = [int]$After.VisibleCount - [int]$Before.VisibleCount
    if ($delta -lt 0 -or $delta -gt 1) { return 'AMBIGUOUS_TAB_TRANSITION' }
    if ($delta -eq 1) {
        if ($Before.RuntimeKey -ceq $After.RuntimeKey) { return 'AMBIGUOUS_TAB_TRANSITION' }
        return 'NEW_TAB'
    }
    if ($Before.RuntimeKey -ceq $After.RuntimeKey) { return 'REUSED_SELECTED_TAB' }
    return 'EXISTING_TAB_ACTIVATED'
}
function Test-BridgeTitleInput {
    param([string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) { return $false }
    if ($Title.Length -gt 120) { return $false }
    return (-not [regex]::IsMatch($Title, '[\r\n\x00-\x1f]'))
}

# Pure geometry predicate for identifying the embedded-browser document.
# Horizontal containment binds the document region to its address bar without
# assuming that their left edges are nearly aligned.
function Test-BridgeBrowserDocumentGeometry {
    param($DocumentRect,$AddressBarRect,$WindowRect)
    foreach($rect in @($DocumentRect,$AddressBarRect,$WindowRect)){
        if($null -eq $rect){return $false}
        foreach($property in @('Left','Top','Right','Bottom','Width','Height')){
            $member=$rect.PSObject.Properties[$property]
            if($null -eq $member){return $false}
            try{$value=[double]$member.Value}catch{return $false}
            if([double]::IsNaN($value) -or [double]::IsInfinity($value)){return $false}
        }
        if([double]$rect.Width -le 0 -or [double]$rect.Height -le 0 -or
           [double]$rect.Right -le [double]$rect.Left -or
           [double]$rect.Bottom -le [double]$rect.Top){return $false}
        if([Math]::Abs([double]$rect.Width-([double]$rect.Right-[double]$rect.Left)) -gt 0.01 -or
           [Math]::Abs([double]$rect.Height-([double]$rect.Bottom-[double]$rect.Top)) -gt 0.01){return $false}
    }
    return (
        [double]$DocumentRect.Top -gt [double]$AddressBarRect.Top -and
        [double]$DocumentRect.Left -le [double]$AddressBarRect.Left -and
        [double]$DocumentRect.Right -ge [double]$AddressBarRect.Right -and
        [double]$DocumentRect.Width -gt 150 -and
        [double]$DocumentRect.Width -lt (0.8 * [double]$WindowRect.Width)
    )
}

function Test-BridgeBrowserDocumentCandidate {
    param(
        [string]$DocumentTitle,[string]$ExpectedTitle,
        [bool]$IsVisible,[bool]$IsDocument,[bool]$IsRootWebArea,
        $DocumentRect,$AddressBarRect,$WindowRect
    )
    if(-not $IsVisible -or -not $IsDocument -or -not $IsRootWebArea){return $false}
    if(-not [string]::Equals($DocumentTitle,$ExpectedTitle,[System.StringComparison]::Ordinal)){return $false}
    return (Test-BridgeBrowserDocumentGeometry -DocumentRect $DocumentRect `
        -AddressBarRect $AddressBarRect -WindowRect $WindowRect)
}

# Pure decision helper for the resolver's document-scoped popup verification.
# UIA discovery and RuntimeIds remain in the current operation; this helper
# receives only sanitized relationship/eligibility facts and is offline-testable.
function Test-BridgeAssociatedMenuSnapshot {
    param($Snapshot)
    if ($null -eq $Snapshot) { return 'MENU_SNAPSHOT_UNAVAILABLE' }
    if (-not $Snapshot.DocumentVerified) { return 'MENU_DOCUMENT_MISMATCH' }
    if ([int]$Snapshot.TargetRowCount -ne 1) { return 'SIDEBAR_TARGET_AMBIGUOUS' }
    if ([int]$Snapshot.ActionButtonCount -ne 1) { return 'CHAT_ACTIONS_AMBIGUOUS' }
    if (-not $Snapshot.TargetStable) { return 'MENU_TARGET_CHANGED' }
    if (-not $Snapshot.ControlsFresh) { return 'MENU_CONTROLS_STALE' }
    if ([int]$Snapshot.MenuContainerCount -ne 1) { return 'MENU_POPUP_AMBIGUOUS' }
    if ([int]$Snapshot.MenuCandidateCount -eq 0) { return 'MENU_OWNERSHIP_UNVERIFIED' }
    if ([int]$Snapshot.MenuCandidateCount -gt 1) { return 'MENU_ITEM_AMBIGUOUS' }
    if (-not $Snapshot.CorrectMenuAncestry) { return 'MENU_OWNERSHIP_UNVERIFIED' }
    if (-not $Snapshot.ItemVisible -or -not $Snapshot.ItemEnabled -or -not $Snapshot.ItemInvokable) {
        return 'MENU_ITEM_UNAVAILABLE'
    }
    return 'OK'
}

# Poll a focused browser address control without changing focus. The caller
# supplies the selected-tab reader and address reader so this remains offline-testable.
function Get-BridgeConversationAddress {
    param(
        [scriptblock]$ReadAddress,
        [scriptblock]$ReadTab,
        $Baseline,
        [ValidateRange(1,2000)][int]$TimeoutMilliseconds = 2000,
        [ValidateRange(1,150)][int]$PollIntervalMilliseconds = 125
    )
    if ($null -eq $Baseline -or [string]::IsNullOrWhiteSpace([string]$Baseline.RuntimeKey)) {
        return [pscustomobject]@{Status='BASELINE_TAB_UNVERIFIED'}
    }
    if ($null -eq $ReadAddress -or $null -eq $ReadTab) {
        return [pscustomobject]@{Status='ADDRESS_READER_UNAVAILABLE'}
    }

    $watch=[System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try { $before=& $ReadTab } catch {
            return [pscustomobject]@{Status='TAB_STATE_UNAVAILABLE'}
        }
        if ($null -eq $before -or $before.Status -ne 'OK') {
            $status='TAB_STATE_UNAVAILABLE'
            if ($null -ne $before -and -not [string]::IsNullOrWhiteSpace([string]$before.Status)) {
                $status=[string]$before.Status
            }
            return [pscustomobject]@{Status=$status}
        }
        if (-not (Test-BridgeTabSnapshotStable -Before $Baseline -After $before)) {
            return [pscustomobject]@{Status='TAB_CHANGED_DURING_ADDRESS_READ'}
        }

        try { $address=[string](& $ReadAddress) } catch {
            return [pscustomobject]@{Status='BROWSER_ADDRESS_UNAVAILABLE'}
        }

        try { $after=& $ReadTab } catch {
            return [pscustomobject]@{Status='TAB_STATE_UNAVAILABLE'}
        }
        if ($null -eq $after -or $after.Status -ne 'OK') {
            $status='TAB_STATE_UNAVAILABLE'
            if ($null -ne $after -and -not [string]::IsNullOrWhiteSpace([string]$after.Status)) {
                $status=[string]$after.Status
            }
            return [pscustomobject]@{Status=$status}
        }
        if (-not (Test-BridgeTabSnapshotStable -Before $before -After $after) -or
            -not (Test-BridgeTabSnapshotStable -Before $Baseline -After $after)) {
            return [pscustomobject]@{Status='TAB_CHANGED_DURING_ADDRESS_READ'}
        }

        $conversationId=Get-BridgeConversationIdFromUrl $address
        Remove-Variable address -ErrorAction SilentlyContinue
        if ($null -ne $conversationId) {
            return [pscustomobject]@{
                Status='OK'
                ConversationId=$conversationId
                Tab=$after
            }
        }

        $remaining=$TimeoutMilliseconds-[int]$watch.ElapsedMilliseconds
        if ($remaining -le 0) {
            return [pscustomobject]@{Status='BROWSER_CONVERSATION_URL_TIMEOUT'}
        }
        Start-Sleep -Milliseconds ([Math]::Min($PollIntervalMilliseconds,$remaining))
    }
}
