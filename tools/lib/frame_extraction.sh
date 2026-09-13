#!/usr/bin/env bash
# Shared feet-pivot frame extraction for character sheets.
#
# Callers must set CLEAN_SHEET (transparent source sheet) and OUTPUT_ROOT
# (destination sprite folder) before sourcing this file, then call:
#
#   extract_frame "<relative/output.png>" "<WxH+X+Y crop>" [foot_band_height]
#
# Each pose is trimmed, then placed on an 80x80 transparent canvas so its
# lowest opaque rows (the feet/lower-leg band) are centered at x=40 and the
# floor contact sits at y=80.

extract_frame() {
  local relative_path="$1"
  local crop_rect="$2"
  local foot_band_height="${3:-8}"
  local destination="$OUTPUT_ROOT/$relative_path"
  local trimmed_pose
  trimmed_pose="$(mktemp -t frame).png"

  magick "$CLEAN_SHEET" \
    -crop "$crop_rect" +repage \
    -trim +repage \
    "$trimmed_pose"

  local pose_width
  local pose_height
  read -r pose_width pose_height < <(
    magick identify -format '%w %h\n' "$trimmed_pose"
  )

  # Use the lowest opaque rows as the feet/lower-leg band. Four rows can see
  # only one planted boot in wide stances; eight captures both feet while
  # staying below the torso. Align its midpoint to x=40.
  if (( pose_height < foot_band_height )); then
    foot_band_height=$pose_height
  fi
  local foot_band_y=$((pose_height - foot_band_height))
  local foot_width
  local foot_x
  # -trim takes its background from the corner pixels, so a boot filling a
  # corner of the band would be read as background. A one-pixel transparent
  # border makes every corner transparent; subtract it from the offset.
  read -r foot_width foot_x < <(
    magick "$trimmed_pose" \
      -alpha extract \
      -crop "${pose_width}x${foot_band_height}+0+${foot_band_y}" +repage \
      -bordercolor black -border 1 \
      -trim \
      -format '%w %X\n' \
      info:
  )
  foot_x=$((foot_x - 1))

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

# A cycle whose poses plant their feet on different rungs cannot use the foot
# band: the band follows the planted foot, so centering on it makes the body
# lurch sideways and the sprite hop off the floor pose by pose. Such a strip
# keeps the alignment its own artwork already has.
#
#   extract_anchored_frame "<relative/output.png>" "<WxH+X+Y crop>" <anchor_sheet_x>
#
# The crop is composited untrimmed: its bottom row becomes the floor contact at
# y=80 and anchor_sheet_x (a column that holds still across the strip, such as
# the head's centroid on a ladder) lands on the pivot at x=40.
extract_anchored_frame() {
  local relative_path="$1"
  local crop_rect="$2"
  local anchor_sheet_x="$3"
  local destination="$OUTPUT_ROOT/$relative_path"

  if [[ ! "$crop_rect" =~ ^([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+)$ ]]; then
    echo "extract_anchored_frame: bad crop rect '$crop_rect'" >&2
    return 1
  fi
  local crop_height="${BASH_REMATCH[2]}"
  local crop_x="${BASH_REMATCH[3]}"

  local destination_x=$((40 - (anchor_sheet_x - crop_x)))
  local destination_y=$((80 - crop_height))
  local destination_geometry
  printf -v destination_geometry '%+d%+d' "$destination_x" "$destination_y"

  magick -size 80x80 canvas:none \
    \( "$CLEAN_SHEET" -crop "$crop_rect" +repage \) \
    -geometry "$destination_geometry" -composite \
    -strip \
    "$destination"
}
