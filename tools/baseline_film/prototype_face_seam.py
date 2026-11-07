"""Offline facial topology experiment. Never overwrites an app asset.

Split existing front-face triangles along the original mouth, keeping the
closed surface coincident, then deform the resulting upper/lower boundaries.
The interior is recessed behind the cut, rather than laid over the face.
"""
import copy
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/face-rig'
OUT.mkdir(parents=True, exist_ok=True)
raw = (ROOT / 'assets/models/tankachu_animated.glb').read_bytes()
size = struct.unpack_from('<I', raw, 12)[0]
m = json.loads(raw[20:20+size])
blob = bytearray(raw[28+size:])
p = m['meshes'][0]['primitives'][0]
original = copy.deepcopy(p)
types = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}
formats = {5126:'f', 5125:'I', 5123:'H', 5121:'B'}

def read(i):
    a=m['accessors'][i]; v=m['bufferViews'][a['bufferView']]
    width=types[a['type']]; fmt='<'+formats[a['componentType']]*width
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    stride=v.get('byteStride',struct.calcsize(fmt))
    return [list(struct.unpack_from(fmt,blob,start+j*stride)) for j in range(a['count'])]

def put(values, kind, component=5126):
    while len(blob)%4: blob.append(0)
    start=len(blob); width=types[kind]
    flat=[v for row in values for v in row]
    blob.extend(struct.pack('<'+formats[component]*len(flat),*flat))
    view=len(m['bufferViews'])
    m['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(blob)-start})
    a={'bufferView':view,'componentType':component,'count':len(values),'type':kind}
    if kind=='VEC3':
        a.update(min=[min(row[j] for row in values) for j in range(3)],
                 max=[max(row[j] for row in values) for j in range(3)])
    m['accessors'].append(a)
    return len(m['accessors'])-1

attrs={k:read(v) for k,v in p['attributes'].items()}
targets=[{k:read(v) for k,v in t.items()} for t in p['targets']]
positions=attrs['POSITION']
count=len(positions)
side=[None]*count
indices=[row[0] for row in read(p['indices'])]
head_joint=m['skins'][0]['joints'].index(2)

def line(x): return .494-.020*min(abs(x)/.045,1.4)
def signed(pos): return pos[1]-line(pos[0])
def mix(a,b,t): return [x+(y-x)*t for x,y in zip(a,b)]
def append_between(a,b,t,which):
    i=len(attrs['POSITION'])
    for key,values in attrs.items():
        if key=='JOINTS_0': values.append([head_joint,0,0,0])
        elif key=='WEIGHTS_0': values.append([1,0,0,0])
        else: values.append(mix(values[a],values[b],t))
    for target in targets:
        for values in target.values(): values.append(mix(values[a],values[b],t))
    side.append(which)
    return i

# Refine only the mouth patch. Midpoints lie on existing triangles, preserving
# the closed surface and UVs while giving curved lip shapes enough resolution.
source_indices=indices[:]
for _ in range(2):
    refined=[]; midpoint={}
    def mid(a,b):
        key=tuple(sorted((a,b)))
        if key not in midpoint:midpoint[key]=append_between(a,b,.5,None)
        return midpoint[key]
    for off in range(0,len(indices),3):
        a,b,c=indices[off:off+3]
        local=all(z>.285 and .415<y<.550 and abs(x)<.090
                  for x,y,z in (positions[a],positions[b],positions[c]))
        if local:
            mid(a,b);mid(b,c);mid(c,a)
    # Adjacent triangles share every introduced edge point. Leaving T-junctions
    # would create tiny bright cracks once the lower lip deforms.
    for off in range(0,len(indices),3):
        tri=indices[off:off+3]
        flags=[tuple(sorted((tri[k],tri[(k+1)%3]))) in midpoint for k in range(3)]
        marked=sum(flags)
        if not marked:refined.extend(tri);continue
        if marked==3:
            a,b,c=tri;ab,bc,ca=mid(a,b),mid(b,c),mid(c,a)
            refined.extend((a,ab,ca,ab,b,bc,ca,bc,c,ab,bc,ca));continue
        # Rotate until the first edge is marked; for two edges, the second is too.
        for k in range(3):
            if flags[k] and (marked==1 or flags[(k+1)%3]):break
        a,b,c=tri[k:]+tri[:k];ab=mid(a,b)
        if marked==1:refined.extend((a,ab,c,ab,b,c))
        else:
            bc=mid(b,c)
            refined.extend((b,bc,ab,a,ab,c,ab,bc,c))
    indices=refined

seam=[]; new_indices=[]; splits=0
for off in range(0,len(indices),3):
    tri=indices[off:off+3]; coords=[positions[i] for i in tri]
    # The back of the head and the nose are excluded.
    local=all(z>.285 and .445<y<.515 and abs(x)<.085 for x,y,z in coords)
    values=[signed(pos) for pos in coords]
    if not local or min(values)>=0 or max(values)<=0:
        new_indices.extend(tri); continue
    crossings=[]
    for k in range(3):
        a,b=tri[k],tri[(k+1)%3]; fa,fb=signed(positions[a]),signed(positions[b])
        if fa*fb<0:
            t=fa/(fa-fb); point=mix(positions[a],positions[b],t)
            crossings.append((a,b,t,point))
    if len(crossings)!=2 or any(abs(c[3][0])>.070 for c in crossings):
        new_indices.extend(tri);continue
    upper={};lower={}
    for a,b,t,point in crossings:
        u=append_between(a,b,t,1); l=append_between(a,b,t,-1)
        upper[frozenset((a,b))]=u;lower[frozenset((a,b))]=l
        seam.append((u,l))
    for sign,edge in ((1,upper),(-1,lower)):
        polygon=[]
        for k in range(3):
            a,b=tri[k],tri[(k+1)%3]
            if signed(positions[a])*sign>=0: polygon.append(a)
            key=frozenset((a,b))
            if key in edge:polygon.append(edge[key])
        for k in range(1,len(polygon)-1):new_indices.extend([polygon[0],polygon[k],polygon[k+1]])
    splits+=1

if splits<2:
    raise RuntimeError('Mouth seam was not found; candidate is not usable')

def delta(pos, which, name):
    x,y,z=pos
    if z<.275 or abs(x)>.075: return [0,0,0]
    f=signed(pos)
    lower=which==-1 or (which is None and f<0)
    # New seam vertices lie on an interpolated cut; use their boundary role
    # rather than re-evaluating the curved field and introducing uneven lips.
    distance=0 if which is not None else abs(f)
    vertical=max(0,1-distance/(.065 if lower else .024))**2
    depth=min(1,max(0,(z-.275)/.030))
    radius,upper,lower_drop,spread,pucker={
        'AA':(.041,.010,.018,1.0,0),
        'E':(.047,.006,.009,1.06,0),
        'O':(.038,.010,.017,.78,.004),
        'U':(.034,.008,.012,.70,.006),
    }[name]
    u=min(1,abs(x)/radius)
    # Round the former V-shaped cut into an oval as it opens. The correction
    # vanishes at the corners and at zero morph weight, keeping the resting face.
    profile=max(0,1-u*u)**.75
    center=.483-.008*u*u
    correction=(center-line(x))*max(0,1-u*u)
    lip_y=correction+(-lower_drop if lower else upper)*profile
    if which is not None:lip_y+=(line(x)-y)*profile
    broad=max(0,1-(abs(x)/.075)**4)**2
    return [x*(spread-1)*broad*vertical*depth,
            lip_y*vertical*depth,pucker*profile*vertical*depth]

names=['AA','E','O','U']
mouths=[[delta(pos,which,name) for pos,which in zip(positions,side)] for name in names]

def vertex_normals(coords):
    # Weld coincident UV vertices for shading, but keep upper/lower lips apart.
    keys=[(*[round(v,6) for v in pos],which or (1 if signed(pos)>=0 else -1))
          for pos,which in zip(positions,side)]
    sums={key:[0.,0.,0.] for key in keys}
    for off in range(0,len(new_indices),3):
        tri=new_indices[off:off+3];a,b,c=[coords[i] for i in tri]
        u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
        normal=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        for i in tri:
            for j in range(3):sums[keys[i]][j]+=normal[j]
    result=[]
    for key in keys:
        v=sums[key];length=math.sqrt(sum(x*x for x in v)) or 1
        result.append([x/length for x in v])
    return result

base_normals=vertex_normals(positions)
mouth_normals=[]
for moves in mouths:
    normals=vertex_normals([[v+d for v,d in zip(pos,move)] for pos,move in zip(positions,moves)])
    mouth_normals.append([[a-b for a,b in zip(n,base)] for n,base in zip(normals,base_normals)])
for key,values in attrs.items():
    a=m['accessors'][original['attributes'][key]]
    p['attributes'][key]=put(values,a['type'],a['componentType'])
p['indices']=put([[v] for v in new_indices],'SCALAR',5125)
p['targets']=[{k:put(values,'VEC3') for k,values in target.items()} for target in targets]
p['targets'] += [{'POSITION':put(values,'VEC3'),'NORMAL':put(normals,'VEC3')}
                 for values,normals in zip(mouths,mouth_normals)]

# A narrow, recessed cavity connected to the actual cut boundary. Its rim
# follows the same morph deltas; no surface geometry covers the original lips.
seam.sort(key=lambda pair:positions[pair[0]][0])
unique=[]
for pair in seam:
    if not unique or abs(positions[pair[0]][0]-positions[unique[-1][0]][0])>1e-6:unique.append(pair)
cavity=[]; cavity_moves=[[] for _ in names]; cavity_indices=[]
for u,l in unique:
    for front,back in ((u,False),(u,True),(l,False),(l,True)):
        x,y,z=positions[front]
        cavity.append([x,y,z-(.030 if back else .0007)])
        for j,name in enumerate(names):cavity_moves[j].append(delta(positions[front],side[front],name))
for k in range(len(unique)-1):
    a=k*4;b=(k+1)*4
    # Upper wall, lower wall and back surface.
    for x,y,z,w in ((a,b,b+1,a+1),(a+2,a+3,b+3,b+2),(a+1,b+1,b+3,a+3)):
        cavity_indices.extend([x,y,z,x,z,w])
# Recessed back wall seals the cavity even where the original lip topology
# contains coincident UV vertices. It never covers the front face.
back=len(cavity)
cavity.extend([[-.075,.435,.275],[.075,.435,.275],[.075,.515,.275],[-.075,.515,.275]])
for values in cavity_moves:values.extend([[0,0,0] for _ in range(4)])
cavity_indices.extend([back,back+1,back+2,back,back+2,back+3])
m['materials'].append({'name':'RecessedMouthInterior','doubleSided':True,
    'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':1}})
n=len(cavity);zeros=[[0,0,0] for _ in cavity]
# A subtly lighter rim falls into a darker recess. The original face remains
# the only visible outside surface; this gradient stays behind the real cut.
colors=[[.065,.019,.009,1] if i<back and i%2==0 else [.014,.004,.002,1]
        for i in range(n)]
inner={'attributes':{'POSITION':put(cavity,'VEC3'),
    'COLOR_0':put(colors,'VEC4'),
    'NORMAL':put([[0,0,1] for _ in cavity],'VEC3'),
    'JOINTS_0':put([[head_joint,0,0,0] for _ in cavity],'VEC4',5123),
    'WEIGHTS_0':put([[1,0,0,0] for _ in cavity],'VEC4')},
    'indices':put([[v] for v in cavity_indices],'SCALAR',5125),
    'material':len(m['materials'])-1,
    'targets':[{'POSITION':put(zeros,'VEC3')} for _ in range(2)]+
              [{'POSITION':put(values,'VEC3')} for values in cavity_moves]}
m['meshes'][0]['primitives'].append(inner)
m['meshes'][0]['extras']['targetNames']=['Blink','Happy']+names
m['meshes'][0]['weights']=[0]*6
mesh_node=next(i for i,node in enumerate(m['nodes']) if node.get('mesh')==0)
for animation in m['animations']:
    for channel in animation['channels']:
        if channel['target']['path']=='weights':
            sampler=animation['samplers'][channel['sampler']]
            values=[row[0] for row in read(sampler['output'])]
            expanded=[]
            for i in range(0,len(values),2):expanded += [[values[i]],[values[i+1]],[0],[0],[0],[0]]
            sampler['output']=put(expanded,'SCALAR')
for j,name in enumerate(['Closed']+names):
    weights=[0]*6
    if j:weights[j+1]=1
    inp=put([[0],[1]],'SCALAR');m['accessors'][inp].update(min=[0],max=[1])
    out=put([[v] for v in weights*2],'SCALAR')
    m['animations'].append({'name':'Face'+name,'samplers':[{'input':inp,'output':out,'interpolation':'LINEAR'}],
        'channels':[{'sampler':0,'target':{'node':mesh_node,'path':'weights'}}]})
# Visual motion review only: these hand-timed shapes are not audio lip sync.
sequence=[(0,None,0),(.18,'AA',.65),(.42,'E',.85),(.64,None,0),
          (.80,'O',.9),(1.04,'U',.8),(1.26,None,0),(1.48,'AA',1),
          (1.72,'E',.6),(1.94,None,0),(2.18,'U',.9),(2.42,'O',.8),
          (2.66,'AA',.7),(2.90,None,0),(3.40,None,0)]
def frame_weights(name,strength):
    weights=[0]*6
    if name: weights[2+names.index(name)]=strength
    return weights

# Ease into each shape with zero endpoint speed rather than snapping at keys.
frames=[]
for a,b in zip(sequence,sequence[1:]):
    for step in range(8):
        t=step/8;s=t*t*(3-2*t)
        frames.append((a[0]+(b[0]-a[0])*t,
            mix(frame_weights(a[1],a[2]),frame_weights(b[1],b[2]),s)))
frames.append((sequence[-1][0],frame_weights(None,0)))
demo=[[v] for _,weights in frames for v in weights]
inp=put([[time] for time,_ in frames],'SCALAR')
m['accessors'][inp].update(min=[0],max=[sequence[-1][0]])
m['animations'].append({'name':'FaceMotionReview',
    'samplers':[{'input':inp,'output':put(demo,'SCALAR'),'interpolation':'LINEAR'}],
    'channels':[{'sampler':0,'target':{'node':mesh_node,'path':'weights'}}]})

def surface_area(triangles):
    area=0
    for i in range(0,len(triangles),3):
        a,b,c=[positions[j] for j in triangles[i:i+3]]
        u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
        cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        area+=math.sqrt(sum(x*x for x in cross))*.5
    return area
area_error=abs(surface_area(source_indices)-surface_area(new_indices))
assert area_error<1e-8, 'Closed face surface changed'
assert all(math.isfinite(v) for row in positions for v in row)
m['buffers'][0]['byteLength']=len(blob)
encoded=json.dumps(m,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
blob+=b'\0'*(-len(blob)%4)
result=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))
result+=struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
(OUT/'oddo-mouth-seam.glb').write_bytes(result)
report={'original_vertices':count,'candidate_vertices':len(positions),'split_triangles':splits,
        'seam_points':len(unique),'closed_surface_area_error':area_error,
        'original_unchanged':True,'app_asset_replaced':False,'audio_sync':False,
        'mouth_subdivision_passes':2,'morph_normals':True,'eased_motion':True}
(OUT/'topology-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
