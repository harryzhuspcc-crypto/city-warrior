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
  "$OUTPUT_ROOT/punch" \
  "$OUTPUT_ROOT/hurt" \
  "$OUTPUT_ROOT/knockdown" \
  "$OUTPUT_ROOT/death"

# Remove superseded walk directories so stale generated frames cannot be
# accidentally reintroduced in SpriteFrames.
rm -rf "$OUTPUT_ROOT/walk" "$OUTPUT_ROOT/walk_side"

# The original sheet is RGB with a flat matte. Preserve the pixels exactly and
# remove only the known matte color; fuzzy removal damages palette colors.
magick "$SOURCE" -alpha on -transparent "$MATTE" "$CLEAN_SHEET"

extract_frame() {
  local relative_path="$1"
  local crop_rect="$2"
  local destination="$OUTPUT_ROOT/$relative_path"

  magick "$CLEAN_SHEET" \
    -crop "$crop_rect" +repage \
    -trim +repage \
    -gravity south \
    -background none \
    -extent 80x80 \
    "$destination"
}

# Coordinates refer to the original 611×1341 source sheet. Keep this list as
# the reproducible slicing manifest while the prototype animation set evolves.
extract_frame "idle/idle_00.png" "32x75+10+8"
extract_frame "idle/idle_01.png" "32x75+10+88"

extract_frame "walk_down/walk_down_00.png" "32x75+10+88"
extract_frame "walk_down/walk_down_01.png" "32x75+43+88"
extract_frame "walk_down/walk_down_02.png" "32x75+76+88"
extract_frame "walk_down/walk_down_03.png" "32x75+109+88"

extract_frame "walk_up/walk_up_00.png" "32x75+153+88"
extract_frame "walk_up/walk_up_01.png" "32x75+186+88"
extract_frame "walk_up/walk_up_02.png" "32x75+220+88"
extract_frame "walk_up/walk_up_03.png" "32x75+252+88"

extract_frame "punch/punch_00.png" "42x72+10+270"
extract_frame "punch/punch_01.png" "58x72+50+270"
extract_frame "punch/punch_02.png" "45x72+103+270"

extract_frame "hurt/hurt_00.png" "55x75+5+920"
extract_frame "hurt/hurt_01.png" "70x75+52+920"

extract_frame "knockdown/knockdown_00.png" "55x75+5+920"
extract_frame "knockdown/knockdown_01.png" "55x75+66+920"
extract_frame "knockdown/knockdown_02.png" "54x75+123+920"
extract_frame "knockdown/knockdown_03.png" "48x75+180+920"

extract_frame "death/death_00.png" "54x75+123+920"

echo "Generated Billy frames under: $OUTPUT_ROOT"
