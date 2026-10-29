// Shared offline CSV adapter. Domain tax logic stays in the MoonBit engine.
export function parseCsv(source) {
  if (source.length > 4_000_000) throw new Error('CSV exceeds 4 MB');
  source = source.replace(/^\uFEFF/, '');
  const rows = [];
  let row = [], field = '', quoted = false, closed = false;
  const pushField = () => { row.push(field); field = ''; closed = false; };
  const pushRow = () => { pushField(); if (row.some(x => x.trim() !== '')) rows.push(row); row = []; };
  for (let i = 0; i < source.length; i++) {
    const ch = source[i];
    if (quoted) {
      if (ch === '"') {
        if (source[i + 1] === '"') { field += '"'; i++; }
        else { quoted = false; closed = true; }
      } else field += ch;
    } else if (ch === ',') pushField();
    else if (ch === '\r' || ch === '\n') { if (ch === '\r' && source[i+1] === '\n') i++; pushRow(); }
    else if (ch === '"' && field === '' && !closed) quoted = true;
    else {
      if (ch === '"' || closed) throw new Error('invalid CSV quoting');
      field += ch;
    }
  }
  if (quoted) throw new Error('unterminated CSV quote');
  if (field !== '' || row.length || closed) pushRow();
  return rows;
}

export function toCents(raw, field = 'amount', line = 0) {
  const text = String(raw ?? '').trim();
  const prefix = line ? 'line ' + line + ': ' : '';
  if (text.startsWith('-')) throw new Error(prefix + field + ' must be non-negative');
  if (!/^\d+(?:\.\d{1,2})?$/.test(text)) throw new Error(prefix + field + ' must be decimal yuan with at most two decimals');
  const [whole, frac = ''] = text.split('.');
  const cents = BigInt(whole) * 100n + BigInt(frac.padEnd(2, '0'));
  if (cents > 1_000_000_000_000n) throw new Error(prefix + field + ' is out of range');
  return Number(cents);
}

export function table(source, required, allowed = null, aliases = {}) {
  const rows = parseCsv(source);
  if (rows.length < 2) throw new Error('CSV needs a header row and at least one employee');
  const header = rows.shift().map(x => {
    const key = x.trim().toLowerCase();
    return Object.hasOwn(aliases, key) ? aliases[key] : key;
  });
  if (new Set(header).size !== header.length) throw new Error('duplicate CSV header');
  for (const name of required) if (!header.includes(name)) throw new Error('missing column: ' + name);
  if (allowed) {
    const extra = header.filter(name => !allowed.includes(name)).sort();
    if (extra.length) throw new Error('unsupported CSV column: ' + extra[0]);
  }
  return rows.map((cells, i) => {
    if (cells.length !== header.length) throw new Error('line ' + (i + 2) + ': wrong column count');
    return Object.fromEntries(header.map((h, j) => [h, cells[j]]));
  });
}

export function auditDocument(source, tolerance = 0) {
  const columns = ['employee_id','year','period','gross','social','special','other','actual_withheld'];
  const aliases = {'员工编号':'employee_id','年份':'year','期次':'period','应发工资':'gross',
    '个人社保公积金':'social','专项附加扣除':'special','其他计税扣除':'other','实扣个税':'actual_withheld'};
  const rows = table(source, columns, columns, aliases);
  const people = new Map();
  for (const [i, row] of rows.entries()) {
    if (row.year.trim() !== '2026') throw new Error('only year 2026 is supported');
    const id = row.employee_id.trim();
    if (!id || id.length > 128) throw new Error('invalid employee_id');
    if (!/^(?:[1-9]|1[0-2])$/.test(row.period.trim())) throw new Error('period must be 1..12');
    const period = Number(row.period);
    const months = people.get(id) ?? new Map();
    if (months.has(period)) throw new Error('duplicate employee period: ' + id + '/' + period);
    const input = Object.fromEntries(['gross','social','special','other'].map(k => [k,toCents(row[k],k,i+2)]));
    months.set(period, {input, actual:toCents(row.actual_withheld,'actual_withheld',i+2)});
    people.set(id, months);
  }
  if (people.size > 1000) throw new Error('audit supports at most 1000 employees');
  const employees = [...people].map(([employee_id, rows]) => {
    const sorted = [...rows].sort((a,b)=>a[0]-b[0]);
    if (sorted.some(([p],i)=>p !== i+1)) throw new Error('period history must start at 1 with no gaps: ' + employee_id);
    return {employee_id,months:sorted.map(([,r])=>r.input),actual_withheld:sorted.map(([,r])=>r.actual)};
  });
  return {year:2026,tolerance,employees};
}
