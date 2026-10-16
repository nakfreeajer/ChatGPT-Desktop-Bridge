# BRIDGE.M02-E.1B offline window-selection decision tests; no live UIA.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Join-Path $root 'src/Bridge.WindowGuard.ps1'
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if(@($errors).Count -gt 0){throw ('PARSE_FAILED: '+$errors[0].Message)}
$checks=1
. $source
function Assert-WindowTest {
    param([bool]$IsTrue,[string]$Description)
    $script:checks++
    if(-not $IsTrue){throw ('ASSERTION_FAILED: '+$Description)}
}
function New-WindowCandidate {
    param([long]$Handle,[int]$ProcessId=100,[string]$ProcessName='ChatGPT',
        [bool]$Visible=$true,[bool]$Enabled=$true,[long]$OwnerHandle=0,
        [long]$Style=0,[long]$ExtendedStyle=0)
    [pscustomobject]@{Handle=$Handle;ProcessId=$ProcessId;ProcessName=$ProcessName;
        IsVisible=$Visible;IsEnabled=$Enabled;OwnerHandle=$OwnerHandle;Style=$Style;ExtendedStyle=$ExtendedStyle}
}
$sourceText=[System.IO.File]::ReadAllText($source)
$nativeTypeMatch=[regex]::Match($sourceText,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if(-not $nativeTypeMatch.Success){throw 'ASSERTION_FAILED: native window interop declaration found'}
Add-Type -TypeDefinition $nativeTypeMatch.Groups[1].Value -ErrorAction Stop | Out-Null
Assert-WindowTest ($null -ne ('BridgeWindowEnumeratorE1B' -as [type])) 'Win32 enumeration declaration compiles without enumerating live windows'
$none=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @()
Assert-WindowTest ($none.Status -eq 'WINDOW_NOT_FOUND') 'zero qualifying windows rejected'
$one=New-WindowCandidate -Handle 101
$single=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @($one)
Assert-WindowTest ($single.Status -eq 'OK' -and [long]$single.Window.Handle -eq 101) 'one qualifying ChatGPT window selected'
$injected=Get-BridgeCurrentWindowSelection -Enumerator { [pscustomobject]@{EnumerationComplete=$true;Candidates=@($one)} }
Assert-WindowTest ($injected.Status -eq 'OK' -and [long]$injected.Window.Handle -eq 101) 'window enumeration can be injected without Desktop access'
$injectedFailure=Get-BridgeCurrentWindowSelection -Enumerator { throw 'offline enumeration failure' }
Assert-WindowTest ($injectedFailure.Status -eq 'WINDOW_ENUMERATION_FAILED') 'injected enumeration failure fails closed'
$differentProcesses=@((New-WindowCandidate -Handle 101 -ProcessId 100),(New-WindowCandidate -Handle 202 -ProcessId 200))
$selection=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates $differentProcesses
Assert-WindowTest ($selection.Status -eq 'AMBIGUOUS_WINDOW') 'windows owned by different processes rejected'
$sameProcess=@((New-WindowCandidate -Handle 101 -ProcessId 100),(New-WindowCandidate -Handle 202 -ProcessId 100))
$selection=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates $sameProcess
Assert-WindowTest ($selection.Status -eq 'AMBIGUOUS_WINDOW') 'multiple windows owned by the same process rejected'
$transients=@(
    (New-WindowCandidate -Handle 301 -OwnerHandle 101),
    (New-WindowCandidate -Handle 302 -ExtendedStyle 0x80),
    (New-WindowCandidate -Handle 303 -Visible $false),
    (New-WindowCandidate -Handle 304 -Enabled $false),
    (New-WindowCandidate -Handle 305 -Style 0x40000000),
    (New-WindowCandidate -Handle 306 -Style 0x80000000)
)
$selection=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates $transients
Assert-WindowTest ($selection.Status -eq 'WINDOW_NOT_FOUND') 'owned, tool, hidden, disabled and child windows are not conversation windows'
$incomplete=Resolve-BridgeWindowSelection -EnumerationComplete $false -Candidates @($one)
Assert-WindowTest ($incomplete.Status -eq 'WINDOW_ENUMERATION_FAILED') 'incomplete enumeration rejected'
$malformed=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @([pscustomobject]@{Handle=101})
Assert-WindowTest ($malformed.Status -eq 'WINDOW_ENUMERATION_FAILED') 'incomplete candidate metadata rejected'
$baseline=$single.Window
$disappeared=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @()
Assert-WindowTest (-not (Test-BridgeWindowSelectionStable -Baseline $baseline -CurrentSelection $disappeared)) 'window disappearance between stages rejected'
$changed=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @((New-WindowCandidate -Handle 102 -ProcessId 100))
Assert-WindowTest (-not (Test-BridgeWindowSelectionStable -Baseline $baseline -CurrentSelection $changed)) 'replacement window handle rejected'
$appeared=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @($one,(New-WindowCandidate -Handle 202 -ProcessId 200))
Assert-WindowTest (-not (Test-BridgeWindowSelectionStable -Baseline $baseline -CurrentSelection $appeared)) 'new qualifying window before invocation rejected'
$incompleteAgain=Resolve-BridgeWindowSelection -EnumerationComplete $false -Candidates @($one)
Assert-WindowTest (-not (Test-BridgeWindowSelectionStable -Baseline $baseline -CurrentSelection $incompleteAgain)) 'failed re-enumeration rejected'
$sameHandleReplacement=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @((New-WindowCandidate -Handle 101 -ProcessId 999))
Assert-WindowTest (-not (Test-BridgeWindowSelectionStable -Baseline $baseline -CurrentSelection $sameHandleReplacement)) 'same HWND from a replacement process rejected'
$unrelated=New-WindowCandidate -Handle 909 -ProcessName 'OtherApp'
$selection=Resolve-BridgeWindowSelection -EnumerationComplete $true -Candidates @($unrelated,$one)
Assert-WindowTest ($selection.Status -eq 'OK' -and [long]$selection.Window.Handle -eq 101) 'unrelated application window ignored'
[pscustomobject]@{Milestone='BRIDGE.M02-E.1B';Test='WindowGuardOffline';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
