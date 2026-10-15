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
