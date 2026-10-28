# Semantics

Every amount in WageKit is an **integer number of cents** (1 yuan = 100 cents).
Floats never touch money. This page fixes the exact computation rules so results
are reproducible and auditable.

## 舍入（Rounding）

- `mul_percent(amount, rate)` computes `amount * rate / 100` and rounds
  **half-up to a cent**.
- Tax = `taxable * rate - quick_deduction`, where the product is rounded
  half-up first, then the quick deduction (an exact cent amount) is subtracted.
- Per-item social insurance shares are each rounded to a cent before summing
  (实务口径，与先合计后舍入可能相差 1 分，这里选择逐项舍入).

## 累计预扣预缴（Cumulative withholding）

For month k of N:

```
taxable_cum(k)   = Σ gross − 5000×k − Σ social − Σ special − Σ other
tax_due_cum(k)   = tax_of(annual_table, taxable_cum(k))     // ≤0 → 0
withheld(k)      = max(0, tax_due_cum(k) − tax_due_cum(k−1))
```

- It is a **period state machine**: month k depends on every earlier month.
- A negative difference (over-withholding) is carried forward as credit, not
  refunded mid-year; the monthly payment is clamped at zero.
- The invariant `Σ withheld = tax_due_cum(N)` holds whenever no negative
  difference occurred.

## 年终奖（Annual one-time bonus）

- **Standalone**: divide the bonus by 12 (integer division, floor), look the
  quotient up in the monthly-converted table, then tax the *whole* bonus at
  that bracket: `bonus × rate − quick`.
- The cliff: at each bracket edge × 12, one extra fen jumps the whole bonus to
  the next rate. The net drops — famously, 36,000 yuan yields 1,080 yuan tax
  while 36,001.20 yuan yields 3,390.02 yuan.
- **Merged**: the bonus is added to the last month's gross and flows through
  the cumulative schedule; the engine reports both and names the cheaper one
  (ties resolve to standalone).

## 劳务报酬（Labor remuneration）

Taxable = income − 800 yuan (income ≤ 4000) or 80% of income (income > 4000).
Brackets on the taxable amount: 20% to 20k yuan; 30% (quick 2000) to 50k yuan;
40% (quick 7000) above.

## 年度汇算（Annual settlement）

```
taxable_annual = Σ gross + other_income + [bonus if merged]
                 − 5000 × N − Σ social − Σ special − Σ other
tax_due        = tax_of(annual_table, taxable_annual)
prepaid        = Σ withheld + other_prepaid
refund/payable = prepaid − tax_due     (reported separately, never a sign)
```

- **Other comprehensive income** (labor remuneration, royalties, author's fees)
  arrives already reduced to its statutory inclusion rate (80% for labor) and
  adds to the annual base; its prepaid amount adds to `prepaid`.
- Wage-only years settle to **zero**: cumulative withholding uses the same
  table and formula as the annual computation. Real refunds come from other
  income types whose withholding rates exceed the annual marginal rate.

## 专项附加扣除（Itemised special extra deductions）

Monthly caps (current cycle): children education 2000/child; infants under 3
2000/child; housing loan 1000 (exclusive with rent); housing rent 800/1100/1500
by city tier; elderly support cap 3000; continuing education cap 400/month (the
3600-yuan annual certificate is spread by the caller); major medical: the
annual out-of-pocket excess over 15,000 yuan, capped at 80,000/year, spread
monthly by the caller. `validate` rejects loan+rent together and any cap
violation.

## 社保公积金（Social insurance & housing fund）

The employee share is computed per item on the base clamped into
`[base_lower, base_upper]`, each item rounded to a cent, then summed. The
bundled city table is **example data**; replace it with current-year figures
from each city's HR bureau before real use.

## 数据版本化（Data versioning）

Tax tables live in code as data (`annual_table`, `monthly_table`), one function
per year-cycle. A policy change is a data change, not an engine change; the
tables are the audit surface.
