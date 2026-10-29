#!/usr/bin/env node
import {readFileSync} from 'node:fs';
import {auditDocument} from '../web/csv.mjs';
import {audit} from '../dist/wagekit.js';
const args=process.argv.slice(2);
const usage='Usage: node bin/audit.mjs <payroll.csv> [--tolerance <yuan>] [--json]\nExit: 0 matched, 1 differences, 2 invalid input.';
if (args[0]==='--help') { console.log(usage); process.exit(0); }
try {
  if(!args[0] || args[0].startsWith('--')) throw new Error(usage);
  let tolerance=0, json=false;
  for(let i=1;i<args.length;i++){
    if(args[i]==='--json') json=true;
    else if(args[i]==='--tolerance'){
      const {toCents}=await import('../web/csv.mjs');
      tolerance=toCents(args[++i],'tolerance');
    } else throw new Error('unknown argument: '+args[i]);
  }
  const doc=auditDocument(readFileSync(args[0],'utf8'),tolerance);
  const result=JSON.parse(audit(JSON.stringify(doc)));
  if(!result.ok) throw new Error(result.error);
  if(json) console.log(JSON.stringify(result,null,2));
  else {
    const yuan=n=>(n/100).toFixed(2);
    console.log('WageKit 2026 工资预扣复核｜'+result.checked+' 期｜'+result.differences+' 项差异');
    for(const r of result.rows.filter(r=>!r.matched)){
      console.log(r.employee_id+' 第'+r.period+'期：应扣 '+yuan(r.expected)+'，实扣 '+yuan(r.actual)+'，差额 '+yuan(r.delta)+' 元');
      console.log('  累计应纳 '+yuan(r.tax_cum)+' − 此前实际累计已扣 '+yuan(r.paid_before)+'；负数按 0 处理');
    }
    if(result.passed)console.log('在声明的适用范围和容差内一致。');
  }
  process.exitCode=result.passed?0:1;
} catch(error) {console.log(JSON.stringify({ok:false,error:error.message}));process.exitCode=2;}
