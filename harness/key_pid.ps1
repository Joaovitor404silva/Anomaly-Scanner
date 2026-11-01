param([int]$ProcId, [string[]]$Keys, [int]$DelayMs = 150)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class KP { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
 [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint fl, UIntPtr ex);
 [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t); }
"@
$p = Get-Process -Id $ProcId
[KP]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [KP]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
[KP]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
[KP]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400
foreach ($tok in $Keys) {
  $vks = @($tok -split '[+,]' | ForEach-Object { [Convert]::ToByte($_, 16) })
  foreach ($vk in $vks) { [KP]::keybd_event($vk, [byte][KP]::MapVirtualKey($vk, 0), 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 40 }
  Start-Sleep -Milliseconds 60
  [array]::Reverse($vks)
  foreach ($vk in $vks) { [KP]::keybd_event($vk, [byte][KP]::MapVirtualKey($vk, 0), 2, [UIntPtr]::Zero); Start-Sleep -Milliseconds 40 }
  Start-Sleep -Milliseconds $DelayMs
}

$global:LASTEXITCODE = 0
