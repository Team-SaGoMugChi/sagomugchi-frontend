/// Adapter for the model-viewer JS bundled with model_viewer_plus 1.10.0.
/// The package lacks a public morph-weight API. Guard the scene adapter and
/// report failure, leaving the original closed mouth if its internals change.
const callFaceDriver = r'''
window.installOddoFace = function(model, report) {
  window.oddoFace?.dispose();
  const symbol = Object.getOwnPropertySymbols(model).find(s => s.description === 'scene');
  const scene = symbol && model[symbol];
  const meshes = [];
  if (scene?.traverse) scene.traverse(mesh => {
    const dict = mesh.morphTargetDictionary;
    if (dict && ['AA','E','O','U'].every(k => Number.isInteger(dict[k]))) meshes.push(mesh);
  });
  if (!meshes.length || typeof scene.queueRender !== 'function') {
    report('face-unavailable'); return;
  }
  let active = false, disposed = false, frame = 0, last = 0, track = null;
  let serial = null, base = 0, clock = 0, rate = 5.2;
  let current = [0,0,0,0];
  const names = ['AA','E','O','U'];
  function apply(blink) {
    for (const mesh of meshes) {
      const dict = mesh.morphTargetDictionary, values = mesh.morphTargetInfluences;
      names.forEach((name,i) => values[dict[name]] = current[i]);
      if (Number.isInteger(dict.Blink)) values[dict.Blink] = blink;
      if (Number.isInteger(dict.Happy)) values[dict.Happy] = 0;
    }
    scene.queueRender();
  }
  function tick(now) {
    if (!active || disposed) return;
    frame = requestAnimationFrame(tick);
    if (last && now-last < 30) return;
    const dt = last ? Math.min((now-last)/1000, .05) : .033;
    last = now;
    const beat = base+(now-clock)*rate/1000;
    let target = [0,0,0,0];
    if (track && beat >= 0 && beat < track.total) {
      const position = beat/track.step, index = Math.floor(position);
      const a=track.samples[index], b=track.samples[index+1] || a;
      if (a) target=a.map((v,i) => v+(b[i]-v)*(position-index));
    }
    const alpha=1-Math.exp(-dt*32);
    current=current.map((v,i) => v+(target[i]-v)*alpha);
    const phase=(now/1000)%4.7;
    const blink=Math.max(0,1-Math.abs(phase-3.2)/.12);
    apply(blink);
  }
  window.oddoFace = {
    ready: true,
    speech(packet) {
      if (packet === null) {track=null;serial=null;current=[0,0,0,0];apply(0);return;}
      const fresh=serial!==packet.serial || Boolean(packet.track);
      if (packet.track) track=packet.track;
      if (fresh) {current=[0,0,0,0];base=0;clock=performance.now();}
      serial=packet.serial;
      rate=packet.rate;
      if (packet.beat !== null) {base=packet.beat;clock=performance.now();}
    },
    setActive(value) {
      if (active === value || disposed) return;
      active=value;last=0;
      if (active) frame=requestAnimationFrame(tick);
      else {cancelAnimationFrame(frame);current=[0,0,0,0];apply(0);}
    },
    dispose() {
      disposed=true;active=false;cancelAnimationFrame(frame);
      current=[0,0,0,0];apply(0);
    }
  };
  report('face-ready');
};
''';
