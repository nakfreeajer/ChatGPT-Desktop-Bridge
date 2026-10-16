# BRIDGE.M02-D.13: pure helper functions for menu-to-browser identity tests.
# No UIA actions. RuntimeId snapshots must not be persisted across invocations.

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
