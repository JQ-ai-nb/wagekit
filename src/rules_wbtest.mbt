///|
test "withholding_under default rules matches the plain entry point" {
  let inputs = []
  for i in 0..<12 {
    inputs.push({
      gross: 2_000_000L + i.to_int64() * 300_000L,
      social: 300_000L,
      special: 100_000L,
      other: 0L,
    })
  }
  let plain = cumulative_withholding(inputs)
  let explicit = withholding_under(default_rules(), inputs)
  for i, r in plain {
    assert_eq(explicit[i].tax_cum, r.tax_cum)
    assert_eq(explicit[i].withheld, r.withheld)
  }
}

///|
test "a rule set compared with itself reports no change" {
  let inputs = [
    { gross: 3_000_000L, social: 0L, special: 300_000L, other: 0L, },
    { gross: 3_000_000L, social: 0L, special: 300_000L, other: 0L, },
  ]
  let impact = policy_impact(default_rules(), default_rules(), inputs)
  assert_eq(impact.total_delta, 0L)
  for m in impact.months {
    assert_eq(m.delta, 0L)
  }
}

///|
test "raising the basic deduction lowers the annual tax" {
  let inputs = []
  for _i in 0..<12 {
    inputs.push({ gross: 3_000_000L, social: 0L, special: 300_000L, other: 0L, })
  }
  let baseline = default_rules()
  // A hypothetical edition with a 6 000 yuan monthly deduction: the shape of
  // the policy changes, no code does.
  let candidate = {
    ..baseline,
    version: "2027.test",
    basic_deduction: 600_000L,
  }
  let impact = policy_impact(baseline, candidate, inputs)
  assert_eq(impact.before_version, RULES_VERSION)
  assert_eq(impact.after_version, "2027.test")
  assert_eq(impact.total_delta < 0L, true)
  // The per-month deltas must add up to the total, or the report lies.
  let mut sum = 0L
  for m in impact.months {
    sum = sum + m.delta
  }
  assert_eq(sum, impact.total_delta)
  assert_eq(impact.total_after, impact.total_before + impact.total_delta)
}

///|
test "a first-bracket rate cut shifts timing but not this year's total" {
  let inputs = []
  for _i in 0..<3 {
    inputs.push({ gross: 3_000_000L, social: 0L, special: 300_000L, other: 0L, })
  }
  let baseline = default_rules()
  // Same brackets, cheaper first rate: an unambiguous, easy-to-check change.
  let candidate = {
    ..baseline,
    annual: {
      upper: baseline.annual.upper,
      rates: [2, 10, 20, 25, 30, 35, 45],
      quick: baseline.annual.quick,
    },
  }
  let impact = policy_impact(baseline, candidate, inputs)
  // Month 1: 22 000 taxable at 2% instead of 3% -> 440 instead of 660.
  assert_eq(impact.months[0].before, 66_000L)
  assert_eq(impact.months[0].after, 44_000L)
  assert_eq(impact.months[0].delta, -22_000L)
  // Month 2: the cumulative method claws the 220 back, because the running
  // total is still in the 10% bracket. This is the state machine working.
  assert_eq(impact.months[1].delta, 22_000L)
  // Month 3 onward is untouched, and the year lands on the same total.
  assert_eq(impact.months[2].delta, 0L)
  assert_eq(impact.total_delta, 0L)
}
