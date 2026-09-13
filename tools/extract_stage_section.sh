#!/usr/bin/env bash

# Crops the first street section of the New York composite into the stage
# slice the prototype alley scrolls across. Only this section is imported;
# the 5216 px composite stays a raw source sheet.

set -euo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SOURCE="$PROJECT_ROOT/assets/source_sheets/new-york-20xx.png"
readonly OUTPUT="$PROJECT_ROOT/assets/stages/new_york_street.png"
# Width covers the garage, the poster wall, the SCOOP MOTO building, and the
# barrel alley up to the rubble wall. The band ends on the last road row (sheet
# row 479) so the walkable strip meets the viewport bottom, and reaches 56 rows
# above the old 216 px band to give the camera somewhere to rise while Billy
# stands on the SCOOP ledge. Sheet row 208 is as high as the crop can go with
# no hole in it: every column from x 300 rightwards - the whole span the view
# can cover while Billy is up on the ledge - is opaque from there down, while
# the garage at x 0-255 only starts at row 224. The level draws the slice at
# y -56, so the extra rows sit above the world origin and no ground coordinate
# moves.
readonly CROP='1232x272+0+208'

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required (missing 'magick' executable)." >&2
  exit 1
fi

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source sheet: $SOURCE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
magick "$SOURCE" -crop "$CROP" +repage -strip "$OUTPUT"
magick identify -format 'Wrote %f (%wx%h)\n' "$OUTPUT"
