#!/usr/bin/env bash
set -euo pipefail
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE="$PROJECT_ROOT/assets/source_sheets/jick-abobo.png"
readonly OUTPUT_ROOT="$PROJECT_ROOT/assets/sprites/abobo"
readonly CLEAN_SHEET="$OUTPUT_ROOT/source/abobo_clean.png"
FRAME_CANVAS_WIDTH=96 FRAME_CANVAS_HEIGHT=96
command -v magick >/dev/null || { echo 'ImageMagick is required.' >&2; exit 1; }
[[ -f "$SOURCE" ]] || { echo "Missing source: $SOURCE" >&2; exit 1; }
mkdir -p "$OUTPUT_ROOT/source"
for animation in idle walk walk_up punch hurt status1 status2 knockdown death throw; do
  mkdir -p "$OUTPUT_ROOT/$animation"
done
magick "$SOURCE" -alpha on -transparent '#4AA7A8' -strip "$CLEAN_SHEET"
# shellcheck source=lib/frame_extraction.sh
source "$PROJECT_ROOT/tools/lib/frame_extraction.sh"
extract_frame idle/idle_00.png '32x84+6+38'
extract_frame walk/walk_00.png '33x84+74+38'
extract_frame walk/walk_01.png '33x80+110+42'
extract_frame walk/walk_02.png '34x80+149+42'
extract_frame walk/walk_03.png '32x80+188+42'
extract_frame walk_up/walk_up_00.png '33x82+255+40'
extract_frame walk_up/walk_up_01.png '34x80+293+42'
extract_frame walk_up/walk_up_02.png '35x82+332+40'
extract_frame walk_up/walk_up_03.png '33x80+371+42'
extract_frame punch/punch_00.png '35x78+192+284'
extract_frame punch/punch_01.png '60x78+229+284'
extract_frame punch/punch_02.png '34x78+293+284'
extract_frame hurt/hurt_00.png '34x80+6+377'
extract_frame hurt/hurt_01.png '33x80+78+377'
extract_frame status1/status1_00.png '34x80+6+377'
extract_frame status1/status1_01.png '33x80+78+377'
extract_frame status2/status2_00.png '34x63+186+394'
extract_frame knockdown/knockdown_00.png '64x59+256+398'
extract_frame knockdown/knockdown_01.png '65x49+326+408'
extract_frame knockdown/knockdown_02.png '65x40+395+417'
extract_frame knockdown/knockdown_03.png '43x55+465+402'
extract_frame death/death_00.png '64x59+256+398'
extract_frame death/death_01.png '65x49+326+408'
extract_frame death/death_02.png '65x40+395+417'
extract_anchored_frame throw/throw_00.png '33x84+6+277' 20
extract_anchored_frame throw/throw_01.png '25x84+44+277' 55
extract_anchored_frame throw/throw_02.png '32x84+74+277' 87
extract_anchored_frame throw/throw_03.png '41x84+111+277' 137
python3 "$PROJECT_ROOT/tools/lib/abobo_sprite_resources.py" "$PROJECT_ROOT"
# Diagnostic sheet excludes clean source; labels retain animation/pose identity.
magick montage "$OUTPUT_ROOT"/{idle,walk,walk_up,punch,hurt,status1,status2,knockdown,death,throw}/*.png \
  -set label '%t' -label '%t' -font Helvetica -pointsize 10 \
  -background '#303840' -fill white -geometry 96x112+4+4 -tile 6x \
  "$OUTPUT_ROOT/contact_sheet.png"
echo "Generated Abobo frames and resource under: $OUTPUT_ROOT"
