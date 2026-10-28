///|
/// The inverse question. Forward payroll answers "what do I take home on a
/// 30 000 gross?"; hiring and retention answer the other direction: "the offer
/// promises 25 000 net, what gross do I put in the contract?" Because tax is
/// piecewise linear with cent rounding, not every net value is attainable —
/// so the honest answer is the smallest gross that reaches the target, plus
/// how far past it the employee actually lands.

///|
pub(all) struct GrossUp {
  /// The net amount asked for, in cents (negative targets clamp to zero).
  target_net : Int64
  /// Smallest gross that reaches the target, in cents.
  gross : Int64
  /// Net actually produced by that gross, in cents.
  net : Int64
  /// `net - target_net`, never negative. Zero means the target is exact.
  overshoot : Int64
  /// Whether the target is reachable to the cent.
  exact : Bool
} derive(Eq)

///|
/// Take-home pay for a single month at a given gross, under a rule set.
/// Social insurance is a cash deduction; special and other deductions only
/// shrink the tax base and never leave the employee's pocket twice.
fn net_at(
  rules : RuleSet,
  gross : Int64,
  social : Int64,
  special : Int64,
  other : Int64,
) -> Int64 {
  let taxable = gross - rules.basic_deduction - social - special - other
  gross - social - tax_of(rules.annual, taxable)
}

///|
/// Gross-up under the default rule set.
pub fn gross_up(
  target_net : Int64,
  social : Int64,
  special : Int64,
  other : Int64,
) -> GrossUp {
  gross_up_under(default_rules(), target_net, social, special, other)
}

///|
/// Gross-up under an explicit rule set. Binary search over a monotonically
/// non-decreasing net curve: tax is never negative, so gross must be at least
/// `social + target`, and doubling finds an upper bound in O(log target).
pub fn gross_up_under(
  rules : RuleSet,
  target_net : Int64,
  social : Int64,
  special : Int64,
  other : Int64,
) -> GrossUp {
  let goal = if target_net < 0L { 0L } else { target_net }
  let mut high = social + goal
  let mut attempts = 0
  while net_at(rules, high, social, special, other) < goal && attempts < 64 {
    high = high * 2L + 1L
    attempts = attempts + 1
  }
  let mut low = 0L
  while low < high {
    let mid = (low + high) / 2L
    if net_at(rules, mid, social, special, other) >= goal {
      high = mid
    } else {
      low = mid + 1L
    }
  }
  let net = net_at(rules, low, social, special, other)
  let overshoot = net - goal
  {
    target_net: goal,
    gross: low,
    net,
    overshoot: if overshoot < 0L {
      0L
    } else {
      overshoot
    },
    exact: net == goal,
  }
}
