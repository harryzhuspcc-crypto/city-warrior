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

# Staged hits: keep legacy hurt and four-frame knockdown (including get-up)
# unchanged. status1 is the two upright reactions; status2 is the crouched
# reaction in the SAME y=643..705 band, not the similar pose one row above.
mkdir -p "$OUTPUT_ROOT/status1" "$OUTPUT_ROOT/status2" \
  "$OUTPUT_ROOT/grabbed" "$OUTPUT_ROOT/thrown"
extract_anchored_frame "status1/status1_00.png" "27x63+8+643" 20
extract_anchored_frame "status1/status1_01.png" "24x63+75+643" 86
extract_anchored_frame "status2/status2_00.png" "23x63+139+643" 150

# Bent-over hair-grab poses: fixed body anchors and shared source floor y=619
# preserve head/hand contact instead of recentering each changing foot band.
# Native facing RIGHT; mirror Williams when Billy grabs facing right.
extract_anchored_frame "grabbed/grabbed_00.png" "38x56+71+563" 82
extract_anchored_frame "grabbed/grabbed_01.png" "32x56+117+563" 128
extract_anchored_frame "grabbed/grabbed_02.png" "30x56+157+563" 168

# Full six-pose victim sequence from the throw reference, including bent
# entry and prone landing. The tiny detached pixels at x=346..349 belong to
# the rotation pose and are intentionally retained. No per-frame flipping.
extract_anchored_frame "thrown/thrown_00.png" "38x56+227+563" 238
extract_anchored_frame "thrown/thrown_01.png" "22x56+273+563" 284
extract_anchored_frame "thrown/thrown_02.png" "47x56+303+563" 326
extract_anchored_frame "thrown/thrown_03.png" "26x56+358+563" 371
extract_anchored_frame "thrown/thrown_04.png" "47x56+392+563" 415
extract_anchored_frame "thrown/thrown_05.png" "48x56+447+563" 471

echo "Generated Williams frames under: $OUTPUT_ROOT"
