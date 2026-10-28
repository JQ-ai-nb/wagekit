///|
/// Stable JavaScript-facing entry point. Thin on purpose: the rules live in
/// the core package, this file only converts a raised TaxError into the wire
/// error object.
pub fn run(source : String) -> String {
  @wagekit.run_report(source) catch {
    TaxError(message) => "{\"ok\":false,\"error\":\"\{message}\"}"
  }
}

///|
/// Native/wasm builds need an entry point when `link` options are present.
fn main {
  ()
}
