///|
test "annual settlement refunds when labor remuneration over-withheld" {
  // One month of salary: prepaid 45 yuan at 3%.
  let inputs = [{ gross: 2_000_000L, social: 0L, special: 0L, other: 0L, }]
  // One labor payment of 10000 yuan: prepaid 1600 yuan at 20% flat.
  let labor_gross = 1_000_000L
  let labor_prepaid = labor_withhold(labor_gross)
  assert_eq(labor_prepaid, 160_000L)
  // Settlement merges 80% of the labor income into the annual base.
  let settlement = annual_settlement(
    inputs,
    0L,
    false,
    mul_percent(labor_gross, 80),
    labor_prepaid,
  )
  // Annual base: 20000 + 8000 - 6000 = 23000 yuan -> 3% -> 690 yuan due
  assert_eq(settlement.tax_due, 69_000L)
  assert_eq(settlement.prepaid, 205_000L)
  // 2050 prepaid vs 690 due: a 1360 yuan refund
  assert_eq(settlement.refund, 136_000L)
  assert_eq(settlement.payable, 0L)
}

///|
test "merged bonus raises the annual due and creates a payable" {
  let inputs = []
  for _i in 0..<12 {
    inputs.push({
      gross: 2_000_000L,
      social: 300_000L,
      special: 100_000L,
      other: 0L,
    })
  }
  let bonus = 3_600_000L
  let merged = annual_settlement(inputs, bonus, true, 0L, 0L)
  let standalone = annual_settlement(inputs, bonus, false, 0L, 0L)
  // merging the bonus raises the annual due
  assert_eq(merged.tax_due > standalone.tax_due, true)
  // the year was fully prepaid at the cumulative schedule, so the extra due
  // becomes a payable, never a refund
  assert_eq(merged.payable > 0L, true)
  assert_eq(merged.refund, 0L)
}

///|
test "standalone bonus leaves the settlement untouched" {
  let inputs = []
  for _i in 0..<12 {
    inputs.push({
      gross: 2_000_000L,
      social: 300_000L,
      special: 100_000L,
      other: 0L,
    })
  }
  let settlement = annual_settlement(inputs, 3_600_000L, false, 0L, 0L)
  // cumulative withholding equals the annual liability by construction
  assert_eq(settlement.tax_due, settlement.prepaid)
  assert_eq(settlement.refund, 0L)
  assert_eq(settlement.payable, 0L)
  assert_eq(settlement.bonus_merged, false)
}
