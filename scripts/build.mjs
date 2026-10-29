import {spawnSync} from 'node:child_process';
import {mkdirSync,copyFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {homedir} from 'node:os';

const root=resolve(import.meta.dirname,'..');
const moon=process.platform==='win32'?'moon.exe':'moon';
const run=spawnSync(moon,['build','api','--target','js','--release','--deny-warn'],{cwd:root,stdio:'inherit'});
if(run.error||run.status!==0){
  console.error('MoonBit 0.10.16+ is required on PATH.');
  process.exit(2);
}
mkdirSync(resolve(root,'dist'),{recursive:true});
copyFileSync(resolve(root,'_build/js/release/build/api/api.js'),resolve(root,'dist/wagekit.js'));
// GitHub Pages serves only /web, so the demo needs its own copy next to
// index.html — a relative ../dist/ import resolves outside the published root.
mkdirSync(resolve(root,'web'),{recursive:true});
copyFileSync(resolve(root,'dist/wagekit.js'),resolve(root,'web/wagekit.js'));
console.log('Built dist/wagekit.js from the MoonBit payroll core.');
console.log('Copied web/wagekit.js so the Pages demo is self-contained.');

// Standard-library code is embedded in generated JS; retain its notices.
const coreRoot=resolve(process.env.MOON_HOME || resolve(homedir(),'.moon'),'lib/core');
for(const output of ['dist/licenses','web/licenses']){
  mkdirSync(resolve(root,output),{recursive:true});
  copyFileSync(resolve(coreRoot,'LICENSE'),resolve(root,output,'moonbit-core-LICENSE.txt'));
  copyFileSync(resolve(coreRoot,'NOTICE'),resolve(root,output,'moonbit-core-NOTICE.txt'));
}
