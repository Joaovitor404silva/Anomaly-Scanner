param([string[]]$Roots = @('C:\S2DevRootHost2', 'C:\S2DevRoot2', 'C:\S2DevRoot3', 'C:\S2DevRootHostP3', 'C:\S2DevRootP3'), [string]$Crawler = $(if ($env:GAME_CRAWLER) { $env:GAME_CRAWLER } else { 'D:\modding\Game-Crawler' }))
$ErrorActionPreference = 'Stop'
$g = 'C:\Program Files (x86)\Steam\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
$stock = "$g\Stalker2\Binaries\Win64\Stalker2-Win64-Shipping.exe"
$proxy = "$Crawler\bin\proxy\version.dll"
if (-not (Test-Path -LiteralPath $proxy)) { throw "no proxy at $proxy (run src\build.bat in Game Crawler)" }
foreach ($Root in $Roots) {
  if ($Root -notmatch '^C:\\S2DevRoot') { throw "refusing root $Root" }
  $dw = "$Root\Stalker2\Binaries\Win64"
  if (-not (Test-Path -LiteralPath $dw)) { Write-Host "skip $Root (no root)"; continue }
  $run = Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$Root\*" }
  if ($run) { throw "a game runs from $Root (pid $($run.ProcessId))" }
  $exe = "$dw\Stalker2-Win64-Shipping.exe"
  if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
  New-Item -ItemType HardLink -Path $exe -Target $stock | Out-Null
  if (Test-Path -LiteralPath "$dw\S2Dev.dll") { Remove-Item -LiteralPath "$dw\S2Dev.dll" -Force }
  Copy-Item -LiteralPath $proxy "$dw\version.dll" -Force
  [IO.File]::WriteAllText("$dw\crawler_home.txt", $Crawler)
  Write-Host "$Root uses Game Crawler ($Crawler)"
}

$global:LASTEXITCODE = 0
