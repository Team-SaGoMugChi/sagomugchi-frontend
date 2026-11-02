// 공통 룩: 벨벳 재질 + 따뜻한 스튜디오 조명 + 바닥 그림자
import * as THREE from 'three';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
export function setupRenderer(W,H,{alpha=false}={}){
  const r=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true,alpha});
  r.setPixelRatio(1);r.setSize(W,H);r.outputColorSpace=THREE.SRGBColorSpace;
  r.toneMapping=THREE.ACESFilmicToneMapping;r.toneMappingExposure=1.05;
  r.shadowMap.enabled=true;r.shadowMap.type=THREE.VSMShadowMap;
  document.body.appendChild(r.domElement);return r;
}
export function velvet(mat){
  const m=new THREE.MeshPhysicalMaterial({map:mat.map,roughness:0.85,metalness:0,
    sheen:0.9,sheenRoughness:0.55,sheenColor:new THREE.Color('#e9b38a'),
    color:new THREE.Color('#d9c2b4')});
  m.map.colorSpace=THREE.SRGBColorSpace;m.map.anisotropy=8;return m;
}
export function studio(scene,r,{bg='#FBF7F1',ground=true}={}){
  scene.environment=new THREE.PMREMGenerator(r).fromScene(new RoomEnvironment(),0.04).texture;
  scene.environmentIntensity=0.55;
  if(bg) scene.background=new THREE.Color(bg);
  const key=new THREE.DirectionalLight('#fff3e6',2.4);key.position.set(1.6,3.2,2.6);
  key.castShadow=true;key.shadow.mapSize.set(2048,2048);key.shadow.radius=12;key.shadow.blurSamples=20;
  Object.assign(key.shadow.camera,{left:-2,right:2,top:2,bottom:-2,near:0.1,far:10});key.shadow.bias=-0.0004;
  scene.add(key);
  const rim=new THREE.DirectionalLight('#ffd9b0',1.6);rim.position.set(-2.2,1.6,-2.4);scene.add(rim);
  const fill=new THREE.DirectionalLight('#f4e8ff',0.5);fill.position.set(-2,0.6,2);scene.add(fill);
  if(ground){const gm=new THREE.ShadowMaterial({opacity:0.16});const g=new THREE.Mesh(new THREE.PlaneGeometry(20,20),gm);
    g.rotation.x=-Math.PI/2;g.receiveShadow=true;scene.add(g);}
  return {key,rim,fill};
}
