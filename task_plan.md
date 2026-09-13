# Task Plan: Stage Music

The previous plan (hit-confirmed combo chains) is complete; it is kept in
`documents/double-dragon/completed/combo_chains_plan.md` and recorded in
`progress.md` and `findings.md`.

## Goal

Bring the arcade soundtrack into the project and give the prototype alley its
stage track. Two halves:

1. Fetch all twelve tracks of the arcade rip and land them in the asset tree
   under the project's naming conventions, alongside the sprite and stage
   sheets they match.
2. Play `Slums (Arrival of the Black Warriors)` — the arcade's stage 1 theme —
   as the prototype alley's background music, looping for as long as the stage
   runs.

Off the plan's Section 9 list, like the ladder work was: the plan says nothing
about audio at any point. Recorded here so the insertion is visible.

## Agreed test seams

- `MusicPlayer`: `stream`, `playing`, `loops()`, `stop_music()`. The stage's
  one music node. It owns the decision that a stage track must loop, which is
  the only part of playing music that can be wrong without being heard for
  three minutes.
- `PrototypeAlley.music`: the level exposes its music player the same way it
  exposes every other collaborator, so a slice can assert the stage starts its
  own track rather than assert against the audio server.

Not seams: the mixing itself. Headless Godot runs a dummy audio driver, so
"is sound leaving the machine" is not a question a smoke test can answer. The
suite checks what is asked of the audio server, not what comes out of it.

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | Fetch the twelve tracks into `assets/audio/bgm/` | [complete] |
| 2 | Import them as Godot audio, looping where a track is a stage loop | [complete] |
| 3 | `MusicPlayer` + the prototype alley's own track (red first) | [complete] |
| 4 | Smoke suite, mutation-checked | [complete] |
| 5 | Verify in the real renderer, then records | [complete] |

## Scope decisions

- **Level-owned, not an autoload.** The project has no autoloads at all, and
  one stage cannot justify inventing the pattern. The level orchestrator
  already owns stage state and wires every other collaborator; music joins
  them. When the plan's "additional stages" item lands and music has to
  survive a scene change, that is the moment for a music autoload — not now.
- **No audio bus layout.** A `Music` bus is the conventional seam for volume,
  but nothing yet has a second sound to balance against. Left as a follow-up
  so this change stays the size of its ask.
- **The tracks stay as downloaded.** They are 64 kbps MP3s; re-encoding to
  Ogg for a seamless loop point would lose a second generation from an already
  lossy source. Noted in `findings.md` as the fix if the loop seam is audible.

## Errors Encountered

| Error | Attempt | Resolution |
|-------|---------|------------|
| `Parse Error: Identifier "MusicPlayer" not declared` | 1 | Expected red: the component did not exist yet |
| `Parse Error: Could not find type "MusicPlayer"` after writing it | 1 | A new `class_name` only reaches the script class cache on an editor import pass |
| `Parse Error: Static function "is_playback_active()" not found` | 1 | Not in 4.7's `AudioServer`; introspected `ClassDB` for what is, and waited on the server by time instead |
| Five suites red with leaked stream / resource still in use | 1 | Stopped the track on `_exit_tree` — measured later to change nothing, and removed |
| Same, still red | 2 | Also dropped the stream reference on teardown; the server holds its own, so no change. Reverted |
| Same, still red | 3 | Diagnosed properly: the release happens on the audio server's mixing pass, not a frame. `tools/lib/audio_settle.gd` waits on it in wall-clock |
| Two suites still red after that | 4 | They never freed their level at all, so nothing had stopped the music for the wait to wait on; `free_level` now names the whole teardown |
| The music suite still red | 5 | Its level lived a single frame, so the stop overtook a start the server had not finished; the slice now lets the track get under way first |
| Five "clean" runs that proved nothing | — | The script had a parse error and never executed. A suite that is green because it did not run looks exactly like one that passed |

## Evidence

| Claim | Evidence |
|-------|----------|
| Twelve tracks fetched intact | `file` reports MPEG layer III for all twelve; `afinfo` durations match the album listing to the second; 21.6 MB against the listing's 21 MB |
| The stage plays Slums, looping | `smoke_test_music.gd` slices 4 and 5: the level's player holds `02_slums.mp3` and is still playing a moment later; seeked to 182.57 s it climbs to 183.03 s and returns to 0.06 s with `loop_count == 1` |
| The loop table is real configuration, not a guess | Mutation: importing the stage track with `loop=false` fails with "02_slums.mp3 must loop, and does not" |
| The stage actually starts its track | Mutation: removing `play()` from `_ready()` fails with "Stage 1 must start its track with the level" |
| Sound reaches a real device | Non-headless run: CoreAudio at 48 kHz, playback position advancing, −17.4 dB peak on the master bus |
| Nothing else regressed | All ten suites pass, stable across three consecutive full runs; `git diff --check` clean; no probe scripts left |
| Quitting with music playing is not clean | 3 runs in 5 of a 240-frame main scene report a held stream at exit, with or without a `stop()` on `_exit_tree`. An engine shutdown race; recorded rather than papered over |
