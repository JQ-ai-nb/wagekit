///|
/// Labor remuneration (劳务报酬) withholding, paid to non-employees.

///|
/// Withholding for one labor payment. Income at or below 800 yuan is taxed on
/// (income - 800); above that, on 80% of income. Brackets on the taxable
/// amount: 20% up to 20k yuan, 30% up to 50k yuan (quick 2000), 40% above
/// (quick 7000).
pub fn labor_withhold(gross : Int64) -> Int64 {
  if gross <= 0L {
    return 0L
  }
  let taxable = if gross <= 400_000L {
    gross - 80_000L
  } else {
    mul_percent(gross, 80)
  }
  if taxable <= 0L {
    return 0L
  }
  if taxable <= 2_000_000L {
    mul_percent(taxable, 20)
  } else if taxable <= 5_000_000L {
    mul_percent(taxable, 30) - 200_000L
  } else {
    mul_percent(taxable, 40) - 700_000L
  }
}
