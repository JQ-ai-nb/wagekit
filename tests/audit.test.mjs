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
