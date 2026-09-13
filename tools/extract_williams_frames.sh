#!/usr/bin/env bash

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE="$PROJECT_ROOT/assets/source_sheets/williams.png"
readonly OUTPUT_ROOT="$PROJECT_ROOT/assets/sprites/williams"
readonly CLEAN_SHEET="$OUTPUT_ROOT/source/williams_clean.png"
readonly MATTE='#738DA5'

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
  "$OUTPUT_ROOT/walk" \
  "$OUTPUT_ROOT/walk_up" \
  "$OUTPUT_ROOT/punch" \
  "$OUTPUT_ROOT/hurt" \
  "$OUTPUT_ROOT/knockdown" \
  "$OUTPUT_ROOT/death"

# The original sheet is RGB with a flat matte. Preserve the pixels exactly and
# remove only the known matte color; fuzzy removal damages palette colors.
magick "$SOURCE" -alpha on -transparent "$MATTE" -strip "$CLEAN_SHEET"

# shellcheck source=lib/frame_extraction.sh
source "$PROJECT_ROOT/tools/lib/frame_extraction.sh"

# Coordinates refer to the original 616×1678 source sheet. Each rectangle is
# the pose's opaque bounding box padded by two matte pixels; neighbors sit at
# least eight pixels away so the padding never captures adjacent art.
extract_frame "idle/idle_00.png" "30x67+6+42"

extract_frame "walk/walk_00.png" "30x67+72+42"
extract_frame "walk/walk_01.png" "21x66+106+43"
extract_frame "walk/walk_02.png" "24x67+131+42"
extract_frame "walk/walk_03.png" "30x66+159+43"

extract_frame "walk_up/walk_up_00.png" "28x64+225+45"
extract_frame "walk_up/walk_up_01.png" "28x65+257+44"
extract_frame "walk_up/walk_up_02.png" "25x65+289+44"
extract_frame "walk_up/walk_up_03.png" "25x64+318+45"

extract_frame "punch/punch_00.png" "32x64+6+129"
extract_frame "punch/punch_01.png" "50x64+42+129"
extract_frame "punch/punch_02.png" "32x63+187+130"

extract_frame "hurt/hurt_00.png" "31x67+6+641"
extract_frame "hurt/hurt_01.png" "28x67+73+641"

extract_frame "knockdown/knockdown_00.png" "51x50+200+658"
extract_frame "knockdown/knockdown_01.png" "51x36+255+672"
extract_frame "knockdown/knockdown_02.png" "52x34+310+674"
extract_frame "knockdown/knockdown_03.png" "34x47+366+661"

extract_frame "death/death_00.png" "52x34+310+674"

echo "Generated Williams frames under: $OUTPUT_ROOT"
