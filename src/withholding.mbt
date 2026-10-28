///|
/// Cumulative withholding for comprehensive income (工资薪金, 累计预扣预缴).
///
/// This is a period state machine, not a per-month function: each month's
/// withholding depends on the running totals of every earlier month.

///|
/// Monthly input for one employee. All amounts in cents.
pub(all) struct MonthInput {
  /// Gross salary before any deduction.
  gross : Int64
  /// Employee-paid social insurance and housing fund.
  social : Int64
  /// Itemised special extra deductions (子女教育、房贷利息、赡养老人…).
  special : Int64
  /// Other deductions (企业年金、商业健康险…).
  other : Int64
} derive(Eq)

///|
/// Per-month result of the cumulative withholding schedule.
pub(all) struct MonthResult {
  /// 1-based month index.
  month : Int32
  /// Cumulative taxable income after deductions (may be negative early on).
  taxable_cum : Int64
  /// Cumulative tax due up to this month.
  tax_cum : Int64
  /// Tax to withhold for this month (never negative).
  withheld : Int64
} derive(Eq)

///|
/// Monthly basic deduction: 5000 yuan in cents.
pub const BASIC_DEDUCTION : Int64 = 500_000L

///|
/// Run the cumulative withholding schedule over a list of monthly inputs.
/// Month 1 is the first entry; withholding for month k is
/// `tax_cum(k) - tax_cum(k-1)` clamped at zero (over-withheld tax carries
/// forward as credit, per the cumulative method).
pub fn cumulative_withholding(inputs : Array[MonthInput]) -> Array[MonthResult] {
  let results = []
  let table = annual_table()
  let mut cum_gross = 0L
  let mut cum_deduct = 0L
  let mut prev_tax = 0L
  for k, input in inputs {
    cum_gross = cum_gross + input.gross
    cum_deduct = cum_deduct +
      BASIC_DEDUCTION +
      input.social +
      input.special +
      input.other
    let taxable = cum_gross - cum_deduct
    let tax_cum = tax_of(table, taxable)
    let diff = tax_cum - prev_tax
    let withheld = if diff < 0L { 0L } else { diff }
    results.push({ month: k + 1, taxable_cum: taxable, tax_cum, withheld, })
    prev_tax = tax_cum
  }
  results
}

///|
/// Total tax across the whole schedule.
pub fn total_withheld(results : Array[MonthResult]) -> Int64 {
  let mut sum = 0L
  for r in results {
    sum = sum + r.withheld
  }
  sum
}
