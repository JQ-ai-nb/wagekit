///|
test "city params cover the bundled cities" {
  assert_eq(city_params("beijing") is Some(_), true)
  assert_eq(city_params("shanghai") is Some(_), true)
  assert_eq(city_params("shenzhen") is Some(_), true)
  assert_eq(city_params("guangzhou") is Some(_), true)
  assert_eq(city_params("hangzhou") is Some(_), true)
  assert_eq(city_params("atlantis") is None, true)
}

///|
test "employee social clamps the base and rounds per item" {
  let params = match city_params("beijing") {
    Some(p) => p
    None => abort("beijing params missing")
  }
  // below the lower bound: the base is lifted to it
  let low = employee_social(params, 100_000L)
  let at_lower = employee_social(params, params.base_lower)
  assert_eq(low, at_lower)
  // above the upper bound: the base is capped
  let high = employee_social(params, 999_999_999L)
  let at_upper = employee_social(params, params.base_upper)
  assert_eq(high, at_upper)
  // itemised rounding: each share rounds to a cent before summing
  let base = params.base_lower
  let manual = mul_percent(base, params.pension_rate) +
    mul_percent(base, params.medical_rate) +
    mul_percent(base, params.unemployment_rate) +
    mul_percent(base, params.fund_rate)
  assert_eq(at_lower, manual)
}
