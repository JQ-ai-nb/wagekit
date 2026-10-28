///|
/// Forward take-home for a single month, used to check the inverse.
fn net_of_single_month(
  gross : Int64,
  social : Int64,
  special : Int64,
  other : Int64,
) -> Int64 {
  let r = cumulative_withholding([{ gross, social, special, other, }])[0]
  gross - social - r.withheld
}

///|
test "grossing up recovers a known gross exactly" {
  let social = 300_000L
  let special = 100_000L
  let target = net_of_single_month(2_000_000L, social, special, 0L)
  assert_eq(target, 1_667_000L)
  let result = gross_up(target, social, special, 0L)
  assert_eq(result.net, target)
  assert_eq(result.exact, true)
  assert_eq(result.overshoot, 0L)
  // It must be the smallest gross that reaches the target.
  assert_eq(
    net_of_single_month(result.gross - 1L, social, special, 0L) < target,
    true,
  )
  assert_eq(result.gross <= 2_000_000L, true)
}

///|
test "a zero target needs no gross at all" {
  let result = gross_up(0L, 0L, 0L, 0L)
  assert_eq(result.gross, 0L)
  assert_eq(result.net, 0L)
  assert_eq(result.exact, true)
}

///|
test "the gross-up curve is monotone and lands on or just above the target" {
  let mut previous = -1L
  for step in 0..<40 {
    let target = 1_000_000L + step.to_int64() * 250_000L
    let result = gross_up(target, 200_000L, 150_000L, 0L)
    assert_eq(result.net >= target, true)
    assert_eq(result.overshoot <= 1L, true)
    assert_eq(result.exact, result.overshoot == 0L)
    assert_eq(result.gross >= target, true)
    assert_eq(result.gross > previous, true)
    previous = result.gross
  }
}

///|
test "grossing up a high salary stays cent-exact or one cent over" {
  // 1 000 000 yuan net: deep into the 45% bracket.
  let result = gross_up(100_000_000L, 0L, 0L, 0L)
  assert_eq(result.net >= result.target_net, true)
  assert_eq(result.overshoot <= 1L, true)
  // At a 45% marginal rate net ≈ 0.55 × gross + 184 170, so a 1 000 000 yuan
  // net offer needs roughly 1 483 000 gross — about 1.48× the take-home.
  assert_eq(result.gross > 145_000_000L, true)
}

///|
test "special deductions lower the gross needed for the same net" {
  let with_deduction = gross_up(2_000_000L, 0L, 400_000L, 0L)
  let without = gross_up(2_000_000L, 0L, 0L, 0L)
  assert_eq(with_deduction.gross < without.gross, true)
}
