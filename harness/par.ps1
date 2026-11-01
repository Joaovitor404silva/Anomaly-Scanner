param(
  [Parameter(Mandatory = $true)][string]$Lines,
  [int]$For = 0,
  [int]$Poll = 500,
  [int]$Fps = 0,
  [string]$Out = '',
  [int]$TimeoutMs = 20000,
  [string]$SideList = 'A,B',
  [int]$Pair = 2
)
$ErrorActionPreference = 'Stop'
$H = 'C:\modding\s2harness'
$PORT = @{ A = 27063; B = 27062; E = 27064 }
if ($Pair -eq 3) { $PORT = @{ A = 27065; B = 27066 }; if ($SideList -match 'E') { throw 'par: side E is pair 2 only' } }
$sides = @($SideList -split ',')
$log = New-Object Collections.Generic.List[string]
function Say($m) { $l = ('[' + (Get-Date -Format 'HH:mm:ss.fff') + '] ' + $m); $log.Add($l); Write-Host $l }

function Send-Req($k, [string[]]$cmds) {
  $io = "$H\bench\io\$($PORT[$k])"
  if (-not (Test-Path -LiteralPath $io)) { throw "par: nbot io folder $io missing (nbot not loaded on $k)" }
  $id = [guid]::NewGuid().ToString('N').Substring(0, 12)
  $tmp = "$io\req_$id.tmp"
  [IO.File]::WriteAllText($tmp, (($cmds -join "`n") + "`n"), (New-Object Text.ASCIIEncoding))
  Move-Item -LiteralPath $tmp "$io\req_$id.txt" -Force
  @{ k = $k; id = $id; io = $io; t0 = [Diagnostics.Stopwatch]::GetTimestamp() }
}
function Wait-Res($rq) {
  $res = "$($rq.io)\res_$($rq.id).txt"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
    if (Test-Path -LiteralPath $res) { Start-Sleep -Milliseconds 20; $t = [IO.File]::ReadAllText($res); Remove-Item -LiteralPath $res -Force -ErrorAction SilentlyContinue; return $t.Trim() }
    Start-Sleep -Milliseconds 15
  }
  throw "par: nbot on $($rq.k) gave no answer in $TimeoutMs ms"
}
function Par-Send([hashtable]$perSide) {
  $rqs = @{}
  foreach ($k in $sides) { if ($perSide[$k].Count) { $rqs[$k] = Send-Req $k $perSide[$k] } }
  $out = @{}
  foreach ($k in $rqs.Keys) { $out[$k] = Wait-Res $rqs[$k] }
  $out
}
function Pos-Of($state) { if ($state -match '"pos":\[([-\d.]+),([-\d.]+),([-\d.]+)\]') { ,@([double]$Matches[1], [double]$Matches[2], [double]$Matches[3]) } else { $null } }
function Tick-Of($ping) { if ($ping -match 'tick=(\d+)') { [double]$Matches[1] } else { -1 } }

$per = @{}; foreach ($k in $sides) { $per[$k] = New-Object Collections.Generic.List[string] }
foreach ($raw in ($Lines -split ';')) {
  $c = $raw.Trim(); if (-not $c) { continue }
  if ($c -match '^@([ABE])\s+(.+)$') { $per[$Matches[1]].Add($Matches[2]) } else { foreach ($k in $sides) { $per[$k].Add($c) } }
}

$fpsRes = $null
if ($Fps -gt 0) {
  $p0 = Par-Send @{ A = @('ping'); B = @('ping'); E = @('ping') }
  $w0 = [Diagnostics.Stopwatch]::StartNew()
}

Say ("par send: " + (($sides | ForEach-Object { "$_=[" + ($per[$_] -join ' | ') + "]" }) -join '  '))
$res = Par-Send $per
foreach ($k in $sides) { Say "reply $k : $(($res[$k] -replace "`r?`n", ' | '))" }

$pos = @{}; foreach ($k in $sides) { $pos[$k] = New-Object Collections.Generic.List[object] }
if ($For -gt 0) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.ElapsedMilliseconds -lt $For) {
    $st = Par-Send @{ A = @('state'); B = @('state'); E = @('state') }
    foreach ($k in $sides) {
      $p = Pos-Of $st[$k]
      if ($p) { $pos[$k].Add(@($sw.ElapsedMilliseconds, $p[0], $p[1], $p[2])); Say ("pos {0} t={1,5}ms x={2,9:N1} y={3,9:N1} z={4,8:N1}" -f $k, $sw.ElapsedMilliseconds, $p[0], $p[1], $p[2]) }
    }
    $left = $Poll - 0; if ($left -gt 0) { Start-Sleep -Milliseconds $left }
  }
  foreach ($k in $sides) {
    if ($pos[$k].Count -ge 2) {
      $a = $pos[$k][0]; $b = $pos[$k][$pos[$k].Count - 1]
      $d = [math]::Sqrt([math]::Pow($b[1] - $a[1], 2) + [math]::Pow($b[2] - $a[2], 2) + [math]::Pow($b[3] - $a[3], 2))
      Say ("moved {0}: {1:N1} uu in {2} ms ({3} samples)" -f $k, $d, ($b[0] - $a[0]), $pos[$k].Count)
    }
  }
}

if ($Fps -gt 0) {
  $rest = $Fps - $w0.ElapsedMilliseconds; if ($rest -gt 0) { Start-Sleep -Milliseconds $rest }
  $p1 = Par-Send @{ A = @('ping'); B = @('ping'); E = @('ping') }
  $el = $w0.Elapsed.TotalSeconds
  foreach ($k in $sides) {
    $t0 = Tick-Of $p0[$k]; $t1 = Tick-Of $p1[$k]
    Say ("fps {0}: {1:N1} ticks/s (tick {2} -> {3} in {4:N2} s)" -f $k, (($t1 - $t0) / $el), $t0, $t1, $el)
  }
}
if ($Out) { [IO.File]::WriteAllLines($Out, $log) }

$global:LASTEXITCODE = 0
