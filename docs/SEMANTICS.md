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

## 金额范围（Amount range）

单笔金额必须满足 `|cents| ≤ MAX_AMOUNT`（1e12 分 = 100 亿元）。超过即由线格式拒绝，
不会进入计算。这个上界的存在理由很具体：`amount × 45%` 必须不能溢出 Int64，否则
会静默得出负数或 0 税额——对税务库来说，给错数比报错糟得多。

最高档在设计上没有上界：`upper` 的最后一项是哨兵值，`bracket()` 对任何更大的金额
都返回最后一档。曾经这里返回 `None`，导致超大收入被按 0 征税，已修正并有测试锁定。

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
                 − 5000 × D − Σ social − Σ special − Σ other
tax_due        = tax_of(annual_table, taxable_annual)
prepaid        = Σ withheld + other_prepaid
refund/payable = prepaid − tax_due     (reported separately, never a sign)
```

**`D` is the deduction basis, and it is a parameter, not a guess.** It decides
how many months of the 5 000 yuan basic deduction the figure is entitled to:

| `deduction_months` | `D` | When it is right |
| --- | --- | --- |
| omitted | number of months supplied | Full year in (12 in → 12 deducted), or an in-year departure settled on the months actually worked. Keeps the settlement consistent with the withholding that produced `prepaid`. |
| `12` | 12 (60 000 yuan) | A resident individual's statutory annual deduction, even when only part of the year's income is supplied. |

The two differ by real money on partial-year input, so the engine refuses to
pick silently. Example, one month of 20 000 salary plus 10 000 labor income
(8 000 after the 80% inclusion, 1 600 prepaid):

- follow the data (`D = 1`): taxable 23 000 → 690 due → **refund 1 360**
- statutory year (`D = 12`): taxable −32 000 → 0 due → **refund 2 050**

With a full year supplied both give the same answer, which is why the default
never surprises a normal annual run.

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

## 规则集（Rule sets）

A `RuleSet` is the whole policy edition in one value: `version`, monthly
`basic_deduction`, the `annual` table and the `monthly` table. `default_rules()`
returns the shipped edition; `withholding_under(rules, inputs)` runs the same
state machine under any other. Nothing in the engine reads a table directly, so
"a policy change is a data change" is enforced by the signature rather than
asserted in prose.

## 税额分解（Explanation）

`explain_withholding(rules, inputs)` returns, per month: cumulative taxable
income, 1-based bracket number, marginal rate, quick deduction, cumulative tax,
withheld amount, and the arithmetic as a string. The invariant is that the
decomposition agrees with the schedule it describes — same `tax_cum`, same
`withheld` — which the test suite checks for a full year, not just one month.
A month whose cumulative taxable income is not positive reports bracket `0` and
zero tax rather than pretending to be in the first bracket.

## 税后反推（Gross-up）

Forward: `net(g) = g − social − tax_of(annual, g − basic − social − special − other)`.
Inverse: find the **smallest** `g` with `net(g) ≥ target`.

- `net` is non-decreasing in `g` because the marginal rate is below 100% and the
  tax is never negative, so the inverse is a monotone search.
- Cent rounding creates plateaus: consecutive gross values can map to the same
  net, so some targets are unreachable. The engine returns the smallest gross
  that reaches or exceeds the target and reports `overshoot = net − target`
  and `exact`. Silently rounding the answer down would underpay the promise.
- Search is doubling to bracket the answer, then binary search: `O(log g)`.
- Scoped to a **first month** (no prior cumulative state). Withholding later in
  the year depends on the months before it, so a "monthly net" figure is only
  well defined for the first period or for a steady state.

## 政策影响面（Policy impact）

`policy_impact(before, after, inputs)` runs one payroll under two editions and
returns per-month `{before, after, delta}` plus the totals. Guarantees: the
monthly deltas sum to `total_delta`, and `total_after = total_before + total_delta`.
This is what a finance team needs before an edition takes effect — not the new
tax, but the difference from the old one.

## 数据版本化（Data versioning）

Tax tables live in code as data (`annual_table`, `monthly_table`), one function
per year-cycle, and are bundled into a `RuleSet` together with the basic
deduction and a version string. A policy change is a data change, not an engine
change; `default_rules()` is the only place that decides which edition an
unqualified call means, and every report stamps the edition that produced it.
