///|
test "month one decomposes into bracket, rate and quick deduction" {
  let inputs = [
    { gross: 3_000_000L, social: 0L, special: 300_000L, other: 0L, },
  ]
  let e = explain_withholding(default_rules(), inputs)[0]
  assert_eq(e.taxable_cum, 2_200_000L)
  assert_eq(e.bracket_no, 1)
  assert_eq(e.rate_percent, 3)
  assert_eq(e.quick_deduction, 0L)
  assert_eq(e.tax_cum, 66_000L)
  assert_eq(e.formula, "22000.00 × 3% − 0.00 = 660.00")
}

///|
test "the third month shows the bracket jump in the formula" {
  let inputs = []
  for _i in 0..<3 {
    inputs.push({ gross: 3_000_000L, social: 0L, special: 300_000L, other: 0L, })
  }
  let third = explain_withholding(default_rules(), inputs)[2]
  assert_eq(third.taxable_cum, 6_600_000L)
  assert_eq(third.bracket_no, 2)
  assert_eq(third.rate_percent, 10)
  assert_eq(third.quick_deduction, 252_000L)
  assert_eq(third.tax_cum, 408_000L)
  assert_eq(third.withheld, 220_000L)
  assert_eq(third.formula, "66000.00 × 10% − 2520.00 = 4080.00")
}

///|
test "explanation agrees with the schedule it describes" {
  let inputs = []
  for i in 0..<12 {
    inputs.push({
      gross: 2_500_000L + i.to_int64() * 250_000L,
      social: 250_000L,
      special: 100_000L,
      other: 0L,
    })
  }
  let rules = default_rules()
  let schedule = withholding_under(rules, inputs)
  for i, e in explain_withholding(rules, inputs) {
    assert_eq(e.tax_cum, schedule[i].tax_cum)
    assert_eq(e.withheld, schedule[i].withheld)
    assert_eq(e.taxable_cum, schedule[i].taxable_cum)
  }
}

///|
test "a month below the threshold explains itself as zero, not as a bracket" {
  let inputs = [{ gross: 500_000L, social: 0L, special: 0L, other: 0L, }]
  let e = explain_withholding(default_rules(), inputs)[0]
  assert_eq(e.taxable_cum, 0L)
  assert_eq(e.bracket_no, 0)
  assert_eq(e.rate_percent, 0)
  assert_eq(e.tax_cum, 0L)
}
