// 탄카츄 보강: 표정 데칼(미소·^^눈·눈 깜빡임)과 분리된 인사용 팔.
//
// - 표정: 원본 텍스처를 정면 직교 투영으로 굽고(얼굴 그대로의 색), 입/눈 부분만
//   다시 그린 이미지를 DecalGeometry로 얼굴에 덮는다. 머리 뼈에 붙여 함께 움직인다.
// - 팔: 원본 팔은 몸통과 한 면으로 붙어 있어 들면 살이 늘어난다. 인사할 때는 원본
//   왼팔을 몸 안으로 접어 넣고, 같은 털 질감의 캡슐 팔을 어깨에 붙여 올린다.
import * as THREE from 'three';
import {DecalGeometry} from 'three/addons/geometries/DecalGeometry.js';

const FACE = {x0: -0.25, x1: 0.25, y0: 0.42, y1: 0.80};
const PX = 2000; // 1 world unit 당 픽셀
const FW = Math.round((FACE.x1 - FACE.x0) * PX), FH = Math.round((FACE.y1 - FACE.y0) * PX);
const toPx = (x, y) => [(x - FACE.x0) * PX, (FACE.y1 - y) * PX];

/** 원본 텍스처를 정면에서 그대로 굽는다(조명 없이 텍스처 색). */
function bakeFront(renderer, mesh) {
  const scene = new THREE.Scene();
  const m = new THREE.Mesh(mesh.geometry, new THREE.MeshBasicMaterial({map: mesh.material.map}));
  scene.add(m);
  const cam = new THREE.OrthographicCamera(FACE.x0, FACE.x1, FACE.y1, FACE.y0, 0.01, 10);
  cam.position.set(0, 0, 3); cam.lookAt(0, 0, 0);
  // 위 lookAt이 y축을 바꾸지 않도록 정면 고정
  cam.position.set(0, 0, 3); cam.rotation.set(0, 0, 0);
  const rt = new THREE.WebGLRenderTarget(FW, FH, {colorSpace: THREE.SRGBColorSpace});
  const tm = renderer.toneMapping; renderer.toneMapping = THREE.NoToneMapping;
  renderer.setRenderTarget(rt); renderer.setClearColor(0x000000, 0); renderer.clear(); renderer.render(scene, cam);
  const buf = new Uint8Array(FW * FH * 4); renderer.readRenderTargetPixels(rt, 0, 0, FW, FH, buf);
  renderer.setRenderTarget(null); renderer.toneMapping = tm;
  const c = document.createElement('canvas'); c.width = FW; c.height = FH; const g = c.getContext('2d');
  const img = g.createImageData(FW, FH);
  for (let y = 0; y < FH; y++) img.data.set(buf.subarray((FH - 1 - y) * FW * 4, (FH - y) * FW * 4), y * FW * 4);
  g.putImageData(img, 0, 0);
  return c;
}

/** 털 패치를 복제해 원본 입/눈을 지운다(가장자리는 부드럽게). */
function eraseWithFur(g, base, cx, cy, rx, ry, srcDx, srcDy) {
  g.save();
  const grad = g.createRadialGradient(0, 0, 0, 0, 0, 1);
  g.beginPath(); g.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2); g.clip();
  g.drawImage(base, -srcDx, -srcDy);
  g.restore();
  // 경계 부드럽게: 바깥쪽 링을 반투명으로 한 번 더
  g.save(); g.globalAlpha = 0.5;
  g.beginPath(); g.ellipse(cx, cy, rx * 1.15, ry * 1.15, 0, 0, Math.PI * 2); g.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2, true); g.clip('evenodd');
  g.drawImage(base, -srcDx, -srcDy); g.restore();
  void grad;
}

const INK = '#2a1610';
function line(g, w) { g.strokeStyle = INK; g.lineWidth = w; g.lineCap = 'round'; g.lineJoin = 'round'; }

/** 편집한 부분 주변만 남기고 바깥은 부드럽게 투명 처리(데칼 사각형 경계가 보이지 않게). */
function feather(c, ellipses) {
  const m = document.createElement('canvas'); m.width = c.width; m.height = c.height;
  const mg = m.getContext('2d'); mg.filter = 'blur(14px)'; mg.fillStyle = '#000';
  for (const [x, y, rx, ry] of ellipses) { mg.beginPath(); mg.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); mg.fill(); }
  const g = c.getContext('2d'); g.globalCompositeOperation = 'destination-in'; g.drawImage(m, 0, 0); g.globalCompositeOperation = 'source-over';
}

/** 표정 이미지 3종(기본은 원본): smile, happy(^^), blink */
function makeExpressionCanvases(base) {
  const mk = () => { const c = document.createElement('canvas'); c.width = FW; c.height = FH; return c; };
  // 정면 굽기 이미지에서 잰 위치(월드): 코 아래 (0, 0.528), 입 중심 (0, 0.500), 눈 중심 (±0.12, 0.585)
  const [nx, ny] = toPx(0, 0.528);
  const [mx, my] = toPx(0, 0.501);
  // ── 미소 입(ω) ──
  const smile = mk(); { const g = smile.getContext('2d'); g.drawImage(base, 0, 0);
    eraseWithFur(g, base, mx, my, 92, 64, 180, 0);
    line(g, 10);
    g.beginPath(); g.moveTo(nx, ny - 4); g.lineTo(nx, ny + 16); g.stroke();
    g.beginPath(); g.moveTo(nx - 64, ny + 6); g.quadraticCurveTo(nx - 34, ny + 66, nx, ny + 16);
    g.quadraticCurveTo(nx + 34, ny + 66, nx + 64, ny + 6); g.stroke();
    feather(smile, [[mx, my + 6, 100, 74]]);
  }
  const eyeC = [toPx(-0.12, 0.585), toPx(0.12, 0.585)];
  const eyes = (kind) => { const c = mk(); const g = c.getContext('2d'); g.drawImage(base, 0, 0);
    for (const [ex, ey] of eyeC) {
      eraseWithFur(g, base, ex, ey, 104, 118, ex < FW / 2 ? 120 : -120, -230);
      line(g, 12); g.beginPath();
      if (kind === 'blink') { g.moveTo(ex - 50, ey + 4); g.quadraticCurveTo(ex, ey + 34, ex + 50, ey + 4); }
      else { g.moveTo(ex - 50, ey + 18); g.quadraticCurveTo(ex, ey - 34, ex + 50, ey + 18); }
      g.stroke();
    }
    feather(c, eyeC.map(([x, y]) => [x, y, 112, 126]));
    return c; };
  return {smile, blink: eyes('blink'), happy: eyes('happy')};
}

function decal(srcMesh, canvas, center, size, refMat, flatten = 0) {
  const geo = new DecalGeometry(srcMesh, new THREE.Vector3(...center), new THREE.Euler(0, 0, 0), new THREE.Vector3(...size));
  // DecalGeometry의 uv는 투영 상자 기준 0..1 → 얼굴 전체 캔버스 중 해당 상자 영역으로 다시 매핑
  const uv = geo.attributes.uv;
  const u0 = (center[0] - size[0] / 2 - FACE.x0) / (FACE.x1 - FACE.x0), u1 = (center[0] + size[0] / 2 - FACE.x0) / (FACE.x1 - FACE.x0);
  const v0 = (center[1] - size[1] / 2 - FACE.y0) / (FACE.y1 - FACE.y0), v1 = (center[1] + size[1] / 2 - FACE.y0) / (FACE.y1 - FACE.y0);
  for (let i = 0; i < uv.count; i++) uv.setXY(i, u0 + uv.getX(i) * (u1 - u0), v0 + uv.getY(i) * (v1 - v0));
  if (flatten > 0) { // 눈의 볼록한 모양이 비치지 않게 노멀을 정면 쪽으로 평탄화
    const n = geo.attributes.normal, f = new THREE.Vector3(0, 0.12, 1).normalize(), v = new THREE.Vector3();
    for (let i = 0; i < n.count; i++) { v.fromBufferAttribute(n, i).lerp(f, flatten).normalize(); n.setXYZ(i, v.x, v.y, v.z); }
  }
  const tex = new THREE.CanvasTexture(canvas); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 8;
  const mat = refMat.clone(); mat.map = tex; mat.transparent = true; mat.opacity = 0; mat.depthWrite = false;
  mat.polygonOffset = true; mat.polygonOffsetFactor = -4; mat.polygonOffsetUnits = -4;
  const m = new THREE.Mesh(geo, mat); m.renderOrder = 2;
  return m;
}

/**
 * 표정 데칼과 인사용 팔을 리그에 붙인다. 반환한 api.expr(), api.waveArm()으로 매 프레임 제어.
 * rig: loadRig() 결과, renderer: 굽기용 WebGLRenderer, mat: 몸에 쓰는 재질
 */
export function addExtras(rig, renderer, mat) {
  const src = new THREE.Mesh(rig.mesh.geometry, rig.mesh.material); src.updateMatrixWorld(true);
  const base = bakeFront(renderer, src);
  const cv = makeExpressionCanvases(base);
  const headRest = new THREE.Vector3(...[0, 0.30, 0.04]).add(new THREE.Vector3(0, 0.09, 0)); // body(0.09) + head 로컬
  void headRest;
  // 머리 뼈의 정지 자세 월드 행렬(뼈 위치 합으로 계산)
  rig.group.updateMatrixWorld(true);
  const headInv = rig.bones.head.matrixWorld.clone().invert();
  const make = (canvas, center, size, name, flatten = 0) => {
    const d = decal(src, canvas, center, size, mat, flatten); d.name = name;
    d.geometry.applyMatrix4(headInv); rig.bones.head.add(d); return d;
  };
  const dSmile = make(cv.smile, [0, 0.50, 0.3], [0.12, 0.09, 0.2], 'exprSmile', 0.3);
  const dBlink = make(cv.blink, [0, 0.585, 0.3], [0.40, 0.15, 0.2], 'exprBlink', 0.85);
  const dHappy = make(cv.happy, [0, 0.585, 0.3], [0.40, 0.15, 0.2], 'exprHappy', 0.85);

  // ── 인사용 팔 ──
  const furC = document.createElement('canvas'); furC.width = 256; furC.height = 256;
  const [fx, fy] = toPx(-0.05, 0.74); furC.getContext('2d').drawImage(base, fx, fy, 100, 100, 0, 0, 256, 256);
  const furTex = new THREE.CanvasTexture(furC); furTex.colorSpace = THREE.SRGBColorSpace; furTex.wrapS = furTex.wrapT = THREE.MirroredRepeatWrapping; furTex.repeat.set(3, 2);
  const armMat = mat.clone(); armMat.map = furTex;
  const R = 0.05, LEN = 0.2;
  const armGeo = new THREE.CapsuleGeometry(R, LEN, 10, 24); armGeo.translate(0, LEN / 2 + R * 0.35, 0);
  const shoulder = new THREE.Group(); shoulder.name = 'waveArmPivot';
  const arm = new THREE.Mesh(armGeo, armMat); arm.castShadow = true; arm.name = 'waveArm'; shoulder.add(arm);
  // 손바닥 젤리(큰 패드 + 발가락 3개)
  const padMat = new THREE.MeshPhysicalMaterial({color: '#5a3424', roughness: .7, sheen: .4, sheenColor: new THREE.Color('#8a5a44')});
  const tip = new THREE.Group(); tip.position.set(0, LEN + R * 0.35, 0); shoulder.add(tip);
  const pad = new THREE.Mesh(new THREE.SphereGeometry(0.026, 20, 14), padMat); pad.scale.set(1, 1, .35); pad.position.set(0, -0.012, R * 0.9); tip.add(pad);
  for (const [x, y] of [[-0.022, 0.024], [0, 0.034], [0.022, 0.024]]) {
    const t = new THREE.Mesh(new THREE.SphereGeometry(0.0105, 14, 10), padMat); t.scale.set(1, 1, .4); t.position.set(x, y, R * 0.78); tip.add(t);
  }
  // 몸통 뼈 기준 어깨 위치(정지 자세 월드 -0.19, 0.29, 0.03)
  const bodyInv = rig.bones.body.matrixWorld.clone().invert();
  shoulder.position.copy(new THREE.Vector3(-0.2, 0.28, 0.12).applyMatrix4(bodyInv));
  shoulder.visible = false; rig.bones.body.add(shoulder);

  const find = (root, name) => { let r; root.traverse(o => { if (o.name === name) r = o; }); return r; };
  return {
    canvases: {base, ...cv},
    /** smile/happy/blink: 0..1 */
    expr(root, {smile = 0, happy = 0, blink = 0} = {}) {
      find(root, 'exprSmile').material.opacity = smile;
      find(root, 'exprHappy').material.opacity = happy * (1 - blink);
      find(root, 'exprBlink').material.opacity = blink;
    },
    /** w: 0..1 팔 올림 정도, t: 시간(흔들기) */
    waveArm(root, bones, w, t) {
      const p = find(root, 'waveArmPivot');
      p.visible = w > 0.02;
      // 원본 왼팔은 몸 안으로 접어 넣는다
      bones.armL.scale.multiplyScalar(lerp(1, 0.04, w)); bones.armL.position.x += 0.05 * w;
      const s = Math.sin(t * 8.5);
      p.rotation.set(THREE.MathUtils.degToRad(14 * w), THREE.MathUtils.degToRad(10), THREE.MathUtils.degToRad(lerp(160, 27 + 8 * s, w)));
      p.scale.setScalar(Math.min(1, w * 1.6));
    },
  };
}
const lerp = (a, b, t) => a + (b - a) * t;
