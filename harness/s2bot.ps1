param([Parameter(Mandatory)][string]$Cmd, [Parameter(ValueFromRemainingArguments)][string[]]$A)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class SB {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
 [StructLayout(LayoutKind.Sequential)] public struct PT { public int X, Y; }
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetDpiForSystem();
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
 [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint fl, UIntPtr ex);
 [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t);
}
"@
[SB]::SetProcessDPIAware() | Out-Null
$proc = Get-CimInstance Win32_Process -Filter "Name='Stalker2-Win64-Shipping.exe'" | Where-Object { $_.ExecutablePath -like (($(if ($env:S2BOT_ROOT) { $env:S2BOT_ROOT } else { 'C:\S2DevRoot' })) + '\*') } | Select-Object -First 1
if (-not $proc) { throw 'dev game not running' }
$h = (Get-Process -Id $proc.ProcessId).MainWindowHandle
function Front { [SB]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [SB]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero); [SB]::ShowWindow($h, 9) | Out-Null; [SB]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 250 }
function Origin { $p = New-Object SB+PT; [SB]::ClientToScreen($h, [ref]$p) | Out-Null; $p }
$vk = @{ Enter = 0x0D; Esc = 0x1B; Space = 0x20; Up = 0x26; Down = 0x28; Left = 0x25; Right = 0x27; Tab = 0x09; Shift = 0x10; Ctrl = 0x11; F5 = 0x74; F9 = 0x78 }
function Vk([string]$k) { if ($vk.ContainsKey($k)) { [byte]$vk[$k] } else { [byte][char]$k.ToUpper() } }
function Down([byte]$v) { [SB]::keybd_event($v, [byte][SB]::MapVirtualKey($v, 0), 0, [UIntPtr]::Zero) }
function Up([byte]$v) { [SB]::keybd_event($v, [byte][SB]::MapVirtualKey($v, 0), 2, [UIntPtr]::Zero) }
switch ($Cmd) {
  'shot' {
    $out = if ($A) { $A[0] } else { "$env:TEMP\s2bot_shot.png" }
    if ([SB]::IsIconic($h)) { [SB]::ShowWindow($h, 4) | Out-Null; Start-Sleep -Milliseconds 300 }
    $r = New-Object SB+RECT; [SB]::GetClientRect($h, [ref]$r) | Out-Null; $o = Origin
    $wr = New-Object SB+RECT; [SB]::GetWindowRect($h, [ref]$wr) | Out-Null
    $s = [SB]::GetDpiForSystem() / 96.0
    $full = New-Object System.Drawing.Bitmap([int][math]::Ceiling(($wr.R - $wr.L) / $s), [int][math]::Ceiling(($wr.B - $wr.T) / $s)); $fg = [System.Drawing.Graphics]::FromImage($full)
    $dc = $fg.GetHdc(); [SB]::PrintWindow($h, $dc, 2) | Out-Null; $fg.ReleaseHdc($dc); $fg.Dispose()
    $b = New-Object System.Drawing.Bitmap([int]$r.R, [int]$r.B); $g = [System.Drawing.Graphics]::FromImage($b)
    $src = New-Object System.Drawing.Rectangle([int][math]::Round(($o.X - $wr.L) / $s), [int][math]::Round(($o.Y - $wr.T) / $s), [int][math]::Round($r.R / $s), [int][math]::Round($r.B / $s))
    $g.DrawImage($full, (New-Object System.Drawing.Rectangle(0, 0, [int]$r.R, [int]$r.B)), $src, [System.Drawing.GraphicsUnit]::Pixel); $g.Dispose(); $full.Dispose()
    $b.Save($out); "shot $out $($r.R)x$($r.B)"
  }
  'click' { Front; $o = Origin; [SB]::SetCursorPos($o.X + [int]$A[0], $o.Y + [int]$A[1]) | Out-Null; Start-Sleep -Milliseconds 120
            [SB]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 90; [SB]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero); "click $($A[0]),$($A[1])" }
  'key'   { Front; foreach ($k in $A) { $v = Vk $k; Down $v; Start-Sleep -Milliseconds 80; Up $v; Start-Sleep -Milliseconds 200 }; "keys $($A -join ' ')" }
  'hold'  { Front; $v = Vk $A[0]; Down $v; Start-Sleep -Milliseconds ([int]$A[1]); Up $v; "held $($A[0]) $($A[1]) ms" }
}


$global:LASTEXITCODE = 0
