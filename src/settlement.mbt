///|
/// Annual settlement (年度汇算): reconcile the year's cumulative withholding
/// against the annual liability. Refunds and extra payments are reported
/// separately so callers never guess the sign.

///|
pub(all) struct Settlement {
  /// Annual tax due on comprehensive income (excluding a standalone bonus).
  tax_due : Int64
  /// Total actually withheld during the year.
  prepaid : Int64
  /// Positive when the taxpayer overpaid and is due a refund.
  refund : Int64
  /// Positive when the taxpayer underpaid and must pay more.
  payable : Int64
  /// Whether the bonus was merged into comprehensive income in this figure.
  bonus_merged : Bool
} derive(Eq)

///|
/// Reconcile a full year from the raw monthly components — the authoritative
/// path. `bonus_merged` decides whether the bonus is already part of the
/// monthly inputs (true) or taxed standalone outside this figure (false; the
/// standalone tax must then be settled separately and is NOT part of the
/// refund/payable calculation here).
pub fn annual_settlement(
  inputs : Array[MonthInput],
  bonus : Int64,
  bonus_merged : Bool,
  other_income : Int64,
  other_prepaid : Int64,
) -> Settlement {
  let results = cumulative_withholding(inputs)
  let prepaid = total_withheld(results) + other_prepaid
  let months = inputs.length()
  let mut comprehensive = 0L
  let mut deductions = 0L
  for input in inputs {
    comprehensive = comprehensive + input.gross
    deductions = deductions + input.social + input.special + input.other
  }
  let base_deduction = BASIC_DEDUCTION * months.to_int64()
  let merged_bonus = if bonus_merged { bonus } else { 0L }
  // Other comprehensive income (labor remuneration, royalties...) arrives
  // already reduced to its 70-80% statutory inclusion and adds here.
  let taxable = comprehensive +
    other_income +
    merged_bonus -
    base_deduction -
    deductions
  let tax_due = tax_of(annual_table(), taxable)
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
