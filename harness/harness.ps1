param(
  [Parameter(Position = 0)][string]$Cmd = 'help',
  [Parameter(Position = 1)][string]$Spec,
  [Parameter(Position = 2)][string]$Arg2,
  [string]$Yaw = '',
  [string]$Do = '',
  [switch]$Hip,
  [switch]$Ads,
  [string]$Dll,
  [string[]]$Pak,
  [string[]]$PakHost,
  [string[]]$PakClient,
  [string]$Flags,
  [string]$FlagsHost,
  [string]$FlagsClient,
  [string[]]$Set,
  [string]$Save = 'C:\modding\s2harness\testsave\master_20261018_host',
  [switch]$NoSave,
  [switch]$Calm,
  [switch]$Day,
  [switch]$Follow,
  [string]$StartOn = '',
  [string]$StartLog = 'A',
  [int]$StartTimeout = 8,
  [int]$Pre = 0,
  [switch]$Sync,
  [switch]$Pose,
  [string]$PoseRef = 'auto',
  [switch]$NoHost,
  [switch]$HostOnly,
  [ValidateSet('keep', 'master')][string]$ClientSave = 'keep',
  [int]$HostTimeout = 480,
  [int]$ClientTimeout = 480,
  [int]$JoinTimeout = 240,
  [string]$WorldRegex = 'ldsave: pawn #\d+ \+8 s|n7: host: pawn no mundo|csave: movimento devolvido ao pawn carregado',
  [string]$JoinRegex = 'NOLA PEER UP',
  [string]$Run,
  [switch]$DryRun,
  [string]$LogA,
  [string]$LogB,
  [string]$Report,
  [string]$Other,
  [switch]$Full,
  [switch]$StopOnFail,
  [switch]$KeepGoing,
  [switch]$KeepControls,
  [switch]$Kill,
  [switch]$AcceptBase,
  [switch]$NoWinTests,
  [int]$QuitTimeout = 40,
  [ValidateRange(1, 2)][int]$Clients = 1,
  [int]$MaxClients = 0,
  [double]$MinFreeGB = 10,
  [string]$On,
  [switch]$All,
  [string]$At,
  [string]$Key,
  [double]$Dist = 0,
  [string]$Fov,
  [ValidateSet('normal', 'lite', 'video')][string]$Profile = 'normal',
  [switch]$Reuse,
  [switch]$Cold,
  [switch]$Serial,
  [switch]$NoReload,
  [int]$ResetTimeout = 240,
  [int]$Wait = 0,
  [int]$MaxResets = 5,
  [double]$Plant = 0,
  [string]$OverBudget = '',
  [string]$Adhoc = '',
  [switch]$Check,
  [string]$Name = '',
  [ValidateSet('2', '3', 'any')][string]$Pair = '2',
  [double]$WatchSecs = 45
)
$ErrorActionPreference = 'Stop'
$HDEF = 'C:\modding\s2harness'; $H = if ($env:S2H_HOME) { $env:S2H_HOME } else { $HDEF }
$PairAny = $false
if ($Cmd.ToLower() -in 'lock', 'submit' -and -not $PSBoundParameters.ContainsKey('Pair')) { $Pair = 'any' }
if ("$Pair" -eq 'any') {
  if ($Cmd.ToLower() -notin 'lock', 'submit') { throw "HARNESS: -Pair any is only for 'lock <name>' and 'submit'; use -Pair 2 or -Pair 3 on other commands" }
  $PairAny = $true; $Pair = '2'
} elseif (-not $PSBoundParameters.ContainsKey('Pair')) {
  $anyf = "$H\pair3.lock.any"
  if ((Test-Path -LiteralPath $anyf) -and (Test-Path -LiteralPath "$H\pair3.lock")) {
    try {
      $anyWho = ([IO.File]::ReadAllText($anyf)).Trim()
      $l3 = @(([IO.File]::ReadAllText("$H\pair3.lock")).Trim() -split '\s+')[0]
      $c3 = ''; if (Test-Path -LiteralPath "$H\pair3.lock.cwd") { $c3 = ([IO.File]::ReadAllText("$H\pair3.lock.cwd")).Trim() }
      $byCwd = ($c3 -and $c3 -eq (Get-Location).Path)
      $byName = ($Cmd.ToLower() -in 'lock', 'unlock' -and $Spec -eq $anyWho)
      if ($anyWho -and $anyWho -eq $l3 -and ($byCwd -or $byName)) { $Pair = '3' }
    } catch { }
  }
}
$G = 'C:\Program Files (x86)\Steam\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
$S2DEV = "$(if ($env:GAME_CRAWLER) { $env:GAME_CRAWLER } else { 'D:\modding\Game-Crawler' })\crawler.js"
$KEYSEND = Join-Path $PSScriptRoot 'keysend.ps1'
$DLLBAK = "$H\runs\dllbak"
$BASEFILE = "$H\baseline_dll.txt"
$BOT = "$PSScriptRoot\s2bot.ps1"
$RECOVER = "$PSScriptRoot\crash_recover.ps1"
$FLAGSBAK = "$H\runs\flagsbak"
$GENFLAGS = "$PSScriptRoot\tools\gen_flags_p2.py"
$UV = "$(if ($env:UV_EXE) { $env:UV_EXE } else { (Get-Command uv -ErrorAction SilentlyContinue).Source })"
$AUTOEXEC = "$PSScriptRoot\lowspec.txt"
$PROFILES = @{
  normal = @{ Autoexec = "$PSScriptRoot\lowspec.txt"; Args = @('-windowed', '-ResX=960', '-ResY=540'); Res = '1366x768w' }
  lite = @{ Autoexec = "$H\lite.txt"; Args = @('-windowed', '-ResX=640', '-ResY=360', '-nosound'); Res = '640x360w' }
  video = @{ Autoexec = "$H\video.txt"; Args = @('-windowed', '-ResX=1280', '-ResY=720'); Res = '1280x720w' }
}
$PROF = $PROFILES[$Profile]
$AUTOEXEC = $PROF.Autoexec
. (Join-Path $PSScriptRoot 'gamewin.ps1')
$script:BlockDir = "$H\runs\blockers"
$EXE = 'Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe'
$SIDES = @{
  A = @{ Key = 'A'; Role = 'host'; Root = 'C:\S2DevRootHost2'; Bridge = 'C:\nola_inst\C'; Suffix = 'host2'; Port = 27063; NoPlug = '1'; Saved = 'Saved_host2' }
  B = @{ Key = 'B'; Role = 'client'; Root = 'C:\S2DevRoot2'; Bridge = 'C:\nola_inst\D'; Suffix = 'client2'; Port = 27062; NoPlug = '0'; Saved = 'Saved_client2' }
  E = @{ Key = 'E'; Role = 'client'; Root = 'C:\S2DevRoot3'; Bridge = 'C:\nola_inst\E'; Suffix = 'client3'; Port = 27064; NoPlug = '0'; Saved = 'Saved_client3' }
}
$SIDES.A.Tag = 'host'; $SIDES.B.Tag = 'client'; $SIDES.E.Tag = 'client3'
$FORBIDDEN = @('C:\S2DevRootHost\', 'C:\S2DevRoot\', 'C:\S2CoopClientRoot', "$G\Stalker2\", "$env:LOCALAPPDATA\Stalker2\Saved\", "$env:LOCALAPPDATA\Stalker2\Saved_client\", 'C:\s2coop_inst\A\', 'C:\s2coop_inst\B\', "$G\ModWork\s2coop\Mods\", "$G\ModWork\s2coop\ModsClient\")
$ALLOWED = @("$G\ModWork\nola\Mods_p2\", "$G\ModWork\nola\ModsClient_p2\", "$G\ModWork\nola\ModsClient_p3\", 'C:\S2DevRoot3\Stalker2\Content\Paks\~mods\', 'C:\S2DevRoot3\Stalker2\Binaries\Win64\ue4ss\UE4SS.log', 'C:\nola_inst\E\', "$env:LOCALAPPDATA\Stalker2\Saved_client3\STEAM\SaveGames", 'C:\S2DevRootHost2\Stalker2\Content\Paks\~mods\', 'C:\S2DevRoot2\Stalker2\Content\Paks\~mods\', 'C:\S2DevRootHost2\Stalker2\Binaries\Win64\ue4ss\UE4SS.log', 'C:\S2DevRoot2\Stalker2\Binaries\Win64\ue4ss\UE4SS.log', 'C:\nola_inst\C\', 'C:\nola_inst\D\', "$env:LOCALAPPDATA\Stalker2\Saved_host2\STEAM\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_client2\STEAM\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_host2\NULL\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_client2\NULL\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_client3\NULL\SaveGames", "$H\")
$LOCK = "$H\pair2.lock"; $QUEUE = "$H\pair2.queue"; $QMX = "$H\pair2.queue.mx"; $LOCKLOG = "$H\runs\lock.log"; $MAXHOLD = 20; $QSTALE = 10
$QMXNAME = 'Global\s2harness_pair2_queue'; $BUDGET = 'pair2.budget'; $CURRENT = "$H\runs\current.txt"; $RUNPFX = ''; $CRASHRX = 'S2DevRoot(Host2|2|3)\\'
if ($Pair -eq 3) {
  if ($Clients -ge 2) { throw 'HARNESS: -Clients 2 (client E) is pair 2 only' }
  $SIDES.A.Root = 'C:\S2DevRootHostP3'; $SIDES.A.Bridge = 'C:\nola_inst\P3A'; $SIDES.A.Suffix = 'host_p3'; $SIDES.A.Port = 27065; $SIDES.A.Saved = 'Saved_host_p3'
  $SIDES.B.Root = 'C:\S2DevRootP3'; $SIDES.B.Bridge = 'C:\nola_inst\P3B'; $SIDES.B.Suffix = 'client_p3'; $SIDES.B.Port = 27066; $SIDES.B.Saved = 'Saved_client_p3'
  $SIDES.E.Root = 'C:\S2DevRootP3_noE'; $SIDES.E.Bridge = 'C:\nola_inst\P3_noE'; $SIDES.E.Port = 0
  $FORBIDDEN += @('C:\S2DevRootHost2\', 'C:\S2DevRoot2\', 'C:\S2DevRoot3\', 'C:\nola_inst\C\', 'C:\nola_inst\D\', 'C:\nola_inst\E\', "$G\ModWork\nola\Mods_p2\", "$G\ModWork\nola\ModsClient_p2\", "$G\ModWork\nola\ModsClient_p3\", "$env:LOCALAPPDATA\Stalker2\Saved_host2\", "$env:LOCALAPPDATA\Stalker2\Saved_client2\", "$env:LOCALAPPDATA\Stalker2\Saved_client3\", "$H\pair2.")
  $ALLOWED = @("$G\ModWork\nola\Mods_pair3\", "$G\ModWork\nola\ModsClient_pair3\", 'C:\S2DevRootHostP3\Stalker2\Content\Paks\~mods\', 'C:\S2DevRootP3\Stalker2\Content\Paks\~mods\', 'C:\S2DevRootHostP3\Stalker2\Binaries\Win64\ue4ss\UE4SS.log', 'C:\S2DevRootP3\Stalker2\Binaries\Win64\ue4ss\UE4SS.log', 'C:\nola_inst\P3A\', 'C:\nola_inst\P3B\', "$env:LOCALAPPDATA\Stalker2\Saved_host_p3\STEAM\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_client_p3\STEAM\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_host_p3\NULL\SaveGames", "$env:LOCALAPPDATA\Stalker2\Saved_client_p3\NULL\SaveGames", "$H\")
  $LOCK = "$H\pair3.lock"; $QUEUE = "$H\pair3.queue"; $QMX = "$H\pair3.queue.mx"; $LOCKLOG = "$H\runs\lock_p3.log"
  $QMXNAME = 'Global\s2harness_pair3_queue'; $BUDGET = 'pair3.budget'; $CURRENT = "$H\runs\current_p3.txt"; $RUNPFX = 'p3_'; $CRASHRX = 'S2DevRoot(HostP3|P3)\\'
  $DLLBAK = "$H\runs\dllbak_p3"; $FLAGSBAK = "$H\runs\flagsbak_p3"; $BASEFILE = "$H\baseline_dll_p3.txt"; $GENFLAGS = "$PSScriptRoot\tools\gen_flags_p3.py"
}
$NETKEYS = @('cpp_net', 'net', 'netpeer', 'netlisten', 'netpeerport', 'netdx', 'netloss', 'netrecord', 'netfiles', 'netloop', 'maxclients', 'netlocal', 'joinmenu')
$TAPSECS = 3
$VK = @{ ENTER = '0D'; ESC = '1B'; SPACE = '20'; TAB = '09'; SHIFT = '10'; CTRL = '11'; ALT = '12'; UP = '26'; DOWN = '28'; LEFT = '25'; RIGHT = '27'; F1 = '70'; F2 = '71'; F3 = '72'; F4 = '73'; F5 = '74'; F6 = '75'; F7 = '76'; F8 = '77'; F9 = '78'; F10 = '79'; LMB = '01'; RMB = '02' }

$script:SayBuf = New-Object System.Collections.Generic.List[string]
function Say($m) { $l = '[' + (Get-Date -Format 'HH:mm:ss') + '] ' + $m; [void]$script:SayBuf.Add($l); Write-Host $l }
function Flush-UpLog {
  try {
    if (-not $script:SayBuf.Count) { return }
    $rd = Get-CurrentRun
    if ($rd -and (Test-Path -LiteralPath $rd)) { [IO.File]::AppendAllLines("$rd\up.log", [string[]]$script:SayBuf.ToArray()) }
    $script:SayBuf.Clear()
  } catch { }
}
$HOTRELOAD = 'D:\modding\cpp\wt\dev1\tools\hotreload.ps1'; $HOTARGS = @(); if ($Pair -eq 3) { $HOTRELOAD = "$H\hotreload.ps1"; $HOTARGS = @('-Pair', '3') }
function Test-HotDll([string]$p) {
  if (-not $p -or -not (Test-Path -LiteralPath $p)) { return $false }
  [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($p)).Contains('nola_hot_start')
}
function Run-Calm {
  $rd = Get-CurrentRun; if (-not $rd) { return }
  $p = Read-Spec 'calm'
  if ($p.Errors.Count) { $p.Errors | ForEach-Object { Write-Host $_ }; Fail 'spec calm has parse errors' }
  $r = Invoke-Spec $p $rd "$rd\report_calm_$(Get-Date -Format 'HHmmss').txt"
  Say "calm: $($r.Verdict) ($($r.Report))"
  $kb = @($r.Rows | Where-Object { $_.Kind -ne 'inv' -and $_.Result -in 'FAIL', 'ERR', 'DEAD', 'CRASH' })
  $ib = @($r.Rows | Where-Object { $_.Kind -eq 'inv' -and $_.Result -eq 'FAIL' })
  if ($ib.Count) { Say "calm: NOLA INV break(s) on $(($ib | ForEach-Object Side) -join ',') logged in the report; not a kill-safety failure, the up goes on" }
  if ($kb.Count) { Fail 'calm spec failed: players may be killable' }
}
function Fail($m) { throw "HARNESS: $m" }
function Full($p) { [IO.Path]::GetFullPath($p) }
function Assert-Writable($p) {
  $f = Full $p
  foreach ($x in $FORBIDDEN) { if ($f.StartsWith($x, [StringComparison]::OrdinalIgnoreCase)) { Fail "refusing to write $f (protected: $x)" } }
  foreach ($x in $ALLOWED) { if ($f.StartsWith($x, [StringComparison]::OrdinalIgnoreCase)) { return } }
  Fail "refusing to write $f (not inside the test pair folders)"
}
function LogPath($k) {
  if ($k -eq 'A' -and $script:LogOverride.A) { return $script:LogOverride.A }
  if ($k -eq 'B' -and $script:LogOverride.B) { return $script:LogOverride.B }
  "$($SIDES[$k].Root)\Stalker2\Binaries\Win64\ue4ss\UE4SS.log"
}
function Get-SideProc($k) {
  if ($script:ProcOverride -and $script:ProcOverride.ContainsKey($k)) { return [pscustomobject]@{ ProcessId = $script:ProcOverride[$k] } }
  $root = $SIDES[$k].Root
  Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$root\Stalker2\*" } | Select-Object -First 1
}
function Get-ModsDir($k) {
  $ini = "$($SIDES[$k].Root)\Stalker2\Binaries\Win64\ue4ss\UE4SS-settings.ini"
  $l = Get-Content -LiteralPath $ini | Where-Object { $_ -match '^ModsFolderPath\s*=' } | Select-Object -First 1
  if (-not $l) { Fail "no ModsFolderPath in $ini" }
  ($l -replace '^ModsFolderPath\s*=\s*', '').Trim()
}
function Assert-Safe {
  foreach ($k in $KEYS) {
    $s = $SIDES[$k]
    $c = Get-Item -LiteralPath "$($s.Root)\Stalker2\Content" -Force
    if ($c.LinkType) { Fail "$($s.Root)\Stalker2\Content is a $($c.LinkType): writing paks there would write pair 1. Build the separate layout first (C:\modding\s2harness\tools\setup_pair2.ps1)." }
    $m = Get-ModsDir $k
    if ($m -notmatch $(if ($Pair -eq 3) { '_pair3\\?$' } else { '_p[23]\\?$' })) { Fail "$($s.Root) loads mods from $m (not a _p2 folder): the DLL install would hit pair 1." }
  }
}
function Put-File($src, $dst) {
  if (-not (Test-Path -LiteralPath $src)) { Fail "missing file $src" }
  Assert-Writable $dst
  if ((Full $src) -ieq (Full $dst)) { Fail "source and destination are the same file ($dst): refusing to delete the source" }
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Force }
  Copy-Item -LiteralPath $src $dst
  $a = (Get-FileHash -LiteralPath $src -Algorithm MD5).Hash; $b = (Get-FileHash -LiteralPath $dst -Algorithm MD5).Hash
  if ($a -ne $b) { Fail "copy check failed $dst" }
  Say "installed $dst md5 $($a.Substring(0,8).ToLower())"
}
function Get-CurrentRun {
  if ($Run) { return $Run }
  $c = $CURRENT
  if (Test-Path -LiteralPath $c) { $r = (Get-Content -LiteralPath $c -Raw).Trim(); if ($r -and (Test-Path -LiteralPath $r)) { return $r } }
  $null
}
function New-RunDir {
  $d = "$H\runs\$RUNPFX" + (Get-Date -Format 'yyyyMMdd_HHmmss')
  New-Item -ItemType Directory -Force $d | Out-Null
  Set-Content -LiteralPath $CURRENT -Value $d -Encoding ascii
  $d
}
function Invoke-S2Dev($k, [string[]]$lines, [int]$TimeoutMs = 30000) {
  $ErrorActionPreference = 'Continue'
  New-Item -ItemType Directory -Force "$H\tmp" | Out-Null
  $f = "$H\tmp\s2dev_" + [guid]::NewGuid().ToString('N') + '.txt'
  [IO.File]::WriteAllLines($f, $lines)
  $old = $env:CRAWLER_PORT; $env:CRAWLER_PORT = "$($SIDES[$k].Port)"; $env:S2DEV_PORT = "$($SIDES[$k].Port)"; $oldT = $env:CRAWLER_TIMEOUT; $env:CRAWLER_TIMEOUT = "$TimeoutMs"
  try { $o = (& node $S2DEV -f $f 2>&1 | ForEach-Object { "$_" } | Out-String) } finally { $env:CRAWLER_PORT = $old; $env:S2DEV_PORT = $old; $env:CRAWLER_TIMEOUT = $oldT; Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
  ((($o -split "`r?`n") | Where-Object { $_ -notmatch '^> ' }) -join "`n").Trim()
}
function Resolve-Cls($k, $text) {
  $ms = [regex]::Matches($text, '@cls:([A-Za-z0-9_]+)')
  foreach ($m in $ms) {
    $n = $m.Groups[1].Value
    if (-not $script:ClsCache.ContainsKey("$k$n")) {
      $o = Invoke-S2Dev $k @("find class:$n 20")
      $hit = ($o -split "`n") | Where-Object { $_ -match '^0x[0-9a-fA-F]+\s' -and $_ -notmatch 'Default__' } | Select-Object -First 1
      if (-not $hit) { Fail "no live object of class $n on $k ($o)" }
      $script:ClsCache["$k$n"] = ($hit -split '\s+')[0]
    }
    $text = $text.Replace($m.Value, $script:ClsCache["$k$n"])
  }
  $text
}
function Var-Num($t) { $x = Expand-Vars "$t"; if ($x -match '^(-?[\d.]+)([+-][\d.]+)$') { return [double]$Matches[1] + [double]$Matches[2] }; [double]$x }
function Expand-Vars($text, [switch]$Escape) {
  $ms = @([regex]::Matches($text, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}'))
  for ($i = $ms.Count - 1; $i -ge 0; $i--) {
    $m = $ms[$i]; $n = $m.Groups[1].Value
    if (-not $script:Vars.ContainsKey($n)) { Fail "variable $n is not set (capture it with (?<$n>...) in an earlier expect)" }
    $v = if ($Escape) { [regex]::Escape($script:Vars[$n]) } else { $script:Vars[$n] }
    $text = $text.Substring(0, $m.Index) + $v + $text.Substring($m.Index + $m.Length)
  }
  $text
}
function Get-Loc($k) {
  $end = (Get-Date).AddSeconds(20)
  do {
    $o = Invoke-S2Dev $k @('call pawn K2_GetActorLocation')
    if ($o -match 'X=(-?[0-9.eE+-]+) Y=(-?[0-9.eE+-]+) Z=(-?[0-9.eE+-]+)') { return @([double]$Matches[1], [double]$Matches[2], [double]$Matches[3]) }
    if ($o -notmatch 'cannot resolve object pawn') { break }
    Start-Sleep -Seconds 1
  } while ((Get-Date) -lt $end)
  Fail "cannot read the pawn location on ${k} (retried 20 s): $o"
}
function Fmt3($v) { ($v | ForEach-Object { [string][Math]::Round($_, 1) }) -join ',' }
$TpGroundSecs = 6
$TpStreamSecs = 30
function Set-NoClip($k, [bool]$on) {
  $cm = Resolve-Cls $k '@cls:CustomConsoleManagerBuild'
  [void](Invoke-S2Dev $k @("call $cm XSetNoClipGSC $(if ($on) { 'true' } else { 'false' }) 600"))
}
function Wait-Grounded($k, [double]$z0) {
  $t = [Diagnostics.Stopwatch]::StartNew()
  while ($t.Elapsed.TotalSeconds -lt $TpGroundSecs) {
    Start-Sleep -Milliseconds 250
    $l = Get-Loc $k
    if ($l[2] -lt $z0 - 1500) { return $null }
    $m = Invoke-S2Dev $k @('get pawn CharacterMovement.MovementMode')
    if ($m -match 'Walking|NavWalking') {
      Start-Sleep -Milliseconds 250
      $l2 = Get-Loc $k
      if ([Math]::Abs($l2[2] - $l[2]) -lt 30) { return $l2 }
    }
  }
  $null
}
function Send-Input($k, [string]$mode, [hashtable]$a = @{}, [switch]$NoThrow) {
  $p = Get-SideProc $k
  if (-not $p) { if ($NoThrow) { return "FAIL $k is not running" }; Fail "$k is not running" }
  $argl = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $KEYSEND, '-ProcId', "$($p.ProcessId)", '-Mode', $mode)
  foreach ($n in @($a.GetEnumerator())) { $argl += "-$($n.Key)"; $argl += "$($n.Value)" }
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $imx = New-Object Threading.Mutex($false, $(if ($env:S2H_INPUT_MX) { $env:S2H_INPUT_MX } else { 'Global\s2harness_input' }))
  $held = $false
  try {
    try { $mt0 = Get-Date; while (-not $held -and ((Get-Date) - $mt0).TotalSeconds -lt 120) { Check-Frozen; $held = $imx.WaitOne(2000) } } catch [Threading.AbandonedMutexException] { $held = $true }
    $gp = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    $qa = @($argl | ForEach-Object { if ("$_" -match '\s') { '"' + $_ + '"' } else { "$_" } })
    for ($try = 1; $try -le 2; $try++) {
      if ($gp -and -not $gp.Responding) { $code = 124; $o = 'window not responding, input skipped'; break }
      $of = [IO.Path]::GetTempFileName(); $ef = [IO.Path]::GetTempFileName()
      try {
        if ($null -eq $script:KeyDownUtc) { $script:KeyDownUtc = [DateTime]::UtcNow }
        $pr = Start-Process -FilePath powershell.exe -ArgumentList $qa -NoNewWindow -PassThru -RedirectStandardOutput $of -RedirectStandardError $ef
        $null = $pr.Handle
        if ($pr.WaitForExit(25000)) { $code = $pr.ExitCode; $o = (([IO.File]::ReadAllText($of) + [IO.File]::ReadAllText($ef))).Trim() }
        else { try { Stop-Process -Id $pr.Id -Force } catch { }; $code = 124; $o = 'keysend timed out after 25 s (window hung?)' }
      } finally { Remove-Item -LiteralPath $of, $ef -Force -ErrorAction SilentlyContinue }
      if ($code -ne 4 -or $o -match 'during the hold|between the down') { break }
      Start-Sleep -Milliseconds 800
    }
  } finally { $ErrorActionPreference = $eap; if ($held) { $imx.ReleaseMutex() }; $imx.Dispose() }
  if ($code -ne 0) { if ($NoThrow) { return "FAIL $k ($code): $o" }; Fail "input to $k not delivered (keysend exit $code): $o" }
  "$k $o"
}
function Tap-Keys($k, [string[]]$hex) { Send-Input $k 'tap' @{ Keys = ($hex -join ' ') } }
function KeyHex($n) {
  $u = $n.ToUpper()
  if ($u -match '^0X([0-9A-F]{1,2})$') { return $Matches[1] }
  if ($VK.ContainsKey($u)) { return $VK[$u] }
  if ($u.Length -eq 1) { return ('{0:X2}' -f [int][char]$u) }
  Fail "unknown key $n"
}

function Get-Mark($k, $path = $null) {
  $p = if ($path) { $path } else { LogPath $k }
  if (-not (Test-Path -LiteralPath $p)) { return @{ Off = 0; Head = ''; Skip = $false } }
  $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite, Delete')
  try {
    $len = $fs.Length; $n = [int][Math]::Min(64, $len); $b = New-Object byte[] $n; [void]$fs.Read($b, 0, $n)
    $skip = $false
    if ($len -gt 0) { $fs.Seek($len - 1, 'Begin') | Out-Null; $skip = ($fs.ReadByte() -ne 10) }
    @{ Off = $len; Head = [Text.Encoding]::UTF8.GetString($b); Skip = $skip }
  } finally { $fs.Dispose() }
}
function Read-NewLines($k, $st, $path = $null) {
  $p = if ($path) { $path } else { LogPath $k }
  if (-not (Test-Path -LiteralPath $p)) { return , @() }
  $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite, Delete')
  try {
    $len = $fs.Length; $n = [int][Math]::Min(64, $len); $hb = New-Object byte[] $n; [void]$fs.Read($hb, 0, $n)
    $head = [Text.Encoding]::UTF8.GetString($hb)
    $same = ($st.Head -ne '') -and ($head.StartsWith($st.Head) -or $st.Head.StartsWith($head))
    if (-not $same -or $len -lt $st.Pos) { $st.Pos = 0; $st.Skip = $false; $st.Head = $head }
    elseif ($head.Length -ge $st.Head.Length) { $st.Head = $head }
    if ($len -le $st.Pos) { return , @() }
    $cnt = [int]($len - $st.Pos); $buf = New-Object byte[] $cnt
    $fs.Seek($st.Pos, 'Begin') | Out-Null
    $got = 0; while ($got -lt $cnt) { $r = $fs.Read($buf, $got, $cnt - $got); if ($r -le 0) { break }; $got += $r }
    if ($got -le 0) { return , @() }
    $last = [Array]::LastIndexOf($buf, [byte]10, $got - 1)
    if ($last -lt 0) { return , @() }
    $text = [Text.Encoding]::UTF8.GetString($buf, 0, $last + 1)
    $st.Pos += $last + 1
    $lines = @($text -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
    if ($st.Skip -and $lines.Count -gt 0) { $lines = @($lines | Select-Object -Skip 1); $st.Skip = $false }
    , $lines
  } finally { $fs.Dispose() }
}
function Set-Marks { foreach ($k in $KEYS) { $script:Marks[$k] = Get-Mark $k } }
function Watch-Blocker($k, $procId) {
  if (-not $procId) { $p = Get-SideProc $k; if (-not $p) { return }; $procId = $p.ProcessId }
  $r = Resolve-GameBlocker ([int]$procId) $script:BlockDir
  if (-not $r) { return }
  if ($r.Action -eq 'answered') { Say "$k blocker answered: $($r.Text)"; return }
  $script:Alive[$k] = $false
  throw "CRASH: $k ($($SIDES[$k].Role)) pid $procId blocked by a window, killed; text+png in $($script:BlockDir): $($r.Text)"
}
function Confirm-Popup($k) {
  $f = Invoke-S2Dev $k @('find class:W_PopupView_C 5') 4000
  $ph = @(($f -split ' \| ') | Where-Object { $_ -match '^0x[0-9a-fA-F]+\s' -and $_ -notmatch 'Default__' })
  if (-not $ph.Count) { return $null }
  $po = ($ph[0] -split '\s+')[0]
  $aw = Invoke-S2Dev $k @("get $po ActivePopupWidget") 4000
  if ($aw -notmatch '= (0x[0-9a-fA-F]+) ') { return $null }
  $w = $Matches[1]
  $cv = Invoke-S2Dev $k @("get $w ConfirmHint.Visibility") 4000
  if ($cv -notmatch '= 0 ') { return $null }
  $ttl = Invoke-S2Dev $k @("get $w Title.Text") 4000
  $r = Invoke-S2Dev $k @("call $po Confirm") 4000
  Say "$k stock popup confirmed ($ttl): $r"
  "$ttl"
}
function Test-Watchdog($dir) {
  $f = Join-Path $dir 'watchdog.pid'
  if (-not (Test-Path -LiteralPath $f)) { return $false }
  try { $id = [int](([IO.File]::ReadAllText($f)).Trim()) } catch { return $false }
  [bool](Get-Process -Id $id -ErrorAction SilentlyContinue)
}
function Check-Frozen {
  $d = $env:S2H_WATCH_RUN
  if (-not $d) { return }
  $f = Join-Path $d 'FROZEN.txt'
  if (Test-Path -LiteralPath $f) { [Console]::Error.WriteLine((Get-Content -LiteralPath $f -Raw).Trim()); exit 3 }
  if (-not $DryRun -and -not $Check -and (-not $script:WdLast -or ((Get-Date) - $script:WdLast).TotalSeconds -ge 20)) {
    $script:WdLast = Get-Date
    if (-not (Test-Watchdog $d)) { try { Start-PairWatchdog $d } catch { } }
  }
}
function Start-PairWatchdog($dir, [switch]$Force) {
  if ($DryRun -or $Check -or -not $dir) { return }
  $cur = $env:S2H_WATCH_RUN; $keep = $false
  if (-not $Force -and $cur) {
    if (Test-Watchdog $cur) { return }
    if ($env:S2H_PLAN -and (Test-Path -LiteralPath $cur)) { $dir = $cur; $keep = $true }
  }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  if (-not $keep) { Remove-Item -LiteralPath (Join-Path $dir 'FROZEN.txt') -Force -ErrorAction SilentlyContinue }
  $env:S2H_WATCH_RUN = $dir
  $env:S2H_WD_WORLD = $WorldRegex
  $par = if ($env:S2H_PLAN) { $env:S2H_PLAN } else { "$PID" }
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\watchdog.ps1", '-ParentPid', $par, '-RunDir', $dir, '-Secs', "$WatchSecs", '-RootA', $SIDES['A'].Root, '-RootB', $SIDES['B'].Root, '-LogA', (LogPath 'A'), '-LogB', (LogPath 'B'))
  $wp = Start-Process -FilePath powershell.exe -ArgumentList $a -WindowStyle Hidden -PassThru
  if ($wp) { [IO.File]::WriteAllText((Join-Path $dir 'watchdog.pid'), "$($wp.Id)") }
}
function Cmd-Watchdog {
  & "$PSScriptRoot\watchdog.ps1" -Once -RootA $SIDES['A'].Root -RootB $SIDES['B'].Root -LogA (LogPath 'A') -LogB (LogPath 'B')
  exit $LASTEXITCODE
}
function Check-Alive {
  Check-Frozen
  if ($DryRun) { return }
  foreach ($k in $KEYS) {
    if ($script:Alive[$k]) { Watch-Blocker $k $null }
    if ($script:Alive[$k] -and -not (Get-SideProc $k)) {
      $script:Alive[$k] = $false
      $ErrorActionPreference = 'Continue'; $r = & powershell -NoProfile -ExecutionPolicy Bypass -File $RECOVER -Pair $Pair -Check 2>&1 | ForEach-Object { "$_" } | Out-String
      throw "DEAD: $k ($($SIDES[$k].Role)) is gone. crash_recover -Check: $($r.Trim())"
    }
  }
}
function Scan($k, $rx, $secs, [switch]$Not) {
  $m = $script:Marks[$k]
  $st = @{ Pos = $m.Off; Head = $m.Head; Skip = $m.Skip }
  $re = New-Object regex ($rx)
  $t0 = Get-Date; $hits = New-Object System.Collections.ArrayList; $lastAlive = $t0
  while ($true) {
    foreach ($l in (Read-NewLines $k $st)) {
      $mm = $re.Match($l)
      if ($mm.Success) {
        foreach ($gn in $re.GetGroupNames()) { if ($gn -notmatch '^\d+$' -and $mm.Groups[$gn].Success) { $script:Vars[$gn] = $mm.Groups[$gn].Value } }
        [void]$hits.Add($l)
        if (-not $Not) { return @{ Ok = $true; Secs = ((Get-Date) - $t0).TotalSeconds; Lines = @($l) } }
        if ($hits.Count -ge 5) { return @{ Ok = $false; Secs = ((Get-Date) - $t0).TotalSeconds; Lines = @($hits) } }
      }
    }
    if ($Not -and $hits.Count -gt 0) { return @{ Ok = $false; Secs = ((Get-Date) - $t0).TotalSeconds; Lines = @($hits) } }
    $el = ((Get-Date) - $t0).TotalSeconds
    if ($el -ge $secs) { break }
    if (((Get-Date) - $lastAlive).TotalSeconds -ge 2) { Check-Alive; $lastAlive = Get-Date }
    Start-Sleep -Milliseconds 200
  }
  @{ Ok = [bool]$Not; Secs = ((Get-Date) - $t0).TotalSeconds; Lines = @() }
}

function Split-Rx($s) {
  $s = $s.Trim()
  if ($s.Length -ge 2 -and (($s.StartsWith('"') -and $s.EndsWith('"')) -or ($s.StartsWith('/') -and $s.EndsWith('/')))) { $s = $s.Substring(1, $s.Length - 2) }
  $s
}
function Test-Rx($s) {
  $probe = [regex]::Replace($s, '\$\{[A-Za-z_][A-Za-z0-9_]*\}', 'x')
  try { [void](New-Object regex ($probe)); $null } catch { $_.Exception.InnerException.Message + '' + $_.Exception.Message }
}
function Parse-Spec([string[]]$lines, $file) {
  $steps = New-Object System.Collections.ArrayList; $errs = New-Object System.Collections.ArrayList; $name = [IO.Path]::GetFileNameWithoutExtension($file)
  $num = '^-?\d+(\.\d+)?$'
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $raw = $lines[$i]; $t = $raw.Trim(); $ln = $i + 1
    if (-not $t) { continue }
    $kw = ($t -split '\s+', 2)[0].ToLower(); $rest = if ($t -match '^\S+\s+(.*)$') { $Matches[1].Trim() } else { '' }
    $st = @{ Line = $ln; Kind = $kw; Side = ''; Text = $t; Args = @(); Rx = ''; Secs = 0; Assert = '' }
    $e = $null
    $sideRest = { param($r) if ($r -match '^([ABE])(\s+(.*))?$') { @($Matches[1], ("" + $Matches[3]).Trim()) } else { $null } }
    switch ($kw) {
      'spec' { $name = $rest; continue }
      'needs' { if (-not $rest) { $e = 'needs: text missing' } }
      'note' { }
      'manual' { if ($rest -notmatch '^(\S+)\s+(.+)$') { $e = 'manual <id> <text>' } else { $st.Args = @($Matches[1], $Matches[2]) } }
      'mark' { if ($rest -and $rest -ne 'start') { $e = 'mark [start]' } else { $st.Args = @($rest) } }
      'wait' { if ($rest -notmatch $num) { $e = 'wait <seconds>' } else { $st.Secs = [double]$rest } }
      'expect' {
        if ($t -notmatch '^expect\s+([ABE])\s+(.+?)\s+within\s+(\d+(?:\.\d+)?)$') { $e = 'expect <A|B|E> <regex> within <s>' }
        else { $st.Side = $Matches[1]; $st.Rx = Split-Rx $Matches[2]; $st.Secs = [double]$Matches[3]; $x = Test-Rx $st.Rx; if ($x) { $e = "bad regex: $x" } }
      }
      'expect_not' {
        if ($t -notmatch '^expect_not\s+([ABE])\s+(.+?)\s+during\s+(\d+(?:\.\d+)?)$') { $e = 'expect_not <A|B|E> <regex> during <s>' }
        else { $st.Side = $Matches[1]; $st.Rx = Split-Rx $Matches[2]; $st.Secs = [double]$Matches[3]; $x = Test-Rx $st.Rx; if ($x) { $e = "bad regex: $x" } }
      }
      { $_ -in 'con', 's2dev', 'dev' } {
        $sr = & $sideRest $rest
        if (-not $sr -or -not $sr[1]) { $e = "$kw <A|B|E> <command> [=> <regex>]" }
        else {
          $st.Side = $sr[0]; $body = $sr[1]
          if ($body -match '^(.*?)\s+=>\s+(.+)$') { $body = $Matches[1]; $st.Assert = Split-Rx $Matches[2]; $x = Test-Rx $st.Assert; if ($x) { $e = "bad regex: $x" } }
          $st.Args = @($body)
        }
      }
      { $_ -in 'cfg', 'setflag' } { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch '^(\S+)\s+(\S+)$') { $e = "$kw <A|B|E> <key> <value>" } else { $st.Side = $sr[0]; $st.Args = @($Matches[1], $Matches[2]) } }
      'aim' { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch '^(-?[\d.]+)\s+(-?[\d.]+)$') { $e = 'aim <A|B|E> <pitch> <yaw>' } else { $st.Side = $sr[0]; $st.Args = @([double]$Matches[1], [double]$Matches[2]) } }
      'lookat' { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch '^(-?[\d.]+|\$\{\w+\}(?:[+-][\d.]+)?)\s+(-?[\d.]+|\$\{\w+\}(?:[+-][\d.]+)?)\s+(-?[\d.]+|\$\{\w+\}(?:[+-][\d.]+)?)$') { $e = 'lookat <A|B|E> <x> <y> <z>  (numbers or ${var})' } else { $st.Side = $sr[0]; $st.Args = @($Matches[1], $Matches[2], $Matches[3]) } }
      'tp' {
        $sr = & $sideRest $rest
        if ($sr -and $sr[1] -match '^(-?[\d.]+|\$\{\w+\}(?:[+-][\d.]+)?)\s+(-?[\d.]+|\$\{\w+\}(?:[+-][\d.]+)?)\s+(-?[\d.]+|\$\{\w+\}(?:[+-][\d.]+)?)$') { $st.Side = $sr[0]; $st.Args = @('xyz', $Matches[1], $Matches[2], $Matches[3]) }
        elseif ($sr -and $sr[1] -match '^near\s+([ABE])\s+(\d+)$') { $st.Side = $sr[0]; $st.Args = @('near', $Matches[1], [double]$Matches[2]) }
        else { $e = 'tp <A|B|E> <x> <y> <z>  |  tp <A|B|E> near <A|B|E> <cm>' }
      }
      'spawn' { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch '^(\S+)\s+(\d+)\s+near\s+([ABE])\s+(\d+(\.\d+)?)$') { $e = 'spawn <A|B|E> <SID> <count> near <A|B|E> <m>' } else { $st.Side = $sr[0]; $st.Args = @($Matches[1], [int]$Matches[2], $Matches[3], [double]$Matches[4]) } }
      'give' { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch '^(\S+)\s+(\d+)$') { $e = 'give <A|B|E> <ItemSID> <count>' } else { $st.Side = $sr[0]; $st.Args = @($Matches[1], [int]$Matches[2]) } }
      'hp' { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch $num) { $e = 'hp <A|B|E> <value>' } else { $st.Side = $sr[0]; $st.Args = @([double]$sr[1]) } }
      'key' {
        $sr = & $sideRest $rest
        if (-not $sr -or $sr[1] -notmatch '^(\S+)(\s+(\d+))?$') { $e = 'key <A|B|E> <KEY> [ms]' }
        else { $st.Side = $sr[0]; $ms = if ($Matches[3]) { [int]$Matches[3] } else { 100 }; try { $st.Args = @((KeyHex $Matches[1]), $ms) } catch { $e = "$_" } }
      }
      'tap' {
        $sr = & $sideRest $rest
        if (-not $sr -or -not $sr[1]) { $e = 'tap <A|B|E> <KEY> [KEY ...]' }
        else { $st.Side = $sr[0]; try { $st.Args = @($sr[1] -split '\s+' | ForEach-Object { ($_ -split '\+' | ForEach-Object { KeyHex $_ }) -join '+' }) } catch { $e = "$_" } }
      }
      'shot' { $sr = & $sideRest $rest; if (-not $sr -or $sr[1] -notmatch '^[A-Za-z0-9_.-]+$') { $e = 'shot <A|B|E> <name>' } else { $st.Side = $sr[0]; $st.Args = @($sr[1]) } }
      'mouse' {
        $sr = & $sideRest $rest
        if (-not $sr -or $sr[1] -notmatch '^(-?\d+)(\s+(-?\d+))?$') { $e = 'mouse <A|B|E> <dx> [dy]' }
        else { $st.Side = $sr[0]; $dy = if ($Matches[3]) { [int]$Matches[3] } else { 0 }; $st.Args = @([int]$Matches[1], $dy) }
      }
      { $_ -in 'quit', 'kill', 'launch', 'focus' } { $sr = & $sideRest $rest; if (-not $sr -or $sr[1]) { $e = "$kw <A|B|E>" } else { $st.Side = $sr[0] } }
      'census' { if ($rest) { $e = 'census (no arguments)' } }
      default { $e = "unknown step '$kw'" }
    }
    if ($kw -eq 'spec') { continue }
    if ($e) { [void]$errs.Add("${file}:${ln}: $e  ($t)") } else { [void]$steps.Add($st) }
  }
  @{ Name = $name; Steps = $steps; Errors = $errs }
}
function Read-Spec($path) {
  if (-not (Test-Path -LiteralPath $path)) { $alt = "$H\specs\$path"; if (Test-Path -LiteralPath $alt) { $path = $alt } elseif (Test-Path -LiteralPath "$alt.txt") { $path = "$alt.txt" } else { Fail "spec not found: $path" } }
  $p = Parse-Spec ([IO.File]::ReadAllLines($path)) $path
  $p.Path = $path
  $p
}
function Count-Spec($p) {
  $auto = @($p.Steps | Where-Object { $_.Kind -in 'expect', 'expect_not', 'census' -or $_.Assert }).Count
  $man = @($p.Steps | Where-Object { $_.Kind -eq 'manual' }).Count
  @{ Auto = $auto; Manual = $man }
}

function EngLog($k) { "$env:LOCALAPPDATA\Stalker2\$($SIDES[$k].Saved)\Logs\Stalker2.log" }
function Reset-Controls($k) {
  if ($KeepControls) { return }
  $sd = "$env:LOCALAPPDATA\Stalker2\$($SIDES[$k].Saved)"
  foreach ($p in @("$sd\CustomizeControls.cfg") + @(Get-ChildItem -LiteralPath $sd -Directory -ErrorAction SilentlyContinue | ForEach-Object { Join-Path $_.FullName 'CustomizeControls.cfg' })) {
    if (Test-Path -LiteralPath $p) { if ($SIDES[$k].Saved -notmatch '^Saved_(host2|client2|client3|host_p3|client_p3)$') { Fail "refusing to reset controls in $sd (not a test pair profile)" }; Remove-Item -LiteralPath $p -Force; Say "controls of $k reset to the game defaults: removed $p" }
  }
}
function Launch-Side($k, $timeout, $runDir) {
  $s = $SIDES[$k]
  if (Get-SideProc $k) { Fail "$k ($($s.Role)) already runs from $($s.Root): run 'harness.ps1 down' first" }
  foreach ($f in 'state.json', 'out.json', 'in.json', 'lua_out.txt', 'lua_cmd.txt', 's2cmd.txt') { $p = Join-Path $s.Bridge $f; if (Test-Path -LiteralPath $p) { Assert-Writable $p; Remove-Item -LiteralPath $p -Force } }
  $log = LogPath $k
  if (Test-Path -LiteralPath $log) { Assert-Writable $log; Move-Item -LiteralPath $log ("$runDir\" + $s.Tag + '_prev_' + (Get-Date -Format 'HHmmss') + '.log') -Force }
  $em = Get-Mark $k (EngLog $k)
  Reset-Controls $k
  $env:S2_ROLE = $s.Role; $env:S2_BRIDGE = $s.Bridge + '\'; $env:CRAWLER_PORT = "$($s.Port)"; $env:S2DEV_PORT = "$($s.Port)"; $env:CRAWLER_NOPLUG = $s.NoPlug; $env:ANOMALY_BENCH = "$H\bench"; $env:CRAWLER_AUTOEXEC = $AUTOEXEC
  $a = @($PROF.Args) + @('-NoWarmupFailMessage', '-unattended', "-saveddirsuffix=$($s.Suffix)")
  $script:BlockDir = $runDir
  Say "launch $k ($($s.Role)) from $($s.Root) Crawler $($s.Port) profile $Profile args $($a -join ' ')"
  $t0 = Get-Date
  Start-Process -FilePath "$($s.Root)\$EXE" -ArgumentList $a | Out-Null
  $p = $null; for ($i = 0; $i -lt 120 -and -not $p; $i++) { Start-Sleep -Milliseconds 500; $p = Get-SideProc $k }
  if (-not $p) { Fail "$k ($($s.Role)) process did not start from $($s.Root) in 60 s" }
  Say "$k pid=$($p.ProcessId); waiting for the world line /$WorldRegex/ (timeout $timeout s)"
  @{ K = $k; Pid = $p.ProcessId; T0 = $t0; Timeout = $timeout; St = @{ Pos = 0; Head = ''; Skip = $false }; Eng = @{ Pos = $em.Off; Head = $em.Head; Skip = $em.Skip }; Menu = $null; World = $null; Hit = $null; Gate = $null; Held = $false; LastKey = $t0; LastPop = $t0; LastBlk = $t0; Pops = 0; Post = 0; Done = $false }
}
function Wait-Worlds($ctxs) {
  $re = New-Object regex ($WorldRegex); $pre = New-Object regex ('Loading prototypes took ([0-9.]+) seconds')
  $by = @{}; foreach ($c in $ctxs) { $by[$c.K] = $c }
  while (@($ctxs | Where-Object { -not $_.Done }).Count) {
    Check-Frozen
    foreach ($c in $ctxs) {
      if ($c.Done) { continue }
      $k = $c.K; $now = Get-Date
      if (-not $c.World) {
        foreach ($l in (Read-NewLines $k $c.St)) { if ($re.IsMatch($l)) { $c.Hit = $l; $c.World = Get-Date; break } }
        if ($c.World) { Say "$k in world after $([int]($c.World - $c.T0).TotalSeconds) s ($($c.Pops) stock popup(s) confirmed): $($c.Hit)"; continue }
        if (-not $c.Menu) { foreach ($l in (Read-NewLines $k $c.Eng (EngLog $k))) { $m = $pre.Match($l); if ($m.Success -and [double]$m.Groups[1].Value -ge 1) { $c.Menu = Get-Date; Say "$k main menu reached after $([int]($c.Menu - $c.T0).TotalSeconds) s (prototypes $($m.Groups[1].Value) s)"; break } } }
        if (($now - $c.LastBlk).TotalSeconds -ge 2) { Watch-Blocker $k $c.Pid; $c.LastBlk = Get-Date }
        $pp = if ($c.Menu) { 8 } else { 4 }
        if (($now - $c.LastPop).TotalSeconds -ge $pp) { if (Confirm-Popup $k) { $c.Pops++ }; $c.LastPop = Get-Date }
        if (-not (Get-Process -Id $c.Pid -ErrorAction SilentlyContinue)) {
          $ErrorActionPreference = 'Continue'; $r = & powershell -NoProfile -ExecutionPolicy Bypass -File $RECOVER -Pair $Pair -Check 2>&1 | ForEach-Object { "$_" } | Out-String
          Fail "$k ($($SIDES[$k].Role)) DIED while loading ($([int]((Get-Date) - $c.T0).TotalSeconds) s). crash_recover -Check: $($r.Trim())"
        }
        if (((Get-Date) - $c.T0).TotalSeconds -gt $c.Timeout) { Fail "TIMEOUT: $k ($($SIDES[$k].Role)) world line /$WorldRegex/ not in $(LogPath $k) after $($c.Timeout) s (game left running: run 'harness.ps1 down')" }
        $open = (-not $c.Menu) -or (-not $c.Gate) -or ($by.ContainsKey($c.Gate) -and $by[$c.Gate].World)
        if (-not $open -and -not $c.Held) { $c.Held = $true; Say "$k waits in the main menu until $($c.Gate) is in world (no Continue key yet)" }
        if ($open -and (($now - $c.LastKey).TotalSeconds -ge $TAPSECS)) { [void](Send-Input $k 'tap' @{ Keys = '46' } -NoThrow); $c.LastKey = Get-Date }
      } else {
        $due = $c.World.AddSeconds(3 * ($c.Post + 1))
        if ($c.Post -lt 2 -and $now -ge $due) { [void](Send-Input $k 'tap' @{ Keys = '20' } -NoThrow); $c.Post++ }
        if ($c.Post -ge 2) {
          Watch-Blocker $k $c.Pid; if (Confirm-Popup $k) { $c.Pops++ }
          $w = Invoke-S2Dev $k @("con r.setres $($PROF.Res)"); Say "$k window: $w"
          $c.Done = $true
        }
      }
    }
    Start-Sleep -Milliseconds 400
  }
}
function Start-Side($k, $timeout, $runDir) {
  $c = Launch-Side $k $timeout $runDir
  Wait-Worlds @($c)
  $c.Pid
}
function Wait-Line($k, $rx, $timeout, $what, $st = $null) {
  if (-not $st) { $st = @{ Pos = 0; Head = ''; Skip = $false } }; $re = New-Object regex ($rx); $t0 = Get-Date
  while ($true) {
    Check-Frozen
    foreach ($l in (Read-NewLines $k $st)) { if ($re.IsMatch($l)) { Say "$what on ${k}: $l"; return $l } }
    Watch-Blocker $k $null
    if (-not (Get-SideProc $k)) { Fail "$k died while waiting for $what" }
    if (((Get-Date) - $t0).TotalSeconds -gt $timeout) { Fail "TIMEOUT: $what /$rx/ not seen on $k ($(LogPath $k)) in $timeout s (games left running: run 'harness.ps1 down')" }
    Start-Sleep -Milliseconds 500
  }
}
function Stop-Side($k, [switch]$Force) {
  $p = Get-SideProc $k
  if (-not $p) { return 'not running' }
  $procId = $p.ProcessId
  if (-not $Force) {
    $o = Invoke-S2Dev $k @('con quit') 8000
    for ($i = 0; $i -lt 30 -and (Get-Process -Id $procId -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
    if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { return "closed by 'con quit' ($o)" }
    $gp = Get-Process -Id $procId -ErrorAction SilentlyContinue
    if ($gp) { [void]$gp.CloseMainWindow() }
    for ($i = 0; $i -lt ($QuitTimeout * 2) -and (Get-Process -Id $procId -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
    if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { return 'closed by WM_CLOSE' }
  }
  Stop-Process -Id $procId -Force
  for ($i = 0; $i -lt 20 -and (Get-Process -Id $procId -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
  if ($Force) { 'killed (forced)' } else { "killed after $QuitTimeout s" }
}
function Set-FlagLine($k, $key, $val) {
  $f = Join-Path $SIDES[$k].Bridge 'flags.txt'; Assert-Writable $f
  $lines = if (Test-Path -LiteralPath $f) { @([IO.File]::ReadAllLines($f)) } else { @() }
  $done = $false
  $lines = @($lines | ForEach-Object { if ($_ -match ('^' + [regex]::Escape($key) + '=')) { $done = $true; "$key=$val" } else { $_ } })
  if (-not $done) { $lines += "$key=$val" }
  [IO.File]::WriteAllText($f, (($lines -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding))
}
function Invoke-Dev($k, $line) {
  $b = $SIDES[$k].Bridge; $in = Join-Path $b 's2cmd.txt'; $out = Join-Path $b 's2cmd_out.txt'
  Assert-Writable $in
  for ($i = 0; $i -lt 25 -and (Test-Path -LiteralPath $in); $i++) { Start-Sleep -Milliseconds 200 }
  $before = if (Test-Path -LiteralPath $out) { (Get-Item -LiteralPath $out).Length } else { 0 }
  [IO.File]::WriteAllText($in, $line + "`n", (New-Object Text.ASCIIEncoding))
  for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Milliseconds 200
    if (-not (Test-Path -LiteralPath $in) -and (Test-Path -LiteralPath $out) -and (Get-Item -LiteralPath $out).Length -gt $before) { break }
  }
  if (Test-Path -LiteralPath $in) { Remove-Item -LiteralPath $in -Force; return 'NOT CONSUMED (needs a non-release DLL and devcmd=1)' }
  Start-Sleep -Milliseconds 200
  $fs = [IO.File]::Open($out, 'Open', 'Read', 'ReadWrite, Delete')
  try { $fs.Seek($before, 'Begin') | Out-Null; $sr = New-Object IO.StreamReader($fs); $sr.ReadToEnd().Trim() } finally { $fs.Dispose() }
}

function Do-Step($st, $runDir) {
  $k = $st.Side
  switch ($st.Kind) {
    'con' { $c = Expand-Vars $st.Args[0]; if ($DryRun) { return 'DRY' }; return (Invoke-S2Dev $k @("con $c")) }
    's2dev' { $c = Expand-Vars $st.Args[0]; if ($DryRun) { return 'DRY' }; $c = Resolve-Cls $k $c; return (Invoke-S2Dev $k @($c)) }
    'dev' { $c = Expand-Vars $st.Args[0]; if ($DryRun) { return 'DRY' }; return (Invoke-Dev $k $c) }
    'cfg' { if ($DryRun) { return 'DRY' }; return (Invoke-Dev $k "cfg $($st.Args[0]) $(Expand-Vars $st.Args[1])") }
    'setflag' { if ($DryRun) { return 'DRY' }; Set-FlagLine $k $st.Args[0] (Expand-Vars $st.Args[1]); return "flags.txt $($st.Args[0])=$($st.Args[1])" }
    'aim' { if ($DryRun) { return 'DRY' }; return (Invoke-S2Dev $k @("call pc SetControlRotation $($st.Args[0]),$($st.Args[1]),0")) }
    'lookat' {
      if ($DryRun) { return 'DRY' }
      $t = @($st.Args | ForEach-Object { Var-Num $_ })
      $l = Get-Loc $k; $dx = $t[0] - $l[0]; $dy = $t[1] - $l[1]; $dz = $t[2] - ($l[2] + 60)
      $yaw = [Math]::Atan2($dy, $dx) * 180 / [Math]::PI; $pitch = [Math]::Atan2($dz, [Math]::Sqrt($dx * $dx + $dy * $dy)) * 180 / [Math]::PI
      $o = Invoke-S2Dev $k @("call pc SetControlRotation $([Math]::Round($pitch,2)),$([Math]::Round($yaw,2)),0")
      return "pitch=$([Math]::Round($pitch,2)) yaw=$([Math]::Round($yaw,2)) from $(Fmt3 $l): $o"
    }
    'tp' {
      if ($DryRun) { return 'DRY' }
      $from = Get-Loc $k
      if ($st.Args[0] -eq 'xyz') { $v = @($st.Args[1..3] | ForEach-Object { Var-Num $_ }) } else { $o = Get-Loc $st.Args[1]; $v = @(($o[0] + $st.Args[2]), $o[1], ($o[2] + 100)) }
      Set-NoClip $k $true
      $r = Invoke-S2Dev $k @("call pawn K2_SetActorLocation $(Fmt3 $v) false true")
      Start-Sleep -Seconds 3
      $g = $null; $tt = [Diagnostics.Stopwatch]::StartNew()
      while (-not $g -and $tt.Elapsed.TotalSeconds -lt $TpStreamSecs) {
        Set-NoClip $k $false
        $g = Wait-Grounded $k $v[2]
        if (-not $g) {
          Set-NoClip $k $true
          [void](Invoke-S2Dev $k @("call pawn K2_SetActorLocation $(Fmt3 $v) false true"))
          Start-Sleep -Seconds 2
        }
      }
      if ($g) { return "$r; grounded at $(Fmt3 $g) after $([int]$tt.Elapsed.TotalSeconds) s" }
      [void](Invoke-S2Dev $k @("call pawn K2_SetActorLocation $(Fmt3 @($from[0], $from[1], ($from[2] + 50))) false true"))
      Set-NoClip $k $false
      $b = Wait-Grounded $k ($from[2] + 50)
      throw "tp not grounded at $(Fmt3 $v) within $TpGroundSecs s; stepped back to $(Fmt3 $from) (grounded=$([bool]$b))"
    }
    'spawn' {
      if ($DryRun) { return 'DRY' }
      $o = Get-Loc $st.Args[2]; $rk = Resolve-Cls $k '@cls:CustomConsoleManagerRK'; $out = @()
      for ($i = 0; $i -lt $st.Args[1]; $i++) {
        $a = 2 * [Math]::PI * $i / [Math]::Max(1, $st.Args[1]); $r = $st.Args[3] * 100
        $x = $o[0] + $r * [Math]::Cos($a); $y = $o[1] + $r * [Math]::Sin($a); $yaw = ($a * 180 / [Math]::PI) + 180
        $out += Invoke-S2Dev $k @("call $rk XSpawnObjBySID $($st.Args[0]) 1 false $([Math]::Round($x,1)) $([Math]::Round($y,1)) $([Math]::Round($o[2] + 50,1)) 0 $([Math]::Round($yaw,1)) 0")
      }
      return ($out -join ' | ')
    }
    'give' { if ($DryRun) { return 'DRY' }; $rk = Resolve-Cls $k '@cls:CustomConsoleManagerRK'; return (Invoke-S2Dev $k @("call $rk XCreateItemInInventoryByID $($st.Args[0]) 0 $($st.Args[1]) 1")) }
    'hp' { if ($DryRun) { return 'DRY' }; return (Invoke-S2Dev $k @("call pawn ForceSetHP $($st.Args[0])")) }
    'key' { if ($DryRun) { return 'DRY' }; $o = Send-Input $k 'hold' @{ Vk = $st.Args[0]; Ms = $st.Args[1] }; return "held 0x$($st.Args[0]) $($st.Args[1]) ms: $o" }
    'tap' { if ($DryRun) { return 'DRY' }; $o = Tap-Keys $k $st.Args; return "tapped $($st.Args -join ' '): $o" }
    'mouse' { if ($DryRun) { return 'DRY' }; return (Send-Input $k 'mouse' @{ Dx = $st.Args[0]; Dy = $st.Args[1] }) }
    'focus' { if ($DryRun) { return 'DRY' }; return (Send-Input $k 'focus') }
    'shot' {
      if ($DryRun) { return 'DRY' }
      $old = $env:S2BOT_ROOT; $env:S2BOT_ROOT = $SIDES[$k].Root
      $ErrorActionPreference = 'Continue'; try { $o = & powershell -NoProfile -ExecutionPolicy Bypass -File $BOT shot "$runDir\$($st.Args[0]).png" 2>&1 | ForEach-Object { "$_" } | Out-String } finally { $env:S2BOT_ROOT = $old }
      return $o.Trim()
    }
    'quit' { if ($DryRun) { return 'DRY' }; $script:Alive[$k] = $false; return (Stop-Side $k) }
    'kill' { if ($DryRun) { return 'DRY' }; $script:Alive[$k] = $false; return (Stop-Side $k -Force) }
    'launch' {
      if ($DryRun) { return 'DRY' }
      $t = if ($k -eq 'A') { $HostTimeout } else { $ClientTimeout }
      $procId = Start-Side $k $t $runDir; $script:Alive[$k] = $true; $script:Marks[$k] = @{ Off = 0; Head = ''; Skip = $false }
      return "pid=$procId in world"
    }
  }
}
function Short($s, $n) { $s = ("" + $s) -replace "\s*`r?`n\s*", ' | '; if ($s.Length -gt $n) { $s.Substring(0, $n - 3) + '...' } else { $s } }
function Invoke-Census($outDir, $srcDir) {
  $wd = "$G\ModWork\tools\worlddiff\worlddiff.py"
  New-Item -ItemType Directory -Force $outDir | Out-Null
  $files = @(); $live = @(); $logs = @()
  foreach ($k in @('A', 'B', 'E')) {
    $dst = Join-Path $outDir "census_$($SIDES[$k].Tag).json"
    if ($srcDir) {
      $src = Join-Path $srcDir "census_$($SIDES[$k].Tag).json"
      if (-not (Test-Path -LiteralPath $src)) { continue }
      if ((Full $src) -ne (Full $dst)) { Copy-Item -LiteralPath $src $dst -Force }
      $files += $dst; continue
    }
    if (-not (Get-SideProc $k)) { continue }
    $src = Join-Path $SIDES[$k].Bridge 'census.json'
    if (Test-Path -LiteralPath $src) { Assert-Writable $src; Remove-Item -LiteralPath $src -Force }
    $o = Invoke-Dev $k 'census'
    Say "$k census: $(Short $o 160)"
    if ($o -notmatch '(?m)^census ok' -or -not (Test-Path -LiteralPath $src)) { Fail "$k census failed: $o" }
    Copy-Item -LiteralPath $src $dst -Force
    $files += $dst; $live += $k
    if (Test-Path -LiteralPath (LogPath $k)) { $logs += (LogPath $k) }
  }
  if ($files.Count -lt 2 -or (Split-Path $files[0] -Leaf) -ne 'census_host.json') { Fail "census needs the host and at least one client (got: $(($files | ForEach-Object { Split-Path $_ -Leaf }) -join ', '))" }
  $ErrorActionPreference = 'Continue'
  $txt = (& $UV run --no-project python -I $wd run @files --out $outDir 2>&1 | ForEach-Object { "$_" })
  $rc = $LASTEXITCODE
  $lrc = 0
  if ($logs.Count -ge 2) {
    $ltxt = (& $UV run --no-project python -I $wd logs @logs 2>&1 | ForEach-Object { "$_" })
    $lrc = $LASTEXITCODE
    [IO.File]::WriteAllLines((Join-Path $outDir 'worlddiff_logs.txt'), [string[]]$ltxt)
    $txt += $ltxt
  }
  $ErrorActionPreference = 'Stop'
  $txt | ForEach-Object { Write-Host $_ }
  if ($rc -eq 1 -or $lrc -eq 1) { foreach ($k in $live) { $o = Invoke-Dev $k 'frtrig worlddiff'; Say "$k frtrig: $(Short $o 120)" } }
  $sum = @($txt | Where-Object { $_ -match '^SUMMARY|FIRST DIVERGENCE' }) -join "`n"
  @{ Rc = [Math]::Max($rc, $lrc); Out = $outDir; Summary = $sum }
}
function Invoke-Spec($p, $runDir, $reportPath) {
  $script:Marks = @{}; $script:Vars = @{}; $script:ClsCache = @{}
  $script:Alive = @{}; foreach ($k in $KEYS) { $script:Alive[$k] = [bool]((-not $DryRun) -and (Get-SideProc $k)) }
  Set-Marks
  $invSt = @{}; foreach ($k in $KEYS) { $m = $script:Marks[$k]; $invSt[$k] = @{ Pos = $m.Off; Head = $m.Head; Skip = $m.Skip } }
  $rows = New-Object System.Collections.ArrayList; $t0 = Get-Date; $abort = $null; $n = 0
  foreach ($st in $p.Steps) {
    $n++
    $row = [ordered]@{ N = $n; Line = $st.Line; Kind = $st.Kind; Side = $st.Side; Text = $st.Text; Result = ''; Secs = 0.0; Detail = '' }
    if ($abort) { $row.Result = if ($st.Kind -eq 'manual') { 'MANUAL' } else { 'SKIP' }; $row.Detail = if ($st.Kind -eq 'manual') { $st.Args[1] } else { $abort }; [void]$rows.Add($row); continue }
    $s0 = Get-Date
    try {
      switch ($st.Kind) {
        'needs' { $row.Result = 'INFO'; $row.Detail = $st.Text.Substring(6) }
        'note' { $row.Result = 'INFO'; $row.Detail = $st.Text.Substring(4).Trim() }
        'manual' { $row.Result = 'MANUAL'; $row.Detail = "$($st.Args[0]): $($st.Args[1])" }
        'census' {
          if ($DryRun) { $row.Result = 'DRY'; $row.Detail = 'census + worlddiff skipped in dry run' }
          else {
            Check-Alive
            $cr = Invoke-Census (Join-Path $runDir ("census_step$n")) $null
            $row.Result = if ($cr.Rc -eq 0) { 'PASS' } else { 'FAIL' }
            $row.Detail = "$($cr.Summary)`n$($cr.Out)"
          }
        }
        'mark' { if ($st.Args[0] -eq 'start') { foreach ($k in $KEYS) { $script:Marks[$k] = @{ Off = 0; Head = ''; Skip = $false }; $invSt[$k] = @{ Pos = 0; Head = ''; Skip = $false } }; $row.Detail = 'anchor = start of both logs' } else { Set-Marks; $row.Detail = "anchor A@$($script:Marks.A.Off) B@$($script:Marks.B.Off)" }; $row.Result = 'OK' }
        'wait' {
          $end = (Get-Date).AddSeconds($st.Secs)
          while ((Get-Date) -lt $end) { Check-Alive; Start-Sleep -Milliseconds ([int][Math]::Max(50, [Math]::Min(1000, ($end - (Get-Date)).TotalMilliseconds))) }
          $row.Result = 'OK'
        }
        { $_ -in 'expect', 'expect_not' } {
          Check-Alive
          $rx = Expand-Vars $st.Rx -Escape
          $r = Scan $st.Side $rx $st.Secs -Not:($st.Kind -eq 'expect_not')
          $row.Result = if ($r.Ok) { 'PASS' } else { 'FAIL' }
          $row.Detail = if ($r.Lines.Count) { ($r.Lines | Select-Object -First 5) -join "`n" } elseif ($st.Kind -eq 'expect') { "no match in $($st.Secs) s" } else { "none in $($st.Secs) s" }
        }
        default {
          Set-Marks
          if ($st.Side -and -not $DryRun -and $st.Kind -ne 'launch' -and -not $script:Alive[$st.Side]) { Check-Alive; if (-not (Get-SideProc $st.Side)) { throw "$($st.Side) is not running" } }
          $out = Do-Step $st $runDir
          $row.Detail = "" + $out
          if ($out -eq 'DRY') { $row.Result = 'DRY' }
          elseif ($st.Assert) { $ax = Expand-Vars $st.Assert -Escape; $row.Result = if ([regex]::IsMatch("" + $out, $ax)) { 'PASS' } else { 'FAIL' } }
          elseif ("$out" -match '^(cannot connect|NOT CONSUMED|no function|cannot resolve|missing arg|arg |ProcessEvent exception|need KismetSystemLibrary|timeout)') { $row.Result = 'ERR' }
          else { $row.Result = 'OK' }
        }
      }
    } catch {
      $msg = "$($_.Exception.Message)"
      if ($msg -like 'DEAD:*') { $row.Result = 'DEAD'; $abort = $msg } elseif ($msg -like 'CRASH:*') { $row.Result = 'CRASH'; $abort = $msg } else { $row.Result = 'ERR' }
      $row.Detail = $msg
    }
    $row.Secs = [Math]::Round(((Get-Date) - $s0).TotalSeconds, 1)
    [void]$rows.Add($row)
    Write-Host ("{0,3} {1,-6} {2,5}s  {3}" -f $row.N, $row.Result, $row.Secs, (Short $st.Text 110))
    if (($StopOnFail -or -not ($KeepGoing -or $DryRun)) -and $row.Result -in 'FAIL', 'ERR' -and -not $abort) { $abort = "stopped after step $n ($($row.Result))" }
  }
  foreach ($k in $KEYS) {
    $all = Read-NewLines $k $invSt[$k]; $inv = @($all | Where-Object { $_ -match 'NOLA INV (?!table)' })
    $n++
    $row = [ordered]@{ N = $n; Line = 0; Kind = 'inv'; Side = $k; Text = "no NOLA INV invariant break on $k during the spec"; Result = $(if ($inv.Count) { 'FAIL' } else { 'PASS' }); Secs = 0.0; Detail = $(if ($inv.Count) { "$($inv.Count) break(s):`n" + (($inv | Select-Object -First 5) -join "`n") } else { 'none' }) }
    [void]$rows.Add($row)
    Write-Host ("{0,3} {1,-6} {2,5}s  {3}" -f $row.N, $row.Result, $row.Secs, $row.Text)
  }
  $cnt = @{}; foreach ($r in $rows) { $cnt[$r.Result] = 1 + [int]$cnt[$r.Result] }
  $bad = [int]$cnt['FAIL'] + [int]$cnt['ERR'] + [int]$cnt['DEAD'] + [int]$cnt['CRASH']
  $verdict = if ($bad) { 'FAIL' } else { 'PASS' }
  $o = New-Object System.Collections.ArrayList
  [void]$o.Add("S2 harness report  spec=$($p.Name)  file=$($p.Path)")
  [void]$o.Add("start=$($t0.ToString('yyyy-MM-dd HH:mm:ss'))  secs=$([int]((Get-Date) - $t0).TotalSeconds)  mode=$(if ($DryRun) { 'dry' } else { 'live' })  logA=$(LogPath 'A')  logB=$(LogPath 'B')")
  [void]$o.Add('')
  [void]$o.Add(('{0,3}  {1,4}  {2,-6}  {3,-4}  {4,6}  {5}' -f '#', 'line', 'result', 'side', 'secs', 'step'))
  foreach ($r in $rows) {
    [void]$o.Add(('{0,3}  {1,4}  {2,-6}  {3,-4}  {4,6}  {5}' -f $r.N, $r.Line, $r.Result, $r.Side, $r.Secs, $r.Text))
    if ($r.Detail -and $r.Kind -notin 'note', 'needs', 'manual', 'wait', 'mark') { foreach ($d in (("" + $r.Detail) -split "`n" | Select-Object -First 5)) { [void]$o.Add('                                  -> ' + (Short $d 400)) } }
    elseif ($r.Kind -eq 'manual') { [void]$o.Add('                                  -> ' + (Short $r.Detail 400)) }
  }
  [void]$o.Add('')
  [void]$o.Add(('TOTAL ' + (($cnt.Keys | Sort-Object | ForEach-Object { "$_=$($cnt[$_])" }) -join ' ') + "  VERDICT $verdict"))
  New-Item -ItemType Directory -Force (Split-Path $reportPath) | Out-Null
  [IO.File]::WriteAllLines($reportPath, [string[]]$o)
  Say "report $reportPath  VERDICT $verdict"
  @{ Rows = $rows; Verdict = $verdict; Bad = $bad; Report = $reportPath }
}

function Prepare-ClientE($fc) {
  $dst = "$($SIDES.E.Bridge)\flags.txt"
  if (-not $fc) { Assert-Writable $dst; Copy-Item -LiteralPath "$($SIDES.B.Bridge)\flags.txt" $dst -Force }
  Set-FlagLine 'E' 'netlisten' '7797'; Set-FlagLine 'E' 'netpeerport' '7799'; Set-FlagLine 'E' 'joinmenu' '0'
}
function Save-FlagsBackup {
  Restore-FlagsBackup
  $d = $FLAGSBAK; New-Item -ItemType Directory -Force $d | Out-Null
  foreach ($k in $KEYS) {
    $f = Join-Path $SIDES[$k].Bridge 'flags.txt'; $b = "$d\$($SIDES[$k].Tag).flags"
    if ((Test-Path -LiteralPath $f) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $f $b }
  }
}
function Restore-FlagsBackup {
  $d = $FLAGSBAK
  if (-not (Test-Path -LiteralPath $d)) { return }
  foreach ($k in 'A', 'B', 'E') {
    $b = "$d\$($SIDES[$k].Tag).flags"
    if (Test-Path -LiteralPath $b) {
      $f = Join-Path $SIDES[$k].Bridge 'flags.txt'; Assert-Writable $f
      Copy-Item -LiteralPath $b $f -Force; Remove-Item -LiteralPath $b -Force; Say "flags restored on $k ($($SIDES[$k].Tag))"
    }
  }
}
function Md5Of($p) { (Get-FileHash -LiteralPath $p -Algorithm MD5).Hash.ToLower() }
function Get-DllTarget($k) {
  $m = if ($script:ModsDirOverride -and $script:ModsDirOverride.ContainsKey($k)) { $script:ModsDirOverride[$k] } else { Get-ModsDir $k }
  "$m\NolaNative\dlls\main.dll"
}
function Get-BaselineMd5 {
  if (-not (Test-Path -LiteralPath $BASEFILE)) { return $null }
  $l = (Get-Content -LiteralPath $BASEFILE | Select-Object -First 1)
  if ($l -match '^([0-9a-fA-F]{32})') { return $Matches[1].ToLower() }
  $null
}
function Backup-Dlls([string]$src, [string[]]$keys) {
  [void](Restore-DllBackup)
  $sf = Full $src
  foreach ($k in $keys) { if ((Full (Get-DllTarget $k)) -ieq $sf) { Fail "-Dll $src is the live main.dll of ${k}: installing it would delete the only copy" } }
  $bm = Get-BaselineMd5
  $ents = @()
  foreach ($k in $keys) {
    $t = Get-DllTarget $k; Assert-Writable $t
    $e = [ordered]@{ Key = $k; Tag = $SIDES[$k].Tag; Target = $t; Existed = (Test-Path -LiteralPath $t); Md5 = ''; Bak = '' }
    if ($e.Existed) {
      $e.Md5 = Md5Of $t
      if ($bm -and $e.Md5 -ne $bm -and -not $AcceptBase) { Fail "main.dll of $k ($t) has md5 $($e.Md5), not the baseline $bm ($BASEFILE). It is probably a leftover test DLL: put the clean one back first (harness.ps1 dllrestore -Dll <clean dll>), or pass -AcceptBase to treat it as the original anyway" }
      $e.Bak = "$DLLBAK\$($e.Tag).main.dll"; Assert-Writable $e.Bak
    }
    $ents += , $e
  }
  New-Item -ItemType Directory -Force $DLLBAK | Out-Null
  try {
    foreach ($e in $ents) {
      if ($e.Existed) {
        Copy-Item -LiteralPath $e.Target $e.Bak -Force
        if ((Md5Of $e.Bak) -ne $e.Md5) { Fail "backup copy of $($e.Target) failed the md5 check" }
      }
    }
  } catch {
    $m = $_; foreach ($e in $ents) { if ($e.Bak -and (Test-Path -LiteralPath $e.Bak)) { Remove-Item -LiteralPath $e.Bak -Force } }; throw $m
  }
  $man = [ordered]@{ saved = (Get-Date).ToString('o'); src = $src; srcMd5 = (Md5Of $src); entries = @($ents) }
  ($man | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath "$DLLBAK\manifest.json" -Encoding utf8
  foreach ($e in $ents) { Say "original main.dll of $($e.Key) saved: md5 $(if ($e.Existed) { $e.Md5.Substring(0, 8) } else { '(absent)' }) -> $($e.Bak)" }
}
function Restore-DllBackup {
  $mf = "$DLLBAK\manifest.json"
  if (-not (Test-Path -LiteralPath $mf)) { return 0 }
  $m = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
  $bad = @(); $n = 0
  foreach ($e in @($m.entries)) {
    try {
      Assert-Writable $e.Target
      if ($e.Existed) {
        if (-not (Test-Path -LiteralPath $e.Bak)) { throw "backup copy $($e.Bak) is missing" }
        if ((Md5Of $e.Bak) -ne $e.Md5) { throw "backup copy $($e.Bak) no longer has md5 $($e.Md5)" }
        $ok = (Test-Path -LiteralPath $e.Target) -and ((Md5Of $e.Target) -eq $e.Md5)
        for ($i = 0; $i -lt 5 -and -not $ok; $i++) {
          try { Copy-Item -LiteralPath $e.Bak $e.Target -Force -ErrorAction Stop } catch { Start-Sleep -Seconds 1 }
          $ok = (Test-Path -LiteralPath $e.Target) -and ((Md5Of $e.Target) -eq $e.Md5)
        }
        if (-not $ok) { throw "after the copy $($e.Target) does not have md5 $($e.Md5) (file locked by a running game?)" }
        Say "main.dll of $($e.Key) restored and verified: md5 $($e.Md5.Substring(0, 8))"
      } else {
        if (Test-Path -LiteralPath $e.Target) { Remove-Item -LiteralPath $e.Target -Force }
        Say "main.dll of $($e.Key) removed (it did not exist before the run)"
      }
      $n++
    } catch { $bad += "$($e.Key): $($_.Exception.Message)" }
  }
  if ($bad.Count) { Fail ("DLL restore incomplete, backups kept in ${DLLBAK}: " + ($bad -join '; ')) }
  foreach ($e in @($m.entries)) { if ($e.Bak -and (Test-Path -LiteralPath $e.Bak)) { Remove-Item -LiteralPath $e.Bak -Force } }
  Remove-Item -LiteralPath $mf -Force
  $n
}
function Install-Dll([string]$src, [string[]]$keys) {
  Backup-Dlls $src $keys
  foreach ($k in $keys) { Put-File $src (Get-DllTarget $k) }
}
function Run-UpGuarded([scriptblock]$body) {
  try { & $body } catch {
    $m = $_
    $live = @($KEYS | Where-Object { Get-SideProc $_ })
    if ($live.Count) { Say "up failed with game(s) $($live -join ',') still running: flags and DLL stay as launched; 'harness.ps1 down' restores them"; throw $m }
    try { Restore-FlagsBackup } catch { Say "WARNING: flag restore failed: $($_.Exception.Message)" }
    try { [void](Restore-DllBackup) } catch { Say "WARNING: DLL restore failed, 'harness.ps1 down' (or dllrestore) will retry: $($_.Exception.Message)" }
    throw $m
  }
}
function Cmd-Up { try { Run-UpGuarded { Cmd-Up-Body }; if ($Day) { Set-DayAll }; if ($Calm) { Run-Calm } } finally { Flush-UpLog } }
function Cmd-DllStatus {
  $bm = Get-BaselineMd5
  Write-Host "baseline md5: $(if ($bm) { $bm } else { '(none: harness.ps1 dllbaseline -Dll <clean dll>)' })  file $BASEFILE"
  foreach ($k in 'A', 'B', 'E') {
    if (-not (Test-Path -LiteralPath $SIDES[$k].Root)) { Write-Host "$k $($SIDES[$k].Root) (no root)"; continue }
    $t = Get-DllTarget $k
    $m5 = if (Test-Path -LiteralPath $t) { Md5Of $t } else { '(absent)' }
    Write-Host ("{0} {1,-34} md5 {2}  {3}" -f $k, $SIDES[$k].Root, $m5, $(if (-not $bm) { '' } elseif ($m5 -eq $bm) { 'baseline' } else { 'NOT BASELINE' }))
    Write-Host "  $t"
  }
  $mf = "$DLLBAK\manifest.json"
  if (Test-Path -LiteralPath $mf) { $m = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json; Write-Host "PENDING restore from $($m.saved) (test dll $($m.src) md5 $($m.srcMd5)):"; foreach ($e in @($m.entries)) { Write-Host "  $($e.Key) -> original md5 $($e.Md5) in $($e.Bak)" } } else { Write-Host 'no pending DLL restore' }
}
function Cmd-DllRestore {
  if ($Dll) {
    if (-not (Test-Path -LiteralPath $Dll)) { Fail "missing file $Dll" }
    foreach ($k in 'A', 'B', 'E') { if (Get-SideProc $k) { Fail "$k runs: stop the games first (harness.ps1 down)" } }
    if (Test-Path -LiteralPath "$DLLBAK\manifest.json") { Fail "a restore is pending: run dllrestore without -Dll first" }
    foreach ($k in 'A', 'B', 'E') { Put-File $Dll (Get-DllTarget $k) }
    Say "main.dll of A, B and E replaced by $Dll (md5 $(Md5Of $Dll))"
  } else { $n = Restore-DllBackup; Say "dllrestore: $n root(s) restored" }
}
function Cmd-DllBaseline {
  if (-not $Dll -or -not (Test-Path -LiteralPath $Dll)) { Fail 'dllbaseline -Dll <the clean main.dll>' }
  Assert-Writable $BASEFILE
  [IO.File]::WriteAllLines($BASEFILE, [string[]]@((Md5Of $Dll), (Full $Dll)))
  Say "baseline md5 $(Md5Of $Dll) from $Dll"
}
function Split-SetArgs($items) {
  $o = New-Object System.Collections.ArrayList
  foreach ($it in @($items)) { if ($it) { foreach ($p in ([regex]::Split("$it", ',(?=[A-Za-z0-9_]+=)'))) { $p = $p.Trim(); if ($p) { [void]$o.Add($p) } } } }
  , @($o)
}
function Mirror-Dir($src, $dst) {
  $rel = { param($root) $r = (Get-Item -LiteralPath $root).FullName.TrimEnd(''); @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($r.Length + 1) + $(if ($_.PSIsContainer) { '' } else { '' }) }) }
  $before = if (Test-Path -LiteralPath $dst) { & $rel $dst } else { @() }
  $null = & robocopy $src $dst /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
  if ($LASTEXITCODE -ge 8) { Fail "robocopy $src -> $dst failed (exit $LASTEXITCODE)" }
  $after = @{}; foreach ($x in (& $rel $dst)) { $after[$x] = 1 }
  $gone = @($before | Where-Object { -not $after.ContainsKey($_) } | Sort-Object)
  foreach ($g in $gone) { Say "  removed from ${dst}: $g" }
  Say "  mirror ${dst}: $(@($before).Count) entries before, $($after.Count) after, $($gone.Count) removed"
  $gone.Count
}
function Stop-CrashReporters {
  $n = 0
  foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='CrashReportClient.exe'" -ErrorAction SilentlyContinue)) {
    $path = "" + $p.ExecutablePath; $cl = "" + $p.CommandLine
    if ($path -match ('^C:\\' + $CRASHRX) -or $cl -match $CRASHRX) {
      try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; $n++; Say "killed orphan CrashReportClient pid $($p.ProcessId) ($path)" } catch { Say "WARNING: cannot kill CrashReportClient pid $($p.ProcessId): $($_.Exception.Message)" }
    }
  }
  if ($n) { Start-Sleep -Milliseconds 800 }
  $n
}
function Get-SaveTargets {
  $sv = @($SIDES.A.Saved)
  if ($ClientSave -eq 'master') { $sv += $SIDES.B.Saved; if ($KEYS -contains 'E') { $sv += $SIDES.E.Saved } }
  $t = @(); foreach ($s in $sv) { foreach ($os in 'STEAM', 'NULL') { $t += "$env:LOCALAPPDATA\Stalker2\$s\$os\SaveGames" } }
  $t
}
function Invoke-HotSwap {
  $rd = Get-CurrentRun; $s = Read-State $rd
  $all = $true
  foreach ($k in $KEYS) { if (-not (Test-HotDll (Get-DllTarget $k))) { $all = $false; Say "hot reload skipped: main.dll of $k is not a dev (hot-reloadable) build" } }
  if (-not (Test-HotDll $Dll)) { Say "hot reload skipped: $Dll is a release build (no nola_hot_start)"; return $false }
  if (-not $all -or -not (Test-Path -LiteralPath $HOTRELOAD)) { return $false }
  $t0 = Get-Date
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $o = & powershell -NoProfile -File $HOTRELOAD @HOTARGS -Dll $Dll -Sides ($KEYS -join ',') 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE; $ErrorActionPreference = $eap
  $o | ForEach-Object { Say "  hotreload: $_" }
  foreach ($k in $KEYS) { if (-not (Get-SideProc $k)) { Say "hot reload failed: $k is gone: cold boot"; return $false } }
  if ($code -ne 0) { Say "hot reload failed (exit $code): cold boot"; return $false }
  Set-StateProp $s 'hot_md5' (Md5Of $Dll); Set-StateProp $s 'dll' $Dll; Set-StateProp $s 'hot_secs' ([Math]::Round(((Get-Date) - $t0).TotalSeconds, 1))
  Write-State $rd $s
  Say "hot reload ok in $([int]((Get-Date) - $t0).TotalSeconds) s: loaded md5 $((Md5Of $Dll).Substring(0, 8)) on $($KEYS -join ',')"
  $true
}
function Test-SaveDlc($dir, $who) {
  if (-not (Test-Path -LiteralPath "$dir\CampaignsSave.sav")) { return }
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $o = (& $UV run --no-project python -I "$PSScriptRoot\savedlc.py" $dir 2>&1 | ForEach-Object { "$_" }) -join ' '
  $rc = $LASTEXITCODE; $ErrorActionPreference = $eap
  Say "DLC check ${who}: $o"
  if ($rc -eq 3 -and (Get-Process steam -ErrorAction SilentlyContinue)) { Say "DLC check ${who}: save needs DLC but Steam is running (app 1643320 owns it): ok"; return }
  if ($rc -eq 3) { Fail "DLC SAVE: $who $dir was made with DLC ($o). Steam is closed, so the test games own no DLC and the game stops on the 'save created with a DLC' dialog and never loads. $(if ($who -like 'client*') { 'Boot with -ClientSave master (the client loads the DLC-free master too) or strip that folder.' } else { 'Use the DLC-free master (default -Save) or strip a copy.' }) Strip: python C:\modding\s2harness\tools\idxmask.py strip <dir>\CampaignsSave.sav <copy>\CampaignsSave.sav (copy the Data folder next to it). Nothing was launched." }
}
function Invoke-SaveTool([string[]]$a) {
  $tool = "$G\ModWork\tools\savecensus\savetool.py"
  $env:SAVECENSUS_OODEC = "$H\tools\oodec.py"
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { $o = @(& $UV run --no-project python -I $tool @a 2>$null | ForEach-Object { "$_" }) } finally { $ErrorActionPreference = $eap }
  ($o -join "`n")
}
function Get-SaveStateText([string]$dir, [string]$name) {
  $txt = Invoke-SaveTool @('state', $dir, '--name', $name)
  if (-not $txt.Trim()) { return $null }
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $dlc = (& $UV run --no-project python -I "$PSScriptRoot\savedlc.py" $dir 2>&1 | ForEach-Object { "$_" }) -join ' '
  $ErrorActionPreference = $eap
  $txt.TrimEnd() + "`ndlc: $dlc`n"
}
function Cmd-SaveState {
  $root = "$H\testsave"
  $names = if (-not $Spec -or $Spec -eq 'all') { @(Get-ChildItem -LiteralPath $root -Directory | ForEach-Object { $_.Name }) } else { @($Spec) }
  foreach ($n in $names) {
    $d = Join-Path $root $n
    if (-not (Test-Path -LiteralPath $d)) { Fail "no testsave\$n" }
    $txt = Get-SaveStateText $d $n
    if (-not $txt) { Say "savestate ${n}: save not readable (no STATE.md written)"; continue }
    [IO.File]::WriteAllText("$d\STATE.md", $txt, (New-Object Text.UTF8Encoding $false))
    Say "savestate ${n}: $(($txt -split "`n")[0])"
  }
  $global:LASTEXITCODE = 0
}
function Cmd-Saves {
  foreach ($d in Get-ChildItem -LiteralPath "$H\testsave" -Directory) {
    $sf = Join-Path $d.FullName 'STATE.md'
    $first = if (Test-Path -LiteralPath $sf) { [IO.File]::ReadAllLines($sf)[0] } else { "$($d.Name): no STATE.md (run: harness.ps1 savestate $($d.Name))" }
    Write-Host $first
  }
}
function Show-SaveStateHead {
  $sf = Join-Path $Save 'STATE.md'
  if (-not (Test-Path -LiteralPath $sf)) { return }
  foreach ($l in @([IO.File]::ReadAllLines($sf) | Select-Object -First 3)) { if ($l) { Say "save state: $l" } }
}
function Cmd-Up-Body {
  if ($Dll -and -not (Test-Path -LiteralPath $Dll)) { Fail "missing DLL ${Dll}: build it before up (nothing was touched, the lock is still yours)" }
  Assert-Safe
  Check-Hold | Out-Null
  Show-SaveStateHead
  if ($Reuse -or -not $Cold) {
    $why = Test-Reuse
    if (-not $why) { Say "REUSE: the pair is up with the same DLL, paks, profile and save: no reboot"; Invoke-Reset; return }
    Say "REUSE not possible: $why"
    $why2 = $null; if ($Dll -and "$why" -like 'DLL swap needed*') { $why2 = Test-Reuse -IgnoreDll; if ($why2) { Say "hot swap not possible, so this is a cold boot: $why2" } }
    if ($Dll -and "$why" -like 'DLL swap needed*' -and -not $why2) {
      if (Invoke-HotSwap) { Say "REUSE: hot reload done, pair keeps running"; Invoke-Reset; return }
    }
    if (@($KEYS | Where-Object { Get-SideProc $_ }).Count) { Say 'cold boot: harness down first'; Invoke-Down }
  }
  foreach ($k in $KEYS) { if (Get-SideProc $k) { Fail "$k ($($SIDES[$k].Role)) already runs from $($SIDES[$k].Root): run 'harness.ps1 down' first" } }
  if (-not (@(Split-SetArgs $Set) -match '^devdlc=[1-9]')) {
    if (-not $NoSave) { Test-SaveDlc $Save 'master save' }
    if ($ClientSave -eq 'keep' -and -not $HostOnly) {
      $os = if (Get-Process steam -ErrorAction SilentlyContinue) { 'STEAM' } else { 'NULL' }
      foreach ($ck in ($KEYS | Where-Object { $_ -ne 'A' })) { Test-SaveDlc "$env:LOCALAPPDATA\Stalker2\$($SIDES[$ck].Saved)\$os\SaveGames" "client $ck kept save ($os)" }
    }
  }
  if ($Pair -eq 3) { $need3 = if ($PSBoundParameters.ContainsKey('MinFreeGB')) { $MinFreeGB } else { 13 }; $fr = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1); Say "pair 3: free RAM $fr GB (need $need3 GB)"; if ($fr -lt $need3) { Fail "not enough free RAM for pair 3: $fr GB < $need3 GB (pair 3 adds two games, measured 11 GB resident (rm1): trim idle games first, C:\modding\s2harness\tools\trim_idle.ps1); nothing launched" } }
  $rd = New-RunDir; Say "run folder $rd"
  $t0 = Get-Date
  Save-FlagsBackup
  if (-not $NoSave) {
    if (-not (Test-Path -LiteralPath "$Save\CampaignsSave.sav")) { Fail "master save not found: $Save" }
    $targets = Get-SaveTargets
    foreach ($t in $targets) {
      Assert-Writable "$t\x"
      New-Item -ItemType Directory -Force $t | Out-Null
      [void](Mirror-Dir $Save $t)
      Get-ChildItem -LiteralPath $t -Recurse -File | ForEach-Object { if ($_.IsReadOnly) { $_.IsReadOnly = $false } }
      $n = @(Get-ChildItem -LiteralPath "$t\Data" -Filter *.sav -File).Count
      Say "save restored: $Save -> $t ($n .sav, read-only cleared)"
    }
  }
  if ($Dll) {
    if (-not (Test-Path -LiteralPath $Dll)) { Fail "missing file $Dll" }
    Install-Dll $Dll $KEYS
  } else { [void](Restore-DllBackup) }
  foreach ($pk in @($Pak) + @($PakHost)) { if ($pk) { Put-File $pk ("$($SIDES.A.Root)\Stalker2\Content\Paks\~mods\" + (Split-Path $pk -Leaf)) } }
  foreach ($pk in @($Pak) + @($PakClient)) { if ($pk) { foreach ($ck in ($KEYS | Where-Object { $_ -ne 'A' })) { Put-File $pk ("$($SIDES[$ck].Root)\Stalker2\Content\Paks\~mods\" + (Split-Path $pk -Leaf)) } } }
  $fh = if ($FlagsHost) { $FlagsHost } elseif ($Flags) { $Flags } else { $null }
  $fc = if ($FlagsClient) { $FlagsClient } elseif ($Flags) { $Flags } else { $null }
  if ($fh -or $fc) {
    if ($fh) { Put-File $fh "$($SIDES.A.Bridge)\flags.txt" }
    if ($fc) { foreach ($ck in ($KEYS | Where-Object { $_ -ne 'A' })) { Put-File $fc "$($SIDES[$ck].Bridge)\flags.txt" } }
  } else {
    $src = (Get-ModsDir 'A') + '\NolaNative\dlls\main.dll'
    Say "flags: gen_flags_p2.py from the DLL tables of $src"
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $g = & $UV run --no-project python -I $GENFLAGS $src 2>&1 | ForEach-Object { "$_" } | Out-String; $ErrorActionPreference = $eap
    if ($LASTEXITCODE -ne 0) { Fail "gen_flags_p2.py failed: $g" }
    ($g -split "`r?`n") | Where-Object { $_ -match 'keys' } | ForEach-Object { Say "  $_" }
  }
  if ($KEYS -contains 'E') { Prepare-ClientE $fc }
  if ($Clients -ge 2) { $mc = if ($MaxClients -gt 0) { $MaxClients } else { 3 }; Set-FlagLine 'A' 'maxclients' "$mc"; Say "flag maxclients=$mc on A"; foreach ($k in $KEYS) { Set-FlagLine $k 'netlocal' '1' }; Say "flag netlocal=1 on all" }
  foreach ($k in $KEYS) { Set-FlagLine $k 'joinmenu' '0' }; Say "flag joinmenu=0 on all (test default: the relay is live without the menu entry; -Set joinmenu=1 keeps the menu)"
  foreach ($k in $KEYS) { Copy-Item -LiteralPath "$($SIDES[$k].Bridge)\flags.txt" "$rd\flags_base_$($SIDES[$k].Tag).txt" }
  $setList = Split-SetArgs $Set; foreach ($kv in $setList) { if ($kv) { if ($kv -notmatch '^([A-Za-z0-9_]+)=(.*)$') { Fail "-Set wants key=value: $kv" }; foreach ($k in $KEYS) { Set-FlagLine $k $Matches[1] $Matches[2] }; Say "flag $kv on A and B" } }
  foreach ($k in $KEYS) { Copy-Item -LiteralPath "$($SIDES[$k].Bridge)\flags.txt" "$rd\flags_$($SIDES[$k].Tag).txt" }
  $state = [ordered]@{ clients = $Clients; start = $t0.ToString('o'); dll = $Dll; dll_md5 = (Get-DllMd5s); paks = @(@($Pak) + @($PakHost) + @($PakClient) | Where-Object { $_ }); pak_md5 = (Get-PakSig); profile = $Profile; save = $(if ($NoSave) { '' } else { $Save }); resets = 0 }
  if ($NoHost) {
    $hp = 0; $state.nohost = $true; Say "NoHost: host A not started (ghost peer mode: the client talks to a ghostpeer.py on its netpeerport)"
    $cb = Launch-Side 'B' $ClientTimeout $rd; $state.launch_client = $cb.T0.ToString('o'); Wait-Worlds @($cb)
  } elseif ($HostOnly) {
    $ca = Launch-Side 'A' $HostTimeout $rd; $state.launch_host = $ca.T0.ToString('o'); $state.hostonly = $true; Wait-Worlds @($ca)
  } elseif ($Serial) {
    $ca = Launch-Side 'A' $HostTimeout $rd; $state.launch_host = $ca.T0.ToString('o'); Wait-Worlds @($ca)
    $cb = Launch-Side 'B' $ClientTimeout $rd; $state.launch_client = $cb.T0.ToString('o'); Wait-Worlds @($cb)
  } else {
    $ca = Launch-Side 'A' $HostTimeout $rd; $state.launch_host = $ca.T0.ToString('o')
    $cb = Launch-Side 'B' $ClientTimeout $rd; $state.launch_client = $cb.T0.ToString('o'); $cb.Gate = 'A'
    Wait-Worlds @($ca, $cb)
  }
  if (-not $NoHost) { $hp = $ca.Pid; $state.host_pid = $hp }
  $cp = $cb.Pid; $state.client_pid = $cp
  if (-not $NoHost -and -not $HostOnly) { $state.join_host = Wait-Line 'A' $JoinRegex $JoinTimeout 'join' }
  if (-not $HostOnly) { $state.join_client = Wait-Line 'B' $JoinRegex $JoinTimeout 'join' }
  if ($KEYS -contains 'E') {
    $os = Get-CimInstance Win32_OperatingSystem; $free = [math]::Round($os.FreePhysicalMemory / 1MB, 1); $cfree = [math]::Round($os.FreeVirtualMemory / 1MB, 1)
    Say "free RAM before E: $free GB (commit free $cfree GB, need $MinFreeGB GB)"
    if ($free -lt $MinFreeGB) { Fail "not enough free RAM for client E: $free GB < $MinFreeGB GB; E not launched" }
    $ep = Start-Side 'E' $ClientTimeout $rd; $state.client3_pid = $ep
    $state.join_client3 = Wait-Line 'E' $JoinRegex $JoinTimeout 'join'
    try { $state.roster_host = Wait-Line 'A' 'NOLA PEER[^\r\n]*(pid=2|players 2 of)' 90 'roster' } catch { Say "WARNING: host log has no 2nd client roster line: $($_.Exception.Message)" }
  }
  $state.ready = (Get-Date).ToString('o')
  ($state | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath "$rd\state.json" -Encoding utf8
  if (-not $NoHost -and $SIDES.A.NoPlug -eq '1') { try { $pl = Invoke-S2Dev 'A' @('plug reload anomaly-scanner') 30000; Say "nbot plugin on A: $(($pl -replace '\s+', ' ').Trim())"; $pl | Set-Content -LiteralPath "$rd\nbot_plug_A.txt" -Encoding utf8 } catch { Say "WARNING: nbot plug reload on A failed: $($_.Exception.Message)" } }
  Say "UP: host pid=$hp client pid=$cp joined in $([int]((Get-Date) - $t0).TotalSeconds) s; run folder $rd"
  try { $bt = Get-BootText $rd; [IO.File]::WriteAllLines("$rd\boot.txt", [string[]]$bt); $bt | ForEach-Object { Write-Host $_ } } catch { Say "WARNING: boot timeline failed: $($_.Exception.Message)" }
}
function Get-DllMd5s { (@($KEYS | ForEach-Object { $t = Get-DllTarget $_; if (Test-Path -LiteralPath $t) { "$_=" + (Md5Of $t) } else { "$_=absent" } })) -join ',' }
function Get-PakSig { (@(@($Pak) + @($PakHost) + @($PakClient) | Where-Object { $_ } | ForEach-Object { (Split-Path $_ -Leaf) + '=' + (Md5Of $_) }) | Sort-Object) -join ',' }
function Read-State($rd) { $f = "$rd\state.json"; if (-not (Test-Path -LiteralPath $f)) { return $null }; Get-Content -LiteralPath $f -Raw | ConvertFrom-Json }
function Write-State($rd, $s) { ($s | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath "$rd\state.json" -Encoding utf8 }
function Set-StateProp($s, $n, $v) { if ($s.PSObject.Properties[$n]) { $s.$n = $v } else { $s | Add-Member -NotePropertyName $n -NotePropertyValue $v } }
function Test-Reuse {
  param([switch]$IgnoreDll)
  $rd = Get-CurrentRun; if (-not $rd) { return 'no current run folder' }
  $s = Read-State $rd; if (-not $s) { return "no state.json in $rd" }
  if (-not $s.ready) { return 'the last up did not finish' }
  foreach ($k in $KEYS) { if (-not (Get-SideProc $k)) { return "$k ($($SIDES[$k].Role)) is not running" } }
  if ($NoHost -or $s.nohost) { return 'NoHost run' }
  if ([int]$s.clients -ne $Clients) { return "clients $($s.clients) -> $Clients" }
  if ("$($s.profile)" -ne $Profile) { return "profile $($s.profile) -> $Profile" }
  $cur = Get-DllMd5s
  $hm = "$($s.hot_md5)"
  if ($IgnoreDll) { }
  elseif ($Dll) {
    $w = Md5Of $Dll
    if ($hm) { if ($hm -ne $w) { return "DLL swap needed on $($KEYS -join ',') (hot-loaded $hm, wanted $w)" } }
    else { foreach ($k in $KEYS) { if ($cur -notmatch "$k=$w") { return "DLL swap needed on $k (running $cur, wanted $w)" } } }
  }
  elseif ($hm -and $Cold) { return 'a hot-loaded DLL is running and this up -Cold wants the original' }
  elseif ((Test-Path -LiteralPath "$DLLBAK\manifest.json") -and $Cold) { return 'a test DLL is installed and this up -Cold wants the original' }
  elseif ($hm -or (Test-Path -LiteralPath "$DLLBAK\manifest.json")) { Say "REUSE keeps the running test DLL (no -Dll given; pass -Dll <path> or -Cold for the original)" }
  if ("$($s.dll_md5)" -and "$($s.dll_md5)" -ne $cur) { return "main.dll changed on disk since the boot ($($s.dll_md5) -> $cur)" }
  $ps = Get-PakSig; if ("$($s.pak_md5)" -ne $ps) { return "paks differ ($($s.pak_md5) -> $ps)" }
  $rl = if ($IgnoreDll) { $MaxResets + 3 } else { $MaxResets }
  if ([int]$s.resets -ge $rl) { return "$($s.resets) resets on this boot (limit $rl): cold boot" }
  if ("$($s.save)" -ne $(if ($NoSave) { '' } else { $Save })) { return "scenario save $($s.save) -> $Save" }
  foreach ($k in $KEYS) {
    try { $new = Build-ResetFlags $rd $k } catch { return "$($_.Exception.Message)" }
    $cur = @([IO.File]::ReadAllLines((Join-Path $SIDES[$k].Bridge 'flags.txt')) | Where-Object { $_ -ne '' })
    $net = @(Flag-Diff $cur $new | Where-Object { $NETKEYS -contains $_ }); if ($net.Count) { return "start-only flag(s) $($net -join ',') change on $k" }
  }
  $null
}
function Flag-Map([string[]]$lines) { $fm = @{}; foreach ($l in $lines) { if ($l -match '^([^=#\s]+)=(.*)$') { $fm[$Matches[1]] = $Matches[2] } }; $fm }
function Set-FlagIn([string[]]$lines, $key, $val) {
  $done = $false
  $o = @($lines | ForEach-Object { if ($_ -match ('^' + [regex]::Escape($key) + '=')) { $done = $true; "$key=$val" } else { $_ } })
  if (-not $done) { $o += "$key=$val" }
  , $o
}
function Flag-Diff([string[]]$a, [string[]]$b) {
  $ma = Flag-Map $a; $mb = Flag-Map $b
  , @(@($ma.Keys) + @($mb.Keys) | Sort-Object -Unique | Where-Object { "$($ma[$_])" -ne "$($mb[$_])" -or $ma.ContainsKey($_) -ne $mb.ContainsKey($_) })
}
function Build-ResetFlags($rd, $k) {
  $tag = $SIDES[$k].Tag
  $src = if ($k -eq 'A' -and ($FlagsHost -or $Flags)) { if ($FlagsHost) { $FlagsHost } else { $Flags } } elseif ($k -ne 'A' -and ($FlagsClient -or $Flags)) { if ($FlagsClient) { $FlagsClient } else { $Flags } } else { "$rd\flags_base_$tag.txt" }
  if (-not (Test-Path -LiteralPath $src)) { Fail "no base flags for $k ($src): this run was not started by this harness version, cold boot needed" }
  $l = @([IO.File]::ReadAllLines($src) | Where-Object { $_ -ne '' })
  if ($src -ne "$rd\flags_base_$tag.txt") { $l = Set-FlagIn $l 'joinmenu' '0' }
  foreach ($kv in (Split-SetArgs $Set)) { if ($kv -notmatch '^([A-Za-z0-9_]+)=(.*)$') { Fail "-Set wants key=value: $kv" }; $l = Set-FlagIn $l $Matches[1] $Matches[2] }
  , $l
}
$N7STAY = 'NOLA n7: host carregou um save \(#\d+\) sem perder passos .*nada a seguir'
function Reset-LineDone($k, $l, $re) {
  if ($re.IsMatch($l)) { return 'world' }
  if ($k -ne 'A' -and $l -match $N7STAY) { return 'stay' }
  $null
}
function Invoke-Reset {
  $rd = Get-CurrentRun; if (-not $rd) { Fail "no current run: run 'harness.ps1 up' first" }
  $s = Read-State $rd; if (-not $s) { Fail "no state.json in $rd" }
  foreach ($k in $KEYS) { if (-not (Get-SideProc $k)) { Fail "$k ($($SIDES[$k].Role)) is not running: use 'harness.ps1 up'" } }
  $t0 = Get-Date
  $plan = @{}
  foreach ($k in $KEYS) {
    $f = Join-Path $SIDES[$k].Bridge 'flags.txt'; Assert-Writable $f
    $cur = @([IO.File]::ReadAllLines($f) | Where-Object { $_ -ne '' }); $new = Build-ResetFlags $rd $k
    $d = Flag-Diff $cur $new; $net = @($d | Where-Object { $NETKEYS -contains $_ })
    if ($net.Count) { Fail "flag(s) $($net -join ',') on $k are read at start only: cold boot needed (harness.ps1 down, then up)" }
    $plan[$k] = @{ F = $f; New = $new; Diff = $d }
  }
  foreach ($k in $KEYS) {
    $p = $plan[$k]
    if ($p.Diff.Count) { [IO.File]::WriteAllText($p.F, (($p.New -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding)); Say "flags swapped live on ${k}: $(($p.Diff | ForEach-Object { $_ + '=' + (Flag-Map $p.New)[$_] }) -join ' ')" } else { Say "flags on ${k}: unchanged" }
    Copy-Item -LiteralPath $p.F "$rd\flags_$($SIDES[$k].Tag).txt" -Force
  }
  $n = [int]$s.resets + 1
  if (-not $NoReload) {
    if ($plan.Values | Where-Object { $_.Diff.Count }) { Start-Sleep -Seconds 2 }
    $sts = @{}; foreach ($k in $KEYS) { $m = Get-Mark $k; $sts[$k] = @{ Pos = $m.Off; Head = $m.Head; Skip = $m.Skip } }
    $script:ClsCache = @{}
    $mp = Resolve-Cls 'A' '@cls:CustomConsoleManagerMP'
    $o = Invoke-S2Dev 'A' @("call $mp XLoadLastSave")
    Say "reset #${n}: host XLoadLastSave: $o"
    $re = New-Object regex ($WorldRegex); $hit = @{}; $lastKey = Get-Date
    while ($hit.Count -lt $KEYS.Count) {
      Check-Frozen
      foreach ($k in $KEYS) { if ($hit.ContainsKey($k)) { continue }; foreach ($l in (Read-NewLines $k $sts[$k])) { $v = Reset-LineDone $k $l $re; if ($v) { $hit[$k] = Get-Date; Say "$k $(if ($v -eq 'stay') { 'stays in world (n7: nothing to follow)' } else { 'in world again' }) after $([int]((Get-Date) - $t0).TotalSeconds) s: $l"; break } } }
      foreach ($k in $KEYS) { Watch-Blocker $k $null; if (-not (Get-SideProc $k)) { Fail "$k died during reset #$n" } }
      if (((Get-Date) - $t0).TotalSeconds -gt $ResetTimeout) { Fail "TIMEOUT: reset #$n world line not seen on $(@($KEYS | Where-Object { -not $hit.ContainsKey($_) }) -join ',') in $ResetTimeout s (games left running)" }
      if (-not $hit.ContainsKey('A') -and ((Get-Date) - $lastKey).TotalSeconds -ge $TAPSECS) { [void](Send-Input 'A' 'tap' @{ Keys = '20' } -NoThrow); $lastKey = Get-Date }
      Start-Sleep -Milliseconds 400
    }
  }
  $secs = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  Set-StateProp $s 'resets' $n; Set-StateProp $s 'last_reset' (Get-Date).ToString('o'); Set-StateProp $s "reset_${n}_secs" $secs
  Write-State $rd $s
  Say "RESET #${n}: $(if ($NoReload) { 'flags only, no reload' } else { 'scenario reloaded' }) in $secs s; run folder $rd"
  if ($n -ge $MaxResets) { Say "note: $n resets on this boot; the next up -Reuse does a cold boot (MaxResets $MaxResets)" }
}
function Cmd-Reset { try { Check-Hold | Out-Null; Invoke-Reset; if ($Day) { Set-DayAll }; if ($Calm) { Run-Calm } } finally { Flush-UpLog } }
function Use-Budget([string]$Who, [string]$Dir, [string]$Kind, [string]$Over) {
  $f = Join-Path $Dir $BUDGET; $lg = Join-Path $Dir 'budget.log'; $n = 0; $bonus = 0
  if (Test-Path -LiteralPath $f) { $t = @(([IO.File]::ReadAllText($f)).Trim() -split '\|'); if ($t[0] -eq $Who -and $t.Count -ge 3) { $n = [int]$t[1]; $bonus = [int]$t[2] } }
  $d = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  if ($n -ge 2 + $bonus) {
    if (-not $Over) { Add-Content -LiteralPath $lg -Value "$d | $Who | $n | REFUSED $Kind"; throw "HARNESS: live budget used ($n/2) for $Who; batch your checks or report PARTIAL" }
    if ($bonus -ge 1) { Add-Content -LiteralPath $lg -Value "$d | $Who | $n | REFUSED $Kind (override already used)"; throw "HARNESS: live budget used ($n/2) for $Who and the one override is spent; report PARTIAL" }
    $bonus = 1
    Add-Content -LiteralPath $lg -Value "$d | $Who | $($n + 1) | OVERBUDGET $Kind | reason: $Over"
  } else { Add-Content -LiteralPath $lg -Value "$d | $Who | $($n + 1) | $Kind" }
  $n++
  [IO.File]::WriteAllText($f, "$Who|$n|$bonus")
}
function Budget-Count([string]$Kind) {
  if ($DryRun) { return }
  $li = Lock-Info; if (-not $li) { return }
  Use-Budget $li.Who $H $Kind $OverBudget
}
function Cmd-Run {
  if (-not $Spec) { Fail 'run <spec>[,<spec2>,...]' }
  $ps = @(@($Spec -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { Read-Spec $_ })
  $pe = 0; foreach ($p in $ps) { if ($p.Errors.Count) { $p.Errors | ForEach-Object { Write-Host $_ }; $pe += $p.Errors.Count } }
  if ($pe) { Fail "specs have $pe parse errors" }
  if (-not ($ps.Count -eq 1 -and $Spec.Trim() -eq 'calm')) { Budget-Count ("run $Spec") }
  if ($Report -and $ps.Count -gt 1) { Fail '-Report takes one spec; several specs write report_<name>_<time>.txt each' }
  $rd = Get-CurrentRun
  if (-not $rd) { if ($DryRun) { $rd = "$H\tmp" } else { Fail "no current run folder: run 'harness.ps1 up' first (or pass -Run <folder>)" } }
  if (-not $DryRun) { [void](Check-Hold); foreach ($k in $KEYS) { if (-not (Get-SideProc $k)) { Say "WARNING: $k ($($SIDES[$k].Role)) is not running" } } }
  $bad = 0; $sum = @(); $tb = Get-Date; $i = 0
  foreach ($p in $ps) {
    if ($i -gt 0 -and -not $DryRun) { if ($NoReload) { Say "next spec without a reload (-NoReload)" } else { Invoke-Reset } }
    $i++; $ts = Get-Date
    $rp = if ($Report) { $Report } else { "$rd\report_$($p.Name)_$(Get-Date -Format 'HHmmss').txt" }
    $r = Invoke-Spec $p $rd $rp
    Get-Content -LiteralPath $r.Report | Write-Host
    $bad += $r.Bad; $sum += ('{0,-30} {1,-5} {2,5} s  {3}' -f $p.Name, $r.Verdict, [int]((Get-Date) - $ts).TotalSeconds, $r.Report)
  }
  if ($ps.Count -gt 1) { Write-Host "BATCH $($ps.Count) specs in $([int]((Get-Date) - $tb).TotalSeconds) s (one boot):"; $sum | ForEach-Object { Write-Host "  $_" } }
  exit $(if ($bad) { 1 } else { 0 })
}
function Cmd-Down { if (-not $Cold) { $wq = @(Read-Queue); if ($wq.Count -gt 0) { Say "down skipped: $($wq.Count) worker(s) queued on pair $Pair ($(($wq | ForEach-Object Name) -join ', ')); the pair stays up so the next up reuses it. Use 'down -Cold' to really stop"; return } }; Invoke-Down }
function Invoke-Down {
  $rd = Get-CurrentRun; if (-not $rd) { $rd = New-RunDir }
  [void](Stop-CrashReporters)
  $start = (Get-Date).AddHours(-3)
  if (Test-Path -LiteralPath "$rd\state.json") { $s = Get-Content -LiteralPath "$rd\state.json" -Raw | ConvertFrom-Json; if ($s.start) { $start = [datetime]$s.start } }
  $sum = New-Object System.Collections.ArrayList
  foreach ($k in $KEYS[($KEYS.Count - 1)..0]) { $r = if ($Kill) { Stop-Side $k -Force } else { Stop-Side $k }; [void]$sum.Add("$k ($($SIDES[$k].Role)): $r"); Say "$k ($($SIDES[$k].Role)): $r" }
  foreach ($k in $KEYS) {
    $s = $SIDES[$k]; $l = LogPath $k
    if (Test-Path -LiteralPath $l) { Copy-Item -LiteralPath $l "$rd\$($s.Tag)_UE4SS.log" -Force; [void]$sum.Add("log $rd\$($s.Tag)_UE4SS.log") }
    $el = EngLog $k; if ((Test-Path -LiteralPath $el) -and (Get-Item -LiteralPath $el).LastWriteTime -ge $start) { Copy-Item -LiteralPath $el "$rd\$($s.Tag)_engine.log" -Force }
    New-Item -ItemType Directory -Force "$rd\bridge_$($s.Tag)" | Out-Null
    foreach ($f in 'flags.txt', 'state.json', 's2cmd_out.txt') { $p = Join-Path $s.Bridge $f; if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p "$rd\bridge_$($s.Tag)\$f" -Force } }
    $cd = "$env:LOCALAPPDATA\Stalker2\$($s.Saved)\Crashes"
    foreach ($c in @(Get-ChildItem -LiteralPath $cd -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -ge $start })) {
      New-Item -ItemType Directory -Force "$rd\crashes" | Out-Null
      Copy-Item -LiteralPath $c.FullName "$rd\crashes\$($s.Tag)_$($c.Name)" -Recurse -Force
      [void]$sum.Add("CRASH $($s.Tag): $($c.Name)")
    }
  }
  Restore-FlagsBackup
  [void](Stop-CrashReporters)
  $dllErr = $null
  try { $nd = Restore-DllBackup; if ($nd) { [void]$sum.Add("main.dll restored and md5 verified on $nd root(s)") } } catch { $dllErr = $_.Exception.Message; [void]$sum.Add("DLL RESTORE FAILED: $dllErr") }
  try { $bt = Get-BootText $rd; [IO.File]::WriteAllLines("$rd\boot.txt", [string[]]$bt) } catch { [void]$sum.Add("boot timeline failed: $($_.Exception.Message)") }
  [IO.File]::WriteAllLines("$rd\down.txt", [string[]]$sum)
  if (Test-Path -LiteralPath $CURRENT) { Remove-Item -LiteralPath $CURRENT -Force }
  Say "DOWN: collected into $rd"
  if ($dllErr) { Fail $dllErr }
}
function Cmd-Status {
  foreach ($k in $KEYS) {
    $p = Get-SideProc $k; $s = $SIDES[$k]
    $ping = if ($p) { Invoke-S2Dev $k @('ping') } else { '-' }
    Write-Host ("{0} {1,-6} {2,-18} pid={3,-6} s2dev:{4} log={5}" -f $k, $s.Role, $s.Root, $(if ($p) { $p.ProcessId } else { '-' }), (Short $ping 40), (LogPath $k))
  }
  Write-Host "current run: $(Get-CurrentRun)"
}
function Cmd-List {
  $ta = 0; $tm = 0
  foreach ($f in Get-ChildItem -LiteralPath "$H\specs" -Filter *.txt | Sort-Object Name) {
    $p = Read-Spec $f.FullName; $c = Count-Spec $p; $ta += $c.Auto; $tm += $c.Manual
    Write-Host ("{0,-34} steps={1,3} auto={2,3} manual={3,3} errors={4}" -f $f.Name, $p.Steps.Count, $c.Auto, $c.Manual, $p.Errors.Count)
    $p.Errors | ForEach-Object { Write-Host "   $_" }
  }
  Write-Host "TOTAL auto=$ta manual=$tm"
}

function Cmd-Selftest {
  $out = "$H\selftest"; New-Item -ItemType Directory -Force $out | Out-Null
  $res = New-Object System.Collections.ArrayList
  function Chk($name, $ok, $detail) { [void]$res.Add([ordered]@{ Name = $name; Ok = [bool]$ok; Detail = "" + $detail }); Write-Host ("{0,-5} {1} {2}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $name, (Short $detail 150)) }
  $fxC = "$H\fixtures\client_20261017_2345.log"; $fxH = "$H\fixtures\host_20261017_2347.log"

  foreach ($f in Get-ChildItem -LiteralPath "$H\specs" -Filter *.txt | Sort-Object Name) {
    $p = Read-Spec $f.FullName; $c = Count-Spec $p
    Chk "parse $($f.Name)" ($p.Errors.Count -eq 0 -and $p.Steps.Count -gt 0) ("steps=$($p.Steps.Count) auto=$($c.Auto) manual=$($c.Manual) " + ($p.Errors -join '; '))
  }
  $bad = @('expect C foo within 3', 'expect A (unclosed within 3', 'expect A foo', 'expect_not A foo within 3', 'wait soon', 'frobnicate A x', 'key A NOSUCHKEY', 'tp A near C 100', 'cfg A onlykey', 'quit A extra', 'manual onlyid', 's2dev B call pawn X => (bad')
  foreach ($b in $bad) { $p = Parse-Spec @($b) 'neg'; Chk "parse rejects: $b" ($p.Errors.Count -eq 1 -and $p.Steps.Count -eq 0) ($p.Errors -join '; ') }
  $good = @('expect B "LIFE: CAIDO #\d+ \(hp (?<hp>[\d.]+) <= 15\)" within 5', 'expect_not A /PEER LEFT/ during 2.5', 'con B s2q E E01_MQ01_OnSignalReceived_4', 'dev A flags qevent => qevent=1', 's2dev B call @cls:CustomConsoleManagerRK XCreateItemInInventoryByID Medkit 0 2 1', 'tp A near B 150', 'spawn A GeneralNPC_Bandit_Stormtrooper 3 near B 15', 'key B F 2000', 'tap A ESC SPACE CTRL+S', 'mark start', 'manual T3 user sees the text')
  $p = Parse-Spec $good 'pos'
  Chk "parse accepts $($good.Count) good lines" ($p.Errors.Count -eq 0 -and $p.Steps.Count -eq $good.Count) ($p.Errors -join '; ')
  $perr = $null; $ptok = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$ptok, [ref]$perr)
  Chk 'harness.ps1 parses with zero errors' ($perr.Count -eq 0) (($perr | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ')
  $ftmp = "$out\flagstest"; if (Test-Path -LiteralPath $ftmp) { Remove-Item -LiteralPath $ftmp -Recurse -Force }
  New-Item -ItemType Directory -Force "$ftmp\A", "$ftmp\B", "$ftmp\E" | Out-Null
  $sv = @{ BA = $SIDES.A.Bridge; BB = $SIDES.B.Bridge; BE = $SIDES.E.Bridge; AL = $ALLOWED; FB = $FLAGSBAK; KEYS = $KEYS }
  $SIDES.A.Bridge = "$ftmp\A"; $SIDES.B.Bridge = "$ftmp\B"; $SIDES.E.Bridge = "$ftmp\E"; $ALLOWED = @("$ftmp\"); $FLAGSBAK = "$ftmp\bak"; $KEYS = @('A', 'B', 'E')
  try {
    foreach ($k in 'A', 'B', 'E') { [IO.File]::WriteAllText("$ftmp\$k\flags.txt", "orig=$k`r`nnetlisten=1`r`n") }
    Save-FlagsBackup
    foreach ($k in 'A', 'B', 'E') { Set-FlagLine $k 'joinmenu' '0'; Set-FlagLine $k 'netlisten' '9' }
    $mid = ([IO.File]::ReadAllText("$ftmp\A\flags.txt") -match 'joinmenu=0')
    Save-FlagsBackup
    Restore-FlagsBackup
    $okr = $true; foreach ($k in 'A', 'B', 'E') { if ([IO.File]::ReadAllText("$ftmp\$k\flags.txt") -ne "orig=$k`r`nnetlisten=1`r`n") { $okr = $false } }
    Chk 'flags backup/restore: additions reverted to the pre-run state' ($mid -and $okr -and -not (Test-Path -LiteralPath "$ftmp\bak\host.flags")) "mid=$mid restored=$okr"
  } finally { $SIDES.A.Bridge = $sv.BA; $SIDES.B.Bridge = $sv.BB; $SIDES.E.Bridge = $sv.BE; $ALLOWED = $sv.AL; $FLAGSBAK = $sv.FB; $KEYS = $sv.KEYS }
  $sp = Split-SetArgs @('a=1,b=2'); Chk 'Set split: a=1,b=2 -> 2 lines' ($sp.Count -eq 2 -and $sp[0] -eq 'a=1' -and $sp[1] -eq 'b=2') ($sp -join '|')
  $sp = Split-SetArgs @('a=1', 'b=2,c=3'); Chk 'Set split: array plus comma item' ($sp.Count -eq 3 -and $sp[2] -eq 'c=3') ($sp -join '|')
  $sp = Split-SetArgs @('list=x,y,z,k=5'); Chk 'Set split: value with commas stays whole' ($sp.Count -eq 2 -and $sp[0] -eq 'list=x,y,z' -and $sp[1] -eq 'k=5') ($sp -join '|')
  $sp = Split-SetArgs @('only=1'); Chk 'Set split: single item' ($sp.Count -eq 1 -and $sp[0] -eq 'only=1') ($sp -join '|')
  $sl = Split-SetArgs @('joinmenu=0'); $sn = 0; $sk = ''; foreach ($kv in $sl) { $sn++; if ($kv -match '^([A-Za-z0-9_]+)=(.*)$') { $sk = $Matches[1] } }; Chk 'Set loop: one item, key parsed' ($sn -eq 1 -and $sk -eq 'joinmenu') "n=$sn key=$sk"
  $mt = "$out\mirrortest"; if (Test-Path -LiteralPath $mt) { Remove-Item -LiteralPath $mt -Recurse -Force }
  New-Item -ItemType Directory -Force "$mt\src", "$mt\dst\old" | Out-Null
  [IO.File]::WriteAllText("$mt\src\keep.sav", 'k'); [IO.File]::WriteAllText("$mt\dst\stale1.sav", 's'); [IO.File]::WriteAllText("$mt\dst\old\stale2.sav", 's')
  $mlog = @(Mirror-Dir "$mt\src" "$mt\dst" 6>&1 | ForEach-Object { "$_" })
  Chk 'mirror logs every removed file' (($mlog -join "`n") -match 'stale1\.sav' -and ($mlog -join "`n") -match 'stale2\.sav' -and (Test-Path -LiteralPath "$mt\dst\keep.sav") -and -not (Test-Path -LiteralPath "$mt\dst\stale1.sav")) ($mlog -join ' | ')
  $stg = @(Get-SaveTargets); $stw = $true; foreach ($x in $stg) { try { Assert-Writable "$x\x" } catch { $stw = $false } }
  Chk 'save restore targets STEAM and NULL SaveGames of the host (the game reads NULL with Steam off), all writable' ($stw -and ($stg -match '\\Saved_host2\\NULL\\SaveGames$') -and ($stg -match '\\Saved_host2\\STEAM\\SaveGames$')) ($stg -join ' | ')
  Chk 'Stop-CrashReporters runs clean' ((Stop-CrashReporters) -ge 0) ''
  Chk 'regex unquoted (quotes)' ($p.Steps[0].Rx -eq 'LIFE: CAIDO #\d+ \(hp (?<hp>[\d.]+) <= 15\)') $p.Steps[0].Rx
  Chk 'regex unquoted (slashes) + during' ($p.Steps[1].Rx -eq 'PEER LEFT' -and $p.Steps[1].Secs -eq 2.5) "$($p.Steps[1].Rx) $($p.Steps[1].Secs)"
  Chk 'assert split' ($p.Steps[3].Args[0] -eq 'flags qevent' -and $p.Steps[3].Assert -eq 'qevent=1') "$($p.Steps[3].Args[0]) | $($p.Steps[3].Assert)"
  Chk 'key name to vk' ($p.Steps[7].Args[0] -eq '46' -and $p.Steps[7].Args[1] -eq 2000) ($p.Steps[7].Args -join ',')
  Chk 'tap chord' (($p.Steps[8].Args -join ' ') -eq '1B 20 11+53') ($p.Steps[8].Args -join ' ')

  $dt = "$out\dlltest"; if (Test-Path -LiteralPath $dt) { Remove-Item -LiteralPath $dt -Recurse -Force }
  New-Item -ItemType Directory -Force $dt | Out-Null
  $svd = @{ AL = $ALLOWED; BAK = $DLLBAK; BF = $BASEFILE; KEYS = $KEYS; MO = $script:ModsDirOverride; FB = $FLAGSBAK }
  $ALLOWED = @("$dt\"); $DLLBAK = "$dt\dllbak"; $BASEFILE = "$dt\baseline.txt"; $FLAGSBAK = "$dt\noflagsbak"; $KEYS = @('A', 'B', 'E')
  $script:ModsDirOverride = @{ A = "$dt\modsA"; B = "$dt\modsB"; E = "$dt\modsE" }
  function Reset-DllFixture {
    if (Test-Path -LiteralPath $DLLBAK) { Remove-Item -LiteralPath $DLLBAK -Recurse -Force }
    if (Test-Path -LiteralPath $BASEFILE) { Remove-Item -LiteralPath $BASEFILE -Force }
    foreach ($k in 'A', 'B', 'E') { $t = Get-DllTarget $k; New-Item -ItemType Directory -Force (Split-Path $t) | Out-Null; [IO.File]::WriteAllText($t, "ORIGINAL-$k-" + ('x' * 50)) }
    [IO.File]::WriteAllText("$dt\test1.dll", 'TEST-ONE-' + ('y' * 60)); [IO.File]::WriteAllText("$dt\test2.dll", 'TEST-TWO-' + ('z' * 60))
  }
  function DllMd5s { ($KEYS | ForEach-Object { Md5Of (Get-DllTarget $_) }) -join ',' }
  try {
    Reset-DllFixture
    $orig = DllMd5s; $t1 = Md5Of "$dt\test1.dll"
    Install-Dll "$dt\test1.dll" @('A', 'B', 'E')
    $inst = DllMd5s
    Chk 'dll: up -Dll installs the test DLL on A, B and E' ($inst -eq "$t1,$t1,$t1") $inst
    $bakOk = $true; $oi = 0; foreach ($k in 'A', 'B', 'E') { $b = "$DLLBAK\$($SIDES[$k].Tag).main.dll"; if (-not (Test-Path -LiteralPath $b) -or (Md5Of $b) -ne ($orig -split ',')[$oi]) { $bakOk = $false }; $oi++ }
    Chk 'dll: the original of every root is saved outside the Mods folders (md5 of each backup = original)' ($bakOk -and (Test-Path -LiteralPath "$DLLBAK\manifest.json") -and -not ("$DLLBAK" -like "$dt\mods*")) "backups ok=$bakOk"
    Install-Dll "$dt\test2.dll" @('A', 'B', 'E')
    $bakOk2 = $true; $oi = 0; foreach ($k in 'A', 'B', 'E') { if ((Md5Of "$DLLBAK\$($SIDES[$k].Tag).main.dll") -ne ($orig -split ',')[$oi]) { $bakOk2 = $false }; $oi++ }
    Chk 'dll: a second up -Dll without down keeps the true original (never saves a test DLL as the original)' ($bakOk2 -and (DllMd5s) -eq (((Md5Of "$dt\test2.dll"), (Md5Of "$dt\test2.dll"), (Md5Of "$dt\test2.dll")) -join ',')) "bak ok=$bakOk2"
    $n = Restore-DllBackup
    Chk 'dll: down restores A, B and E to the original md5 and removes the backups' ($n -eq 3 -and (DllMd5s) -eq $orig -and -not (Test-Path -LiteralPath "$DLLBAK\manifest.json") -and -not (Test-Path -LiteralPath "$DLLBAK\host.main.dll")) "restored=$n now=$(DllMd5s) want=$orig"
    Chk 'dll: down with nothing pending does nothing' ((Restore-DllBackup) -eq 0 -and (DllMd5s) -eq $orig) ''

    $caught = $null; try { Run-UpGuarded { Install-Dll "$dt\test1.dll" @('A', 'B', 'E'); throw 'boom in up' } } catch { $caught = $_.Exception.Message }
    Chk 'dll: a failed up restores the originals and rethrows' ($caught -eq 'boom in up' -and (DllMd5s) -eq $orig -and -not (Test-Path -LiteralPath "$DLLBAK\manifest.json")) "caught=$caught now=$(DllMd5s)"

    $caught = $null; try { Install-Dll (Get-DllTarget 'B') @('A', 'B') } catch { $caught = $_.Exception.Message }
    Chk 'dll: -Dll equal to a root''s live main.dll is refused, nothing touched' ($caught -like '*live main.dll of B*' -and (DllMd5s) -eq $orig -and -not (Test-Path -LiteralPath "$DLLBAK\manifest.json")) $caught
    $caught = $null; try { Put-File (Get-DllTarget 'A') (Get-DllTarget 'A') } catch { $caught = $_.Exception.Message }
    Chk 'dll: Put-File refuses src = dst (the source is never deleted)' ($caught -like '*same file*' -and (Test-Path -LiteralPath (Get-DllTarget 'A'))) $caught

    [IO.File]::WriteAllLines($BASEFILE, [string[]]@(($orig -split ',')[0]))
    $caught = $null; try { Install-Dll "$dt\test1.dll" @('A', 'B') } catch { $caught = $_.Exception.Message }
    Chk 'dll: an original that is not the baseline md5 is refused (leftover test DLL), nothing touched' ($caught -like '*not the baseline*' -and (DllMd5s) -eq $orig -and -not (Test-Path -LiteralPath "$DLLBAK\manifest.json")) $caught
    Set-Variable -Name AcceptBase -Value ([switch]$true) -Scope Script
    try { Install-Dll "$dt\test1.dll" @('A', 'B') } finally { Set-Variable -Name AcceptBase -Value ([switch]$false) -Scope Script }
    [void](Restore-DllBackup)
    Chk '-AcceptBase installs anyway and the restore still brings the originals back' ((DllMd5s) -eq $orig) (DllMd5s)

    Reset-DllFixture; $orig = DllMd5s
    Remove-Item -LiteralPath (Get-DllTarget 'E') -Force
    Install-Dll "$dt\test1.dll" @('A', 'E')
    [void](Restore-DllBackup)
    Chk 'dll: a root with no main.dll before the run has none after the restore' (-not (Test-Path -LiteralPath (Get-DllTarget 'E')) -and (Md5Of (Get-DllTarget 'A')) -eq ($orig -split ',')[0]) ''

    Reset-DllFixture; $orig = DllMd5s
    Install-Dll "$dt\test1.dll" @('A', 'B', 'E')
    $mf = Get-Content -LiteralPath "$DLLBAK\manifest.json" -Raw | ConvertFrom-Json
    [IO.File]::WriteAllText("$DLLBAK\client.main.dll", 'tampered')
    $caught = $null; try { [void](Restore-DllBackup) } catch { $caught = $_.Exception.Message }
    Chk 'dll: a damaged backup copy fails the restore loudly (md5 check) and keeps the manifest' ($caught -like '*incomplete*no longer has md5*' -and (Test-Path -LiteralPath "$DLLBAK\manifest.json")) $caught
    [IO.File]::WriteAllText("$DLLBAK\client.main.dll", "ORIGINAL-B-" + ('x' * 50))
    $lock = [IO.File]::Open((Get-DllTarget 'E'), 'Open', 'Read', 'None')
    $caught = $null; try { [void](Restore-DllBackup) } catch { $caught = $_.Exception.Message } finally { $lock.Dispose() }
    Chk 'dll: a locked target (game still loaded) fails the restore and keeps the backups for a retry' ($caught -like '*incomplete*' -and (Test-Path -LiteralPath "$DLLBAK\manifest.json")) $caught
    $n = Restore-DllBackup
    Chk 'dll: the retry after the lock is gone restores and verifies all three' ($n -eq 3 -and (DllMd5s) -eq $orig) "n=$n"
  } finally { $ALLOWED = $svd.AL; $DLLBAK = $svd.BAK; $BASEFILE = $svd.BF; $FLAGSBAK = $svd.FB; $KEYS = $svd.KEYS; $script:ModsDirOverride = $svd.MO }

  $pe = @('mouse B x', 'focus B extra', 'mouse Z 1'); foreach ($b in $pe) { $pp = Parse-Spec @($b) 'neg'; Chk "parse rejects: $b" ($pp.Errors.Count -eq 1 -and $pp.Steps.Count -eq 0) ($pp.Errors -join '; ') }
  $pp = Parse-Spec @('mouse A -3 2', 'mouse B 5', 'focus E') 'pos'
  Chk 'parse accepts mouse and focus' ($pp.Errors.Count -eq 0 -and $pp.Steps.Count -eq 3 -and $pp.Steps[0].Args[0] -eq -3 -and $pp.Steps[0].Args[1] -eq 2 -and $pp.Steps[1].Args[1] -eq 0 -and $pp.Steps[2].Side -eq 'E') ($pp.Errors -join '; ')

  Chk 'profile: lite = 640x360, -nosound, lite.txt autoexec that exists' (($PROFILES.lite.Args -join ' ') -eq '-windowed -ResX=640 -ResY=360 -nosound' -and $PROFILES.lite.Res -eq '640x360w' -and (Test-Path -LiteralPath $PROFILES.lite.Autoexec)) ($PROFILES.lite.Args -join ' ')
  Chk 'profile: normal keeps the old launch args and lowspec autoexec' (($PROFILES.normal.Args -join ' ') -eq '-windowed -ResX=960 -ResY=540' -and $PROFILES.normal.Autoexec -eq "$PSScriptRoot\lowspec.txt") ($PROFILES.normal.Args -join ' ')
  $ss = "${function:Launch-Side}"; $ww = "${function:Wait-Worlds}"
  Chk 'launch: every instance gets -unattended, the blocker watchdog and the popup confirm' ($ss -match "'-unattended'" -and $ww -match 'Watch-Blocker' -and $ww -match 'Confirm-Popup' -and "${function:Start-Side}" -match 'Wait-Worlds' -and "${function:Check-Alive}" -match 'Watch-Blocker' -and "${function:Wait-Line}" -match 'Watch-Blocker') ''
  $ub = "${function:Cmd-Up-Body}"
  $hs = "${function:Invoke-HotSwap}"; $tr = "${function:Test-Reuse}"; $cu = "${function:Cmd-Up}"; $cr = "${function:Cmd-Reset}"
  Chk 'hot: up -Reuse -Dll tries hot reload only when the sole blocker is the DLL swap, then resets' ($ub -match 'Test-Reuse -IgnoreDll' -and $ub -match 'Invoke-HotSwap' -and $tr -match 'IgnoreDll') ''
  Chk 'hot: release DLLs (no nola_hot_start) and failed reloads fall back to the cold boot' ($hs -match 'release build' -and $hs -match 'cold boot' -and $hs -match 'return \$false') ''
  Chk 'hot: state.json gets hot_md5 and Test-Reuse compares it against -Dll' ($hs -match "'hot_md5'" -and $tr -match 'hot_md5') ''
  Chk 'hot: Test-HotDll tells dev from release by the export' ((Test-HotDll "$out/none_x.dll") -eq $false) ''
  Chk 'log: up and reset flush the console output to up.log, -Calm runs spec calm' ($cu -match 'Flush-UpLog' -and $cr -match 'Flush-UpLog' -and $cu -match 'Run-Calm' -and $cr -match 'Run-Calm' -and $ub -match 'REUSE not possible') ''

  Chk 'up: host and client launch in parallel (client Continue gated on the host world), -Serial keeps the old order' ($ub -match "\`$cb\.Gate = 'A'" -and $ub -match 'Wait-Worlds @\(\$ca, \$cb\)' -and $ww -match '\$c\.Gate' -and $ub -match 'elseif \(\$Serial\)') ''
  Chk 'up: joinmenu=0 is written before -Set (so -Set joinmenu=1 still wins)' ($ub.IndexOf("Set-FlagLine `$k 'joinmenu' '0'") -gt 0 -and $ub.IndexOf("Set-FlagLine `$k 'joinmenu' '0'") -lt $ub.IndexOf('$setList = Split-SetArgs $Set')) ''
  $rf = "$H\fixtures\reset_ft1"
  if (Test-Path -LiteralPath $rf) {
    $wre = New-Object regex ($WorldRegex)
    $cv = @(Get-Content -LiteralPath "$rf\client_reset.log" | ForEach-Object { Reset-LineDone 'B' $_ $wre } | Where-Object { $_ })
    $hv = @(Get-Content -LiteralPath "$rf\host_reset.log" | ForEach-Object { Reset-LineDone 'A' $_ $wre } | Where-Object { $_ })
    $hs = @(Get-Content -LiteralPath "$rf\host_reset.log" | ForEach-Object { if ($_ -match $N7STAY) { 'x' } })
    Chk 'reset: FT1 live log, a client whose n7 has nothing to follow counts as done (stay), the host needs its world line' ($cv.Count -ge 1 -and $cv[0] -eq 'stay' -and $hv.Count -ge 1 -and $hv[0] -eq 'world' -and $hs.Count -eq 0) "client=$($cv -join ',') host=$($hv -join ',')"
    Chk 'reset: the n7 stay line never ends the wait on the host' ($null -eq (Reset-LineDone 'A' (Get-Content -LiteralPath "$rf\client_reset.log" | Where-Object { $_ -match $N7STAY } | Select-Object -First 1) $wre)) ''
  }
  $bf = "$H\fixtures\boot_hl1"
  if (Test-Path -LiteralPath $bf) {
    $bt = Get-BootText $bf; $bj = $bt -join "`n"
    Chk 'boot timeline: HL1 fixture gives PEER UP at 253.8 s, host world 114 s, client world 256.6 s' ($bj -match 'SUMMARY peer_up 253\.8 s; world host 114 s, client 256\.6 s') (@($bt)[-1])
    Chk 'boot timeline: every phase found for both sides (process, ue4ss, engine_init, mods, popup_gone, menu, load, world, peer_up)' ((@('process', 'ue4ss', 'engine_init', 'mods', 'popup_gone', 'menu', 'load', 'world', 'peer_up') | Where-Object { ([regex]::Matches($bj, "(?m)^(host|client)\s+$_\s")).Count -ne 2 }).Count -eq 0) ''
    Chk 'boot timeline: menu = prototypes end (host 12:58:00.8 after 43.5 s), popup_gone = its start' ($bj -match 'host\s+menu\s+12:58:00\.8' -and $bj -match 'host\s+popup_gone\s+12:57:17\.3') ''
  } else { Chk 'boot timeline fixture present' $false $bf }
  $fd = Flag-Diff @('a=1', 'netlisten=7799', 'c=0') @('a=2', 'netlisten=7799', 'c=0', 'b=3')
  Chk 'reset: Flag-Diff lists changed and added keys only' (($fd -join ',') -eq 'a,b') ($fd -join ',')
  Chk 'reset: start-only keys (net*, joinmenu, maxclients) force a cold boot' ($NETKEYS -contains 'netlisten' -and $NETKEYS -contains 'joinmenu' -and $NETKEYS -contains 'maxclients' -and -not ($NETKEYS -contains 'qevent')) ''
  $rt = "$out\resettest"; if (Test-Path -LiteralPath $rt) { Remove-Item -LiteralPath $rt -Recurse -Force }; New-Item -ItemType Directory -Force $rt | Out-Null
  [IO.File]::WriteAllLines("$rt\flags_base_host.txt", [string[]]@('qevent=1', 'joinmenu=0', 'netlisten=7799'))
  $svS = $Set; Set-Variable -Name Set -Value @('qevent=0,newk=5') -Scope Script
  try { $bl = Build-ResetFlags $rt 'A' } finally { Set-Variable -Name Set -Value $svS -Scope Script }
  Chk 'reset: flags = run base (joinmenu=0 kept) + this call''s -Set' (($bl -join ',') -eq 'qevent=0,joinmenu=0,netlisten=7799,newk=5') ($bl -join ',')
  $svL = @{ L = $LOCK; Q = $QUEUE; G = $LOCKLOG }
  $LOCK = "$rt\pair2.lock"; $QUEUE = "$rt\pair2.queue"; $LOCKLOG = "$rt\lock.log"
  try {
    $r1 = Lock-Try 'W1'; $r2 = Lock-Try 'W2'; $r3 = Lock-Try 'W3'
    Chk 'lock: free lock taken by the first caller, the next two queue in order' ($r1.Got -and $r1.New -and -not $r2.Got -and $r2.Pos -eq 1 -and -not $r3.Got -and $r3.Pos -eq 2 -and (Lock-Info).Who -eq 'W1') "W1=$($r1.Got) W2 pos $($r2.Pos) W3 pos $($r3.Pos)"
    $c = $null; try { Unlock-Pair 'W2' } catch { $c = $_.Exception.Message }
    Chk 'lock: unlock by a worker that does not hold it is refused (never steal) and the lock stays' ($c -like '*never remove*' -and (Lock-Info).Who -eq 'W1') $c
    Unlock-Pair 'W1' | Out-Null
    $r3b = Lock-Try 'W3'; $r2b = Lock-Try 'W2'
    Chk 'lock: after the release the queue head (W2) gets it, W3 (second) does not jump the queue' (-not $r3b.Got -and $r2b.Got -and (Lock-Info).Who -eq 'W2' -and @(Read-Queue).Count -eq 1) "W3=$($r3b.Got) W2=$($r2b.Got)"
    $q = @(Read-Queue); $q[0].Seen = (Get-Date).AddMinutes(-($QSTALE + 1)); Write-Queue $q
    [void](Lock-Try 'W4')
    Chk 'lock: a queue entry not refreshed for QSTALE min is dropped and logged' ((@(Read-Queue | ForEach-Object { $_.Name }) -join ',') -eq 'W4' -and ((Get-Content -LiteralPath $LOCKLOG -Raw) -match 'dropped W3')) (@(Read-Queue | ForEach-Object { $_.Name }) -join ',')
    [IO.File]::WriteAllText($LOCK, "OLD $((Get-Date).AddMinutes(-41).ToString('o'))")
    [void](Check-Hold 6>$null); [void](Check-Hold 6>$null)
    $wl = @(Get-Content -LiteralPath $LOCKLOG | Where-Object { $_ -match 'WARNING HOLD OLD' })
    Chk 'lock: a hold over MAXHOLD min is logged as a WARNING once (no repeat within 5 min)' ($wl.Count -eq 1 -and $wl[0] -match '4[01](\.\d)? min > 20 min') ($wl -join ' | ')
    Remove-Item -LiteralPath $LOCK, $QUEUE, "$LOCK.cwd" -Force -ErrorAction SilentlyContinue
    $r5 = Lock-Try 'W5'; $cw1 = Test-Path -LiteralPath "$LOCK.cwd"; $cw1v = if ($cw1) { ([IO.File]::ReadAllText("$LOCK.cwd")).Trim() } else { '' }
    Unlock-Pair 'W5' | Out-Null
    $src = [IO.File]::ReadAllText($PSCommandPath)
    Chk 'lock: the holder folder is recorded in .cwd, removed on unlock, and a guard blocks pair commands from another folder' ($r5.Got -and $cw1 -and $cw1v -eq (Get-Location).Path -and -not (Test-Path -LiteralPath "$LOCK.cwd") -and $src -match "is held by .* from .*not from this session") "cwd=$cw1v"
  } finally { $LOCK = $svL.L; $QUEUE = $svL.Q; $LOCKLOG = $svL.G }
  if (-not (Get-SideProc 'A')) { $c0 = Get-Date; $cp = Confirm-Popup 'A'; Chk 'popup: Confirm-Popup with no game answers nothing and returns fast' ($null -eq $cp -and ((Get-Date) - $c0).TotalSeconds -lt 15) "$([int]((Get-Date) - $c0).TotalSeconds) s" }
  if ($NoWinTests) { Say 'blocker watchdog tests skipped (-NoWinTests)' } else {
    $bd = "$out\blocker"; if (Test-Path -LiteralPath $bd) { Remove-Item -LiteralPath $bd -Recurse -Force }
    New-Item -ItemType Directory -Force $bd | Out-Null
    function BoxProc($text, $res) { $c = "Add-Type -AssemblyName System.Windows.Forms; `$r = [System.Windows.Forms.MessageBox]::Show('$text', 'Message', 'YesNo'); Set-Content -LiteralPath '$res' -Value `$r"; $bp = Start-Process powershell -ArgumentList @('-NoProfile', '-Command', $c) -PassThru -WindowStyle Hidden; for ($i = 0; $i -lt 40 -and -not (Get-GameBlocker $bp.Id).Count; $i++) { Start-Sleep -Milliseconds 250 }; $bp }
    $bp = BoxProc 'Crash detected during the previous launch. Do you want to skip custom mods during this launch?' "$bd\skip.txt"
    $r = Resolve-GameBlocker $bp.Id $bd; [void]$bp.WaitForExit(10000)
    Chk 'blocker: the skip-mods Message box is answered No and the process lives on' ($r.Action -eq 'answered' -and (Test-Path -LiteralPath "$bd\skip.txt") -and ((Get-Content -LiteralPath "$bd\skip.txt") -eq 'No')) "$($r.Action) $($r.Text)"
    Start-Sleep -Seconds 1
    $bp = BoxProc 'Fatal error!' "$bd\fatal.txt"
    $sv = $script:BlockDir; $script:BlockDir = $bd; $caught = ''
    try { Watch-Blocker 'A' $bp.Id } catch { $caught = "$($_.Exception.Message)" } finally { $script:BlockDir = $sv; $script:Alive['A'] = $false }
    [void]$bp.WaitForExit(10000)
    Chk 'blocker: any other Message box throws CRASH, kills the process, saves text and png' ($caught -like 'CRASH:*Fatal error!*' -and $bp.HasExited -and -not (Test-Path -LiteralPath "$bd\fatal.txt") -and @(Get-ChildItem -LiteralPath $bd -Filter 'blocker_*.txt').Count -ge 1 -and @(Get-ChildItem -LiteralPath $bd -Filter 'blocker_*.png').Count -ge 1) $caught
    Chk 'blocker: no window means no action' ($null -eq (Resolve-GameBlocker $PID $bd)) ''
  }
  if ($NoWinTests) { Say 'window routing tests skipped (-NoWinTests)' } else {
    $wd = "$out\wintest"; if (Test-Path -LiteralPath $wd) { Remove-Item -LiteralPath $wd -Recurse -Force }
    New-Item -ItemType Directory -Force $wd | Out-Null
    $kw = Join-Path $PSScriptRoot 'keywin.ps1'; $wp = @{}; $title = 'Stalker2-Win64-Shipping_selftest'; $xi = 0
    function WinLog($k) { $f = "$wd\$k.log"; if (-not (Test-Path -LiteralPath $f)) { return , @() }; $r = @(); foreach ($l in [IO.File]::ReadAllLines($f)) { $m = [regex]::Match($l, '^(\d+) ([DUM]) (\S+)'); if ($m.Success) { $r += [pscustomobject]@{ T = [int]$m.Groups[1].Value; D = $m.Groups[2].Value; V = $m.Groups[3].Value } } }; , $r }
    function Downs($k) { $wl = WinLog $k; @($wl | Where-Object { $_.D -eq 'D' -and $_.V -ne '10' } | ForEach-Object { $_.V }) -join ' ' }
    function Run1($line) { $pp = Parse-Spec @($line) 'w'; if ($pp.Errors.Count) { throw ($pp.Errors -join '; ') }; Do-Step $pp.Steps[0] $out }
    $script:ProcOverride = $null
    try {
      foreach ($k in 'A', 'B', 'E') { $wp[$k] = Start-Process powershell -WindowStyle Normal -PassThru -ArgumentList '-NoProfile', '-STA', '-File', $kw, '-Log', "$wd\$k.log", '-Title', $title, '-X', (40 + 140 * $xi), '-Y', 60; $xi++ }
      $ready = $false; for ($i = 0; $i -lt 60 -and -not $ready; $i++) { Start-Sleep -Milliseconds 500; $ready = (@('A', 'B', 'E' | Where-Object { (Test-Path -LiteralPath "$wd\$_.log") -and ([IO.File]::ReadAllText("$wd\$_.log") -match 'READY') })).Count -eq 3 }
      $titles = @('A', 'B', 'E' | ForEach-Object { (Get-Process -Id $wp[$_].Id).MainWindowTitle } | Select-Object -Unique)
      Chk 'win: three test windows are up and share the same title' ($ready -and $titles.Count -eq 1 -and $titles[0] -eq $title) "ready=$ready titles=$($titles -join '|')"
      $script:ProcOverride = @{ A = $wp.A.Id; B = $wp.B.Id; E = $wp.E.Id }
      $o = Run1 'key B F 400'
      $b = WinLog 'B'; $dn = @($b | Where-Object { $_.D -eq 'D' -and $_.V -eq '46' }); $up = @($b | Where-Object { $_.D -eq 'U' -and $_.V -eq '46' })
      $held = if ($dn.Count -eq 1 -and $up.Count -eq 1) { $up[0].T - $dn[0].T } else { -1 }
      Chk 'win: key B F (hold 400 ms) reaches B only, with the key held for the time asked' ($dn.Count -eq 1 -and $up.Count -eq 1 -and $held -ge 330 -and $held -le 1200 -and (Downs 'A') -eq '' -and (Downs 'E') -eq '') "held=$held A=[$(Downs 'A')] E=[$(Downs 'E')] $o"
      foreach ($l in 'tap A SHIFT G', 'tap E SHIFT H', 'tap B SHIFT I', 'tap A SHIFT J', 'tap E SHIFT K', 'tap B SHIFT L') { [void](Run1 $l) }
      Chk 'win: interleaved taps A,E,B,A,E,B each land only in their own window' ((Downs 'A') -eq '47 4A' -and (Downs 'B') -eq '46 49 4C' -and (Downs 'E') -eq '48 4B') "A=[$(Downs 'A')] B=[$(Downs 'B')] E=[$(Downs 'E')]"
      [void](Run1 'key E F 300'); [void](Run1 'key A F 300')
      Chk 'win: key E and key A holds go to E and A, B gets nothing more' ((Downs 'E') -eq '48 4B 46' -and (Downs 'A') -eq '47 4A 46' -and (Downs 'B') -eq '46 49 4C') "A=[$(Downs 'A')] B=[$(Downs 'B')] E=[$(Downs 'E')]"
      [void](Run1 'tap B CTRL+S')
      Chk 'win: a chord tap (CTRL+S) goes to its window' ((Downs 'B') -eq '46 49 4C 11 53') (Downs 'B')
      $o = Run1 'focus A'
      Chk 'win: focus A reports the pid of A' ($o -like "*pid=$($wp.A.Id) *") $o
      $o = Run1 'mouse B 1 0'; $o2 = Run1 'mouse B -1 0'
      Chk 'win: mouse B is aimed at the process of B' ($o -like "*OK mouse*pid=$($wp.B.Id) *" -and $o2 -like "*pid=$($wp.B.Id) *") "$o | $o2"
      Stop-Process -Id $wp.E.Id -Force; Start-Sleep -Milliseconds 500
      $caught = $null; try { [void](Run1 'key E F 100') } catch { $caught = $_.Exception.Message }
      Chk 'win: key to a side whose game is gone fails (ERR in a run), never silently OK' ($caught -like '*not delivered*NOPROC*') $caught
      $ping = Start-Process ping -ArgumentList '-n', '20', '127.0.0.1' -WindowStyle Hidden -PassThru; Start-Sleep -Milliseconds 500
      $script:ProcOverride.A = $ping.Id
      $caught = $null; try { [void](Run1 'tap A SPACE') } catch { $caught = $_.Exception.Message }
      Stop-Process -Id $ping.Id -Force -ErrorAction SilentlyContinue
      Chk 'win: a process with no window fails (NOWINDOW), never silently OK' ($caught -like '*not delivered*NOWINDOW*') $caught
      $script:ProcOverride.A = $wp.A.Id
      Chk 'win: the failed steps sent no stray keys to the windows still up' ((Downs 'A') -eq '47 4A 46' -and (Downs 'B') -eq '46 49 4C 11 53') "A=[$(Downs 'A')] B=[$(Downs 'B')]"
    } finally {
      $script:ProcOverride = $null
      foreach ($k in 'A', 'B', 'E') { if ($wp[$k]) { Stop-Process -Id $wp[$k].Id -Force -ErrorAction SilentlyContinue } }
    }
  }

  $script:LogOverride = @{ A = $fxH; B = $fxC }
  $script:Vars = @{}; $script:Marks = @{}
  Set-Variable -Name DryRun -Value $true -Scope Script
  $script:Alive = @{ A = $false; B = $false }
  function OffOf($path, $rx) { $b = [IO.File]::ReadAllBytes($path); $t = [Text.Encoding]::UTF8.GetString($b); $m = [regex]::Match($t, $rx); [Text.Encoding]::UTF8.GetByteCount($t.Substring(0, $m.Index)) }
  $script:Marks.B = @{ Off = 0; Head = ''; Skip = $false }
  $r = Scan 'B' 'LIFE: CAIDO #3 \(hp (?<hp>[\d.]+) <= 15\)' 0
  Chk 'match from start: CAIDO #3 found, hp captured' ($r.Ok -and $r.Lines[0] -like '*23:45:07.6554728*' -and $script:Vars.hp -eq '10.7') ("" + $r.Lines[0] + " hp=" + $script:Vars.hp)
  $off = OffOf $fxC '\[2026-10-17 23:45:08'
  $script:Marks.B = @{ Off = $off; Head = ''; Skip = $false }
  $script:Marks.B.Head = (Get-Mark 'B').Head
  $r = Scan 'B' 'LIFE: CAIDO #3' 0
  Chk 'offset honoured: CAIDO #3 not seen after its line' (-not $r.Ok) "off=$off"
  $r = Scan 'B' 'MORREU ENQUANTO CAIDO \(hp=0\.0 alive=false' 0
  Chk 'offset: MORREU after the mark found' ($r.Ok -and $r.Lines[0] -like '*23:45:13.6422985*') $r.Lines[0]
  $script:Marks.B = @{ Off = $off + 5; Head = (Get-Mark 'B').Head; Skip = $true }
  $r = Scan 'B' '^\[2026-10-17 23:45:0[89]' 0
  Chk 'mid-line mark: partial first line dropped' ($r.Ok -and $r.Lines[0].StartsWith('[2026-10-17 23:45:0')) $r.Lines[0]
  $script:Marks.B = @{ Off = 0; Head = ''; Skip = $false }
  $r = Scan 'B' 'PreExit -> BYE' 0 -Not
  Chk 'expect_not: no BYE line in the old build (UEngine::PreExit offset line ignored)' $r.Ok ("" + ($r.Lines -join ' | '))
  $r = Scan 'B' 'LIFE: DE PE' 0 -Not
  Chk 'expect_not: DE PE present -> FAIL with lines' ((-not $r.Ok) -and $r.Lines.Count -ge 2) ("" + ($r.Lines -join ' | '))
  $script:Marks.A = @{ Off = (OffOf $fxH '\[2026-10-17 23:46:0'); Head = (Get-Mark 'A').Head; Skip = $false }
  $r = Scan 'A' 'NOLA PEER SILENT' 0
  Chk 'host fixture: PEER SILENT after 23:46:00' ($r.Ok -and $r.Lines[0] -like '*23:46:04.6854442*') $r.Lines[0]
  $script:Marks.A = @{ Off = 0; Head = 'SOMETHING ELSE ENTIRELY'; Skip = $false }
  $r = Scan 'A' 'Console created' 0
  Chk 'new log detected by head: rescan from 0' $r.Ok $r.Lines[0]
  $script:Marks.A = @{ Off = 99999999; Head = (Get-Mark 'A').Head; Skip = $false }
  $r = Scan 'A' 'Console created' 0
  Chk 'truncated log detected by size: rescan from 0' $r.Ok $r.Lines[0]

  $tA = "$out\replay_A.log"; $tB = "$out\replay_B.log"
  $cut = [datetime]::ParseExact('2026-10-17 23:45:00', 'yyyy-MM-dd HH:mm:ss', $null); $endA = $cut.AddSeconds(70)
  $tsre = New-Object regex '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{7})\]'
  $events = New-Object System.Collections.ArrayList
  $pre = @{ 0 = New-Object System.Text.StringBuilder; 1 = New-Object System.Text.StringBuilder }
  $srcs = @(@{ I = 0; F = $fxH; End = $endA }, @{ I = 1; F = $fxC; End = $cut.AddSeconds(3600) })
  foreach ($s in $srcs) {
    $last = [datetime]::MinValue
    foreach ($l in [IO.File]::ReadAllLines($s.F)) {
      $m = $tsre.Match($l); if ($m.Success) { $last = [datetime]::ParseExact($m.Groups[1].Value, 'yyyy-MM-dd HH:mm:ss.fffffff', $null) }
      if ($last -lt $cut) { [void]$pre[$s.I].Append($l).Append("`r`n") } elseif ($last -le $s.End) { [void]$events.Add(@(($last - $cut).TotalMilliseconds, $s.I, $l, $events.Count)) }
    }
  }
  $events = @($events | Sort-Object @{ e = { $_[0] } }, @{ e = { $_[3] } })
  [IO.File]::WriteAllText($tA, $pre[0].ToString()); [IO.File]::WriteAllText($tB, $pre[1].ToString())
  $speed = 10.0
  $rs = [powershell]::Create()
  [void]$rs.AddScript({
      param($ev, $paths, $speed)
      $fs = @($paths | ForEach-Object { [IO.File]::Open($_, 'Append', 'Write', 'ReadWrite, Delete') })
      Start-Sleep -Milliseconds 300
      $sw = [Diagnostics.Stopwatch]::StartNew()
      try {
        foreach ($e in $ev) {
          $due = $e[0] / $speed; $wait = $due - $sw.Elapsed.TotalMilliseconds
          if ($wait -gt 1) { Start-Sleep -Milliseconds ([int]$wait) }
          $b = [Text.Encoding]::UTF8.GetBytes($e[2] + "`r`n"); $fs[$e[1]].Write($b, 0, $b.Length); $fs[$e[1]].Flush()
        }
      } finally { $fs | ForEach-Object { $_.Dispose() } }
    }).AddArgument($events).AddArgument(@($tA, $tB)).AddArgument($speed)
  $script:LogOverride = @{ A = $tA; B = $tB }
  $spec = Read-Spec "$H\selftest\replay_spec.txt"
  Chk 'replay spec parses' ($spec.Errors.Count -eq 0) ($spec.Errors -join '; ')
  $rh = $rs.BeginInvoke()
  $rr = Invoke-Spec $spec $out "$out\replay_report.txt"
  $rs.EndInvoke($rh); $rs.Dispose()
  $want = @('INFO', 'OK', 'PASS', 'PASS', 'PASS', 'FAIL', 'PASS', 'FAIL', 'DRY', 'FAIL', 'MANUAL', 'DRY', 'OK', 'PASS', 'PASS', 'PASS', 'PASS', 'PASS')
  $got = @($rr.Rows | ForEach-Object { $_.Result })
  for ($i = 0; $i -lt [Math]::Max($want.Count, $got.Count); $i++) {
    $row = $rr.Rows[$i]
    Chk ("replay row {0,2} want {1,-6} got {2,-6} {3}" -f ($i + 1), $want[$i], $got[$i], (Short $row.Text 70)) ($want[$i] -eq $got[$i]) ("" + $row.Detail)
  }
  Chk 'replay verdict FAIL (expected rows of FAIL present)' ($rr.Verdict -eq 'FAIL') $rr.Verdict
  $script:LogOverride = @{}
  $np = @($res | Where-Object { $_.Ok }).Count; $nf = @($res | Where-Object { -not $_.Ok }).Count
  $lines = @("S2 harness selftest $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  fixtures: $fxC (md5 $((Get-FileHash $fxC -Algorithm MD5).Hash.Substring(0,8).ToLower())), $fxH (md5 $((Get-FileHash $fxH -Algorithm MD5).Hash.Substring(0,8).ToLower()))", '') + @($res | ForEach-Object { ('{0,-5} {1}  {2}' -f $(if ($_.Ok) { 'PASS' } else { 'FAIL' }), $_.Name, (Short $_.Detail 200)) }) + @('', "SELFTEST pass=$np fail=$nf  $(if ($nf) { 'FAIL' } else { 'ALL PASS' })")
  [IO.File]::WriteAllLines("$out\selftest_report.txt", [string[]]$lines)
  Write-Host "SELFTEST pass=$np fail=$nf -> $out\selftest_report.txt"
  exit $(if ($nf) { 1 } else { 0 })
}

function Read-Shared($p) { $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite, Delete'); try { $t = (New-Object IO.StreamReader($fs)).ReadToEnd() } finally { $fs.Dispose() }; , @($t -split "`r?`n") }
$INV = [Globalization.CultureInfo]::InvariantCulture
function Ts-Ue($l) { if ($l -match '^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{7})\]') { return [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm:ss.fffffff', $INV) }; $null }
function Ts-Eng($l) { if ($l -match '^\[(\d{4}\.\d\d\.\d\d-\d\d\.\d\d\.\d\d:\d{3})\]') { return [datetime]::SpecifyKind([datetime]::ParseExact($Matches[1], 'yyyy.MM.dd-HH.mm.ss:fff', $INV), 'Utc').ToLocalTime() }; $null }
function First-Hit($lines, $rx, [switch]$Eng) {
  $re = New-Object regex ($rx)
  foreach ($l in $lines) { $m = $re.Match($l); if ($m.Success) { $t = if ($Eng) { Ts-Eng $l } else { Ts-Ue $l }; if ($t) { return @{ T = $t; L = $l; M = $m } } } }
  $null
}
function Find-EngineLog($k, $rd, $t1) {
  $f = "$rd\$($SIDES[$k].Tag)_engine.log"; if (Test-Path -LiteralPath $f) { return $f }
  if (-not $t1) { return $null }
  $d = "$env:LOCALAPPDATA\Stalker2\$($SIDES[$k].Saved)\Logs"
  foreach ($c in @(Get-ChildItem -LiteralPath $d -Filter 'Stalker2*.log' -File -ErrorAction SilentlyContinue)) {
    $hl = (Read-Shared $c.FullName) | Select-Object -First 1
    if ($hl -match 'Log file open, (\d\d/\d\d/\d\d \d\d:\d\d:\d\d)') { $o = [datetime]::ParseExact($Matches[1], 'MM/dd/yy HH:mm:ss', $INV); if ([Math]::Abs(($o - $t1).TotalSeconds) -le 30) { return $c.FullName } }
  }
  $null
}
function Get-BootRows($rd) {
  $s = Read-State $rd
  $rows = New-Object System.Collections.ArrayList
  foreach ($k in 'A', 'B', 'E') {
    $tag = $SIDES[$k].Tag
    $ul = "$rd\$($tag)_UE4SS.log"; if (-not (Test-Path -LiteralPath $ul)) { $ul = LogPath $k; if (-not (Get-SideProc $k)) { $ul = $null } }
    if (-not $ul -or -not (Test-Path -LiteralPath $ul)) { continue }
    $u = Read-Shared $ul
    $u1 = $null; foreach ($l in $u) { $u1 = Ts-Ue $l; if ($u1) { break } }
    if (-not $u1) { continue }
    if ($s -and $s.start -and $u1 -lt ([datetime]$s.start).AddSeconds(-5)) { continue }
    $add = { param($ph, $t, $txt) if ($t) { [void]$rows.Add([pscustomobject]@{ Side = $k; Phase = $ph; T = $t; Text = "$txt" }) } }
    $ln = if ($s) { $s.PSObject.Properties["launch_$tag"] } else { $null }
    if ($ln -and $ln.Value) { & $add 'launch' ([datetime]$ln.Value) 'harness Start-Process' }
    $ef = Find-EngineLog $k $rd $u1
    $e = if ($ef) { Read-Shared $ef } else { @() }
    if ($e.Count -and $e[0] -match 'Log file open, (\d\d/\d\d/\d\d \d\d:\d\d:\d\d)') { & $add 'process' ([datetime]::ParseExact($Matches[1], 'MM/dd/yy HH:mm:ss', $INV)) 'engine log opened (1 s resolution)' }
    & $add 'ue4ss' $u1 'first UE4SS line'
    $fh = First-Hit $e 'Engine is initialized' -Eng; if ($fh) { & $add 'engine_init' $fh.T 'Engine is initialized' }
    $fh = First-Hit $u 'NOLA x0 ready'; if ($fh) { & $add 'mods' $fh.T 'NOLA x0 ready' }
    $fh = First-Hit $e 'Loading prototypes took ([1-9][0-9]*\.[0-9]+) seconds' -Eng
    if ($fh) { $took = [double]$fh.M.Groups[1].Value; & $add 'popup_gone' ($fh.T.AddSeconds(-$took)) 'auth popup dismissed = prototype load starts'; & $add 'menu' $fh.T "prototypes loaded in $took s, main menu" }
    $fh = First-Hit $u 'Steam user not ready within'; if ($fh) { & $add 'steam_off' $fh.T 'Steam wait timed out (info)' }
    $fh = First-Hit $u 'NOLA ldstrip|NOLA n7: host comecou a carregar|NOLA lshold: load #1'; if ($fh) { & $add 'load' $fh.T 'save load started (Continue)' }
    $fh = First-Hit $u $WorldRegex; if ($fh) { & $add 'world' $fh.T 'world line' }
    $fh = First-Hit $u $JoinRegex; if ($fh) { & $add 'peer_up' $fh.T 'NOLA PEER UP' }
  }
  , @($rows | Sort-Object T)
}
function Get-BootText($rd) {
  $rows = Get-BootRows $rd
  if (-not $rows.Count) { return , @("boot timeline: no logs in $rd") }
  $s = Read-State $rd
  $t0 = if ($s -and $s.start) { [datetime]$s.start } else { $rows[0].T }
  $o = New-Object System.Collections.ArrayList
  [void]$o.Add("boot timeline $rd  (t = seconds after the up start $($t0.ToString('HH:mm:ss.f')); d = since the previous phase of the same side)")
  $last = @{}
  foreach ($r in $rows) {
    $d = if ($last.ContainsKey($r.Side)) { [string]::Format($INV, '{0,6:0.0}', ($r.T - $last[$r.Side]).TotalSeconds) } else { '     -' }
    $last[$r.Side] = $r.T
    [void]$o.Add([string]::Format($INV, '{0,-7} {1,-12} {2}  t={3,6:0.0}  d={4}  {5}', $SIDES[$r.Side].Tag, $r.Phase, $r.T.ToString('HH:mm:ss.f', $INV), ($r.T - $t0).TotalSeconds, $d, $r.Text))
  }
  $pu = @($rows | Where-Object { $_.Phase -eq 'peer_up' } | Sort-Object T | Select-Object -Last 1)
  $w = @($rows | Where-Object { $_.Phase -eq 'world' } | ForEach-Object { "$($SIDES[$_.Side].Tag) $([Math]::Round(($_.T - $t0).TotalSeconds, 1)) s" }) -join ', '
  [void]$o.Add("SUMMARY peer_up $(if ($pu.Count) { [Math]::Round(($pu[0].T - $t0).TotalSeconds, 1) } else { 'none' }) s; world $w")
  , @($o)
}
function Lock-Log($m) { New-Item -ItemType Directory -Force (Split-Path $LOCKLOG) | Out-Null; Add-Content -LiteralPath $LOCKLOG -Value ((Get-Date).ToString('s') + ' ' + $m) -Encoding ascii }
function Lock-Info {
  if (-not (Test-Path -LiteralPath $LOCK)) { return $null }
  $t = ''; try { $t = ([IO.File]::ReadAllText($LOCK)).Trim() } catch { }
  $who = @($t -split '\s+')[0]; if (-not $who) { $who = '?' }
  $at = $null; if ($t -match '\s(\d{4}-\d\d-\d\dT[0-9:.]+(Z|[+-]\d\d:\d\d)?)') { try { $at = [datetime]::Parse($Matches[1], $INV) } catch { } }
  if (-not $at) { $at = (Get-Item -LiteralPath $LOCK).LastWriteTime }
  [pscustomobject]@{ Who = $who; At = $at; Min = [Math]::Round(((Get-Date) - $at).TotalMinutes, 1); Text = $t }
}
function Check-Hold {
  $li = Lock-Info
  if ($li -and $li.Min -ge $MAXHOLD) {
    $key = "HOLD $($li.Who) since $($li.At.ToString('s'))"
    Say "WARNING: pair$Pair.lock held by $($li.Who) for $($li.Min) min (max hold $MAXHOLD min): finish, batch the rest into one boot, or release it"
    $recent = $false
    if (Test-Path -LiteralPath $LOCKLOG) { foreach ($l in @(Get-Content -LiteralPath $LOCKLOG -Tail 50)) { if ($l -match '^(\S+) WARNING (HOLD .*?) \(' -and $Matches[2] -eq $key) { if (((Get-Date) - [datetime]::Parse($Matches[1], $INV)).TotalMinutes -lt 5) { $recent = $true } } } }
    if (-not $recent) { Lock-Log "WARNING $key ($($li.Min) min > $MAXHOLD min)" }
  }
  $li
}
function Read-Queue {
  if (-not (Test-Path -LiteralPath $QUEUE)) { return }
  @([IO.File]::ReadAllLines($QUEUE) | Where-Object { $_ -match "`t" } | ForEach-Object { $p = $_ -split "`t"; [pscustomobject]@{ Name = $p[0]; Since = [datetime]::Parse($p[1], $INV); Seen = [datetime]::Parse($p[2], $INV) } })
}
function Write-Queue($q) { [IO.File]::WriteAllLines($QUEUE, [string[]]@($q | ForEach-Object { "$($_.Name)`t$($_.Since.ToString('o'))`t$($_.Seen.ToString('o'))" })) }
function Lock-Try($name) {
  $mx = New-Object Threading.Mutex($false, $QMXNAME); $got = $false
  try {
    try { $got = $mx.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $got = $true }
    if (-not $got) { Fail "pair$Pair queue mutex busy for 15 s" }
    $now = Get-Date
    $q = @(); foreach ($e in @(Read-Queue)) { if (($now - $e.Seen).TotalMinutes -gt $QSTALE -and $e.Name -ne $name) { Lock-Log "queue: dropped $($e.Name) (not seen for $QSTALE min)" } else { $q += $e } }
    $li = Lock-Info
    if ($li -and $li.Who -eq $name) { $q = @($q | Where-Object { $_.Name -ne $name }); Write-Queue $q; return @{ Got = $true; New = $false; Pos = 0; N = $q.Count; Li = $li } }
    $me = $q | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    if (-not $me) { $me = [pscustomobject]@{ Name = $name; Since = $now; Seen = $now }; $q += $me; Lock-Log "queue: $name joined at position $($q.Count)$(if ($li) { " (holder $($li.Who), $($li.Min) min)" })" } else { $me.Seen = $now }
    $pos = [array]::IndexOf([string[]]@($q | ForEach-Object { $_.Name }), $name) + 1
    if ($li -and $li.Who -ne $name) { $ir = Test-IdleHold $li ([int]$Pair); if ($ir) { Release-IdleHold $li $ir $name; $li = $null } }
    if ($li -and $li.Who -ne $name -and $pos -eq 1 -and (Test-LockExpired $li)) { Expire-Lock $li $name; $li = $null }
    if (-not $li -and $pos -eq 1) {
      $ok = $false
      try { $fs = [IO.File]::Open($LOCK, 'CreateNew', 'Write', 'None'); try { $b = [Text.Encoding]::ASCII.GetBytes("$name $($now.ToString('o'))"); $fs.Write($b, 0, $b.Length) } finally { $fs.Dispose() }; $ok = $true } catch [IO.IOException] { $ok = $false }
      if ($ok) {
        try { [IO.File]::WriteAllText("$LOCK.cwd", (Get-Location).Path) } catch { }
        Clear-LockMarks
        $q = @($q | Where-Object { $_.Name -ne $name }); Write-Queue $q
        Lock-Log "lock: taken by $name after $([int]($now - $me.Since).TotalSeconds) s in the queue"
        return @{ Got = $true; New = $true; Pos = 0; N = $q.Count; Li = (Lock-Info) }
      }
      $li = Lock-Info
    }
    Write-Queue $q
    @{ Got = $false; New = $false; Pos = $pos; N = $q.Count; Li = $li }
  } finally { if ($got) { $mx.ReleaseMutex() }; $mx.Dispose() }
}
function Cmd-Lock {
  if (-not $Spec) { Fail 'lock <worker name> [-Wait seconds]' }
  $t0 = Get-Date; $n = 0
  while ($true) {
    $r = Lock-Try $Spec
    if ($r.Got -and $r.New) { Remove-Item -LiteralPath "$H\$BUDGET" -Force -ErrorAction SilentlyContinue }
    if ($r.Got) { Say "pair$Pair.lock $(if ($r.New) { 'taken' } else { 'already held' }) by $Spec ($($r.N) waiting behind)"; exit 0 }
    $hs = if ($r.Li) { "held by $($r.Li.Who) for $($r.Li.Min) min" } else { 'free, an earlier worker in the queue goes first' }
    if ($n % 30 -eq 0) { Say "pair$Pair.lock $hs; $Spec is number $($r.Pos) of $($r.N) in the queue" }
    if ($n % 150 -eq 0) { [void](Check-Hold) }
    $n++
    if (((Get-Date) - $t0).TotalSeconds + 2 -gt $Wait) { Say "still queued (call 'lock $Spec' again within $QSTALE min to keep the place)"; exit 3 }
    Start-Sleep -Seconds 2
  }
}
function Set-LockPair([int]$p) {
  $script:Pair = "$p"
  if ($p -eq 3) {
    $script:LOCK = "$H\pair3.lock"; $script:QUEUE = "$H\pair3.queue"; $script:QMX = "$H\pair3.queue.mx"; $script:LOCKLOG = "$H\runs\lock_p3.log"
    $script:QMXNAME = 'Global\s2harness_pair3_queue'; $script:BUDGET = 'pair3.budget'
  } else {
    $script:LOCK = "$H\pair2.lock"; $script:QUEUE = "$H\pair2.queue"; $script:QMX = "$H\pair2.queue.mx"; $script:LOCKLOG = "$H\runs\lock.log"
    $script:QMXNAME = 'Global\s2harness_pair2_queue'; $script:BUDGET = 'pair2.budget'
  }
}
function Leave-PairQueue([int]$p, [string]$name) {
  Set-LockPair $p
  $mx = New-Object Threading.Mutex($false, $QMXNAME); $got = $false
  try {
    try { $got = $mx.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $got = $true }
    if ($got -and (Test-Path -LiteralPath $QUEUE)) { Write-Queue @(Read-Queue | Where-Object { $_.Name -ne $name }) }
  } finally { if ($got) { $mx.ReleaseMutex() }; $mx.Dispose() }
}
function Cmd-LockAny {
  if (-not $Spec) { Fail 'lock <worker name> -Pair any [-Wait seconds]' }
  $t0 = Get-Date; $n = 0
  while ($true) {
    $win = 0; $r = $null; $held = @{}
    foreach ($p in 2, 3) { Set-LockPair $p; $li = Lock-Info; if ($li -and $li.Who -eq $Spec) { $win = $p; $r = @{ Got = $true; New = $false; N = @(Read-Queue).Count }; break } }
    if (-not $win) { foreach ($p in 2, 3) { Set-LockPair $p; $r = Lock-Try $Spec; $held[$p] = $r; if ($r.Got) { $win = $p; break } } }
    if ($win) {
      Set-LockPair $win
      if ($r.New) { Remove-Item -LiteralPath "$H\$BUDGET" -Force -ErrorAction SilentlyContinue }
      foreach ($o in 2, 3) { if ($o -ne $win) { Leave-PairQueue $o $Spec } }
      Set-LockPair $win
      if ($win -eq 3 -and $r.New) { [IO.File]::WriteAllText("$H\pair3.lock.any", $Spec) }
      Say "pair$win.lock $(if ($r.New) { 'taken' } else { 'already held' }) by $Spec ($($r.N) waiting behind)"
      Write-Host "taken pair $win"
      exit 0
    }
    if ($n % 30 -eq 0) {
      foreach ($p in 2, 3) { $e = $held[$p]; $hs = if ($e.Li) { "held by $($e.Li.Who) for $($e.Li.Min) min" } else { 'free, an earlier worker in the queue goes first' }; Say "pair${p}.lock $hs; $Spec is number $($e.Pos) of $($e.N) in the queue" }
    }
    if ($n % 150 -eq 0) { foreach ($p in 2, 3) { Set-LockPair $p; [void](Check-Hold) } }
    $n++
    if (((Get-Date) - $t0).TotalSeconds + 2 -gt $Wait) { Say "still queued on both pairs (call 'lock $Spec -Pair any' again within $QSTALE min to keep the places)"; exit 3 }
    Start-Sleep -Seconds 2
  }
}
function Unlock-Pair($name) {
  $mx = New-Object Threading.Mutex($false, $QMXNAME); $got = $false
  try {
    try { $got = $mx.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $got = $true }
    $li = Lock-Info
    if ($li -and $li.Who -ne $name) { Fail "pair$Pair.lock is held by $($li.Who), not by ${name}: never remove another worker's lock" }
    $q = @(Read-Queue | Where-Object { $_.Name -ne $name }); if (Test-Path -LiteralPath $QUEUE) { Write-Queue $q }
    if (-not $li) { Say "pair$Pair.lock is not held; $name left the queue"; return }
    Remove-Item -LiteralPath $LOCK -Force
    Remove-Item -LiteralPath "$LOCK.cwd" -Force -ErrorAction SilentlyContinue
    Clear-LockMarks
    Lock-Log "lock: released by $name after $($li.Min) min"
    Say "pair$Pair.lock released by $name after $($li.Min) min; next in the queue: $(if ($q.Count) { $q[0].Name } else { 'nobody' })"
  } finally { if ($got) { $mx.ReleaseMutex() }; $mx.Dispose() }
}
function Cmd-Unlock {
  if (-not $Spec) { Fail 'unlock <worker name>' }
  $cur = [int]$Pair
  $li = Lock-Info
  if ($li -and $li.Who -ne $Spec) {
    foreach ($lp in 2, 3) { Leave-PairQueue $lp $Spec }
    Set-LockPair $cur
    Say "pair$Pair.lock is held by $($li.Who), not by ${Spec}: its lock was not touched; ${Spec} left the queue on both pairs"
    return
  }
  Unlock-Pair $Spec
}
function Cmd-LockStatus {
  $li = Check-Hold
  Write-Host "pair$Pair.lock: $(if ($li) { "$($li.Who) since $($li.At.ToString('HH:mm:ss')) ($($li.Min) min)" } else { 'free' })"
  $i = 0; foreach ($e in @(Read-Queue)) { $i++; Write-Host ("  {0}. {1} waiting since {2} (last seen {3})" -f $i, $e.Name, $e.Since.ToString('HH:mm:ss'), $e.Seen.ToString('HH:mm:ss')) }
}
function Budget-Log([string]$m) { try { Add-Content -LiteralPath "$H\budget.log" -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + " | pair$Pair | $m") -Encoding ascii } catch { } }
function Get-LockLimit($li) {
  $lim = $MAXHOLD
  if (Test-Path -LiteralPath "$LOCK.ext") { $t = @(([IO.File]::ReadAllText("$LOCK.ext")).Trim() -split '\|'); if ($t[0] -eq $li.Who) { $lim += 10 } }
  $lim
}
function Test-LockExpired($li) { [bool]($li -and $li.Min -ge (Get-LockLimit $li)) }
function Clear-LockMarks { foreach ($x in 'ext', 'adhoc', 'any') { Remove-Item -LiteralPath "$LOCK.$x" -Force -ErrorAction SilentlyContinue } }
function Expire-Lock($li, [string]$by) {
  $lim = Get-LockLimit $li
  Remove-Item -LiteralPath $LOCK -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath "$LOCK.cwd" -Force -ErrorAction SilentlyContinue
  Clear-LockMarks
  Lock-Log "lock: EXPIRED holder $($li.Who) after $($li.Min) min (limit $lim), taken over by $by"
  Budget-Log "LOCKEXPIRED holder $($li.Who) | $($li.Min) min | limit $lim | next $by"
}
function Test-PlanChild {
  $ep = "$env:S2H_PLAN"
  if ($ep -match '^\d+$' -and (Get-Process -Id ([int]$ep) -ErrorAction SilentlyContinue)) { return $true }
  try {
    $pp = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop).ParentProcessId
    $cl = "" + (Get-CimInstance Win32_Process -Filter "ProcessId=$pp" -ErrorAction Stop).CommandLine
    return [bool]($cl -match '-File\s+"?\S*harness\.ps1"?\s+plan\s')
  } catch { return $false }
}
function Test-AdhocApplies($li) {
  $f = "$H\adhoc_from.txt"
  if (-not (Test-Path -LiteralPath $f)) { return $true }
  try { return ($li.At -ge [datetime]::Parse((([IO.File]::ReadAllText($f)).Trim()), $INV)) } catch { return $true }
}
function Enforce-Rules {
  $c = $Cmd.ToLower()
  $pairCmds = 'par', 'scene', 'frame', 'shot', 'stage', 'face', 'aim', 'fire', 'hold', 'use', 'burst', 'up', 'run', 'reset', 'setflag', 'dllrestore', 'animcheck', 'plan', 'tp', 'equip', 'closeui', 'settime'
  $adhocCmds = 'up', 'run', 'reset', 'stage', 'face', 'aim', 'fire', 'hold', 'use', 'burst', 'shot', 'scene', 'setflag', 'animcheck', 'tp', 'frame', 'equip', 'closeui', 'settime'
  if ($c -notin $pairCmds) { return }
  if ($c -eq 'plan' -and $Check) { return }
  if ($DryRun) { return }
  $li = Lock-Info; if (-not $li) { return }
  $expired = Test-LockExpired $li
  if (-not $expired -and $c -notin $adhocCmds) { return }
  $inPlan = Test-PlanChild
  if (-not $inPlan -and $expired) {
    $lim = Get-LockLimit $li
    if ($OverBudget -and -not (Test-Path -LiteralPath "$LOCK.ext") -and $li.Min -lt ($MAXHOLD + 10)) {
      [IO.File]::WriteAllText("$LOCK.ext", "$($li.Who)|$((Get-Date).ToString('o'))|$OverBudget")
      Budget-Log "LOCKEXT holder $($li.Who) | $($li.Min) min | +10 min | reason: $OverBudget"
      Say "lock extended by 10 min (once) for $($li.Who): reason: $OverBudget"
    } else {
      Budget-Log "LOCKREFUSED $c holder $($li.Who) | $($li.Min) min | limit $lim"
      $hint = ''; if (-not (Test-Path -LiteralPath "$LOCK.ext")) { $hint = '; once, -OverBudget "<reason>" on this command adds 10 min if nobody has taken the lock' }
      Fail "lock expired after $($li.Min) min (limit $lim): unlock and requeue ('harness.ps1 unlock $($li.Who)', then 'lock $($li.Who)'); the first waiter in the queue may take it now$hint"
    }
  }
  if ($c -in $adhocCmds -and -not $inPlan -and (Test-AdhocApplies $li)) {
    if (-not $Adhoc) {
      Budget-Log "ADHOCREFUSED $c $Spec | holder $($li.Who)"
      Fail "ad-hoc '$c' is refused inside the lock: write the session as a .plan, validate with 'plan <file> -Check', run 'plan <file>' (runner calls are allowed). One escape per lock session: -Adhoc ""<reason>"""
    }
    if (Test-Path -LiteralPath "$LOCK.adhoc") {
      Budget-Log "ADHOCREFUSED $c $Spec | holder $($li.Who) | escape already used | reason: $Adhoc"
      Fail "ad-hoc '$c' refused: the one -Adhoc escape of this lock session is spent; use a .plan"
    }
    [IO.File]::WriteAllText("$LOCK.adhoc", "$($li.Who)|$((Get-Date).ToString('o'))|$Adhoc")
    Budget-Log "ADHOC $c $Spec | holder $($li.Who) | reason: $Adhoc"
    Say "ad-hoc '$c' allowed once for this lock session: $Adhoc"
  }
}
$IDLECAP = 4
$PAIRCMDS = @('par', 'scene', 'frame', 'shot', 'stage', 'face', 'aim', 'fire', 'hold', 'use', 'burst', 'up', 'run', 'reset', 'down', 'setflag', 'dllrestore', 'animcheck', 'plan', 'tp', 'equip', 'closeui', 'settime', 'nbot', 'census', 'timeline')
$JOBS = "$H\jobs"
function Get-LastPairCmd([string]$who) {
  $f = "$H\runs\cmd.log"; if (-not (Test-Path -LiteralPath $f)) { return $null }
  try { $all = Read-Shared $f } catch { return [datetime]::MaxValue }
  $n = @($all).Count; if ($n -lt 2) { return [datetime]::MaxValue }; $ls = if ($n -gt 800) { $all[($n - 800)..($n - 1)] } else { $all }
  $last = $null
  foreach ($l in $ls) {
    if ($l -notmatch '^(\S+)\s+(\S+)\s+(\S+)(.*)$') { continue }
    if ($Matches[2] -ne $who -or $Matches[3].ToLower() -notin $PAIRCMDS -or $Matches[4] -match '\s-Check\s*$') { continue }
    $ts = $Matches[1]
    try { $tt = [datetime]::Parse($ts, $INV) } catch { continue }
    if (-not $last -or $tt -gt $last) { $last = $tt }
  }
  $last
}
function Get-PairProcs([int]$p) {
  $anyOn = (Test-Path -LiteralPath "$H\pair3.lock.any")
  try { $procs = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' or Name='pwsh.exe'" -ErrorAction Stop) } catch { return @('unknown') }
  if (-not $procs.Count) { return @('unknown') }
  @($procs | Where-Object {
      $c = "" + $_.CommandLine
      if ($_.ProcessId -eq $PID -or $c -notmatch 'harness\.ps1') { return $false }
      if ($H -ne $HDEF -and $c.IndexOf($H, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
      if ($c -notmatch 'harness\.ps1[''"]?\s+(?:-Pair\s+\S+\s+)?([A-Za-z]+)') { return $false }
      if ($Matches[1].ToLower() -notin $PAIRCMDS) { return $false }
      if ($c -match '\s-Check\b') { return $false }
      if ($c -match '-Pair\s+[''"]?(\d)') { return ([int]$Matches[1] -eq $p) }
      ($p -eq 2 -or $anyOn)
    })
}
function Test-IdleHold($li, [int]$p) {
  if (-not $li) { return $null }
  $lc = Get-LastPairCmd $li.Who
  $from = $li.At; if ($lc -and $lc -gt $from) { $from = $lc }
  $idle = ((Get-Date) - $from).TotalMinutes
  if ($idle -lt $IDLECAP) { return $null }
  if (@(Get-PairProcs $p).Count) { return $null }
  if ("$($li.Who)" -like 'job:*') {
    foreach ($pf in @(Get-ChildItem -LiteralPath "$H\jobs\running" -Filter '*.pid' -ErrorAction SilentlyContinue)) {
      $jp = 0; [void][int]::TryParse(("" + (Get-Content -LiteralPath $pf.FullName -TotalCount 1 -ErrorAction SilentlyContinue)).Trim(), [ref]$jp)
      if ($jp -and (Get-Process -Id $jp -ErrorAction SilentlyContinue)) { return $null }
    }
  }
  [pscustomobject]@{ Idle = [Math]::Round($idle, 1); Last = $lc }
}
function Release-IdleHold($li, $ir, [string]$by) {
  Remove-Item -LiteralPath $LOCK -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath "$LOCK.cwd" -Force -ErrorAction SilentlyContinue
  Clear-LockMarks
  $ls = if ($ir.Last) { $ir.Last.ToString('HH:mm:ss') } else { 'none since the lock was taken' }
  Lock-Log "lock: IDLE-RELEASED holder $($li.Who) after $($ir.Idle) min with no pair command (last $ls) and no harness process of pair $Pair; held $($li.Min) min; waiting: $by"
  Budget-Log "LOCKIDLE holder $($li.Who) | idle $($ir.Idle) min | held $($li.Min) min | next $by"
}
function Read-JobMeta([string]$id) {
  $f = "$JOBS\meta\$id.json"
  if (Test-Path -LiteralPath $f) { try { return ([IO.File]::ReadAllText($f) | ConvertFrom-Json) } catch { } }
  [pscustomobject]@{ id = $id; name = ($id -replace '^\d{8}_\d{6}_\d{3}_', ''); pair = 'any'; overbudget = '' }
}
function Get-QueuedJobs {
  if (-not (Test-Path -LiteralPath "$JOBS\queue")) { return @() }
  @(Get-ChildItem -LiteralPath "$JOBS\queue" -Filter *.plan | Sort-Object Name | ForEach-Object { $m = Read-JobMeta $_.BaseName; [pscustomobject]@{ Id = $_.BaseName; Name = "$($m.name)"; Pair = "$($m.pair)" } })
}
function Get-RunnerPid {
  $f = "$JOBS\jobrunner.pid"; $rp = 0
  if ((Test-Path -LiteralPath $f) -and [int]::TryParse(([IO.File]::ReadAllText($f)).Trim(), [ref]$rp)) { $pr = Get-Process -Id $rp -ErrorAction SilentlyContinue; if ($pr -and $pr.ProcessName -match 'powershell|pwsh') { return $rp } }
  0
}
function Cmd-IdleCap {
  $p = [int]$Pair; $rc = 1
  $mx = New-Object Threading.Mutex($false, $QMXNAME); $got = $false
  try {
    try { $got = $mx.WaitOne(15000) } catch [Threading.AbandonedMutexException] { $got = $true }
    if (-not $got) { Fail "pair$Pair queue mutex busy for 15 s" }
    $li = Lock-Info
    if (-not $li) { Write-Host "pair$Pair.lock is free" }
    else {
      $now = Get-Date
      $w = @(@(Read-Queue) | Where-Object { $_.Name -ne $li.Who -and ($now - $_.Seen).TotalMinutes -le $QSTALE } | ForEach-Object { $_.Name }) + @(Get-QueuedJobs | Where-Object { $_.Pair -in 'any', "$p" } | ForEach-Object { "job:$($_.Name)" })
      if (-not $w.Count) { Write-Host "pair$Pair.lock held by $($li.Who) ($($li.Min) min): nobody queued, kept" }
      else {
        $ir = Test-IdleHold $li $p
        if (-not $ir) { Write-Host "pair$Pair.lock held by $($li.Who) ($($li.Min) min): active (a pair command less than $IDLECAP min ago or a harness pair process running), kept" }
        else { Release-IdleHold $li $ir ($w -join ','); Write-Host "pair$Pair.lock IDLE-RELEASED: $($li.Who) idle $($ir.Idle) min; waiting: $($w -join ', ')"; $rc = 0 }
      }
    }
  } finally { if ($got) { $mx.ReleaseMutex() }; $mx.Dispose() }
  exit $rc
}
function Cmd-Submit {
  if (-not $Spec -or -not $Name) { Fail 'submit <file.plan> -Name <worker> [-Pair any|2|3] [-OverBudget why]' }
  if ($Name -notmatch '^[A-Za-z0-9_.-]+$') { Fail '-Name: letters, digits, _ . - only' }
  if (-not (Test-Path -LiteralPath $Spec -PathType Leaf)) { Fail "plan file not found: $Spec" }
  $src = (Resolve-Path -LiteralPath $Spec).Path
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, 'plan', $src, '-Check'); if ($OverBudget) { $a += @('-OverBudget', $OverBudget) }
  $ErrorActionPreference = 'Continue'
  $o = @(& powershell.exe @a 2>&1 | ForEach-Object { "$_" }); $rc = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  $o | ForEach-Object { Write-Host $_ }
  if ($rc -ne 0) { Write-Host "SUBMIT REFUSED: 'plan -Check' failed (exit $rc), nothing was queued"; exit 2 }
  $pp = if ($PairAny) { 'any' } else { "$Pair" }
  foreach ($d in 'queue', 'running', 'done', 'meta') { New-Item -ItemType Directory -Force "$JOBS\$d" | Out-Null }
  $id = (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + "_$Name"
  $meta = [ordered]@{ id = $id; name = $Name; pair = $pp; src = $src; submitted = (Get-Date).ToString('o'); overbudget = $OverBudget; cwd = (Get-Location).Path }
  [IO.File]::WriteAllText("$JOBS\meta\$id.json", ($meta | ConvertTo-Json))
  Copy-Item -LiteralPath $src -Destination "$JOBS\queue\$id.tmp" -Force
  Move-Item -LiteralPath "$JOBS\queue\$id.tmp" -Destination "$JOBS\queue\$id.plan"
  $q = @(Get-QueuedJobs); $pos = [array]::IndexOf([string[]]@($q | ForEach-Object { $_.Id }), $id) + 1
  if (-not (Get-RunnerPid)) {
    Write-Host 'jobrunner is not running: starting it'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'jobrunner.ps1') start | ForEach-Object { Write-Host "$_" }
  }
  Write-Host "job $id queued (pair $pp, position $pos of $($q.Count)); wait with: harness.ps1 job $id -Wait <s>"
  Write-Host "id: $id"
  exit 0
}
function Get-JobStatus([string]$id) {
  $d = "$JOBS\done\$id"
  if (Test-Path -LiteralPath "$d\rc.txt") {
    $rl = @([IO.File]::ReadAllLines("$d\rc.txt")); $rc = 1; [void][int]::TryParse("$($rl[0])".Trim(), [ref]$rc)
    $res = @(); if (Test-Path -LiteralPath "$d\result.txt") { $res = @([IO.File]::ReadAllLines("$d\result.txt")) }
    $fl = @($res | Where-Object { $_ -like 'failed: *' }) | Select-Object -First 1
    $cr = @($rl | Where-Object { $_ -like 'crash: *' }) | Select-Object -First 1
    $tx = if ($rc -eq 0) { 'done rc 0' } elseif ($fl) { "failed rc $rc, $($fl.Substring(8))" } else { "done rc $rc" }
    if ($cr) { $tx += " ($cr)" }
    return [pscustomobject]@{ State = 'done'; Rc = $rc; Text = $tx; Dir = $d; Lines = $res }
  }
  if (Test-Path -LiteralPath "$JOBS\running\$id.plan") {
    $pf = "$JOBS\running\$id.pair"; $pp = '?'; $t0 = (Get-Item -LiteralPath "$JOBS\running\$id.plan").LastWriteTime
    if (Test-Path -LiteralPath $pf) { $pp = ([IO.File]::ReadAllText($pf)).Trim(); $t0 = (Get-Item -LiteralPath $pf).LastWriteTime }
    return [pscustomobject]@{ State = 'running'; Rc = $null; Text = "running pair$pp since $($t0.ToString('HH:mm:ss'))"; Dir = $d; Lines = @() }
  }
  if (Test-Path -LiteralPath "$JOBS\queue\$id.plan") {
    $q = @(Get-QueuedJobs); $pos = [array]::IndexOf([string[]]@($q | ForEach-Object { $_.Id }), $id) + 1; $m = Read-JobMeta $id
    $tx = "queued (position $pos of $($q.Count), pair $($m.pair))"; if (-not (Get-RunnerPid)) { $tx += '; jobrunner NOT running (jobrunner.ps1 start)' }
    return [pscustomobject]@{ State = 'queued'; Rc = $null; Text = $tx; Dir = $d; Lines = @() }
  }
  [pscustomobject]@{ State = 'unknown'; Rc = $null; Text = 'unknown job'; Dir = $d; Lines = @() }
}
function Resolve-JobId([string]$s) {
  if (Test-Path -LiteralPath "$JOBS\meta\$s.json") { return $s }
  $c = @(Get-ChildItem -LiteralPath "$JOBS\meta" -Filter "*$s*.json" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.BaseName })
  if ($c.Count) { return $c[-1] }
  $null
}
function Cmd-Job {
  if (-not $Spec) {
    Write-Host "jobrunner: $(if ($rp = Get-RunnerPid) { "running pid $rp" } else { 'NOT running (jobrunner.ps1 start)' })"
    foreach ($q in @(Get-QueuedJobs)) { Write-Host "  queued  $($q.Id) (pair $($q.Pair))" }
    if (Test-Path -LiteralPath "$JOBS\running") { foreach ($r in @(Get-ChildItem -LiteralPath "$JOBS\running" -Filter *.plan)) { Write-Host "  $((Get-JobStatus $r.BaseName).Text)  $($r.BaseName)" } }
    if (Test-Path -LiteralPath "$JOBS\done") { foreach ($dn in @(Get-ChildItem -LiteralPath "$JOBS\done" -Directory | Sort-Object Name | Select-Object -Last 10)) { $s = Get-JobStatus $dn.Name; if ($s.State -eq 'done') { Write-Host "  $($s.Text)  $($dn.Name)" } } }
    exit 0
  }
  $id = Resolve-JobId $Spec; if (-not $id) { Fail "job not found: $Spec" }
  $t0 = Get-Date; $prev = ''
  while ($true) {
    $s = Get-JobStatus $id
    if ($s.Text -ne $prev) { Say "job ${id}: $($s.Text)"; $prev = $s.Text }
    if ($s.State -eq 'done') { Write-Host "result: $($s.Dir)"; $s.Lines | ForEach-Object { Write-Host "  $_" }; exit $s.Rc }
    if ($s.State -eq 'unknown') { exit 4 }
    if (((Get-Date) - $t0).TotalSeconds + 2 -gt $Wait) { Write-Host "not finished yet; result folder when done: $($s.Dir)"; exit 3 }
    Start-Sleep -Seconds 2
  }
}
function Cmd-Timeline {
  $fm = "$G\ModWork\tools\flight\flightmerge.py"
  $out = if ($Report) { $Report } else { $r = Get-CurrentRun; if (-not $r) { $r = New-RunDir }; Join-Path $r 'timeline' }
  $roots = @()
  foreach ($k in @('A', 'B', 'E')) {
    $b = $SIDES[$k].Bridge
    if (-not (Test-Path -LiteralPath (Join-Path $b 'nola_debug\sessions'))) { continue }
    $roots += $b
    if (-not $DryRun -and (Get-SideProc $k)) { $o = Invoke-Dev $k 'fr dump timeline'; Say "$k fr dump: $o" }
  }
  if (-not $roots) { Fail 'no nola_debug\sessions under the pair 2 bridges (needs the debug DLL with flightrec=1)' }
  if (-not $DryRun) { Start-Sleep -Seconds 1 }
  $col = Join-Path $out 'dumps'
  & $UV run --no-project python -I $fm collect @roots --out $col --sessions 1
  if ($LASTEXITCODE -ne 0) { Fail "flightmerge collect failed ($LASTEXITCODE)" }
  & $UV run --no-project python -I $fm merge $col --out $out
  if ($LASTEXITCODE -ne 0) { Fail "flightmerge merge failed ($LASTEXITCODE)" }
  & $UV run --no-project python -I $fm query $col
  $q = $LASTEXITCODE
  Say "timeline: $out\timeline.json (open in ui.perfetto.dev), $out\timeline.txt, $out\queries.txt; query exit $q (2 = findings)"
  exit $q
}

$ACBONES = 'jnt_hips,jnt_spine_01,jnt_spine_03,jnt_neck,jnt_head,jnt_l_arm,jnt_l_fore_arm,jnt_l_hand,jnt_r_arm,jnt_r_fore_arm,jnt_r_hand,jnt_l_leg,jnt_l_foot,jnt_r_leg,jnt_r_foot'
$ACFOOT = 'jnt_l_foot,jnt_r_foot'
function Get-AnimActors($k) {
  $other = if ($k -eq 'A') { 'B' } else { 'A' }
  $ol = Get-Loc $other
  $o = Invoke-S2Dev $k @('find class:BP_AI_Human_C 400')
  $addrs = @([regex]::Matches($o, '(?m)^(0x[0-9a-fA-F]+)\s+BP_AI_Human_C\s+(?!.*Default__)') | ForEach-Object { $_.Groups[1].Value })
  if (-not $addrs.Count) { Fail "no BP_AI_Human_C avatar candidate on $k" }
  $r = Invoke-S2Dev $k @($addrs | ForEach-Object { "call $_ K2_GetActorLocation"; "get $_ bHidden" })
  $ls = @([regex]::Matches($r, 'X=(-?[0-9.eE+-]+) Y=(-?[0-9.eE+-]+) Z=(-?[0-9.eE+-]+)'))
  $hs = @([regex]::Matches($r, 'bHidden @\S+ = (true|false)'))
  $best = $null; $bd = 1e9
  for ($i = 0; $i -lt $addrs.Count; $i++) {
    if ($i -ge $ls.Count -or $i -ge $hs.Count -or $hs[$i].Groups[1].Value -eq 'true') { continue }
    $dx = [double]$ls[$i].Groups[1].Value - $ol[0]; $dy = [double]$ls[$i].Groups[2].Value - $ol[1]; $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
    if ($d -lt $bd) { $bd = $d; $best = $addrs[$i] }
  }
  if (-not $best -or $bd -gt 300) { Fail "no visible avatar within 3 m of the partner on $k (nearest $([int]$bd) cm)" }
  Say "avatar on ${k}: $best ($([int]$bd) cm from the partner's real pawn)"
  @{ SelfPawn = '0'; SelfMesh = '0'; AvPawn = ($best -replace '^0x', ''); AvMesh = '0' }
}
function Cmd-AnimCheck {
  $secs = if ($Spec) { [int]$Spec } else { 30 }
  $rd = Get-CurrentRun; if (-not $rd) { Fail "no current run folder: run 'harness.ps1 up -Reuse' first" }
  Budget-Count 'animcheck'
  [void](Check-Hold)
  $ac = "$G\ModWork\tools\animcheck"; . "$PSScriptRoot\planlib.ps1"; $out = New-UniqueDir $rd 'animcheck'
  New-Item -ItemType Directory -Force $out, "$H\tmp" | Out-Null
  $files = @{}
  foreach ($k in 'A', 'B') {
    if (-not (Get-SideProc $k)) { Fail "$k is not running" }
    $pl = Invoke-S2Dev $k @('plug reload animprobe')
    Say "animprobe on ${k}: $((($pl -replace '\s+', ' ')).Trim())"
    $a = Get-AnimActors $k
    $tag = $SIDES[$k].Tag
    $files[$k] = Join-Path $out "$tag.probe.jsonl"
    if (Test-Path -LiteralPath $files[$k]) { Remove-Item -LiteralPath $files[$k] -Force }
    $line = "$($secs + 4) 50 $($files[$k]) $tag $($a.SelfPawn) $($a.SelfMesh) $($a.AvPawn) $($a.AvMesh) $Plant $ACBONES $ACFOOT"
    [IO.File]::WriteAllText("$H\tmp\animprobe_cmd_$($SIDES[$k].Port).txt", $line, (New-Object Text.ASCIIEncoding))
  }
  $t0 = Get-Date
  Start-Sleep -Seconds 2
  $p = Read-Spec 'animcheck'
  if ($p.Errors.Count) { $p.Errors | ForEach-Object { Write-Host $_ }; Fail 'spec animcheck has parse errors' }
  $r = Invoke-Spec $p $rd "$out\report_spec.txt"
  $left = $secs + 3 - ((Get-Date) - $t0).TotalSeconds
  if ($left -gt 0) { Start-Sleep -Seconds ([int][Math]::Ceiling($left)) }
  foreach ($k in 'A', 'B') {
    $f = $files[$k]; $sz = -1
    for ($i = 0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 500; if (Test-Path -LiteralPath $f) { $n = (Get-Item -LiteralPath $f).Length; if ($n -gt 0 -and $n -eq $sz -and -not (Test-Path -LiteralPath "$H\tmp\animprobe_cmd_$($SIDES[$k].Port).txt")) { break }; $sz = $n } }
    if (-not (Test-Path -LiteralPath $f) -or (Get-Item -LiteralPath $f).Length -eq 0) { Fail "no animprobe samples from $k ($f)" }
    Say "$k samples: $((Get-Content -LiteralPath $f | Measure-Object -Line).Lines) lines, $([int]((Get-Item -LiteralPath $f).Length / 1024)) KB"
  }
  $ErrorActionPreference = 'Continue'
  $txt = (& $UV run --no-project python -I "$ac\cli.py" analyze "host=$($files.A)" "client=$($files.B)" --profile "$ac\examples\s2\profile.json" --avatar 'host_player=host:1>client:2' --avatar 'client_player=client:1>host:2' --assert 'glitches==0' --assert 'avatar.glitches==0' --assert 'avatar.wrong_facing==0' --html "$out\report.html" --json "$out\report.json" --label "animcheck $(Split-Path $rd -Leaf)" 2>&1 | ForEach-Object { "$_" })
  $rc = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  [IO.File]::WriteAllLines("$out\summary.txt", [string[]]$txt)
  $txt | ForEach-Object { Write-Host $_ }
  Say "animcheck: $(if ($rc -eq 0) { 'PASS' } else { 'FAIL' }) (cli exit $rc); report $out\report.html; summary $out\summary.txt; pre-screen only, screenshot proof still required"
  exit $rc
}
$script:LogOverride = @{ A = $LogA; B = $LogB }
$KEYS = @('A', 'B')
if ($Cmd.ToLower() -ne 'selftest') { if ($Clients -ge 2 -or ($Cmd.ToLower() -ne 'up' -and (Get-SideProc 'E'))) { $KEYS = @('A', 'B', 'E') } }
$script:Marks = @{}; $script:Vars = @{}; $script:ClsCache = @{}; $script:Alive = @{ A = $false; B = $false }
if ($Cmd.ToLower() -in 'scene', 'frame', 'shot', 'stage', 'face', 'aim', 'fire', 'hold', 'use', 'burst', 'equip', 'closeui', 'settime', 'plan') { . "$G\ModWork\tools\proofcam\harness_scene.ps1"; . "$H\scenes\lib\verbs.ps1" }
if ($Cmd.ToLower() -in 'par', 'scene', 'frame', 'shot', 'stage', 'face', 'aim', 'fire', 'hold', 'use', 'burst', 'up', 'run', 'reset', 'down', 'setflag', 'dllrestore', 'animcheck', 'plan', 'equip', 'closeui', 'settime' -and -not ($Cmd.ToLower() -eq 'plan' -and $Check) -and (Test-Path -LiteralPath $LOCK) -and (Test-Path -LiteralPath "$LOCK.cwd")) {
  $lockCwd = ([IO.File]::ReadAllText("$LOCK.cwd")).Trim()
  if ($lockCwd -and $lockCwd -ne (Get-Location).Path) { $li = Lock-Info; Fail "pair$Pair.lock is held by $(if ($li) { $li.Who } else { 'another worker' }) from $lockCwd, not from this session ($((Get-Location).Path)): wait with 'lock <name> -Wait' as its own command and run '$Cmd' only after it prints 'taken'" }
}
try { $cl = Lock-Info; Add-Content -LiteralPath "$H\runs\cmd.log" -Value ((Get-Date).ToString('s') + " $(if ($cl) { $cl.Who } else { '-' }) $Cmd $Spec$(if ($Check) { ' -Check' })") -Encoding ascii } catch { }
Enforce-Rules
function Read-AssertState($what, $k, $arg) {
  if ($env:S2H_ASSERT_FAKE) {
    $fk = [IO.File]::ReadAllText($env:S2H_ASSERT_FAKE) | ConvertFrom-Json
    switch ($what) {
      'state' { return $fk.$k }
      'flag' { $f = $fk.$k.flags; if ($null -eq $f) { return $null }; return $f.$arg }
      'peer' { return [pscustomobject]@{ Ok = [bool]$fk.peer; Detail = $(if ($fk.peer) { 'PEER UP on A and B' } else { 'no PEER UP (fake)' }) } }
      'detector' { return [bool]$fk.$k.detector }
      'ui' { return "$($fk.$k.ui)" }
      'quest' { $q = $fk.$k.quests; if ($null -eq $q) { return $null }; return $q.$arg }
      'savequest' { $q = $fk.$k.savequests; if ($null -eq $q) { return $null }; return $q.$arg }
      'calm' { return [pscustomobject]@{ Ok = [bool]$fk.calm; Detail = $(if ($fk.calm) { 'calm' } else { 'hostiles near A (fake)' }) } }
    }
    return $null
  }
  switch ($what) {
    'state' {
      $o = Invoke-Nbot $k @('state')
      if ("$o" -match '^\s*err') { throw "nbot $k state: $o" }
      $j = $o | ConvertFrom-Json
      try { $ia = Invoke-S2Dev $k @('call pawn IsAlive'); if ("$ia" -match 'ReturnValue = false') { $j | Add-Member -NotePropertyName dead -NotePropertyValue $true -Force } } catch { }
      return $j
    }
    'flag' {
      $f = Join-Path $SIDES[$k].Bridge 'flags.txt'
      if (-not (Test-Path -LiteralPath $f)) { return $null }
      foreach ($l in [IO.File]::ReadAllLines($f)) { if ($l -match ('^' + [regex]::Escape($arg) + '=(.*)$')) { return $Matches[1].Trim() } }
      return $null
    }
    'peer' {
      $det = @(); $ok = $true
      foreach ($s in 'A', 'B') {
        $p = LogPath $s
        if (-not (Test-Path -LiteralPath $p)) { $ok = $false; $det += "${s}: no log"; continue }
        $fs = [IO.File]::Open($p, 'Open', 'Read', 'ReadWrite, Delete')
        try {
          $n = [int][Math]::Min(8MB, $fs.Length); $b = New-Object byte[] $n; [void]$fs.Seek($fs.Length - $n, 'Begin'); $got = 0
          while ($got -lt $n) { $r = $fs.Read($b, $got, $n - $got); if ($r -le 0) { break }; $got += $r }
        } finally { $fs.Dispose() }
        $txt = [Text.Encoding]::UTF8.GetString($b, 0, $got)
        $up = $txt.LastIndexOf('NOLA PEER UP'); $left = $txt.LastIndexOf('PEER LEFT')
        if ($up -ge 0 -and $up -gt $left) { $det += "${s}: PEER UP" } else { $ok = $false; $det += "${s}: " + $(if ($left -gt $up) { 'PEER LEFT after the last PEER UP' } else { 'no PEER UP in the last 8 MB of the log' }) }
      }
      return [pscustomobject]@{ Ok = $ok; Detail = ($det -join '; ') }
    }
    'quest' {
      $o = Invoke-S2Dev $k @("json quest state $arg")
      $j = $null; try { $j = "$o" | ConvertFrom-Json } catch { }
      if (-not $j -or -not $j.ok) { return $null }
      return "$($j.data.state)"
    }
    'savequest' {
      $o = Invoke-SaveTool @('quests', $Save, '--node', $arg, '--json')
      $j = $null; try { $j = "$o" | ConvertFrom-Json } catch { }
      if (-not $j) { return $null }
      return "$($j.state)"
    }
    'detector' {
      $o = Invoke-S2Dev $k @('call pawn IsDetectorInHands')
      return ("$o" -match 'ReturnValue = true')
    }
    'ui' {
      $o = Invoke-S2Dev $k @('find class:W_Inventory_C 20')
      $open = @()
      foreach ($ln in ("$o" -split "`n")) {
        if ($ln -match '^(0x[0-9a-fA-F]+)\s+W_Inventory_C\s' -and $ln -notmatch 'Default__') {
          $r = Invoke-S2Dev $k @("call $($Matches[1]) IsInViewport", "call $($Matches[1]) IsVisible")
          if ("$r" -match 'ReturnValue = true[\s\S]*ReturnValue = true') { $open += 'InventoryNew' }
        }
      }      return ($open -join ',')
    }
    'calm' {
      $cm = [int]([double]$arg * 100)
      $sc = "$H\tmp\assert_calm_$cm.scene"; New-Item -ItemType Directory -Force "$H\tmp" | Out-Null
      [IO.File]::WriteAllText($sc, "scene assert_calm`r`nrequire nohostile $cm allow=Neutral`r`n", (New-Object Text.ASCIIEncoding))
      $a = @('scene', $sc, '-On', $k); if ($Pair -ne 2) { $a += @('-Pair', "$Pair") }
      $ErrorActionPreference = 'Continue'
      $o = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:PlanSelf @a 2>&1 | ForEach-Object { "$_" } | Out-String).Trim()
      $rc = $LASTEXITCODE
      $tail = (($o -split "`r?`n") | Where-Object { $_ } | Select-Object -Last 2) -join ' | '
      return [pscustomobject]@{ Ok = ($rc -eq 0); Detail = $tail }
    }
  }
  $null
}
function Verify-Equip($k, [int]$n) {
  . "$PSScriptRoot\planlib.ps1"
  $r = Wait-Equip $k $n { param($w, $kk, $x) Read-AssertState $w $kk $x } 3000
  if (-not $r.Ok) { Fail $r.Msg }
  Write-Host $r.Msg
}
function Set-GameTime($k, [string]$clock) {
  . "$PSScriptRoot\planlib.ps1"
  $c = ConvertTo-GameClock $clock
  if (-not $c) { Fail "settime: bad hour '$clock' (use 0-23 or HH:MM)" }
  if ($DryRun) { Say "settime ${k}: DRY $c"; return }
  if (-not (Get-SideProc $k)) { Fail "settime: $k is not running" }
  if (-not (Get-Command Wait-SceneResult -ErrorAction SilentlyContinue)) { . "$G\ModWork\tools\proofcam\harness_scene.ps1" }
  $o = Invoke-Nbot $k @("scene line time $c")
  if ($o -notmatch '^scene \S+ running') { Fail "settime ${k}: nbot said: $o" }
  $j = Wait-SceneResult $k 30
  $r = @($j.results)[-1]
  if (-not $r -or $r.result -ne 'PASS') { Fail "settime ${k}: game clock not set ($($j.state) $($r.result) $($r.detail))" }
  $parts = $c -split ':'; $vis = 'sun clock not touched'
  try {
    $f = Invoke-S2Dev $k @('find class:CustomConsoleManagerAA 20')
    $hit = ($f -split "`n") | Where-Object { $_ -match '^0x[0-9a-fA-F]+\s' -and $_ -notmatch 'Default__' } | Select-Object -First 1
    if ($hit) { $vis = "XSetWeatherTime: " + ((Invoke-S2Dev $k @("call $(($hit -split '\s+')[0]) XSetWeatherTime $([int]$parts[0]) $([int]$parts[1]) 0")) -replace '\s+', ' ').Trim() }
    else { $vis = 'sun clock not set (CustomConsoleManagerAA not found)' }
  } catch { $vis = "sun clock not set ($($_.Exception.Message))" }
  Say "settime ${k}: game clock $c ($($r.detail)); $vis"
}
function Set-DayAll {
  foreach ($k in 'A', 'B') { if ($DryRun -or (Get-SideProc $k)) { Set-GameTime $k '12:00' } }
}
function Cmd-Plan {
  if (-not $Spec) { Fail 'plan <file.plan> [-Check] [-OverBudget why]' }
  . "$PSScriptRoot\planlib.ps1"
  $steps = Read-Plan $Spec
  $lim = if ($OverBudget) { 3 } else { 2 }
  $errs = @(Test-Plan $steps $lim { param($n) try { $p = Read-Spec $n; if ($p.Errors.Count) { "$($p.Errors.Count) parse errors, first: $($p.Errors[0])" } } catch { "$($_.Exception.Message)" } })
  $errs += @(Test-PlanShotSteps $steps)
  if ($errs.Count) { $errs | ForEach-Object { Write-Host "PLAN INVALID: $_" }; Write-Host "PLAN INVALID: $($errs.Count) problem(s), nothing was run"; exit 2 }
  foreach ($pw in @(Get-PlanWarnings $steps)) { Write-Host "PLAN WARN: $pw" }
  $nr = @($steps | Where-Object { $_.Verb -in 'run', 'animcheck' -and -not ($_.Verb -eq 'run' -and $_.Tokens[1] -eq 'calm') }).Count
  if ($Check) { Write-Host "PLAN OK: $(@($steps).Count) steps, $nr live runs (budget $lim), no lock needed for -Check"; exit 0 }
  $li = Lock-Info; if (-not $li) { Fail "plan needs the pair lock: 'lock <name>' first" }
  [void](Check-Hold)
  $pd0 = "$H\runs\" + (Get-Date -Format 'yyyyMMdd_HHmmss'); $pd = $pd0; $pdi = 1
  while ($true) { if (-not (Test-Path -LiteralPath $pd)) { try { New-Item -ItemType Directory -Path $pd -ErrorAction Stop | Out-Null; break } catch { } }; $pdi++; if ($pdi -gt 60) { Fail "cannot create a plan dir under $H\runs" }; $pd = "${pd0}_$pdi" }
  $script:PlanLog = "$pd\plan.log"; $script:PlanDir = $pd; $script:PlanOut = ''; $script:PlanSelf = Join-Path $PSScriptRoot 'harness.ps1'
  Start-PairWatchdog $pd -Force
  $ex = {
    param($s)
    $t = @($s.Tokens); $v = $s.Verb
    $fzf = "$($script:PlanDir)\FROZEN.txt"
    $fzx = { if (Test-Path -LiteralPath $fzf) { $fz = (Get-Content -LiteralPath $fzf -Raw).Trim(); Add-Content -LiteralPath $script:PlanLog -Value ((Get-Date).ToString('s') + ' ABORT ' + $fz) -Encoding ascii; Write-Host "ABORT: $fz"; [Console]::Error.WriteLine($fz); exit 3 } }
    & $fzx
    switch ($v) {
      'wait' { $wend = (Get-Date).AddMilliseconds([int]([double]$t[1] * 1000)); while ((Get-Date) -lt $wend) { & $fzx; Start-Sleep -Milliseconds ([int][Math]::Max(1, [Math]::Min(1000, ($wend - (Get-Date)).TotalMilliseconds))) }; return 0 }
      'mark' { Add-Content -LiteralPath $script:PlanLog -Value ((Get-Date).ToString('s') + ' MARK ' + (($t | Select-Object -Skip 1) -join ' ')) -Encoding ascii; return 0 }
      'out' { New-Item -ItemType Directory -Force $t[1] | Out-Null; $script:PlanOut = (Resolve-Path -LiteralPath $t[1]).Path; return 0 }
      'setflag' { Set-FlagLine $t[1].ToUpper() $t[2] ((($t | Select-Object -Skip 3)) -join ' '); return 0 }
      's2dev' { $sk = $t[1].ToUpper(); $sc = Resolve-Cls $sk (($t | Select-Object -Skip 2) -join ' '); $o = Invoke-S2Dev $sk @($sc); Write-Host $o; if ("$o" -match 'cannot resolve object') { return 1 }; return 0 }
      'givew' { $go = @(& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\tools\give.ps1" -Who $t[1].ToUpper() -Sid $t[2] -Pair $Pair 2>&1 | ForEach-Object { "$_" }); $gc = $LASTEXITCODE; Write-Host "givew $($t[2]): $($go | Select-Object -Last 1)"; if ($gc -ne 0 -or ($go -match 'sid too long|VV read|VV entry')) { return 1 }; return 0 }
      'assert' { return (Invoke-PlanAssertStep $s { param($w, $k, $x) Read-AssertState $w $k $x }) }
    }
    $a = @($t); if ($v -eq 'nbot') { $a = @('par', (($t | Select-Object -Skip 1) -join ' ')) }
    if ($v -eq 'shot') { $a = @(Convert-ShotPlanArgs (Parse-ShotTokens @($t | Select-Object -Skip 1))) }
    if ($script:PlanOut -and $v -in $PLAN_OUTVERBS) { $a += @('-Run', $script:PlanOut) }
    if ($Pair -ne 2) { $a += @('-Pair', "$Pair") }
    if ($OverBudget -and $v -in 'run', 'animcheck') { $a += @('-OverBudget', $OverBudget) }
    $ErrorActionPreference = 'Continue'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:PlanSelf @a 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath "$($script:PlanDir)\step_$('{0:D2}' -f $s.N).txt" | Write-Host
    $rc = $LASTEXITCODE
    if ($rc -eq 3 -and (Test-Path -LiteralPath "$($script:PlanDir)\FROZEN.txt")) { $fz = (Get-Content -LiteralPath "$($script:PlanDir)\FROZEN.txt" -Raw).Trim(); Add-Content -LiteralPath $script:PlanLog -Value ((Get-Date).ToString('s') + ' ABORT ' + $fz) -Encoding ascii; Write-Host "ABORT: $fz"; [Console]::Error.WriteLine($fz); exit 3 }
    return $rc
  }
  $env:S2H_PLAN = "$PID"
  try { $r = Invoke-PlanSteps $steps $ex $script:PlanLog } finally { Remove-Item Env:\S2H_PLAN -ErrorAction SilentlyContinue }
  Write-Host "plan log: $($script:PlanLog)"
  exit $(if ($r.Ok) { 0 } else { 1 })
}
if ($Cmd.ToLower() -in 'run', 'up', 'reset') { $wr = Get-CurrentRun; if (-not $wr) { $wr = "$H\runs\watch_" + (Get-Date -Format 'yyyyMMdd_HHmmss') }; Start-PairWatchdog $wr }
switch ($Cmd.ToLower()) {
  'watchdog' { Cmd-Watchdog }
  'par' {
    if (-not $Spec) { Fail 'par "<nbot lines separated by ;, @A/@B prefix = one side>" [-Wait <ms to watch positions + FPS>] [-Report out.log]' }
    $pa = @{ Lines = $Spec; For = $Wait; Fps = $Wait; Out = $(if ($Report) { $Report } else { '' }) }; if ($Pair -eq 3) { $pa.Pair = 3 }
    & "$H\par.ps1" @pa
  }
  'scene' { Cmd-Scene }
  'stage' { Cmd-Stage }
  { $_ -in 'face', 'aim', 'fire', 'hold', 'use' } {
    Do-Verb @(@($Cmd, $Spec, $Arg2) | Where-Object { $_ })
    if ($Cmd.ToLower() -eq 'use' -and $Spec -match '^equip([0-9])$') { Verify-Equip (St-Side 'B') ([int]$Matches[1]) }
  }
  'burst' { Cmd-Burst }
  'equip' { Cmd-Equip }
  'closeui' { Cmd-CloseUi }
  'settime' { Cmd-SetTime }
  'frame' { Cmd-Frame }
  'shot' { Cmd-Shot }
  'up' { Cmd-Up }
  'run' { Cmd-Run }
  'reset' { Cmd-Reset }
  'down' { Cmd-Down }
  'boot' { $rd = if ($Spec) { $Spec } else { Get-CurrentRun }; if (-not $rd) { Fail 'boot [<run dir>]' }; $bt = Get-BootText $rd; $bt | ForEach-Object { Write-Host $_ }; [IO.File]::WriteAllLines("$rd\boot.txt", [string[]]$bt) }
  'lock' { if ($Spec -like 'job:*' -and $env:S2H_JOBRUNNER -ne '1') { Fail "lock ${Spec}: job: names belong to the jobrunner; lock under your own worker name" }; if ($Spec -in @('status','lockstatus')) { Cmd-LockStatus } elseif ($PairAny) { Cmd-LockAny } else { Cmd-Lock } }
  'unlock' { if ($Spec -like 'job:*' -and $env:S2H_JOBRUNNER -ne '1') { Fail "unlock ${Spec}: a running job's lock is released only by the jobrunner; never unlock another worker" }; Cmd-Unlock }
  'lockstatus' { Cmd-LockStatus }
  'status' { Cmd-Status }
  'dllstatus' { Cmd-DllStatus }
  'dllrestore' { Cmd-DllRestore }
  'dllbaseline' { Cmd-DllBaseline }
  'list' { Cmd-List }
  'parse' { $p = Read-Spec $Spec; $c = Count-Spec $p; $p.Steps | ForEach-Object { Write-Host ("{0,4} {1,-10} {2,-2} {3}" -f $_.Line, $_.Kind, $_.Side, $_.Text) }; $p.Errors | ForEach-Object { Write-Host "ERROR $_" }; Write-Host "steps=$($p.Steps.Count) auto=$($c.Auto) manual=$($c.Manual) errors=$($p.Errors.Count)"; exit $(if ($p.Errors.Count) { 1 } else { 0 }) }
  'selftest' { Cmd-Selftest }
  'timeline' { Cmd-Timeline }
  'animcheck' { Cmd-AnimCheck }
  'plan' { Cmd-Plan }
  'submit' { Cmd-Submit }
  'job' { Cmd-Job }
  'idlecap' { Cmd-IdleCap }
  'census' {
    $out = if ($Report) { $Report } else { $r = Get-CurrentRun; if (-not $r) { $r = New-RunDir }; Join-Path $r ('census_' + (Get-Date -Format 'HHmmss')) }
    $cr = Invoke-Census $out $(if ($Spec) { $Spec } else { $null })
    Say "census: $out (census_<side>.json, worlddiff.txt, worlddiff.tsv, worlddiff_logs.txt) exit $($cr.Rc) (1 = divergence or NOLA INV)"
    exit $cr.Rc
  }
  'savestate' { Cmd-SaveState }
  'saves' { Cmd-Saves }
  'logcheck' {
    $a = @('run', '--no-project', 'python', '-I', "$G\ModWork\tools\logcat\check_log_specs.py")
    if ($Spec) { $a += @('--only', $Spec) }
    if ($Full) { $a += '-v' }
    & uv @a
    exit $LASTEXITCODE
  }
  'logexpand' {
    if (-not $Spec) { Write-Host 'logexpand <log name from logs.tsv>'; exit 2 }
    & uv run --no-project python -I "$G\ModWork\tools\logcat\check_log_specs.py" --expand $Spec
    exit $LASTEXITCODE
  }
  'triage' {
    $t = "$G\ModWork\tools\triage\triage.ps1"
    $ta = @{}
    if ($Full) { $ta.Full = $true }
    if ($Spec) { & $t $Spec @ta } else { & $t @ta }
    exit $LASTEXITCODE
  }
  'proofdiff' {
    $t = "$G\ModWork\tools\proofdiff\proofdiff.ps1"
    if (-not $Spec) { Write-Host 'proofdiff <before.png|folder|dirA> [-Other after.png|dirB] [-Report outdir]'; exit 2 }
    $o = if ($Report) { $Report } else { Join-Path $env:TEMP 'proofdiff' }
    if (Test-Path -LiteralPath $Spec -PathType Leaf) {
      if (-not $Other) { Write-Host 'proofdiff <before.png> -Other <after.png>'; exit 2 }
      & $t pair $Spec $Other --out $o
    } elseif ($Other) {
      & $t dirs $Spec $Other --out $o --montage
    } else {
      & $t folder $Spec --out $o --montage
    }
    exit $LASTEXITCODE
  }
  default {
    @'
harness.ps1 (STALKER 2 co-op live test harness, TEST PAIR 2 (default): host A = C:\S2DevRootHost2 bridge C, client B = C:\S2DevRoot2 bridge D)
  lock <name> -Pair any [-Wait s]   join both pair queues, take whichever is free first (prints 'taken pair N'); later calls and plan default to that pair, -Pair 2 / -Pair 3 overrides
  -Pair 3 on any command: TEST PAIR 3 (host A = C:\S2DevRootHostP3 bridge P3A S2Dev 27065, client B = C:\S2DevRootP3 bridge P3B S2Dev 27066, UDP 7795/7794, pair3.lock, runs\p3_*); no -Clients 2, no hot reload, no par
  third instance: -Clients 2 on up adds client E (C:\S2DevRoot3, bridge E, S2Dev 27064, Saved_client3) and sets maxclients on the host (-MaxClients, default 3); run/down/status/quit include E while it runs
  up       [-Clients 1|2] [-MaxClients n] [-MinFreeGB 10 (free RAM needed before E starts; pair 3 default 13 = one pair measured 11.0 GB + 2)] [-Dll main.dll] [-Pak p.pak] [-PakHost p.pak] [-PakClient p.pak] [-Flags f | -FlagsHost f -FlagsClient f] [-Set k=v[,k2=v2]]
           [-Save <master dir>] [-NoSave] [-NoHost (client only, for ghostpeer.py)] [-ClientSave keep|master] [-HostTimeout s] [-ClientTimeout s] [-JoinTimeout s] [-WorldRegex rx] [-JoinRegex rx]
  plan     <file.plan> [-Check] [-OverBudget why]   one line per step = the same verbs (up run stage aim fire hold use burst shot frame animcheck setflag s2dev <A|B|E> nbot wait <s> mark <label> out <dir>), '?' prefix = keep going on failure; -Check validates only (verbs, DLL/spec files, run count <= budget), no lock; plan itself needs the lock, logs runs\<ts>\plan.log, stops at the first failure, leaves the pair up
  submit   <file.plan> -Name <worker> [-Pair any|2|3] [-OverBudget why]   default way to test live: runs 'plan -Check' (refused = nothing queued, exit 2), queues the plan in jobs\queue and prints 'id: <job id>'; jobrunner.ps1 (no AI) runs queued jobs back to back on whichever pair is free (lock job:<name>), never down between jobs
  job      [<id>] [-Wait s]   job status: queued (position) | running pairN | done rc N | failed rc N at step ...; prints the result folder jobs\done\<id> (plan.log, rc.txt, out.txt, result.txt); exit = job rc when done, 3 = not finished yet; no id = list
  idlecap  [-Pair 2|3]   release a lock whose holder ran no pair command for 4 min (cmd.log) while someone is queued and no harness pair process of that pair runs (lock.log IDLE-RELEASED); waiters' 'lock' does the same check
  run      <spec> [-Run <run dir>] [-Report file] [-KeepGoing] [-DryRun -LogA f -LogB f]
  down     [-Kill] [-QuitTimeout s]   (also kills orphan CrashReportClient of pair 2, which locks the Mods DLL)
  -Set rule: repeat -Set or join with commas; a comma splits only when the next text starts with name= (-Set a=1,b=2 -> two lines); a value may hold commas (-Set list=x,y,z -> one line list=x,y,z). The restore of the master save into Saved_*2 logs every file it removes.
  status | list | parse <spec> | selftest [-NoWinTests]
  logcheck [<spec file substring>] [-Full]   offline: every expect/con/dev regex of the specs and plans must match a printable string of the C++ log catalog (tools\logcat); exit 1 on a dead regex
  timeline [-Report outdir] [-DryRun]       flight recorder (debug DLL): devcmd 'fr dump timeline' on each running side, collect the newest nola_debug\sessions folder of bridges C/D/E, merge into <run>\timeline (timeline.json for ui.perfetto.dev, timeline.txt, queries.txt); exit 2 when a query finds a tag sent but never received/handled
  savestate [<testsave name|all>]   write testsave\<name>\STATE.md (position, game time, DLC, main quests with active nodes) from the save via savetool.py; 'up' prints its head; saves = list testsave\* with the first STATE.md line
  census [<dir with census_host.json, census_client.json...>] [-Report outdir]   dev DLL: devcmd 'census' on every running side, copy each bridge census.json to <run>\census_<time>\census_<tag>.json,
           run tools\worlddiff (snapshot diff by family + NOLA WH first divergence of the UE4SS logs); on a divergence sends 'frtrig worlddiff' (flight recorder); exit 1 = divergence or NOLA INV; with a dir: offline diff only
  logexpand <log name>                       the regex of one catalog entry (logs.tsv)
  scene <name|file.scene> [-On C|D|E] [-DryRun]   P6 scene executor: scenes\<name>.scene steps run in game by the nbot s2dev plugin (dev DLL, devcmd=1 for census steps);
           '@C|@D|@E step' picks the instance per line, 'key F 150' and 'shot <name> [key=k] [all=1]' run on the harness; stops at the first FAIL;
           <run>\scene_<name>_<time>\report.txt + scene.json (one PASS/FAIL row per step with detail and data); exit 1 on FAIL
  par "<nbot cmds ; separated, '@A cmd' / '@B cmd' = one side>" [-Wait <ms: poll both positions every 0.5 s + tick FPS>] [-Report out.log]   no-focus input: the same request files reach both games' nbot at once
           (verbs: move holdmove rot look goto tp jump crouch equip melee fire aim 1|0 reload use heal [sid..] state ping ...); e.g. par "holdmove 1 0 4000;aim 1" -Wait 2500; keysend only for UI keys
  stage side|front|back [-Dist m (4)] [-Yaw deg] [-At x,y,z]   st1: B on open floor facing -Yaw, A at -Dist m on that side of B, A frames the whole body; retries until the avatar is rendered; prints ready (scenes\lib\stage.scene)
  face <peer|x,y,z> | aim <peer|x,y,z|forward> [-Ads] [-Wait s hold] | fire <n> [-Hip|-Ads] | hold <KEY> <ms> | use <jump|crouch|stand|melee|reload|interact|heal|ads|unads|equipN|KEY>   st1: act on B (-On A for A); exact yaw/pitch, no mouse loops
  burst <n> <gap ms> [-Do "fire 3 ads"] [-StartOn <regex> [-StartLog A|B|s2dev:A|s2dev:B] [-StartTimeout 8]] [-Pre N] [-Sync]   st1: A frames n PNGs (wincap) while the -Do action runs, into <run>\burst_<time>\C_NN.png
  frame [<census key|$var|peer|me>] [-On C|D|E] [-Dist m (also moves the pawn to a stand point at m)] [-Fov deg]   turn the local view to a target (control rotation)
  shot [<name>] [-On C,D,E]  default = every running side  [-At <ms from now | unix ms>] [-Key <census key|$var|peer|me>]   synced proof shot: every side projects the target box at the same
           wall time and the window is captured (PrintWindow, gfxcapture fallback); <side>_<name>_<md5>.png + .json sidecar (target, distance, screen box,
           WasRecentlyRendered, capture skew, advisory Windows OCR vs nola_texts.tsv) + montage_<name>.png with the box drawn
  triage [<crash folder|.dmp|run dir>] [-Full]   10-line crash summary with s2rag names and mod PDB symbols (default: newest harness run with crashes)
  proofdiff <before.png|folder|dirA> [-Other after.png|dirB] [-Report outdir]   odiff pixel diff + A|B|diff montage (default out: %TEMP%\proofdiff)
  -Dll safety: up -Dll first saves the ORIGINAL main.dll of every root it touches (md5 + copy in runs\dllbak, outside the Mods folders) and down (or a failed up) puts it
           back and verifies the md5. A source file that is a root's live main.dll is refused. An original that is not the baseline md5 (baseline_dll.txt) is refused unless -AcceptBase.
  dllstatus                        md5 of main.dll on A, B, E vs the baseline, and any pending restore
  dllrestore [-Dll clean.dll]      no -Dll: finish a pending restore; with -Dll (games stopped): copy that clean DLL to A, B and E
  dllbaseline -Dll clean.dll       record the clean DLL md5 that up -Dll checks the originals against
  Input (keysend.ps1): every key/hold/tap/mouse is aimed at the process of that side (pid, never the window title), the window is focused and the foreground is verified
           before every action; a step that cannot reach its window ends ERR instead of OK.
Spec lines (A = host, B = client):
  spec <name> | needs <text> | note <text> | manual <id> <text>
  mark [start]                       anchor = log ends now (every action step also re-anchors), start = whole logs
  wait <s>
  expect <A|B|E> <regex> within <s>    first matching line written after the anchor; (?<name>..) captures, ${name} reuses (escaped)
  expect_not <A|B|E> <regex> during <s>
  con <A|B|E> <console command>        s2dev con (KismetSystemLibrary ExecuteConsoleCommand / cvar)
  s2dev <A|B|E> <raw s2dev command> [=> <regex>]   @cls:<Class> = first live object of that class
  dev <A|B|E> <devcmd line> [=> <regex>]           bridge s2cmd.txt (non-release DLL, devcmd=1)
  cfg <A|B|E> <flag> <value>           live flag through devcmd       setflag <A|B|E> <flag> <value>   edit the bridge flags.txt
  aim <A|B|E> <pitch> <yaw> | lookat <A|B|E> <x> <y> <z> | tp <A|B|E> <x> <y> <z> | tp <A|B|E> near <A|B|E> <cm> (waits up to 6 s for Walking + stable z; a fall > 15 m or no floor steps back to the start and the step is ERR)
  spawn <A|B|E> <SID> <n> near <A|B|E> <m> | give <A|B|E> <ItemSID> <n> | hp <A|B|E> <value>
  key <A|B|E> <KEY> [ms] (hold) | tap <A|B|E> <KEY> [KEY ...] | mouse <A|B|E> <dx> [dy] (relative) | focus <A|B|E> | shot <A|B|E> <name>
  quit <A|B|E> (con quit, WM_CLOSE, then kill) | kill <A|B|E> | launch <A|B|E> (waits for the world line)
  census                               world census of every running side + worlddiff; PASS = no divergence and no due NOLA INV (dev DLL)
  every run adds one row per side: FAIL when a 'NOLA INV <rule>' invariant break was logged after the spec started (dev DLL, devinv=1)
'@ | Write-Host
  }
}

$global:LASTEXITCODE = 0
