///|
/// Compare bonus <= monthly_upper * 12 without truncating the quotient.
pub fn bonus_standalone_under(rules : RuleSet, bonus : Int64) -> Int64 {
  if bonus <= 0L {
    return 0L
  }
  let table = rules.monthly
  let last = table.upper.length() - 1
  for i, upper in table.upper {
    if i == last || bonus <= upper * 12L {
      return mul_percent(bonus, table.rates[i]) - table.quick[i]
    }
  }
  0L
}

///|
pub fn bonus_standalone(bonus : Int64) -> Int64 {
  bonus_standalone_under(default_rules(), bonus)
}

///|
pub fn bonus_net(bonus : Int64) -> Int64 {
  bonus - bonus_standalone(bonus)
}

///|
pub(all) struct BonusChoice {
  standalone_tax : Int64
  combined_extra_tax : Int64
  /// Comparison of final annual liabilities, not in-year withholding.
  best : String
} derive(Eq)

///|
/// Caller supplies complete annual income and deductions. Omitted employment
/// months contribute zero income; annual resident deduction covers 12 months.
pub fn bonus_compare_under(
  rules : RuleSet,
  bonus : Int64,
  inputs : Array[MonthInput],
  other_income~ : Int64 = 0L,
  annual_deductions~ : Int64 = 0L,
) -> BonusChoice {
  let standalone = bonus_standalone_under(rules, bonus)
  let without = annual_liability(
    rules, inputs, 0L, other_income, annual_deductions,
  )
  let merged = annual_liability(
    rules, inputs, bonus, other_income, annual_deductions,
  )
  let extra = merged - without
  {
    standalone_tax: standalone,
    combined_extra_tax: extra,
    best: if standalone <= extra {
      "standalone"
    } else {
      "combined"
    },
  }
}

///|
pub fn bonus_compare(bonus : Int64, inputs : Array[MonthInput]) -> BonusChoice {
  bonus_compare_under(default_rules(), bonus, inputs)
}
