///|
test "report carries the rule-set version" {
  let doc = "{\"year\":2026,\"months\":[{\"gross\":1000000,\"social\":0,\"special\":0,\"other\":0}]}"
  let report = run_report(doc)
  assert_eq(report.contains("\"rules\":\"2026.1\""), true)
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
