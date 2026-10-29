///|
/// Itemised special extra deductions (专项附加扣除), monthly amounts in cents.
/// Standards follow the current State Council cycle; every cap is checked, and
/// housing loan vs housing rent are mutually exclusive by law.

///|
pub(all) struct SpecialDeductions {
  /// Number of children in full-time education (2000 yuan/month each).
  children_education : Int32
  /// Number of infants under 3 (2000 yuan/month each).
  infants : Int32
  /// First-home mortgage interest: 1000 yuan/month, exclusive with rent.
  housing_loan : Bool
  /// Housing rent tier in cents per month: 0 / 80000 / 110000 / 150000.
  housing_rent : Int64
  /// Elderly support amount claimed by this taxpayer (cap 3000 yuan/month).
  elder_support : Int64
  /// Academic continuing education, at most 400 yuan/month.
  /// Vocational qualification deductions belong in annual_deductions.
  continuing_education : Int64
  /// Reserved for 0.1 compatibility; must be zero. Major medical is annual-only.
  major_medical_monthly : Int64
} derive(Eq)

///|
pub const CHILD_EDU_MONTHLY : Int64 = 200_000L

///|
pub const INFANT_MONTHLY : Int64 = 200_000L

///|
pub const LOAN_MONTHLY : Int64 = 100_000L

///|
pub const ELDER_CAP : Int64 = 300_000L

///|
pub const CONTINUING_CAP : Int64 = 40_000L

///|
pub const MAJOR_MEDICAL_YEAR_CAP : Int64 = 8_000_000L

///|
/// Validate mutual-exclusion and per-item caps. `major_medical_annual` is the
/// yearly excess the monthly share was derived from.
pub fn validate(
  sd : SpecialDeductions,
  major_medical_annual : Int64,
  only_child~ : Bool = true,
) -> Unit raise TaxError {
  if sd.children_education < 0 ||
    sd.infants < 0 ||
    sd.elder_support < 0L ||
    sd.continuing_education < 0L ||
    major_medical_annual < 0L {
    fail("deductions must be non-negative")
  }
  if sd.major_medical_monthly != 0L {
    fail("major medical is annual-only; pass annual_deductions at settlement")
  }
  if !only_child && sd.elder_support > ELDER_CAP / 2L {
    fail("non-only child elderly support exceeds 1500 yuan monthly cap")
  }
  if sd.housing_loan && sd.housing_rent != 0L {
    fail("housing loan and housing rent are mutually exclusive")
  }
  match sd.housing_rent {
    0L | 80_000L | 110_000L | 150_000L => ()
    _ =>
      fail("housing rent must be one of 0 / 800 / 1100 / 1500 yuan per month")
  }
  if sd.elder_support > ELDER_CAP {
    fail("elderly support exceeds the 3000 yuan monthly cap")
  }
  if sd.continuing_education > CONTINUING_CAP {
    fail("continuing education exceeds the 400 yuan monthly cap")
  }
  if major_medical_annual > MAJOR_MEDICAL_YEAR_CAP {
    fail("major medical excess exceeds the 80000 yuan yearly cap")
  }
}

///|
/// Monthly total of all itemised deductions, in cents.
pub fn monthly_total(sd : SpecialDeductions) -> Int64 {
  let children = sd.children_education.to_int64() * CHILD_EDU_MONTHLY
  let infants = sd.infants.to_int64() * INFANT_MONTHLY
  let housing = if sd.housing_loan { LOAN_MONTHLY } else { sd.housing_rent }
  children + infants + housing + sd.elder_support + sd.continuing_education
}

///|
/// Eligible annual self-paid medical expenses, after insurance reimbursement.
/// Eligibility is caller-verified; this calculates the 15000 excess / 80000 cap.
pub fn medical_annual_deduction(eligible_self_paid : Int64) -> Int64 {
  clamp_cents(eligible_self_paid - 1_500_000L, 0L, MAJOR_MEDICAL_YEAR_CAP)
}
