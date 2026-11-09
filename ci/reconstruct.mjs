import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';
const version=process.env.RIFT_CI_VERSION;if(!/^\d+\.\d+\.\d+$/.test(version||''))throw Error('Invalid version');
const root=path.resolve('distribution',version),manifest=JSON.parse(fs.readFileSync(path.join(root,'release.json')));
if(manifest.version!==version||!/^RIFT-Setup-[\d.]+-x64\.exe$/.test(manifest.filename)||!Array.isArray(manifest.parts)||manifest.parts.length>50)throw Error('Invalid manifest');
fs.mkdirSync('validation',{recursive:true});const output=path.resolve('validation',manifest.filename),fd=fs.openSync(output,'w');let size=0;const hash=createHash('sha256');
try{for(const part of manifest.parts){if(!/^part-\d{3}\.bin$/.test(part.file))throw Error('Invalid part path');const bytes=fs.readFileSync(path.join(root,part.file));if(bytes.length!==part.size||createHash('sha256').update(bytes).digest('hex')!==part.sha256)throw Error('Part checksum mismatch');fs.writeSync(fd,bytes);hash.update(bytes);size+=bytes.length;}}finally{fs.closeSync(fd);}
if(size!==manifest.size||hash.digest('hex')!==manifest.sha256)throw Error('Complete installer checksum mismatch');
fs.writeFileSync('validation/SHA256SUMS.txt',manifest.sha256+'  '+manifest.filename+'\n');console.log(JSON.stringify({file:output,bytes:size,sha256:manifest.sha256}));
