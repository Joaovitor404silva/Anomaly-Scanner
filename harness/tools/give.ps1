param([ValidateSet('A', 'B')][string]$Who = 'A', [string]$Sid = 'GunAK74_ST', [int]$Pair = 0)
if ($Pair) { $env:SV2_PAIR = "$Pair" }
. "$PSScriptRoot\sv2lib.ps1"
$p = if ($Who -eq 'A') { $PA } else { $PB }
"before: $(Slots $p)"
$v = VVPrep $p $Sid
"vv=$($v.VV) cnt=$($v.Cnt) num=$($v.Num) max=$($v.Max)"
VVGive $p $v | Select-Object -Last 3
Start-Sleep -Seconds 1
"after: $(Slots $p)"

$global:LASTEXITCODE = 0
