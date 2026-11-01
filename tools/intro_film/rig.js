// 탄카츄 전용 리그: Tripo(Mixamo 인간형) 스켈레톤을 버리고 체형에 맞는 뼈대로 다시 스키닝한다.
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';

// 뼈 배치(월드 좌표, 모델 높이 1.0 기준). 캐릭터 정면 = +Z.
export const BONES = {
  root:   {p:[0,0,0],          parent:null},
  body:   {p:[0,0.09,0.0],     parent:'root'},
  head:   {p:[0,0.30,0.04],    parent:'body'},
  earL:   {p:[-0.24,0.86,-0.02],parent:'head'},
  earR:   {p:[0.24,0.86,-0.02], parent:'head'},
  armL:   {p:[-0.205,0.30,0.03],parent:'body'},
  pawL:   {p:[-0.275,0.215,0.05],parent:'armL'},
  armR:   {p:[0.205,0.30,0.03], parent:'body'},
  pawR:   {p:[0.275,0.215,0.05], parent:'armR'},
  legL:   {p:[-0.12,0.10,0.0],  parent:'root'},
  legR:   {p:[0.12,0.10,0.0],   parent:'root'},
};
export const BONE_NAMES = Object.keys(BONES);

function label(orig, v){
  const n = orig.replace('mixamorig','');
  const side = v.x < 0 ? 'L' : 'R';
  const isArm = /Arm|Hand/.test(n) && !/Shoulder/.test(n);
  if (isArm) return (v.y < 0.205 ? 'paw' : 'arm') + side;
  if (/Shoulder/.test(n)) {
    if (Math.abs(v.x) > 0.205 && v.y < 0.33 && v.y > 0.15) return (v.y < 0.205 ? 'paw':'arm') + side;
    return v.y > 0.305 ? 'head' : 'body';
  }
  if (/Foot|Toe|Leg$|LeftLeg|RightLeg/.test(n) && !/UpLeg/.test(n)) return 'leg' + side;
  if (/UpLeg/.test(n)) return v.y < 0.105 ? 'leg' + side : 'body';
  if (/Head|Neck/.test(n)) {
    if (v.y > 0.80 && Math.abs(v.x) > 0.15) return 'ear' + side;
    return 'head';
  }
  return v.y > 0.305 ? 'head' : 'body';
}

export async function loadRig(url = 'oddo_rigged.glb', {smooth = 7} = {}) {
  const g = await new GLTFLoader().loadAsync(url);
  g.scene.updateMatrixWorld(true);
  let src; g.scene.traverse(o => { if (o.isSkinnedMesh) src = o; });
  const sk = src.skeleton, geo0 = src.geometry;
  const pos0 = geo0.attributes.position, si = geo0.attributes.skinIndex, sw = geo0.attributes.skinWeight;
  const N = pos0.count, v = new THREE.Vector3();
  const rest = new Float32Array(N * 3), labels = new Array(N);
  for (let i = 0; i < N; i++) {
    src.getVertexPosition(i, v); v.applyMatrix4(src.matrixWorld);
    rest.set([v.x, v.y, v.z], i * 3);
    let best = 0, bw = -1;
    for (let k = 0; k < 4; k++) { const w = sw.getComponent(i, k); if (w > bw) { bw = w; best = si.getComponent(i, k); } }
    labels[i] = label(sk.bones[best].name, v);
  }
  // 위치 기준으로 정점 용접(UV 이음새로 갈라진 정점끼리 이웃으로 묶기)
  const key = i => rest.slice(i*3, i*3+3).map(x => Math.round(x*2e4)).join(',');
  const weld = new Map(), wid = new Int32Array(N);
  for (let i = 0; i < N; i++) { const k = key(i); if (!weld.has(k)) weld.set(k, weld.size); wid[i] = weld.get(k); }
  const M = weld.size, adj = Array.from({length: M}, () => new Set());
  const idx = geo0.index.array;
  for (let t = 0; t < idx.length; t += 3) {
    const a = wid[idx[t]], b = wid[idx[t+1]], c = wid[idx[t+2]];
    adj[a].add(b).add(c); adj[b].add(a).add(c); adj[c].add(a).add(b);
  }
  const B = BONE_NAMES.length, bi = Object.fromEntries(BONE_NAMES.map((n, i) => [n, i]));
  let W = new Float32Array(M * B);
  for (let i = 0; i < N; i++) W[wid[i] * B + bi[labels[i]]] = 1;
  // 경계에서만 부드럽게 섞이도록 이웃 평균(라플라시안) 반복. 머리-몸 경계는 덜 섞는다.
  for (let it = 0; it < smooth; it++) {
    const nw = new Float32Array(M * B);
    for (let m = 0; m < M; m++) {
      const nb = adj[m]; const self = 1.0;
      for (let b = 0; b < B; b++) nw[m*B+b] = W[m*B+b] * self;
      for (const n of nb) for (let b = 0; b < B; b++) nw[m*B+b] += W[n*B+b];
      let s = 0; for (let b = 0; b < B; b++) s += nw[m*B+b];
      for (let b = 0; b < B; b++) nw[m*B+b] /= s;
    }
    W = nw;
  }
  // 정점별 상위 4개 가중치
  const skinIndex = new Uint16Array(N * 4), skinWeight = new Float32Array(N * 4);
  for (let i = 0; i < N; i++) {
    const m = wid[i];
    const arr = BONE_NAMES.map((_, b) => [b, W[m*B+b]]).sort((x, y) => y[1] - x[1]).slice(0, 4);
    const s = arr.reduce((a, x) => a + x[1], 0) || 1;
    arr.forEach(([b, w], k) => { skinIndex[i*4+k] = b; skinWeight[i*4+k] = w / s; });
  }
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(rest, 3));
  geo.setAttribute('uv', geo0.attributes.uv.clone());
  geo.setAttribute('normal', geo0.attributes.normal.clone());
  geo.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(skinIndex, 4));
  geo.setAttribute('skinWeight', new THREE.Float32BufferAttribute(skinWeight, 4));
  geo.setIndex(geo0.index.clone());
  // 뼈대 생성(부모 기준 로컬 위치)
  const bones = {};
  for (const n of BONE_NAMES) {
    const b = new THREE.Bone(); b.name = n; bones[n] = b;
    const P = BONES[n].parent;
    const p = new THREE.Vector3(...BONES[n].p);
    if (P) { p.sub(new THREE.Vector3(...BONES[P].p)); bones[P].add(b); }
    b.position.copy(p);
  }
  const mat = src.material.clone();
  const mesh = new THREE.SkinnedMesh(geo, mat); mesh.name = 'Tankachu';
  mesh.add(bones.root);
  mesh.bind(new THREE.Skeleton(BONE_NAMES.map(n => bones[n])));
  mesh.castShadow = true; mesh.frustumCulled = false;
  const group = new THREE.Group(); group.name = 'TankachuRig'; group.add(mesh);
  return {group, mesh, bones, labels, material: mat};
}

export const LABEL_COLORS = {body:'#888', head:'#e9b', earL:'#f60', earR:'#f60', armL:'#0a0', pawL:'#06f', armR:'#0a0', pawR:'#06f', legL:'#a0f', legR:'#a0f', root:'#000'};
