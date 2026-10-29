///|
test "report carries the rule-set version" {
  let doc = "{\"year\":2026,\"months\":[{\"gross\":1000000,\"social\":0,\"special\":0,\"other\":0}]}"
  let report = run_report(doc)
  assert_eq(report.contains("\"rules\":\"CN-resident-2026.2\""), true)
  assert_eq(report.contains("\"ok\":true"), true)
}

///|
test "wire rejects a thirteenth month" {
  let mut months = ""
  for i in 0..<13 {
    if i > 0 {
      months = months + ","
    }
    months = months +
      "{\"gross\":100000,\"social\":0,\"special\":0,\"other\":0}"
  }
  let doc = "{\"year\":2026,\"months\":[" + months + "]}"
  let rejected = try {
    let _ = run_report(doc)
    false
  } catch {
    TaxError(_) => true
  }
  assert_eq(rejected, true)
}

///|
fn rejects_report(source : String) -> Bool {
  try {
    let _ = run_report(source)
    false
  } catch {
    TaxError(_) => true
  }
}

///|
test "wire rejects misspelled and unsupported fields" {
  assert_eq(
    rejects_report("{\"year\":2026,\"months\":[],\"other_incom\":1}"),
    true,
  )
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"months\":[{\"gross\":100,\"social\":0,\"special\":0,\"other\":0,\"tax_exempt\":1}]}",
    ),
    true,
  )
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"months\":[],\"preview\":{\"basic_deducton\":1}}",
    ),
    true,
  )
}

///|
test "annual other income and its prepaid tax must be explicit together" {
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"annual_complete\":true,\"months\":[],\"other_income\":1}",
    ),
    true,
  )
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"annual_complete\":true,\"months\":[],\"other_prepaid\":1}",
    ),
    true,
  )
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"annual_complete\":true,\"months\":[],\"other_income\":0,\"other_prepaid\":0}",
    ),
    false,
  )
}

///|
test "bonus inclusion requires annual data and actual prepaid wages" {
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"months\":[],\"bonus\":3600000,\"bonus_merged\":true}",
    ),
    true,
  )
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"annual_complete\":true,\"months\":[],\"bonus\":3600000,\"bonus_merged\":true}",
    ),
    true,
  )
  assert_eq(
    rejects_report(
      "{\"year\":2026,\"annual_complete\":true,\"months\":[],\"salary_prepaid\":0,\"bonus_merged\":true}",
    ),
    true,
  )
}
