///|
test "labor remuneration withholding" {
  // 10000 yuan: taxable 8000 -> 20% -> 1600
  assert_eq(labor_withhold(1_000_000L), 160_000L)
  // 3000 yuan: taxable 2200 -> 20% -> 440
  assert_eq(labor_withhold(300_000L), 44_000L)
  // 60000 yuan: taxable 48000 -> 30% - 2000 -> 12400
  assert_eq(labor_withhold(6_000_000L), 1_240_000L)
  // 700 yuan: below the 800 exemption -> zero
  assert_eq(labor_withhold(70_000L), 0L)
}
