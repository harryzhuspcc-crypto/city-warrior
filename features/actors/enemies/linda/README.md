# Linda

Scene: `res://features/actors/enemies/linda/linda.tscn`.

## Stage one

The existing **Opening → Middle → Ending → Boss** chain is unchanged. Opening
and middle still contain three Williams each. Ending at **x=1040** now spawns
**three Williams, then one Linda**, using the original Williams markers and a
fourth marker at **(1184,184)** on the right of the final screen. The 45-frame
spawn spacing brings Linda in while the Williams fight is underway; she does
not wait for their deaths. All four must leave before Ending clears. Abobo
still triggers at **x=1120**, only after that clear. Camera, ladder, exit and
music gating include Linda through the encounter's normal enemy bookkeeping.

`EncounterController.enemy_sequence` is an optional exact roster for mixed
waves. Its length must match `enemy_count`; other encounters continue using
their single `enemy_scene` unchanged.

## Movement and attacks

Linda inherits the existing component-based fighter scene, replacing its
script, stats, art, attacks and voice. Her small specialization selects a punch
within 30 px, or a whip farther out (AI reach 44 px, depth tolerance 6 px).
The shared AI handles approach, depth alignment, cooldown and retreat.

- 45 HP, horizontal/depth speed 65/42 px/s; 55-frame attack cooldown.
- Punch: 12 startup / 4 active / 16 recovery frames, 8 damage.
- Whip: 18 startup / 5 active / 21 recovery frames, 10 damage. Four poses
  start at frames 0/8/18/23; the active window uses the extended-whip pose.
- Shared staged reactions, knockdown/get-up and death clocks. No Williams-only
  hair-grab poses or Abobo throw behavior are applied to Linda.
- Confirmed whip hits request `sfx_19_whip.wav` through **SFX**; misses are
  silent, matching existing impact-audio behavior. Linda's death requests
  `voice_03_linda_dies.wav` once through **Voice**.

These timings and balance values are prototype choices, not arcade-exact.

## Sprite sheet / regeneration

Runtime art: `assets/sprites/linda/linda_atlas.png` (**320×800**, transparent).
It contains **28 frames**, in 80×80 cells, one animation per row:
idle, walk, walk_up, punch, whip, hurt, status1, status2, knockdown, death.
Unused cells are transparent. All art faces right; `EnemyVisuals` mirrors left.
Each cell's feet pivot is **(40,80)**; the scene retains visual offset
**(0,-40)**. Attack poses use explicit body anchors so the whip tip cannot
shift the actor. Movement uses the lower eight opaque rows as the foot anchor.

- `linda_sprite_frames.tres`: ready-to-use Godot resource, using AtlasTextures.
- `linda_atlas.json`: regions, frame counts, speeds, loop flags and source crops.
- `contact_sheet.png`: labeled preview; not used as the runtime texture.

Regenerate from the existing, unmodified `assets/source_sheets/linda.png`:

```sh
python3 -m venv /tmp/linda-art
/tmp/linda-art/bin/pip install Pillow
/tmp/linda-art/bin/python tools/extract_linda_frames.py
```

Only exact matte RGB **(74,167,168)** is removed; no smoothing, scaling or fuzzy
color removal. Fall/death frames reuse the reference fall strip; status2 uses
the low recovery pose. The inherited source-sheet licensing warning applies:
these third-party arcade assets are for prototype use, not cleared for release.

## Verification

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/smoke_test_linda.gd
python3 tools/run_smoke_tests.py
```

The Linda suite checks atlas clips, transparency, pivots, facing, independent
resources, both attacks in both directions with real overlap queries,
startup/active/recovery timing, one damage/audio event, misses, interruption,
staged reactions, get-up/death, live AI, and the real ending-to-boss progression.
It explicitly leaves Linda alive after removing the three Williams to verify
she gates Abobo, the camera, exit and boss music; her death clears exactly once.

Verified with Godot 4.7.2: clean headless import, all **14 smoke suites pass**
without diagnostics, and byte-identical asset regeneration. The labeled art
was inspected directly; no browser/desktop automation or interactive playtest
was used. As with existing music-backed level tests, use `AudioSettle` on
teardown: abrupt `--quit-after` on the live level can report audio resources
still in use while its MP3 playback is being released.
