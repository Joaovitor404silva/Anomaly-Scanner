param(
  [Parameter(Mandatory = $true)][string]$Log,
  [Parameter(Mandatory = $true)][long]$From,
  [Parameter(Mandatory = $true)][string]$Regex,
  [Parameter(Mandatory = $true)][string]$Out,
  [double]$TimeoutSec = 8
)
$ErrorActionPreference = 'Stop'
$re = New-Object Text.RegularExpressions.Regex($Regex, 'IgnoreCase')
$end = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
$pos = $From; $carry = ''
while ([DateTime]::UtcNow -lt $end) {
  try {
    if (Test-Path -LiteralPath $Log) {
      $fs = New-Object IO.FileStream($Log, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
      try {
        if ($fs.Length -lt $pos) { $pos = 0; $carry = '' }
        if ($fs.Length -gt $pos) {
          [void]$fs.Seek($pos, [IO.SeekOrigin]::Begin)
          $buf = New-Object byte[] ([int][Math]::Min(4MB, $fs.Length - $pos))
          $got = $fs.Read($buf, 0, $buf.Length); $pos += $got
          $text = $carry + [Text.Encoding]::UTF8.GetString($buf, 0, $got)
          $lines = $text -split "`n"
          $carry = $lines[$lines.Count - 1]
          for ($i = 0; $i -lt $lines.Count - 1; $i++) {
            if ($re.IsMatch($lines[$i])) {
              [IO.File]::WriteAllText($Out, "$([DateTime]::UtcNow.Ticks)`t$($lines[$i].TrimEnd())")
              exit 0
            }
          }
          if ($carry -and $re.IsMatch($carry)) {
            [IO.File]::WriteAllText($Out, "$([DateTime]::UtcNow.Ticks)`t$($carry.TrimEnd())")
            exit 0
          }
        }
      } finally { $fs.Dispose() }
    }
  } catch { }
  Start-Sleep -Milliseconds 25
}
[IO.File]::WriteAllText($Out, 'timeout')
exit 1

$global:LASTEXITCODE = 0
