"""Inspect a downloaded GLB without assuming a rig preset includes facial controls."""
import argparse
import json
from pathlib import Path
import re
import struct

parser = argparse.ArgumentParser()
parser.add_argument('model', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
raw = args.model.read_bytes()
if raw[:4] != b'glTF':
    raise ValueError('Expected binary GLB')
size = struct.unpack_from('<I', raw, 12)[0]
model = json.loads(raw[20:20 + size])
nodes = model.get('nodes', [])
joint_ids = {i for skin in model.get('skins', []) for i in skin['joints']}
joint_names = [nodes[i].get('name', '') for i in sorted(joint_ids)]
morphs = [name for mesh in model.get('meshes', [])
          for name in mesh.get('extras', {}).get('targetNames', [])]
animations = []
for animation in model.get('animations', []):
    targets = []
    for channel in animation['channels']:
        target = channel['target']
        targets.append({'node': nodes[target['node']].get('name', ''),
                        'path': target['path']})
    animations.append({'name': animation.get('name'), 'targets': targets})
result = {
    'file': args.model.name,
    'joint_count': len(joint_ids),
    'joint_names': joint_names,
    'facial_joint_candidates': [n for n in joint_names if re.search(r'jaw|lip|mouth|tongue|eye', n, re.I)],
    'morph_names': morphs,
    'morph_target_count': [len(p.get('targets', [])) for mesh in model.get('meshes', []) for p in mesh['primitives']],
    'animations': animations,
    'extensions': model.get('extensionsUsed', []),
    'note': 'Presence of a joint name or a VRM preset alone does not verify working lip sync.',
}
if args.output:
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k not in ('joint_names', 'animations')}, ensure_ascii=False))
