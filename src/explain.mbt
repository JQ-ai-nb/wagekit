///|
/// Why a number, not just what number. A tax figure nobody can decompose is a
/// black box; the point of this module is that every withheld amount can be
/// traced back to the bracket, rate and quick deduction that produced it.

///|
pub(all) struct MonthExplanation {
  month : Int32
  /// Cumulative taxable income after deductions.
  taxable_cum : Int64
  /// 1-based bracket number in the annual table; 0 means no tax is due.
  bracket_no : Int32
  /// Marginal rate of that bracket, in integer percent.
  rate_percent : Int32
  /// Quick deduction of that bracket, in cents.
  quick_deduction : Int64
  /// Cumulative tax due up to this month, in cents.
  tax_cum : Int64
  /// Tax withheld this month, in cents.
  withheld : Int64
  /// Human-readable arithmetic, e.g. "22000.00 × 3% − 0.00 = 660.00".
  formula : String
} derive(Eq)

///|
/// Decompose every month of a withholding schedule under an explicit rule set.
pub fn explain_withholding(
  rules : RuleSet,
  inputs : Array[MonthInput],
) -> Array[MonthExplanation] {
  let results = withholding_under(rules, inputs)
  let out = []
  for r in results {
    match bracket(rules.annual, r.taxable_cum) {
      None =>
        out.push({
          month: r.month,
          taxable_cum: r.taxable_cum,
          bracket_no: 0,
          rate_percent: 0,
          quick_deduction: 0L,
          tax_cum: 0L,
          withheld: 0L,
          formula: "累计应纳税所得额未超过起征点，应纳税额为 0.00",
        })
      Some(i) => {
        let rate = rules.annual.rates[i]
        let quick = rules.annual.quick[i]
        out.push({
          month: r.month,
          taxable_cum: r.taxable_cum,
          bracket_no: i + 1,
          rate_percent: rate,
          quick_deduction: quick,
          tax_cum: r.tax_cum,
          withheld: r.withheld,
          formula: yuan_text(r.taxable_cum) +
          " × " +
          rate.to_string() +
          "% − " +
          yuan_text(quick) +
          " = " +
          yuan_text(r.tax_cum),
        })
      }
    }
  }
  out
}
