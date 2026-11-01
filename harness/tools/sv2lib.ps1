[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$SV2 = $PSScriptRoot
$PAIR = if ($env:SV2_PAIR) { [int]$env:SV2_PAIR } elseif (Test-Path "$SV2\pair.txt") { [int](Get-Content "$SV2\pair.txt") } else { 3 }
if ($PAIR -eq 2) { $PA = 27063; $PB = 27062; $RA = 'C:\S2DevRootHost2'; $RB = 'C:\S2DevRoot2'; $SA = 'Saved_host2'; $SB = 'Saved_client2' } else { $PA = 27065; $PB = 27066; $RA = 'C:\S2DevRootHostP3'; $RB = 'C:\S2DevRootP3'; $SA = 'Saved_host_p3'; $SB = 'Saved_client_p3' }
function S2([int]$p, [string[]]$l) { & "$SV2\s2.ps1" -Port $p -Lines $l }
function NB([int]$p, [string[]]$l) { & "$SV2\nb.ps1" -Port $p -Lines $l }
function GamePid([string]$root) { (Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$root*" } | Select-Object -First 1).ProcessId }
function PidA { GamePid $RA }
function PidB { GamePid $RB }
function FixCfg {
  foreach ($d in $SA, $SB) {
    $f = "$env:LOCALAPPDATA\Stalker2\$d\CustomizeControls.cfg"; $t = [IO.File]::ReadAllText($f); $n = ([regex]::Matches($t, "(?m)^(\t+Key = )F(\r?)$")).Count
    [IO.File]::WriteAllText($f, [regex]::Replace($t, "(?m)^(\t+Key = )F(\r?)$", '${1}I${2}'), (New-Object Text.UTF8Encoding($true)))
    $m = 0
    foreach ($g in "$env:LOCALAPPDATA\Stalker2\$d\GameSettings\AppliedSettingsWin64.cfg", "$env:LOCALAPPDATA\Stalker2\$d\GameSettings\AppliedSettings.cfg") {
      [void](New-Item -ItemType Directory -Force "$SV2\cfgbak"); $bk = "$SV2\cfgbak\$d.$(Split-Path $g -Leaf)"; if (-not (Test-Path $bk)) { Copy-Item $g $bk }
      $s = [IO.File]::ReadAllText($g); $m += ([regex]::Matches($s, 'ShowTutorials = true')).Count
      [IO.File]::WriteAllText($g, $s.Replace('ShowTutorials = true', 'ShowTutorials = false'), (New-Object Text.UTF8Encoding($true)))
    }
    "$d inventory F->I $n, ShowTutorials true->false $m"
  }
}
function Cap([int]$procId, [string]$out) { & powershell -NoProfile -ExecutionPolicy Bypass -File C:\modding\s2harness\wincap.ps1 -ProcId $procId -Out $out 2>&1 | Select-Object -Last 1 }
function Key([int]$procId, [string]$hex) { & powershell -NoProfile -ExecutionPolicy Bypass -File C:\modding\s2harness\keysend.ps1 -ProcId $procId -Mode tap -Keys $hex 2>&1 | Select-Object -Last 1 }
function Mgr([int]$p, [string]$cls) { $o = S2 $p @("find class:$cls 5"); foreach ($ln in ($o -split "`n")) { if ($ln -match '^(0x[0-9a-f]+)\s' -and $ln -notmatch 'Default__') { return $Matches[1] } } }
function U16Hex([string]$s) { (([Text.Encoding]::Unicode.GetBytes($s) + @(0, 0)) | ForEach-Object { '{0:x2}' -f $_ }) -join '' }
function VVPrep([int]$p, [string]$sid) {
  $vv = Mgr $p 'CustomConsoleManagerVV'
  $o = S2 $p @("rd $vv+0xa8 16")
  if ($o -notmatch '^\s*[0-9a-f]+\s+((?:[0-9a-f]{2}\s){16})') { throw "VV read: $o" }
  $bb = $Matches[1].Trim() -split '\s+' | ForEach-Object { [Convert]::ToByte($_, 16) }
  $arr = [BitConverter]::ToUInt64([byte[]]$bb, 0); $cnt = [BitConverter]::ToInt32([byte[]]$bb, 8)
  $e = S2 $p @(('rd 0x{0:x} 16' -f $arr))
  if ($e -notmatch '^\s*[0-9a-f]+\s+((?:[0-9a-f]{2}\s){16})') { throw "VV entry read: $e" }
  $eb = $Matches[1].Trim() -split '\s+' | ForEach-Object { [Convert]::ToByte($_, 16) }
  $sptr = [BitConverter]::ToUInt64([byte[]]$eb, 0); $num = [BitConverter]::ToInt32([byte[]]$eb, 8); $max = [BitConverter]::ToInt32([byte[]]$eb, 12)
  $ptr0 = $sptr; $max0 = $max; $swap = $false
  if (($sid.Length + 1) -gt $max) {
    for ($i = 1; $i -lt $cnt -and -not $swap; $i++) {
      $ei = S2 $p @(('rd 0x{0:x} 16' -f ($arr + 16 * $i)))
      if ($ei -notmatch '^\s*[0-9a-f]+\s+((?:[0-9a-f]{2}\s){16})') { continue }
      $ib = $Matches[1].Trim() -split '\s+' | ForEach-Object { [Convert]::ToByte($_, 16) }
      $im = [BitConverter]::ToInt32([byte[]]$ib, 12)
      if (($sid.Length + 1) -le $im) { $sptr = [BitConverter]::ToUInt64([byte[]]$ib, 0); $max = $im; $swap = $true }
    }
  }
  $old = S2 $p @(('rd 0x{0:x} {1}' -f $sptr, ($max * 2)))
  [pscustomobject]@{ VV = $vv; Arr = $arr; Cnt = $cnt; Str = $sptr; Num = $num; Max = $max; Old = $old; Sid = $sid; Swap = $swap; Ptr0 = $ptr0; Max0 = $max0 }
}
function VVGive([int]$p, $v) {
  if (($v.Sid.Length + 1) -gt $v.Max) { throw 'sid too long for the slot' }
  $origHex = (($v.Old -split "`n") | ForEach-Object { if ($_ -match '^\s*[0-9a-f]+\s+((?:[0-9a-f]{2}\s){1,16})') { $Matches[1].Trim() -replace '\s', '' } }) -join ''
  $le64 = { param($x) (([BitConverter]::GetBytes([uint64]$x)) | ForEach-Object { '{0:x2}' -f $_ }) -join '' }
  $le32 = { param($x) (([BitConverter]::GetBytes([int32]$x)) | ForEach-Object { '{0:x2}' -f $_ }) -join '' }
  $pre = @(); $post = @()
  if ($v.Swap) {
    $pre = @(('wr 0x{0:x} {1}' -f $v.Arr, (& $le64 $v.Str)), ('wr 0x{0:x} {1}' -f ($v.Arr + 12), (& $le32 $v.Max)))
    $post = @(('wr 0x{0:x} {1}' -f $v.Arr, (& $le64 $v.Ptr0)), ('wr 0x{0:x} {1}' -f ($v.Arr + 12), (& $le32 $v.Max0)))
  }
  $r = S2 $p (@(
    ('wr 0x{0:x} {1}' -f $v.Str, (U16Hex $v.Sid))) + $pre + @(
    ('wr 0x{0:x} {1}' -f ($v.Arr + 8), ('{0:x2}000000' -f ($v.Sid.Length + 1))),
    ("wr $($v.VV)+0xb0 01000000"),
    "call $($v.VV) XGiveWeaponWithAttaches",
    ("wr $($v.VV)+0xb0 " + ('{0:x2}000000' -f $v.Cnt)),
    ('wr 0x{0:x} {1}' -f ($v.Arr + 8), ('{0:x2}000000' -f $v.Num))) + $post + @(
    ('wr 0x{0:x} {1}' -f $v.Str, $origHex.Substring(0, [Math]::Min($origHex.Length, $v.Max * 4)))))
  $r
}
function SidHandle([int]$p, $v) {
  $r = S2 $p @(('wr 0x{0:x} {1}' -f $v.Str, (U16Hex $v.Sid)), ('wr 0x{0:x} {1}' -f ($v.Arr + 8), ('{0:x2}000000' -f ($v.Sid.Length + 1))), ('xcall exe+0x2638d06 exe+0xb120760 0x{0:x} 0' -f $v.Arr))
  $origHex = (($v.Old -split "`n") | ForEach-Object { if ($_ -match '^\s*[0-9a-f]+\s+((?:[0-9a-f]{2}\s){1,16})') { $Matches[1].Trim() -replace '\s', '' } }) -join ''
  [void](S2 $p @(('wr 0x{0:x} {1}' -f ($v.Arr + 8), ('{0:x2}000000' -f $v.Num)), ('wr 0x{0:x} {1}' -f $v.Str, $origHex.Substring(0, [Math]::Min($origHex.Length, $v.Max * 4)))))
  if ($r -match 'eax=(\d+)') { return [uint32]$Matches[1] }
  $r
}
function EquipId([int]$p, [string]$id, [int]$slot) { S2 $p @("xcall exe+0x34f84f2 [exe+0xa2da4b0] $id $slot 0") }
function Slots([int]$p) {
  $o = S2 $p @('rd [[pawn+0x650]+0x678]+0x1d0 408')
  $b = New-Object System.Collections.Generic.List[byte]
  foreach ($ln in ($o -split "`n")) { if ($ln -match '^\s*([0-9a-fA-F]{8,16})\s+((?:[0-9a-fA-F]{2}\s){1,16})') { foreach ($h in ($Matches[2].Trim() -split '\s+')) { $b.Add([Convert]::ToByte($h, 16)) } } }
  $a = $b.ToArray(); $r = @()
  for ($i = 0; $i -lt 17 -and ($i * 0x18 + 12) -le $a.Length; $i++) { $r += ('{0}:{1:x8}' -f $a[$i * 0x18], [BitConverter]::ToUInt32($a, $i * 0x18 + 8)) }
  $r -join ' '
}
