param([Parameter(Mandatory)][string]$Out)
$ErrorActionPreference = 'Stop'
$g = 'C:\Program Files (x86)\Steam\steamapps\common\S.T.A.L.K.E.R. 2 Heart of Chornobyl'
$rows = New-Object System.Collections.Generic.List[string]
function Head($p) { $fs = [IO.File]::OpenRead($p); try { $n = [Math]::Min($fs.Length, 4MB); $b = New-Object byte[] $n; [void]$fs.Read($b, 0, $n); ([BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($b)) -replace '-', '') } finally { $fs.Close() } }
foreach ($d in "$g\Stalker2\Binaries\Win64", 'C:\S2DevRoot\Stalker2\Binaries\Win64', 'C:\S2DevRootHost\Stalker2\Binaries\Win64') {
  Get-ChildItem -LiteralPath $d -File | ForEach-Object { $rows.Add("full`t$($_.FullName)`t$($_.Length)`t$((Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash)") }
}
foreach ($d in "$g\Stalker2\Content\Paks", 'C:\S2DevRoot\Stalker2\Content\Paks', 'C:\S2DevRootHost\Stalker2\Content\Paks') {
  if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -File -Recurse | ForEach-Object { $rows.Add("head4m`t$($_.FullName)`t$($_.Length)`t$($_.LastWriteTimeUtc.Ticks)`t$(Head $_.FullName)") } }
}
Get-ChildItem -LiteralPath $g -File | ForEach-Object { $rows.Add("full`t$($_.FullName)`t$($_.Length)`t$((Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash)") }
[IO.File]::WriteAllLines($Out, [string[]]($rows | Sort-Object))
"rows $($rows.Count) -> $Out"

$global:LASTEXITCODE = 0
