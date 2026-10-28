///|
/// Whole-year summary: what a payroll clerk and an auditor both want on one
/// screen. Derived only from the monthly inputs and the withholding schedule,
/// so it can never disagree with the payslips.

///|
pub(all) struct YearSummary {
  /// Number of months covered.
  months : Int32
  /// Total gross pay.
  gross_total : Int64
  /// Total employee cash deductions (social insurance + housing fund).
  cash_deduction_total : Int64
  /// Total tax-base deductions (special extra + other), which reduce tax but
  /// not the cash paid out.
  tax_base_deduction_total : Int64
  /// Total tax withheld.
  tax_total : Int64
  /// Total net pay: gross - cash deductions - tax.
  net_total : Int64
  /// Tax as basis points of gross (万分比), e.g. 812 = 8.12%.
  effective_rate_bp : Int32
} derive(Eq)

///|
/// Build the summary from the same inputs and schedule the payslips use.
pub fn summarize(
  inputs : Array[MonthInput],
  results : Array[MonthResult],
) -> YearSummary {
  let mut gross = 0L
  let mut cash = 0L
  let mut tax_base = 0L
  for input in inputs {
    gross = gross + input.gross
    cash = cash + input.social
    tax_base = tax_base + input.special + input.other
  }
  let tax = total_withheld(results)
  let net = gross - cash - tax
  let rate = if gross <= 0L {
    0
  } else {
    ((tax * 10_000L + gross / 2L) / gross).to_int()
  }
  {
    months: inputs.length(),
    gross_total: gross,
    cash_deduction_total: cash,
    tax_base_deduction_total: tax_base,
    tax_total: tax,
    net_total: net,
    effective_rate_bp: rate,
  }
}

///|
/// Render the year summary in Markdown.
pub fn render_year_summary(summary : YearSummary) -> String {
  let buf = StringBuilder()
  let whole = summary.effective_rate_bp / 100
  let frac = summary.effective_rate_bp % 100
  let frac_text = if frac < 10 {
    "0" + frac.to_string()
  } else {
    frac.to_string()
  }
  buf.write_string("# 年度汇总（\{summary.months} 个月）\n\n")
  buf.write_string("| 项目 | 金额（元） |\n| --- | --- |\n")
  buf.write_string("| 应发合计 | \{yuan_text(summary.gross_total)} |\n")
  buf.write_string(
    "| 三险一金合计 | \{yuan_text(summary.cash_deduction_total)} |\n",
  )
  buf.write_string(
    "| 计税扣除合计（专项附加 + 其他） | \{yuan_text(summary.tax_base_deduction_total)} |\n",
  )
  buf.write_string("| 预扣个税合计 | \{yuan_text(summary.tax_total)} |\n")
  buf.write_string("| 实发合计 | \{yuan_text(summary.net_total)} |\n")
  buf.write_string(
    "| 实际税负率 | " + whole.to_string() + "." + frac_text + "% |\n",
  )
  buf.to_string()
}
