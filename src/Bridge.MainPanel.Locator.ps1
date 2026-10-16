. (Join-Path $PSScriptRoot 'Bridge.MainComposer.Predicate.ps1')

function Test-BridgeMainPanelNodeWithin {
    param([object]$Node, [int]$AncestorKey, [hashtable]$NodeByKey)

    $parentKey = [int]$Node.ParentKey
    $visited = @{}
    $stepCount = 0
    while ($NodeByKey.ContainsKey($parentKey) -and $stepCount -le $NodeByKey.Count) {
        if ($visited.ContainsKey($parentKey)) { return $false }
        $visited[$parentKey] = $true
        $stepCount++
        if ($parentKey -eq $AncestorKey) { return $true }
        $parent = $NodeByKey[$parentKey]
        if ($parentKey -ne $AncestorKey -and $parent.ControlType -eq 'ControlType.Document') { return $false }
        $parentKey = [int]$parent.ParentKey
    }
    return $false
}

function Select-BridgeMainPanelBranch {
    [CmdletBinding()]
    param(
        [object]$MainDocumentOwnershipEstablished,
        [object]$EnumerationComplete,
        [object]$MetadataFresh,
        [object]$Nodes
    )

    if ($MainDocumentOwnershipEstablished -isnot [bool] -or -not $MainDocumentOwnershipEstablished) {
        return [pscustomobject]@{ Status='MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
    }
    if ($MetadataFresh -is [bool] -and -not $MetadataFresh) {
        return [pscustomobject]@{ Status='STALE_UIA_METADATA'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
    }
    if ($EnumerationComplete -isnot [bool] -or -not $EnumerationComplete) {
        return [pscustomobject]@{ Status='UIA_ENUMERATION_INCOMPLETE'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
    }
    if ($MetadataFresh -isnot [bool] -or $null -eq $Nodes) {
        return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
    }

    $nodeList = @($Nodes)
    $nodeByKey = @{}
    foreach ($node in $nodeList) {
        if ($null -eq $node) { return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null } }
        foreach ($field in @('NodeKey','ParentKey','ControlType','Role','Name','IsStale')) {
            if ($null -eq $node.PSObject.Properties[$field]) { return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null } }
        }
        if ($node.NodeKey -isnot [int] -or $node.ParentKey -isnot [int] -or
            $node.ControlType -isnot [string] -or $node.Role -isnot [string] -or $node.IsStale -isnot [bool]) {
            return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
        }
        if ($node.IsStale) { return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null } }
        if ($nodeByKey.ContainsKey($node.NodeKey)) { return [pscustomobject]@{ Status='UIA_METADATA_AMBIGUOUS'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null } }
        $nodeByKey[$node.NodeKey] = $node
    }
    if (-not $nodeByKey.ContainsKey(0) -or $nodeByKey[0].ControlType -ne 'ControlType.Document') {
        return [pscustomobject]@{ Status='UIA_METADATA_INVALID'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
    }
    foreach ($node in $nodeList) {
        if ($node.NodeKey -ne 0 -and -not $nodeByKey.ContainsKey($node.ParentKey)) {
            return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; MainNode=$null; ConversationRegion=$null; NodeByKey=$null }
        }
    }

    $mainNodes = @($nodeList | Where-Object {
        $_.NodeKey -ne 0 -and $_.Role -eq 'Main' -and (Test-BridgeMainPanelNodeWithin -Node $_ -AncestorKey 0 -NodeByKey $nodeByKey)
    })
    if ($mainNodes.Count -eq 0) { return [pscustomobject]@{ Status='MAIN_LANDMARK_NOT_FOUND'; MainNode=$null; ConversationRegion=$null; NodeByKey=$nodeByKey } }
    if ($mainNodes.Count -ne 1) { return [pscustomobject]@{ Status='AMBIGUOUS_MAIN_LANDMARK'; MainNode=$null; ConversationRegion=$null; NodeByKey=$nodeByKey } }

    $mainNode = $mainNodes[0]
    $regions = @($nodeList | Where-Object {
        $_.Role -eq 'Region' -and $_.Name -ceq 'Conversation' -and
        (Test-BridgeMainPanelNodeWithin -Node $_ -AncestorKey $mainNode.NodeKey -NodeByKey $nodeByKey)
    })
    if ($regions.Count -eq 0) { return [pscustomobject]@{ Status='CONVERSATION_REGION_NOT_FOUND'; MainNode=$mainNode; ConversationRegion=$null; NodeByKey=$nodeByKey } }
    if ($regions.Count -ne 1) { return [pscustomobject]@{ Status='AMBIGUOUS_CONVERSATION_REGION'; MainNode=$mainNode; ConversationRegion=$null; NodeByKey=$nodeByKey } }

    return [pscustomobject]@{ Status='BRANCH_SELECTED'; MainNode=$mainNode; ConversationRegion=$regions[0]; NodeByKey=$nodeByKey }
}

function Select-BridgeMainPanelTargets {
    [CmdletBinding()]
    param(
        [object]$MainDocumentOwnershipEstablished,
        [object]$EnumerationComplete,
        [object]$MetadataFresh,
        [object]$MetadataComplete,
        [object]$DocumentGeometry,
        [object]$Nodes
    )

    $branch = Select-BridgeMainPanelBranch -MainDocumentOwnershipEstablished $MainDocumentOwnershipEstablished `
        -EnumerationComplete $EnumerationComplete -MetadataFresh $MetadataFresh -Nodes $Nodes
    if ($branch.Status -ne 'BRANCH_SELECTED') {
        return [pscustomobject]@{ Status=$branch.Status; Composer=$null; SendButton=$null; MainLandmark=$null; ConversationRegion=$null }
    }
    if ($MetadataComplete -isnot [bool] -or -not $MetadataComplete) {
        return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; Composer=$null; SendButton=$null; MainLandmark=$null; ConversationRegion=$null }
    }

    $nodeList = @($Nodes)
    $regionKey = [int]$branch.ConversationRegion.NodeKey
    $regionNodes = @($nodeList | Where-Object {
        $_.NodeKey -ne $regionKey -and (Test-BridgeMainPanelNodeWithin -Node $_ -AncestorKey $regionKey -NodeByKey $branch.NodeByKey)
    })
    $composerMatches = @($regionNodes | Where-Object { $_.ControlType -eq 'ControlType.Edit' -and $_.Name -ceq 'Ask ChatGPT' })
    if ($composerMatches.Count -eq 0) {
        return [pscustomobject]@{ Status='COMPOSER_NOT_FOUND'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
    }
    if ($composerMatches.Count -ne 1) {
        return [pscustomobject]@{ Status='AMBIGUOUS_COMPOSER'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
    }

    $composer = $composerMatches[0]
    $composerRequired = @('IsEnabled','IsVisible','IsKeyboardFocusable','ValuePatternAvailable','TextPatternAvailable','ValuePatternIsReadOnly','BoundingRectangle')
    foreach ($field in $composerRequired) {
        if ($null -eq $composer.PSObject.Properties[$field]) {
            return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
        }
    }
    $composerDecision = Select-BridgeMainComposerCandidate -MainDocumentOwnershipEstablished $true `
        -EnumerationComplete $true -MetadataFresh $true -MetadataComplete $true `
        -DocumentGeometry $DocumentGeometry -Candidates @($composer)
    if ($composerDecision.Status -ne 'SELECTED') {
        return [pscustomobject]@{ Status='COMPOSER_INELIGIBLE'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
    }

    $sendMatches = @($regionNodes | Where-Object { $_.ControlType -eq 'ControlType.Button' -and $_.Name -ceq 'Send' })
    if ($sendMatches.Count -eq 0) {
        return [pscustomobject]@{ Status='SEND_CONTROL_NOT_FOUND'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
    }
    if ($sendMatches.Count -ne 1) {
        return [pscustomobject]@{ Status='AMBIGUOUS_SEND_CONTROL'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
    }
    $sendButton = $sendMatches[0]
    foreach ($field in @('IsEnabled','IsVisible','InvokePatternAvailable')) {
        if ($null -eq $sendButton.PSObject.Properties[$field] -or $sendButton.$field -isnot [bool]) {
            return [pscustomobject]@{ Status='UIA_METADATA_INCOMPLETE'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
        }
    }
    if (-not $sendButton.IsEnabled -or -not $sendButton.IsVisible -or -not $sendButton.InvokePatternAvailable) {
        return [pscustomobject]@{ Status='SEND_CONTROL_INELIGIBLE'; Composer=$null; SendButton=$null; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
    }

    return [pscustomobject]@{ Status='SELECTED'; Composer=$composer; SendButton=$sendButton; MainLandmark=$branch.MainNode; ConversationRegion=$branch.ConversationRegion }
}

function Get-BridgeMainPanelRoleValue {
    param([object]$Element, [object]$LandmarkProperty)

    $landmarkValue = $Element.GetCurrentPropertyValue($LandmarkProperty, $true)
    $role = if ($null -eq $landmarkValue) { '' } else { [string]$landmarkValue.ToString() }
    if ($role -eq 'Main' -or $role -eq 'Region') { return $role }
    $localizedRole = [string]$Element.Current.LocalizedControlType
    if ($localizedRole -ieq 'main') { return 'Main' }
    if ($localizedRole -ieq 'region') { return 'Region' }
    return ''
}

function Test-BridgeMainPanelUiAAncestry {
    param([object]$Element, [object]$Ancestor, [int]$MaximumDepth = 32)

    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    $current = $Element
    for ($depth = 0; $depth -lt $MaximumDepth -and $null -ne $current; $depth++) {
        if ($current.Equals($Ancestor)) { return $true }
        $current = $walker.GetParent($current)
    }
    return $false
}

function Get-BridgeMainPanelHumanAnchorPath {
    param([object]$WindowRoot, [object]$HumanAnchor, [object]$ExpectedWindowHandle, [int]$MaximumDepth = 32)

    try {
        if ($null -eq $WindowRoot -or $null -eq $HumanAnchor -or
            $WindowRoot -isnot [System.Windows.Automation.AutomationElement] -or
            $HumanAnchor -isnot [System.Windows.Automation.AutomationElement] -or
            [IntPtr]$ExpectedWindowHandle -eq [IntPtr]::Zero -or
            [int]$WindowRoot.Current.NativeWindowHandle -ne ([IntPtr]$ExpectedWindowHandle).ToInt32()) {
            return [pscustomobject]@{ Status='OWNERSHIP_EVIDENCE_INVALID'; Document=$null; Main=$null; Region=$null }
        }

        $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
        $landmarkProperty = [System.Windows.Automation.AutomationElementIdentifiers]::LandmarkTypeProperty
        $current = $HumanAnchor
        $region = $null
        $main = $null
        $document = $null
        for ($depth = 0; $depth -lt $MaximumDepth -and $null -ne $current; $depth++) {
            if ($current.Equals($WindowRoot)) {
                if ($null -ne $document -and $null -ne $main -and $null -ne $region) {
                    return [pscustomobject]@{ Status='HUMAN_ANCHOR_VERIFIED'; Document=$document; Main=$main; Region=$region }
                }
                break
            }
            $controlType = $current.Current.ControlType
            if ($controlType -eq [System.Windows.Automation.ControlType]::Document) {
                if ($null -ne $document -or $null -eq $main -or $null -eq $region) { break }
                $document = $current
            }
            $role = Get-BridgeMainPanelRoleValue -Element $current -LandmarkProperty $landmarkProperty
            if ($null -eq $region -and $role -eq 'Region' -and [string]$current.Current.Name -ceq 'Conversation') { $region = $current }
            if ($null -ne $region -and $null -eq $main -and $role -eq 'Main') { $main = $current }
            $current = $walker.GetParent($current)
        }
    } catch { }
    return [pscustomobject]@{ Status='MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED'; Document=$null; Main=$null; Region=$null }
}

function New-BridgeMainPanelOwnershipEvidence {
    [CmdletBinding()]
    param([object]$WindowRoot, [object]$HumanAnchor, [object]$WindowHandle)

    $path = Get-BridgeMainPanelHumanAnchorPath -WindowRoot $WindowRoot -HumanAnchor $HumanAnchor -ExpectedWindowHandle $WindowHandle
    if ($path.Status -ne 'HUMAN_ANCHOR_VERIFIED') {
        return [pscustomobject]@{ Status=$path.Status; Evidence=$null }
    }
    return [pscustomobject]@{
        Status='HUMAN_ANCHOR_VERIFIED'
        Evidence=[pscustomobject]@{
            EvidenceKind='HUMAN_ANCHORED_MAIN_PANEL'
            DocumentElement=$path.Document
            WindowRoot=$WindowRoot
            HumanAnchor=$HumanAnchor
            MainLandmark=$path.Main
            ConversationRegion=$path.Region
            WindowHandle=[IntPtr]$WindowHandle
            IsFresh=$true
            MainDesktopBound=$false
            ConversationIdentity='UNRESOLVED'
        }
    }
}

function Test-BridgeMainPanelOwnershipEvidenceEnvelope {
    param([object]$Evidence, [object]$DocumentElement)

    if ($null -eq $Evidence) { return 'OWNERSHIP_EVIDENCE_UNAVAILABLE' }
    foreach ($field in @('EvidenceKind','DocumentElement','WindowRoot','HumanAnchor','MainLandmark','ConversationRegion','WindowHandle','IsFresh','MainDesktopBound','ConversationIdentity')) {
        if ($null -eq $Evidence.PSObject.Properties[$field]) { return 'OWNERSHIP_EVIDENCE_INVALID' }
    }
    if ($Evidence.EvidenceKind -ne 'HUMAN_ANCHORED_MAIN_PANEL') { return 'OWNERSHIP_EVIDENCE_UNSUPPORTED' }
    if ($Evidence.IsFresh -isnot [bool] -or -not $Evidence.IsFresh) { return 'OWNERSHIP_EVIDENCE_STALE' }
    if ($Evidence.MainDesktopBound -isnot [bool] -or $Evidence.MainDesktopBound -or $Evidence.ConversationIdentity -ne 'UNRESOLVED') {
        return 'OWNERSHIP_EVIDENCE_INVALID'
    }
    if ($null -eq $DocumentElement -or $null -eq $Evidence.DocumentElement) {
        return 'OWNERSHIP_EVIDENCE_INVALID'
    }
    try {
        if (-not [object]::ReferenceEquals($DocumentElement, $Evidence.DocumentElement)) { return 'OWNERSHIP_EVIDENCE_DOCUMENT_MISMATCH' }
    } catch { return 'OWNERSHIP_EVIDENCE_STALE' }
    return 'OWNERSHIP_EVIDENCE_VALID'
}

function Test-BridgeMainPanelControlIdentityEqual {
    param([object]$First, [object]$Second)
    if ($null -eq $First -or $null -eq $Second) { return $false }
    try {
        return [bool]$First.Equals($Second)
    } catch { return $false }
}

function Confirm-BridgeMainPanelFinalSnapshot {
    param([object]$EnumerationComplete, [object]$ComposerCandidates, [object]$SendCandidates, [object]$DocumentGeometry, [object]$OriginalComposer, [object]$OriginalSend)

    if ($EnumerationComplete -isnot [bool] -or -not $EnumerationComplete) { return 'FINAL_ENUMERATION_INCOMPLETE' }
    $composers = @($ComposerCandidates | Where-Object { $_.ControlType -eq 'ControlType.Edit' -and $_.Name -ceq 'Ask ChatGPT' })
    $sends = @($SendCandidates | Where-Object { $_.ControlType -eq 'ControlType.Button' -and $_.Name -ceq 'Send' })
    if ($composers.Count -eq 0) { return 'FINAL_COMPOSER_MISSING' }
    if ($composers.Count -gt 1) { return 'FINAL_COMPOSER_AMBIGUOUS' }
    if ($sends.Count -eq 0) { return 'FINAL_SEND_MISSING' }
    if ($sends.Count -gt 1) { return 'FINAL_SEND_AMBIGUOUS' }
    $eligible = Select-BridgeMainComposerCandidate -MainDocumentOwnershipEstablished $true -EnumerationComplete $true `
        -MetadataFresh $true -MetadataComplete $true -DocumentGeometry $DocumentGeometry -Candidates $composers
    if ($eligible.Status -ne 'SELECTED') { return 'FINAL_COMPOSER_INELIGIBLE' }
    $send = $sends[0]
    foreach ($field in @('IsEnabled','IsVisible','InvokePatternAvailable')) {
        if ($null -eq $send.PSObject.Properties[$field] -or $send.$field -isnot [bool]) { return 'FINAL_METADATA_INCOMPLETE' }
    }
    if (-not $send.IsEnabled -or -not $send.IsVisible -or -not $send.InvokePatternAvailable) { return 'FINAL_SEND_INELIGIBLE' }
    if (-not (Test-BridgeMainPanelControlIdentityEqual -First $composers[0].Identity -Second $OriginalComposer) -or
        -not (Test-BridgeMainPanelControlIdentityEqual -First $send.Identity -Second $OriginalSend)) { return 'FINAL_CONTROL_REPLACED' }
    return 'FINAL_SNAPSHOT_VERIFIED'
}

function Get-BridgeMainPanelFinalRegionSnapshot {
    param([object]$RegionElement, [object]$DocumentElement, [object]$OriginalComposer, [object]$OriginalSend, [int]$MaximumNodes=2500, [int]$MaximumDepth=24)
    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue([pscustomobject]@{ Element=$RegionElement; Depth=0 })
    $edits = @(); $buttons = @(); $visited = 0
    try {
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            if ($item.Depth -ge $MaximumDepth) {
                if ($null -ne $walker.GetFirstChild($item.Element)) { return 'FINAL_ENUMERATION_INCOMPLETE' }
                continue
            }
            $child = $walker.GetFirstChild($item.Element)
            while ($null -ne $child) {
                $visited++
                if ($visited -gt $MaximumNodes) { return 'FINAL_ENUMERATION_INCOMPLETE' }
                $type = $child.Current.ControlType
                if ($type -eq [System.Windows.Automation.ControlType]::Document) {
                    $child = $walker.GetNextSibling($child); continue
                }
                if ($type -eq [System.Windows.Automation.ControlType]::Edit -or $type -eq [System.Windows.Automation.ControlType]::Button) {
                    $patterns = @($child.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
                    $entry = [pscustomobject]@{
                        Identity=$child; ControlType=$type.ProgrammaticName; Name=[string]$child.Current.Name
                        IsEnabled=[bool]$child.Current.IsEnabled; IsVisible=(-not [bool]$child.Current.IsOffscreen)
                    }
                    if ($type -eq [System.Windows.Automation.ControlType]::Edit) {
                        $entry | Add-Member IsKeyboardFocusable ([bool]$child.Current.IsKeyboardFocusable)
                        $entry | Add-Member ValuePatternAvailable ($patterns -contains 'ValuePatternIdentifiers.Pattern')
                        $entry | Add-Member TextPatternAvailable ($patterns -contains 'TextPatternIdentifiers.Pattern')
                        $entry | Add-Member ValuePatternIsReadOnly ([bool]$child.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.IsReadOnly)
                        $rect = $child.Current.BoundingRectangle
                        $entry | Add-Member BoundingRectangle ([pscustomobject]@{Left=$rect.Left;Top=$rect.Top;Right=$rect.Right;Bottom=$rect.Bottom})
                        $edits += ,$entry
                    } else {
                        $entry | Add-Member InvokePatternAvailable ($patterns -contains 'InvokePatternIdentifiers.Pattern')
                        $buttons += ,$entry
                    }
                }
                $queue.Enqueue([pscustomobject]@{Element=$child;Depth=($item.Depth+1)})
                $child = $walker.GetNextSibling($child)
            }
        }
    } catch { return 'FINAL_UIA_STATE_UNAVAILABLE' }

    try {
        if ($DocumentElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Document) { return 'FINAL_DOCUMENT_CHANGED' }
        $documentRect = $DocumentElement.Current.BoundingRectangle
        $DocumentGeometry = [pscustomobject]@{Left=$documentRect.Left;Top=$documentRect.Top;Right=$documentRect.Right;Bottom=$documentRect.Bottom}
    } catch { return 'FINAL_UIA_STATE_UNAVAILABLE' }

    $originalComposerNode = $OriginalComposer
    $originalSendNode = $OriginalSend
    $composerIdentity = $originalComposerNode.Element
    $sendIdentity = $originalSendNode.Element
    Confirm-BridgeMainPanelFinalSnapshot -EnumerationComplete $true -ComposerCandidates $edits -SendCandidates $buttons `
        -DocumentGeometry $DocumentGeometry -OriginalComposer $composerIdentity -OriginalSend $sendIdentity
}

function Get-BridgeMainPanelControls {
    [CmdletBinding()]
    param(
        [object]$DocumentElement,
        [object]$OwnershipEvidence,
        [int]$MaximumNodes = 2500,
        [int]$MaximumDepth = 24
    )

    $evidenceStatus = Test-BridgeMainPanelOwnershipEvidenceEnvelope -Evidence $OwnershipEvidence -DocumentElement $DocumentElement
    if ($evidenceStatus -ne 'OWNERSHIP_EVIDENCE_VALID') {
        return [pscustomobject]@{ Status=$evidenceStatus; Composer=$null; SendButton=$null; TraversalStarted=$false; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }
    if ($MaximumNodes -lt 1 -or $MaximumNodes -gt 5000 -or $MaximumDepth -lt 1 -or $MaximumDepth -gt 32) {
        return [pscustomobject]@{ Status='INVALID_TRAVERSAL_LIMIT'; Composer=$null; SendButton=$null; TraversalStarted=$false }
    }
    $ownershipPath = Get-BridgeMainPanelHumanAnchorPath -WindowRoot $OwnershipEvidence.WindowRoot `
        -HumanAnchor $OwnershipEvidence.HumanAnchor -ExpectedWindowHandle $OwnershipEvidence.WindowHandle
    if ($ownershipPath.Status -ne 'HUMAN_ANCHOR_VERIFIED' -or
        -not $ownershipPath.Document.Equals($DocumentElement) -or
        -not $ownershipPath.Main.Equals($OwnershipEvidence.MainLandmark) -or
        -not $ownershipPath.Region.Equals($OwnershipEvidence.ConversationRegion)) {
        return [pscustomobject]@{ Status='OWNERSHIP_EVIDENCE_STALE'; Composer=$null; SendButton=$null; TraversalStarted=$false; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }
    if ($null -eq $DocumentElement -or $DocumentElement -isnot [System.Windows.Automation.AutomationElement]) {
        return [pscustomobject]@{ Status='DOCUMENT_ELEMENT_UNAVAILABLE'; Composer=$null; SendButton=$null; TraversalStarted=$false }
    }

    try {
        if ($DocumentElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Document) {
            return [pscustomobject]@{ Status='DOCUMENT_ELEMENT_INVALID'; Composer=$null; SendButton=$null; TraversalStarted=$false }
        }
        $landmarkProperty = [System.Windows.Automation.AutomationElementIdentifiers]::LandmarkTypeProperty
        $documentRectValue = $DocumentElement.Current.BoundingRectangle
        $documentRect = [pscustomobject]@{ Left=$documentRectValue.Left; Top=$documentRectValue.Top; Right=$documentRectValue.Right; Bottom=$documentRectValue.Bottom }
    } catch {
        return [pscustomobject]@{ Status='UIA_METADATA_UNAVAILABLE'; Composer=$null; SendButton=$null; TraversalStarted=$false }
    }

    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    $queue = New-Object System.Collections.Queue
    $rootNode = [pscustomobject]@{ NodeKey=0; ParentKey=-1; Depth=0; Element=$DocumentElement; ControlType='ControlType.Document'; Role='Document'; Name=$null; IsStale=$false }
    $nodes = @($rootNode)
    $queue.Enqueue($rootNode)
    $nextKey = 1
    $traversalComplete = $true

    while ($queue.Count -gt 0) {
        $parentNode = $queue.Dequeue()
        if ($parentNode.Depth -ge $MaximumDepth) {
            $childProbe = $null
            try { $childProbe = $walker.GetFirstChild($parentNode.Element) } catch { return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; Composer=$null; SendButton=$null; TraversalStarted=$true } }
            if ($null -ne $childProbe) { $traversalComplete = $false }
            continue
        }
        $child = $null
        try { $child = $walker.GetFirstChild($parentNode.Element) } catch { return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; Composer=$null; SendButton=$null; TraversalStarted=$true } }
        while ($null -ne $child) {
            if ($nodes.Count -ge $MaximumNodes) { $traversalComplete = $false; break }
            try {
                $controlType = $child.Current.ControlType
                if ($controlType -eq [System.Windows.Automation.ControlType]::Document) {
                    $child = $walker.GetNextSibling($child)
                    continue
                }
                $role = Get-BridgeMainPanelRoleValue -Element $child -LandmarkProperty $landmarkProperty
                $name = $null
                if ($role -eq 'Region') { $name = [string]$child.Current.Name }
                $node = [pscustomobject]@{ NodeKey=$nextKey; ParentKey=[int]$parentNode.NodeKey; Depth=($parentNode.Depth+1); Element=$child; ControlType=$controlType.ProgrammaticName; Role=$role; Name=$name; IsStale=$false }
                $nodes += ,$node
                $queue.Enqueue($node)
                $nextKey++
                $child = $walker.GetNextSibling($child)
            } catch {
                return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; Composer=$null; SendButton=$null; TraversalStarted=$true }
            }
        }
        if (-not $traversalComplete) { break }
    }

    if (-not $traversalComplete) {
        return [pscustomobject]@{ Status='UIA_ENUMERATION_INCOMPLETE'; Composer=$null; SendButton=$null; TraversalStarted=$true }
    }
    $branch = Select-BridgeMainPanelBranch -MainDocumentOwnershipEstablished $true -EnumerationComplete $true -MetadataFresh $true -Nodes $nodes
    if ($branch.Status -ne 'BRANCH_SELECTED') {
        return [pscustomobject]@{ Status=$branch.Status; Composer=$null; SendButton=$null; TraversalStarted=$true }
    }
    if (-not $branch.MainNode.Element.Equals($ownershipPath.Main) -or
        -not $branch.ConversationRegion.Element.Equals($ownershipPath.Region)) {
        return [pscustomobject]@{ Status='OWNERSHIP_EVIDENCE_STRUCTURE_MISMATCH'; Composer=$null; SendButton=$null; TraversalStarted=$true; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }

    $nodeByKey = $branch.NodeByKey
    foreach ($node in $nodes) {
        if ($node.NodeKey -eq 0 -or $node.ControlType -notin @('ControlType.Edit','ControlType.Button')) { continue }
        if (-not (Test-BridgeMainPanelNodeWithin -Node $node -AncestorKey $branch.ConversationRegion.NodeKey -NodeByKey $nodeByKey)) { continue }
        try {
            $node.Name = [string]$node.Element.Current.Name
            $node.IsEnabled = [bool]$node.Element.Current.IsEnabled
            $node.IsVisible = -not [bool]$node.Element.Current.IsOffscreen
            if ($node.ControlType -eq 'ControlType.Edit') {
                $node.IsKeyboardFocusable = [bool]$node.Element.Current.IsKeyboardFocusable
                $patternNames = @($node.Element.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
                $node.ValuePatternAvailable = $patternNames -contains 'ValuePatternIdentifiers.Pattern'
                $node.TextPatternAvailable = $patternNames -contains 'TextPatternIdentifiers.Pattern'
                $node.ValuePatternIsReadOnly = $true
                if ($node.ValuePatternAvailable) {
                    $valuePattern = $node.Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
                    $node.ValuePatternIsReadOnly = [bool]$valuePattern.Current.IsReadOnly
                }
                $rectangle = $node.Element.Current.BoundingRectangle
                $node.BoundingRectangle = [pscustomobject]@{ Left=$rectangle.Left; Top=$rectangle.Top; Right=$rectangle.Right; Bottom=$rectangle.Bottom }
            } else {
                $buttonPatterns = @($node.Element.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
                $node.InvokePatternAvailable = $buttonPatterns -contains 'InvokePatternIdentifiers.Pattern'
            }
        } catch {
            return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; Composer=$null; SendButton=$null; TraversalStarted=$true }
        }
    }

    $selection = Select-BridgeMainPanelTargets -MainDocumentOwnershipEstablished $true -EnumerationComplete $true `
        -MetadataFresh $true -MetadataComplete $true -DocumentGeometry $documentRect -Nodes $nodes
    if ($selection.Status -ne 'SELECTED') {
        return [pscustomobject]@{ Status=$selection.Status; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }

    try {
        if ($DocumentElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Document -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.MainLandmark.Element -Ancestor $DocumentElement) -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.ConversationRegion.Element -Ancestor $selection.MainLandmark.Element) -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.Composer.Element -Ancestor $selection.ConversationRegion.Element) -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.SendButton.Element -Ancestor $selection.ConversationRegion.Element)) {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
        }
        $ownershipPathNow = Get-BridgeMainPanelHumanAnchorPath -WindowRoot $OwnershipEvidence.WindowRoot `
            -HumanAnchor $OwnershipEvidence.HumanAnchor -ExpectedWindowHandle $OwnershipEvidence.WindowHandle
        if ($ownershipPathNow.Status -ne 'HUMAN_ANCHOR_VERIFIED' -or
            -not $ownershipPathNow.Document.Equals($DocumentElement) -or
            -not $ownershipPathNow.Main.Equals($selection.MainLandmark.Element) -or
            -not $ownershipPathNow.Region.Equals($selection.ConversationRegion.Element)) {
            return [pscustomobject]@{ Status='OWNERSHIP_EVIDENCE_STALE'; Composer=$null; SendButton=$null; TraversalStarted=$true; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
        }
        $mainRoleNow = Get-BridgeMainPanelRoleValue -Element $selection.MainLandmark.Element -LandmarkProperty $landmarkProperty
        $regionRoleNow = Get-BridgeMainPanelRoleValue -Element $selection.ConversationRegion.Element -LandmarkProperty $landmarkProperty
        if ($mainRoleNow -ne 'Main' -or $regionRoleNow -ne 'Region' -or
            [string]$selection.ConversationRegion.Element.Current.Name -cne 'Conversation') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
        }

        $composerElement = $selection.Composer.Element
        $composerPatternsNow = @($composerElement.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
        $freshComposer = [pscustomobject]@{
            ControlType = $composerElement.Current.ControlType.ProgrammaticName
            IsEnabled = [bool]$composerElement.Current.IsEnabled
            IsVisible = -not [bool]$composerElement.Current.IsOffscreen
            IsKeyboardFocusable = [bool]$composerElement.Current.IsKeyboardFocusable
            ValuePatternAvailable = ($composerPatternsNow -contains 'ValuePatternIdentifiers.Pattern')
            TextPatternAvailable = ($composerPatternsNow -contains 'TextPatternIdentifiers.Pattern')
            ValuePatternIsReadOnly = [bool]$composerElement.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).Current.IsReadOnly
            BoundingRectangle = $null
        }
        if ([string]$composerElement.Current.Name -cne 'Ask ChatGPT') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
        }
        $documentRectNow = $DocumentElement.Current.BoundingRectangle
        $freshDocumentRect = [pscustomobject]@{Left=$documentRectNow.Left;Top=$documentRectNow.Top;Right=$documentRectNow.Right;Bottom=$documentRectNow.Bottom}
        $freshRect = $composerElement.Current.BoundingRectangle
        $freshComposer.BoundingRectangle = [pscustomobject]@{Left=$freshRect.Left;Top=$freshRect.Top;Right=$freshRect.Right;Bottom=$freshRect.Bottom}
        $freshComposerDecision = Select-BridgeMainComposerCandidate -MainDocumentOwnershipEstablished $true `
            -EnumerationComplete $true -MetadataFresh $true -MetadataComplete $true -DocumentGeometry $freshDocumentRect -Candidates @($freshComposer)
        if ($freshComposerDecision.Status -ne 'SELECTED') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
        }

        $sendElement = $selection.SendButton.Element
        $sendPatternsNow = @($sendElement.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
        if ($sendElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Button -or
            [string]$sendElement.Current.Name -cne 'Send' -or -not [bool]$sendElement.Current.IsEnabled -or
            [bool]$sendElement.Current.IsOffscreen -or $sendPatternsNow -notcontains 'InvokePatternIdentifiers.Pattern') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
        }
    } catch {
        return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }

    $finalSnapshotStatus = Get-BridgeMainPanelFinalRegionSnapshot -RegionElement $selection.ConversationRegion.Element `
        -DocumentElement $DocumentElement -OriginalComposer $selection.Composer -OriginalSend $selection.SendButton `
        -MaximumNodes $MaximumNodes -MaximumDepth $MaximumDepth
    if ($finalSnapshotStatus -ne 'FINAL_SNAPSHOT_VERIFIED') {
        return [pscustomobject]@{ Status=$finalSnapshotStatus; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }
    $ownershipPathFinal = Get-BridgeMainPanelHumanAnchorPath -WindowRoot $OwnershipEvidence.WindowRoot `
        -HumanAnchor $OwnershipEvidence.HumanAnchor -ExpectedWindowHandle $OwnershipEvidence.WindowHandle
    if ($ownershipPathFinal.Status -ne 'HUMAN_ANCHOR_VERIFIED' -or
        -not $ownershipPathFinal.Document.Equals($DocumentElement) -or
        -not $ownershipPathFinal.Main.Equals($selection.MainLandmark.Element) -or
        -not $ownershipPathFinal.Region.Equals($selection.ConversationRegion.Element)) {
        return [pscustomobject]@{ Status='OWNERSHIP_EVIDENCE_STALE'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
    }

    return [pscustomobject]@{ Status='SELECTED'; Composer=$selection.Composer; SendButton=$selection.SendButton; TraversalStarted=$true; SnapshotOnly=$true; OwnershipSource='HUMAN_ANCHORED'; MainDesktopBound=$false; MainConversationIdentity='UNRESOLVED' }
}
