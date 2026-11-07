"""Append restrained call motion to the existing model without changing its mesh."""
import argparse
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--face', action='store_true', help='Use the reviewed face mesh; JS owns facial weights')
args = parser.parse_args()
source_path = 'output/face-rig/oddo-mouth-seam.glb' if args.face else 'assets/models/tankachu_animated.glb'
source = (ROOT / source_path).read_bytes()
length = struct.unpack_from('<I', source, 12)[0]
model = json.loads(source[20:20 + length])
binary_length = struct.unpack_from('<I', source, 20 + length)[0]
binary = bytearray(source[28 + length:28 + length + binary_length])
nodes = {n.get('name'): i for i, n in enumerate(model['nodes'])}

def accessor(values, kind, bounds=False):
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    binary.extend(struct.pack('<' + 'f' * len(values), *values))
    view = len(model['bufferViews'])
    model['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(values) * 4})
    width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[kind]
    entry = {'bufferView': view, 'componentType': 5126, 'count': len(values)//width, 'type': kind}
    if bounds:
        entry.update(min=[min(values)], max=[max(values)])
    model['accessors'].append(entry)
    return len(model['accessors']) - 1

def quaternion(x, y, z):
    x, y, z = [math.radians(v)/2 for v in (x,y,z)]
    a,b,c,d,e,f = math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
    return [a*d*f+b*c*e, b*c*f-a*d*e, b*d*e+a*c*f, b*d*f-a*c*e]

for name, duration in [('CallListen', 17), ('CallSpeak', 11), ('CallWait', 13), ('CallAck', 1.6)]:
    times = [i/30 for i in range(round(duration*30)+1)]
    inp = accessor(times, 'SCALAR', True)
    animation = {'name': name, 'samplers': [], 'channels': []}
    def track(node, path, values, kind):
        sampler = len(animation['samplers'])
        animation['samplers'].append({'input': inp, 'output': accessor(values, kind), 'interpolation': 'LINEAR'})
        animation['channels'].append({'sampler': sampler, 'target': {'node': nodes[node], 'path': path}})
    head, body, ears_l, ears_r, face = [],[],[],[],[]
    for t in times:
        phase = 2*math.pi*t/duration
        # All waves close at loop boundaries. Ack returns to a neutral pose.
        if name == 'CallAck':
            pitch = 6 * math.sin(math.pi*t/duration)**2
            yaw = roll = breath = 0
        else:
            strength = .55 if name == 'CallSpeak' else .45
            pitch = strength*(1.2*math.sin(phase)+.6*math.sin(3*phase))
            yaw = strength*1.5*math.sin(phase)
            roll = strength*1.3*math.sin(2*phase)
            breath = .0035*math.sin(3*phase)
        head.extend(quaternion(pitch,yaw,roll))
        body.extend([1-breath/2,1+breath,1-breath/2])
        ears_l.extend(quaternion(0,0,.9*math.sin(2*phase)))
        ears_r.extend(quaternion(0,0,-.7*math.sin(2*phase)))
        blink = max([max(0,1-abs(t-at)/.13) for at in (2.7,7.2,11.9,15.3)] if name != 'CallAck' else [0])
        face.extend([blink,0])
    track('head','rotation',head,'VEC4')
    track('body','scale',body,'VEC3')
    track('earL','rotation',ears_l,'VEC4')
    track('earR','rotation',ears_r,'VEC4')
    if not args.face:
        track('Tankachu','weights',face,'SCALAR')
    model['animations'].append(animation)

model['buffers'][0]['byteLength'] = len(binary)
encoded = json.dumps(model,separators=(',',':')).encode()
encoded += b' ' * (-len(encoded)%4)
binary += b'\0' * (-len(binary)%4)
out = struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))
out += struct.pack('<II',len(encoded),0x4e4f534a)+encoded
out += struct.pack('<II',len(binary),0x004e4942)+binary
destination = 'oddo_call_face.glb' if args.face else 'oddo_call.glb'
(ROOT/'assets/models'/destination).write_bytes(out)
print('Call motion built: '+destination)
