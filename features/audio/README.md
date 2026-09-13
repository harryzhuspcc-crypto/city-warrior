# Audio

- `music_player.gd` — a stage's background music. The level owns one and hands
  it a track in the scene; it starts on ready and refuses a track that does not
  loop.

Music is level-owned rather than an autoload: nothing survives a scene change
yet, and one stage cannot justify inventing the pattern. When a second stage
arrives and music has to outlive the level, that is the moment for an autoload.
