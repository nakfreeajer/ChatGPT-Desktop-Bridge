function ConvertTo-BridgeMainComposerBounds {
    param([object]$Rectangle)

    if ($null -eq $Rectangle) {
        return [pscustomobject]@{ Status = 'INCOMPLETE'; Bounds = $null }
    }

    $values = [ordered]@{}
    foreach ($field in @('Left', 'Top', 'Right', 'Bottom')) {
        $property = $Rectangle.PSObject.Properties[$field]
        if ($null -eq $property -or $null -eq $property.Value) {
            return [pscustomobject]@{ Status = 'INCOMPLETE'; Bounds = $null }
        }

        $parsed = 0.0
        $text = [System.Convert]::ToString($property.Value, [Globalization.CultureInfo]::InvariantCulture)
        $validNumber = [double]::TryParse(
            $text,
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$parsed
        )
        if (-not $validNumber -or [double]::IsNaN($parsed) -or [double]::IsInfinity($parsed)) {
            return [pscustomobject]@{ Status = 'INVALID'; Bounds = $null }
        }
        $values[$field] = $parsed
    }

    if ($values.Right -le $values.Left -or $values.Bottom -le $values.Top) {
        return [pscustomobject]@{ Status = 'INVALID'; Bounds = $null }
    }

    return [pscustomobject]@{ Status = 'VALID'; Bounds = [pscustomobject]$values }
}

function Select-BridgeMainComposerCandidate {
    [CmdletBinding()]
    param(
        [object]$MainDocumentOwnershipEstablished,
        [object]$EnumerationComplete,
        [object]$MetadataFresh,
        [object]$MetadataComplete,
        [object]$DocumentGeometry,
        [object]$Candidates
    )

    if ($MainDocumentOwnershipEstablished -isnot [bool] -or -not $MainDocumentOwnershipEstablished) {
        return [pscustomobject]@{ Status = 'MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }
    if ($MetadataFresh -is [bool] -and -not $MetadataFresh) {
        return [pscustomobject]@{ Status = 'CANDIDATE_DATA_STALE'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }
    if ($EnumerationComplete -isnot [bool] -or -not $EnumerationComplete) {
        return [pscustomobject]@{ Status = 'CANDIDATE_ENUMERATION_INCOMPLETE'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }
    if ($MetadataFresh -isnot [bool] -or $MetadataComplete -isnot [bool] -or -not $MetadataComplete) {
        return [pscustomobject]@{ Status = 'CANDIDATE_METADATA_INCOMPLETE'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }

    $documentBounds = ConvertTo-BridgeMainComposerBounds -Rectangle $DocumentGeometry
    if ($documentBounds.Status -eq 'INCOMPLETE') {
        return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }
    if ($documentBounds.Status -ne 'VALID') {
        return [pscustomobject]@{ Status = 'METADATA_INVALID'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }
    if ($null -eq $Candidates) {
        return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = 0; EligibleCount = 0; SelectedCandidate = $null }
    }

    $candidateList = @($Candidates)
    $requiredFields = @(
        'ControlType', 'IsEnabled', 'IsVisible', 'IsKeyboardFocusable',
        'ValuePatternAvailable', 'TextPatternAvailable', 'ValuePatternIsReadOnly',
        'BoundingRectangle'
    )
    $eligible = @()

    foreach ($candidate in $candidateList) {
        if ($null -eq $candidate) {
            return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
        }
        foreach ($field in $requiredFields) {
            if ($null -eq $candidate.PSObject.Properties[$field]) {
                return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
            }
        }
        foreach ($booleanField in @('IsEnabled', 'IsVisible', 'IsKeyboardFocusable', 'ValuePatternAvailable', 'TextPatternAvailable', 'ValuePatternIsReadOnly')) {
            if ($candidate.$booleanField -isnot [bool]) {
                return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
            }
        }
        if ($candidate.ControlType -isnot [string] -or [string]::IsNullOrWhiteSpace($candidate.ControlType)) {
            return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
        }

        $candidateBounds = ConvertTo-BridgeMainComposerBounds -Rectangle $candidate.BoundingRectangle
        if ($candidateBounds.Status -eq 'INCOMPLETE') {
            return [pscustomobject]@{ Status = 'METADATA_INCOMPLETE'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
        }
        if ($candidateBounds.Status -ne 'VALID') {
            return [pscustomobject]@{ Status = 'METADATA_INVALID'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
        }

        $bounds = $candidateBounds.Bounds
        $doc = $documentBounds.Bounds
        $insideDocument = ($bounds.Left -ge $doc.Left -and $bounds.Top -ge $doc.Top -and
            $bounds.Right -le $doc.Right -and $bounds.Bottom -le $doc.Bottom)

        if ($candidate.ControlType -eq 'ControlType.Edit' -and
            $candidate.IsEnabled -and $candidate.IsVisible -and $candidate.IsKeyboardFocusable -and
            $candidate.ValuePatternAvailable -and $candidate.TextPatternAvailable -and
            -not $candidate.ValuePatternIsReadOnly -and $insideDocument) {
            $eligible += ,$candidate
        }
    }

    if ($eligible.Count -eq 0) {
        return [pscustomobject]@{ Status = 'NO_ELIGIBLE_CANDIDATE'; CandidateCount = $candidateList.Count; EligibleCount = 0; SelectedCandidate = $null }
    }
    if ($eligible.Count -gt 1) {
        return [pscustomobject]@{ Status = 'MULTIPLE_ELIGIBLE_CANDIDATES'; CandidateCount = $candidateList.Count; EligibleCount = $eligible.Count; SelectedCandidate = $null }
    }

    return [pscustomobject]@{ Status = 'SELECTED'; CandidateCount = $candidateList.Count; EligibleCount = 1; SelectedCandidate = $eligible[0] }
}
