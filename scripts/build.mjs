import {spawnSync} from 'node:child_process';
import {mkdirSync,copyFileSync} from 'node:fs';
import {resolve} from 'node:path';

const root=resolve(import.meta.dirname,'..');
const moon=process.platform==='win32'?'moon.exe':'moon';
const run=spawnSync(moon,['build','api','--target','js','--release','--deny-warn'],{cwd:root,stdio:'inherit'});
if(run.error||run.status!==0){
  console.error('MoonBit 0.10.16+ is required on PATH.');
  process.exit(2);
}
mkdirSync(resolve(root,'dist'),{recursive:true});
copyFileSync(resolve(root,'_build/js/release/build/api/api.js'),resolve(root,'dist/wagekit.js'));
console.log('Built dist/wagekit.js from the MoonBit payroll core.');
