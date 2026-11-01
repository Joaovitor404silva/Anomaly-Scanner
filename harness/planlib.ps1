$PLAN_VERBS = @('givew', 'up', 'reset', 'run', 'stage', 'face', 'aim', 'fire', 'hold', 'use', 'burst', 'shot', 'frame', 'animcheck', 'scene', 'census', 'par', 'status', 'setflag', 's2dev', 'nbot', 'wait', 'mark', 'out', 'assert', 'equip', 'closeui', 'settime')
$PLAN_OUTVERBS = @('shot', 'burst', 'frame', 'animcheck')

function Split-PlanLine([string]$s) {
  $t = New-Object System.Collections.Generic.List[string]
  foreach ($m in [regex]::Matches($s, '"([^"]*)"|(\S+)')) { [void]$t.Add($(if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value })) }
  $t.ToArray()
}

function Read-Plan([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { throw "HARNESS: plan file not found: $path" }
  $steps = @(); $n = 0
  foreach ($raw in [IO.File]::ReadAllLines($path)) {
    $n++; $l = $raw.Trim()
    if (-not $l -or $l.StartsWith('#')) { continue }
    $soft = $false; if ($l.StartsWith('?')) { $soft = $true; $l = $l.Substring(1).Trim() }
    [string[]]$tok = @(Split-PlanLine $l)
    $steps += [pscustomobject]@{ N = $n; Text = $l; Verb = $(if ($tok.Count) { $tok[0].ToLower() } else { '' }); Tokens = $tok; Soft = $soft }
  }
  , $steps
}

function Test-Plan($steps, [int]$RunLimit, [scriptblock]$SpecCheck) {
  $err = New-Object System.Collections.Generic.List[string]
  $e = { param($s, $m) [void]$err.Add("plan line $($s.N) '$($s.Text)': $m") }
  if (-not @($steps).Count) { [void]$err.Add('plan has no steps') }
  $runs = 0
  foreach ($s in @($steps)) {
    $v = $s.Verb; $t = $s.Tokens
    if ($v -eq 'down') { & $e $s 'down is not allowed: a plan always leaves the pair up'; continue }
    if ($v -notin $PLAN_VERBS) { & $e $s "unknown verb '$v' (known: $($PLAN_VERBS -join ' '))"; continue }
    switch ($v) {
      'up' {
        for ($i = 1; $i -lt $t.Count - 1; $i++) {
          if ($t[$i] -in '-Dll', '-Pak', '-PakHost', '-PakClient') {
            foreach ($p in ($t[$i + 1] -split ',')) { if ($p -and -not (Test-Path -LiteralPath $p)) { & $e $s "$($t[$i]) file does not exist: $p" } }
          }
        }
        if ($t[$t.Count - 1] -eq '-Dll') { & $e $s '-Dll needs a path' }
      }
      'run' {
        if ($t.Count -lt 2) { & $e $s 'run needs a spec'; break }
        $names = @($t[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        foreach ($nm in $names) { $m = & $SpecCheck $nm; if ($m) { & $e $s "spec ${nm}: $m" } }
        if (-not ($names.Count -eq 1 -and $names[0] -eq 'calm')) { $runs++ }
      }
      'burst' {
        $bx = 0
        if ($t.Count -lt 2 -or -not [int]::TryParse($t[1], [ref]$bx) -or $bx -lt 1) { & $e $s 'burst <n frames> [gap ms] [-Do "action"] [-StartOn <regex> [-StartLog A|B|s2dev:A|s2dev:B] [-StartTimeout s]] [-Pre N] [-Sync] [-Follow]'; break }
        for ($i = 2; $i -lt $t.Count; $i++) {
          $o = $t[$i].ToLower()
          if ($o -in '-starton', '-startlog', '-starttimeout', '-pre') {
            if ($i + 1 -ge $t.Count) { & $e $s "$($t[$i]) needs a value"; break }
            $val = $t[$i + 1]; $i++
            if ($o -eq '-startlog' -and $val -notmatch '^(?i)([ABE]|s2dev:[ABE])$') { & $e $s "-StartLog must be A, B, s2dev:A or s2dev:B (got '$val')" }
            if ($o -in '-starttimeout', '-pre' -and -not [int]::TryParse($val, [ref]$bx)) { & $e $s "$($t[$i - 1]) needs a number" }
            if ($o -eq '-starton') { try { [void][regex]::new($val) } catch { & $e $s "-StartOn is not a valid regex: $($_.Exception.Message)" } }
          }
        }
        $low = @($t | ForEach-Object { $_.ToLower() })
        if (($low -contains '-follow') -and ($low -contains '-starton' -or $low -contains '-sync' -or $low -contains '-pre')) { & $e $s '-Follow cannot be combined with -StartOn/-Sync/-Pre' }
        if (($low -contains '-pre') -and -not ($low -contains '-starton' -or $low -contains '-sync')) { & $e $s '-Pre needs -StartOn or -Sync' }
      }
      'animcheck' { $runs++ }
      'assert' { $am = Test-AssertSyntax $t; if ($am) { & $e $s $am } }
      'equip' { $em = Test-EquipArgs $t; if ($em) { & $e $s $em } }
      'closeui' { if ($t.Count -ne 2 -or $t[1].ToUpper() -notin 'A', 'B') { & $e $s 'closeui A|B' } }
      'settime' { $em = Test-SetTimeArgs $t; if ($em) { & $e $s $em } }
      'wait' { $x = 0.0; if ($t.Count -lt 2 -or -not [double]::TryParse($t[1], [ref]$x) -or $x -lt 0) { & $e $s 'wait <seconds>' } }
      'mark' { if ($t.Count -lt 2) { & $e $s 'mark <label>' } }
      'out' { if ($t.Count -lt 2) { & $e $s 'out <dir>' } }
      'setflag' { if ($t.Count -lt 4 -or $t[1] -notin 'A', 'B', 'E') { & $e $s 'setflag <A|B|E> <key> <value>' } }
      'givew' { if ($t.Count -ne 3 -or $t[1] -notin 'A', 'B') { & $e $s 'givew <A|B> <WeaponSID>' } }
      's2dev' { if ($t.Count -lt 3 -or $t[1] -notin 'A', 'B', 'E') { & $e $s 's2dev <A|B|E> <command...>' } }
      { $_ -in 'nbot', 'par' } { if ($t.Count -lt 2) { & $e $s "$v needs arguments" } }
    }
  }
  if ($runs -gt $RunLimit) { [void]$err.Add("plan has $runs live runs (run + animcheck), budget is ${RunLimit}, split it or drop checks") }
  $err.ToArray()
}

function Invoke-PlanSteps($steps, [scriptblock]$Exec, [string]$LogPath) {
  $rows = @(); $failed = $null; $t0 = Get-Date; $liveRan = $false
  $log = { param($m) $l = (Get-Date).ToString('s') + ' ' + $m; for ($k = 0; $k -lt 20; $k++) { try { Add-Content -LiteralPath $LogPath -Value $l -Encoding ascii -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 50 } }; Write-Host $l }
  & $log "plan start: $(@($steps).Count) steps"
  $i = 0
  foreach ($s in @($steps)) {
    $i++; $ts = Get-Date; $rc = 0; $msg = ''
    if ($s.Verb -eq 'animcheck' -or ($s.Verb -eq 'run' -and $s.Tokens[1] -ne 'calm')) { $liveRan = $true }
    try { $rc = [int](& $Exec $s) } catch { $rc = 1; $msg = "$($_.Exception.Message)" }
    $sec = [Math]::Round(((Get-Date) - $ts).TotalSeconds, 1)
    $ok = ($rc -eq 0)
    $row = [pscustomobject]@{ I = $i; N = $s.N; Text = $s.Text; Rc = $rc; Sec = $sec; Ok = $ok }
    $rows += $row
    & $log ("step {0}/{1} line {2} rc={3} {4} s :: {5}{6}" -f $i, @($steps).Count, $s.N, $rc, $sec.ToString([Globalization.CultureInfo]::InvariantCulture), $s.Text, $(if ($msg) { " :: $msg" } else { '' }))
    if (-not $ok -and -not $s.Soft) { $failed = $row; break }
  }
  $tot = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
  if ($failed) { & $log "plan FAILED at step $($failed.I) (line $($failed.N): $($failed.Text)) after $tot s; the pair is left up$(if (-not $liveRan) { '; no live run (run/animcheck) was executed, the live budget is untouched' } else { '' })" } else { & $log "plan DONE: $(@($steps).Count) steps in $tot s; the pair is left up" }
  [pscustomobject]@{ Ok = (-not $failed); Failed = $failed; Rows = $rows; Sec = $tot }
}

$PLAN_ASSERT_KINDS = @('alive', 'noui', 'weapon', 'pos', 'flag', 'peer', 'calm', 'quest', 'save')
$PLAN_WEAPONS = @('pistol', 'rifle', 'knife', 'bolt', 'detector', 'any')

function Test-EquipKind([string]$equip, [string]$kind) {
  $n = -1; if ($equip -match '^\s*(\d+)') { $n = [int]$Matches[1] }
  $name = "$equip".ToLower()
  switch ($kind.ToLower()) {
    'pistol' { return ($n -eq 1 -or $name -match 'pistol') }
    'rifle' { return ($n -in 2, 3 -or $name -match 'rifle|primary|secondary|shotgun|smg|sniper|automatic') }
    'knife' { return ($n -eq 4 -or $name -match 'knife') }
    'bolt' { return ($n -eq 6 -or $name -match 'bolt') }
    'detector' { return ($name -match 'detector') }
    'any' { return ($n -ge 1) }
  }
  $false
}

function Test-AssertSyntax($t) {
  if ($t.Count -lt 2) { return "assert <$($PLAN_ASSERT_KINDS -join '|')> ..." }
  $k = $t[1].ToLower(); $x = 0.0; $side = { param($s) $s -and $s.ToUpper() -in 'A', 'B', 'E' }
  switch ($k) {
    'alive' { if ($t.Count -ne 3 -or -not (& $side $t[2])) { return 'assert alive A|B' } }
    'noui' { if ($t.Count -ne 3 -or -not (& $side $t[2])) { return 'assert noui A|B' } }
    'weapon' { if ($t.Count -ne 4 -or -not (& $side $t[2]) -or $t[3].ToLower() -notin $PLAN_WEAPONS) { return "assert weapon A|B <$($PLAN_WEAPONS -join '|')>" } }
    'pos' {
      $ok = ($t.Count -in 5, 6) -and (& $side $t[2]) -and [double]::TryParse($t[3], [ref]$x) -and [double]::TryParse($t[4], [ref]$x)
      if ($ok -and $t.Count -eq 6) { $ok = [double]::TryParse($t[5], [ref]$x) -and $x -gt 0 }
      if (-not $ok) { return 'assert pos A|B x y [radius cm]' }
    }
    'flag' { if ($t.Count -lt 5 -or -not (& $side $t[2])) { return 'assert flag A|B name value' } }
    'peer' { if ($t.Count -ne 2) { return 'assert peer' } }
    'quest' { if ($t.Count -ne 5 -or -not (& $side $t[2]) -or $t[4].ToLower() -notin 'active', 'finished', 'none') { return 'assert quest A|B <NodeSID> active|finished|none' } }
    'save' { if ($t.Count -ne 6 -or -not (& $side $t[2]) -or $t[3].ToLower() -ne 'quest' -or $t[5].ToLower() -notin 'active', 'finished', 'none') { return 'assert save A|B quest <NodeSID> active|finished|none' } }
    'calm' { if ($t.Count -gt 3 -or ($t.Count -eq 3 -and (-not [double]::TryParse($t[2], [ref]$x) -or $x -le 0))) { return 'assert calm [meters]' } }
    default { return "unknown assert '$k' (known: $($PLAN_ASSERT_KINDS -join ' '))" }
  }
  $null
}

function Get-PlanWarnings($steps) {
  $w = New-Object System.Collections.Generic.List[string]
  $sawW = $false; $sawA = $false
  foreach ($s in @($steps)) {
    $v = $s.Verb; $t = $s.Tokens
    if ($v -eq 'assert' -and $t.Count -ge 2) { if ($t[1].ToLower() -eq 'weapon') { $sawW = $true }; if ($t[1].ToLower() -eq 'alive') { $sawA = $true } }
    if ($v -in 'fire', 'burst', 'animcheck') {
      $needW = $v -ne 'burst' -or $s.Text -match '(?i)-Do\s+"?[^"]*\b(fire|ads|reload|melee|equip)'
      $miss = @(); if ($needW -and -not $sawW) { $miss += 'assert weapon' }; if (-not $sawA) { $miss += 'assert alive' }
      if ($miss.Count) { [void]$w.Add("plan line $($s.N) '$($s.Text)': $v without a preceding $($miss -join ' and ')") }
    }
    if ($v -eq 'up' -and @($t | Where-Object { $_ -ieq '-Dll' }).Count -gt 0 -and @($t | Where-Object { $_ -ieq '-Reuse' }).Count -eq 0) { [void]$w.Add("plan line $($s.N) '$($s.Text)': up -Dll without -Reuse cold boots; hot reload is the rule (cold boot only when the repro needs a restart)") }
    if ($v -eq 'up') {
      $di = [Array]::FindIndex([string[]]$t, [Predicate[string]]{ param($x) $x -ieq '-Dll' })
      if ($di -ge 0 -and $di + 1 -lt $t.Count -and (Test-Path -LiteralPath $t[$di + 1]) -and -not [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($t[$di + 1])).Contains('nola_hot_start')) { [void]$w.Add("plan line $($s.N) '$($s.Text)': the DLL is a release build (no nola_hot_start): no hot reload, dev commands and devcmd flags are refused; rebuild it as a dev build (wt.ps1 build <name>, -Release also writes Output)") }
    }
    if ($v -eq 'up' -and @($t | Where-Object { $_ -ieq '-Calm' }).Count -eq 0) { [void]$w.Add("plan line $($s.N) '$($s.Text)': up without -Calm (the viewer can be killed)") }
  }
  $upNoSave = @($steps | Where-Object { $_.Verb -eq 'up' -and @($_.Tokens | Where-Object { $_ -ieq '-Save' -or $_ -ieq '-NoSave' }).Count -eq 0 })
  if ($upNoSave.Count) {
    foreach ($r in @($steps | Where-Object { $_.Verb -eq 'run' -and $_.Tokens.Count -ge 2 -and (Test-Path -LiteralPath $_.Tokens[1]) })) {
      if (Select-String -LiteralPath $r.Tokens[1] -Pattern '^\s*tp\s+[ABE]\s+-?\d' -Quiet) { [void]$w.Add("plan line $($upNoSave[0].N) '$($upNoSave[0].Text)': up without -Save but the spec $($r.Tokens[1]) teleports to world coordinates; the reused save decides what is there (quest stage, population), name the save") }
    }
  }
  $sawDevA = $false; $sawDevB = $false; $dw = @{ v = $false }; $sawSceneA = $false; $sawNoui = @{}
  $needDev = { param($s, $why) if (-not $dw.v -and -not ($sawDevA -and $sawDevB)) { $dw.v = $true; [void]$w.Add("plan line $($s.N) '$($s.Text)': $why but no earlier setflag A devcmd 1 and setflag B devcmd 1 in the plan (PLAN_MANUAL R8)") } }
  foreach ($s in @($steps)) {
    $v = $s.Verb; $t = $s.Tokens
    if ($v -eq 'setflag' -and $t.Count -ge 4 -and $t[2] -ieq 'devcmd' -and $t[3] -eq '1') { if ($t[1] -ieq 'A') { $sawDevA = $true }; if ($t[1] -ieq 'B') { $sawDevB = $true } }
    if ($v -eq 'assert' -and $t.Count -ge 3 -and $t[1] -ieq 'noui') { $sawNoui[$t[2].ToUpper()] = $true }
    if ($v -in 'scene', 'census') { & $needDev $s "$v needs devcmd" }
    if ($v -eq 'scene' -and $s.Text -match '(?i)-On\s+\S*\b[AC]\b|@C') { $sawSceneA = $true }
    if ($v -eq 'shot' -and $s.Text -match '(?i)key=host:') {
      & $needDev $s 'shot key=host: needs devcmd'
      if ($s.Text -match 'key=host:\$' -and -not $sawSceneA) { [void]$w.Add("plan line $($s.N) '$($s.Text)': shot key=host:`$var with no earlier scene ... -On A that defines the var (PLAN_MANUAL R32)") }
    }
    if ($v -ne 'run' -or $t.Count -lt 2) { continue }
    foreach ($sp in @($t[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
      if (-not (Test-Path -LiteralPath $sp -PathType Leaf)) { continue }
      $sl = @(); $sn = 0
      foreach ($raw in [IO.File]::ReadAllLines($sp)) { $sn++; $x = $raw.Trim(); if (-not $x -or $x.StartsWith('#')) { continue }; $tk = @(Split-PlanLine $x); $sl += [pscustomobject]@{ N = $sn; Text = $x; V = $tk[0].ToLower(); T = $tk } }
      $at = "plan line $($s.N), spec $sp"
      if (@($sl | Where-Object { $_.V -eq 'dev' -and $_.T.Count -ge 2 -and $_.T[1] -in 'A', 'B' }).Count) { & $needDev $s 'the spec has dev lines (dev A|B)' }
      $hasManual = @($sl | Where-Object { $_.V -eq 'manual' }).Count -gt 0
      $tpB = $false; $keyWarned = $false
      for ($i = 0; $i -lt $sl.Count; $i++) {
        $L = $sl[$i]; $lt = $L.T
        if ($L.V -eq 'tp' -and $lt.Count -ge 2) {
          if ($lt[1] -ieq 'B') {
            $tpB = $true
            $later = @($sl | Select-Object -Skip ($i + 1) | Where-Object { $_.V -eq 'expect_not' -and $_.T.Count -ge 3 -and $_.T[1] -ieq 'B' -and $_.Text -match 'cine|coleira' })
            if (-not $later.Count) { [void]$w.Add("${at} line $($L.N) '$($L.Text)': tp B with no later expect_not B ... (cine|coleira) (PLAN_MANUAL R12/R24)") }
          } elseif ($lt[1] -ieq 'A' -and $tpB) { [void]$w.Add("${at} line $($L.N) '$($L.Text)': tp A after a tp B, the host teleport pulls the client (PLAN_MANUAL R12)") }
        }
        if ($L.V -eq 'key' -and $lt.Count -ge 2 -and $lt[1] -in 'A', 'B' -and -not $keyWarned -and -not $hasManual -and -not $sawNoui[$lt[1].ToUpper()]) { $keyWarned = $true; [void]$w.Add("${at} line $($L.N) '$($L.Text)': key press with no assert noui $($lt[1].ToUpper()) before it in the plan and no manual line in the spec (PLAN_MANUAL R10/R30)") }
        if ($L.V -eq 'expect' -and $i -ge 2 -and $L.Text -notmatch '\\d|\[0-9\]') {
          $j = $i - 1
          if ($sl[$j].V -eq 'mark') {
            $j--; $waited = $false
            while ($j -ge 0 -and $sl[$j].V -eq 'wait') { $waited = $true; $j-- }
            if ($waited -and $j -ge 0 -and $sl[$j].V -in 'tp', 'key', 'kill', 'launch', 'spawn') { [void]$w.Add("${at} line $($L.N) '$($L.Text)': expect right after wait + mark after the trigger '$($sl[$j].Text)' and the regex has no counter, a one-shot line is lost at the re-anchor (PLAN_MANUAL R19/R20)") }
          }
        }
      }
    }
  }
  $w.ToArray()
}

function Invoke-PlanAssert($t, [scriptblock]$reader) {
  $kind = $t[1].ToLower(); $k = if ($t.Count -gt 2) { $t[2].ToUpper() } else { '' }
  $head = 'assert ' + (($t | Select-Object -Skip 1) -join ' ')
  $res = { param($ok, $m) [pscustomobject]@{ Ok = $ok; Msg = "${head}: $m" } }
  try {
    switch ($kind) {
      'alive' {
        $asw = [Diagnostics.Stopwatch]::StartNew()
        while ($true) {
          $s = & $reader 'state' $k ''
          if (-not ($null -eq $s -or $null -eq $s.hp -or [double]$s.hp -eq -1)) { break }
          if ($asw.ElapsedMilliseconds -ge $PLAN_ALIVE_RETRY_MS) { break }
          Start-Sleep -Milliseconds 250
        }
        if ($null -eq $s -or $null -eq $s.hp) { return & $res $false "expected $k alive (hp > 0), found no pawn state" }
        if ($s.dead -eq $true) { return & $res $false "expected $k alive, found IsAlive false (death screen) with hp $($s.hp)" }
        if ([double]$s.hp -gt 0) { return & $res $true "$k alive, hp $($s.hp)" }
        if ([double]$s.hp -eq -1) { return & $res $false "expected $k alive (hp > 0), found hp -1 (not read yet) after $([int]($PLAN_ALIVE_RETRY_MS / 1000)) s of retries" }
        return & $res $false "expected $k alive (hp > 0), found hp $($s.hp)"
      }
      'weapon' {
        $s = & $reader 'state' $k ''
        if ($null -eq $s) { return & $res $false "expected $($t[3]) in hand on $k, found no pawn state" }
        $eq = "$($s.equip)"
        if (Test-EquipKind $eq $t[3]) { return & $res $true "$k holds '$eq'" }
        if ($t[3].ToLower() -eq 'detector') {
            $dv = & $reader 'detector' $k ''
            if ($dv -eq $true) { return & $res $true "$k has the detector in hands (main hand '$eq')" }
            return & $res $false "expected detector in hands on $k, found no detector (main hand '$eq')"
        }
        return & $res $false "expected $($t[3]) in hand on $k, found '$eq'"
      }
      'noui' {
        $u = & $reader 'ui' $k ''
        if (-not $u) { return & $res $true "no inventory or menu open on $k" }
        return & $res $false "expected no inventory or menu open on $k, found $u open"
      }
      'pos' {
        $s = & $reader 'state' $k ''
        if ($null -eq $s -or $null -eq $s.pos) { return & $res $false "expected $k near ($($t[3]), $($t[4])), found no pawn state" }
        $r = if ($t.Count -ge 6) { [double]$t[5] } else { 200.0 }
        $dx = [double]$s.pos[0] - [double]$t[3]; $dy = [double]$s.pos[1] - [double]$t[4]; $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
        $found = '({0:F0}, {1:F0})' -f [double]$s.pos[0], [double]$s.pos[1]
        if ($d -le $r) { return & $res $true "$k at $found, $([int]$d) cm from target" }
        return & $res $false "expected $k within $r cm of ($($t[3]), $($t[4])), found $found, $([int]$d) cm away"
      }
      'flag' {
        $want = (($t | Select-Object -Skip 4) -join ' ')
        $v = & $reader 'flag' $k $t[3]
        if ($null -ne $v -and "$v".Trim() -eq $want) { return & $res $true "$k $($t[3])=$v" }
        return & $res $false "expected $k $($t[3])=$want, found $(if ($null -eq $v) { 'unset' } else { $v })"
      }
      'peer' {
        $p = & $reader 'peer' '' ''
        if ($p.Ok) { return & $res $true "$($p.Detail)" }
        return & $res $false "expected NOLA PEER UP on both sides, found $($p.Detail)"
      }
      'quest' {
        $node = $t[3]; $want = "$($t[4])".ToLower()
        if (-not $node -or $want -notin 'active', 'finished', 'none') { return & $res $false 'usage: assert quest A|B <NodeSID> active|finished|none' }
        $v = & $reader 'quest' $k $node
        if ($null -ne $v -and "$v" -eq $want) { return & $res $true "$k $node is $v" }
        return & $res $false "expected $k $node $want, found $(if ($null -eq $v) { 'no quest state (ScenarioManager unreadable)' } else { $v })"
      }
      'save' {
        if ("$($t[3])".ToLower() -ne 'quest') { return & $res $false 'usage: assert save A|B quest <NodeSID> active|finished|none' }
        $node = $t[4]; $want = "$($t[5])".ToLower()
        if (-not $node -or $want -notin 'active', 'finished', 'none') { return & $res $false 'usage: assert save A|B quest <NodeSID> active|finished|none' }
        $v = & $reader 'savequest' $k $node
        if ($null -ne $v -and "$v" -eq $want) { return & $res $true "save of $k has $node $v" }
        return & $res $false "expected save of $k to have $node $want, found $(if ($null -eq $v) { 'no readable save quest state' } else { $v })"
      }
      'calm' {
        $m = if ($t.Count -ge 3) { [double]$t[2] } else { 30.0 }
        $c = & $reader 'calm' 'A' $m
        if ($c.Ok) { return & $res $true "no hostile within $m m" }
        return & $res $false "expected no hostile within $m m of A, found $($c.Detail)"
      }
    }
  } catch { return & $res $false "could not read the game state: $($_.Exception.Message)" }
  & $res $false "unknown assert kind $kind"
}

function Invoke-PlanAssertStep($s, [scriptblock]$reader) {
  $r = Invoke-PlanAssert $s.Tokens $reader
  if (-not $r.Ok) { throw "ASSERT FAILED (plan line $($s.N)): $($r.Msg)" }
  Write-Host "ASSERT OK: $($r.Msg)"
  0
}

function Wait-Equip([string]$k, [int]$n, [scriptblock]$reader, [int]$timeoutMs = 3000, [int]$pollMs = 250) {
  $sw = [Diagnostics.Stopwatch]::StartNew(); $eq = ''
  while ($true) {
    try { $s = & $reader 'state' $k ''; $eq = if ($null -ne $s) { "$($s.equip)" } else { 'no pawn state' } } catch { $eq = "unreadable: $($_.Exception.Message)" }
    if ($eq -match ('^\s*' + $n + '\b')) { return [pscustomobject]@{ Ok = $true; Msg = "equip ${n} verified on ${k}: '$eq' after $([int]$sw.ElapsedMilliseconds) ms" } }
    if ($sw.ElapsedMilliseconds -ge $timeoutMs) { break }
    Start-Sleep -Milliseconds $pollMs
  }
  [pscustomobject]@{ Ok = $false; Msg = "equip ${n} not in hand on ${k} after $([int]($timeoutMs / 1000)) s: expected '${n} (...)', found '$eq' (item missing from the inventory, or the equip call did nothing)" }
}

$PLAN_ALIVE_RETRY_MS = 2000
$PLAN_EQUIP_KINDS = @('pistol', 'rifle', 'knife', 'bolt', 'detector')

function ConvertTo-GameClock([string]$s) {
  if ("$s" -notmatch '^(\d{1,2})(?::(\d{2}))?$') { return $null }
  $h = [int]$Matches[1]; $m = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
  if ($h -gt 23 -or $m -gt 59) { return $null }
  '{0:D2}:{1:D2}' -f $h, $m
}

function Test-SetTimeArgs($t) {
  $u = 'settime A|B <hour 0-23 or HH:MM>'
  if ($t.Count -ne 3 -or -not $t[1] -or $t[1].ToUpper() -notin 'A', 'B') { return $u }
  if (-not (ConvertTo-GameClock $t[2])) { return "settime: bad hour '$($t[2])' ($u)" }
  $null
}

function Test-EquipArgs($t) {
  $u = "equip A|B <$($PLAN_EQUIP_KINDS -join '|')>"
  if ($t.Count -ne 3 -or -not $t[1] -or $t[1].ToUpper() -notin 'A', 'B') { return $u }
  if (-not $t[2] -or $t[2].ToLower() -notin $PLAN_EQUIP_KINDS) { return "equip: unknown item '$($t[2])' ($u)" }
  $null
}

function New-UniqueDir([string]$parent, [string]$prefix) {
  $base = Join-Path $parent ($prefix + '_' + (Get-Date -Format 'HHmmss')); $d = $base; $n = 1
  while (Test-Path -LiteralPath $d) { $n++; $d = "${base}_$n" }
  New-Item -ItemType Directory -Force $d | Out-Null
  $d
}

function Invoke-BurstFollow([scriptblock]$done, [scriptblock]$aim, [int]$gapMs = 150, [int]$maxMs = 130000) {
  $n = 0; $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    try { & $aim; $n++ } catch { }
    if (& $done) { break }
    if ($sw.ElapsedMilliseconds -ge $maxMs) { break }
    Start-Sleep -Milliseconds ([Math]::Max(20, [int]($gapMs / 2)))
  }
  $n
}

function Get-EquipHeld([string]$k, [string]$kind, [scriptblock]$reader) {
  $eq = ''; $held = $false
  try { $s = & $reader 'state' $k ''; $eq = if ($null -ne $s) { "$($s.equip)" } else { 'no pawn state' } } catch { $eq = "unreadable: $($_.Exception.Message)" }
  if ($eq -and (Test-EquipKind $eq $kind)) { $held = $true }
  if (-not $held -and $kind -eq 'detector') { try { if ((& $reader 'detector' $k '') -eq $true) { $held = $true; $eq = "detector in hands (main hand '$eq')" } } catch { } }
  [pscustomobject]@{ Held = $held; Eq = $eq }
}

function Invoke-PlanEquip([string]$k, [string]$kind, [scriptblock]$reader, [scriptblock]$press, [int]$timeoutMs = 3000, [int]$pollMs = 250, [scriptblock]$closeUi = $null) {
  $closed = ''
  if ($closeUi) {
    $u = ''; try { $u = & $reader 'ui' $k '' } catch { $u = '' }
    if ($u) {
      try { [void](& $closeUi $k) } catch { return [pscustomobject]@{ Ok = $false; Pressed = $false; Msg = "equip $kind on ${k}: could not close the open ${u}: $($_.Exception.Message)" } }
      $usw = [Diagnostics.Stopwatch]::StartNew()
      while ($true) {
        Start-Sleep -Milliseconds $pollMs
        try { $u2 = & $reader 'ui' $k '' } catch { $u2 = '' }
        if (-not $u2) { break }
        if ($usw.ElapsedMilliseconds -ge 2000) { return [pscustomobject]@{ Ok = $false; Pressed = $false; Msg = "equip $kind on ${k}: $u2 still open after Esc" } }
      }
      $closed = " (closed the open $u first)"
    }
  }
  $g = Get-EquipHeld $k $kind $reader
  if ($g.Held) { return [pscustomobject]@{ Ok = $true; Pressed = $false; Msg = "equip $kind on ${k}: already in hand ('$($g.Eq)'), no key pressed$closed" } }
  try { [void](& $press $k $kind) } catch { return [pscustomobject]@{ Ok = $false; Pressed = $true; Msg = "equip $kind on ${k}: could not press the key: $($_.Exception.Message)" } }
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    Start-Sleep -Milliseconds $pollMs
    $g = Get-EquipHeld $k $kind $reader
    if ($g.Held) { return [pscustomobject]@{ Ok = $true; Pressed = $true; Msg = "equip $kind on ${k}: pressed once, now '$($g.Eq)' after $([int]$sw.ElapsedMilliseconds) ms$closed" } }
    if ($sw.ElapsedMilliseconds -ge $timeoutMs) { break }
  }
  [pscustomobject]@{ Ok = $false; Pressed = $true; Msg = "equip $kind not in hand on ${k} after $([int]($timeoutMs / 1000)) s: found '$($g.Eq)' (item missing from the inventory, or the equip call did nothing)$closed" }
}
