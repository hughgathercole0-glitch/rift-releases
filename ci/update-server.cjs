const fs=require('node:fs');const path=require('node:path');const https=require('node:https');const {createHash}=require('node:crypto');
const root=process.env.RIFT_TEST_SERVER,port=18443;
const sha=file=>createHash('sha512').update(fs.readFileSync(file)).digest('base64');
const server=https.createServer({pfx:fs.readFileSync(process.env.RIFT_TEST_PFX),passphrase:process.env.RIFT_TEST_PFX_PASSWORD},(req,res)=>{
 const url=new URL(req.url,'https://localhost');const mode=fs.readFileSync(path.join(root,'mode.txt'),'utf8').trim();
 if(url.pathname==='/latest.yml'){const name=mode==='bad'?'bad.exe':mode==='interrupt'?'interrupted.exe':'good.exe',file=path.join(root,name),version=mode==='good'?'0.6.2':'0.6.3',digest=sha(file),size=fs.statSync(file).size;res.writeHead(200,{'Content-Type':'application/yaml','Cache-Control':'no-store'});res.end(JSON.stringify({version,files:[{url:name,sha512:digest,size}],path:name,sha512:digest,releaseDate:new Date().toISOString()}));return;}
 const name=url.pathname.slice(1);if(!['good.exe','bad.exe','interrupted.exe'].includes(name)){res.writeHead(404);res.end();return;}
 const file=path.join(root,name),size=fs.statSync(file).size;let start=0,end=size-1,status=200;
 if(req.headers.range){const match=/^bytes=(\d+)-(\d*)$/.exec(req.headers.range);if(!match){res.writeHead(416);res.end();return;}start=Number(match[1]);end=match[2]?Number(match[2]):end;if(start>end||end>=size){res.writeHead(416);res.end();return;}status=206;res.setHeader('Content-Range',`bytes ${start}-${end}/${size}`);}
 res.writeHead(status,{'Content-Type':'application/octet-stream','Content-Length':end-start+1,'Accept-Ranges':'bytes'});
 if(req.method==='HEAD'){res.end();return;}
 if(mode==='interrupt'){console.log('Deliberately interrupting update download after 1 MiB');const stream=fs.createReadStream(file,{start,end:Math.min(end,start+1048576)});stream.on('end',()=>res.destroy());stream.pipe(res);return;}
 fs.createReadStream(file,{start,end}).pipe(res);
});server.listen(port,'::',()=>console.log('Test update server ready on HTTPS localhost:'+port));
