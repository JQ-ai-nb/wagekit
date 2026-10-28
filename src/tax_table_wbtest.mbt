///|
test "annual table brackets at 36000 yuan" {
  // exactly 36000 yuan: 3% -> 1080 yuan
  assert_eq(tax_of(annual_table(), 3_600_000L), 108_000L)
  // 36000.01 yuan: 10% gives 3600.001 yuan, rounded to a fen -> 3600.00;
  // minus the quick deduction 2520 -> still 1080.00 yuan
  assert_eq(tax_of(annual_table(), 3_600_001L), 108_000L)
  // 144000 yuan: 10% -> 14160? no: 1440000-252000 = 1188000 cents = 11880 yuan
  assert_eq(tax_of(annual_table(), 14_400_000L), 1_188_000L)
  // negative / zero taxable: no tax
  assert_eq(tax_of(annual_table(), 0L), 0L)
  assert_eq(tax_of(annual_table(), -100L), 0L)
}
