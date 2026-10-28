///|
/// Progressive tax rate table: brackets, percentages and quick deductions.
/// All bounds and quick deductions are in cents.

///|
pub(all) struct RateTable {
  /// Upper bound of each bracket (inclusive), in cents; the last bracket is
  /// unreachable and only listed for completeness.
  upper : Array[Int64]
  /// Tax rate in integer percent, e.g. 10 means 10%.
  rates : Array[Int32]
  /// Quick deduction per bracket, in cents.
  quick : Array[Int64]
} derive(Eq)

///|
/// Annual comprehensive income table (IIT law, current edition).
/// Brackets at 36k / 144k / 300k / 420k / 660k / 960k yuan.
pub fn annual_table() -> RateTable {
  {
    upper: [
      3_600_000L,
      14_400_000L,
      30_000_000L,
      42_000_000L,
      66_000_000L,
      96_000_000L,
      922_337_203_685_477_580_7L / 100L,
    ],
    rates: [3, 10, 20, 25, 30, 35, 45],
    quick: [
      0L,
      252_000L,
      1_692_000L,
      3_192_000L,
      5_292_000L,
      8_592_000L,
      1_819_200_000L / 100L,
    ],
  }
}

///|
/// Monthly-converted table used by the standalone annual bonus rule.
/// Brackets at 3k / 12k / 25k / 35k / 55k / 80k yuan per month.
pub fn monthly_table() -> RateTable {
  {
    upper: [
      300_000L,
      1_200_000L,
      2_500_000L,
      3_500_000L,
      5_500_000L,
      8_000_000L,
      922_337_203_685_477_580_7L / 100L,
    ],
    rates: [3, 10, 20, 25, 30, 35, 45],
    quick: [0L, 21_000L, 141_000L, 266_000L, 441_000L, 716_000L, 1_516_000L],
  }
}

///|
/// Index of the bracket a taxable amount falls into. `None` means the amount
/// is not positive and no tax is due.
pub fn bracket(table : RateTable, taxable : Int64) -> Int32? {
  if taxable <= 0L {
    return None
  }
  for i, bound in table.upper {
    if taxable <= bound {
      return Some(i)
    }
  }
  None
}

///|
/// Tax for a taxable amount under a table: `taxable * rate - quick`, rounded
/// half-up to a cent. Non-positive taxable amounts yield zero tax.
pub fn tax_of(table : RateTable, taxable : Int64) -> Int64 {
  match bracket(table, taxable) {
    None => 0L
    Some(i) => mul_percent(taxable, table.rates[i]) - table.quick[i]
  }
}
