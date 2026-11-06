#!/usr/bin/env python3
"""Package the unchanged final-stage picture and existing Willy sprite artwork.

uv run --with pillow python tools/build_stage_four_assets.py
"""

import json
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def build() -> None:
    layout = json.loads((ROOT / "assets/stages/headquarters_layout.json").read_text())
    picture = Image.open(ROOT / "assets/source_sheets/final-mission.png").convert("RGBA")
    assert picture.size == (layout["width"], layout["height"])
    picture.save(ROOT / "assets/stages/headquarters.png")
    # Just one native square from the bottom row of each carved panel. These
    # standalone textures can also map onto the cuboid's top and side faces.
    for index in range(3):
        x = 272 + index * 112
        stone = picture.crop((x, 256, x + 24, 280))
        stone.save(ROOT / f"assets/stages/headquarters_wall_block_{index + 1}.png")
    (ROOT / "assets/stages/headquarters_layout.tres").write_text(
        '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/layout = '
        + json.dumps(layout, indent=2) + '\n'
    )
    source = ROOT / "assets/source_sheets/willy.png"
    if not source.exists():
        shutil.copyfile(ROOT / "dd_assets/double-dragon/willy.png", source)
    sheet = Image.open(source).convert("RGBA")
    background = sheet.getpixel((0, 0))
    # All crops exclude sheet labels and neighbouring poses. Each pose is
    # bottom-aligned to the shared fighters' 96x80 presentation canvas.
    poses = {
        "idle": [(7, 149, 47, 214)],
        "walk": [(7, 149, 47, 214), (50, 149, 93, 214), (96, 149, 132, 214), (135, 149, 173, 214)],
        "walk_up": [(207, 149, 260, 214), (263, 149, 315, 214), (319, 149, 367, 214), (371, 149, 417, 214)],
        "shoot": [(7, 357, 49, 423), (137, 357, 191, 423), (196, 357, 251, 423), (258, 357, 312, 423)],
        "punch": [(169, 246, 216, 330), (67, 267, 132, 330), (7, 149, 47, 214)],
        "hurt": [(8, 453, 57, 518), (59, 453, 104, 518)],
        "knockdown": [(134, 467, 175, 518), (176, 467, 215, 518), (508, 477, 568, 518), (7, 149, 47, 214)],
        "death": [(134, 467, 175, 518), (176, 467, 215, 518), (508, 477, 568, 518)],
    }
    output = ROOT / "assets/sprites/willy"
    output.mkdir(parents=True, exist_ok=True)
    resources, animations = [], []
    for name, crops in poses.items():
        frames = []
        for index, bounds in enumerate(crops):
            pose = sheet.crop(bounds)
            pose.putdata([(0, 0, 0, 0) if pixel == background else pixel for pixel in pose.get_flattened_data()])
            pose = pose.crop(pose.getbbox())
            assert pose.width <= 96 and pose.height <= 80, (name, index, pose.size)
            boots = pose.getchannel("A").crop((0, max(0, pose.height - 8), pose.width, pose.height)).getbbox()
            pivot = (boots[0] + boots[2]) // 2
            canvas = Image.new("RGBA", (96, 80))
            destination = (48 - pivot, 80 - pose.height)
            assert destination[0] >= 0 and destination[0] + pose.width <= 96
            canvas.alpha_composite(pose, destination)
            filename = f"{name}_{index:02}.png"
            canvas.save(output / filename)
            identifier = f"{name}_{index}"
            resources.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/willy/{filename}" id="{identifier}"]')
            frames.append('{"duration": 1.0, "texture": ExtResource("' + identifier + '")}')
        animations.append('{"frames": [' + ', '.join(frames) + '], "loop": '
                          + ('true' if name in ("idle", "walk", "walk_up") else 'false')
                          + f', "name": &"{name}", "speed": 8.0' + '}')
    (output / "willy_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + '\n'.join(resources)
        + '\n\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n'
    )
    print("Built unchanged Stage 4 picture, traced terrain, and Willy's original sprites")


if __name__ == "__main__":
    build()
