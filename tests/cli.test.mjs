import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..');
const cli = resolve(root, 'bin/wagekit.mjs');

function run(doc, extra = []) {
  const dir = mkdtempSync(join(tmpdir(), 'wagekit-'));
  const file = join(dir, 'input.json');
  writeFileSync(file, JSON.stringify(doc));
  return spawnSync(process.execPath, [cli, file, ...extra], {encoding: 'utf8'});
}

const threeMonths = {
  year: 2026,
  months: [
    {gross: 3000000, social: 0, special: 300000, other: 0},
    {gross: 3000000, social: 0, special: 300000, other: 0},
    {gross: 3000000, social: 0, special: 300000, other: 0},
  ],
  bonus: 3600000,
};

test('cumulative withholding matches the schedule', () => {
  const result = run(threeMonths);
  assert.equal(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.ok, true);
  assert.equal(report.months[0].withheld, 66000);
  assert.equal(report.months[1].withheld, 122000);
  assert.equal(report.months[2].withheld, 220000);
  assert.equal(report.total_withheld, 408000);
});

test('bonus reports both treatments and a recommendation', () => {
  const result = run(threeMonths);
  const report = JSON.parse(result.stdout);
  assert.equal(report.bonus.standalone_tax, 108000);
  assert.equal(['standalone', 'combined'].includes(report.bonus.best), true);
});

test('the famous cliff is reproducible from the wire', () => {
  const below = JSON.parse(run({year: 2026, months: [], bonus: 3600000}).stdout);
  const above = JSON.parse(run({year: 2026, months: [], bonus: 3600012}).stdout);
  assert.equal(below.bonus.standalone_tax, 108000);
  assert.equal(above.bonus.standalone_tax, 339001);
  // one extra fen of bonus, 2310.01 yuan more tax
  assert.ok(above.bonus.standalone_tax > below.bonus.standalone_tax);
});

test('invalid input exits with code 2', () => {
  const result = run({months: [{gross: 'not-a-number'}]});
  assert.equal(result.status, 2);
  assert.equal(JSON.parse(result.stdout).ok, false);
});

test('--md renders a full-year payslip',()=>{
  const result=run(threeMonths,['--md']);
  assert.equal(result.status,0);
  assert.match(result.stdout,/WageKit 工资条（2026）/);
  assert.match(result.stdout,/工资条 2026 年 3 月/);
  assert.match(result.stdout,/年终奖计税方式对比/);
});

test('negative amounts are rejected at the wire',()=>{
  const result=run({year:2026,months:[{gross:-100,social:0,special:0,other:0}]});
  assert.equal(result.status,2);
  assert.match(JSON.parse(result.stdout).error,/non-negative/);
});

test('out-of-range years are rejected',()=>{
  const result=run({year:2200,months:[{gross:100,social:0,special:0,other:0}]});
  assert.equal(result.status,2);
  assert.match(JSON.parse(result.stdout).error,/2000\.\.2100/);
});

test('more than twelve months is rejected',()=>{
  const months=Array.from({length:13},()=>({gross:1000000,social:0,special:0,other:0}));
  const result=run({year:2026,months});
  assert.equal(result.status,2);
  assert.match(JSON.parse(result.stdout).error,/at most 12/);
});

test('explain decomposes each month into bracket, rate and quick deduction',()=>{
  const report=JSON.parse(run({...threeMonths,explain:true}).stdout);
  assert.equal(report.explain.length,3);
  assert.equal(report.explain[0].bracket,1);
  assert.equal(report.explain[0].rate,3);
  assert.equal(report.explain[0].formula,'22000.00 × 3% − 0.00 = 660.00');
  assert.equal(report.explain[1].bracket,2);
  assert.equal(report.explain[1].quick,252000);
  assert.equal(report.explain[2].formula,'66000.00 × 10% − 2520.00 = 4080.00');
  // The breakdown must agree with the schedule it explains.
  report.explain.forEach((e,i)=>assert.equal(e.withheld,report.months[i].withheld));
});

test('target_net grosses up to the smallest gross that reaches it',()=>{
  const report=JSON.parse(run({
    year:2026,
    months:[{gross:3000000,social:0,special:300000,other:0}],
    target_net:2000000,
  }).stdout);
  assert.equal(report.gross_up.net,2000000);
  assert.equal(report.gross_up.overshoot,0);
  assert.equal(report.gross_up.exact,true);
  assert.ok(report.gross_up.gross>2000000);
});

test('explain and gross_up stay absent unless asked for',()=>{
  const report=JSON.parse(run(threeMonths).stdout);
  assert.equal(report.explain,undefined);
  assert.equal(report.gross_up,undefined);
});

test('settlement reconciles other income and reports the refund',()=>{
  const report=JSON.parse(run({
    year:2026,
    months:[{gross:2000000,social:0,special:0,other:0}],
    other_income:800000,
    other_prepaid:160000,
  }).stdout);
  assert.equal(report.settlement.tax_due,69000);
  assert.equal(report.settlement.prepaid,205000);
  assert.equal(report.settlement.refund,136000);
  assert.equal(report.settlement.payable,0);
});

test('settlement stays absent on a wage-only payroll',()=>{
  assert.equal(JSON.parse(run(threeMonths).stdout).settlement,undefined);
});

test('negative other income is rejected',()=>{
  const result=run({year:2026,months:[],other_income:-1});
  assert.equal(result.status,2);
  assert.match(JSON.parse(result.stdout).error,/other_income must be non-negative/);
});

test('preview reports what a different basic deduction would cost',()=>{
  const report=JSON.parse(run({...threeMonths,preview:{basic_deduction:600000}}).stdout);
  const impact=report.policy_impact;
  assert.equal(impact.total_before,408000);
  assert.equal(impact.total_after,378000);
  assert.equal(impact.total_delta,-30000);
  const sum=impact.months.reduce((acc,m)=>acc+m.delta,0);
  assert.equal(sum,impact.total_delta);
  assert.equal(impact.after_version,'preview');
});
