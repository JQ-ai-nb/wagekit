///|
/// Stable JavaScript facades; domain logic remains in the MoonBit core.
pub fn run(source : String) -> String {
  @wagekit.run_report(source) catch {
    TaxError(message) => {
      let error : Json = { "ok": false, "error": Json::string(message) }
      error.stringify()
    }
  }
}

///|
pub fn run_payslip(source : String) -> String {
  @wagekit.run_payslip_report(source) catch {
    TaxError(message) => "error: \{message}"
  }
}

///|
pub fn audit(source : String) -> String {
  @wagekit.run_audit_report(source) catch {
    TaxError(message) => {
      let error : Json = { "ok": false, "error": Json::string(message) }
      error.stringify()
    }
  }
}

///|
fn main {
  ()
}
