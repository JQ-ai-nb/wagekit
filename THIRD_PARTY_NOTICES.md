# Third-Party Notices

WageKit has **no third-party code dependencies**. The runtime dependency is:

- `moonbitlang/core` (Apache-2.0) — the MoonBit standard library, provided by
  the toolchain; its license is distributed with the toolchain installation.

The bundled city social-insurance parameter table (`city_params()`) is example
data authored for this project, not copied from any third-party source.

The independent test oracle (`tests/oracle.py`) uses only the Python standard
library (`decimal`, `random`, `json`, `subprocess`) and is test infrastructure,
not a runtime dependency.

Tax rules follow publicly available legislation and administrative documents;
the implementation is original and no third-party implementation was ported.
