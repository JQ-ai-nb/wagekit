///|
/// A policy table must be ordered and continuous at each boundary. Arbitrary
/// rates with unchanged quick deductions can create a bogus tax cliff.
pub fn validate_rules(rules : RuleSet) -> Unit raise TaxError {
  if rules.version == "" ||
    rules.basic_deduction < 0L ||
    rules.basic_deduction > MAX_AMOUNT {
    fail("invalid rule version or basic deduction")
  }
  for table in [rules.annual, rules.monthly] {
    let n = table.upper.length()
    if n == 0 ||
      n > 32 ||
      table.rates.length() != n ||
      table.quick.length() != n {
      fail("rate table arrays must have equal nonzero lengths")
    }
    if table.quick[0] != 0L {
      fail("first quick deduction must be zero")
    }
    for i in 0..<n {
      if table.rates[i] < 0 ||
        table.rates[i] >= 100 ||
        table.quick[i] < 0L ||
        table.quick[i] > MAX_AMOUNT ||
        table.upper[i] <= 0L {
        fail("invalid rate table value")
      }
      if i > 0 {
        if table.upper[i] <= table.upper[i - 1] ||
          table.rates[i] < table.rates[i - 1] {
          fail("rate table must be ordered")
        }
        let bound = table.upper[i - 1]
        if bound > MAX_AMOUNT {
          fail("finite rate boundary is out of range")
        }
        let left = mul_percent(bound, table.rates[i - 1]) - table.quick[i - 1]
        let right = mul_percent(bound, table.rates[i]) - table.quick[i]
        if left != right {
          fail(
            "rate table is discontinuous: update quick deductions with rates",
          )
        }
      }
    }
  }
}
