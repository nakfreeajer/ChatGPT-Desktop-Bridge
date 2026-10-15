# BRIDGE.M02-A offline validation: Windows PowerShell 5.1, no ChatGPT process required.
# No UIA interaction, URL navigation, key injection or message submission.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$files = @(
    (Join-Path $root 'src/Bridge.Identity.ps1'),
    (Join-Path $root 'src/Bridge.Navigate.ps1'),
    $PSCommandPath
)
$checks = 0
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$parseErrors)
    if (@($parseErrors).Count -ne 0) {
        throw ('PARSE_FAILED: ' + (Split-Path $file -Leaf))
    }
    $checks++
}
. (Join-Path $root 'src/Bridge.Identity.ps1')
function Assert-BridgeTest {
    param([bool]$Condition, [string]$Description)
    $script:checks++
    if (-not $Condition) { throw ('ASSERTION_FAILED: ' + $Description) }
}
$id='11111111-2222-3333-4444-555555555555'
$url='https://chatgpt.com/c/' + $id
Assert-BridgeTest (Test-BridgeConversationId $id) 'valid ID'
Assert-BridgeTest (-not (Test-BridgeConversationId '')) 'empty ID rejected'
Assert-BridgeTest (-not (Test-BridgeConversationId 'not-a-chat-id')) 'invalid ID rejected'
Assert-BridgeTest (-not (Test-BridgeConversationId ($id + '/extra'))) 'ID with suffix rejected'
Assert-BridgeTest ((Get-BridgeConversationIdFromUrl $url) -eq $id) 'valid URL parsed'
Assert-BridgeTest ((Get-BridgeConversationIdFromUrl ($url + '?view=1')) -eq $id) 'query accepted'
Assert-BridgeTest ($null -eq (Get-BridgeConversationIdFromUrl ('https://attacker.example/c/' + $id))) 'foreign host rejected'
Assert-BridgeTest ($null -eq (Get-BridgeConversationIdFromUrl ('https://chatgpt.com/share/' + $id))) 'share URL rejected'
Assert-BridgeTest ($null -eq (Get-BridgeConversationIdFromUrl ('https://chatgpt.com/c/' + $id + 'f'))) 'extra ID character rejected'
Assert-BridgeTest (Test-BridgeHomeAddress 'chatgpt.com') 'shortened home address'
Assert-BridgeTest (Test-BridgeHomeAddress 'https://chatgpt.com/') 'HTTPS home address'
Assert-BridgeTest (-not (Test-BridgeHomeAddress $url)) 'conversation not home'
Assert-BridgeTest (Test-BridgeSuggestionTarget ('Visit ' + $url) $url) 'matching suggestion'
Assert-BridgeTest (-not (Test-BridgeSuggestionTarget ('Visit ' + $url) ('https://chatgpt.com/c/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'))) 'mismatched suggestion rejected'
Assert-BridgeTest (-not (Test-BridgeSuggestionTarget ('Visit ' + $url + ' and ' + $url) $url)) 'ambiguous multi-URL suggestion rejected'
[pscustomobject]@{Milestone='BRIDGE.M02-A';Test='OfflineIdentityAndSyntax';Result='PASS';Assertions=$checks} | ConvertTo-Json -Compress
