param([string]$Log, [string]$Title = 'Stalker2 selftest window', [int]$X = 100, [int]$Y = 100)
Add-Type -AssemblyName System.Windows.Forms
$sw = [Diagnostics.Stopwatch]::StartNew()
$script:Log = $Log
function W($s) { [IO.File]::AppendAllText($script:Log, ('{0} {1}' -f [int]$sw.ElapsedMilliseconds, $s) + "`r`n") }
$f = New-Object Windows.Forms.Form
$f.Text = $Title; $f.StartPosition = 'Manual'; $f.Location = New-Object Drawing.Point($X, $Y); $f.Size = New-Object Drawing.Size(360, 220); $f.KeyPreview = $true
$f.Add_KeyDown({ param($s, $e) W ('D ' + ('{0:X2}' -f [int]$e.KeyCode)); $e.Handled = $true })
$f.Add_KeyUp({ param($s, $e) W ('U ' + ('{0:X2}' -f [int]$e.KeyCode)); $e.Handled = $true })
$f.Add_MouseDown({ param($s, $e) W ('M ' + $e.Button) })
$f.Add_Shown({ W 'READY' })
[void][Windows.Forms.Application]::Run($f)

$global:LASTEXITCODE = 0
