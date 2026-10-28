#!/usr/bin/env python3
"""Independent oracle for WageKit.

Re-implements the same payroll rules with Python Decimal (no shared code with
the MoonBit core), generates randomized payroll years that cover every tax
bracket, and compares the MoonBit CLI output field by field.

Usage:
    python tests/oracle.py [N]

Exit codes: 0 all checks pass; 1 mismatch (diff printed).
"""

from __future__ import annotations

import json
import random
import subprocess
import sys
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BATCH = ROOT / "tests" / "batch.mjs"

# Tax tables, in cents. Written independently from the MoonBit tables.
ANNUAL_TABLE = [
    (3_600_000, 3, 0),
    (14_400_000, 10, 252_000),
    (30_000_000, 20, 1_692_000),
    (42_000_000, 25, 3_192_000),
    (66_000_000, 30, 5_292_000),
    (96_000_000, 35, 8_592_000),
    (10**18, 45, 18_192_000),
]
MONTHLY_TABLE = [
    (300_000, 3, 0),
    (1_200_000, 10, 21_000),
    (2_500_000, 20, 141_000),
    (3_500_000, 25, 266_000),
    (5_500_000, 30, 441_000),
    (8_000_000, 35, 716_000),
    (10**18, 45, 1_516_000),
]


def _tax_of(table, taxable: int) -> int:
    if taxable <= 0:
        return 0
    for upper, rate, quick in table:
        if taxable <= upper:
            raw = Decimal(taxable) * Decimal(rate) / Decimal(100)
            taxed = int(raw.quantize(Decimal(1), rounding=ROUND_HALF_UP))
            return taxed - quick
    raise AssertionError("unreachable")


def _cumulative(inputs):
    results = []
    cum_gross = 0
    cum_deduct = 0
    prev_tax = 0
    for k, m in enumerate(inputs, start=1):
        cum_gross += m["gross"]
        cum_deduct += 500_000 + m["social"] + m["special"] + m["other"]
        taxable = cum_gross - cum_deduct
        tax_cum = _tax_of(ANNUAL_TABLE, taxable)
        withheld = max(0, tax_cum - prev_tax)
        results.append(
            {
                "month": k,
                "taxable_cum": taxable,
                "tax_cum": tax_cum,
                "withheld": withheld,
            }
        )
        prev_tax = tax_cum
    return results


def _bonus_standalone(bonus: int) -> int:
    if bonus <= 0:
        return 0
    per_month = bonus // 12
    for upper, rate, quick in MONTHLY_TABLE:
        if per_month <= upper:
            raw = Decimal(bonus) * Decimal(rate) / Decimal(100)
            return int(raw.quantize(Decimal(1), rounding=ROUND_HALF_UP)) - quick
    raise AssertionError("unreachable")


def _case(count: int) -> list[dict]:
    rng = random.Random(42)
    cases = []
    for _ in range(count):
        months = rng.randint(1, 12)
        entries = []
        for _ in range(months):
            gross = rng.randint(0, 8_000_000)
            entries.append(
                {
                    "gross": gross,
                    "social": rng.randint(0, min(gross, 600_000)),
                    "special": rng.randint(0, 600_000),
                    "other": rng.randint(0, 100_000),
                }
            )
        case = {"year": 2026, "months": entries}
        if rng.random() < 0.6:
            case["bonus"] = rng.choice(
                [
                    rng.randint(0, 100_000),
                    3_599_999,
                    3_600_000,
                    3_600_012,
                    14_400_012,
                    30_000_012,
                    42_000_012,
                    66_000_012,
                    96_000_012,
                    rng.randint(0, 20_000_000),
                ]
            )
        cases.append(case)
    return cases


def _expected(case: dict) -> dict:
    results = _cumulative(case["months"])
    expected = {
        "ok": True,
        "year": case.get("year", 2026),
        "months": results,
        "total_withheld": sum(r["withheld"] for r in results),
        "bonus": None,
    }
    if "bonus" in case:
        bonus = case["bonus"]
        without = _cumulative(case["months"])
        merged = [dict(m) for m in case["months"]]
        if merged:
            merged[-1]["gross"] += bonus
        else:
            merged = [{"gross": bonus, "social": 0, "special": 0, "other": 0}]
        with_bonus = _cumulative(merged)
        extra = sum(r["withheld"] for r in with_bonus) - sum(
            r["withheld"] for r in without
        )
        standalone = _bonus_standalone(bonus)
        expected["bonus"] = {
            "amount": bonus,
            "standalone_tax": standalone,
            "combined_extra_tax": extra,
            "best": "standalone" if standalone <= extra else "combined",
        }
    return expected


def main() -> int:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    cases = _case(count)
    cases_file = ROOT / "_build" / "oracle-cases.json"
    cases_file.parent.mkdir(exist_ok=True)
    cases_file.write_text(json.dumps(cases), encoding="utf-8")
    raw = subprocess.run(
        ["node", str(BATCH), str(cases_file)],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    if raw.returncode != 0:
        print("batch runner failed:", raw.stderr[-500:])
        return 1
    reports = json.loads(raw.stdout)
    failures = 0
    for i, (case, report) in enumerate(zip(cases, reports)):
        expected = _expected(case)
        if report != expected:
            failures += 1
            if failures <= 5:
                print(f"MISMATCH case #{i}")
                print(" case  :", json.dumps(case))
                print(" expect:", json.dumps(expected))
                print(" actual:", json.dumps(report))
    if failures:
        print(f"oracle: {failures}/{len(cases)} cases mismatched")
        return 1
    print(f"oracle: {len(cases)} cases matched field by field")
    return 0


if __name__ == "__main__":
    sys.exit(main())
