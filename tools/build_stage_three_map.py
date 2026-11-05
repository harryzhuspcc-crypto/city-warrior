#!/usr/bin/env python3
"""Extract Stage 3 unchanged and package its separate collision manifest.

Run with: uv run --with pillow python tools/build_stage_three_map.py
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def build() -> None:
    layout = json.loads((ROOT / "assets/stages/woods_layout.json").read_text())
    source = Image.open(ROOT / "assets/source_sheets/new-york-20xx.png").convert("RGBA")
    x, y, width, height = layout["source_crop"]
    assert x >= 0 and y >= 0 and x + width <= source.width and y + height <= source.height
    picture = source.crop((x, y, x + width, y + height))
    assert picture.size == (layout["width"], layout["height"])
    output = ROOT / "assets/stages/woods.png"
    picture.save(output)
    assert Image.open(output).convert("RGBA").tobytes() == picture.tobytes()
    (ROOT / "assets/stages/woods_layout.tres").write_text(
        '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/layout = '
        + json.dumps(layout, indent=2) + '\n'
    )
    print(f"Extracted unchanged Stage 3: {output} ({width}x{height})")


if __name__ == "__main__":
    build()
