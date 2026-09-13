# Abobo extraction findings

Source: `assets/source_sheets/jick-abobo.png`, copied unchanged from the supplied Double Dragon sheet (772×468). Native inspection confirms the throw reference is the four poses at x≈8,46,76,113 in the y=278–360 band, not the raised-arm attacks in the second row. Exact matte: RGB(74,167,168), removed without fuzz.

Canvas decision: **96×96**, bottom-center pivot **(48,96)**. Centered AnimatedSprite2D at scale 1 expects **position (0,-48)** (or equivalent sprite offset, not both). Billy stays **80×80**, pivot **(40,80)**, centered visual **(0,-40)**. Scale node translation appropriately if a visual scale is used. Nearest filtering; no art resizing.

The script is the authoritative crop manifest (source pixel coordinates, exclusive rectangle bottom). Throw crops share floor y=361 and explicit planted-body x anchors; this retains bend/rise rather than vertically trimming every pose. Other Abobo frames use the shared lowest-eight-opaque-row foot anchor. Tallest raised-arm art requires more than the legacy 80-pixel canvas. No grabbed/thrown aliases: recommend disabling hair-grab susceptibility for Abobo rather than presenting invented victim art.

Billy's matching reference is the three poses in the y=1079–1134 band (inverted, tumbling, prone). They are new `being_thrown` frames only; existing animations/pixels must remain unchanged. Shared source floor y=1135 and body-centered horizontal anchors are visual pivots, NOT a simulated ballistic arc: gameplay must move the victim root/visual independently during flight.

## Regeneration and verification

Run `bash tools/extract_abobo_frames.sh` (ImageMagick + Python 3). It regenerates 29 frames, the clean sheet, `abobo_sprite_frames.tres`, and `contact_sheet.png`. `bash tools/extract_billy_frames.sh` also upserts only Billy's `being_thrown` resource entry via `tools/lib/abobo_sprite_resources.py`; the rest of Billy's resource is preserved. The shared extraction helper accepts optional canvas dimensions with unchanged 80×80 defaults.

Native inspection of the generated Abobo contact sheet and Billy three-frame contact sheet confirms the reference pose order, intact extremities, transparent matte and baseline alignment. Pixel-count validation confirmed the initial 27 Abobo crops retain every non-matte pixel (no canvas clipping); integration also extracts the two existing fall crops for death, for 29 total frames. Billy regeneration produced no changes to any existing PNG. Resource updater rerun was byte-identical; shell syntax checks passed. The extraction worker did not run Godot; integration verification is documented in `features/actors/enemies/abobo/README.md`. The source copy was already tracked and is byte-identical to the supplied file.

## Pose timing / integration recommendations

These are extraction-worker recommendations, not the final runtime schedule. The implemented 60 Hz paired timeline (including death's three-pose fall) is documented in `features/actors/enemies/abobo/README.md`; logical physics frames, not SpriteFrames playback speeds, drive combat.

- Abobo `throw`: non-looping, 10 fps with duration multipliers **1.4, 1.2, 1.4, 1.8**: **140 / 120 / 140 / 180 ms** (580 ms total). Poses: bent reach, gather, chest lift, overhead release. Recommended release at entry to pose 3 (**400 ms**), not animation completion.
- Billy `being_thrown`: non-looping, 10 fps with multipliers **1.2, 1.6, 2.4**: **120 / 160 / 240 ms** (520 ms total). Start inverted pose on release, then tumble; synchronize prone pose to actual landing if flight duration differs. No pre-release carry pose is supplied by this three-pose reference.
- Abobo idle 4 fps (one static pose); walk/walk_up 8 fps; punch 10 fps (extension at pose 1, 100 ms); hurt/status1 8 fps; status2 5 fps (single crouched stun); knockdown 8 fps (fall, tumble, prone, get-up); death uses fall, tumble, then holds the prone frame, non-looping. For lethal knockdown do not play the get-up frame.
- Art faces right initially. Use whole-sequence mirroring for left-facing action; do not mirror individual tumble/turn poses. Throw anchors x=20/55/87/137 are planted-body estimates, not hand sockets. Billy anchors x=309/354/410 center the rotating body; no hand-contact pairing is encoded in SpriteFrames.
- Floor is the exclusive canvas bottom: lowest opaque row is y=95 (Abobo), y=79 (Billy). A centered sprite translated by half its canvas height puts that bottom edge at the actor's feet. Keep any flight offset separate from this permanent visual offset.
