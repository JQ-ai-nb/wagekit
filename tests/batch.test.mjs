import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..');
const cli = resolve(root, 'bin/batch.mjs');

function run(csv, extra = ['--json']) {
  const dir = mkdtempSync(join(tmpdir(), 'wk-batch-'));
  const file = join(dir, 'in.csv');
  writeFileSync(file, csv);
  const out = join(dir, 'slips');
  const result = spawnSync(process.execPath, [cli, file, '--out', out, ...extra], {encoding: 'utf8'});
  return {result, out};
}

test('batch writes one payslip per employee and totals the tax', () => {
  const csv = [
    'name,gross,social,special,other,bonus',
    '张三,30000,3000,1000,0,36000',
    '李四,18000,1800,2000,0,0',
    '王五,55000,5500,0,0,120000',
  ].join('\n');
  const {result, out} = run(csv);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.people, 3);
  assert.deepEqual(readdirSync(out).sort(), ['001-张三.md', '002-李四.md', '003-王五.md']);

  const [a, b, c] = report.rows;
  // 30 000 - 5 000 - 3 000 - 1 000 = 21 000, at 3% -> 630
  assert.equal(a.withheld, 63000);
  assert.equal(a.bonus_tax, 108000);
  assert.equal(a.net, 2637000);
  // 18 000 - 5 000 - 1 800 - 2 000 = 9 200, at 3% -> 276
  assert.equal(b.withheld, 27600);
  // 55 000 - 5 000 - 5 500 = 44 500, at 10% - 2520 -> 1930
  assert.equal(c.withheld, 193000);
  assert.equal(report.rows.reduce((acc, r) => acc + r.withheld, 0), 63000 + 27600 + 193000);
});

test('the bonus column is optional', () => {
  const csv = 'name,gross,social,special,other\n甲,20000,2000,0,0';
  const {result} = run(csv);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.rows[0].bonus_tax, 0);
  // 20 000 - 5 000 - 2 000 = 13 000, at 3% -> 390
  assert.equal(report.rows[0].withheld, 39000);
});

test('a missing required column is rejected', () => {
  const {result} = run('name,gross,social,other\n甲,20000,2000,0');
  assert.equal(result.status, 2);
  assert.match(result.stderr, /special/);
});

test('negative amounts are rejected', () => {
  const {result} = run('name,gross,social,special,other\n甲,-1,0,0,0');
  assert.equal(result.status, 2);
  assert.match(result.stderr, /non-negative/);
});

test('amounts with more than two decimals are rejected', () => {
  const {result} = run('name,gross,social,special,other\n甲,100.005,0,0,0');
  assert.equal(result.status, 2);
  assert.match(result.stderr, /two decimals/);
});

test('a header-only file is rejected', () => {
  const {result} = run('name,gross,social,special,other');
  assert.equal(result.status, 2);
  assert.match(result.stderr, /at least one employee/);
});
