#!/usr/bin/env python3
"""Serialize Abobo SpriteFrames, or surgically upsert Billy's victim animation."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])

def animation(name, ids, speed, loop=False, durations=None):
    durations = durations or [1.0] * len(ids)
    frames = ', '.join('{"duration": %s, "texture": ExtResource("%s")}' % pair
                       for pair in zip(durations, ids))
    return '{\n"frames": [' + frames + '],\n"loop": ' + str(loop).lower() + \
        ',\n"name": &"' + name + '",\n"speed": ' + str(float(speed)) + '\n}'

if len(sys.argv) > 2 and sys.argv[2] == 'billy':
    path = root / 'assets/sprites/billy/billy_sprite_frames.tres'
    text = path.read_text()
    # Preserve all unrelated resources, UIDs, animation timings and formatting.
    text = re.sub(r'^\[ext_resource[^\n]*id="being_thrown_\d+"\]\n', '', text, flags=re.M)
    text = re.sub(r',?\s*\{\s*"frames": \[(?:(?!\n\}).)*?"name": &"being_thrown"[^}]*\}',
                  '', text, flags=re.S)
    ids = [f'being_thrown_{i}' for i in range(3)]
    declarations = ''.join(f'[ext_resource type="Texture2D" path="res://assets/sprites/billy/being_thrown/being_thrown_{i:02}.png" id="{key}"]\n'
                           for i, key in enumerate(ids))
    text = text.replace('[resource]', declarations + '\n[resource]', 1)
    end = text.rfind(']')
    text = text[:end].rstrip() + ', ' + animation('being_thrown', ids, 10, durations=[1.2, 1.6, 2.4]) + text[end:]
    # Normalize only blank space before our declarations to make reruns stable.
    text = re.sub(r'\n{3,}(?=\[ext_resource type="Texture2D" path="res://assets/sprites/billy/being_thrown)', '\n\n', text)
    path.write_text(text)
else:
    base = root / 'assets/sprites/abobo'
    specs = [('idle', 4, True), ('walk', 8, True), ('walk_up', 8, True),
             ('punch', 10, False), ('hurt', 8, False), ('status1', 8, False),
             ('status2', 5, False), ('knockdown', 8, False), ('death', 1, False),
             ('throw', 10, False)]
    declarations, animations = [], []
    for name, speed, loop in specs:
        ids = []
        for i, path in enumerate(sorted((base / name).glob('*.png'))):
            key = f'{name}_{i}'
            ids.append(key)
            declarations.append(f'[ext_resource type="Texture2D" path="res://{path.relative_to(root)}" id="{key}"]')
        durations = [1.4, 1.2, 1.4, 1.8] if name == 'throw' else None
        animations.append(animation(name, ids, speed, loop, durations))
    (base / 'abobo_sprite_frames.tres').write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + '\n'.join(declarations) +
        '\n\n[resource]\nanimations = [' + ', '.join(animations) + ']\n')
