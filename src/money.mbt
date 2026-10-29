///|
/// All monetary values are integer cents (1 yuan = 100 cents). Money never
/// crosses this module as a float: floats lose cents, and cents are the whole
/// point of payroll.

///|
/// Round-half-up division of `value * percent / 100`, cent-exact.
pub fn mul_percent(value : Int64, percent : Int32) -> Int64 {
  let product = value * percent.to_int64()
  if product >= 0L {
    (product + 50L) / 100L
  } else {
    -((-product + 50L) / 100L)
  }
}

///|
/// Render cents as a yuan string with exactly two decimals, e.g. 123456 -> "1234.56".
pub fn yuan_text(cents : Int64) -> String {
  let negative = cents < 0L
  let abs = if negative { -cents } else { cents }
  let yuan = abs / 100L
  let rest = abs % 100L
  let frac = if rest < 10L { "0" + rest.to_string() } else { rest.to_string() }
  (if negative { "-" } else { "" }) + yuan.to_string() + "." + frac
}

///|
/// Ceiling for any single amount, in cents: 1e12 cents = 10 billion yuan.
/// Chosen well above any real payroll and low enough that `amount * 45`
/// (the top rate) cannot overflow Int64. Inputs above it are rejected rather
/// than silently mis-taxed.
pub const MAX_AMOUNT : Int64 = 1_000_000_000_000L

///|
/// Clamp a value into [lower, upper]. Both bounds are inclusive.
pub fn clamp_cents(value : Int64, lower : Int64, upper : Int64) -> Int64 {
  if value < lower {
    lower
  } else if value > upper {
    upper
  } else {
    value
  }
}
