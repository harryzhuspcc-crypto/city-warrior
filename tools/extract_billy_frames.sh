#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE="$PROJECT_ROOT/assets/source_sheets/billy-lee.png"
readonly OUTPUT_ROOT="$PROJECT_ROOT/assets/sprites/billy"
readonly CLEAN_SHEET="$OUTPUT_ROOT/source/billy_clean.png"
readonly MATTE='#80A480'

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required (missing 'magick' executable)." >&2
  exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source sheet: $SOURCE" >&2
  exit 1
fi

mkdir -p \
  "$OUTPUT_ROOT/source" \
  "$OUTPUT_ROOT/idle" \
  "$OUTPUT_ROOT/walk_up" \
  "$OUTPUT_ROOT/walk_down" \
  "$OUTPUT_ROOT/jump" \
  "$OUTPUT_ROOT/punch" \
  "$OUTPUT_ROOT/punch_cross" \
  "$OUTPUT_ROOT/uppercut" \
  "$OUTPUT_ROOT/kick" \
  "$OUTPUT_ROOT/turn_kick" \
  "$OUTPUT_ROOT/elbow" \
  "$OUTPUT_ROOT/head_attack" \
  "$OUTPUT_ROOT/back_kick" \
  "$OUTPUT_ROOT/jump_kick" \
  "$OUTPUT_ROOT/hurt" \
  "$OUTPUT_ROOT/knockdown" \
  "$OUTPUT_ROOT/death" \
  "$OUTPUT_ROOT/climb"

# Remove superseded walk directories so stale generated frames cannot be
# accidentally reintroduced in SpriteFrames.
rm -rf "$OUTPUT_ROOT/walk" "$OUTPUT_ROOT/walk_side"

# The original sheet is RGB with a flat matte. Preserve the pixels exactly and
# remove only the known matte color; fuzzy removal damages palette colors.
magick "$SOURCE" -alpha on -transparent "$MATTE" -strip "$CLEAN_SHEET"

# shellcheck source=lib/frame_extraction.sh
source "$PROJECT_ROOT/tools/lib/frame_extraction.sh"

# Coordinates refer to the original 611×1341 source sheet. Keep this list as
# the reproducible slicing manifest while the prototype animation set evolves.
extract_frame "idle/idle_00.png" "32x75+10+8"
extract_frame "idle/idle_01.png" "32x75+10+88"

extract_frame "walk_down/walk_down_00.png" "32x75+10+88"
extract_frame "walk_down/walk_down_01.png" "32x75+43+88"
extract_frame "walk_down/walk_down_02.png" "32x75+76+88"
extract_frame "walk_down/walk_down_03.png" "33x75+108+88"

extract_frame "walk_up/walk_up_00.png" "32x75+153+88"
extract_frame "walk_up/walk_up_01.png" "32x75+186+88"
extract_frame "walk_up/walk_up_02.png" "32x75+220+88"
extract_frame "walk_up/walk_up_03.png" "32x75+252+88"

extract_frame "jump/jump_00.png" "38x75+10+430"
extract_frame "jump/jump_01.png" "42x60+50+445"

extract_frame "punch/punch_00.png" "42x72+10+270"
extract_frame "punch/punch_01.png" "56x72+50+270"
extract_frame "punch/punch_02.png" "45x72+103+270"

# Punch chain, step two. The sheet's punch band authors the same punch twice
# with alternating arms - poses at x 16/53/107 are pixel-identical to those at
# x 315/352/406 - so the chain's second hit is the other arm, at x 166/201/255.
extract_frame "punch_cross/punch_cross_00.png" "27x60+166+280"
extract_frame "punch_cross/punch_cross_01.png" "46x59+201+281"
extract_frame "punch_cross/punch_cross_02.png" "28x58+255+282"

# Punch chain finisher: the rising uppercut of three-hit-punch.png, whose four
# poses are the band's last group. Pose 0 is pixel-identical to punch_02; it is
# sliced again here so the finisher's animation stands on its own.
extract_frame "uppercut/uppercut_00.png" "27x59+406+281"
extract_frame "uppercut/uppercut_01.png" "25x57+441+283"
extract_frame "uppercut/uppercut_02.png" "35x60+474+280"
extract_frame "uppercut/uppercut_03.png" "30x71+517+269"

extract_frame "kick/kick_00.png" "34x72+12+350"
extract_frame "kick/kick_01.png" "45x72+47+350"

# Kick chain finisher: the five-pose turning kick of three-hit-kick.png. The
# last two poses are the spin through, not a turn to face the other way.
extract_frame "turn_kick/turn_kick_00.png" "28x60+120+359"
extract_frame "turn_kick/turn_kick_01.png" "27x60+156+359"
extract_frame "turn_kick/turn_kick_02.png" "44x57+191+362"
extract_frame "turn_kick/turn_kick_03.png" "32x59+243+360"
extract_frame "turn_kick/turn_kick_04.png" "28x59+283+360"

extract_frame "elbow/elbow_00.png" "22x62+435+357"
extract_frame "elbow/elbow_01.png" "34x63+465+356"

extract_frame "head_attack/head_attack_00.png" "24x57+531+362"
extract_frame "head_attack/head_attack_01.png" "32x59+563+360"

# Ladder climb cycle: the five-pose rear view marked REPEAT on the sheet, band
# y 174-235. Every pose plants a foot on the band's bottom row, so the shared
# floor and the head centroid (x 23/55/89/118/149) keep the cycle steady; the
# per-pose foot band would swing the body with the lifted leg.
extract_anchored_frame "climb/climb_00.png" "22x62+16+174" 23
extract_anchored_frame "climb/climb_01.png" "24x62+46+174" 55
extract_anchored_frame "climb/climb_02.png" "24x62+78+174" 89
extract_anchored_frame "climb/climb_03.png" "21x62+110+174" 118
extract_anchored_frame "climb/climb_04.png" "22x62+139+174" 149

extract_frame "back_kick/back_kick_00.png" "28x64+16+435"
extract_frame "back_kick/back_kick_01.png" "37x39+52+460"
extract_frame "back_kick/back_kick_02.png" "22x59+436+440"
extract_frame "back_kick/back_kick_03.png" "39x62+466+437"
extract_frame "back_kick/back_kick_04.png" "26x48+513+451"

extract_frame "jump_kick/jump_kick_00.png" "24x62+121+437"
extract_frame "jump_kick/jump_kick_01.png" "28x64+153+435"
extract_frame "jump_kick/jump_kick_02.png" "37x39+189+460"
extract_frame "jump_kick/jump_kick_03.png" "44x44+234+455"
extract_frame "jump_kick/jump_kick_04.png" "37x39+286+460"

extract_frame "hurt/hurt_00.png" "58x75+5+920"
extract_frame "hurt/hurt_01.png" "55x75+66+920"

extract_frame "knockdown/knockdown_00.png" "58x75+5+920"
extract_frame "knockdown/knockdown_01.png" "55x75+66+920"
extract_frame "knockdown/knockdown_02.png" "54x75+123+920"
extract_frame "knockdown/knockdown_03.png" "48x75+180+920"

extract_frame "death/death_00.png" "54x75+123+920"

# Hair-grab band (reference: four opening poses, then four backward-throw
# poses). Explicit planted-body anchors avoid following the raised knee or
# trailing boot. All crops share source floor y=576 -> canvas pivot (40,80).
# Native initial facing is RIGHT; the throw turns left in the artwork itself.
mkdir -p "$OUTPUT_ROOT/hair_grab" "$OUTPUT_ROOT/knee" "$OUTPUT_ROOT/hair_throw"
extract_anchored_frame "hair_grab/hair_grab_00.png" "24x61+16+515" 26
extract_anchored_frame "hair_grab/hair_grab_01.png" "31x61+48+515" 60
extract_anchored_frame "hair_grab/hair_grab_02.png" "23x61+87+515" 96
extract_anchored_frame "hair_grab/hair_grab_03.png" "24x61+118+515" 130

# Independent copies of the knee-up and recovery poses, not texture aliases.
extract_anchored_frame "knee/knee_00.png" "23x61+87+515" 96
extract_anchored_frame "knee/knee_01.png" "24x61+118+515" 130

extract_anchored_frame "hair_throw/hair_throw_00.png" "24x61+174+515" 186
extract_anchored_frame "hair_throw/hair_throw_01.png" "23x61+206+515" 217
extract_anchored_frame "hair_throw/hair_throw_02.png" "50x61+237+515" 259
extract_anchored_frame "hair_throw/hair_throw_03.png" "32x61+295+515" 312

# Abobo throw victim reference: inverted, tumbling, prone. Keep the source
# floor y=1135 and body anchors; flight displacement belongs to gameplay.
mkdir -p "$OUTPUT_ROOT/being_thrown"
extract_anchored_frame "being_thrown/being_thrown_00.png" "30x56+294+1079" 309
extract_anchored_frame "being_thrown/being_thrown_01.png" "49x56+330+1079" 354
extract_anchored_frame "being_thrown/being_thrown_02.png" "49x56+386+1079" 410
python3 "$PROJECT_ROOT/tools/lib/abobo_sprite_resources.py" "$PROJECT_ROOT" billy

echo "Generated Billy frames under: $OUTPUT_ROOT"
