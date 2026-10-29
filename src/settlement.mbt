///|
pub(all) struct Settlement {
  tax_due : Int64
  prepaid : Int64
  refund : Int64
  payable : Int64
  bonus_merged : Bool
} derive(Eq)

///|
/// Resident annual liability. Other income is already reduced to statutory
/// inclusion. Annual deductions exclude amounts already deducted in months.
fn annual_liability(
  rules : RuleSet,
  inputs : Array[MonthInput],
  merged_bonus : Int64,
  other_income : Int64,
  annual_deductions : Int64,
) -> Int64 {
  let mut taxable = other_income +
    merged_bonus -
    rules.basic_deduction * 12L -
    annual_deductions
  for input in inputs {
    taxable = taxable + input.gross - input.social - input.special - input.other
  }
  tax_of(rules.annual, taxable)
}

///|
/// Bonus is additional to input wages, included once if bonus_merged.
/// Supply salary_prepaid for actual reconciliation; otherwise paid tax is a
/// model estimate. Annual resident deduction always covers twelve months.
pub fn annual_settlement_under(
  rules : RuleSet,
  inputs : Array[MonthInput],
  bonus : Int64,
  bonus_merged : Bool,
  other_income : Int64,
  other_prepaid : Int64,
  salary_prepaid? : Int64,
  annual_deductions~ : Int64 = 0L,
) -> Settlement {
  let prepaid = (match salary_prepaid {
      Some(paid) => paid
      None => total_withheld(withholding_under(rules, inputs))
    }) +
    other_prepaid
  let tax_due = annual_liability(
    rules,
    inputs,
    if bonus_merged {
      bonus
    } else {
      0L
    },
    other_income,
    annual_deductions,
  )
  let diff = prepaid - tax_due
  {
    tax_due,
    prepaid,
    refund: if diff > 0L {
      diff
    } else {
      0L
    },
    payable: if diff < 0L {
      -diff
    } else {
      0L
    },
    bonus_merged,
  }
}

///|
pub fn annual_settlement(
  inputs : Array[MonthInput],
  bonus : Int64,
  bonus_merged : Bool,
  other_income : Int64,
  other_prepaid : Int64,
  salary_prepaid? : Int64,
  annual_deductions~ : Int64 = 0L,
) -> Settlement {
  match salary_prepaid {
    Some(paid) =>
      annual_settlement_under(
        default_rules(),
        inputs,
        bonus,
        bonus_merged,
        other_income,
        other_prepaid,
        salary_prepaid=paid,
        annual_deductions~,
      )
    None =>
      annual_settlement_under(
        default_rules(),
        inputs,
        bonus,
        bonus_merged,
        other_income,
        other_prepaid,
        annual_deductions~,
      )
  }
}
