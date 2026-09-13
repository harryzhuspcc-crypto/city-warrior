# Audio

- `music_player.gd` — a stage's background music. The level owns one and hands
  it a track in the scene; it starts on ready and refuses a track that does not
  loop.
- `actor_audio_component.gd` — actor-local combat presentation. It plays impact
  SFX only for confirmed hits, action voices when voiced attacks begin, and a
  death voice from the actor's health signal. Both Billy and Williams play
  `sfx_10_fall_to_the_ground.wav` on SFX once per ground fall, not on hit/death
  entry: ordinary knockdown/death lands at reaction frame 16; a hair throw
  lands with its prone pose at throw frame 32. Throw handoff and prone death
  do not replay the landing. Normal jumps and aerial-attack landings are not
  falls and remain silent. The reaction component owns the landing event;
  audio only listens.

`default_bus_layout.tres` separates Music, SFX, and Voice under Master so each
category can be mixed independently.

The prototype level also owns a non-looping `StageClearMusic` player. Reaching
the exit after all encounters stops the looping theme and plays the mission-
complete cue once.

Music is level-owned rather than an autoload: nothing survives a scene change
yet, and one stage cannot justify inventing the pattern. When a second stage
arrives and music has to outlive the level, that is the moment for an autoload.
