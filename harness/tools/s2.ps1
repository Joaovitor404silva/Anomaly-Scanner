param([int]$Port, [string[]]$Lines, [int]$TimeoutMs = 30000)
$f = Join-Path $env:TEMP ('sv2_s2dev_' + [guid]::NewGuid().ToString('N') + '.txt')
[IO.File]::WriteAllLines($f, $Lines)
$env:CRAWLER_PORT = "$Port"; $env:S2DEV_PORT = "$Port"; $env:CRAWLER_TIMEOUT = "$TimeoutMs"
$ErrorActionPreference = 'Continue'
try { $o = (& node "$(if ($env:GAME_CRAWLER) { $env:GAME_CRAWLER } else { 'D:\modding\Game-Crawler' })\crawler.js" -f $f 2>&1 | ForEach-Object { "$_" } | Out-String) } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
((($o -split "`r?`n") | Where-Object { $_ -notmatch '^> ' }) -join "`n").Trim()

$global:LASTEXITCODE = 0
