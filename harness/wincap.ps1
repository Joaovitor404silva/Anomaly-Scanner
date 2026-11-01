param(
    [Parameter(Mandatory = $true)][string]$Out,
    [int]$ProcId = 0,
    [string]$Title = '',
    [int]$Count = 1,
    [int]$GapMs = 100
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('WinCap' -as [type])) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WinCap {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
}
'@
}
$p = if ($ProcId) { Get-Process -Id $ProcId } else { Get-Process | Where-Object { $_.MainWindowTitle -like "*$Title*" -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }
if (-not $p -or $p.MainWindowHandle -eq 0) { throw "no window for pid=$ProcId title='$Title'" }
$h = $p.MainWindowHandle
if ([WinCap]::IsIconic($h)) { throw "window $h is minimized; PrintWindow cannot render it" }
$r = New-Object WinCap+RECT
[void][WinCap]::GetWindowRect($h, [ref]$r)
$w = $r.R - $r.L; $hh = $r.B - $r.T
$t0 = [DateTime]::UtcNow
for ($i = 0; $i -lt $Count; $i++) {
    $bmp = New-Object System.Drawing.Bitmap $w, $hh
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $tcap = [DateTime]::UtcNow
    $dc = $g.GetHdc()
    $ok = [WinCap]::PrintWindow($h, $dc, 2)
    $g.ReleaseHdc($dc); $g.Dispose()
    $f = if ($Count -gt 1) { $Out -replace '\.png$', ('_{0:D2}.png' -f $i) } else { $Out }
    $part = "$f.part"
    $bmp.Save($part, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    [IO.File]::SetLastWriteTimeUtc($part, $tcap)
    Move-Item -LiteralPath $part -Destination $f -Force
    try { $chk = [System.Drawing.Image]::FromFile($f); $chk.Dispose() } catch { throw "frame $f does not decode: $($_.Exception.Message)" }
    Write-Output "$f ok=$ok ${w}x${hh} pid=$($p.Id)"
    if ($i -lt $Count - 1) { $nap = ($t0.AddMilliseconds(($i + 1) * $GapMs) - [DateTime]::UtcNow).TotalMilliseconds; if ($nap -gt 0) { Start-Sleep -Milliseconds ([int]$nap) } }
}

$global:LASTEXITCODE = 0
