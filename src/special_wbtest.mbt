///|
/// Run a validating call and report whether it completed without a TaxError.
fn runs_clean(f : () -> Unit raise TaxError) -> Bool {
  let mut ok = true
  f() catch {
    TaxError(_) => ok = false
  }
  ok
}

///|
test "validate rejects loan and rent together" {
  let sd : SpecialDeductions = {
    children_education: 1,
    infants: 0,
    housing_loan: true,
    housing_rent: 110_000L,
    elder_support: 0L,
    continuing_education: 0L,
    major_medical_monthly: 0L,
  }
  assert_eq(runs_clean(() => validate(sd, 0L)), false)
}

///|
test "validate accepts rent alone and checks caps" {
  let sd : SpecialDeductions = {
    children_education: 2,
    infants: 1,
    housing_loan: false,
    housing_rent: 150_000L,
    elder_support: 300_000L,
    continuing_education: 40_000L,
    major_medical_monthly: 0L,
  }
  assert_eq(runs_clean(() => validate(sd, 8_000_000L)), true)
  assert_eq(runs_clean(() => validate(sd, 8_000_001L)), false)
}

///|
test "monthly total sums every itemised row" {
  let sd : SpecialDeductions = {
    children_education: 2,
    infants: 1,
    housing_loan: true,
    housing_rent: 0L,
    elder_support: 300_000L,
    continuing_education: 40_000L,
    major_medical_monthly: 0L,
  }
  // 2*2000 + 2000 + 1000 + 3000 + 400 = 10400 yuan
  assert_eq(monthly_total(sd), 1_040_000L)
}
