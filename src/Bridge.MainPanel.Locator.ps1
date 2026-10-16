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

function Get-BridgeMainPanelControls {
    [CmdletBinding()]
    param(
        [object]$DocumentElement,
        [object]$MainDocumentOwnershipEstablished,
        [int]$MaximumNodes = 2500,
        [int]$MaximumDepth = 24
    )

    if ($MainDocumentOwnershipEstablished -isnot [bool] -or -not $MainDocumentOwnershipEstablished) {
        return [pscustomobject]@{ Status='MAIN_DOCUMENT_OWNERSHIP_UNVERIFIED'; Composer=$null; SendButton=$null; TraversalStarted=$false }
    }
    if ($MaximumNodes -lt 1 -or $MaximumNodes -gt 5000 -or $MaximumDepth -lt 1 -or $MaximumDepth -gt 32) {
        return [pscustomobject]@{ Status='INVALID_TRAVERSAL_LIMIT'; Composer=$null; SendButton=$null; TraversalStarted=$false }
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
        return [pscustomobject]@{ Status=$selection.Status; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
    }

    try {
        if ($DocumentElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Document -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.MainLandmark.Element -Ancestor $DocumentElement) -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.ConversationRegion.Element -Ancestor $selection.MainLandmark.Element) -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.Composer.Element -Ancestor $selection.ConversationRegion.Element) -or
            -not (Test-BridgeMainPanelUiAAncestry -Element $selection.SendButton.Element -Ancestor $selection.ConversationRegion.Element)) {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
        }
        $mainRoleNow = Get-BridgeMainPanelRoleValue -Element $selection.MainLandmark.Element -LandmarkProperty $landmarkProperty
        $regionRoleNow = Get-BridgeMainPanelRoleValue -Element $selection.ConversationRegion.Element -LandmarkProperty $landmarkProperty
        if ($mainRoleNow -ne 'Main' -or $regionRoleNow -ne 'Region' -or
            [string]$selection.ConversationRegion.Element.Current.Name -cne 'Conversation') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
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
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
        }
        $documentRectNow = $DocumentElement.Current.BoundingRectangle
        $freshDocumentRect = [pscustomobject]@{Left=$documentRectNow.Left;Top=$documentRectNow.Top;Right=$documentRectNow.Right;Bottom=$documentRectNow.Bottom}
        $freshRect = $composerElement.Current.BoundingRectangle
        $freshComposer.BoundingRectangle = [pscustomobject]@{Left=$freshRect.Left;Top=$freshRect.Top;Right=$freshRect.Right;Bottom=$freshRect.Bottom}
        $freshComposerDecision = Select-BridgeMainComposerCandidate -MainDocumentOwnershipEstablished $true `
            -EnumerationComplete $true -MetadataFresh $true -MetadataComplete $true -DocumentGeometry $freshDocumentRect -Candidates @($freshComposer)
        if ($freshComposerDecision.Status -ne 'SELECTED') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
        }

        $sendElement = $selection.SendButton.Element
        $sendPatternsNow = @($sendElement.GetSupportedPatterns() | ForEach-Object { $_.ProgrammaticName })
        if ($sendElement.Current.ControlType -ne [System.Windows.Automation.ControlType]::Button -or
            [string]$sendElement.Current.Name -cne 'Send' -or -not [bool]$sendElement.Current.IsEnabled -or
            [bool]$sendElement.Current.IsOffscreen -or $sendPatternsNow -notcontains 'InvokePatternIdentifiers.Pattern') {
            return [pscustomobject]@{ Status='UIA_TARGET_CHANGED'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
        }
    } catch {
        return [pscustomobject]@{ Status='STALE_UIA_ELEMENT'; Composer=$null; SendButton=$null; TraversalStarted=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
    }

    return [pscustomobject]@{ Status='SELECTED'; Composer=$selection.Composer; SendButton=$selection.SendButton; TraversalStarted=$true; SnapshotOnly=$true; OwnershipSource='CALLER_ASSERTED'; MainConversationIdentity='UNRESOLVED' }
}
