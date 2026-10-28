///|
/// Rule sets are data, not code. A `RuleSet` bundles everything a policy
/// edition owns — both rate tables, the monthly basic deduction, and the
/// version stamp — so the engine can be re-run under a different edition
/// without a rebuild, and a report can name the exact edition that produced it.

///|
pub(all) struct RuleSet {
  /// Version string carried into every report, e.g. "2026.1".
  version : String
  /// Monthly basic deduction (5 000 yuan in the 2026 edition).
  basic_deduction : Int64
  /// Annual comprehensive-income table used by cumulative withholding.
  annual : RateTable
  /// Monthly-converted table used by the standalone bonus rule.
  monthly : RateTable
} derive(Eq)

///|
/// The edition this build ships with.
pub fn default_rules() -> RuleSet {
  {
    version: RULES_VERSION,
    basic_deduction: BASIC_DEDUCTION,
    annual: annual_table(),
    monthly: monthly_table(),
  }
}

///|
/// Cumulative withholding under an explicit rule set. Same state machine as
/// `cumulative_withholding`, but every constant comes from `rules`.
pub fn withholding_under(
  rules : RuleSet,
  inputs : Array[MonthInput],
) -> Array[MonthResult] {
  let results = []
  let mut cum_gross = 0L
  let mut cum_deduct = 0L
  let mut prev_tax = 0L
  for k, input in inputs {
    cum_gross = cum_gross + input.gross
    cum_deduct = cum_deduct +
      rules.basic_deduction +
      input.social +
      input.special +
      input.other
    let taxable = cum_gross - cum_deduct
    let tax_cum = tax_of(rules.annual, taxable)
    let diff = tax_cum - prev_tax
    let withheld = if diff < 0L { 0L } else { diff }
    results.push({ month: k + 1, taxable_cum: taxable, tax_cum, withheld, })
    prev_tax = tax_cum
  }
  results
}

///|
/// One month of a policy-impact report.
pub(all) struct MonthImpact {
  month : Int32
  /// Withholding under the baseline edition.
  before : Int64
  /// Withholding under the candidate edition.
  after : Int64
  /// `after - before`: positive means the employee pays more.
  delta : Int64
} derive(Eq)

///|
/// What a rule change does to one payroll, month by month. This is the figure
/// an HR or finance team actually needs before a policy edition takes effect:
/// not the new tax, but the difference from the old one.
pub(all) struct PolicyImpact {
  before_version : String
  after_version : String
  months : Array[MonthImpact]
  total_before : Int64
  total_after : Int64
  total_delta : Int64
} derive(Eq)

///|
/// Re-run the same payroll under two editions and report the difference.
pub fn policy_impact(
  before : RuleSet,
  after : RuleSet,
  inputs : Array[MonthInput],
) -> PolicyImpact {
  let baseline = withholding_under(before, inputs)
  let candidate = withholding_under(after, inputs)
  let months = []
  for i, base in baseline {
    let next = candidate[i]
    months.push({
      month: base.month,
      before: base.withheld,
      after: next.withheld,
      delta: next.withheld - base.withheld,
    })
  }
  let total_before = total_withheld(baseline)
  let total_after = total_withheld(candidate)
  {
    before_version: before.version,
    after_version: after.version,
    months,
    total_before,
    total_after,
    total_delta: total_after - total_before,
  }
}
