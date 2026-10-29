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

///|
test "the annual table never jumps by more than a fen at an edge" {
  // A wrong quick-deduction shows up here and nowhere else: the bracket would
  // either gap (tax falls) or overlap (tax leaps) at the boundary.
  for
    edge in [
      3_600_000L, 14_400_000L, 30_000_000L, 42_000_000L, 66_000_000L, 96_000_000L,
    ] {
    let below = tax_of(annual_table(), edge - 1L)
    let at = tax_of(annual_table(), edge)
    let over = tax_of(annual_table(), edge + 1L)
    assert_eq(below <= at, true)
    assert_eq(at <= over, true)
    assert_eq(at - below <= 1L, true)
    assert_eq(over - at <= 1L, true)
  }
}

///|
test "an amount above the last sentinel still uses the top bracket" {
  // The sentinel in `upper` is Int64::max/100, so an income above it used to
  // fall out of the table and be taxed at zero - a silent wrong answer.
  let table = annual_table()
  assert_eq(bracket(table, 900_000_000_000_000_000L), Some(6))
  let taxable = 100_000_000_000L
  assert_eq(tax_of(table, taxable), mul_percent(taxable, 45) - 18_192_000L)
}
