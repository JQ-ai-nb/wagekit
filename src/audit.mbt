///|
/// One independently reconciled employment history, in chronological order.
pub(all) struct PayrollLedger {
  employee_id : String
  inputs : Array[MonthInput]
  actual_withheld : Array[Int64]
} derive(Eq)

///|
pub(all) struct AuditRow {
  employee_id : String
  period : Int32
  tax_cum : Int64
  paid_before : Int64
  expected : Int64
  actual : Int64
  delta : Int64
  matched : Bool
} derive(Eq)

///|
pub(all) struct AuditReport {
  rows : Array[AuditRow]
  checked : Int32
  differences : Int32
  passed : Bool
} derive(Eq)

///|
/// Validate public core inputs before calculation. Signed money arithmetic is
/// bounded here so hostile input cannot overflow the internal Int64 sums.
pub fn validate_months(inputs : Array[MonthInput]) -> Unit raise TaxError {
  if inputs.length() > 12 {
    fail("a tax year has at most 12 months")
  }
  for input in inputs {
    for value in [input.gross, input.social, input.special, input.other] {
      if value < 0L || value > MAX_AMOUNT {
        fail("month amount is out of range")
      }
    }
  }
}

///|
/// Reconcile against the actual prior paid tax, not a fictitious corrected
/// ledger. This avoids reporting a legitimate later catch-up as another error.
pub fn reconcile(
  rules : RuleSet,
  ledgers : Array[PayrollLedger],
  tolerance~ : Int64 = 0L,
) -> AuditReport raise TaxError {
  validate_rules(rules)
  if tolerance < 0L || tolerance > MAX_AMOUNT {
    fail("invalid audit tolerance")
  }
  if ledgers.length() == 0 || ledgers.length() > 1000 {
    fail("audit needs 1..1000 employees")
  }
  let seen : Map[String, Bool] = Map([])
  let rows = []
  let mut differences = 0
  for ledger in ledgers {
    if ledger.employee_id == "" || ledger.employee_id.length() > 128 {
      fail("invalid employee id")
    }
    if seen.contains(ledger.employee_id) {
      fail("duplicate employee id")
    }
    seen[ledger.employee_id] = true
    validate_months(ledger.inputs)
    if ledger.inputs.length() == 0 ||
      ledger.actual_withheld.length() != ledger.inputs.length() {
      fail(
        "each employee needs 1..12 matching input and actual withholding entries",
      )
    }
    let schedule = withholding_under(rules, ledger.inputs)
    let mut paid = 0L
    for i, period in schedule {
      let actual = ledger.actual_withheld[i]
      if actual < 0L || actual > MAX_AMOUNT {
        fail("actual withholding is out of range")
      }
      let due = period.tax_cum - paid
      let expected = if due > 0L { due } else { 0L }
      let delta = actual - expected
      let matched = delta <= tolerance && delta >= -tolerance
      if !matched {
        differences = differences + 1
      }
      rows.push({
        employee_id: ledger.employee_id,
        period: i + 1,
        tax_cum: period.tax_cum,
        paid_before: paid,
        expected,
        actual,
        delta,
        matched,
      })
      paid = paid + actual
    }
  }
  { rows, checked: rows.length(), differences, passed: differences == 0, }
}

///|
fn audit_json(report : AuditReport, rules : RuleSet) -> String {
  let buf = StringBuilder()
  buf.write_string(
    "{\"ok\":true,\"rules\":" + Json::string(rules.version).stringify(),
  )
  buf.write_string(
    ",\"passed\":\{report.passed},\"checked\":\{report.checked},\"differences\":\{report.differences},\"rows\":[",
  )
  for i, row in report.rows {
    if i > 0 {
      buf.write_string(",")
    }
    let code = if row.matched { "MATCH" } else { "WITHHOLDING_DIFFERENCE" }
    buf.write_string(
      "{\"employee_id\":" + Json::string(row.employee_id).stringify(),
    )
    buf.write_string(
      ",\"period\":\{row.period},\"tax_cum\":\{row.tax_cum},\"paid_before\":\{row.paid_before},\"expected\":\{row.expected},\"actual\":\{row.actual},\"delta\":\{row.delta},\"matched\":\{row.matched},\"code\":\"\{code}\"}",
    )
  }
  buf.write_string("]}")
  buf.to_string()
}

///|
/// Public JSON facade for CSV adapters and browser clients.
pub fn run_audit_report(source : String) -> String raise TaxError {
  if source.length() > 8_000_000 {
    fail("JSON input is too large")
  }
  let doc = @json.parse(
    source,
    max_nesting_depth=16,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    _ => fail("input is not valid JSON")
  }
  let fields = j_obj(doc, "audit input")
  let year = j_int(required(fields, "year"), "year")
  if year != 2026 {
    fail("only year 2026 is supported by the bundled rules")
  }
  let people = j_array(required(fields, "employees"), "employees")
  let ledgers = people.map(value => {
    let fields = j_obj(value, "employee")
    let id = match required(fields, "employee_id") {
      String(s) => s
      _ => fail("employee_id must be a string")
    }
    let inputs = j_array(required(fields, "months"), "months").map(read_month)
    let actual = j_array(required(fields, "actual_withheld"), "actual_withheld").map(v => {
        j_cents(v, "actual_withheld")
      },
    )
    { employee_id: id, inputs, actual_withheld: actual, }
  })
  let tolerance = match opt_cents(fields, "tolerance") {
    Some(v) => v
    None => 0L
  }
  let rules = default_rules()
  audit_json(reconcile(rules, ledgers, tolerance~), rules)
}
