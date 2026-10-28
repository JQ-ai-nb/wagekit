///|
test "mul_percent rounds half-up to a cent" {
  // 12345 cents * 3% = 370.35 cents -> 370
  assert_eq(mul_percent(12345L, 3), 370L)
  // 5 cents * 3% = 0.15 -> 0
  assert_eq(mul_percent(5L, 3), 0L)
  // 17 cents * 3% = 0.51 -> 1
  assert_eq(mul_percent(17L, 3), 1L)
}

///|
test "yuan_text renders two decimals" {
  assert_eq(yuan_text(123456L), "1234.56")
  assert_eq(yuan_text(5L), "0.05")
  assert_eq(yuan_text(-42L), "-0.42")
  assert_eq(yuan_text(0L), "0.00")
}
