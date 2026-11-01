param([ValidateSet(1, 2)][int]$Pair = 1, [switch]$NoHost, [switch]$NoClient)
$P = @{
  1 = @{ H = 'C:\S2DevRootHost'; C = 'C:\S2DevRoot'; HB = 'C:\s2coop_inst\A'; CB = 'C:\s2coop_inst\B'; HS = ''; CS = 'client'; HP = 27061; CP = 27060; HR = 7778; CR = 7779 }
  2 = @{ H = 'C:\S2DevRootHost2'; C = 'C:\S2DevRoot2'; HB = 'C:\nola_inst\C'; CB = 'C:\nola_inst\D'; HS = 'host2'; CS = 'client2'; HP = 27063; CP = 27062; HR = 7788; CR = 7789 }
}[$Pair]
$EXE = 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'
$RELAY = 'D:\modding\offline\b3\relay_v2.py'; $UV = "$(if ($env:UV_EXE) { $env:UV_EXE } else { (Get-Command uv -ErrorAction SilentlyContinue).Source })"
function Log($m) { Write-Host ("[" + (Get-Date -Format 'HH:mm:ss') + "] pair$Pair " + $m) }
function RootProc($root) { Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$root\Stalker2\*" } }
if (-not (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) { Log 'WARNING: Steam is not running (saves go to the NULL platform folder)' }
$os = Get-CimInstance Win32_OperatingSystem; Log ("free RAM {0:N1} GB" -f ($os.FreePhysicalMemory / 1MB))

function WaitWorld($bridge, $procId, $tag) {
  $sf = Join-Path $bridge 'state.json'
  for ($i = 0; $i -lt 60; $i++) {
    if ((Test-Path -LiteralPath $sf) -and ((Get-Content -LiteralPath $sf -Raw) -match '"in_world":true')) {
      foreach ($k in 1..2) { Start-Sleep -Seconds 3; & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\key_pid.ps1" -ProcId $procId -Keys 20 | Out-Null }
      Log "$tag in world"; return $true }
    if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { Log "$tag DIED"; return $false }
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\key_pid.ps1" -ProcId $procId -Keys 46 | Out-Null
    Start-Sleep -Seconds 5
  }
  Log "$tag world timeout"; return $false
}
function Start1($root, $role, $bridge, $suffix, $port, $noplug) {
  if (RootProc $root) { Log "$role already running from $root"; return (RootProc $root).ProcessId }
  foreach ($f in 'state.json', 'out.json', 'in.json', 'lua_out.txt', 'lua_cmd.txt') { Remove-Item -LiteralPath (Join-Path $bridge $f) -Force -ErrorAction SilentlyContinue }
  $env:S2_ROLE = $role; $env:S2_BRIDGE = $bridge + '\'; $env:CRAWLER_PORT = "$port"; $env:S2DEV_PORT = "$port"; $env:CRAWLER_NOPLUG = $noplug; $env:ANOMALY_BENCH = "$(if ($env:S2H_HOME) { $env:S2H_HOME } else { 'C:\modding\s2harness' })\bench"
  $env:CRAWLER_AUTOEXEC = "$PSScriptRoot\lowspec.txt"
  $a = @('-windowed', '-ResX=960', '-ResY=540', '-NoWarmupFailMessage'); if ($suffix) { $a += "-saveddirsuffix=$suffix" }
  Log "launch $role from $root (Crawler $port)"
  Start-Process -FilePath "$root\$EXE" -ArgumentList $a | Out-Null
  for ($i = 0; $i -lt 30 -and -not (RootProc $root); $i++) { Start-Sleep -Seconds 2 }
  $id = (RootProc $root).ProcessId; Log "$role pid=$id"
  WaitWorld $bridge $id $role | Out-Null
  $env:CRAWLER_PORT = "$port"; $env:S2DEV_PORT = "$port"; $r = & node "$(if ($env:GAME_CRAWLER) { $env:GAME_CRAWLER } else { 'D:\modding\Game-Crawler' })\crawler.js" con 'r.setres 1366x768w' 2>&1 | Select-Object -Last 1; Log "$role window: $r"
  return $id
}
if (-not $NoClient) { $cpid = Start1 $P.C 'client' $P.CB $P.CS $P.CP '0' }
if (-not $NoHost) { $hpid = Start1 $P.H 'host' $P.HB $P.HS $P.HP '1' }

Get-CimInstance Win32_Process -Filter "CommandLine like '%relay_v2.py%'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match "--listen\s+($($P.HR)|$($P.CR))\b" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
foreach ($r in @(@{l = $P.HR; p = "127.0.0.1:$($P.CR)"; d = $P.HB }, @{l = $P.CR; p = "127.0.0.1:$($P.HR)"; d = $P.CB })) {
  $alg = @('run', '--no-project', 'python', '-I', $RELAY, '--listen', "$($r.l)", '--peer', $r.p, '--dir', $r.d)
  Start-Process -FilePath $UV -ArgumentList $alg -WindowStyle Hidden -RedirectStandardOutput (Join-Path $r.d 'relay.log') -RedirectStandardError (Join-Path $r.d 'relay.err.log') | Out-Null
}
Start-Sleep -Seconds 5
$os = Get-CimInstance Win32_OperatingSystem
Log ("done: client pid=$cpid host pid=$hpid  free RAM {0:N1} GB" -f ($os.FreePhysicalMemory / 1MB))

$global:LASTEXITCODE = 0
