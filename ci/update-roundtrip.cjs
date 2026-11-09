const fs=require('node:fs');const path=require('node:path');const {spawn,spawnSync}=require('node:child_process');
const {chromium}=require('../ci-tools/node_modules/playwright-core');const asar=require('../ci-tools/node_modules/@electron/asar');
const app=process.env.RIFT_TEST_APP,serverRoot=process.env.RIFT_TEST_SERVER,archive=path.join(path.dirname(app),'resources','app.asar'),port=19222;
const result={platform:'Windows',from:'0.6.0',to:'0.6.1',testCertificateOnly:true,trustedPublicPublisher:false,retailerCheckoutVerified:false};
const wait=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,timeout=120000,retryErrors=true){const end=Date.now()+timeout;let last;while(Date.now()<end){try{const value=await fn();if(value)return value;}catch(e){if(!retryErrors)throw e;last=e;}await wait(750);}throw last||Error('Timed out waiting for native update state.');}
function killApp(){spawnSync('taskkill',['/IM','RIFT.exe','/F'],{stdio:'ignore'});}
function startApp(){const out=fs.openSync('validation/app-update.log','a'),err=fs.openSync('validation/app-update-errors.log','a');const child=spawn(app,[`--remote-debugging-port=${port}`,'--disable-gpu'],{stdio:['ignore',out,err],env:{...process.env,ELECTRON_ENABLE_LOGGING:'1'}});fs.closeSync(out);fs.closeSync(err);return child;}
async function connect(){const browser=await until(()=>chromium.connectOverCDP(`http://127.0.0.1:${port}`),60000);const page=await until(()=>browser.contexts().flatMap(c=>c.pages()).find(p=>p.url().startsWith('rift://app/')),30000);await page.waitForFunction(()=>!!window.riftDesktop);return {browser,page};}
function version(){if(asar.uncacheAll)asar.uncacheAll();return JSON.parse(asar.extractFile(archive,'package.json')).version;}
async function state(page){return page.evaluate(async()=> (await window.riftDesktop.info()).updates);}
(async()=>{
 fs.mkdirSync('validation',{recursive:true});const out=fs.openSync('validation/update-server.log','a');const server=spawn(process.execPath,['ci/update-server.cjs'],{stdio:['ignore',out,out],env:process.env});fs.closeSync(out);
 try{
  await wait(1500);killApp();await wait(1000);startApp();let {browser,page}=await connect();
  if((await page.evaluate(()=>window.riftDesktop.info())).version!=='0.6.0')throw Error('Unexpected starting version.');
  await page.evaluate(()=>{localStorage.setItem('rift-ci-persistence','native-update-fixture');});
  await page.locator('a[data-page="vault"]').click();await page.locator('#passphrase').fill('CI-only-update-test-passphrase');await page.locator('#unlock').click();await page.waitForFunction(()=>document.querySelector('#vault-status').textContent==='Unlocked');
  await page.locator('input[name="givenName"]').fill('CI fixture');await page.locator('#profile-form button[type="submit"]').click();await page.waitForFunction(()=>document.querySelector('#toast').textContent.includes('shipping details saved'));
  const before=await page.evaluate(()=>localStorage.getItem('quickcart.web.vault.v1'));if(before.includes('CI fixture'))throw Error('Fixture shipping data was stored without encryption.');
  await page.evaluate(()=>window.riftDesktop.configureUpdates({url:'https://localhost:18443/',publisher:'RIFT CI Test'}));
  await page.getByRole('button',{name:'Check for updates',exact:true}).click();
  await until(async()=>{const s=await state(page);if(s.status==='error')throw Error('Native update download or signature verification failed: '+s.message);return s.status==='ready';},180000,false);
  result.downloadVerified=true;
  page.once('dialog',dialog=>dialog.accept());await page.getByRole('button',{name:'Restart & update',exact:true}).click().catch(()=>{});
  await until(()=>version()==='0.6.1',180000);await wait(6000);
  const processes=spawnSync('tasklist',['/FI','IMAGENAME eq RIFT.exe','/FO','CSV'],{encoding:'utf8'}).stdout;
  if(!processes.includes('RIFT.exe'))throw Error('Updated app did not relaunch.');
  result.silentInstallAndRelaunch=true;await browser.close().catch(()=>{});killApp();await wait(1500);startApp();({browser,page}=await connect());
  if((await page.evaluate(()=>window.riftDesktop.info())).version!=='0.6.1')throw Error('Updated version did not start.');
  if(await page.evaluate(()=>localStorage.getItem('rift-ci-persistence'))!=='native-update-fixture')throw Error('Browser data did not survive the update.');
  if(await page.evaluate(()=>localStorage.getItem('quickcart.web.vault.v1'))!==before)throw Error('Encrypted vault changed during update.');
  await page.locator('a[data-page="vault"]').click();await page.locator('#passphrase').fill('CI-only-update-test-passphrase');await page.locator('#unlock').click();await page.waitForFunction(()=>document.querySelector('#vault-status').textContent==='Unlocked');
  if(await page.locator('input[name="givenName"]').inputValue()!=='CI fixture')throw Error('Vault could not be recovered after update.');
  const testSource=path.join(path.dirname(app),'native-tests');asar.extractAll(archive,testSource);
  const tests=spawnSync(process.execPath,['--test',...['engine.test.mjs','connections.test.mjs','journal.test.mjs'].map(file=>path.join(testSource,'agent',file))],{encoding:'utf8'});
  fs.writeFileSync('validation/native-agent-tests.log',tests.stdout+'\n'+tests.stderr);if(tests.status!==0)throw Error('Installed native Windows agent tests failed.');result.nativeAgentTests=true;
  result.userDataAndVaultPreserved=true;await page.screenshot({path:'validation/updated-desktop.png'});
  for(const mode of ['interrupt','bad']){
   fs.writeFileSync(path.join(serverRoot,'mode.txt'),mode);await page.evaluate(()=>window.riftDesktop.checkUpdates()).catch(()=>{});
   await until(async()=>{const s=await state(page);if(s.status==='ready')throw Error('Invalid update was incorrectly offered for installation.');return s.status==='error';},180000,false);
   const rejected=await page.evaluate(async()=>{try{await window.riftDesktop.installUpdate();return false;}catch{return true;}});if(!rejected||version()!=='0.6.1')throw Error('Failed update changed the installed version or allowed installation.');
   result[mode==='interrupt'?'interruptedDownloadRejected':'invalidSignatureRejected']=true;
  }
  result.status='passed';fs.writeFileSync('validation/update-result.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));await browser.close().catch(()=>{});
 }finally{killApp();server.kill();}
})().catch(error=>{result.status='failed';result.error=error.stack;fs.writeFileSync('validation/update-result.json',JSON.stringify(result,null,2));console.error(error);process.exitCode=1;});
