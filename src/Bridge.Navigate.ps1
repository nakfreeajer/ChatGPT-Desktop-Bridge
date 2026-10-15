# BRIDGE.M02-C: experimental navigation-only prototype with selected-tab stability guard.
# Windows PowerShell 5.1. No chat composer modifications, button sends, or OpenAI API/CDP.
# Observe:  .\src\Bridge.Navigate.ps1 -ConversationId <id>
# Navigate: .\src\Bridge.Navigate.ps1 -ConversationId <id> -Navigate -AcceptKeyboardRisk
# IMPORTANT: Global Enter has a focus race. Use only with empty chat drafts in a test session.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ConversationId,
    [switch]$Navigate,
    [switch]$AcceptKeyboardRisk,
    [ValidateRange(3,30)][int]$TimeoutSeconds = 12
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Bridge.Identity.ps1')
. (Join-Path $PSScriptRoot 'Bridge.TabGuard.ps1')

$result = [ordered]@{
    Milestone           = 'BRIDGE.M02-C'
    Status              = 'UNVERIFIED'
    Stage               = 'PREFLIGHT'
    NavigationAttempted = $false
    UrlIdentityVerified = $false
    EditorVerified      = $false
    SelectedTabVerified = $false
    TabSelectionStable  = $false
    VisibleBrowserTabs  = 0
    MainDesktopBound    = $false
    ComposerWriteAttempted = $false
    ChatSendButtonInvoked  = $false
    MessageDeliveryStatus = 'NOT_ASSESSED'
}
function Stop-Bridge {
    param([string]$Code,[string]$At)
    $script:result.Status = $Code
    $script:result.Stage = $At
    throw [System.InvalidOperationException]::new($Code)
}
function Get-BridgeMainWindow {
    $processes = @(Get-Process ChatGPT -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 })
    if ($processes.Count -eq 0) { Stop-Bridge 'WINDOW_NOT_FOUND' 'WINDOW' }
    if ($processes.Count -ne 1) { Stop-Bridge 'AMBIGUOUS_WINDOW' 'WINDOW' }
    return [IntPtr]$processes[0].MainWindowHandle
}
function Get-BridgeAddressBar {
    param([IntPtr]$Handle)
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    if ($null -eq $root) { Stop-Bridge 'WINDOW_UNAVAILABLE' 'ADDRESS_BAR' }
    $cond = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty, 'Search or enter a URL'
    )
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$cond)
    $bars = @($all | Where-Object {
        $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::ComboBox -and
        $_.Current.IsEnabled -and -not $_.Current.IsOffscreen
    })
    if ($bars.Count -ne 1) { Stop-Bridge 'ADDRESS_BAR_AMBIGUOUS_OR_MISSING' 'ADDRESS_BAR' }
    $bar = $bars[0]
    if (-not ($bar.GetSupportedPatterns() -contains [System.Windows.Automation.ValuePattern]::Pattern)) {
        Stop-Bridge 'ADDRESS_BAR_VALUE_UNAVAILABLE' 'ADDRESS_BAR'
    }
    return $bar
}
function Read-BridgeAddress {
    param($Bar)
    $Bar.SetFocus()
    Start-Sleep -Milliseconds 250
    return [string]$Bar.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
}
function Test-BridgeBrowserEditor {
    param([IntPtr]$Handle, $Bar)
    # Geometry is a discovery hint only; a Document ancestor is also required.
    $br = $Bar.Current.BoundingRectangle
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($Handle)
    $condition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit
    )
    $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,$condition)
    $candidates = @()
    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    foreach ($editor in $all) {
        try {
            if (-not $editor.Current.IsEnabled -or $editor.Current.IsOffscreen) { continue }
            $q = $editor.Current.BoundingRectangle
            $overlap = [math]::Min($q.Right,$br.Right)-[math]::Max($q.Left,$br.Left)
            if ($q.Top -le $br.Bottom -or $overlap -lt 50) { continue }
            $node = $editor
            $doc = $null
            for ($i=0; $i -lt 80 -and $null -ne $node; $i++) {
                if ($node.Current.ControlType -eq [System.Windows.Automation.ControlType]::Document) {
                    $doc = $node
                    break
                }
                $node = $walker.GetParent($node)
            }
            if ($null -ne $doc -and $doc.Current.AutomationId -eq 'RootWebArea' -and
                $editor.Current.IsKeyboardFocusable -and
                $editor.GetSupportedPatterns() -contains [System.Windows.Automation.ValuePattern]::Pattern) {
                $candidates += $editor
            }
        } catch {
            # Stale or inaccessible UIA elements are ignored; no success can be inferred from them.
        }
    }
    return ($candidates.Count -eq 1)
}
function Assert-BridgeSuggestion {
    param([IntPtr]$Handle, $Bar, [string]$ExpectedUrl)
    # InvokePattern on the suggestion did not navigate in the original experiment.
    # This routine only verifies the focused ListItem; Enter is handled separately.
    $focused = [System.Windows.Automation.AutomationElement]::FocusedElement
    if ($null -eq $focused) { return $false }
    if ($focused.Current.ControlType -ne [System.Windows.Automation.ControlType]::ListItem -or
        $focused.Current.IsOffscreen -or -not $focused.Current.HasKeyboardFocus) { return $false }
    if (-not (Test-BridgeSuggestionTarget -SuggestionName ([string]$focused.Current.Name) -TargetUrl $ExpectedUrl)) {
        return $false
    }
    $parent = [System.Windows.Automation.TreeWalker]::RawViewWalker.GetParent($focused)
    if ($null -eq $parent -or $parent.Current.ControlType -ne [System.Windows.Automation.ControlType]::List) {
        return $false
    }
    $fr = $focused.Current.BoundingRectangle
    $br = $Bar.Current.BoundingRectangle
    if ($fr.Y -lt ($br.Bottom - 10) -or $fr.Y -gt ($br.Bottom + 300) -or
        $fr.Right -le $br.Left -or $fr.Left -ge $br.Right) { return $false }
    $value = [string]$Bar.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.Value
    if (-not [string]::Equals($value,$ExpectedUrl,[System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    $check = [System.Windows.Automation.AutomationElement]::FocusedElement
    if ($null -eq $check -or -not $check.Current.HasKeyboardFocus) { return $false }
    return ([string]::Join(',',$focused.GetRuntimeId()) -eq [string]::Join(',',$check.GetRuntimeId()))
}

try {
    if (-not (Test-BridgeConversationId $ConversationId)) { Stop-Bridge 'INVALID_CONVERSATION_ID' 'INPUT' }
    if ($Navigate -and -not $AcceptKeyboardRisk) { Stop-Bridge 'KEYBOARD_RISK_NOT_ACCEPTED' 'INPUT' }
    if (-not [Environment]::OSVersion.Platform.ToString().StartsWith('Win')) {
        Stop-Bridge 'WINDOWS_REQUIRED' 'PLATFORM'
    }
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    if ($Navigate) {
        Add-Type -AssemblyName System.Windows.Forms
        if (-not ('BridgeWindowApiM02A' -as [type])) {
            Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class BridgeWindowApiM02A { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd); [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); }'
        }
    }
    $expectedId = $ConversationId.ToLowerInvariant()
    $targetUrl = 'https://chatgpt.com/c/' + $expectedId
    $handle = Get-BridgeMainWindow

    if ($Navigate) {
        $result.Stage = 'FOREGROUND'
        [void][BridgeWindowApiM02A]::SetForegroundWindow($handle)
        Start-Sleep -Milliseconds 400
        if ([BridgeWindowApiM02A]::GetForegroundWindow() -ne $handle) {
            Stop-Bridge 'FOREGROUND_FAILED' 'FOREGROUND'
        }
    }

    $result.Stage = 'CURRENT_URL'
    $bar = Get-BridgeAddressBar $handle
    $tabBaseline = Get-BridgeSelectedBrowserTab -Handle $handle -Bar $bar -Stage 'TAB_BASELINE'
    if ($tabBaseline.Status -ne 'OK') { Stop-Bridge $tabBaseline.Status 'TAB_BASELINE' }
    $result.SelectedTabVerified = $true
    $result.VisibleBrowserTabs = $tabBaseline.VisibleCount
    $currentUrl = Read-BridgeAddress $bar
    Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'CURRENT_URL'
    $currentId = Get-BridgeConversationIdFromUrl $currentUrl

    if ($null -ne $currentId -and $currentId -eq $expectedId) {
        # Already at the requested browser conversation: verify its composer below.
    } elseif (-not $Navigate) {
        Stop-Bridge 'IDENTITY_MISMATCH' 'CURRENT_URL'
    } else {
        # Refuse implicit navigation away from any other conversation.
        if (-not (Test-BridgeHomeAddress $currentUrl)) {
            Stop-Bridge 'START_PAGE_NOT_HOME' 'CURRENT_URL'
        }
        $result.Stage = 'INJECT_URL'
        Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'INJECT_URL'
        $pattern = $bar.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        if ($pattern.Current.IsReadOnly) { Stop-Bridge 'ADDRESS_BAR_READ_ONLY' 'INJECT_URL' }
        if (-not $bar.Current.HasKeyboardFocus) { Stop-Bridge 'ADDRESS_BAR_NOT_FOCUSED' 'INJECT_URL' }
        $pattern.SetValue($targetUrl)

        $result.Stage = 'SUGGESTION'
        $verified = $false
        for ($attempt=0; $attempt -lt 8; $attempt++) {
            Start-Sleep -Milliseconds 100
            if ([BridgeWindowApiM02A]::GetForegroundWindow() -ne $handle) {
                Stop-Bridge 'FOREGROUND_LOST' 'SUGGESTION'
            }
            Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'SUGGESTION'
            try {
                if (Assert-BridgeSuggestion -Handle $handle -Bar $bar -ExpectedUrl $targetUrl) {
                    $verified = $true
                    break
                }
            } catch {
                # A UIA control may become stale during autocomplete; never fall through to Enter.
            }
        }
        if (-not $verified) { Stop-Bridge 'SUGGESTION_NOT_VERIFIED' 'SUGGESTION' }
        # Global key injection is experimental and limited to this explicitly opted-in navigation.
        # A focus change between this check and SendWait remains a known residual risk.
        $result.Stage = 'ACTIVATE_SUGGESTION'
        Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'ACTIVATE_SUGGESTION'
        if ([BridgeWindowApiM02A]::GetForegroundWindow() -ne $handle -or
            -not (Assert-BridgeSuggestion -Handle $handle -Bar $bar -ExpectedUrl $targetUrl)) {
            Stop-Bridge 'FOCUS_CHANGED' 'ACTIVATE_SUGGESTION'
        }
        $result.NavigationAttempted = $true
        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    }

    $result.Stage = 'VERIFY_LOADED_BROWSER'
    $verifiedUrl = $false
    $verifiedEditor = $false
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 350
        try {
            $bar = Get-BridgeAddressBar $handle
            Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'VERIFY_LOADED_BROWSER'
            $url = Read-BridgeAddress $bar
            Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'VERIFY_LOADED_BROWSER'
            $id = Get-BridgeConversationIdFromUrl $url
            if ($null -ne $id -and $id -eq $expectedId) {
                $verifiedUrl = $true
                $verifiedEditor = Test-BridgeBrowserEditor -Handle $handle -Bar $bar
                if ($verifiedEditor) {
                    Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'VERIFY_LOADED_BROWSER'
                    break
                }
            } elseif ($Navigate -and $result.NavigationAttempted -and
                -not (Test-BridgeHomeAddress $url)) {
                Stop-Bridge 'IDENTITY_MISMATCH_AFTER_NAVIGATION' 'VERIFY_LOADED_BROWSER'
            }
        } catch {
            if ($result.Status -ne 'UNVERIFIED') { throw }
            # Transient UIA changes during navigation must not be mistaken for verified success.
        }
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    $result.UrlIdentityVerified = $verifiedUrl
    $result.EditorVerified = $verifiedEditor
    if (-not $verifiedUrl) { Stop-Bridge 'NAVIGATION_UNCONFIRMED' 'VERIFY_LOADED_BROWSER' }
    if (-not $verifiedEditor) { Stop-Bridge 'EDITOR_NOT_VERIFIED' 'VERIFY_LOADED_BROWSER' }
    Assert-BridgeTabStable -Handle $handle -Bar $bar -Baseline $tabBaseline -Stage 'FINAL_TAB_CHECK'
    $result.TabSelectionStable = $true
    $result.Status = 'VERIFIED_BROWSER_ROUTE'
    $result.Stage = 'COMPLETE'
} catch {
    if ($result.Status -eq 'UNVERIFIED') {
        $result.Status = 'UIA_OR_RUNTIME_ERROR'
    }
}
# Never print target IDs, URLs, chat titles, or message text.
[pscustomobject]$result | ConvertTo-Json -Compress
