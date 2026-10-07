"""Rebuild the 2017 CAFR validation inputs with both Mergent stock measures.

The original validation folders were populated from the paper-compatible
static stock.  This script preserves that stock explicitly and adds the
refunding-inclusive, redemption-adjusted stock.  It does not alter any CAFR
annotations already entered in the reconciliation templates.

Outputs
-------
* Each validation folder receives ``source_observation_updated.csv`` and
  ``source_observation_static.csv``. ``source_observation_full.csv`` is reset
  to the updated observation to match the validation README's stated source.
* ``debt_reconciliation_inputs.csv`` and ``CAFR_reconciliation_template.csv``
  contain both stock definitions and their Census gaps.
* ``reconciliation_stock_comparison_2017.csv`` is a one-row-per-city audit
  file for comparing the two measures against CAFR benchmarks.

Run from any working directory:
    python3 Code/Python/Clean/CAFR/rebuild_cafr_reconciliations.py
"""

from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
VALIDATION_DIR = ROOT / "Data" / "Census CAFR Validation"
CURRENT_STOCK_FILE = (
    ROOT
    / "Data"
    / "Clean_Intermediate"
    / "Census COG Finance"
    / "processed"
    / "census_mergent_debt_cross_section_2017.csv"
)
STATIC_STOCK_FILE = (
    ROOT
    / "Data"
    / "Clean_Intermediate"
    / "Census COG Finance"
    / "processed"
    / "no_refundings"
    / "census_mergent_debt_cross_section_2017.csv"
)

INPUT_FIELDS = ["metric", "source_variable", "amount_usd", "source", "definition"]
TEMPLATE_FIELDS = INPUT_FIELDS + [
    "cafr_report_fiscal_year_end",
    "cafr_file_or_url",
    "cafr_page",
    "cafr_table_or_note",
    "cafr_amount_usd",
    "difference_cafr_minus_source_usd",
    "accounting_scope_or_basis",
    "reconciliation_notes",
]


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def write_rows(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


def numeric(row: dict[str, str], field: str) -> float:
    value = row.get(field, "")
    return float(value) if value not in ("", None) else 0.0


def money(value: float) -> str:
    # Source files use dollars and retain exact integer principal where possible.
    return str(int(round(value)))


def source_row_map(path: Path) -> dict[str, dict[str, str]]:
    rows = read_rows(path)
    result: dict[str, dict[str, str]] = {}
    for row in rows:
        gov_id = row.get("gov_id", "")
        if gov_id in result:
            raise ValueError(f"Duplicate gov_id {gov_id} in {path}")
        result[gov_id] = row
    return result


def is_validation_folder(path: Path) -> bool:
    return path.is_dir() and path.name[:2].isdigit() and (path / "source_observation_full.csv").exists()


def stock_rows(current: dict[str, str], static: dict[str, str], census_total: float) -> list[dict[str, str]]:
    stock_fields = [
        (
            "total",
            "total outstanding debt",
            "mergent_total_outstanding_debt",
            "All matched-city Mergent instruments in the stock measure as of 2017-12-31.",
        ),
        (
            "go_revenue",
            "GO plus revenue outstanding debt",
            "mergent_go_revenue_outstanding_debt",
            "Matched-city GO and revenue bonds in the stock measure as of 2017-12-31.",
        ),
        (
            "other",
            "other outstanding debt",
            "mergent_other_outstanding_debt",
            "Matched-city bonds classified as other in the stock measure as of 2017-12-31.",
        ),
        (
            "lease_rent_loan_agreement",
            "lease/rent/loan-agreement outstanding debt",
            "mergent_lease_rent_loan_agreement_outstanding_debt",
            "Lease, rent, or loan-agreement subset in the stock measure as of 2017-12-31.",
        ),
    ]
    rows: list[dict[str, str]] = []
    for label, display, field, definition in stock_fields:
        for construction, source, row, construction_definition in [
            (
                "updated",
                "Mergent, refunding-inclusive/redemption-adjusted",
                current,
                "Retains refunding CUSIPs and subtracts dated redemptions, partial calls, and available dated balance reductions.",
            ),
            (
                "static",
                "Mergent, paper-compatible static/no-refunding",
                static,
                "Excludes Mergent REF-purpose CUSIPs and retains non-REF CUSIPs at original par through contractual maturity.",
            ),
        ]:
            amount = numeric(row, field)
            rows.append(
                {
                    "metric": f"Mergent {construction} {display}",
                    "source_variable": f"mergent_{construction}_{label}_outstanding_debt",
                    "amount_usd": money(amount),
                    "source": source,
                    "definition": f"{definition} {construction_definition}",
                }
            )
            if label == "total":
                rows.append(
                    {
                        "metric": f"Census total less Mergent {construction} total",
                        "source_variable": f"census_less_mergent_{construction}_total",
                        "amount_usd": money(census_total - amount),
                        "source": "Derived",
                        "definition": (
                            "Census end-of-fiscal-year total debt minus the specified "
                            "Mergent 2017-12-31 stock. This is not solely non-Mergent debt: "
                            "it can also reflect date, reporting-entity, and refunding-treatment differences."
                        ),
                    }
                )
    return rows


def preserve_template_annotations(path: Path) -> tuple[dict[str, dict[str, str]], str]:
    if not path.exists():
        return {}, ""
    rows = read_rows(path)
    fiscal_year_end = rows[0].get("cafr_report_fiscal_year_end", "") if rows else ""
    annotations = {row.get("source_variable", ""): row for row in rows}
    return annotations, fiscal_year_end


def main() -> None:
    current_by_gov = source_row_map(CURRENT_STOCK_FILE)
    static_by_gov = source_row_map(STATIC_STOCK_FILE)
    folders = sorted(path for path in VALIDATION_DIR.iterdir() if is_validation_folder(path))
    if len(folders) != 20:
        raise ValueError(f"Expected 20 validation folders; found {len(folders)}")

    master_rows: list[dict[str, object]] = []
    for folder in folders:
        legacy_source = read_rows(folder / "source_observation_full.csv")
        if len(legacy_source) != 1:
            raise ValueError(f"Expected one source row in {folder}")
        gov_id = legacy_source[0]["gov_id"]
        current = current_by_gov.get(gov_id)
        static = static_by_gov.get(gov_id)
        if current is None or static is None:
            raise ValueError(f"Missing stock row for {folder.name} ({gov_id})")

        # Keep an explicitly named copy of the legacy/static source before
        # replacing source_observation_full with the current updated source.
        write_rows(folder / "source_observation_static.csv", list(static.keys()), [static])
        write_rows(folder / "source_observation_updated.csv", list(current.keys()), [current])
        write_rows(folder / "source_observation_full.csv", list(current.keys()), [current])

        old_inputs = read_rows(folder / "debt_reconciliation_inputs.csv")
        census_rows = [row for row in old_inputs if row.get("source") not in {"Mergent", "Derived"}]
        census_total_row = next(
            (row for row in census_rows if row.get("source_variable") == "total_end_debt_outstanding_dollars"),
            None,
        )
        if census_total_row is None:
            raise ValueError(f"No Census end-debt row in {folder}")
        census_total = numeric(census_total_row, "amount_usd")
        refreshed_rows = census_rows + stock_rows(current, static, census_total)
        write_rows(folder / "debt_reconciliation_inputs.csv", INPUT_FIELDS, refreshed_rows)

        template_path = folder / "CAFR_reconciliation_template.csv"
        annotations, fiscal_year_end = preserve_template_annotations(template_path)
        template_rows: list[dict[str, str]] = []
        for row in refreshed_rows:
            preserved = annotations.get(row["source_variable"], {})
            template_row = {field: preserved.get(field, "") for field in TEMPLATE_FIELDS}
            template_row.update(row)
            if not template_row["cafr_report_fiscal_year_end"]:
                template_row["cafr_report_fiscal_year_end"] = fiscal_year_end
            template_rows.append(template_row)
        write_rows(template_path, TEMPLATE_FIELDS, template_rows)

        updated_total = numeric(current, "mergent_total_outstanding_debt")
        static_total = numeric(static, "mergent_total_outstanding_debt")
        master_rows.append(
            {
                "folder": folder.name,
                "city": current.get("census_name", ""),
                "state": current.get("state", ""),
                "gov_id": gov_id,
                "census_fiscal_year_ending": current.get("fiscal_year_ending", ""),
                "census_total_ending_debt_usd": money(census_total),
                "mergent_updated_total_usd": money(updated_total),
                "mergent_static_total_usd": money(static_total),
                "updated_minus_static_usd": money(updated_total - static_total),
                "census_less_updated_usd": money(census_total - updated_total),
                "census_less_static_usd": money(census_total - static_total),
                "mergent_updated_go_revenue_usd": money(numeric(current, "mergent_go_revenue_outstanding_debt")),
                "mergent_static_go_revenue_usd": money(numeric(static, "mergent_go_revenue_outstanding_debt")),
            }
        )

    master_fields = list(master_rows[0].keys())
    master_path = VALIDATION_DIR / "reconciliation_stock_comparison_2017.csv"
    write_rows(master_path, master_fields, master_rows)

    improved = sum(
        abs(float(row["census_less_updated_usd"])) < abs(float(row["census_less_static_usd"]))
        for row in master_rows
    )
    print(f"Rebuilt {len(folders)} CAFR validation folders.")
    print(f"Wrote {master_path.relative_to(ROOT)}")
    print(f"Updated stock is closer to unadjusted Census total in {improved}/{len(master_rows)} cities.")


if __name__ == "__main__":
    main()
