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
  "$OUTPUT_ROOT/kick" \
  "$OUTPUT_ROOT/elbow" \
  "$OUTPUT_ROOT/head_attack" \
  "$OUTPUT_ROOT/back_kick" \
  "$OUTPUT_ROOT/jump_kick" \
  "$OUTPUT_ROOT/hurt" \
  "$OUTPUT_ROOT/knockdown" \
  "$OUTPUT_ROOT/death"

# Remove superseded walk directories so stale generated frames cannot be
# accidentally reintroduced in SpriteFrames.
rm -rf "$OUTPUT_ROOT/walk" "$OUTPUT_ROOT/walk_side"

# The original sheet is RGB with a flat matte. Preserve the pixels exactly and
# remove only the known matte color; fuzzy removal damages palette colors.
magick "$SOURCE" -alpha on -transparent "$MATTE" -strip "$CLEAN_SHEET"

extract_frame() {
  local relative_path="$1"
  local crop_rect="$2"
  local destination="$OUTPUT_ROOT/$relative_path"
  local trimmed_pose
  trimmed_pose="$(mktemp -t billy-frame).png"

  magick "$CLEAN_SHEET" \
    -crop "$crop_rect" +repage \
    -trim +repage \
    "$trimmed_pose"

  local pose_width
  local pose_height
  read -r pose_width pose_height < <(
    magick identify -format '%w %h\n' "$trimmed_pose"
  )

  # Use the lowest eight opaque rows as the feet/lower-leg band. Four rows can
  # see only one planted boot in wide stances; eight captures both feet while
  # staying below the torso. Align its midpoint to x=40.
  local foot_band_height=8
  if (( pose_height < foot_band_height )); then
    foot_band_height=$pose_height
  fi
  local foot_band_y=$((pose_height - foot_band_height))
  local foot_width
  local foot_x
  read -r foot_width foot_x < <(
    magick "$trimmed_pose" \
      -alpha extract \
      -crop "${pose_width}x${foot_band_height}+0+${foot_band_y}" +repage \
      -trim \
      -format '%w %X\n' \
      info:
  )

  local destination_x=$(((80 - (2 * foot_x) - foot_width) / 2))
  local destination_y=$((80 - pose_height))
  local destination_geometry
  printf -v destination_geometry '%+d%+d' "$destination_x" "$destination_y"

  magick -size 80x80 canvas:none \
    "$trimmed_pose" -geometry "$destination_geometry" -composite \
    -strip \
    "$destination"
  rm -f "$trimmed_pose"
}

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

extract_frame "kick/kick_00.png" "34x72+12+350"
extract_frame "kick/kick_01.png" "45x72+47+350"

extract_frame "elbow/elbow_00.png" "22x62+435+357"
extract_frame "elbow/elbow_01.png" "34x63+465+356"

extract_frame "head_attack/head_attack_00.png" "24x57+531+362"
extract_frame "head_attack/head_attack_01.png" "32x59+563+360"

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

echo "Generated Billy frames under: $OUTPUT_ROOT"
