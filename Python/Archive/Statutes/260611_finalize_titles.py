#!/usr/bin/env python3
r"""
260611_finalize_titles.py  --  Debt by Democracy: state statute AI task

Phase 1, step 3. Apply the agreed PRUNED title/chapter selection (the curated set
discussed with the user on 2026-06-11) to 260611_title_selection.csv by adding an
auditable `include_final` column. Big "Revenue and Taxation" titles are excluded;
KY/WI keyword noise is removed. Every state's constitution is always included.

This keeps the decision transparent: the keyword tiers stay in the file, and
`include_final` records exactly what Phase 2 will crawl. Re-runnable. A typo guard
prints any curated slug that did NOT match a row in the file.

In/Out (same file, column added):
  Data\Statutes\documentation\260611_title_selection.csv
"""
from __future__ import annotations

import sys
from pathlib import Path

import polars as pl

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

CSV = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
           r"\Data\Statutes\documentation\260611_title_selection.csv")

# Curated final statute divisions per state (div_slug, lower-case). Constitutions
# are added automatically. Rationale recorded in documentation\task_plan.md.
FINAL: dict[str, list[str]] = {
    # Title-based states: whole relevant title(s). Revenue&Taxation excluded.
    "AL": ["title-11"],                                  # Counties & Municipal Corps
    "AK": ["title-1", "title-29", "title-37"],           # Gen Prov, Municipal Govt, Public Finance
    "AZ": ["title-7", "title-9", "title-11", "title-35"],  # Bonds, Cities&Towns, Counties, Public Finances
    "MA": ["title-vii"],                                 # Cities, Towns & Districts (Ch.44 Muni Finance)
    "MS": ["title-17", "title-21", "title-31"],          # Local Govt, Municipalities, Public Business/Bonds
    "NH": ["title-iii"],                                 # Towns, Cities, Village Districts
    "NJ": ["title-40", "title-40a"],                     # Municipalities & Counties
    "TN": ["title-6", "title-7", "title-9"],             # Cities&Towns, Local Govt, Public Finances
    # Chapter-based states: hand-picked city finance/borrowing + key election chapters.
    "KY": ["chapter-58", "chapter-65", "chapter-66", "chapter-82", "chapter-83",
           "chapter-83a", "chapter-91", "chapter-91a", "chapter-92", "chapter-96",
           "chapter-103", "chapter-107", "chapter-117", "chapter-118"],
    "WI": ["chapter-18", "chapter-62", "chapter-65", "chapter-66", "chapter-67",
           "chapter-197", "chapter-198", "chapter-5", "chapter-8", "chapter-10"],
}


def main() -> None:
    df = pl.read_csv(CSV)

    # Build the include_final flag row-by-row.
    def decide(row) -> str:
        if row["kind"] == "constitution":
            return "Y"
        wanted = FINAL.get(row["state_abbr"], [])
        return "Y" if (row["div_slug"] or "").lower() in wanted else "N"

    df = df.with_columns(
        pl.struct(["kind", "state_abbr", "div_slug"])
        .map_elements(decide, return_dtype=pl.Utf8)
        .alias("include_final")
    )

    # Typo guard: every curated slug should match exactly one statute row.
    present = {
        (r["state_abbr"], (r["div_slug"] or "").lower())
        for r in df.filter(pl.col("kind") == "statute").iter_rows(named=True)
    }
    missing = [(s, slug) for s, slugs in FINAL.items() for slug in slugs
               if (s, slug) not in present]
    if missing:
        print("!! Curated slugs with NO matching row (check spelling):")
        for s, slug in missing:
            print(f"   {s}  {slug}")
    else:
        print("Typo guard: all curated slugs matched a row.")

    df.write_csv(CSV)

    summary = (
        df.filter(pl.col("include_final") == "Y")
        .group_by("state_abbr")
        .agg(
            n_final=pl.len(),
            n_statute=(pl.col("kind") == "statute").sum(),
            n_const=(pl.col("kind") == "constitution").sum(),
        )
        .with_columns(pl.col("state_abbr").cast(
            pl.Enum(["AL", "AK", "AZ", "KY", "MA", "MS", "NH", "NJ", "TN", "WI"])
        ).to_physical().alias("_o")).sort("_o").drop("_o")
    )
    with pl.Config(tbl_rows=20):
        print(summary)
    print(f"\nTotal divisions to crawl (incl. constitutions): "
          f"{df.filter(pl.col('include_final') == 'Y').height}")
    print("Wrote include_final ->", CSV)


if __name__ == "__main__":
    main()
