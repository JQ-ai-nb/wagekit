///|
fn ledger(gross : Array[Int64], paid : Array[Int64]) -> PayrollLedger {
  {
    employee_id: "E001",
    inputs: gross.map(g => { gross: g, social: 0L, special: 0L, other: 0L, }),
    actual_withheld: paid,
  }
}

///|
test "falling liability does not erase credit when wages recover" {
  let inputs = ledger([1_500_000L, 0L, 1_500_000L], [30_000L, 0L, 15_000L]).inputs
  let schedule = cumulative_withholding(inputs)
  assert_eq(schedule.map(r => r.withheld), [30_000L, 0L, 15_000L])
  assert_eq(total_withheld(schedule), 45_000L)
}

///|
test "audit finds an actual 150 yuan excess with prior payment evidence" {
  let report = reconcile(default_rules(), [
    ledger([1_500_000L, 0L, 1_500_000L], [30_000L, 0L, 30_000L]),
  ])
  assert_eq(report.passed, false)
  assert_eq(report.differences, 1)
  assert_eq(report.rows[2].paid_before, 30_000L)
  assert_eq(report.rows[2].expected, 15_000L)
  assert_eq(report.rows[2].delta, 15_000L)
}

///|
test "a legitimate catch-up is compared against actual prior payments" {
  let report = reconcile(default_rules(), [
    ledger([1_500_000L, 0L, 1_500_000L], [15_000L, 0L, 30_000L]),
  ])
  assert_eq(report.differences, 1)
  assert_eq(report.rows[2].matched, true)
}

///|
test "audit tolerance is explicit and inclusive" {
  let row = ledger([1_500_000L], [30_001L])
  assert_eq(reconcile(default_rules(), [row]).passed, false)
  assert_eq(reconcile(default_rules(), [row], tolerance=1L).passed, true)
}

///|
test "duplicate employees and misaligned histories are rejected" {
  let row = ledger([1_500_000L], [30_000L])
  assert_eq(
    runs_clean(() => {
      let _ = reconcile(default_rules(), [row, row])
    }),
    false,
  )
  assert_eq(
    runs_clean(() => {
      let _ = reconcile(default_rules(), [ledger([1_500_000L], [])])
    }),
    false,
  )
}

///|
test "malformed or discontinuous policy tables are rejected" {
  let rules = default_rules()
  validate_rules(rules)
  let bad = {
    ..rules,
    annual: { ..rules.annual, rates: [2, 10, 20, 25, 30, 35, 45], },
  }
  assert_eq(runs_clean(() => validate_rules(bad)), false)
}

///|
test "both bonus and annual liability honor injected rules" {
  let base = default_rules()
  let no_tax = { upper: [1_000_000_000_000L], rates: [0], quick: [0L], }
  let rules = {
    ..base,
    version: "hypothetical-zero",
    annual: no_tax,
    monthly: no_tax,
  }
  validate_rules(rules)
  assert_eq(bonus_standalone_under(rules, 10_000_000L), 0L)
  let input = ledger([10_000_000L], [0L]).inputs
  assert_eq(
    annual_settlement_under(rules, input, 0L, false, 0L, 0L).tax_due,
    0L,
  )
}

///|
test "fractional contribution rates and independent bases are supported" {
  let item : Contribution = {
    base_lower: 0L,
    base_upper: 2_000_000L,
    rate_bp: 50,
    fixed: 300L,
  }
  assert_eq(contribution(item, 1_000_000L), 5_300L)
  assert_eq(contribution(item, 3_000_000L), 10_300L)
}

///|
test "medical deduction applies annually after the threshold and cap" {
  assert_eq(medical_annual_deduction(1_000_000L), 0L)
  assert_eq(medical_annual_deduction(2_500_000L), 1_000_000L)
  assert_eq(medical_annual_deduction(10_000_000L), 8_000_000L)
}
