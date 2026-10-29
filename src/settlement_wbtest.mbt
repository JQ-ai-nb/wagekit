///|
test "partial employment retains the full resident annual deduction" {
  let inputs = [{ gross: 2_000_000L, social: 0L, special: 0L, other: 0L, }]
  let settlement = annual_settlement(inputs, 0L, false, 800_000L, 160_000L)
  assert_eq(settlement.tax_due, 0L)
  assert_eq(settlement.prepaid, 205_000L)
  assert_eq(settlement.refund, 205_000L)
}

///|
test "provided prepaid amounts are used without inventing a payment" {
  let inputs = [{ gross: 2_000_000L, social: 0L, special: 0L, other: 0L, }]
  let result = annual_settlement(
    inputs,
    0L,
    false,
    0L,
    0L,
    salary_prepaid=12_345L,
  )
  assert_eq(result.prepaid, 12_345L)
  assert_eq(result.refund, 12_345L)
}

///|
test "additional bonus is included once in final liability" {
  let inputs = [{ gross: 10_000_000L, social: 0L, special: 0L, other: 0L, }]
  let result = annual_settlement(inputs, 3_600_000L, true, 0L, 0L)
  // (100000 + 36000 - 60000) * 10% - 2520 = 5080
  assert_eq(result.tax_due, 508_000L)
}

///|
test "annual deductions reduce liability without lowering prior withholding" {
  let inputs = [{ gross: 10_000_000L, social: 0L, special: 0L, other: 0L, }]
  let before = annual_settlement(inputs, 0L, false, 0L, 0L)
  let after = annual_settlement(
    inputs,
    0L,
    false,
    0L,
    0L,
    annual_deductions=1_000_000L,
  )
  assert_eq(before.prepaid, after.prepaid)
  assert_eq(before.tax_due, 148_000L)
  assert_eq(after.tax_due, 90_000L)
}
