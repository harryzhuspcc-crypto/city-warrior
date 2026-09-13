# Williams staged reactions and hair-grab combat

## Controls

1. Hit Williams: **status1** (two recoil poses).
2. Hit him again **before status1 recovers**: **status2** (stomach pose).
3. Either hit during status2 to knock him down, or **walk Billy into his body** while status2 is still active to grab his hair. There is no grab button.
4. While holding: **L / kick** knees the captive; **J / punch OR K / jump** throws him backward, opposite Billy's original facing. Movement/facing are locked while paired. Jump-containing chords also throw rather than starting special moves.

## Timing and assumptions

At 60 physics ticks/sec:

- Status1 lasts **30 frames / 0.5s**; status2 lasts **60 frames / 1s**. Both durations are exported in Williams' `FighterStats`. Recoil slides for only six frames so Billy can close to contact.
- Recovery immediately clears the stage. Billy's own existing post-recovery hit chain is unchanged. Explicit knockdown special moves/finishers still knock Williams down immediately; lethal hits still take priority and retain the existing death voice.
- Ordinary nonlethal knockdowns request **no fall/death sound**. Existing punch/kick contact sounds remain.
- Grab requires horizontal walking into an actual body slide collision, within six pixels of the victim's lane. Status1, recovered/downed/dead/already-held victims and attacking/airborne/elevated Billy cannot start it. No proximity-only grab or cross-lane snapping.
- Entry shows up to eight frames, then holds until an action or interruption. Fresh knee/throw commands can interrupt entry immediately. The original status2 timer no longer runs once captured. The idle hold does not automatically knee.
- A knee takes 20 frames, deals **8 damage once** on frame 4, plays one kick contact sound and returns to the hold. Repeated knees do not run the ordinary three-hit reaction chain. A lethal knee releases both actors.
- A throw takes 40 frames, deals **20 damage once** on frame 8 and carries a surviving victim 100 pixels backward with a 35-pixel visual arc. World/actor collisions can shorten the distance. The victim lands prone, then uses the existing get-up timing; the fall is not replayed. A lethal throw releases immediately into the existing death reaction.
- Pairing uses 30-pixel hand/head spacing. If a wall prevents moving Williams outward, Billy steps backward instead. If neither actor has space, no pair is acquired and the status2 window remains available.
- Inputs during a knee/throw are discarded, not queued into another attack after release.

## Implementation

- `HitReactionComponent`: opt-in staged reaction policy; Williams enables it, Billy does not.
- `HairGrabComponent`: actor-local pair mediator, fixed physics clock, authored pose schedules and collision-aware throw motion. Player/enemy orchestrators retain ownership of their states and health/hurtbox damage path.
- Cleanup clears pair references before notifications, removes both collision exceptions, restores the victim's visual baseline, and clears buffered controls. Hits, direct reactions, death, forced attacks, scene removal and freeing either participant release the pair. Williams also clears a removed/freed Billy from its AI target cache.
- `billy_knee.tres` and `billy_hair_throw.tres`: named damage/presentation payloads; they are delivered only to the captive, never as a broad ordinary hitbox.

## Artwork

22 new transparent 80x80 frames, reproducibly sliced from the existing source sheets:

| Billy | Frames | Williams | Frames |
|---|---:|---|---:|
| hair_grab | 4 | status1 | 2 |
| knee | 2 | status2 | 1 |
| hair_throw | 4 | grabbed | 3 |
| | | thrown | 6 |

Existing knockdown frames already contain the three reference fall poses plus a get-up pose and are preserved. The new pair/flight frames use fixed source body anchors rather than recentering every raised foot or rotating limb. Extraction manifests record crop rectangles and anchors in `tools/extract_billy_frames.sh` and `tools/extract_williams_frames.sh`. Existing PNGs and old SpriteFrames definitions are unchanged.

All eight supplied reference screenshots, source sheets, extracted frames and offline paired composites were inspected using native image reading. No browser/computer-use or interactive game session was used.

## Verification

- `python3 tools/run_smoke_tests.py`: all 12 suites, including `smoke_test_hair_grab.gd`.
- New coverage: exact recovery boundaries, stage resets, silent nonlethal fall, pose resources, walking acquisition in both directions, eligibility/lane checks, repeated knees, both throw controls, chord priority, backward arc/landing/get-up, wall collision, and paired interruption/death/removal/free cleanup.
- Existing Williams regression now checks follow-up punches **within** active staged reactions instead of expecting post-recovery hit accumulation. Legacy feet-pivot audits retain their existing coverage; the new fixed-anchor poses have their own canvas/animation contract checks.
- Both extraction scripts pass `bash -n`; rerunning them leaves all 99 sprite/source PNG hashes unchanged. `git diff --check` passes.
- Engine: `/Applications/Godot.app/Contents/MacOS/Godot`, Godot 4.7.2; headless import and all smoke suites pass without diagnostics.
- Additional `--headless --quit-after 120` main-scene boot loads successfully but reports MP3 playback/resource leaks at forced shutdown. This was reproduced with only a plain `AudioStreamPlayer` playing `02_slums.mp3`, with no actors or combat code instantiated. The unrelated music teardown behavior was left unchanged; it does not occur in the regression runner's clean teardown.
