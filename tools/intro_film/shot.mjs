import puppeteer from 'puppeteer-core';
const [,,page_,out,w,h]=process.argv;
const b=await puppeteer.launch({executablePath:process.env.CHROME_PATH || '/usr/bin/google-chrome',args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
const p=await b.newPage();await p.setViewport({width:+w||900,height:+h||600});
p.on('console',m=>console.log('PAGE',m.text()));p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto('http://127.0.0.1:8765/'+page_);await p.waitForFunction('window.DONE',{timeout:120000});
await p.screenshot({path:out});await b.close();
