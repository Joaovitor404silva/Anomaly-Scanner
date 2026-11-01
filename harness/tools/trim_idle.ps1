param([ValidateSet('2', '3', 'all')][string]$Pair = '3', [switch]$Loop, [int]$EverySec = 120)
$sig = @'
using System; using System.Runtime.InteropServices;
public static class TW { [DllImport("psapi.dll")] public static extern bool EmptyWorkingSet(IntPtr h); }
'@
if (-not ('TW' -as [type])) { Add-Type -TypeDefinition $sig }
$roots = switch ($Pair) { '2' { @('C:\S2DevRootHost2\', 'C:\S2DevRoot2\', 'C:\S2DevRoot3\') } '3' { @('C:\S2DevRootHostP3\', 'C:\S2DevRootP3\') } default { @('C:\S2DevRootHost2\', 'C:\S2DevRoot2\', 'C:\S2DevRoot3\', 'C:\S2DevRootHostP3\', 'C:\S2DevRootP3\') } }
do {
  $before = 0; $after = 0; $n = 0
  foreach ($w in Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'") {
    if (-not ($roots | Where-Object { $w.ExecutablePath -like "$_*" })) { continue }
    $p = Get-Process -Id $w.ProcessId -ErrorAction SilentlyContinue; if (-not $p) { continue }
    $before += $p.WorkingSet64; [void][TW]::EmptyWorkingSet($p.Handle); $p.Refresh(); $after += $p.WorkingSet64; $n++
  }
  '{0} trimmed {1} game(s): working set {2:N2} -> {3:N2} GB' -f (Get-Date -Format T), $n, ($before / 1GB), ($after / 1GB)
  if ($Loop) { Start-Sleep -Seconds $EverySec }
} while ($Loop)

$global:LASTEXITCODE = 0
