# Offline predicate checks only; no live UIA, application, browser or message actions.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'src/Bridge.MainComposer.Predicate.ps1'
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if (@($errors).Count -gt 0) { throw ('PARSE_FAILED: ' + $errors[0].Message) }
$checks = 1
. $source

function Assert-MainComposerTest {
    param([bool]$Condition, [string]$Description)
    $script:checks++
    if (-not $Condition) { throw ('ASSERTION_FAILED: ' + $Description) }
}

function New-TestRect {
    param([double]$Left, [double]$Top, [double]$Right, [double]$Bottom)
    [pscustomobject]@{ Left = $Left; Top = $Top; Right = $Right; Bottom = $Bottom }
}

function New-TestEdit {
    param(
        [string]$Tag,
        [string]$ControlType = 'ControlType.Edit',
        [bool]$Enabled = $true,
        [bool]$Visible = $true,
        [bool]$Focusable = $true,
        [bool]$ValuePattern = $true,
        [bool]$TextPattern = $true,
        [bool]$ReadOnly = $false,
        [object]$Bounds = (New-TestRect 20 20 80 40)
    )
    [pscustomobject]@{
        TestTag = $Tag
        ControlType = $ControlType
        IsEnabled = $Enabled
        IsVisible = $Visible
        IsKeyboardFocusable = $Focusable
        ValuePatternAvailable = $ValuePattern
        TextPatternAvailable = $TextPattern
        ValuePatternIsReadOnly = $ReadOnly
        BoundingRectangle = $Bounds
    }
}

$document = New-TestRect 0 0 100 100
$eligible = New-TestEdit 'eligible'
$base = @{
    MainDocumentOwnershipEstablished = $true
    EnumerationComplete = $true
    MetadataFresh = $true
    MetadataComplete = $true
    DocumentGeometry = $document
}

# Observed shape: two editors outside the independently supplied document, one inside.
$observed = @(
    (New-TestEdit 'outside-left' -Bounds (New-TestRect -40 10 -10 30)),
    (New-TestEdit 'inside' -Bounds (New-TestRect 20 20 80 40)),
    (New-TestEdit 'outside-right' -Bounds (New-TestRect 110 10 140 30))
)
$result = Select-BridgeMainComposerCandidate @base -Candidates $observed
Assert-MainComposerTest ($result.Status -eq 'SELECTED' -and $result.SelectedCandidate.TestTag -eq 'inside') 'observed three-candidate geometry selects the single inside candidate'

$twoEligible = @((New-TestEdit 'first'), (New-TestEdit 'second' -Bounds (New-TestRect 10 50 90 80)))
$result = Select-BridgeMainComposerCandidate @base -Candidates $twoEligible
Assert-MainComposerTest ($result.Status -eq 'MULTIPLE_ELIGIBLE_CANDIDATES' -and $result.EligibleCount -eq 2 -and $null -eq $result.SelectedCandidate) 'multiple eligible candidates fail closed'

$result = Select-BridgeMainComposerCandidate @base -Candidates @()
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'empty candidate set returns no eligible candidate'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'invalid' -Bounds (New-TestRect 2 2 2 9)))
Assert-MainComposerTest ($result.Status -eq 'METADATA_INVALID') 'zero-width candidate geometry is invalid'

$missingRect = New-TestEdit 'missing-rect' -Bounds $null
$result = Select-BridgeMainComposerCandidate @base -Candidates @($missingRect)
Assert-MainComposerTest ($result.Status -eq 'METADATA_INCOMPLETE') 'missing candidate geometry is incomplete'

$missingField = New-TestEdit 'missing-field'
$missingField.PSObject.Properties.Remove('TextPatternAvailable')
$result = Select-BridgeMainComposerCandidate @base -Candidates @($missingField)
Assert-MainComposerTest ($result.Status -eq 'METADATA_INCOMPLETE') 'missing required pattern metadata fails closed'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'offscreen' -Visible $false))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'offscreen candidate is ineligible'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'disabled' -Enabled $false))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'disabled candidate is ineligible'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'readonly' -ReadOnly $true))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'read-only candidate is ineligible'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'not-focusable' -Focusable $false))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'non-focusable candidate is ineligible'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'missing-value-pattern' -ValuePattern $false))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'candidate without ValuePattern is ineligible'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'missing-text-pattern' -TextPattern $false))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'candidate without TextPattern is ineligible'

$result = Select-BridgeMainComposerCandidate @base -Candidates @((New-TestEdit 'outside' -Bounds (New-TestRect 105 10 120 30)))
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'valid candidate geometry outside Document is ineligible'

$reversed = @($observed[2], $observed[1], $observed[0])
$result = Select-BridgeMainComposerCandidate @base -Candidates $reversed
Assert-MainComposerTest ($result.Status -eq 'SELECTED' -and $result.SelectedCandidate.TestTag -eq 'inside') 'candidate ordering does not change the selection'

$incompleteEnumeration = @{} + $base
$incompleteEnumeration.EnumerationComplete = $false
$result = Select-BridgeMainComposerCandidate @incompleteEnumeration -Candidates @($eligible)
Assert-MainComposerTest ($result.Status -eq 'CANDIDATE_ENUMERATION_INCOMPLETE') 'incomplete enumeration fails closed'

$stale = @{} + $base
$stale.MetadataFresh = $false
$result = Select-BridgeMainComposerCandidate @stale -Candidates @($eligible)
Assert-MainComposerTest ($result.Status -eq 'CANDIDATE_DATA_STALE') 'stale candidate metadata fails closed'

$unowned = @{} + $base
$unowned.MainDocumentOwnershipEstablished = $false
$result = Select-BridgeMainComposerCandidate @unowned -Candidates @($eligible)
Assert-MainComposerTest ($result.Status -eq 'MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED' -and $null -eq $result.SelectedCandidate) 'unverified document ownership never authorizes selection'

$invalidDocument = @{} + $base
$invalidDocument.DocumentGeometry = New-TestRect 0 0 0 100
$result = Select-BridgeMainComposerCandidate @invalidDocument -Candidates @($eligible)
Assert-MainComposerTest ($result.Status -eq 'METADATA_INVALID') 'invalid document geometry is rejected'

$missingDocumentGeometry = @{} + $base
$missingDocumentGeometry.DocumentGeometry = $null
$result = Select-BridgeMainComposerCandidate @missingDocumentGeometry -Candidates @($eligible)
Assert-MainComposerTest ($result.Status -eq 'METADATA_INCOMPLETE') 'missing document geometry is incomplete'

$missingMetadata = @{} + $base
$missingMetadata.MetadataComplete = $false
$result = Select-BridgeMainComposerCandidate @missingMetadata -Candidates @($eligible)
Assert-MainComposerTest ($result.Status -eq 'CANDIDATE_METADATA_INCOMPLETE') 'globally incomplete metadata fails closed'

$notEdit = New-TestEdit 'not-edit' -ControlType 'ControlType.Custom'
$result = Select-BridgeMainComposerCandidate @base -Candidates @($notEdit)
Assert-MainComposerTest ($result.Status -eq 'NO_ELIGIBLE_CANDIDATE') 'non-Edit control is ineligible'

[pscustomobject]@{ Milestone = 'BRIDGE.MAIN.1E'; Test = 'MainComposerPredicateOffline'; Result = 'PASS'; Assertions = $checks } | ConvertTo-Json -Compress
