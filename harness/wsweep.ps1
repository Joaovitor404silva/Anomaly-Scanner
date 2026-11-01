param([string[]]$Weapons = @('GunViper_PP','GunM860_SG','GunSVDM_SP','GunPKP_MG'), [int]$Pair = 2, [string]$Dll = '')
$ErrorActionPreference = 'Stop'
$Weapons = @($Weapons | ForEach-Object { $_ -split '[,; ]+' } | Where-Object { $_ })
$H = 'C:\modding\s2harness'
Set-Content "$PSScriptRoot\tools\pair.txt" "$Pair"
$deadline = (Get-Date).AddMinutes(90)
while ($true) {
  $ErrorActionPreference = 'Continue'
  $lo = (& "$PSScriptRoot\harness.ps1" lock wsweep -Pair $Pair 2>&1 | ForEach-Object { "$_" }) -join "`n"
  $ErrorActionPreference = 'Stop'
  $lo
  if ($lo -match "pair$Pair\.lock (taken|already held) by wsweep") { break }
  if ((Get-Date) -gt $deadline) { throw 'wsweep: lock wait over 90 min' }
  Start-Sleep -Seconds 30
}
try {
  if ($Dll) {
    $boot = "$H\plans\wsweep_boot.plan"
    $pre = Get-Content "$H\plans\tb1.plan" | Select-Object -Skip 1 | Where-Object { $_ -notmatch '^(out|shot|nbot) ' }
    @("up -Day -Calm -Dll $Dll -ClientSave master") + $pre | Set-Content $boot -Encoding ascii
    & "$PSScriptRoot\harness.ps1" plan $boot -Pair $Pair
  }
  $first = $true
  foreach ($w in $Weapons) {
    if (-not $first -or -not $Dll) { & "$PSScriptRoot\harness.ps1" plan "$H\plans\wsweep_reset.plan" -Pair $Pair }
    $first = $false
    $given = $false
    foreach ($g in 1..3) {
      Set-Content "$PSScriptRoot\tools\pair.txt" "$Pair"
      $ErrorActionPreference = 'Continue'
      $gout = & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\tools\give.ps1" -Who B -Sid $w -Pair $Pair 2>&1 | ForEach-Object { "$_" }
      $grc = $LASTEXITCODE
      $ErrorActionPreference = 'Stop'
      if ($grc -eq 0 -and -not ($gout -match 'sid too long|VV read|VV entry')) { $gout | Select-Object -Last 1; $given = $true; break }
      "give $w try $g failed rc $grc : $($gout | Select-Object -First 2)"; Start-Sleep -Seconds 8
    }
    if (-not $given) { "$w skipped: give failed"; continue }
    $p = "$H\plans\wsweep_$w.plan"
    (Get-Content "$H\plans\wsweep_one.tpl") -replace '\{W\}', $w | Set-Content $p -Encoding ascii
    & "$PSScriptRoot\harness.ps1" plan $p -Pair $Pair
    "$w done rc $LASTEXITCODE"
  }
} finally { & "$PSScriptRoot\harness.ps1" unlock wsweep -Pair $Pair }

$global:LASTEXITCODE = 0
