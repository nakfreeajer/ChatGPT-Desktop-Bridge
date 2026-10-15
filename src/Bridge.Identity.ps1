# BRIDGE.M02-A: pure, side-effect-free conversation identity helpers.
# This file cannot navigate, enter messages or interact with a chat composer.
function Test-BridgeConversationId {
    param([string]$Id)
    return [regex]::IsMatch([string]$Id, '\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
function Get-BridgeConversationIdFromUrl {
    param([string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { return $null }
    $pattern = '\Ahttps://chatgpt\.com/c/(?<id>[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})(?:[/?#].*)?\z'
    $m = [regex]::Match($Address, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $m.Success) { return $null }
    return $m.Groups['id'].Value.ToLowerInvariant()
}
function Test-BridgeHomeAddress {
    param([string]$Address)
    return [regex]::IsMatch([string]$Address, '\A(?:https://)?chatgpt\.com/?\z', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
function Test-BridgeSuggestionTarget {
    param([string]$SuggestionName, [string]$TargetUrl)
    if ([string]::IsNullOrWhiteSpace($SuggestionName) -or [string]::IsNullOrWhiteSpace($TargetUrl)) { return $false }
    $pattern = 'https://chatgpt\.com/c/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}(?=$|[/?#\s])'
    $urls = [regex]::Matches($SuggestionName, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return ($urls.Count -eq 1 -and [string]::Equals($urls[0].Value, $TargetUrl, [System.StringComparison]::OrdinalIgnoreCase))
}
