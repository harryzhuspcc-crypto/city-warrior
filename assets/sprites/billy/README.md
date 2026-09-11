# Billy prototype frames

Generated from `assets/source_sheets/billy-lee.png` by:

```bash
./tools/extract_billy_frames.sh
```

Every output uses an 80×80 transparent canvas. The midpoint of each pose's
lowest opaque foot-contact band is aligned to bottom-center so the
`AnimatedSprite2D` origin consistently represents the actor's supporting feet.

Walking uses `walk_up` only when Up/W is dominant. Down/S and horizontal
movement share the front-facing `walk_down` animation.

Jumping uses two physics-selected poses: `jump_00` while rising and `jump_01`
while descending. Sprite playback does not control jump physics.
