// Batch benchmark: N employees x 12 months through the JSON wire, one run per
// employee (the realistic shape: each employee's year is computed separately).
//
//   node scripts/build.mjs && node bench/bench.mjs [people] [runs]
import {run} from '../dist/wagekit.js';

const people = Number(process.argv[2] ?? 1000);
const runs = Number(process.argv[3] ?? 5);

function employee(seed) {
  const gross = 800_000 + ((seed * 7919) % 3_200_000); // 8k - 40k yuan
  const social = Math.round(gross * (8 + ((seed * 13) % 5)) / 100); // 8-12%
  const special = ((seed * 997) % 5) * 100_000; // 0-4000 yuan
  const months = Array.from({length: 12}, () => ({gross, social, special, other: 0}));
  return JSON.stringify({
    year: 2026,
    months,
    ...(seed % 3 === 0 ? {bonus: 1_200_000 + ((seed * 31) % 2_800_000)} : {}),
  });
}

const docs = Array.from({length: people}, (_, i) => employee(i + 1));
const samples = [];
for (let r = 0; r < runs; r++) {
  const start = process.hrtime.bigint();
  let rows = 0;
  for (const doc of docs) {
    const report = JSON.parse(run(doc));
    if (!report.ok) throw new Error('report failed: ' + JSON.stringify(report).slice(0, 200));
    rows += report.months.length;
  }
  const end = process.hrtime.bigint();
  samples.push(Number(end - start) / 1e6);
}
samples.sort((a, b) => a - b);
const median = samples[Math.floor(samples.length / 2)];
console.log(
  JSON.stringify(
    {
      people,
      months_per_person: 12,
      runs,
      median_total_ms: Number(median.toFixed(1)),
      per_person_ms: Number((median / people).toFixed(3)),
      per_month_us: Number(((median * 1000) / (people * 12)).toFixed(1)),
    },
    null,
    2,
  ),
);
