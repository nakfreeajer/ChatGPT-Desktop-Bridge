# BRIDGE.M02-C offline checks: no UIA calls, navigation, keyboard input, or message sending.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$files = @(
    (Join-Path $root 'src/Bridge.Identity.ps1'),
    (Join-Path $root 'src/Bridge.TabGuard.ps1'),
    (Join-Path $root 'src/Bridge.Navigate.ps1'),
    (Join-Path $root 'tests/Identity.Offline.Tests.ps1'),
    $PSCommandPath
)
$checks = 0
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if ($null -ne $errors -and @($errors).Count -gt 0) {
        throw ('PARSE_FAILED: ' + (Split-Path $file -Leaf) + ' ' + ($errors[0].Message))
    }
    $checks++
}
. (Join-Path $root 'src/Bridge.TabGuard.ps1')
function Assert-BridgeCheck {
    param([bool]$Valid, [string]$Description)
    $script:checks++
    if (-not $Valid) { throw ('ASSERTION_FAILED: ' + $Description) }
}
$before = [pscustomobject]@{RuntimeKey='1:2:3';VisibleCount=2}
$same   = [pscustomobject]@{RuntimeKey='1:2:3';VisibleCount=2}
$other  = [pscustomobject]@{RuntimeKey='1:2:4';VisibleCount=2}
$extra  = [pscustomobject]@{RuntimeKey='1:2:3';VisibleCount=3}
$lost   = [pscustomobject]@{RuntimeKey='';VisibleCount=2}
Assert-BridgeCheck (Test-BridgeTabSnapshotStable $before $same) 'same tab unchanged'
Assert-BridgeCheck (-not (Test-BridgeTabSnapshotStable $before $other)) 'tab switch rejected'
Assert-BridgeCheck (-not (Test-BridgeTabSnapshotStable $before $extra)) 'tab count change rejected'
Assert-BridgeCheck (-not (Test-BridgeTabSnapshotStable $before $lost)) 'missing selected tab ID rejected'
Assert-BridgeCheck (-not (Test-BridgeTabSnapshotStable $null $same)) 'missing baseline rejected'
Assert-BridgeCheck (-not (Test-BridgeTabSnapshotStable $before $null)) 'missing postcheck rejected'
$source = [System.IO.File]::ReadAllText((Join-Path $root 'src/Bridge.Navigate.ps1'))
Assert-BridgeCheck ($source.Contains('Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline')) 'selected-tab assertions integrated'
# Source inspection for presence of checks at each critical phase. This does not replace UIA qualification.
Assert-BridgeCheck ($source.Contains(" -Stage 'INJECT_URL'")) 'guard before injection'
Assert-BridgeCheck ($source.Contains(" -Stage 'SUGGESTION'")) 'guard during suggestion'
Assert-BridgeCheck ($source.Contains(" -Stage 'ACTIVATE_SUGGESTION'")) 'guard before keyboard Enter'
Assert-BridgeCheck ($source.Contains(" -Stage 'VERIFY_LOADED_BROWSER'")) 'guard after navigation'
Assert-BridgeCheck ($source.Contains(" -Stage 'FINAL_TAB_CHECK'")) 'last verification'
Assert-BridgeCheck ($source.Contains('if ($result.Status -ne ' + "'UNVERIFIED') { throw }")) 'fail-closed explicit status errors'
Assert-BridgeCheck ($source.Contains('[System.Windows.Forms.SendKeys]::SendWait(' + "'{ENTER}')")) 'existing explicit key path preserved'
Assert-BridgeCheck (-not $source.Contains('InvokePattern]::Pattern).Invoke(')) 'no send invocation added'
[pscustomobject]@{Milestone='BRIDGE.M02-C';Test='OfflineTabGuardAndSyntax';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
