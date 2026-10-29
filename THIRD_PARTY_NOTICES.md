# Third-Party Notices

WageKit source is MIT. Its only runtime dependency is moonbitlang/core, the
MoonBit standard library, licensed under Apache-2.0:
https://github.com/moonbitlang/core

The generated JavaScript embeds standard-library code. The upstream license
and NOTICE are redistributed in third_party/ and web/licenses/; the build
script also copies both into dist/licenses/. Keep those files when distributing
the browser or CLI bundle. Upstream source comments retain their own notices.

The city contribution values are synthetic examples, not an official dataset.
The Decimal oracle uses the Python standard library and is test infrastructure.
Tax calculations reference official public documents listed in docs/RULES.md.
No source was copied from the related salary calculators in docs/COMPARISON.md.
