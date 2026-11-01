# Writing live plans and specs (NOLA co-op harness)

A plan is one harness line per step (`harness.ps1 plan <file>`); a spec is the log check a `run` line executes. The supervisor runs them; the writer never does. A plan that fails on its first run costs a 20 min pair slot, so every rule below exists because a real run broke (FAIL_NOTES.md). Rules are numbered R1..R41; gaps are rules dropped or merged in the 2026-10-30 audit (ModWork\agents\plans\2026-10-30-pipeline-rule-audit.md).

## 1. Pre-flight checklist (tick every line before hand-over)

- [ ] R1 **Save named.** The `up` line has `-Save C:\modding\s2harness\testsave\<name>` (or `-NoSave` when any world state will do). Pick it from the table in section 7; the save decides quest stage, population and where the players stand. No -Save = the pair's last save, whatever that was (v130f2 red/green both read 1-2 NPCs because the prologue save had no village).
- [ ] R2 **Save holds the state.** `harness.ps1 savestate <name>` prints STATE.md (position, game time, active quest nodes). Check the nodes you need are active and the trigger has not fired yet. A new save is captured from the user's save right before the trigger and named in the brief.
- [ ] R3 **Save change = cold boot.** `up -Reuse` with a different save than the running pair falls back to a cold boot (~200 s). Say so in the plan note and group plans on the same save back to back.
- [ ] R4 **Dev DLL.** `-Dll` points to `D:\modding\cpp\wt\<wt>\cppbuild\Output\NolaNative\Game__Shipping__Win64\NolaNative.dll` of a dev (Fast) build. `wt.ps1 build -Release` overwrites that same Output slot: after any -Release build, rebuild dev. A release DLL gives no hot reload, dev lines NOT CONSUMED, and every `up` cold boots. -Check warns; fix it, do not hand over with the warning.
- [ ] R5 **Hot reload.** `up -Reuse -Calm -Dll <dll>`; never `up -Dll` without -Reuse. A cold boot only when the repro needs a restart (host reboot test) and the plan note says why. Never `down` in a plan.
- [ ] R6 **-Calm.** `up` always has -Calm, then `run calm` after the flags (it is free, not counted in the budget). `run calm` needs a dev DLL (its `dev A flags` lines).
- [ ] R7 **God flags per side.** Fights or deaths: `setflag A|B downsecs 99999`, `bothdie 0`, `bothdown 0` on both sides. A downed client bleeds out and bothdie kills the host; a dead player stops game time and freezes NPCs, so every counter reads 0.
- [ ] R8 **devcmd.** Any `scene`, `census`, `dev` or `shot key=host:...` line needs `setflag A devcmd 1` and `setflag B devcmd 1` before it (scene spawn failed: "census not written in 15 s").
- [ ] R9 **Feature flags per side.** One `setflag <side> <flag> <value>` per side that needs it; the red plan sets the flag to 0 explicitly (never relies on a missing flag). The old build ignores unknown flags, so the same plan runs on both builds.
- [ ] R10 **Asserts before actions.** `assert alive A`, `assert alive B`, `assert peer` after the flags; `assert noui B` before any key press; `assert weapon <side> <kind>` before fire/animcheck and before a burst whose -Do fires, aims, reloads, melees or equips. A failed assert stops the plan for free (no live run spent).
- [ ] R11 **settime.** `settime A 12` and `settime B 12` before shots or anything visual (night shots do not count as proof).
- [ ] R12 **Host moves first.** A host teleport pulls the client to the host within 3 s (s2m_travel.cpp:530-553). Order: `tp A`, `wait`, then `tp B`; never move A after B is in place. In the spec add `expect_not B NOLA (cine: host a|tpfloor: coleira) during 3` after the client move.
- [ ] R13 **Long teleports settle.** After a tp to another area wait 10-20 s before the next action; B's pawn is rebuilt for a few seconds (the harness retries `tp near` for 20 s, your own actions do not).
- [ ] R14 **Budget.** At most 2 `run` lines (plus animcheck) per plan, `run calm` excepted. One plan = one 20 min lock slot. -Check counts them.
- [ ] R16 **Soft steps.** Prefix optional steps with `?` (`?s2dev A con fov 75`); every other step stops the plan on failure.
- [ ] R17 **-Check clean.** From cwd `C:\modding\s2harness`: `powershell -NoProfile -File harness.ps1 plan <file> -Check` prints `PLAN OK` with no `PLAN WARN`. Then `logcheck` (R25). Hand over only: plan path, spec path, DLL md5, save, expected red and green numbers, manual steps.
- [ ] R18 **Human steps declared.** Anything a script cannot do (section 3) is a `manual <id> <text>` line in the spec and a note in the plan; the supervisor does it by hand.

## 2. Spec rules

- R19 **Anchor = mark.** `expect` sees only lines written after the last anchor. `mark` re-anchors, and every action step (tp, key, con, dev, s2dev, spawn, kill, launch) re-anchors right before it runs. So: trigger step, then its expects. A `wait` + `mark` after the trigger throws away everything the trigger printed.
- R20 **One-shot events after the mark.** "copy created", "death", "quest node finished" print once. If a plan `scene` fires them before the spec starts, the spec cannot see them: either put the trigger inside the spec (after `mark`) or expect a periodic line (the `natnpc 10 s`, `natdead 10 s`, `corpsemc` counters) instead.
- R21 **Windows are sequential.** `within N` starts when that expect line runs, not at the mark; expects run one after another, so order them by the time they fire and size each window for its own event. `expect_not X during N` blocks N seconds; put it last unless it guards a pull or cine right after a move.
- R22 **Outcome counters both builds print.** The red must be able to fail on the old build and the green pass on the new one with the SAME spec: compare numbers (`npcs_classe=\d\d+`, `copias=([1-9]|\d\d+)`, `com_corpo=([1-9]|\d\d+)`, a quest step on the host), never "a new-code token is missing". A spec that only passes because the new build logs a new word is not a red. Activity is not outcome: `grooms_feitos>0` passed while the copy stayed bald; check that the result matches the host (asset names, count near B, quest node).
- R23 **Numbers in the note.** The `note` line states the old-build numbers (run time and values) and the new-build numbers. The supervisor reads it before trusting a FAIL.
- R24 **expect_not for pulls and cines.** After any client move: `expect_not B NOLA (cine: host a|tpfloor: coleira) during 3`. After a host move or load: `expect_not B NOLA n7: host comecou outra campanha during 30` when relevant.
- R25 **Regexes checked offline.** Every expect regex must match a line of the C++ log catalog: `harness.ps1 logcheck <spec substring>` for specs under C:\modding\s2harness\specs, or `uv run --no-project python -I "<ModWork>\tools\logcat\check_log_specs.py" --specs <your tests dir> --only <name>` for a worktree spec. Exit 1 = dead regex; a token that exists only on your branch is reported NO-MATCH until the catalog is rebuilt from your tree, so prefer counters that already exist. Escape parentheses: `\(host\)`.
- R26 **One trigger, no inventions.** The spec reproduces the brief's measured repro (same place, same action). It does not add a second trigger or a different route.
- R27 **INV row.** Every run adds a FAIL row when a `NOLA INV` invariant break was logged after the spec started (dev DLL). A spec with `kill`/`launch` or a host reload will trip it; read the report row before blaming your expects, and mention the expected INV in the note.
- R28 **Dev lines need the dev DLL.** `dev`, `cfg`, `census`, `s2dev ... pawn` lines fail on a release DLL (NOT CONSUMED).
- R29 **Flags by setflag, not cfg.** A `cfg` value is overwritten by the flags.txt reread within ~6 s; use `setflag` in the plan for anything that must hold.

## 3. Interaction and visual tests

- R30 **Scripted key presses do not interact.** `key B F 1500` on the cave scanner did nothing: `face` aims at the actor root and the client view was third person behind its body, so no interact prompt was up. There is no verb that reads the prompt yet. For an interaction test: `assert noui B`, `frame <key> -On D` to look at the object, `wait 2`, then the key hold; if the red run still shows no `pupanim: acao local` line, write `manual <id> B holds F on <object>` in the spec and say in the plan note that the supervisor does it by hand.
- R31 **Keys.** Inventory F (a tap opens it, a hold interacts), pistol Z, knife C, weapon wheel = hold Tab. Close an inventory with `closeui B`, never with a tap.
- R32 **Proof shots.** First plan line `out D:\modding\proofs\<YYYYMMDD>_<worker>_<test>`. `shot <name> on=A,B key=<target> cam=2.5` after `settime 12`; same key on both sides so the verifier compares the same NPC. `key=host:$var` names the host spawn var (`spawn ... as=<var>` in a scene run earlier in the same plan, within 60 min); on the client the harness resolves it through the natpair census, so the scene must run on A (`-On A`) before the shot and `wait 3` lets the copy appear. `key=host:uNNN` for an NPC read from a census. Never `frame -Dist` for proofs. Animation and pose claims use the visual-proof skill (screenshots + fresh verifier); a log line is not visual proof.
- R33 **Human action.** Dialogs, third-person interactions, menus with mouse, anything that needs the eyes on the prompt: declare it (R18). Say exactly what the human presses and when (after which plan line).

## 4. Template plan + spec (passes -Check and logcheck as of 2026-10-30)

`<test>.plan` (replace dev1, the proofs folder, the flag `corpsemc`, the scene and the spec path):
```
out D:\modding\proofs\20261030_tmpl_copies
up -Reuse -Calm -Dll D:\modding\cpp\wt\dev1\cppbuild\Output\NolaNative\Game__Shipping__Win64\NolaNative.dll -Save C:\modding\s2harness\testsave\master_20261018_host
setflag A downsecs 99999
setflag B downsecs 99999
setflag A bothdie 0
setflag B bothdie 0
setflag A bothdown 0
setflag B bothdown 0
setflag A devcmd 1
setflag B devcmd 1
setflag A corpsemc 1
run calm
assert alive A
assert alive B
assert peer
assert noui B
settime A 12
settime B 12
mark tmpl_trigger
scene D:\modding\cpp\wt\v130a\tests\v130a_flesh.scene -On A
run D:\modding\cpp\wt\dev1\tests\tmpl_copies_spec.txt
wait 3
shot tmpl_copies on=A,B key=host:$f1 cam=2.5
```
`tmpl_copies_spec.txt`:
```
spec tmpl_copies
note A first to the lake shore (365788 594200), B next to it 5 s later. Both builds print the natnpc 10 s counters: old DLL (run 17:39:40) host npcs_classe=2 na_lista=0, B copias=0; new DLL (run 17:18:45) host npcs_classe=45 na_lista=43, B copias=42. The red must read the old numbers, the green the new ones.
tp A 365788 594200 620
wait 5
mark
tp B 365788 594276 620
wait 5
expect_not B NOLA (cine: host a|tpfloor: coleira) during 3
expect A NOLA natnpc 10 s \(host\): npcs_classe=\d+ na_lista=\d+ within 15
expect B NOLA natnpc 10 s \(cliente\): host=\d+ copias=\d+ within 15
```
The red plan is the same file with the feature flag at 0 and `out ..._red`; the green sets it to 1. Tighten `\d+` to the numbers from the note (`\d\d+`, `([1-9]|\d\d+)`) once the red run confirms the old values.

## 5. Failure -> rule (FAIL_NOTES.md 2026-10-30 and the day's plan.logs)

| failure seen | rule |
|---|---|
| plan refused: pair lock held from another cwd | run plan/submit from C:\modding\s2harness; writers hand over, supervisor runs (R17) |
| lock expired after 96 min | one plan = one slot, 20 min cap; no idle waits (R14) |
| up refused: main.dll not baseline | never copy a DLL by hand; after one, `dllrestore -Dll baseline\...` (R4) |
| red runs on a release DLL: NOT CONSUMED, cold boots | rebuild dev after any -Release build; -Check warns (R4, R28) |
| up -Dll cold booted every plan | `up -Reuse -Calm -Dll` always (R5) |
| expects missed one-shot events | trigger after the spec's mark, or expect periodic counters (R19, R20) |
| red counted as red only by a missing new token | counters both builds print, numbers in the note (R22, R23) |
| tp A near B: pawn on B unresolved after a long teleport | wait after long tps (R13) |
| shot key=host:$var: host var not known | spawn scene with as=var on A in the same plan, wait 3, then shot (R32) |
| village spec read 0 copies: host tp last pulled B away | host first, then client, expect_not pull (R12, R24) |
| client F on the scanner did nothing scripted | prompt not checked; declare a manual step (R30, R33) |
| red and green both read 1-2 NPCs: no -Save, prologue save reused | name the save, check STATE.md (R1, R2) |
| scene spawn: census not written (devcmd) | setflag devcmd 1 both sides before scenes (R8) |
| run calm FAIL: dev A flags not consumed | dev DLL only (R6, R28) |
| hostboot spec FAIL on the INV row only | read the INV row, note the expected break (R27) |
| up -Reuse -Save other save: REUSE not possible, 200 s cold boot | group plans by save, say it in the note (R3) |
| ixreal expect window ran out at 10 s with no action | windows start at the expect; order and size them (R21) |

## 6. Extra rules from the day's logs

- R34 A `scene` kills nothing on the client; spawn/kill run on A, movement scenes on the side that moves (`-On B`).
- R35 Keep 6 or fewer spawned NPCs per boot; freeze them (`freeze=1`) unless the test is about movement.
- R36 After a world reset (`reset`, `up -Reuse`) god flags, fov and time are gone: set them again in every plan, never assume the previous plan left them.
- R38 Zalissya coordinates: village 404034 546754 700 (A indoors at z 606), B 404234 546754 700; 150 m east 419034 546754 706; 384034 546754 is bushes and a 6 m fall. Lake default: A 365788 594200 598, B 365788 594276 596. Teleport only with z at ground level.
- R39 Flat ground for animation: tb1 yard 650302 477894 1235 (A) / 650602 477894 1235 (B). Not the SIRCAA plaza (safe zone, no weapons).
- R40 `par` and `-Clients 2` are pair 2 only; a plan that needs them says `pair 2` in its note.
- R41 A plan never contains `down`, `lock`, `unlock` or `kill` of a game outside a spec; the spec `kill A` + `launch A` is the only reboot form and needs the INV note (R27).

## 7. Test saves (C:\modding\s2harness\testsave, `harness.ps1 saves` lists them)

| save | where | quest state | use it for |
|---|---|---|---|
| master_20261018_host | grass by the lake, A 365788,594200,598 / B 365788,594276,596, 17:25, DLC mask 14 (Steam open) | E02_MQ01 (3 active), E02_MQ03 (9 active) | default; spawn scenes, combat, animation, anything place-independent. Zalissya is NOT populated here |
| usercity_20261029_host | user's save in Zalissya, 19:57 | E02_MQ03 (9 active) | village population, copies near B, A-Life counts (v130f2) |
| scanner_20261030_host | prologue cave before the scanner, 01:00, no DLC | E01_MQ01 (28 active, CaveScanningPoint pending) | scanner interaction, quest advance on the host, qdiv (v130c/d) |
| master_20261018_host_stripped_nolacrash | stripped copy | - | do not use: crashes the host 3/3 |

## 8. -Check warnings

Implemented (plans\planlib.ps1 Get-PlanWarnings): host tp after client tp, tp B without the pull expect_not, devcmd missing, host:$var without a scene on A, key without assert noui or manual, one-shot lost after wait + mark, up without -Reuse, release DLL, up without -Calm, up without -Save when the spec teleports, fire/animcheck/firing burst without assert weapon, any of them without assert alive.
Not implemented: note without numbers (token-only red), `up -Save X` after another save, logcheck inside -Check.
