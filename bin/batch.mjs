#!/usr/bin/env node
// Batch payroll: one CSV in, one payslip per employee out.
//
//   node bin/batch.mjs employees.csv [--out payslips] [--json]
//
// CSV columns (headings required, order free):
//   name,gross,social,special,other,bonus
// Amounts are YUAN (decimals allowed); they are converted to integer cents
// before they ever reach the engine, so 3000.10 becomes 300010 exactly.
//
// Exit codes: 0 ok; 2 bad input (unreadable file, missing column, bad number).
import {readFileSync, mkdirSync, writeFileSync} from 'node:fs';
import {resolve, join} from 'node:path';

const usage =
  'Usage: node bin/batch.mjs <employees.csv> [--out <dir>] [--json]\n' +
  'Columns: name,gross,social,special,other,bonus (bonus optional)\n' +
  'Amounts are yuan; they are converted to integer cents.';

const args = process.argv.slice(2);
let inputPath = '';
let outDirRaw = 'payslips';
let quietJson = false;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === '--out') {
    outDirRaw = args[++i] ?? 'payslips';
  } else if (arg === '--json') {
    quietJson = true;
  } else if (arg === '--help' || arg === '-h') {
    console.error(usage);
    process.exit(0);
  } else if (arg.startsWith('--')) {
    console.error(`unknown flag: ${arg}\n${usage}`);
    process.exit(2);
  } else if (inputPath === '') {
    inputPath = arg;
  } else {
    console.error(`unexpected argument: ${arg}\n${usage}`);
    process.exit(2);
  }
}
if (inputPath === '') {
  console.error(usage);
  process.exit(2);
}

const outDir = resolve(outDirRaw);

const REQUIRED = ['name', 'gross', 'social', 'special', 'other'];
const toCents = (raw, field, line) => {
  const text = String(raw ?? '').trim();
  if (text === '') {
    if (field === 'bonus') return 0;
    throw new Error(`line ${line}: missing ${field}`);
  }
  const value = Number(text);
  if (!Number.isFinite(value)) throw new Error(`line ${line}: ${field} is not a number: ${text}`);
  if (value < 0) throw new Error(`line ${line}: ${field} must be non-negative`);
  // Round to cents explicitly: Number(x)*100 can land on 300009.99999999994.
  const cents = Math.round(value * 100);
  if (Math.abs(cents / 100 - value) > 1e-9) {
    throw new Error(`line ${line}: ${field} has more than two decimals: ${text}`);
  }
  return cents;
};

let table;
try {
  table = readFileSync(resolve(inputPath), 'utf8');
} catch (error) {
  console.error(`cannot read ${inputPath}: ${error.message}`);
  process.exit(2);
}

const rows = table.split(/\r?\n/).filter((line) => line.trim() !== '');
if (rows.length < 2) {
  console.error('CSV needs a header row and at least one employee');
  process.exit(2);
}

const header = rows[0].split(',').map((h) => h.trim().toLowerCase());
for (const field of REQUIRED) {
  if (!header.includes(field)) {
    console.error(`header is missing "${field}"; found: ${header.join(', ')}`);
    process.exit(2);
  }
}
const col = (name) => header.indexOf(name);

const core = await import('../dist/wagekit.js');
const people = [];
try {
  for (let i = 1; i < rows.length; i++) {
    const cells = rows[i].split(',');
    const line = i + 1;
    const name = (cells[col('name')] ?? '').trim() || `employee-${i}`;
    const entry = {
      gross: toCents(cells[col('gross')], 'gross', line),
      social: toCents(cells[col('social')], 'social', line),
      special: toCents(cells[col('special')], 'special', line),
      other: toCents(cells[col('other')], 'other', line),
    };
    const bonus = col('bonus') >= 0 ? toCents(cells[col('bonus')], 'bonus', line) : 0;
    people.push({name, line, entry, bonus});
  }
} catch (error) {
  console.error(error.message);
  process.exit(2);
}

mkdirSync(outDir, {recursive: true});
const summary = [];
const problems = [];
for (const person of people) {
  const doc = {
    year: 2026,
    months: [person.entry],
    ...(person.bonus > 0 ? {bonus: person.bonus} : {}),
  };
  const text = JSON.stringify(doc);
  const report = JSON.parse(core.run(text));
  if (!report.ok) {
    problems.push({name: person.name, error: report.error});
    continue;
  }
  const slip = core.run_payslip(text);
  const safe = person.name.replace(/[\\/:*?"<>|\s]+/g, '_');
  const file = join(outDir, `${String(summary.length + 1).padStart(3, '0')}-${safe}.md`);
  writeFileSync(file, slip, 'utf8');
  summary.push({
    name: person.name,
    gross: person.entry.gross,
    withheld: report.total_withheld,
    bonus_tax: report.bonus ? report.bonus.standalone_tax : 0,
    net: person.entry.gross - person.entry.social - report.total_withheld,
    file,
  });
}

if (quietJson) {
  process.stdout.write(JSON.stringify({people: summary.length, problems, rows: summary}, null, 2) + '\n');
} else {
  const monthTax = summary.reduce((acc, r) => acc + r.withheld, 0);
  const bonusTax = summary.reduce((acc, r) => acc + r.bonus_tax, 0);
  const monthNet = summary.reduce((acc, r) => acc + r.net, 0);
  console.log(`已生成 ${summary.length} 份工资条 → ${outDir}`);
  console.log(`月度预扣个税合计 ${(monthTax / 100).toFixed(2)} 元｜月实发合计 ${(monthNet / 100).toFixed(2)} 元`);
  if (bonusTax > 0) {
    // Kept separate on purpose: the engine may recommend merging the bonus into
    // comprehensive income, in which case the standalone figure is not the tax
    // actually paid. Do not fold it into the monthly totals.
    console.log(`年终奖按单独计税合计 ${(bonusTax / 100).toFixed(2)} 元（是否更省见每份工资条的对比）`);
  }
  for (const problem of problems) {
    console.error(`跳过 ${problem.name}: ${problem.error}`);
  }
}
process.exitCode = problems.length > 0 ? 1 : 0;
