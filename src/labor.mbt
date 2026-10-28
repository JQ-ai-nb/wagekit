///|
/// Withholding on income other than wages: labor remuneration (劳务报酬),
/// royalties (稿酬) and licensing fees (特许权使用费). All three share the
/// same expense deduction (800 yuan flat, or 80%), but differ in the rate:
/// labor uses the 20/30/40% scale, the other two a flat 20%.

///|
pub(all) enum OtherIncomeKind {
  /// 劳务报酬：三档预扣率 20/30/40%，速算扣除 0/2000/7000。
  Labor
  /// 稿酬：减除费用后按 20% 预扣。
  Royalty
  /// 特许权使用费：减除费用后按 20% 预扣。
  License
} derive(Eq)

///|
/// Expense deduction shared by the three income kinds: 800 yuan when the
/// payment is at most 4000 yuan, otherwise 20% of it. Returns the taxable
/// amount (never negative).
pub fn other_income_taxable(gross : Int64) -> Int64 {
  if gross <= 0L {
    return 0L
  }
  let taxable = if gross <= 400_000L {
    gross - 80_000L
  } else {
    mul_percent(gross, 80)
  }
  if taxable < 0L {
    0L
  } else {
    taxable
  }
}

///|
/// Withholding for one payment of the given kind.
pub fn other_income_withhold(kind : OtherIncomeKind, gross : Int64) -> Int64 {
  let taxable = other_income_taxable(gross)
  if taxable <= 0L {
    return 0L
  }
  match kind {
    Labor =>
      if taxable <= 2_000_000L {
        mul_percent(taxable, 20)
      } else if taxable <= 5_000_000L {
        mul_percent(taxable, 30) - 200_000L
      } else {
        mul_percent(taxable, 40) - 700_000L
      }
    Royalty | License => mul_percent(taxable, 20)
  }
}

///|
/// Labor remuneration withholding, kept as the historical entry point.
pub fn labor_withhold(gross : Int64) -> Int64 {
  other_income_withhold(Labor, gross)
}

///|
/// The share of the payment that enters comprehensive income at settlement:
/// all three kinds use 80% (the 20% expense deduction is statutory).
pub fn other_income_inclusion(gross : Int64) -> Int64 {
  mul_percent(gross, 80)
}
