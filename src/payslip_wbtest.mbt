///|
test "payslip renders the legal items" {
  let input : MonthInput = {
    gross: 3_000_000L,
    social: 300_000L,
    special: 300_000L,
    other: 0L,
  }
  let result = cumulative_withholding([input])[0]
  let text = render_payslip(2026, 1, input, result, "测试备注")
  assert_eq(text.contains("应发工资"), true)
  assert_eq(text.contains("本月预扣个税"), true)
  assert_eq(text.contains("实发"), true)
  assert_eq(text.contains("测试备注"), true)
}

///|
test "negative net pay raises an explicit warning" {
  let input : MonthInput = {
    gross: 100_000L,
    social: 200_000L,
    special: 0L,
    other: 0L,
  }
  let result = cumulative_withholding([input])[0]
  let text = render_payslip(2026, 1, input, result, "")
  assert_eq(text.contains("警告：实发为负"), true)
}
