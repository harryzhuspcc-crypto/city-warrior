#!/usr/bin/env python3
"""Build Linda's runtime atlas, Godot SpriteFrames and labeled pose reference.

Requires Pillow: python3 -m pip install Pillow
Coordinates are native pixels in the unmodified arcade reference sheet.
"""

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/source_sheets/linda.png"
OUTPUT = ROOT / "assets/sprites/linda"
CELL = 80
MATTE = (74, 167, 168)
# (x, y, width, height, optional fixed source-x pivot). All poses face right.
# Whip poses use body pivots, NOT the whip tip in the lowest opaque rows.
IDLE = [(8, 349, 29, 61)]
WALK = [(77, 349, 29, 61), (114, 349, 23, 61),
        (145, 349, 24, 61), (177, 350, 29, 60)]
WALK_UP = [(246, 350, 27, 60), (281, 350, 26, 60),
           (315, 350, 24, 60), (347, 349, 27, 61)]
PUNCH = [(8, 115, 28, 60), (44, 114, 47, 61), (99, 114, 29, 61)]
WHIP = [(414, 349, 43, 61, 436), (465, 348, 39, 62, 487),
        (512, 351, 48, 59, 526), (568, 352, 29, 58, 582)]
HURT = [(8, 270, 25, 62), (73, 269, 21, 63)]
FALL = [(266, 288, 47, 44), (321, 300, 47, 32),
        (376, 305, 46, 27), (430, 288, 30, 44)]
ANIMATIONS = [
    ("idle", IDLE, 4, True),
    ("walk", WALK, 8, True),
    ("walk_up", WALK_UP, 8, True),
    ("punch", PUNCH, 10, False),
    ("whip", WHIP, 10, False),
    ("hurt", HURT, 8, False),
    ("status1", HURT, 8, False),
    ("status2", [FALL[3]], 5, False),
    ("knockdown", FALL, 8, False),
    ("death", FALL[:3], 8, False),
]


def build() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    assert source.size == (745, 418), "Unexpected Linda reference sheet"
    pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            if pixels[x, y][:3] == MATTE:
                pixels[x, y] = (*MATTE, 0)
    columns = max(len(poses) for _, poses, _, _ in ANIMATIONS)
    atlas = Image.new("RGBA", (columns * CELL, len(ANIMATIONS) * CELL))
    contact = Image.new("RGB", (columns * CELL, len(ANIMATIONS) * (CELL + 18)), "#303840")
    draw = ImageDraw.Draw(contact)
    resources, clips, metadata = [], [], {}
    for row, (name, poses, speed, loop) in enumerate(ANIMATIONS):
        frames, regions = [], []
        for index, spec in enumerate(poses):
            x, y, width, height = spec[:4]
            pose = source.crop((x, y, x + width, y + height))
            assert pose.getbbox() is not None
            if len(spec) == 5:
                pivot = spec[4] - x
            else:
                # Preserve the project's feet-pivot convention. The lower
                # eight rows see both boots instead of following one toe.
                band = pose.getchannel("A").crop((0, max(0, height - 8), width, height))
                bounds = band.getbbox()
                pivot = (bounds[0] + bounds[2]) // 2
            destination = (CELL // 2 - pivot, CELL - height)
            assert destination[0] >= 0 and destination[0] + width <= CELL, spec
            assert destination[1] >= 0, spec
            frame = Image.new("RGBA", (CELL, CELL))
            frame.paste(pose, destination)
            atlas.paste(frame, (index * CELL, row * CELL))
            contact.paste(frame, (index * CELL, row * (CELL + 18)), frame)
            draw.text((index * CELL + 3, row * (CELL + 18) + CELL + 2),
                      f"{name} {index}", fill="white")
            region = [index * CELL, row * CELL, CELL, CELL]
            key = f"{name}_{index}"
            resources.append(
                f'[sub_resource type="AtlasTexture" id="{key}"]\n'
                'atlas = ExtResource("atlas")\n'
                f'region = Rect2({", ".join(map(str, region))})\n'
            )
            frames.append('{"duration": 1.0, "texture": SubResource("' + key + '")}')
            regions.append({"region": region, "source_crop": list(spec[:4]),
                            "source_pivot_x": x + pivot})
        metadata[name] = {"fps": speed, "loop": loop, "frames": regions}
        clips.append('{\n"frames": [' + ', '.join(frames) + '],\n'
                     f'"loop": {str(loop).lower()},\n"name": &"{name}",\n"speed": {float(speed)}\n' + '}')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT / "linda_atlas.png")
    contact.save(OUTPUT / "contact_sheet.png")
    (OUTPUT / "linda_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n'
        '[ext_resource type="Texture2D" path="res://assets/sprites/linda/linda_atlas.png" id="atlas"]\n\n'
        + '\n'.join(resources) + '\n[resource]\nanimations = [' + ', '.join(clips) + ']\n'
    )
    (OUTPUT / "linda_atlas.json").write_text(json.dumps({
        "image": "linda_atlas.png", "cell_size": [CELL, CELL],
        "pivot": [CELL // 2, CELL], "facing": "right",
        "animations": metadata,
    }, indent=2) + '\n')
    print(f"Generated {sum(len(poses) for _, poses, _, _ in ANIMATIONS)} Linda poses: {OUTPUT}")


if __name__ == "__main__":
    build()
