# BRIDGE.M02-E.1B: operation-local selection of one ChatGPT conversation window.
# Qualifying HWNDs are visible, enabled, ownerless, non-tool, non-child and
# non-popup top-level windows belonging to ChatGPT.exe. Owned/tool/popup
# windows are treated as transient UI and never as conversation windows.

function Resolve-BridgeWindowSelection {
    param([bool]$EnumerationComplete,[object[]]$Candidates=@())
    if(-not $EnumerationComplete){return [pscustomobject]@{Status='WINDOW_ENUMERATION_FAILED';Window=$null;QualifyingCount=0}}
    $qualifying=@()
    foreach($candidate in @($Candidates)){
        if($null -eq $candidate){return [pscustomobject]@{Status='WINDOW_ENUMERATION_FAILED';Window=$null;QualifyingCount=0}}
        try{
            foreach($field in @('Handle','ProcessId','ProcessName','IsVisible','IsEnabled','OwnerHandle','Style','ExtendedStyle')){
                if($null -eq $candidate.PSObject.Properties[$field]){throw 'CANDIDATE_FIELD_MISSING'}
            }
            $handle=if($candidate.Handle -is [IntPtr]){$candidate.Handle.ToInt64()}else{[long]$candidate.Handle}
            $owner=if($candidate.OwnerHandle -is [IntPtr]){$candidate.OwnerHandle.ToInt64()}else{[long]$candidate.OwnerHandle}
            $processId=[int]$candidate.ProcessId
            $processName=[string]$candidate.ProcessName
            $visible=[bool]$candidate.IsVisible
            $enabled=[bool]$candidate.IsEnabled
            $style=[long]$candidate.Style
            $extendedStyle=[long]$candidate.ExtendedStyle
            if($handle -eq 0 -or $processId -le 0 -or [string]::IsNullOrWhiteSpace($processName)){
                throw 'CANDIDATE_METADATA_INVALID'
            }
        }catch{
            return [pscustomobject]@{Status='WINDOW_ENUMERATION_FAILED';Window=$null;QualifyingCount=0}
        }
        $isChild=(($style -band [long]0x40000000) -ne 0)
        $isPopup=(($style -band [long]0x80000000) -ne 0)
        $isToolWindow=(($extendedStyle -band [long]0x80) -ne 0)
        if([string]::Equals($processName,'ChatGPT',[System.StringComparison]::OrdinalIgnoreCase) -and
            $visible -and $enabled -and $owner -eq 0 -and -not $isChild -and -not $isPopup -and -not $isToolWindow){
            $qualifying+=,[pscustomobject]@{Handle=[IntPtr]$handle;ProcessId=$processId}
        }
    }
    if($qualifying.Count -eq 0){return [pscustomobject]@{Status='WINDOW_NOT_FOUND';Window=$null;QualifyingCount=0}}
    if($qualifying.Count -ne 1){return [pscustomobject]@{Status='AMBIGUOUS_WINDOW';Window=$null;QualifyingCount=$qualifying.Count}}
    return [pscustomobject]@{Status='OK';Window=$qualifying[0];QualifyingCount=1}
}

function Test-BridgeWindowSelectionStable {
    param($Baseline,$CurrentSelection)
    if($null -eq $Baseline -or $null -eq $CurrentSelection -or $CurrentSelection.Status -ne 'OK' -or
        [int]$CurrentSelection.QualifyingCount -ne 1 -or $null -eq $CurrentSelection.Window){return $false}
    try{
        $beforeHandle=if($Baseline.Handle -is [IntPtr]){$Baseline.Handle.ToInt64()}else{[long]$Baseline.Handle}
        $afterHandle=if($CurrentSelection.Window.Handle -is [IntPtr]){$CurrentSelection.Window.Handle.ToInt64()}else{[long]$CurrentSelection.Window.Handle}
        return ($beforeHandle -ne 0 -and $beforeHandle -eq $afterHandle -and
            [int]$Baseline.ProcessId -eq [int]$CurrentSelection.Window.ProcessId)
    }catch{return $false}
}

function Get-BridgeTopLevelWindowCandidates {
    $empty=[pscustomobject]@{EnumerationComplete=$false;Candidates=@()}
    try{
        if(-not ('BridgeWindowEnumeratorE1B' -as [type])){
            Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class BridgeWindowEnumeratorE1B {
    private delegate bool EnumWindowsCallback(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr lParam);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint command);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsWindowEnabled(IntPtr hWnd);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW", SetLastError=true)]
    private static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern void SetLastError(uint error);
    public static int ReadWindowLong(IntPtr hWnd, int index) {
        SetLastError(0);
        int value = GetWindowLong(hWnd, index);
        int error = Marshal.GetLastWin32Error();
        if (value == 0 && error != 0) throw new System.ComponentModel.Win32Exception(error);
        return value;
    }
    public static IntPtr[] Enumerate(out bool completed) {
        var handles = new List<IntPtr>();
        EnumWindowsCallback callback = delegate(IntPtr hWnd, IntPtr lParam) {
            handles.Add(hWnd);
            return true;
        };
        bool result = EnumWindows(callback, IntPtr.Zero);
        completed = result;
        return handles.ToArray();
    }
}
'@ -ErrorAction Stop | Out-Null
        }
        $completed=$false
        $handles=[BridgeWindowEnumeratorE1B]::Enumerate([ref]$completed)
        if(-not $completed){return $empty}
        $processNames=@{}
        $candidates=@()
        foreach($handle in $handles){
            if(-not [BridgeWindowEnumeratorE1B]::IsWindow($handle)){return $empty}
            [uint32]$processId=0
            $threadId=[BridgeWindowEnumeratorE1B]::GetWindowThreadProcessId($handle,[ref]$processId)
            if($threadId -eq 0 -or $processId -eq 0){return $empty}
            if(-not $processNames.ContainsKey([int]$processId)){
                $process=Get-Process -Id ([int]$processId) -ErrorAction Stop
                try{$processNames[[int]$processId]=[string]$process.ProcessName}finally{$process.Dispose()}
            }
            $owner=[BridgeWindowEnumeratorE1B]::GetWindow($handle,[uint32]4)
            $style=[BridgeWindowEnumeratorE1B]::ReadWindowLong($handle,-16)
            $extendedStyle=[BridgeWindowEnumeratorE1B]::ReadWindowLong($handle,-20)
            $candidates+=,[pscustomobject]@{
                Handle=$handle;ProcessId=[int]$processId;ProcessName=$processNames[[int]$processId]
                IsVisible=[BridgeWindowEnumeratorE1B]::IsWindowVisible($handle)
                IsEnabled=[BridgeWindowEnumeratorE1B]::IsWindowEnabled($handle)
                OwnerHandle=$owner;Style=[long]$style;ExtendedStyle=[long]$extendedStyle
            }
        }
        return [pscustomobject]@{EnumerationComplete=$true;Candidates=$candidates}
    }catch{return $empty}
}

function Get-BridgeCurrentWindowSelection {
    param([scriptblock]$Enumerator)
    try{
        if($null -ne $Enumerator){$snapshot=& $Enumerator}else{$snapshot=Get-BridgeTopLevelWindowCandidates}
        if($null -eq $snapshot -or $null -eq $snapshot.PSObject.Properties['EnumerationComplete'] -or
            $null -eq $snapshot.PSObject.Properties['Candidates']){
            return (Resolve-BridgeWindowSelection -EnumerationComplete $false)
        }
        return (Resolve-BridgeWindowSelection -EnumerationComplete ([bool]$snapshot.EnumerationComplete) -Candidates $snapshot.Candidates)
    }catch{
        return (Resolve-BridgeWindowSelection -EnumerationComplete $false)
    }
}
