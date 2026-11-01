if (-not ('S2GW' -as [type])) {
  Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class S2GW {
  public delegate bool EP(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EP p, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr w, EP p, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder l);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
  static string Txt(IntPtr h) { var s = new StringBuilder(8192); SendMessage(h, 0x0D, (IntPtr)8192, s); return s.ToString(); }
  public static List<string> Dialogs(uint pid) {
    var r = new List<string>();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h) && Cls(h) == "#32770") {
        var parts = new List<string>(); parts.Add(Txt(h));
        EnumChildWindows(h, (c, l2) => { var t = Txt(c); if (t.Length > 0) parts.Add(Cls(c) + ":" + t.Replace("\r", " ").Replace("\n", " ")); return true; }, IntPtr.Zero);
        r.Add(string.Join(" | ", parts));
      }
      return true;
    }, IntPtr.Zero);
    return r;
  }
  public static int Command(uint pid, int id) {
    int n = 0;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h) && Cls(h) == "#32770") { PostMessage(h, 0x0111, (IntPtr)id, IntPtr.Zero); n++; }
      return true;
    }, IntPtr.Zero);
    return n;
  }
  public static int Click(uint pid, string button) {
    int n = 0;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h) && Cls(h) == "#32770") {
        EnumChildWindows(h, (c, l2) => { if (Cls(c) == "Button" && Txt(c).Replace("&", "") == button) { PostMessage(c, 0x00F5, IntPtr.Zero, IntPtr.Zero); n++; } return true; }, IntPtr.Zero);
      }
      return true;
    }, IntPtr.Zero);
    return n;
  }
}
"@
}
function Get-GameBlocker([int]$GamePid) {
  $r = New-Object System.Collections.ArrayList
  foreach ($d in [S2GW]::Dialogs([uint32]$GamePid)) { [void]$r.Add([pscustomobject]@{ Kind = 'dialog'; Pid = $GamePid; Text = $d }) }
  foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='WerFault.exe' or Name='CrashReportClient.exe'" -ErrorAction SilentlyContinue)) {
    $cl = "" + $p.CommandLine
    if ($p.Name -eq 'WerFault.exe' -and $cl -match "-p\s+$GamePid(\s|$)") { $t = @([S2GW]::Dialogs([uint32]$p.ProcessId)) -join ' || '; [void]$r.Add([pscustomobject]@{ Kind = 'werfault'; Pid = $p.ProcessId; Text = "WerFault $cl $t" }) }
    if ($p.Name -eq 'CrashReportClient.exe' -and ($cl -match "$GamePid" -or $p.ParentProcessId -eq $GamePid)) { [void]$r.Add([pscustomobject]@{ Kind = 'crashreport'; Pid = $p.ProcessId; Text = "CrashReportClient $cl" }) }
  }
  , @($r)
}
function Resolve-GameBlocker([int]$GamePid, [string]$OutDir) {
  $bl = Get-GameBlocker $GamePid
  if (-not $bl.Count) { return $null }
  $txt = ($bl | ForEach-Object { "$($_.Kind) pid $($_.Pid): $($_.Text)" }) -join "`n"
  if ($OutDir) {
    New-Item -ItemType Directory -Force $OutDir | Out-Null
    $stamp = Get-Date -Format 'HHmmss'
    Add-Content -LiteralPath "$OutDir\blocker_$stamp.txt" -Value $txt
    try {
      Add-Type -AssemblyName System.Windows.Forms, System.Drawing
      $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height); $g = [System.Drawing.Graphics]::FromImage($bmp)
      $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size); $bmp.Save("$OutDir\blocker_$stamp.png"); $g.Dispose(); $bmp.Dispose()
    } catch { }
  }
  $skip = @($bl | Where-Object { $_.Kind -eq 'dialog' -and $_.Text -match 'skip custom mods' })
  if ($skip.Count -eq $bl.Count) {
    $n = [S2GW]::Command([uint32]$GamePid, 7)
    return [pscustomobject]@{ Action = 'answered'; Text = "skip-mods prompt answered No (IDNO to $n dialog): $txt" }
  }
  foreach ($x in $bl) { if ($x.Kind -ne 'dialog') { Stop-Process -Id $x.Pid -Force -ErrorAction SilentlyContinue } }
  Stop-Process -Id $GamePid -Force -ErrorAction SilentlyContinue
  [pscustomobject]@{ Action = 'killed'; Text = $txt }
}
