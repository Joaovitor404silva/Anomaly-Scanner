param(
  [int]$ParentPid = 0,
  [string]$RunDir = '',
  [double]$Secs = 45,
  [double]$Poll = 1,
  [double]$ArmAfter = 240,
  [string]$RootA = '',
  [string]$RootB = '',
  [int]$PidA = 0,
  [int]$PidB = 0,
  [string]$LogA = '',
  [string]$LogB = '',
  [switch]$Once
)
$ErrorActionPreference = 'Stop'
$WorldRx = if ($env:S2H_WD_WORLD) { $env:S2H_WD_WORLD } else { 'ldsave: pawn #\d+ \+8 s|n7: host: pawn no mundo|csave: movimento devolvido ao pawn carregado' }
Add-Type -Namespace S2W -Name Dbg -MemberDefinition @'
[DllImport("dbghelp.dll", SetLastError = true)]
public static extern bool MiniDumpWriteDump(IntPtr hProcess, uint processId, IntPtr hFile, uint dumpType, IntPtr exceptionParam, IntPtr userStreamParam, IntPtr callbackParam);
'@
$sides = @(
  [pscustomobject]@{ K = 'A'; Id = $PidA; Root = $RootA; Log = $LogA },
  [pscustomobject]@{ K = 'B'; Id = $PidB; Root = $RootB; Log = $LogB }
)
function Side-Id($s) {
  if ($s.Id) { return $s.Id }
  if (-not $s.Root) { return 0 }
  $p = Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$($s.Root)\Stalker2\*" } | Select-Object -First 1
  if ($p) { [int]$p.ProcessId } else { 0 }
}
function Side-Log($s) {
  if ($s.Log) { return $s.Log }
  "$($s.Root)\Stalker2\Binaries\Win64\ue4ss\UE4SS.log"
}
function Side-State($s) {
  $id = Side-Id $s
  if (-not $id) { return $null }
  $p = Get-Process -Id $id -ErrorAction SilentlyContinue
  if (-not $p) { return $null }
  $lp = Side-Log $s
  $lw = if (Test-Path -LiteralPath $lp) { (Get-Item -LiteralPath $lp).LastWriteTime } else { $null }
  $age = try { ((Get-Date) - $p.StartTime).TotalSeconds } catch { 0 }
  [pscustomobject]@{ Id = $id; Resp = [bool]$p.Responding; LastWrite = $lw; Path = $lp; Age = $age }
}
function Write-Dump($id, $path) {
  $p = Get-Process -Id $id
  $fs = [IO.File]::Create($path)
  try {
    $ok = [S2W.Dbg]::MiniDumpWriteDump($p.Handle, [uint32]$id, $fs.SafeFileHandle.DangerousGetHandle(), 0x1064, [IntPtr]::Zero, [IntPtr]::Zero, [IntPtr]::Zero)
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
  } finally { $fs.Close() }
  if (-not $ok) { throw "MiniDumpWriteDump failed (win32 $err)" }
  (Get-Item -LiteralPath $path).Length
}
if ($Once) {
  foreach ($s in $sides) {
    $x = Side-State $s
    if (-not $x) { Write-Host "$($s.K): not running"; continue }
    $age = if ($x.LastWrite) { [math]::Round(((Get-Date) - $x.LastWrite).TotalSeconds, 1) } else { 'no log' }
    Write-Host "$($s.K): pid $($x.Id) Responding=$($x.Resp) log_age=$age s ($($x.Path))"
  }
  exit 0
}
$now = Get-Date
$st = @{}
foreach ($s in $sides) { $st[$s.K] = @{ Resp = $now; Log = $now; Armed = $false } }
$wlog = if ($RunDir) { Join-Path $RunDir 'watchdog.log' } else { $null }
function WLog($m) { if ($wlog) { try { Add-Content -LiteralPath $wlog -Value ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) -Encoding ascii } catch { } } }
WLog "start pid $PID parent $ParentPid secs $Secs poll $Poll"
$errN = 0
while ($true) {
  if ($ParentPid -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { WLog 'parent gone, exit'; exit 0 }
  Start-Sleep -Seconds $Poll
  $now = Get-Date
  foreach ($s in $sides) {
    try {
      $x = Side-State $s
      $t = $st[$s.K]
      if (-not $x) { $t.Resp = $now; $t.Log = $now; $t.Armed = $false; continue }
      if ($x.Resp) { $t.Resp = $now }
      if ($x.LastWrite -and $x.LastWrite -gt $t.Log) { $t.Log = $x.LastWrite }
      if (-not $t.Armed -and $x.Age -ge $ArmAfter) { $t.Armed = $true; $t.Log = $now; WLog "$($s.K) armed by process age $([int]$x.Age) s" }
      if (-not $t.Armed -and (Select-String -LiteralPath $x.Path -Pattern $WorldRx -Quiet -ErrorAction SilentlyContinue)) { $t.Armed = $true; $t.Log = $now }
      if (-not $t.Armed) { continue }
      if ((($now - $t.Resp).TotalSeconds -ge $Secs) -and (($now - $t.Log).TotalSeconds -ge $Secs)) {
        $since = if ($t.Resp -gt $t.Log) { $t.Resp } else { $t.Log }
        $dump = Join-Path $RunDir ("hang_{0}_{1}.dmp" -f $s.K, (Get-Date -Format 'HHmmss'))
        Set-Content -LiteralPath (Join-Path $RunDir 'FROZEN.txt') -Value "FROZEN $($s.K) since $($since.ToString('HH:mm:ss')), dump $dump (writing)" -Encoding ascii
        $dn = try { "dump $dump ($(Write-Dump $x.Id $dump) bytes)" } catch { "dump failed: $($_.Exception.Message)" }
        $msg = "FROZEN $($s.K) since $($since.ToString('HH:mm:ss')), $dn"
        Set-Content -LiteralPath (Join-Path $RunDir 'FROZEN.txt') -Value $msg -Encoding ascii
        WLog $msg
        exit 0
      }
    } catch {
      $errN++
      if ($errN -le 50) { WLog "error on $($s.K): $($_.Exception.Message)" }
    }
  }
}

$global:LASTEXITCODE = 0
