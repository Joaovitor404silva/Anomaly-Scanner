param([ValidateSet(1, 2, 3)][int]$Pair = 1, [switch]$Check)
$ErrorActionPreference = 'Stop'
$R = @{ 1 = @{ client = @('C:\S2DevRoot', 'Saved_client', 'B'); host = @('C:\S2DevRootHost', 'Saved', 'A') }
        2 = @{ client = @('C:\S2DevRoot2', 'Saved_client2', 'D'); host = @('C:\S2DevRootHost2', 'Saved_host2', 'C') }
        3 = @{ client = @('C:\S2DevRootP3', 'Saved_client_p3', 'P3B'); host = @('C:\S2DevRootHostP3', 'Saved_host_p3', 'P3A') } }[$Pair]
$OUT = 'D:\modding\offline\crashes'; New-Item -ItemType Directory -Force $OUT | Out-Null
$LK = 'C:\s2coop_inst\relaunch.lock'
function Alive($root) { Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like "$root\Stalker2\*" } }
$dead = @($R.Keys | Where-Object { -not (Alive $R[$_][0]) })
if (-not $dead) { "pair$Pair OK: both games running"; exit 0 }
if (-not $Check) {
  if (Test-Path $LK) {
    if (((Get-Date) - (Get-Item $LK).LastWriteTime).TotalMinutes -lt 10) { "RELAUNCH IN PROGRESS by: $(Get-Content $LK\who.txt -EA SilentlyContinue). Wait for it, then check again."; exit 3 }
    Remove-Item $LK -Recurse -Force
  }
  New-Item -ItemType Directory $LK | Out-Null; "$env:USERNAME $(Get-Date -Format HH:mm:ss) pid $PID" | Set-Content "$LK\who.txt"
}
try {
  $stop = $false
  foreach ($role in $dead) {
    $root, $saved, $side = $R[$role]
    $cd = Get-ChildItem "$env:LOCALAPPDATA\Stalker2\$saved\Crashes" -Directory -EA SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $err = '-'; $top = 'no-crash-folder'; $frames = @()
    if ($cd -and ((Get-Date) - $cd.LastWriteTime).TotalMinutes -lt 30) {
      $x = Get-Content "$($cd.FullName)\CrashContext.runtime-xml" -Raw -EA SilentlyContinue
      if ($x -match '<ErrorMessage>([^<]*)') { $err = $Matches[1].Trim() }
      $frames = @([regex]::Matches($x, '<CallStack>([^<]*)') | ForEach-Object { $_.Groups[1].Value -split "`r?`n" } | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^ntdll' } | Select-Object -First 8)
      $mods = @([regex]::Matches($x, '<CallStack>([^<]*)') | ForEach-Object { $_.Groups[1].Value -split "`r?`n" } | ForEach-Object { ($_.Trim() -split ' ')[0] } | Where-Object { $_ -and $_ -notmatch '^ntdll' } | Select-Object -Unique)
      $g = $frames | Where-Object { $_ -match 'Shipping 0x[0-9a-f]+ \+ ([0-9a-f]+)' } | Select-Object -First 1
      if ($g -match '\+ ([0-9a-f]+)') { $top = "exe+0x$($Matches[1])" } elseif ($frames) { $top = 'nosym:' + ($mods -join '>') }
    }
    $log = Get-Content "$root\Stalker2\Binaries\Win64\ue4ss\UE4SS.log" -Tail 40 -EA SilentlyContinue
    $t = Get-Date -Format 'yyyyMMdd_HHmmss'
    @("crash $t pair$Pair $role ($side) root=$root", "error: $err", "top: $top", "crash folder: $($cd.FullName)", "frames:") + $frames + @('', 'last 40 UE4SS.log lines:') + $log |
      Set-Content "$OUT\${t}_$role.txt" -Encoding utf8
    $cid = if ($cd) { $cd.Name } else { '-' }
    $known = @(Get-Content "$OUT\crashlog.txt" -EA SilentlyContinue | Where-Object { ($_ -split "`t")[5] -eq $cid -and $cid -ne '-' }).Count
    if (-not $known) { "$t`tpair$Pair`t$role`t$top`t$err`t$cid" | Add-Content "$OUT\crashlog.txt" -Encoding utf8 }
    $since = (Get-Date).AddHours(-2)
    $same = @(Get-Content "$OUT\crashlog.txt" | Where-Object { $p = $_ -split "`t"; $p.Count -ge 4 -and $p[3] -eq $top -and $top -ne 'no-crash-folder' -and
      [datetime]::ParseExact($p[0], 'yyyyMMdd_HHmmss', $null) -gt $since } | ForEach-Object { $p = $_ -split "`t"; if ($p.Count -ge 6) { $p[5] } else { $p[0] } } | Select-Object -Unique).Count
    "DEAD: $role ($side)  error: $err  top: $top  same top in 2 h: $same  report: $OUT\${t}_$role.txt"
    if ($same -ge 3) { $stop = $true; "STOP (circuit breaker): 3 identical crashes at $top. Do not relaunch; analyze the dump ($($cd.FullName)\UEMinidump.dmp) with the RE skill and tell the supervisor." }
  }
  if ($Check -or $stop) { exit $(if ($stop) { 4 } else { 0 }) }
  if ($Pair -eq 3) { "pair3: dead $($dead -join ','); relaunch with: harness.ps1 -Pair 3 up (launch_pair has no pair 3)"; exit 6 }
  & "$PSScriptRoot\launch_pair.ps1" -Pair $Pair
  $still = @($R.Keys | Where-Object { -not (Alive $R[$_][0]) })
  if ($still) { "RELAUNCH FAILED for: $($still -join ',')"; exit 5 } else { "RELAUNCHED: $($dead -join ',') back in the world" }
} finally { if (-not $Check) { Remove-Item $LK -Recurse -Force -EA SilentlyContinue } }

$global:LASTEXITCODE = 0
