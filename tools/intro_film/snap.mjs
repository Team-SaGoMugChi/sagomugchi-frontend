import puppeteer from 'puppeteer-core';
const times=process.argv[2].split(',').map(Number); const pre=process.argv[3]||'out/s';
const b=await puppeteer.launch({executablePath:process.env.CHROME_PATH || '/usr/bin/google-chrome',args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage();await p.setViewport({width:1080,height:1920});
p.on('pageerror',e=>console.log('ERR',e.message));p.on('console',m=>{if(!m.text().includes('404'))console.log('PAGE',m.text())});
await p.goto('http://127.0.0.1:8765/ad.html');await p.waitForFunction('window.DONE',{timeout:180000});
for(const t of times){await p.evaluate(t=>window.render(t),t);await p.screenshot({path:`${pre}_${t.toFixed(2)}.jpg`,type:'jpeg',quality:85});}
await b.close();
