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
    Number(n, ..) => {
      let cents = n.to_int64()
      if cents.to_double() != n {
        fail("expected an integer number of cents for " + what)
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
} derive(Eq)

///|
fn parse_input(source : String) -> WireInput raise TaxError {
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
  if year < 2000 || year > 2100 {
    fail("year must be within 2000..2100")
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
  { year, inputs, bonus, explain, target_net, }
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
      let choice = bonus_compare(bonus, input.inputs)
      buf.write_string("\n---\n\n")
      buf.write_string(render_bonus_report(choice))
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
      let choice = bonus_compare(bonus, inputs)
      buf.write_string(
        ",\"bonus\":{\"amount\":\{bonus},\"standalone_tax\":\{choice.standalone_tax},\"combined_extra_tax\":\{choice.combined_extra_tax},\"best\":\"\{choice.best}\"}",
      )
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
      buf.write_string(
        ",\"gross_up\":{\"target_net\":\{g.target_net},\"gross\":\{g.gross},\"net\":\{g.net},\"overshoot\":\{g.overshoot},\"exact\":\{g.exact}}",
      )
    }
    None => ()
  }
  buf.write_string("}")
  buf.to_string()
}
