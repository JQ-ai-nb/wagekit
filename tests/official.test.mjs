import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {run} from '../dist/wagekit.js';

const cases = JSON.parse(readFileSync(new URL('../examples/official-reference-cases.json',import.meta.url),'utf8'));
for (const item of cases) {
  test('public tax authority example: '+item.id,()=>{
    const result=JSON.parse(run(JSON.stringify(item.input)));
    assert.equal(result.ok,true,JSON.stringify(result));
    if (item.expected.withheld) assert.deepEqual(result.months.map(x=>x.withheld),item.expected.withheld);
    assert.equal(result.total_withheld,item.expected.total_withheld);
    if (item.expected.bonus) assert.deepEqual(result.bonus,item.expected.bonus);
    if (item.expected.settlement) assert.deepEqual(result.settlement,item.expected.settlement);
  });
}

