param(
  [Parameter(Mandatory = $true)][int]$ProcId,
  [ValidateSet('tap', 'hold', 'mouse', 'focus')][string]$Mode = 'tap',
  [string]$Keys = '',
  [string]$Vk = '',
  [int]$Ms = 100,
  [int]$Dx = 0,
  [int]$Dy = 0,
  [int]$DelayMs = 150,
  [int]$FocusTries = 12,
  [int]$SettleMs = 400
)
$ErrorActionPreference = 'Stop'
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class KS {
  delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint fl, UIntPtr ex);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint c, uint t);
  [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
  public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
  public static string Txt(IntPtr h) { var s = new StringBuilder(256); GetWindowText(h, s, 256); return s.ToString(); }
  public static uint Pid(IntPtr h) { uint p; GetWindowThreadProcessId(h, out p); return p; }
  public static IntPtr Find(uint pid) {
    IntPtr best = IntPtr.Zero; long bestScore = -1;
    EnumWindows(delegate (IntPtr h, IntPtr l) {
      if (Pid(h) != pid || !IsWindowVisible(h) || GetWindow(h, 4) != IntPtr.Zero) return true;
      string c = Cls(h);
      if (c.Contains("IME") || c == "tooltips_class32") return true;
      RECT r; GetWindowRect(h, out r);
      long area = (long)Math.Max(0, r.R - r.L) * Math.Max(0, r.B - r.T);
      if (IsIconic(h)) area = 1;
      long score = area + (c == "UnrealWindow" ? 1000000000L : 0);
      if (score > bestScore) { bestScore = score; best = h; }
      return true;
    }, IntPtr.Zero);
    return best;
  }
  [DllImport("user32.dll")] static extern IntPtr GetAncestor(IntPtr h, uint f);
  static bool Has1(IntPtr h) { IntPtr f = GetForegroundWindow(); return f != IntPtr.Zero && (f == h || GetAncestor(f, 3) == h); }
  public static bool Has(IntPtr h, uint pid) { for (int i = 0; i < 4; i++) { if (Has1(h)) return true; System.Threading.Thread.Sleep(40); } return false; }
  public static string Fg() { IntPtr f = GetForegroundWindow(); if (f == IntPtr.Zero) return "none"; return "hwnd=0x" + f.ToInt64().ToString("X") + " pid=" + Pid(f) + " class=" + Cls(f) + " title='" + Txt(f) + "'"; }
  public static bool Focus(IntPtr h, uint pid, int tries) {
    for (int i = 0; i < tries; i++) {
      if (!IsWindow(h)) return false;
      if (IsIconic(h)) ShowWindow(h, 9);
      if (Has(h, pid)) return true;
      if (i > 0) { keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero); }
      IntPtr f = GetForegroundWindow(); uint dummy; uint ft = f == IntPtr.Zero ? 0 : GetWindowThreadProcessId(f, out dummy);
      uint me = GetCurrentThreadId(); bool at = false;
      if (ft != 0 && ft != me) at = AttachThreadInput(me, ft, true);
      BringWindowToTop(h); SetForegroundWindow(h);
      if (at) AttachThreadInput(me, ft, false);
      System.Threading.Thread.Sleep(150);
      if (Has(h, pid)) return true;
    }
    return Has(h, pid);
  }
}
"@
function Done($code, $msg) { Write-Output $msg; exit $code }
$tpid = [uint32]$ProcId
if (-not (Get-Process -Id $ProcId -ErrorAction SilentlyContinue)) { Done 2 "NOPROC pid=$ProcId is not running" }
$h = [KS]::Find($tpid)
if ($h -eq [IntPtr]::Zero) { Done 2 "NOWINDOW pid=$ProcId has no visible top-level window" }
$tag = "pid=$ProcId hwnd=0x$($h.ToInt64().ToString('X')) class=$([KS]::Cls($h))"
$KMX = New-Object Threading.Mutex($false, 'Global\s2harness_keysend'); $kgot = $false; try { $kgot = $KMX.WaitOne(20000) } catch [Threading.AbandonedMutexException] { $kgot = $true }; if (-not $kgot) { Done 6 "BUSY $tag another keysend held the input for 20 s" }
if (-not [KS]::Focus($h, $tpid, $FocusTries)) { Done 3 "NOFOCUS $tag; foreground is $([KS]::Fg())" }
Start-Sleep -Milliseconds $SettleMs
if (-not [KS]::Has($h, $tpid)) { Done 3 "NOFOCUS $tag lost the foreground during the settle; foreground is $([KS]::Fg())" }
function Ensure-Focus($why) {
  if ([KS]::Has($h, $tpid)) { return }
  if (-not [KS]::Focus($h, $tpid, 4)) { Done 4 "FOCUSLOST $tag $why; foreground is $([KS]::Fg())" }
  Start-Sleep -Milliseconds 150
}
function Press($v, $up) {
  if ($v -eq 1) { [KS]::mouse_event($(if ($up) { 4 } else { 2 }), 0, 0, 0, [UIntPtr]::Zero); return }
  if ($v -eq 2) { [KS]::mouse_event($(if ($up) { 16 } else { 8 }), 0, 0, 0, [UIntPtr]::Zero); return }
  [KS]::keybd_event([byte]$v, [byte][KS]::MapVirtualKey([uint32]$v, 0), $(if ($up) { 2 } else { 0 }), [UIntPtr]::Zero)
}
function Chord($tok) { @($tok -split '[+,]' | Where-Object { $_ } | ForEach-Object { [Convert]::ToInt32($_, 16) }) }
switch ($Mode) {
  'focus' { Done 0 "OK focus $tag" }
  'tap' {
    foreach ($tok in @($Keys -split '\s+' | Where-Object { $_ })) {
      $vks = Chord $tok
      Ensure-Focus "before tap $tok"
      foreach ($v in $vks) { Press $v $false; Start-Sleep -Milliseconds 40 }
      Start-Sleep -Milliseconds 60
      [array]::Reverse($vks)
      $lostTap = -not [KS]::Has($h, $tpid)
      if ($lostTap) { [void][KS]::Focus($h, $tpid, 4); Start-Sleep -Milliseconds 100 }
      foreach ($v in $vks) { Press $v $true; Start-Sleep -Milliseconds 40 }
      if ($lostTap) { Done 4 "FOCUSLOST $tag between the down and the up of tap $tok; foreground was $([KS]::Fg())" }
      Start-Sleep -Milliseconds $DelayMs
    }
    Done 0 "OK tap $Keys $tag"
  }
  'hold' {
    $vks = Chord $Vk
    if (-not $vks.Count) { Done 5 "BADARGS hold needs -Vk" }
    if ($Dx -ne 0 -or $Dy -ne 0) { [KS]::mouse_event(1, $Dx, $Dy, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300 }
    foreach ($v in $vks) { Press $v $false; Start-Sleep -Milliseconds 20 }
    $t0 = Get-Date; $lost = $false
    while (((Get-Date) - $t0).TotalMilliseconds -lt $Ms) {
      Start-Sleep -Milliseconds ([int][Math]::Max(10, [Math]::Min(100, $Ms - ((Get-Date) - $t0).TotalMilliseconds)))
      if (-not [KS]::Has($h, $tpid)) { $lost = $true; break }
    }
    [array]::Reverse($vks)
    if ($lost) { [void][KS]::Focus($h, $tpid, 4); Start-Sleep -Milliseconds 100 }
    foreach ($v in $vks) { Press $v $true; Start-Sleep -Milliseconds 20 }
    if ($lost) { Done 4 "FOCUSLOST $tag during the hold after $([int]((Get-Date) - $t0).TotalMilliseconds) ms; foreground is $([KS]::Fg())" }
    Done 0 "OK hold $Vk $Ms ms $tag"
  }
  'mouse' {
    if ($Vk) {
      $vks = Chord $Vk
      foreach ($v in $vks) { Press $v $false; Start-Sleep -Milliseconds 40 }
      Start-Sleep -Milliseconds ([Math]::Max(40, $Ms))
      foreach ($v in $vks) { Press $v $true; Start-Sleep -Milliseconds 40 }
    }
    if ($Dx -ne 0 -or $Dy -ne 0) { Ensure-Focus 'before the mouse move'; [KS]::mouse_event(1, $Dx, $Dy, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 100 }
    Done 0 "OK mouse dx=$Dx dy=$Dy $tag"
  }
}

$global:LASTEXITCODE = 0
