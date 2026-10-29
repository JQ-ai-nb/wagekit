#!/usr/bin/env node
// Convenience slips for each employee's first ordinary withholding period.
import {readFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {resolve,join} from 'node:path';
import {table,toCents} from '../web/csv.mjs';
import {run,run_payslip} from '../dist/wagekit.js';
const args=process.argv.slice(2);
const usage='Usage: node bin/batch.mjs employees.csv [--out directory] [--json]';
if(args[0]==='--help'){console.log(usage);process.exit(0);}
try{
 if(!args[0]||args[0].startsWith('--'))throw new Error(usage);
 let out=resolve('payslips'),json=false;
 for(let i=1;i<args.length;i++){
  if(args[i]==='--out'){if(!args[++i])throw new Error('missing output directory');out=resolve(args[i]);}
  else if(args[i]==='--json')json=true;
  else throw new Error('unknown argument: '+args[i]);
 }
 const source=table(readFileSync(args[0],'utf8'),['name','gross','social','special','other']);
 if(source.length>1000)throw new Error('at most 1000 employees');
 // Validate every row before any slip is written.
 const prepared=source.map((row,i)=>{
  const entry=Object.fromEntries(['gross','social','special','other'].map(k=>[k,toCents(row[k],k,i+2)]));
  const bonus=row.bonus?.trim()?toCents(row.bonus,'bonus',i+2):0;
  const doc=JSON.stringify({year:2026,months:[entry],...(bonus?{bonus}:{})});
  const report=JSON.parse(run(doc));
  if(!report.ok)throw new Error(report.error);
  return {name:row.name.trim()||'employee-'+(i+1),entry,doc,report};
 });
 mkdirSync(out,{recursive:true});
 const rows=prepared.map((person,i)=>{
  const safe=person.name.replace(/[\\/:*?"<>|\s]+/g,'_').slice(0,80);
  const file=join(out,String(i+1).padStart(3,'0')+'-'+safe+'.md');
  writeFileSync(file,run_payslip(person.doc),'utf8');
  return {name:person.name,gross:person.entry.gross,withheld:person.report.total_withheld,
    bonus_tax:person.report.bonus?.standalone_tax??0,
    net:person.entry.gross-person.entry.social-person.report.total_withheld,file};
 });
 if(json)console.log(JSON.stringify({people:rows.length,problems:[],rows},null,2));
 else console.log('已生成 '+rows.length+' 份首期工资条 → '+out+'。后续月份复核请使用 audit.mjs 并提供完整历史。');
}catch(error){console.error(error.message);console.log(JSON.stringify({ok:false,error:error.message}));process.exitCode=2;}
