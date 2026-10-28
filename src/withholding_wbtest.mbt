///|
test "withholding is never negative and totals reconcile" {
  let inputs = []
  for i in 0..<12 {
    inputs.push({
      gross: 2_000_000L + i.to_int64() * 100_000L,
      social: 300_000L,
      special: 100_000L,
      other: 0L,
    })
  }
  let results = cumulative_withholding(inputs)
  for r in results {
    assert_eq(r.withheld >= 0L, true)
  }
  assert_eq(total_withheld(results), results[11].tax_cum)
}
