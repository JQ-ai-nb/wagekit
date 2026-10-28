///|
test "labor uses the progressive withholding scale" {
  // 10000 yuan: taxable 8000 -> 20%
  assert_eq(other_income_withhold(Labor, 1_000_000L), 160_000L)
  // 3000 yuan: taxable 2200 -> 20%
  assert_eq(other_income_withhold(Labor, 300_000L), 44_000L)
  // 60000 yuan: taxable 48000 -> 30% - 2000 -> 12400
  assert_eq(other_income_withhold(Labor, 6_000_000L), 1_240_000L)
  // 700 yuan: below the 800 exemption
  assert_eq(other_income_withhold(Labor, 70_000L), 0L)
}

///|
test "royalty and license use a flat 20 percent" {
  // 10000 yuan: taxable 8000 -> 1600 either way
  assert_eq(other_income_withhold(Royalty, 1_000_000L), 160_000L)
  assert_eq(other_income_withhold(License, 1_000_000L), 160_000L)
  // 60000 yuan: taxable 48000 -> flat 20% = 9600 (labor would pay 12400)
  assert_eq(other_income_withhold(Royalty, 6_000_000L), 960_000L)
  assert_eq(other_income_withhold(License, 6_000_000L), 960_000L)
  assert_eq(
    other_income_withhold(Labor, 6_000_000L) >
    other_income_withhold(Royalty, 6_000_000L),
    true,
  )
}

///|
test "shared expense deduction and inclusion share" {
  assert_eq(other_income_taxable(400_000L), 320_000L)
  assert_eq(other_income_taxable(400_001L), 320_001L)
  assert_eq(other_income_taxable(80_000L), 0L)
  assert_eq(other_income_taxable(50_000L), 0L)
  // all three kinds enter comprehensive income at 80%
  assert_eq(other_income_inclusion(1_000_000L), 800_000L)
}
