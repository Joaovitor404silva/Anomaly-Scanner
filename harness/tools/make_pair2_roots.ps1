param([switch]$Force, [string]$Payload = 'D:\modding\release\v1.2.1\payload')
$ErrorActionPreference = 'Stop'
$g = 'C:\Program Files (x86)\Steam\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
$roots = @(@{ Root = 'C:\S2DevRootHost2'; Mods = "$g\ModWork\nola\Mods_p2" }, @{ Root = 'C:\S2DevRoot2'; Mods = "$g\ModWork\nola\ModsClient_p2" })
function Link($p, $t) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType HardLink -Path $p -Target $t | Out-Null } }
function Junc($p, $t) { if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Junction -Path $p -Target $t | Out-Null } }
function NewDir($p) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
foreach ($r in $roots) {
  $Root = $r.Root
  if ($Root -notmatch '^C:\\S2DevRoot(Host)?2$') { throw "refusing root $Root" }
  $run = Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$Root\*" }
  if ($run) { throw "a game runs from $Root (pid $($run.ProcessId))" }
  if ((Test-Path -LiteralPath $Root) -and $Force) { & cmd.exe /c rmdir /s /q "$Root"; if (Test-Path -LiteralPath $Root) { throw "could not remove $Root" } }
  if (Test-Path -LiteralPath $Root) { Write-Host "keep $Root"; continue }
  NewDir $Root
  Junc "$Root\Engine" "$g\Engine"; Junc "$Root\DLC1" "$g\DLC1"
  foreach ($f in Get-ChildItem -LiteralPath $g -File) { Link "$Root\$($f.Name)" $f.FullName }
  NewDir "$Root\Stalker2"; Junc "$Root\Stalker2\Plugins" "$g\Stalker2\Plugins"; NewDir "$Root\Stalker2\Content"
  foreach ($d in Get-ChildItem -LiteralPath "$g\Stalker2\Content" -Directory) { if ($d.Name -ne 'Paks') { Junc "$Root\Stalker2\Content\$($d.Name)" $d.FullName } }
  $dp = "$Root\Stalker2\Content\Paks"; NewDir $dp
  foreach ($f in Get-ChildItem -LiteralPath "$g\Stalker2\Content\Paks" -File) { Link "$dp\$($f.Name)" $f.FullName }
  NewDir "$dp\~mods"
  $sw = "$g\Stalker2\Binaries\Win64"; $dw = "$Root\Stalker2\Binaries\Win64"; NewDir $dw
  foreach ($f in Get-ChildItem -LiteralPath $sw -File) { if ($f.Name -notin 'dwmapi.dll', 'Stalker2-Win64-Shipping.exe') { Link "$dw\$($f.Name)" $f.FullName } }
  foreach ($n in 'D3D12', 'DML') { if (Test-Path -LiteralPath "$sw\$n") { Junc "$dw\$n" "$sw\$n" } }
  & "$PSScriptRoot\use_crawler.ps1" -Roots $Root
  Copy-Item -LiteralPath "$Payload\dwmapi.dll" "$dw\dwmapi.dll"
  & robocopy "$Payload\ue4ss" "$dw\ue4ss" /E /XD Mods /NFL /NDL /NJH /NJS | Out-Null
  $ini = "$dw\ue4ss\UE4SS-settings.ini"
  $t = (Get-Content -LiteralPath $ini) -replace '^ModsFolderPath\s*=.*$', "ModsFolderPath = $($r.Mods)"
  [IO.File]::WriteAllLines($ini, [string[]]$t)
  if (Test-Path -LiteralPath $r.Mods) { Remove-Item -LiteralPath $r.Mods -Recurse -Force }
  & robocopy "$Payload\ue4ss\Mods" $r.Mods /E /NFL /NDL /NJH /NJS | Out-Null
  Copy-Item -LiteralPath "$Payload\paks\zzzzzz_Nola_P.pak" "$dp\~mods\zzzzzz_Nola_P.pak"
  Write-Host "built $Root mods $($r.Mods)"
}

$global:LASTEXITCODE = 0
