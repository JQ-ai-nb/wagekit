///|
/// JSON wire format for the JS/CLI facade. Keep parsing strict: every amount
/// must be an integer number of cents, silently truncating a float would be
/// an accounting bug.

///|
pub(all) suberror TaxError {
  TaxError(String)
}

///|
fn[T] fail(message : String) -> T raise TaxError {
  raise TaxError(message)
}

///|
fn j_obj(value : Json, what : String) -> Map[String, Json] raise TaxError {
  match value {
    Object(fields) => fields
    _ => fail("expected JSON object for " + what)
  }
}

///|
fn j_array(value : Json, what : String) -> Array[Json] raise TaxError {
  match value {
    Array(items) => items
    _ => fail("expected JSON array for " + what)
  }
}

///|
/// Parse a JSON number that must be an integer count of cents.
fn j_cents(value : Json, what : String) -> Int64 raise TaxError {
  match value {
    Number(n, repr~) => {
      match repr {
        Some(text) =>
          if text.contains(".") || text.contains("e") || text.contains("E") {
            fail("amount must be a plain integer number of cents")
          }
        None => ()
      }
      let cents = n.to_int64()
      if cents.to_double() != n {
        fail("expected an integer number of cents for " + what)
      }
      // Reject absurd magnitudes instead of letting the arithmetic overflow
      // into a negative or zero tax figure.
      if cents > MAX_AMOUNT || cents < -MAX_AMOUNT {
        fail(
          what +
          " is out of range: at most " +
          MAX_AMOUNT.to_string() +
          " cents (10 billion yuan)",
        )
      }
      cents
    }
    _ => fail("expected JSON number for " + what)
  }
}

///|
fn j_int(value : Json, what : String) -> Int32 raise TaxError {
  match value {
    Number(n, ..) => {
      let i = n.to_int()
      if i.to_double() != n {
        fail("expected an integer for " + what)
      }
      i
    }
    _ => fail("expected JSON number for " + what)
  }
}

///|
/// Optional non-negative cent amount. Absent means "not requested", which is
/// deliberately distinct from zero: it decides whether a report block appears.
fn opt_cents(
  fields : Map[String, Json],
  name : String,
) -> Int64? raise TaxError {
  match fields.get(name) {
    Some(value) => {
      let v = j_cents(value, name)
      if v < 0L {
        fail(name + " must be non-negative")
      }
      Some(v)
    }
    None => None
  }
}

///|
fn required(fields : Map[String, Json], name : String) -> Json raise TaxError {
  match fields.get(name) {
    Some(value) => value
    None => fail("missing required field: " + name)
  }
}

///|
fn read_month(value : Json) -> MonthInput raise TaxError {
  let fields = j_obj(value, "month entry")
  let input = {
    gross: j_cents(required(fields, "gross"), "gross"),
    social: j_cents(required(fields, "social"), "social"),
    special: j_cents(required(fields, "special"), "special"),
    other: j_cents(required(fields, "other"), "other"),
  }
  if input.gross < 0L {
    fail("gross must be non-negative")
  }
  if input.social < 0L {
    fail("social must be non-negative")
  }
  if input.special < 0L {
    fail("special must be non-negative")
  }
  if input.other < 0L {
    fail("other must be non-negative")
  }
  input
}

///|
/// Parsed wire document shared by the JSON and Markdown entry points.
pub(all) struct WireInput {
  year : Int32
  inputs : Array[MonthInput]
  bonus : Int64?
  /// Ask for the per-month decomposition in the report.
  explain : Bool
  /// Ask for the gross that produces this first-month take-home.
  target_net : Int64?
  /// Other comprehensive income, already reduced to its statutory inclusion.
  other_income : Int64?
  /// Tax already withheld on `other_income`.
  other_prepaid : Int64?
  /// Ask what a different monthly basic deduction would do to this payroll.
  preview_basic : Int64?
  /// Basic-deduction months for the settlement figure; omitted = follow the
  /// number of months supplied.
  deduction_months : Int32?
  annual_complete : Bool
  annual_deductions : Int64
  salary_prepaid : Int64?
} derive(Eq)

///|
fn parse_input(source : String) -> WireInput raise TaxError {
  if source.length() > 8_000_000 {
    fail("JSON input is too large")
  }
  let document = @json.parse(
    source,
    max_nesting_depth=16,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => fail("input is not valid JSON")
  }
  let fields = j_obj(document, "input")
  let year = match fields.get("year") {
    Some(value) => j_int(value, "year")
    None => 2026
  }
  if year != 2026 {
    fail("only year 2026 is supported by the bundled rules")
  }
  let inputs = j_array(required(fields, "months"), "months").map(read_month)
  if inputs.length() > 12 {
    fail("a tax year has at most 12 months")
  }
  let bonus = match fields.get("bonus") {
    Some(value) => {
      let b = j_cents(value, "bonus")
      if b < 0L {
        fail("bonus must be non-negative")
      }
      Some(b)
    }
    None => None
  }
  let explain = match fields.get("explain") {
    Some(True) => true
    Some(False) => false
    Some(_) => fail("explain must be a boolean")
    None => false
  }
  let target_net = match fields.get("target_net") {
    Some(value) => {
      let t = j_cents(value, "target_net")
      if t < 0L {
        fail("target_net must be non-negative")
      }
      Some(t)
    }
    None => None
  }
  let other_income = opt_cents(fields, "other_income")
  let other_prepaid = opt_cents(fields, "other_prepaid")
  let preview_basic = match fields.get("preview") {
    Some(value) => opt_cents(j_obj(value, "preview"), "basic_deduction")
    None => None
  }
  let deduction_months = match fields.get("deduction_months") {
    Some(value) => {
      let months = j_int(value, "deduction_months")
      if months != 12 {
        fail("resident annual settlement requires deduction_months=12")
      }
      Some(months)
    }
    None => None
  }
  let annual_complete = match fields.get("annual_complete") {
    Some(True) => true
    Some(False) | None => false
    _ => fail("annual_complete must be a boolean")
  }
  let annual_deductions = match opt_cents(fields, "annual_deductions") {
    Some(v) => v
    None => 0L
  }
  let salary_prepaid = opt_cents(fields, "salary_prepaid")
  if !annual_complete &&
    (
      other_income is Some(_) ||
      other_prepaid is Some(_) ||
      annual_deductions > 0L ||
      salary_prepaid is Some(_) ||
      deduction_months is Some(_)
    ) {
    fail(
      "annual_complete=true is required for annual settlement; supply all annual income and deductions",
    )
  }
  {
    year,
    inputs,
    bonus,
    explain,
    target_net,
    other_income,
    other_prepaid,
    preview_basic,
    deduction_months,
    annual_complete,
    annual_deductions,
    salary_prepaid,
  }
}

///|
/// Render a full-year payslip (Markdown) for the same wire document.
pub fn run_payslip_report(source : String) -> String raise TaxError {
  let input = parse_input(source)
  let results = cumulative_withholding(input.inputs)
  let buf = StringBuilder()
  buf.write_string("# WageKit 工资条（\{input.year}）\n")
  for r in results {
    if r.month > 1 {
      buf.write_string("\n---\n")
    }
    buf.write_string(
      render_payslip(input.year, r.month, input.inputs[r.month - 1], r, ""),
    )
  }
  buf.write_string("\n---\n\n")
  buf.write_string(render_year_summary(summarize(input.inputs, results)))
  match input.bonus {
    Some(bonus) => {
      buf.write_string("\n---\n\n")
      if input.annual_complete {
        let other_income = match input.other_income {
          Some(v) => v
          None => 0L
        }
        let choice = bonus_compare_under(
          default_rules(),
          bonus,
          input.inputs,
          other_income~,
          annual_deductions=input.annual_deductions,
        )
        buf.write_string(render_bonus_report(choice))
      } else {
        buf.write_string(
          "年终奖单独计税试算：" +
          yuan_text(bonus_standalone(bonus)) +
          " 元；全年数据未确认，不给出合并计税建议。\n",
        )
      }
    }
    None => ()
  }
  buf.to_string()
}

///|
/// Compute the full report for a wire document:
///
/// ```json
/// {"year":2026,"months":[{"gross":3000000,"social":0,"special":300000,"other":0}],"bonus":3600000}
/// ```
///
/// All amounts are integer cents. `bonus` is optional.
pub fn run_report(source : String) -> String raise TaxError {
  let input = parse_input(source)
  let year = input.year
  let inputs = input.inputs
  let results = cumulative_withholding(inputs)
  let buf = StringBuilder()
  buf.write_string("{\"ok\":true,\"rules\":\"")
  buf.write_string(RULES_VERSION)
  buf.write_string("\",\"year\":")
  buf.write_string(year.to_string())
  buf.write_string(",\"months\":[")
  for i, r in results {
    if i > 0 {
      buf.write_string(",")
    }
    buf.write_string(
      "{\"month\":\{r.month},\"taxable_cum\":\{r.taxable_cum},\"tax_cum\":\{r.tax_cum},\"withheld\":\{r.withheld}}",
    )
  }
  buf.write_string("],\"total_withheld\":\{total_withheld(results)}")
  match input.bonus {
    Some(bonus) => {
      let standalone = bonus_standalone(bonus)
      if input.annual_complete {
        let other_income = match input.other_income {
          Some(v) => v
          None => 0L
        }
        let choice = bonus_compare_under(
          default_rules(),
          bonus,
          inputs,
          other_income~,
          annual_deductions=input.annual_deductions,
        )
        buf.write_string(
          ",\"bonus\":{\"amount\":\{bonus},\"standalone_tax\":\{standalone},\"combined_extra_tax\":\{choice.combined_extra_tax},\"best\":\"\{choice.best}\"}",
        )
      } else {
        buf.write_string(
          ",\"bonus\":{\"amount\":\{bonus},\"standalone_tax\":\{standalone},\"combined_extra_tax\":null,\"best\":\"needs_annual_data\"}",
        )
      }
    }
    None => buf.write_string(",\"bonus\":null")
  }
  if input.explain {
    buf.write_string(",\"explain\":[")
    for i, e in explain_withholding(default_rules(), inputs) {
      if i > 0 {
        buf.write_string(",")
      }
      buf.write_string(
        "{\"month\":\{e.month},\"taxable_cum\":\{e.taxable_cum},\"bracket\":\{e.bracket_no},\"rate\":\{e.rate_percent},\"quick\":\{e.quick_deduction},\"tax_cum\":\{e.tax_cum},\"withheld\":\{e.withheld},\"formula\":\"\{e.formula}\"}",
      )
    }
    buf.write_string("]")
  }
  match input.target_net {
    Some(target) => {
      let profile : MonthInput = if inputs.length() > 0 {
        inputs[0]
      } else {
        { gross: 0L, social: 0L, special: 0L, other: 0L, }
      }
      let g = gross_up(target, profile.social, profile.special, profile.other)
      if g.gross > MAX_AMOUNT {
        fail("gross-up result exceeds supported amount")
      }
      buf.write_string(
        ",\"gross_up\":{\"target_net\":\{g.target_net},\"gross\":\{g.gross},\"net\":\{g.net},\"overshoot\":\{g.overshoot},\"exact\":\{g.exact}}",
      )
    }
    None => ()
  }
  // Annual results require an explicit complete-year declaration.
  if input.annual_complete {
    let other = match input.other_income {
      Some(v) => v
      None => 0L
    }
    let paid = match input.other_prepaid {
      Some(v) => v
      None => 0L
    }
    let salary_paid = match input.salary_prepaid {
      Some(v) => v
      None => total_withheld(results)
    }
    let source = if input.salary_prepaid is Some(_) {
      "provided"
    } else {
      "modeled"
    }
    let s = annual_settlement(
      inputs,
      0L,
      false,
      other,
      paid,
      salary_prepaid=salary_paid,
      annual_deductions=input.annual_deductions,
    )
    buf.write_string(
      ",\"settlement\":{\"tax_due\":\{s.tax_due},\"prepaid\":\{s.prepaid},\"refund\":\{s.refund},\"payable\":\{s.payable},\"bonus_merged\":false,\"prepaid_source\":\"\{source}\"}",
    )
  }
  // What a different monthly basic deduction would do to this payroll.
  match input.preview_basic {
    Some(basic) => {
      let baseline = default_rules()
      let candidate = {
        ..baseline,
        version: "preview",
        basic_deduction: basic,
      }
      let impact = policy_impact(baseline, candidate, inputs)
      buf.write_string(
        ",\"policy_impact\":{\"before_version\":\"\{impact.before_version}\",\"after_version\":\"\{impact.after_version}\",\"total_before\":\{impact.total_before},\"total_after\":\{impact.total_after},\"total_delta\":\{impact.total_delta},\"months\":[",
      )
      for i, m in impact.months {
        if i > 0 {
          buf.write_string(",")
        }
        buf.write_string(
          "{\"month\":\{m.month},\"before\":\{m.before},\"after\":\{m.after},\"delta\":\{m.delta}}",
        )
      }
      buf.write_string("]}")
    }
    None => ()
  }
  buf.write_string("}")
  buf.to_string()
}
