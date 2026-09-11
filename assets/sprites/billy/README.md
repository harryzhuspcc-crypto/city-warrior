# Billy prototype frames

Generated from `assets/source_sheets/billy-lee.png` by:

```bash
./tools/extract_billy_frames.sh
```

Every output uses an 80×80 transparent canvas. Cropped pixels are aligned to the bottom center so the `AnimatedSprite2D` origin can consistently represent the actor's feet.

Walking uses `walk_up` only when Up/W is dominant. Down/S and horizontal
movement share the front-facing `walk_down` animation.
