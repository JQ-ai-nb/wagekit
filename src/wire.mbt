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
  {
    gross: j_cents(required(fields, "gross"), "gross"),
    social: j_cents(required(fields, "social"), "social"),
    special: j_cents(required(fields, "special"), "special"),
    other: j_cents(required(fields, "other"), "other"),
  }
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
  let inputs = j_array(required(fields, "months"), "months").map(read_month)
  let results = cumulative_withholding(inputs)
  let buf = StringBuilder()
  buf.write_string("{\"ok\":true,\"year\":")
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
  match fields.get("bonus") {
    Some(value) => {
      let bonus = j_cents(value, "bonus")
      let choice = bonus_compare(bonus, inputs)
      buf.write_string(
        ",\"bonus\":{\"amount\":\{bonus},\"standalone_tax\":\{choice.standalone_tax},\"combined_extra_tax\":\{choice.combined_extra_tax},\"best\":\"\{choice.best}\"}",
      )
    }
    None => buf.write_string(",\"bonus\":null")
  }
  buf.write_string("}")
  buf.to_string()
}
