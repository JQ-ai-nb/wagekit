import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve} from 'node:path';

const root = resolve(import.meta.dirname, '..');
const cli = resolve(root, 'bin/wagekit.mjs');

function run(doc) {
  const dir = mkdtempSync(join(tmpdir(), 'wagekit-'));
  const file = join(dir, 'input.json');
  writeFileSync(file, JSON.stringify(doc));
  return spawnSync(process.execPath, [cli, file], {encoding: 'utf8'});
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
