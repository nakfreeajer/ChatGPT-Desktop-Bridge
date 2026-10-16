# BRIDGE.CODEX.BASELINE.1B: interactive wrapper for one supervised resolver run.
# The expected ID exists only in this PowerShell process and is never reported.
[CmdletBinding(DefaultParameterSetName='Preflight')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='Preflight')]
    [switch]$PreflightOnly,
    [Parameter(Mandatory=$true,ParameterSetName='Invoke')]
    [switch]$ConfirmOpenInBrowser
)
$ErrorActionPreference = 'Stop'

$report = [ordered]@{
    Milestone = 'BRIDGE.CODEX.BASELINE.1B'
    Status = 'BLOCKED'
    Stage = 'INPUT'
    Mode = $PSCmdlet.ParameterSetName
    MainTitleVerified = $false
    BrowserBaselineDifferent = $false
    MenuItemInvoked = $false
    BrowserIdentityVerified = $false
    BrowserDocumentVerified = $false
    SelectedTabVerified = $false
    TabSelectionStable = $false
    BrowserTabTransition = 'NOT_ASSESSED'
    VisibleBrowserTabs = 0
    MainDesktopBound = $false
    ComposerWriteAttempted = $false
    ChatSendButtonInvoked = $false
    MessageDeliveryStatus = 'NOT_ASSESSED'
    ResolverStatus = 'NOT_RUN'
}

function Stop-Supervised {
    param([string]$Status,[string]$Stage,[AllowNull()][string]$ResolverStatus=$null)
    $script:report.Status = $Status
    $script:report.Stage = $Stage
    if ($null -ne $ResolverStatus) { $script:report.ResolverStatus = $ResolverStatus }
    throw 'SUPERVISED_STOP'
}

function Get-SupervisedExpectedId {
    try {
        $secure = Read-Host 'Enter independently verified ARM conversation UUID' -AsSecureString
    } catch {
        Stop-Supervised 'BLOCKED' 'INTERACTIVE_INPUT_UNAVAILABLE'
    }
    if ($null -eq $secure -or $secure.Length -eq 0) {
        Stop-Supervised 'BLOCKED' 'BASELINE_NOT_PROVIDED'
    }
    $pointer = [IntPtr]::Zero
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        $id = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } catch {
        Stop-Supervised 'BLOCKED' 'BASELINE_INPUT_UNAVAILABLE'
    } finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
        $secure.Dispose()
    }
    . (Join-Path $PSScriptRoot 'Bridge.Identity.ps1')
    if (-not (Test-BridgeConversationId $id)) {
        Remove-Variable id -ErrorAction SilentlyContinue
        Stop-Supervised 'BLOCKED' 'BASELINE_FORMAT_INVALID'
    }
    return $id.ToLowerInvariant()
}

function Get-SupervisedBrowserBaseline {
    param([string]$ExpectedId)
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    . (Join-Path $PSScriptRoot 'Bridge.Identity.ps1')
    . (Join-Path $PSScriptRoot 'Bridge.TabGuard.ps1')
    . (Join-Path $PSScriptRoot 'Bridge.Resolve.Helpers.ps1')

    $windows = @(Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })
    if ($windows.Count -ne 1) { Stop-Supervised 'BLOCKED' 'WINDOW_NOT_UNIQUE' }
    $handle = [IntPtr]$windows[0].MainWindowHandle
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    if ($null -eq $root) { Stop-Supervised 'BLOCKED' 'WINDOW_UNAVAILABLE' }

    $condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,'Search or enter a URL'
    )
    $found = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
    $bars = @()
    for ($i=0; $i -lt $found.Count; $i++) {
        $bar = $found.Item($i)
        if ($bar.Current.ControlType -eq [System.Windows.Automation.ControlType]::ComboBox -and
            -not $bar.Current.IsOffscreen -and $bar.Current.IsEnabled -and
            $bar.GetSupportedPatterns() -contains [System.Windows.Automation.ValuePattern]::Pattern) {
            $bars += $bar
        }
    }
    if ($bars.Count -ne 1) { Stop-Supervised 'BLOCKED' 'BROWSER_ADDRESS_BAR_NOT_UNIQUE' }

    $tab = Get-BridgeSelectedBrowserTab -Handle $handle -Bar $bars[0] -Stage 'BASELINE'
    if ($tab.Status -ne 'OK') { Stop-Supervised 'BLOCKED' 'BROWSER_TAB_NOT_VERIFIED' }
    try {
        # Focus once; the shared bounded reader never changes focus while polling.
        $bars[0].SetFocus()
    } catch {
        Stop-Supervised 'BLOCKED' 'BROWSER_ADDRESS_UNAVAILABLE'
    }
    $addressReader = {
        $current=$bars[0].Current
        if($current.ControlType -ne [System.Windows.Automation.ControlType]::ComboBox -or
            $current.IsOffscreen -or -not $current.IsEnabled -or
            $bars[0].GetSupportedPatterns() -notcontains [System.Windows.Automation.ValuePattern]::Pattern){
            throw 'BROWSER_ADDRESS_CONTROL_UNAVAILABLE'
        }
        [string]$bars[0].GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
    }
    $tabReader = { Get-BridgeSelectedBrowserTab -Handle $handle -Bar $bars[0] -Stage 'BASELINE' }
    $addressResult=Get-BridgeConversationAddress -ReadAddress $addressReader -ReadTab $tabReader `
        -Baseline $tab -TimeoutMilliseconds 2000 -PollIntervalMilliseconds 125
    if($addressResult.Status -ne 'OK') { Stop-Supervised 'BLOCKED' ([string]$addressResult.Status) }
    $after=$addressResult.Tab
    $browserId=[string]$addressResult.ConversationId
    Remove-Variable addressReader,tabReader,addressResult -ErrorAction SilentlyContinue
    $matchesExpected = [string]::Equals($browserId,$ExpectedId,[System.StringComparison]::OrdinalIgnoreCase)
    Remove-Variable browserId -ErrorAction SilentlyContinue
    if ($matchesExpected) {
        Stop-Supervised 'BLOCKED' 'BROWSER_ALREADY_ON_EXPECTED_ID'
    }
    return $after.VisibleCount
}

try {
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        Stop-Supervised 'BLOCKED' 'INTERACTIVE_INPUT_UNAVAILABLE'
    }
    $expectedId = Get-SupervisedExpectedId
    $resolver = Join-Path $PSScriptRoot 'Bridge.Resolve.ps1'

    if ($PreflightOnly) {
        $preflightOutput = & $resolver -ConversationTitle 'Artifact Relay Manager' -ExpectedConversationId $expectedId
        $preflight = $preflightOutput | ConvertFrom-Json
        $report.ResolverStatus = [string]$preflight.Status
        $report.MainTitleVerified = [bool]$preflight.MainTitleVerified
        if ($preflight.Status -ne 'PREFLIGHT_PASS') {
            Stop-Supervised 'FAIL' 'RESOLVER_PREFLIGHT' ([string]$preflight.Status)
        }
        $report.Status = 'PASS'
        $report.Stage = 'PREFLIGHT_COMPLETE'
    } else {
        $preflightOutput = & $resolver -ConversationTitle 'Artifact Relay Manager' -ExpectedConversationId $expectedId
        $preflight = $preflightOutput | ConvertFrom-Json
        $report.ResolverStatus = [string]$preflight.Status
        $report.MainTitleVerified = [bool]$preflight.MainTitleVerified
        if ($preflight.Status -ne 'PREFLIGHT_PASS') {
            Stop-Supervised 'FAIL' 'RESOLVER_PREFLIGHT' ([string]$preflight.Status)
        }

        $report.Stage = 'BROWSER_BASELINE'
        $report.VisibleBrowserTabs = Get-SupervisedBrowserBaseline -ExpectedId $expectedId
        $report.BrowserBaselineDifferent = $true
        $report.Stage = 'HUMAN_CONFIRMATION'
        $confirmation = Read-Host 'Preconditions passed. Type OPEN to invoke the menu once'
        if ($confirmation -cne 'OPEN') {
            Stop-Supervised 'BLOCKED' 'HUMAN_CONFIRMATION_NOT_GIVEN' 'PREFLIGHT_PASS'
        }

        $report.Stage = 'BROWSER_BASELINE_RECHECK'
        $report.VisibleBrowserTabs = Get-SupervisedBrowserBaseline -ExpectedId $expectedId
        $report.BrowserBaselineDifferent = $true
        $report.Stage = 'LIVE_RESOLVER'
        $liveOutput = & $resolver -ConversationTitle 'Artifact Relay Manager' -ExpectedConversationId $expectedId -OpenInBrowser
        $live = $liveOutput | ConvertFrom-Json
        $report.ResolverStatus = [string]$live.Status
        $report.MainTitleVerified = [bool]$live.MainTitleVerified
        $report.MenuItemInvoked = [bool]$live.MenuItemInvoked
        $report.BrowserIdentityVerified = [bool]$live.BrowserIdentityVerified
        $report.BrowserDocumentVerified = [bool]$live.BrowserDocumentVerified
        $report.SelectedTabVerified = [bool]$live.SelectedTabVerified
        $report.TabSelectionStable = [bool]$live.TabSelectionStable
        $report.BrowserTabTransition = [string]$live.BrowserTabTransition
        $report.VisibleBrowserTabs = [int]$live.VisibleBrowserTabs
        if ($live.Status -eq 'MENU_TO_BROWSER_ID_VERIFIED') {
            $report.Status = 'PASS'
            $report.Stage = 'COMPLETE'
        } else {
            Stop-Supervised 'FAIL' 'LIVE_RESOLVER' ([string]$live.Status)
        }
    }
} catch {
    if ($_.Exception.Message -ne 'SUPERVISED_STOP') {
        $report.Status = 'FAIL'
        $report.Stage = 'UNEXPECTED_RUNTIME_CONDITION'
        $report.ResolverStatus = 'RUNTIME_ERROR'
    }
} finally {
    Remove-Variable expectedId,preflightOutput,liveOutput,preflight,live,confirmation -ErrorAction SilentlyContinue
}

[pscustomobject]$report | ConvertTo-Json -Compress
