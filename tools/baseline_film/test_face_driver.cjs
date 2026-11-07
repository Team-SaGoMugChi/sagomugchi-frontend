// Deterministic bridge test: no browser, microphone, audio or user data.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync('lib/widgets/call_face_driver.dart', 'utf8').split("r'''")[1].split("''';")[0];
let now = 0, next = 0;
const frames = new Map();
const context = {window: {}, performance: {now: () => now},
  requestAnimationFrame: fn => {frames.set(++next, fn); return next;},
  cancelAnimationFrame: id => frames.delete(id)};
vm.createContext(context); vm.runInContext(source, context);
const dict = {Blink: 0, Happy: 1, AA: 2, E: 3, O: 4, U: 5};
const meshes = [0,1].map(() => ({morphTargetDictionary: dict, morphTargetInfluences: [0,0,0,0,0,0]}));
let renders = 0;
const scene = {traverse: fn => meshes.forEach(fn), queueRender: () => renders++};
const model = {[Symbol('scene')]: scene};
const reports = [];
context.window.installOddoFace(model, text => reports.push(text));
const driver = context.window.oddoFace;
assert.equal(reports.at(-1), 'face-ready');
const tick = delta => {now += delta; const pending=[...frames.values()];frames.clear();pending.forEach(fn => fn(now));};
driver.speech({serial: 1, rate: 1, beat: 0, track: {total: 1, step: .5, samples: [[.9,0,0,0],[0,0,.9,0],[0,0,0,0]]}});
driver.setActive(true);
tick(40);tick(40);
assert(meshes[0].morphTargetInfluences[2] > .5, 'actual AA mesh opens');
assert.deepEqual(meshes[0].morphTargetInfluences, meshes[1].morphTargetInfluences, 'interior follows face');
driver.speech({serial: 1, rate: 1, beat: .5});tick(40);tick(40);tick(40);
assert(meshes[0].morphTargetInfluences[4] > .4, 'word progress changes shape');
for(let i=0;i<30;i++) tick(40);
assert(meshes[0].morphTargetInfluences.slice(2).every(v => v < .001), 'does not loop past sentence end');
driver.speech(null);
assert(meshes[0].morphTargetInfluences.slice(2).every(v => v === 0), 'stop closes immediately');
driver.setActive(false);assert.equal(frames.size, 0);
driver.setActive(true);driver.dispose();assert.equal(frames.size, 0);
assert(renders > 0);
context.window.installOddoFace({}, text => reports.push(text));
assert.equal(reports.at(-1), 'face-unavailable', 'changed viewer fails safely');
console.log('Face bridge: shape changes, interior, progress, end, stop, lifecycle and adapter fallback passed');
