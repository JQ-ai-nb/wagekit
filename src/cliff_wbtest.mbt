///|
/// Independent fixed expected amounts at the first cliff.
test "one fen above a bonus edge already changes the rate" {
  assert_eq(bonus_standalone(3_600_000L), 108_000L)
  assert_eq(bonus_standalone(3_600_001L), 339_000L)
  assert_eq(bonus_standalone(3_600_011L), 339_001L)
  assert_eq(bonus_standalone(3_600_012L), 339_001L)
  assert_eq(bonus_standalone(3_600_100L), 339_010L)
}

///|
test "all six bonus boundaries are compared without division" {
  let edges = [
    3_600_000L, 14_400_000L, 30_000_000L, 42_000_000L, 66_000_000L, 96_000_000L,
  ]
  let taxes = [
    108_000L, 1_419_000L, 5_859_000L, 10_234_000L, 19_359_000L, 32_884_000L,
  ]
  let over = [
    339_000L, 2_739_000L, 7_234_000L, 12_159_000L, 22_384_000L, 41_684_000L,
  ]
  for i, edge in edges {
    assert_eq(bonus_standalone(edge), taxes[i])
    assert_eq(bonus_standalone(edge + 1L), over[i])
    assert_eq(bonus_net(edge + 1L) < bonus_net(edge), true)
  }
}

///|
test "complete resident annual data can reverse an in-year bonus choice" {
  let inputs = [{ gross: 2_000_000L, social: 0L, special: 0L, other: 0L, }]
  let result = bonus_compare(3_600_000L, inputs)
  assert_eq(result.standalone_tax, 108_000L)
  assert_eq(result.combined_extra_tax, 0L)
  assert_eq(result.best, "combined")
}
