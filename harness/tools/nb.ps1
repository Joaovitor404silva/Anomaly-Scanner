param([int]$Port, [string[]]$Lines, [int]$TimeoutMs = 30000)
$io = "C:\modding\s2harness\bench\io\$Port"
$id = [guid]::NewGuid().ToString('N').Substring(0, 12)
$tmp = "$io\req_$id.tmp"; $req = "$io\req_$id.txt"; $res = "$io\res_$id.txt"
[IO.File]::WriteAllText($tmp, (($Lines -join "`n") + "`n"), (New-Object Text.ASCIIEncoding))
Move-Item -LiteralPath $tmp $req -Force
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
  if (Test-Path -LiteralPath $res) { Start-Sleep -Milliseconds 30; $t = [IO.File]::ReadAllText($res); Remove-Item -LiteralPath $res -Force -ErrorAction SilentlyContinue; return $t.Trim() }
  Start-Sleep -Milliseconds 50
}
Remove-Item -LiteralPath $req -Force -ErrorAction SilentlyContinue
"timeout"

$global:LASTEXITCODE = 0
