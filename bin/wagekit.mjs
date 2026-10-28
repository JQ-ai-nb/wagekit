#!/usr/bin/env node
// WageKit CLI: run a payroll/tax report from a JSON document.
//
//   node bin/wagekit.mjs input.json
//
// Input (all amounts are integer CENTS):
//   {"year":2026,
//    "months":[{"gross":3000000,"social":0,"special":300000,"other":0}],
//    "bonus":3600000}
//
// Exit codes: 0 report ok; 2 invalid input.
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';

const usage='Usage: node bin/wagekit.mjs <input.json> [--md]\nAll amounts are integer cents (1 yuan = 100 cents).\n--md renders a full-year payslip in Markdown instead of JSON.\nExit: 0 ok; 2 invalid input.';
const args=process.argv.slice(2);
if(args.length===1&&['-h','--help'].includes(args[0])){console.log(usage);process.exit(0);}
const markdown=args.includes('--md');
const positional=args.filter(a=>a!=='--md');
if(positional.length!==1){console.error(usage);process.exit(2);}

const inputPath=resolve(positional[0]);
let documentText;
try{
  documentText=JSON.stringify(JSON.parse(readFileSync(inputPath,'utf8')));
}catch(error){
  // Machine-readable on stdout, human hint on stderr: same contract as every
  // other failure, so `node bin/wagekit.mjs x.json | jq .ok` never sees empty.
  const message='invalid input file: '+error.message;
  console.error(message);
  console.log(JSON.stringify({ok:false,error:message}));
  process.exit(2);
}

const core=await import('../dist/wagekit.js');
const raw=markdown?core.run_payslip(documentText):core.run(documentText);
console.log(raw);
process.exitCode=markdown?(raw.startsWith('error:')?2:0):(raw.includes('"ok":true')?0:2);
