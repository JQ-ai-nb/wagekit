import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {parseCsv,toCents,auditDocument} from '../web/csv.mjs';
import {audit,run} from '../dist/wagekit.js';
const cli=(file,...args)=>spawnSync(process.execPath,['bin/audit.mjs',file,...args],{cwd:new URL('..',import.meta.url),encoding:'utf8'});
test('audit CLI returns 1 and row evidence for a seeded 150 yuan difference',()=>{
 const r=cli('examples/audit.csv','--json');assert.equal(r.status,1);
 const report=JSON.parse(r.stdout);assert.equal(report.checked,4);assert.equal(report.differences,1);
 assert.equal(report.rows[2].delta,15000);assert.equal(report.rows[2].paid_before,30000);
});
test('corrected audit file returns 0',()=>{assert.equal(cli('examples/audit-clean.csv').status,0);});
test('decimal conversion uses exact text, including 0.29',()=>{
 assert.equal(toCents('0.29'),29);assert.equal(toCents('3000.10'),300010);
 for(const text of ['1e3','0.0001','10000000000.01','NaN'])assert.throws(()=>toCents(text));
});
test('CSV supports UTF-8 BOM, quotes, escaped quotes and CRLF',()=>{
 assert.deepEqual(parseCsv('\uFEFFid,value\r\n"E,01","a""b"\r\n'),[['id','value'],['E,01','a"b']]);
 assert.throws(()=>parseCsv('id\n"unclosed'));
});
test('duplicate employee periods and incomplete histories are rejected',()=>{
 const h='employee_id,year,period,gross,social,special,other,actual_withheld\n';
 assert.throws(()=>auditDocument(h+'A,2026,1,15000,0,0,0,300\nA,2026,1,0,0,0,0,0'),/duplicate/);
 assert.throws(()=>auditDocument(h+'A,2026,2,15000,0,0,0,300'),/history/);
});
test('audit core rejects mismatched arrays and duplicate ids',()=>{
 const e={employee_id:'A',months:[{gross:100,social:0,special:0,other:0}],actual_withheld:[]};
 assert.equal(JSON.parse(audit(JSON.stringify({year:2026,employees:[e]}))).ok,false);
 e.actual_withheld=[0];
 assert.equal(JSON.parse(audit(JSON.stringify({year:2026,employees:[e,e]}))).ok,false);
});
test('JSON source duplicate keys are rejected rather than normalized away',()=>{
 assert.equal(JSON.parse(run('{"year":2026,"year":2020,"months":[]}')).ok,false);
});
test('fractional money tokens that round to integer Doubles are rejected',()=>{
 assert.equal(JSON.parse(run('{"year":2026,"months":[],"bonus":1000000000000.00001}')).ok,false);
});
test('incomplete annual data produces no definitive bonus recommendation',()=>{
 const r=JSON.parse(run('{"year":2026,"months":[],"bonus":3600000}'));
 assert.equal(r.bonus.best,'needs_annual_data');assert.equal(r.bonus.combined_extra_tax,null);
});
test('complete partial-employment annual data recommends the correct bonus route',()=>{
 const r=JSON.parse(run(JSON.stringify({year:2026,annual_complete:true,months:[{gross:2000000,social:0,special:0,other:0}],bonus:3600000})));
 assert.equal(r.bonus.best,'combined');assert.equal(r.bonus.combined_extra_tax,0);
});
test('annual-only data requires an explicit complete-year declaration',()=>{
 const r=JSON.parse(run('{"year":2026,"months":[],"other_income":100000}'));assert.equal(r.ok,false);
});
test('unsupported past and future years are rejected',()=>{
 for(const year of [2020,2027,2030])assert.equal(JSON.parse(run(JSON.stringify({year,months:[]}))).ok,false);
});
test('unsupported columns are rejected rather than silently ignored',()=>{
 const csv='employee_id,year,period,gross,social,special,other,actual_withheld,tax_exempt\nA,2026,1,15000,0,0,0,300,1000';
 assert.throws(()=>auditDocument(csv),/unsupported CSV column: tax_exempt/);
});
test('Chinese payroll headers map to the same audit fields',()=>{
 const zh='员工编号,年份,期次,应发工资,个人社保公积金,专项附加扣除,其他计税扣除,实扣个税\nE001,2026,1,15000,0,0,0,300';
 const r=JSON.parse(audit(JSON.stringify(auditDocument(zh))));
 assert.equal(r.passed,true);assert.equal(r.rows[0].expected,30000);
 const duplicate=zh.replace('员工编号,年份','员工编号,employee_id,年份').replace('E001,2026','E001,E001,2026');
 assert.throws(()=>auditDocument(duplicate),/duplicate CSV header/);
});
test('year uses a plain integer token without float-rounding ambiguity',()=>{
 assert.equal(JSON.parse(run('{"year":2026.00000000000001,"months":[]}')).ok,false);
});
test('unknown JSON fields in audit and employee records are rejected',()=>{
 const employee={employee_id:'A',months:[{gross:100,social:0,special:0,other:0}],actual_withheld:[0]};
 assert.match(JSON.parse(audit(JSON.stringify({year:2026,employees:[employee],tolrance:2}))).error,/unknown field: tolrance/);
 assert.match(JSON.parse(audit(JSON.stringify({year:2026,employees:[{...employee,exemption:2}]}))).error,/unknown field: exemption/);
});
test('merged bonus settlement uses declared total prepaid and includes bonus once',()=>{
 const months=Array.from({length:12},()=>({gross:1000000,social:0,special:100000,other:0}));
 const data={year:2026,months,annual_complete:true,bonus:4800000,bonus_merged:true,salary_prepaid:687000};
 const r=JSON.parse(run(JSON.stringify(data)));
 assert.equal(r.ok,true);assert.equal(r.settlement.bonus_merged,true);
 assert.equal(r.settlement.tax_due,708000);assert.equal(r.settlement.prepaid,687000);assert.equal(r.settlement.payable,21000);
 assert.equal(r.bonus.standalone_tax,459000);assert.equal(r.bonus.combined_extra_tax,480000);
});
test('combined bonus settlement rejects missing prepaid wages and bonus',()=>{
 const d={year:2026,months:[],annual_complete:true,bonus:4800000,bonus_merged:true};
 assert.match(JSON.parse(run(JSON.stringify(d))).error,/requires salary_prepaid/);
 assert.match(JSON.parse(run(JSON.stringify({...d,bonus:undefined,salary_prepaid:0}))).error,/requires a separate bonus/);
});
