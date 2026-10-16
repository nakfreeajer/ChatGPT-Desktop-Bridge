# Offline structural selection tests only; no live UIA, browser or messaging actions.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$locatorSource = Join-Path $root 'src/Bridge.MainPanel.Locator.ps1'
$predicateSource = Join-Path $root 'src/Bridge.MainComposer.Predicate.ps1'
foreach ($sourcePath in @($predicateSource, $locatorSource)) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($sourcePath, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw ('PARSE_FAILED: ' + (Split-Path $sourcePath -Leaf) + ': ' + $errors[0].Message) }
}
$checks = 2
. $locatorSource

function Assert-MainPanelTest {
    param([bool]$Condition, [string]$Description)
    $script:checks++
    if (-not $Condition) { throw ('ASSERTION_FAILED: ' + $Description) }
}

function New-PanelNode {
    param(
        [int]$Key,
        [int]$Parent,
        [string]$Type,
        [string]$Role = '',
        [AllowNull()][string]$Name = $null,
        [bool]$Stale = $false,
        [string]$Tag = ''
    )
    [pscustomobject]@{
        NodeKey=$Key; ParentKey=$Parent; ControlType=$Type; Role=$Role; Name=$Name; IsStale=$Stale; TestTag=$Tag
    }
}

function New-PanelEdit {
    param([int]$Key=4,[int]$Parent=3,[string]$Name='Ask ChatGPT',[bool]$Enabled=$true,[bool]$Visible=$true,[bool]$Focusable=$true,[bool]$ValueAvailable=$true,[bool]$TextAvailable=$true,[bool]$ReadOnly=$false,[object]$Bounds=$null,[string]$Tag='composer',[bool]$Stale=$false)
    if ($null -eq $Bounds) { $Bounds = [pscustomobject]@{Left=10.0;Top=20.0;Right=90.0;Bottom=40.0} }
    $node = New-PanelNode -Key $Key -Parent $Parent -Type 'ControlType.Edit' -Name $Name -Tag $Tag
    $node.IsStale = $Stale
    $node | Add-Member IsEnabled $Enabled
    $node | Add-Member IsVisible $Visible
    $node | Add-Member IsKeyboardFocusable $Focusable
    $node | Add-Member ValuePatternAvailable $ValueAvailable
    $node | Add-Member TextPatternAvailable $TextAvailable
    $node | Add-Member ValuePatternIsReadOnly $ReadOnly
    $node | Add-Member BoundingRectangle $Bounds
    return $node
}

function New-PanelSend {
    param([int]$Key=5,[int]$Parent=3,[string]$Name='Send',[bool]$Enabled=$true,[bool]$Visible=$true,[bool]$InvokeAvailable=$true,[string]$Tag='send')
    $node = New-PanelNode -Key $Key -Parent $Parent -Type 'ControlType.Button' -Name $Name -Tag $Tag
    $node | Add-Member IsEnabled $Enabled
    $node | Add-Member IsVisible $Visible
    $node | Add-Member InvokePatternAvailable $InvokeAvailable
    return $node
}

function New-PanelFixture {
    param([object[]]$ExtraNodes=@())
    $nodes = @(
        (New-PanelNode -Key 0 -Parent -1 -Type 'ControlType.Document' -Role 'Document'),
        (New-PanelNode -Key 1 -Parent 0 -Type 'ControlType.Group' -Role 'Main'),
        (New-PanelNode -Key 2 -Parent 1 -Type 'ControlType.Group'),
        (New-PanelNode -Key 3 -Parent 2 -Type 'ControlType.Group' -Role 'Region' -Name 'Conversation'),
        (New-PanelEdit),
        (New-PanelSend)
    )
    $nodes += $ExtraNodes
    return ,$nodes
}

$documentGeometry = [pscustomobject]@{Left=0.0;Top=0.0;Right=100.0;Bottom=100.0}
$base = @{MainDocumentOwnershipEstablished=$true;EnumerationComplete=$true;MetadataFresh=$true;MetadataComplete=$true;DocumentGeometry=$documentGeometry}
$nodes = New-PanelFixture
$result = Select-BridgeMainPanelTargets @base -Nodes $nodes
Assert-MainPanelTest ($result.Status -eq 'SELECTED' -and $result.Composer.TestTag -eq 'composer' -and $result.SendButton.TestTag -eq 'send') 'unique main region, composer and Send are selected'

$missingMain = @($nodes | Where-Object { $_.NodeKey -eq 0 })
$result = Select-BridgeMainPanelTargets @base -Nodes $missingMain
Assert-MainPanelTest ($result.Status -eq 'MAIN_LANDMARK_NOT_FOUND') 'missing main landmark is rejected'

$duplicateMain = @($nodes) + (New-PanelNode -Key 6 -Parent 0 -Type 'ControlType.Group' -Role 'Main')
$result = Select-BridgeMainPanelTargets @base -Nodes $duplicateMain
Assert-MainPanelTest ($result.Status -eq 'AMBIGUOUS_MAIN_LANDMARK') 'duplicate main landmarks are rejected'

$missingRegion = @($nodes | Where-Object { $_.NodeKey -lt 3 })
$result = Select-BridgeMainPanelTargets @base -Nodes $missingRegion
Assert-MainPanelTest ($result.Status -eq 'CONVERSATION_REGION_NOT_FOUND') 'missing Conversation region is rejected'

$duplicateRegion = @($nodes) + (New-PanelNode -Key 6 -Parent 2 -Type 'ControlType.Group' -Role 'Region' -Name 'Conversation')
$result = Select-BridgeMainPanelTargets @base -Nodes $duplicateRegion
Assert-MainPanelTest ($result.Status -eq 'AMBIGUOUS_CONVERSATION_REGION') 'duplicate Conversation regions are rejected'

$duplicateComposer = @($nodes) + (New-PanelEdit -Key 6 -Parent 3 -Tag 'duplicate-composer')
$result = Select-BridgeMainPanelTargets @base -Nodes $duplicateComposer
Assert-MainPanelTest ($result.Status -eq 'AMBIGUOUS_COMPOSER') 'duplicate named composer controls are rejected'

$changedComposerName = @($nodes | Where-Object { $_.NodeKey -ne 4 }) + (New-PanelEdit -Name 'Different label')
$result = Select-BridgeMainPanelTargets @base -Nodes $changedComposerName
Assert-MainPanelTest ($result.Status -eq 'COMPOSER_NOT_FOUND') 'changed composer name is rejected'

$missingComposer = @($nodes | Where-Object { $_.NodeKey -ne 4 })
$result = Select-BridgeMainPanelTargets @base -Nodes $missingComposer
Assert-MainPanelTest ($result.Status -eq 'COMPOSER_NOT_FOUND') 'missing composer is rejected'

$missingSend = @($nodes | Where-Object { $_.NodeKey -ne 5 })
$result = Select-BridgeMainPanelTargets @base -Nodes $missingSend
Assert-MainPanelTest ($result.Status -eq 'SEND_CONTROL_NOT_FOUND') 'missing Send control is rejected'

$duplicateSend = @($nodes) + (New-PanelSend -Key 6 -Parent 3 -Tag 'duplicate-send')
$result = Select-BridgeMainPanelTargets @base -Nodes $duplicateSend
Assert-MainPanelTest ($result.Status -eq 'AMBIGUOUS_SEND_CONTROL') 'ambiguous Send controls are rejected'

$changedSendName = @($nodes | Where-Object { $_.NodeKey -ne 5 }) + (New-PanelSend -Name 'Submit')
$result = Select-BridgeMainPanelTargets @base -Nodes $changedSendName
Assert-MainPanelTest ($result.Status -eq 'SEND_CONTROL_NOT_FOUND') 'changed Send name is rejected'

$disabledSend = @($nodes | Where-Object { $_.NodeKey -ne 5 }) + (New-PanelSend -Enabled $false)
$result = Select-BridgeMainPanelTargets @base -Nodes $disabledSend
Assert-MainPanelTest ($result.Status -eq 'SEND_CONTROL_INELIGIBLE') 'disabled Send is rejected without invocation'

$offscreenSend = @($nodes | Where-Object { $_.NodeKey -ne 5 }) + (New-PanelSend -Visible $false)
$result = Select-BridgeMainPanelTargets @base -Nodes $offscreenSend
Assert-MainPanelTest ($result.Status -eq 'SEND_CONTROL_INELIGIBLE') 'offscreen Send is rejected without invocation'

$nonInvokableSend = @($nodes | Where-Object { $_.NodeKey -ne 5 }) + (New-PanelSend -InvokeAvailable $false)
$result = Select-BridgeMainPanelTargets @base -Nodes $nonInvokableSend
Assert-MainPanelTest ($result.Status -eq 'SEND_CONTROL_INELIGIBLE') 'Send without InvokePattern is rejected without invocation'

$staleNodes = @($nodes | Where-Object { $_.NodeKey -ne 4 }) + (New-PanelEdit -Stale $true)
$result = Select-BridgeMainPanelTargets @base -Nodes $staleNodes
Assert-MainPanelTest ($result.Status -eq 'STALE_UIA_ELEMENT') 'stale UIA reference is rejected'

$unowned = @{} + $base
$unowned.MainDocumentOwnershipEstablished = $false
$result = Select-BridgeMainPanelTargets @unowned -Nodes $nodes
Assert-MainPanelTest ($result.Status -eq 'MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED' -and $null -eq $result.Composer -and $null -eq $result.SendButton) 'unverified Document ownership authorizes no controls'
$runtimeBlocked = Get-BridgeMainPanelControls -DocumentElement $null -MainDocumentOwnershipEstablished $false
Assert-MainPanelTest ($runtimeBlocked.Status -eq 'MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED' -and -not $runtimeBlocked.TraversalStarted) 'runtime locator refuses before UIA traversal without owned Document'
$runtimeLimitRejected = Get-BridgeMainPanelControls -DocumentElement $null -MainDocumentOwnershipEstablished $true -MaximumNodes 5001
Assert-MainPanelTest ($runtimeLimitRejected.Status -eq 'INVALID_TRAVERSAL_LIMIT' -and -not $runtimeLimitRejected.TraversalStarted) 'runtime locator remains bounded'

$incomplete = @{} + $base
$incomplete.EnumerationComplete = $false
$result = Select-BridgeMainPanelTargets @incomplete -Nodes $nodes
Assert-MainPanelTest ($result.Status -eq 'UIA_ENUMERATION_INCOMPLETE') 'incomplete UIA enumeration is rejected'

$staleMetadata = @{} + $base
$staleMetadata.MetadataFresh = $false
$result = Select-BridgeMainPanelTargets @staleMetadata -Nodes $nodes
Assert-MainPanelTest ($result.Status -eq 'STALE_UIA_METADATA') 'stale snapshot metadata is rejected'

$composerOutsideRegion = @($nodes | Where-Object { $_.NodeKey -ne 4 }) + (New-PanelEdit -Parent 2)
$result = Select-BridgeMainPanelTargets @base -Nodes $composerOutsideRegion
Assert-MainPanelTest ($result.Status -eq 'COMPOSER_NOT_FOUND') 'composer outside Conversation region is not selected'

$sendOutsideRegion = @($nodes | Where-Object { $_.NodeKey -ne 5 }) + (New-PanelSend -Parent 2)
$result = Select-BridgeMainPanelTargets @base -Nodes $sendOutsideRegion
Assert-MainPanelTest ($result.Status -eq 'SEND_CONTROL_NOT_FOUND') 'Send outside Conversation region is not selected'

$nestedDocumentBranch = @($nodes) + @(
    (New-PanelNode -Key 6 -Parent 0 -Type 'ControlType.Document' -Role 'Document'),
    (New-PanelNode -Key 7 -Parent 6 -Type 'ControlType.Group' -Role 'Main'),
    (New-PanelNode -Key 8 -Parent 7 -Type 'ControlType.Group' -Role 'Region' -Name 'Conversation')
)
$result = Select-BridgeMainPanelTargets @base -Nodes $nestedDocumentBranch
Assert-MainPanelTest ($result.Status -eq 'SELECTED') 'nested Document branch cannot create a second main-panel match'

$changedRole = @($nodes | Where-Object { $_.NodeKey -ne 1 }) + (New-PanelNode -Key 1 -Parent 0 -Type 'ControlType.Group' -Role 'Other')
$result = Select-BridgeMainPanelTargets @base -Nodes $changedRole
Assert-MainPanelTest ($result.Status -eq 'MAIN_LANDMARK_NOT_FOUND') 'changed landmark role is rejected'

$changedRegionName = @($nodes | Where-Object { $_.NodeKey -ne 3 }) + (New-PanelNode -Key 3 -Parent 2 -Type 'ControlType.Group' -Role 'Region' -Name 'Other')
$result = Select-BridgeMainPanelTargets @base -Nodes $changedRegionName
Assert-MainPanelTest ($result.Status -eq 'CONVERSATION_REGION_NOT_FOUND') 'changed region name is rejected'

$cyclicHierarchy = @(
    (New-PanelNode -Key 0 -Parent -1 -Type 'ControlType.Document' -Role 'Document'),
    (New-PanelNode -Key 1 -Parent 2 -Type 'ControlType.Group' -Role 'Main'),
    (New-PanelNode -Key 2 -Parent 1 -Type 'ControlType.Group')
)
$result = Select-BridgeMainPanelTargets @base -Nodes $cyclicHierarchy
Assert-MainPanelTest ($result.Status -eq 'MAIN_LANDMARK_NOT_FOUND') 'cyclic hierarchy cannot establish a main landmark'

[pscustomobject]@{Milestone='BRIDGE.MAIN.1E';Test='MainPanelLocatorOffline';Result='PASS';Assertions=$checks}|ConvertTo-Json -Compress
