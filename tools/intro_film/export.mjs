import puppeteer from 'puppeteer-core'; import fs from 'fs';
const b=await puppeteer.launch({executablePath:process.env.CHROME_PATH || '/usr/bin/google-chrome',args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const p=await b.newPage(); p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto('http://127.0.0.1:8765/export.html'); await p.waitForFunction('window.DONE',{timeout:180000});
const r=await p.evaluate(()=>window.RESULT); fs.writeFileSync('out/tankachu_animated.glb',Buffer.from(r,'base64')); await b.close();
