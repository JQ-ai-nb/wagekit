///|
/// City social-insurance and housing-fund parameters. The bundled table is
/// EXAMPLE data at realistic magnitudes: before real payroll use, replace it
/// with the current-year figures published by each city's HR bureau.

///|
pub(all) struct CityParams {
  city : String
  /// Contribution base lower bound, cents/month.
  base_lower : Int64
  /// Contribution base upper bound, cents/month.
  base_upper : Int64
  /// Pension, employee share, integer percent.
  pension_rate : Int32
  /// Medical, employee share, integer percent.
  medical_rate : Int32
  /// Unemployment, employee share, integer percent (may be 0).
  unemployment_rate : Int32
  /// Housing fund, employee share, integer percent (5..12).
  fund_rate : Int32
} derive(Eq)

///|
/// Bundled example parameters. Keys are lowercase city names.
pub fn city_params(city : String) -> CityParams? {
  match city {
    "beijing" =>
      Some({
        city: "beijing",
        base_lower: 508_000L,
        base_upper: 3_528_300L,
        pension_rate: 8,
        medical_rate: 2,
        unemployment_rate: 0,
        fund_rate: 12,
      })
    "shanghai" =>
      Some({
        city: "shanghai",
        base_lower: 738_400L,
        base_upper: 3_692_100L,
        pension_rate: 8,
        medical_rate: 2,
        unemployment_rate: 0,
        fund_rate: 7,
      })
    "shenzhen" =>
      Some({
        city: "shenzhen",
        base_lower: 352_300L,
        base_upper: 3_486_000L,
        pension_rate: 8,
        medical_rate: 2,
        unemployment_rate: 0,
        fund_rate: 5,
      })
    "guangzhou" =>
      Some({
        city: "guangzhou",
        base_lower: 460_000L,
        base_upper: 2_812_200L,
        pension_rate: 8,
        medical_rate: 2,
        unemployment_rate: 0,
        fund_rate: 5,
      })
    "hangzhou" =>
      Some({
        city: "hangzhou",
        base_lower: 446_200L,
        base_upper: 2_231_000L,
        pension_rate: 8,
        medical_rate: 2,
        unemployment_rate: 0,
        fund_rate: 12,
      })
    _ => None
  }
}

///|
/// Employee-side monthly social insurance + housing fund for a gross salary:
/// each item is computed on the clamped base and rounded to a cent, then
/// summed (practise differs from rounding only the total).
pub fn employee_social(params : CityParams, gross : Int64) -> Int64 {
  let base = clamp_cents(gross, params.base_lower, params.base_upper)
  mul_percent(base, params.pension_rate) +
  mul_percent(base, params.medical_rate) +
  mul_percent(base, params.unemployment_rate) +
  mul_percent(base, params.fund_rate)
}
