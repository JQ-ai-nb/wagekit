///|
/// A consumer built the way a third party would build one: it imports the
/// package and touches nothing but `pub` items. If this compiles, the public
/// surface is enough to run payroll; if it stops compiling, the API broke
/// someone else's build, which is the only definition of a breaking change
/// that matters here.
///
/// Run it with `moon run examples/embed`.
fn main {
  // A single month: 30 000 gross, 3 000 social, 1 000 special deductions.
  let inputs : Array[@wagekit.MonthInput] = [
    { gross: 3_000_000L, social: 300_000L, special: 100_000L, other: 0L, },
  ]
  let schedule = @wagekit.cumulative_withholding(inputs)
  println("本月预扣 " + @wagekit.yuan_text(schedule[0].withheld) + " 元")
  println(
    "累计应纳税所得额 " +
    @wagekit.yuan_text(schedule[0].taxable_cum) +
    " 元",
  )

  // The same month, explained: which bracket, which rate, which arithmetic.
  let rules = @wagekit.default_rules()
  let explained = @wagekit.explain_withholding(rules, inputs)
  println(
    "档位 " +
    explained[0].bracket_no.to_string() +
    "：" +
    explained[0].formula,
  )

  // Hiring question: what gross pays 20 000 net?
  let offer = @wagekit.gross_up(2_000_000L, 300_000L, 0L, 0L)
  println(
    "到手 " +
    @wagekit.yuan_text(offer.target_net) +
    " 元需要税前 " +
    @wagekit.yuan_text(offer.gross) +
    " 元" +
    (if offer.exact { "（精确）" } else { "（最小可行解）" }),
  )

  // Policy question: what would a 6 000 monthly deduction do to this payroll?
  let candidate = { ..rules, version: "preview", basic_deduction: 600_000L, }
  let impact = @wagekit.policy_impact(rules, candidate, inputs)
  println(
    "起征点 6000：全年少扣 " +
    @wagekit.yuan_text(-impact.total_delta) +
    " 元",
  )
}
