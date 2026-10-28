///|
test "summarize totals and effective rate" {
  let inputs = []
  for _i in 0..<12 {
    inputs.push({
      gross: 2_000_000L,
      social: 300_000L,
      special: 100_000L,
      other: 0L,
    })
  }
  let results = cumulative_withholding(inputs)
  let s = summarize(inputs, results)
  assert_eq(s.months, 12)
  assert_eq(s.gross_total, 24_000_000L)
  assert_eq(s.cash_deduction_total, 3_600_000L)
  assert_eq(s.tax_base_deduction_total, 1_200_000L)
  assert_eq(s.tax_total, results[11].tax_cum)
  assert_eq(s.net_total, 24_000_000L - 3_600_000L - results[11].tax_cum)
  // rate is tax / gross in basis points, rounded
  assert_eq(
    s.effective_rate_bp,
    ((results[11].tax_cum * 10_000L + 12_000_000L) / 24_000_000L).to_int(),
  )
}

///|
test "summary is consistent with the payslip stream" {
  let inputs = []
  for i in 0..<6 {
    inputs.push({
      gross: 3_000_000L + i.to_int64() * 100_000L,
      social: 300_000L,
      special: 300_000L,
      other: 0L,
    })
  }
  let results = cumulative_withholding(inputs)
  let s = summarize(inputs, results)
  let mut net_from_slips = 0L
  for i, r in results {
    net_from_slips = net_from_slips +
      inputs[i].gross -
      inputs[i].social -
      r.withheld
  }
  // cash net must reconcile exactly with the sum of the payslip lines
  assert_eq(s.net_total, net_from_slips)
  assert_eq(s.tax_total, total_withheld(results))
}

///|
test "empty year yields zeros" {
  let s = summarize([], [])
  assert_eq(s.months, 0)
  assert_eq(s.gross_total, 0L)
  assert_eq(s.effective_rate_bp, 0)
}
