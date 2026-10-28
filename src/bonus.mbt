///|
/// Annual one-time bonus (全年一次性奖金). Two legal treatments exist and the
/// taxpayer may choose the cheaper one; the standalone path famously has
/// cliff edges where one extra yuan of bonus costs thousands in tax.

///|
/// Standalone taxation: divide the bonus by 12, look the quotient up in the
/// monthly-converted table, then tax the *whole* bonus at that bracket.
pub fn bonus_standalone(bonus : Int64) -> Int64 {
  if bonus <= 0L {
    return 0L
  }
  let table = monthly_table()
  let per_month = bonus / 12L
  match bracket(table, per_month) {
    None => 0L
    Some(i) => mul_percent(bonus, table.rates[i]) - table.quick[i]
  }
}

///|
/// Net (after-tax) amount of the standalone treatment.
pub fn bonus_net(bonus : Int64) -> Int64 {
  bonus - bonus_standalone(bonus)
}

///|
/// Result of comparing both legal treatments for one bonus.
pub(all) struct BonusChoice {
  /// Tax when the bonus is taxed standalone.
  standalone_tax : Int64
  /// *Extra* tax when the bonus is merged into comprehensive income, compared
  /// with the same year without the bonus.
  combined_extra_tax : Int64
  /// "standalone" or "combined", whichever is cheaper (ties -> standalone).
  best : String
} derive(Eq)

///|
/// Compare standalone vs merged treatment. `inputs` are the monthly salary
/// entries of the whole year; the bonus is merged into the last month.
pub fn bonus_compare(bonus : Int64, inputs : Array[MonthInput]) -> BonusChoice {
  let standalone = bonus_standalone(bonus)
  let without = cumulative_withholding(inputs)
  let merged_inputs : Array[MonthInput] = match inputs.last() {
    Some(last) => {
      let copy = inputs.copy()
      copy[copy.length() - 1] = { ..last, gross: last.gross + bonus, }
      copy
    }
    None => [{ gross: bonus, social: 0L, special: 0L, other: 0L, }]
  }
  let with_results = cumulative_withholding(merged_inputs)
  let combined_extra = total_withheld(with_results) - total_withheld(without)
  let best = if standalone <= combined_extra {
    "standalone"
  } else {
    "combined"
  }
  { standalone_tax: standalone, combined_extra_tax: combined_extra, best, }
}
