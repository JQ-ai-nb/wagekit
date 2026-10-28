///|
/// Cliffs are the point of the bonus rule, so they get a sweep rather than an
/// anecdote. The trap has two layers: the bracket is chosen by the **quotient**
/// of an integer division by 12, so the jump happens 12 fen past the edge, not
/// at the edge, and not 1 fen past it.

///|
/// Monthly-table upper bounds, in cents of monthly-converted income.
fn cliff_edges() -> Array[Int64] {
  [300_000L, 1_200_000L, 2_500_000L, 3_500_000L, 5_500_000L, 8_000_000L]
}

///|
test "one extra fen does not cross a cliff, twelve do" {
  // 36 000 yuan is inside bracket 1; 36 000.01 still is, because 36 000.01 / 12
  // floors to 3 000.00. Only 36 000.12 pushes the quotient to 3 000.01.
  assert_eq(bonus_standalone(3_600_000L), 108_000L)
  assert_eq(bonus_standalone(3_600_001L), 108_000L)
  assert_eq(bonus_standalone(3_600_012L), 339_001L)
}

///|
test "the famous cliff costs 2 309.10 yuan on one extra yuan" {
  let below = 3_600_000L
  let above = 3_600_100L
  assert_eq(bonus_standalone(below), 108_000L)
  assert_eq(bonus_standalone(above), 339_010L)
  let drop = (below - bonus_standalone(below)) -
    (above - bonus_standalone(above))
  assert_eq(drop, 230_910L)
}

///|
test "every cliff jumps at the twelfth fen past its edge" {
  for edge in cliff_edges() {
    let at_edge = edge * 12L
    let one_fen_below = at_edge + 11L
    let one_fen_over = at_edge + 12L
    let tax_edge = bonus_standalone(at_edge)
    let tax_below = bonus_standalone(one_fen_below)
    let tax_over = bonus_standalone(one_fen_over)
    // +11 fen: same bracket, so the tax moves by cents rather than thousands.
    assert_eq(tax_below >= tax_edge, true)
    assert_eq(tax_below - tax_edge < 100L, true)
    // +12 fen: the quotient crosses by one fen and the whole bonus is re-rated.
    assert_eq(tax_over - tax_edge > 100_000L, true)
    // Take-home must fall even though the bonus rose.
    assert_eq(one_fen_over - tax_over < at_edge - tax_edge, true)
  }
}

///|
test "cliff edges are exactly where the monthly table changes rate" {
  let table = monthly_table()
  for i, edge in cliff_edges() {
    // Tax at the edge must come from bracket i, and one fen more from i+1:
    // recompute both by hand from the table and compare with tax_of.
    let left = mul_percent(edge, table.rates[i]) - table.quick[i]
    let right = mul_percent(edge + 1L, table.rates[i + 1]) - table.quick[i + 1]
    assert_eq(tax_of(table, edge), left)
    assert_eq(tax_of(table, edge + 1L), right)
    // The two brackets must meet: no gap, no overlap beyond rounding.
    assert_eq(right - left <= 1L, true)
  }
}
