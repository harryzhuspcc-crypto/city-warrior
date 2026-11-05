#!/usr/bin/env python3
"""Extract the ORIGINAL industrial picture, without repainting any pixels.

Requires Pillow. Collision tracing is separate metadata; it is never drawn
into the picture. No tiled panels, copied floor, new pits or conveyor overlay.
"""

import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def build() -> None:
    layout = json.loads((ROOT / "assets/stages/industrial_layout.json").read_text())
    source = Image.open(ROOT / "assets/source_sheets/new-york-20xx.png").convert("RGBA")
    x, y, width, height = layout["source_crop"]
    picture = source.crop((x, y, x + width, y + height))
    assert picture.size == (layout["width"], layout["height"])
    output = ROOT / "assets/stages/industrial_yard.png"
    picture.save(output)
    # Keep original RGBA, including the source's transparent unused regions.
    assert Image.open(output).convert("RGBA").tobytes() == picture.tobytes()
    (ROOT / "assets/stages/industrial_layout.tres").write_text(
        '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/layout = '
        + json.dumps(layout, indent=2) + '\n'
    )
    print(f"Extracted unchanged industrial picture: {output} ({width}x{height})")


if __name__ == "__main__":
    build()
