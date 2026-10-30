#!/usr/bin/env python3
"""Compose a flat, playable industrial yard from the supplied map artwork.

Requires Pillow. This is a new prototype layout, not the original arcade
stage's multi-height platform/river topology.
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
WIDTH, HEIGHT = 1536, 272


def build() -> None:
    source = Image.open(ROOT / "assets/source_sheets/new-york-20xx.png").convert("RGBA")
    # Exact native-pixel panels, above the new continuous walking apron.
    panels = [
        (1280, 192, 1552, 400),  # striped loading gate / chain-link fence
        (1568, 96, 1792, 304),   # industrial machinery and pipes
        (1792, 16, 2240, 224),  # warehouse door and loading boxes
        (1568, 96, 1792, 304),
        (1280, 192, 1552, 400),
        (1568, 96, 1792, 304),
    ]
    result = Image.new("RGBA", (WIDTH, HEIGHT), "#393b39")
    x = 0
    for box in panels:
        panel = source.crop(box)
        result.alpha_composite(panel, (x, 0))
        x += panel.width
        if x >= WIDTH:
            break

    # Tile only the clear concrete apron, never a hole or platform face.
    floor = source.crop((1088, 416, 1152, 480))
    for x in range(0, WIDTH, floor.width):
        result.alpha_composite(floor, (x, 208))
    draw = ImageDraw.Draw(result)
    draw.rectangle((0, 204, WIDTH - 1, 207), fill="#242929")
    draw.line((0, 208, WIDTH - 1, 208), fill="#888977")
    # A narrow hazard curb keeps the wall/floor join readable. Every mark is
    # decorative: the actual movement band is y=152..216 in world space.
    for x in range(0, WIDTH, 32):
        draw.polygon([(x, 205), (x + 11, 205), (x + 7, 207), (x, 207)], fill="#bbad50")
    for x in (176, 528, 944, 1328):
        draw.rectangle((x, 258, x + 22, 260), fill="#8b8c77")
    destination = ROOT / "assets/stages/industrial_yard.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    result.convert("RGB").save(destination)
    print(f"Wrote {destination} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    build()
