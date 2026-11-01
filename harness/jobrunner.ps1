param([ValidateSet('start', 'stop', 'status', 'loop')][string]$Cmd = 'status', [int]$MaxJobMin = 45, [int]$Tick = 2, [int]$Retry = 8)
$ErrorActionPreference = 'Stop'
$env:S2H_JOBRUNNER = '1'
$H = if ($env:S2H_HOME) { $env:S2H_HOME } else { 'C:\modding\s2harness' }
$HS = if ($env:S2H_HARNESS) { $env:S2H_HARNESS } else { Join-Path $PSScriptRoot 'harness.ps1' }
$J = "$H\jobs"
foreach ($d in 'queue', 'running', 'done', 'meta') { New-Item -ItemType Directory -Force "$J\$d" | Out-Null }
$PIDF = "$J\jobrunner.pid"; $LOGF = "$J\jobrunner.log"; $STOPF = "$J\jobrunner.stop"
$PAIRS = @(2, 3); if ($env:S2H_JR_PAIRS) { $PAIRS = @($env:S2H_JR_PAIRS -split ',' | ForEach-Object { [int]$_ }) }
$MXNAME = 'Global\s2jobrunner_' + ($H -replace '[^A-Za-z0-9]', '_')

function Log($m) { $l = (Get-Date).ToString('s') + ' ' + $m; try { Add-Content -LiteralPath $LOGF -Value $l -Encoding ascii } catch { }; Write-Host $l }
function Get-RunnerPid {
  $rp = 0
  if ((Test-Path -LiteralPath $PIDF) -and [int]::TryParse(([IO.File]::ReadAllText($PIDF)).Trim(), [ref]$rp)) { $pr = Get-Process -Id $rp -ErrorAction SilentlyContinue; if ($pr -and $pr.ProcessName -match 'powershell|pwsh') { return $rp } }
  0
}
function Read-Text($p) { if (-not (Test-Path -LiteralPath $p)) { return '' }; try { $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite, Delete'); try { (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() } } catch { '' } }
function Hs([string[]]$a) {
  $ErrorActionPreference = 'Continue'
  $o = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HS @a 2>&1 | ForEach-Object { "$_" })
  [pscustomobject]@{ Rc = $LASTEXITCODE; Out = ($o -join ' | ') }
}
function Read-Meta([string]$id) {
  $f = "$J\meta\$id.json"
  if (Test-Path -LiteralPath $f) { try { return ([IO.File]::ReadAllText($f) | ConvertFrom-Json) } catch { } }
  [pscustomobject]@{ id = $id; name = ($id -replace '^\d{8}_\d{6}_\d{3}_', ''); pair = 'any'; overbudget = '' }
}
function Get-Tree([int]$root) {
  $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Select-Object ProcessId, ParentProcessId, Name)
  $out = New-Object System.Collections.Generic.List[object]; $todo = @($root)
  while ($todo.Count) { $n = @(); foreach ($t in $todo) { foreach ($c in $all) { if ($c.ParentProcessId -eq $t -and $c.ProcessId -ne $t) { $out.Add($c); $n += $c.ProcessId } } }; $todo = $n }
  $out
}
$script:slots = @{}
function Start-PlanJob([string]$id, $m, [int]$p) {
  $rp = "$J\running\$id.plan"
  try { Move-Item -LiteralPath "$J\queue\$id.plan" -Destination $rp -ErrorAction Stop } catch { Log "job ${id}: claim failed ($($_.Exception.Message))"; return $false }
  [IO.File]::WriteAllText("$J\running\$id.pair", "$p")
  $dd = "$J\done\$id"; New-Item -ItemType Directory -Force $dd | Out-Null; Copy-Item -LiteralPath $rp -Destination "$dd\job.plan" -Force
  $al = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$HS`"", 'plan', "`"$rp`"", '-Pair', "$p")
  if ("$($m.overbudget)") { $al += @('-OverBudget', "`"$($m.overbudget)`"") }
  $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList $al -WorkingDirectory $J -RedirectStandardOutput "$dd\stdout.txt" -RedirectStandardError "$dd\stderr.txt" -WindowStyle Hidden -PassThru
  $null = $pr.Handle
  [IO.File]::WriteAllText("$J\running\$id.pid", "$($pr.Id)")
  $script:slots[$p] = [pscustomobject]@{ Id = $id; Name = "$($m.name)"; P = $pr; T0 = Get-Date; Killed = $false }
  Log "job $id ($($m.name)): started on pair $p, plan pid $($pr.Id)"
  $true
}
function Finish-PlanJob([int]$p) {
  $s = $script:slots[$p]; $id = $s.Id; $dd = "$J\done\$id"
  New-Item -ItemType Directory -Force $dd | Out-Null
  $rc = $null
  try { if ($s.P -and $s.P.GetType().Name -eq 'Process') { [void]$s.P.WaitForExit(3000); $rc = $s.P.ExitCode } } catch { $rc = $null }
  $so = Read-Text "$dd\stdout.txt"; $se = Read-Text "$dd\stderr.txt"
  $pl = ''; foreach ($mm in [regex]::Matches($so, 'plan log: (\S[^\r\n]*)')) { $pl = $mm.Groups[1].Value.Trim() }
  $ptxt = ''
  if ($pl -and (Test-Path -LiteralPath $pl)) { Copy-Item -LiteralPath $pl -Destination "$dd\plan.log" -Force; $ptxt = Read-Text $pl }
  if ($null -eq $rc -or "$rc" -eq '') { $rc = if ($ptxt -match 'plan DONE') { 0 } else { 1 } }
  if ($s.Killed) { $rc = 124 }
  $rc = [int]$rc
  $res = New-Object System.Collections.Generic.List[string]
  $res.Add("pair: $p"); $res.Add("lock: job:$($s.Name)"); $res.Add("started: $($s.T0.ToString('s'))"); $res.Add("finished: $((Get-Date).ToString('s'))")
  if ($pl) { $res.Add("plan dir: $(Split-Path $pl)") }
  if ($ptxt -match 'plan FAILED at step (.+?) after') { $res.Add("failed: step $($Matches[1])") }
  elseif ($s.Killed) { $res.Add("failed: killed after $MaxJobMin min (job time cap)") }
  elseif ($rc -ne 0) { $last = @(($so + "`n" + $se) -split "`r?`n" | Where-Object { $_.Trim() } | Where-Object { $_ -notmatch '^\s*(\+|No linha|At line|CategoryInfo|FullyQualifiedErrorId)' }) | Select-Object -Last 1; $res.Add("failed: $last") }
  $crash = ''
  $texts = @($so, $se); if ($pl) { foreach ($sf in @(Get-ChildItem -LiteralPath (Split-Path $pl) -Filter 'step_*.txt' -ErrorAction SilentlyContinue)) { $texts += (Read-Text $sf.FullName) } }
  foreach ($tx in $texts) { $cm = [regex]::Match($tx, '(DEAD: [^\r\n]*|[^\r\n]*DIED while loading[^\r\n]*)'); if ($cm.Success) { $crash = $cm.Groups[1].Value.Trim(); break } }
  if ($crash) { $res.Add("crash: $crash") }
  $out = ''
  foreach ($ln in @([IO.File]::ReadAllLines("$dd\job.plan"))) { if ($ln -match '^\s*\??\s*out\s+"?([^"]+?)"?\s*$') { $out = $Matches[1] } }
  if (-not $out -and $pl) { $out = Split-Path $pl }
  [IO.File]::WriteAllText("$dd\out.txt", "$out")
  [IO.File]::WriteAllLines("$dd\result.txt", [string[]]$res.ToArray())
  $rcl = @("$rc"); if ($crash) { $rcl += "crash: $crash" }
  [IO.File]::WriteAllLines("$dd\rc.txt", [string[]]$rcl)
  $u = Hs @('unlock', "job:$($s.Name)", '-Pair', "$p")
  foreach ($x in 'plan', 'pair', 'pid') { Remove-Item -LiteralPath "$J\running\$id.$x" -Force -ErrorAction SilentlyContinue }
  $script:slots.Remove($p)
  Log "job ${id}: finished on pair $p rc $rc$(if ($crash) { " crash: $crash" }); unlock exit $($u.Rc); result $dd"
}
function Adopt-Running {
  foreach ($f in @(Get-ChildItem -LiteralPath "$J\running" -Filter *.pair -ErrorAction SilentlyContinue)) {
    $id = $f.BaseName; $p = [int]([IO.File]::ReadAllText($f.FullName)).Trim(); $pp = 0
    if (Test-Path -LiteralPath "$J\running\$id.pid") { [void][int]::TryParse(([IO.File]::ReadAllText("$J\running\$id.pid")).Trim(), [ref]$pp) }
    $pr = $null; if ($pp) { $pr = Get-Process -Id $pp -ErrorAction SilentlyContinue }
    $m = Read-Meta $id
    $script:slots[$p] = [pscustomobject]@{ Id = $id; Name = "$($m.name)"; P = $pr; T0 = $f.LastWriteTime; Killed = $false }
    Log "job ${id}: adopted on pair $p (plan pid $pp $(if ($pr) { 'alive' } else { 'gone' }))"
  }
}
function Invoke-Tick {
  foreach ($p in @($script:slots.Keys)) {
    $s = $script:slots[$p]
    if (-not $s.P -or $s.P.HasExited) { Finish-PlanJob $p; continue }
    if (((Get-Date) - $s.T0).TotalMinutes -gt $MaxJobMin) {
      Log "job $($s.Id): over $MaxJobMin min, stopping its plan and harness steps (game processes are left running)"
      foreach ($c in @(Get-Tree $s.P.Id)) { if ($c.Name -match '^(powershell|pwsh|node)\.exe$') { Stop-Process -Id $c.ProcessId -Force -ErrorAction SilentlyContinue } }
      Stop-Process -Id $s.P.Id -Force -ErrorAction SilentlyContinue
      $s.Killed = $true; Start-Sleep -Seconds 1; Finish-PlanJob $p
    }
  }
  $free = @($PAIRS | Where-Object { -not $script:slots.ContainsKey($_) })
  if (-not $free.Count) { return }
  $tried = @{}
  foreach ($q in @(Get-ChildItem -LiteralPath "$J\queue" -Filter *.plan -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $id = $q.BaseName; $m = Read-Meta $id; $pref = "$($m.pair)"
    $cand = @($free | Where-Object { -not $tried.ContainsKey($_) -and ($pref -eq 'any' -or $pref -eq "$_") })
    if (-not $cand.Count) { continue }
    foreach ($c in $cand) { $tried[$c] = $true }
    if ($script:lastTry.ContainsKey($id) -and ((Get-Date) - $script:lastTry[$id]).TotalSeconds -lt $Retry) { continue }
    $script:lastTry[$id] = Get-Date
    $won = 0
    foreach ($c in $cand) { $r = Hs @('lock', "job:$($m.name)", '-Pair', "$c", '-Wait', '0'); if ($r.Rc -eq 0) { $won = $c; break } }
    if (-not $won) { continue }
    foreach ($c in $cand) { if ($c -ne $won) { [void](Hs @('unlock', "job:$($m.name)", '-Pair', "$c")) } }
    if (Start-PlanJob $id $m $won) { $script:lastTry.Remove($id); $free = @($free | Where-Object { $_ -ne $won }); Start-Sleep -Milliseconds 1100 }
    else { [void](Hs @('unlock', "job:$($m.name)", '-Pair', "$won")) }
    if (-not $free.Count) { break }
  }
}

switch ($Cmd) {
  'start' {
    $rp = Get-RunnerPid
    if ($rp) { Write-Host "jobrunner already running pid $rp (log $LOGF)"; exit 0 }
    Remove-Item -LiteralPath $STOPF -Force -ErrorAction SilentlyContinue
    $pr = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", 'loop', '-MaxJobMin', "$MaxJobMin", '-Tick', "$Tick", '-Retry', "$Retry") -WorkingDirectory $J -WindowStyle Hidden -PassThru
    for ($i = 0; $i -lt 20 -and -not (Get-RunnerPid); $i++) { Start-Sleep -Milliseconds 250 }
    Write-Host "jobrunner started pid $($pr.Id) (pairs $($PAIRS -join ','), log $LOGF)"
  }
  'stop' {
    $rp = Get-RunnerPid
    if (-not $rp) { Write-Host 'jobrunner is not running'; exit 0 }
    [IO.File]::WriteAllText($STOPF, (Get-Date).ToString('o'))
    for ($i = 0; $i -lt 40 -and (Get-Process -Id $rp -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 250 }
    if (Get-Process -Id $rp -ErrorAction SilentlyContinue) { Stop-Process -Id $rp -Force -ErrorAction SilentlyContinue }
    Write-Host "jobrunner stopped (pid $rp); running plans keep running and are adopted by the next start"
  }
  'status' {
    $rp = Get-RunnerPid
    Write-Host "jobrunner: $(if ($rp) { "running pid $rp" } else { 'stopped' }) (pairs $($PAIRS -join ','))"
    foreach ($f in @(Get-ChildItem -LiteralPath "$J\running" -Filter *.pair -ErrorAction SilentlyContinue)) { Write-Host "  running pair$(([IO.File]::ReadAllText($f.FullName)).Trim()) $($f.BaseName) since $($f.LastWriteTime.ToString('HH:mm:ss'))" }
    foreach ($f in @(Get-ChildItem -LiteralPath "$J\queue" -Filter *.plan -ErrorAction SilentlyContinue | Sort-Object Name)) { Write-Host "  queued $($f.BaseName) (pair $((Read-Meta $f.BaseName).pair))" }
    if (Test-Path -LiteralPath $LOGF) { Get-Content -LiteralPath $LOGF -Tail 5 | ForEach-Object { Write-Host "  $_" } }
  }
  'loop' {
    $mx = New-Object Threading.Mutex($false, $MXNAME); $own = $false
    try { $own = $mx.WaitOne(0) } catch [Threading.AbandonedMutexException] { $own = $true }
    if (-not $own) { Write-Host 'another jobrunner loop owns this jobs folder'; exit 1 }
    try {
      [IO.File]::WriteAllText($PIDF, "$PID")
      Set-Location -LiteralPath $J
      $script:lastTry = @{}
      Log "jobrunner loop start pid $PID, pairs $($PAIRS -join ','), harness $HS"
      Adopt-Running
      while (-not (Test-Path -LiteralPath $STOPF)) {
        try { Invoke-Tick } catch { Log "tick error: $($_.Exception.Message)"; Start-Sleep -Seconds 5 }
        Start-Sleep -Seconds $Tick
      }
      Remove-Item -LiteralPath $STOPF -Force -ErrorAction SilentlyContinue
      Log "jobrunner loop stop pid $PID ($($script:slots.Count) plan(s) left running)"
    } finally {
      try { if (([IO.File]::ReadAllText($PIDF)).Trim() -eq "$PID") { Remove-Item -LiteralPath $PIDF -Force } } catch { }
      $mx.ReleaseMutex(); $mx.Dispose()
    }
  }
}

$global:LASTEXITCODE = 0
