import puppeteer from 'puppeteer-core';
import fs from 'fs';
const FPS=30, dir='out/frames'; fs.mkdirSync(dir,{recursive:true});
const b=await puppeteer.launch({executablePath:process.env.CHROME_PATH || '/usr/bin/google-chrome',args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage();await p.setViewport({width:1080,height:1920});
p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto('http://127.0.0.1:8765/ad.html');await p.waitForFunction('window.DONE',{timeout:180000});
const dur=await p.evaluate(()=>window.DURATION); const N=Math.round(dur*FPS);
const t0=Date.now();
for(let i=0;i<N;i++){const f=`${dir}/${String(i).padStart(4,'0')}.jpg`; if(fs.existsSync(f))continue;
  await p.evaluate(t=>window.render(t),i/FPS); await p.screenshot({path:f,type:'jpeg',quality:94});
  if(i%30===0)console.log(i,'/',N,((Date.now()-t0)/1000).toFixed(0)+'s');}
await b.close(); console.log('DONE');
