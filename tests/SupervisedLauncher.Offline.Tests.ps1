# BRIDGE.CODEX.BASELINE.1B offline guards. No prompts, UIA, app, browser, or menu invocation.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$files=@(
    (Join-Path $root 'src/Bridge.Identity.ps1'),
    (Join-Path $root 'src/Bridge.TabGuard.ps1'),
    (Join-Path $root 'src/Bridge.Resolve.ps1'),
    (Join-Path $root 'src/Bridge.Resolve.Supervised.ps1'),
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
. (Join-Path $root 'src/Bridge.Identity.ps1')
function Assert-SupervisedTest {
    param([bool]$IsTrue,[string]$Description)
    $script:checks++
    if(-not $IsTrue){throw ('ASSERTION_FAILED: '+$Description)}
}
$valid='11111111-2222-3333-4444-555555555555'
Assert-SupervisedTest (Test-BridgeConversationId $valid) 'UUID accepted by existing identity validator'
Assert-SupervisedTest (-not (Test-BridgeConversationId 'not-a-chat-id')) 'non-UUID rejected by existing identity validator'
$source=[System.IO.File]::ReadAllText((Join-Path $root 'src/Bridge.Resolve.Supervised.ps1'))
Assert-SupervisedTest ($source.Contains("Read-Host 'Enter independently verified ARM conversation UUID' -AsSecureString")) 'baseline requested as SecureString'
Assert-SupervisedTest ($source.Contains('[Console]::IsInputRedirected')) 'redirected input fails closed'
Assert-SupervisedTest ($source.Contains('[Environment]::UserInteractive')) 'noninteractive session fails closed'
Assert-SupervisedTest ($source.Contains('SecureStringToBSTR($secure)')) 'conversion limited to process memory'
Assert-SupervisedTest ($source.Contains('ZeroFreeBSTR($pointer)')) 'temporary BSTR zeroed'
Assert-SupervisedTest ($source.Contains('$secure.Dispose()')) 'secure input disposed'
Assert-SupervisedTest ($source.Contains('Test-BridgeConversationId $id')) 'ID format validated'
Assert-SupervisedTest ($source.Contains('& $resolver -ConversationTitle')) 'resolver invoked in current process'
Assert-SupervisedTest (-not $source.Contains('Start-Process')) 'no child process launch'
Assert-SupervisedTest (-not $source.Contains('SetEnvironmentVariable')) 'no environment persistence'
Assert-SupervisedTest (-not $source.Contains('Out-File')) 'no file report output'
Assert-SupervisedTest ($source.Contains('[switch]$PreflightOnly')) 'preflight mode available'
Assert-SupervisedTest ($source.Contains('[switch]$ConfirmOpenInBrowser')) 'separate invocation mode available'
Assert-SupervisedTest ($source.Contains('$confirmation -cne ''OPEN''')) 'exact live confirmation required'
Assert-SupervisedTest ($source.Contains('Get-SupervisedBrowserBaseline -ExpectedId $expectedId')) 'selected browser precondition checked'
Assert-SupervisedTest ($source.Contains("'BROWSER_ALREADY_ON_EXPECTED_ID'")) 'same-ID browser baseline rejected'
Assert-SupervisedTest ([regex]::Matches($source,'-OpenInBrowser').Count -eq 1) 'one live resolver call site'
Assert-SupervisedTest ($source.Contains('MainDesktopBound = $false')) 'durable main identity remains unclaimed'
Assert-SupervisedTest ($source.Contains('[pscustomobject]$report | ConvertTo-Json -Compress')) 'sanitized report serialized'
Assert-SupervisedTest ($source.Contains('Test-BridgeTabSnapshotStable $tab $after')) 'browser tab held stable during baseline read'
Assert-SupervisedTest ($source.Contains('$bars[0].SetFocus()')) 'selected address read through UIA'
Assert-SupervisedTest (-not $source.Contains('SendKeys')) 'no keyboard injection'
Assert-SupervisedTest (-not $source.Contains('SetValue(')) 'no composer writes'
Assert-SupervisedTest (-not $source.Contains('.Invoke()')) 'only the existing resolver can invoke the menu'
$preflightAt=$source.IndexOf('$preflightOutput = & $resolver')
$browserCheckAt=$source.IndexOf('Get-SupervisedBrowserBaseline -ExpectedId $expectedId')
$confirmationAt=$source.IndexOf("Read-Host 'Preconditions passed. Type OPEN to invoke the menu once'")
$recheckAt=$source.LastIndexOf('Get-SupervisedBrowserBaseline -ExpectedId $expectedId')
$liveAt=$source.IndexOf('& $resolver -ConversationTitle ''Artifact Relay Manager'' -ExpectedConversationId $expectedId -OpenInBrowser')
Assert-SupervisedTest ($preflightAt -ge 0 -and $browserCheckAt -gt $preflightAt) 'resolver preflight precedes browser check'
Assert-SupervisedTest ($confirmationAt -gt $browserCheckAt -and $recheckAt -gt $confirmationAt -and $liveAt -gt $recheckAt) 'human confirmation and baseline recheck precede live call'
$reportStart=$source.IndexOf('$report = [ordered]@{')
$reportEnd=$source.IndexOf('function Stop-Supervised')
$reportSource=$source.Substring($reportStart,$reportEnd-$reportStart)
Assert-SupervisedTest (-not $reportSource.Contains('ExpectedConversationId')) 'report fields omit expected ID'
Assert-SupervisedTest (-not $reportSource.Contains('address')) 'report fields omit browser address'
[pscustomobject]@{Milestone='BRIDGE.CODEX.BASELINE.1B';Test='SupervisedLauncherOffline';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
