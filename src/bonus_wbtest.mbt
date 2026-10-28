///|
test "bonus report renders both treatments" {
  let inputs = [{ gross: 2_000_000L, social: 0L, special: 0L, other: 0L, }]
  let text = render_bonus_report(bonus_compare(3_600_000L, inputs))
  assert_eq(text.contains("单独计税"), true)
  assert_eq(text.contains("并入综合所得"), true)
  assert_eq(text.contains("建议方式"), true)
}
