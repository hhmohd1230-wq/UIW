# Check-in #6 — 2026-10-01

No code change. 51.9 has zero fights and the repo is clean, built and deployed;
the queue is blocked on a play session, not on a commit. Pushing anything that
touches `dist/` right now would confound the one variable 51.9 was staged to
measure (`CONFIG.NLBarrierDodge = false`).

State verified this run:

- `git status` clean, HEAD `a029b19`.
- `python build.py` then `build-openmap.ps1 -Volt` reproduce
  `dist/UIW_openmap.lua` byte-identically (sha256 `6adca4cf17b84075`,
  1319387 bytes). The `$voltDir` rename holds: `-Volt` copies both
  `UIW_openmap.lua` and `bossprobe.lua`.
- The Volt workspace copy matches that hash. 51.9 + the probe are deployed.
- No Roblox client connected, so nothing was loaded and nothing was verified
  in-game. Same condition as the 51.9 and probe check-ins.
- `bosslog.txt` last written 2026-09-20 09:10. 271 fights, newest tag 51.8.

## 1. The Champion did not recover. The open map is the cost, not the walls.

Midgardian Champion, `%/s` by era, open map only:

| era | n | %/s | deaths/fight | dist |
|---|---|---|---|---|
| 50.0-50.6 | 21 | 1.28 | 0.67 | 74 |
| 50.9-51.2 | 17 | 0.77 | 0.82 | 88 |
| 51.3-51.8 | 14 | 0.82 | 0.79 | 73 |

Solid walls in 51.1/51.2 did nothing: eight builds flat at 0.64-0.96 after
1.33-1.59. The split that does track is the map layer itself, over all builds
50.0+:

| build | n | %/s | deaths/fight |
|---|---|---|---|
| open map | 52 | 0.99 | 0.75 |
| plain | 7 | 1.37 | 0.29 |

That is the reasoning 51.9 already acted on, and it is unmeasured. n=7 on the
plain arm is thin - the first 51.9 run is the test, and if the Champion comes
back toward 1.3 with the gates closed, the barrier experiment was the cost.

## 2. Bob's clamps: the ring is not the thing that moved. The wedge was.

| era | n | %/s | deaths/f | dist | fights with still >= 50% |
|---|---|---|---|---|---|
| 50.4-50.6 | 15 | 0.77 | 0.80 | 122 | 0/15 |
| 50.9-51.2 | 10 | 0.00 | 0.60 | 248 | 8/10 |
| 51.3-51.8 | 16 | 0.48 | 0.75 | 134 | 1/16 |

The 50.9-51.2 window is not a planner result. Eight of ten fights were spent
standing still at 208-287 studs for 0.00%/s - the character was wedged, and
every aggregate over that window is an average of a stuck run. 51.3+ ends it:
one frozen fight in sixteen, `still` back to 10-19%.

So the answer to "did 51.2's ring clamp bring dist back to 80-116" is no, and
the question does not have a clean answer, because 51.2's three Bob fights
(dist 287, 0.00%/s, still 76%) measured the wedge rather than the clamp. On
51.3-51.8, dist sits at 134 against a reach of 88 and damage at 0.48 - short
of the 0.84 target and well off 50.5's 116/1.00. Deaths 0.75 is inside the
0.80 target.

`NLBobRinged` and `NLBobPillarClear` still cannot be confirmed to fire. Both
are written on the DodgeSolver (`v44_28_live_windows.lua:972, :985`) and
neither reached a log before the probe commit. `bossprobe.lua` now reports
both as per-fight deltas (`ring R/P`); the next run reads them.

## 3. Unwedge: count unknown, but the escape is working as an escape.

`controller.Unwedges` / `UnwedgeAt` (`v51_01_unwedge.lua:74-75`) have never
been written anywhere readable, so "more than a few times per run" is still
unanswered - `bossprobe.lua` adds `unwedge N@x,y,z | stuck N`.

What the log does show is that the thing being escaped from stopped happening.
Frozen Bob fights went 8/10 on 50.9-51.2 to 1/16 on 51.3-51.8. If the next
run shows a high `unwedge` count on top of that, the escape is papering over a
live cause and the `UnwedgeAt` coordinates are the lead. If it shows a low
count, the solid walls are keeping us out and the escape is the backstop it
was written to be.

## 4. The cycle predictor cannot fire, and neither option in the question is the fix.

`NLCycleSwitches` is nil for a reason that is not about Bob.

`v50_07_cycle.lua:96-110` wraps `DodgeSolver:Solve`, calls the inner solve
first, and only then flips `self.NLBossMode` from `"attack"` to `"evade"`.
Two things follow:

- The flip happens after `best` and `yaw` were already computed and returned,
  so it cannot change the frame it fires on.
- The only consumer of `NLBossMode` is inside `Solve` itself
  (`v44_28_live_windows.lua:1478`, the sideways-to-the-Champion rule), and
  `Solve` reassigns `NLBossMode` unconditionally at `:1151`/`:1156` *before*
  reaching that read. The wrapper's write is overwritten every call before
  anything observes it.

So the predictor is inert for the Champion too, not just for Bob - and the
`NLEvadeGoalScale` weighting at `:1157` keys off the local `pressed`, not off
`NLBossMode`, so even a surviving flip would not reweight anything. Bob is
additionally excluded at `:1151`, which sets `NLBossMode = nil` for anything
that is not `wide` or `champion`; the original diagnosis is correct as far as
it goes.

Fixing the ordering is tempting and premature. The prediction has to become an
*input* to the mode decision - computed before `Solve` runs, folded into
`pressed` - rather than a write after it. But before rewiring anything, the
probe's `due=` field answers whether the predictor holds any data at all:
`Workspace.ChildAdded` in `v50_07_cycle.lua:56` fires only for direct children
of Workspace. If a Bob fight reads `due=never`, `seen` is empty, the attack
names or their parenting are the bug, and the ordering fix would have changed
nothing - the same mistake as treating the unwedge escape as the fix.

Decide after one run with the probe: `due=never` sends us to the listener;
a live `due=` with `mode none` on Bob and `mode attack/evade` on the Champion
sends us to the ordering.

## What check-in #7 needs

One run of `bossprobe.lua` on 51.9, with the Champion and Bob each fought a
few times. The probe loadstrings the bundle itself, so it is a single
`execute-file` on `bossprobe.lua` - no separate load.

Reading order on the new fight line: `due=` first (does the predictor see
anything), then `mode` (is Bob really outside the split), then
`unwedge`/`stuck` (is the escape a backstop or a crutch), then `ring R/P` (do
the 51.2 clamps fire at all), and the Champion's `%/s` against 1.3 to settle
the barrier question.

## The repo has forked, and this needs a decision

Found while pushing this note: `origin/main` is 31 commits ahead of the local
tree, and the local tree is 3 commits ahead of it. The merge base is `104bf54`
(NL 51.2). Nothing was merged, pulled or force-pushed - the fork is left
exactly as found.

- local only: 51.9 (`52c1336`), the probe (`a029b19`), this note. Never pushed.
- remote only: a healer system (988 lines), a carry-party system (444), the
  Enchanted Dragon entry, a Steampunk boss entry, a forward combat dodge
  (`v44_34`), HUD work, and CI `Build dist from src` commits.

Four overlaps decide how a merge has to go:

1. `CONFIG.NLBarrierDodge` defaults to `false` locally and `true` on the
   remote. A careless merge takes the remote's `true` and 51.9's single
   variable is gone before it was ever measured.
2. `tools/bossprobe.lua` does not exist on the remote. A reset to remote loses
   the instrument - the same exposure the probe commit was written to close.
3. The remote's `v51_01_unwedge.lua` is *better* and the local tree lacks it:
   a cleanup hook so a reload does not stack Heartbeat connections, a
   Steampunk Sewers exclusion so ghosting cannot drop us off the walkway, and
   a gate on `dungeonStarted` + `Dungeon.HasSeenEnemies` so the stuck counter
   does not run outside a live fight. That last one bears directly on question
   3: it suppresses exactly the spurious unwedges we were about to go counting.
4. The remote's `v50_01_force_walkspeed.lua` adds a healer bypass
   (`controller.HealerEnabled`). Solo Nightmare is unaffected - WalkSpeed
   forcing stays as decided.

`dist/` on the remote is CI-built from remote `src`, so it is a different
bundle from the one deployed to the Volt workspace. The deployed build is
still 51.9 + probe (sha256 `6adca4cf17b84075`), so a measurement run can
happen right now without resolving any of this.

Suggested order, for the user to confirm: measure 51.9 first on what is
already deployed, then merge remote into local keeping `NLBarrierDodge = false`
and taking the remote's unwedge file wholesale, then rebuild and re-measure.
Merging first would mix the barrier variable with 8666 lines of unrelated
change and neither would be readable.
