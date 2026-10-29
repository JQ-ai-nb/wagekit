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
/// `tax_cum(k) - sum(withholding before k)` clamped at zero.
/// Falling tax liability never erases amounts already withheld.
pub fn cumulative_withholding(inputs : Array[MonthInput]) -> Array[MonthResult] {
  withholding_under(default_rules(), inputs)
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
