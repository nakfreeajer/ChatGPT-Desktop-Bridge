# BRIDGE.M02-C: read-only browser tab identity and selection checks.
# Windows PowerShell 5.1. The selected tab is identified by its ephemeral UIA RuntimeId.
# This is a within-run stability token, NEVER a durable conversation identifier.

function Test-BridgeTabSnapshotStable {
    param($Before, $After)
    if ($null -eq $Before -or $null -eq $After) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Before.RuntimeKey)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$After.RuntimeKey)) { return $false }
    return (
        [string]$Before.RuntimeKey -ceq [string]$After.RuntimeKey -and
        [int]$Before.VisibleCount -eq [int]$After.VisibleCount
    )
}

function Get-BridgeSelectedBrowserTab {
    param([IntPtr]$Handle, $Bar, [string]$Stage)
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    if ($null -eq $root) { Stop-Bridge 'WINDOW_UNAVAILABLE' $Stage }
    try {
        $b = $Bar.Current.BoundingRectangle
        $c = [System.Windows.Automation.PropertyCondition]::new(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::TabItem
        )
        $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $c)
        $visible = @()
        for ($i=0; $i -lt $all.Count; $i++) {
            $t = $all.Item($i)
            if ($t.Current.IsOffscreen -or -not $t.Current.IsEnabled) { continue }
            $r = $t.Current.BoundingRectangle
            # A browser tab lies directly above / slightly left of its own address bar.
            # Only relative layout is used; there are no fixed screen coordinates.
            if ($r.Width -le 0 -or $r.Height -le 0 -or
                $r.Top -ge $b.Top -or $r.Bottom -lt ($b.Top - 200) -or
                $r.Right -le ($b.Left - 250) -or $r.Left -ge $b.Right) { continue }
            $visible += $t
        }
        if ($visible.Count -eq 0) { return [pscustomobject]@{Status='BROWSER_TAB_NOT_FOUND'} }
        $selected = @()
        foreach ($t in $visible) {
            if (-not ($t.GetSupportedPatterns() -contains [System.Windows.Automation.SelectionItemPattern]::Pattern)) {
                return [pscustomobject]@{Status='TAB_SELECTION_UNSUPPORTED'}
            }
            $p = $t.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
            if ($p.Current.IsSelected) { $selected += $t }
        }
        if ($selected.Count -ne 1) {
            return [pscustomobject]@{Status='TAB_SELECTION_AMBIGUOUS'}
        }
        $ids = $selected[0].GetRuntimeId()
        if ($null -eq $ids -or $ids.Length -eq 0) {
            return [pscustomobject]@{Status='TAB_RUNTIME_ID_MISSING'}
        }
        return [pscustomobject]@{
            Status       = 'OK'
            RuntimeKey   = [string]::Join(':', [string[]]$ids)
            VisibleCount = [int]$visible.Count
        }
    } catch {
        # UIA elements may be invalidated by tab updates. Never assume stability.
        return [pscustomobject]@{Status='TAB_QUERY_FAILED'}
    }
}

function Assert-BridgeTabStable {
    param([IntPtr]$Handle, $Bar, $Baseline, [string]$Stage)
    $now = Get-BridgeSelectedBrowserTab -Handle $Handle -Bar $Bar -Stage $Stage
    if ($now.Status -ne 'OK') { Stop-Bridge $now.Status $Stage }
    if (-not (Test-BridgeTabSnapshotStable -Before $Baseline -After $now)) {
        Stop-Bridge 'TAB_CHANGED' $Stage
    }
}
