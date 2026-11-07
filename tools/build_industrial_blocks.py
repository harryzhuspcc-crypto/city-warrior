#!/usr/bin/env python3
"""Seed an editable terrain scene from the original industrial layout.

Once the scene exists, edit its polygons in Godot. Importing the artwork does
not regenerate them.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def manifest_text(layout):
    """Keep polygon coordinates on one line so outlines are easy to review."""
    rows = []
    for key, value in layout.items():
        if key in ('surfaces', 'blockers'):
            entries = ',\n'.join('    ' + json.dumps(item) for item in value)
            rows.append('  ' + json.dumps(key) + ': [\n' + entries + '\n  ]')
        else:
            rows.append('  ' + json.dumps(key) + ': ' + json.dumps(value))
    return '{\n' + ',\n'.join(rows) + '\n}'


def initial_scene(layout):
    lines = [
        '[gd_scene load_steps=4 format=3]',
        '[ext_resource type="Texture2D" path="res://assets/stages/industrial_yard.png" id="art"]',
        '[ext_resource type="Script" path="res://levels/industrial_yard/industrial_terrain_outline.gd" id="outline"]',
        '[ext_resource type="Script" path="res://levels/platform_simple_test/editable_platform.gd" id="platform"]',
        '[node name="PlatformBlocks" type="Node2D"]',
        '[node name="Background" type="Sprite2D" parent="."]\n'
        'texture_filter = 1\n'
        f'position = Vector2(0, {layout["image_offset_y"]})\n'
        'texture = ExtResource("art")\ncentered = false\nmetadata/_edit_lock_ = true',
        '[node name="CollisionOutlines" type="Node2D" parent="."]\n'
        f'position = Vector2(0, {layout["image_offset_y"]})',
    ]
    for group in ("surfaces", "blockers"):
        parent = group.capitalize()
        lines.append(f'[node name="{parent}" type="Node2D" parent="CollisionOutlines"]')
        for entry in layout[group]:
            points = ", ".join(str(value) for point in entry["polygon"] for value in point)
            properties = [
                f'[node name="{entry["name"]}" type="Polygon2D" parent="CollisionOutlines/{parent}"]',
                'color = Color(0, 0, 0, 0)',
                f'polygon = PackedVector2Array({points})',
                'script = ExtResource("outline")',
            ]
            if group == "surfaces":
                properties[-1] = 'script = ExtResource("platform")'
                properties += [f'height = {float(entry["height"])}',
                    f'solid = {json.dumps(entry.get("solid", False))}',
                    f'fall_from_edges = {json.dumps(entry.get("drop_edges", False))}',
                    f'rear_wall = {json.dumps(entry.get("rear_wall", False))}',
                    'rear_wall_on_level_only = true', 'draw_side_faces = false']
                fields = ("landing_depth_assist", "belt_speed")
            else:
                properties.append('outline_color = Color(1, 0.65, 0.23, 1)')
                fields = ("height", "world_boundary", "solid_wall", "max_base_height")
            for field in fields:
                if field in entry and entry[field] != 0:
                    value = entry[field]
                    literal = json.dumps(value) if isinstance(value, bool) else str(float(value))
                    properties.append(f"{field} = {literal}")
            lines.append("\n".join(properties))
    return "\n\n".join(lines) + "\n"


def build():
    output = ROOT / "levels/industrial_yard/industrial_blocks.tscn"
    if output.exists():
        print(f"Keeping existing editor-authored outlines: {output}")
        return
    layout = json.loads((ROOT / "assets/stages/industrial_layout.json").read_text())
    output.write_text(initial_scene(layout))
    print(output)


if __name__ == "__main__":
    build()
