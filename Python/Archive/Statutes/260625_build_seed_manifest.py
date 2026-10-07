#!/usr/bin/env python3
r"""
260625_build_seed_manifest.py  --  Debt by Democracy: state statute AI task

Phase 1, step 1 for the FINAL batch (the last states beyond the 10-state pilot +
25-state expansion). Filter the curated long-format source list
(state_source_links.csv) down to these states and write a tidy manifest, mirroring
260611_/260613_build_seed_manifest.py.

FINAL 14: CT DE IL IN IA KS MD MN NV NY PA RI SC VA.
(HAWAII IS EXCLUDED -- Hawaii has no independent city governments, so it is out of
scope for this municipal-bond project; user-confirmed 2026-06-25. 14 + 10 pilot + 25
expansion = 49 coded states; HI documented as excluded = "all 50" accounted for.)

Control status is NOT designated for these (not in the dummy), so this manifest omits
the control flag; it exists only to (1) tell title-selection which Justia titles
already hold a seed section and (2) tag pinpoint sections to revisit at Phase 4.

LOCAL only (no network); safe to re-run (overwrites deterministically).

Inputs : Data\Statutes\state_source_links.csv
Outputs: Data\Statutes\documentation\260625_final15_seed_manifest.csv

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260625_build_seed_manifest.py
"""
from __future__ import annotations

import sys
from pathlib import Path
from urllib.parse import urlparse

import polars as pl

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
MAIN = HOME / "Data" / "Statutes"
SEED_IN = MAIN / "state_source_links.csv"
OUT = MAIN / "documentation" / "260625_final15_seed_manifest.csv"

# Final scope (14 states; Hawaii excluded -- no independent city governments).
# Order preserved in the output for readability.
FINAL15 = ["CT", "DE", "IL", "IN", "IA", "KS", "MD", "MN", "NV", "NY",
           "PA", "RI", "SC", "VA"]


def guess_ext(url: str) -> str:
    if not url:
        return ""
    path = urlparse(url).path.lower()
    return "pdf" if path.endswith(".pdf") else "html"


def bond_hint(link_note: str) -> str:
    s = (link_note or "").lower()
    go = any(k in s for k in ("go ", "go:", "general obligation", "go bond", "utgo"))
    rev = any(k in s for k in ("rev", "revenue"))
    if go and rev:
        return "both"
    if go:
        return "go"
    if rev:
        return "rev"
    return ""


def is_justia_codes(url: str) -> bool:
    return bool(url) and "law.justia.com/codes/" in url


def main() -> None:
    if not SEED_IN.exists():
        raise SystemExit(f"Seed file not found: {SEED_IN}")

    df = pl.read_csv(SEED_IN)

    fin = (
        df.filter(pl.col("state_abbr").is_in(FINAL15))
        .with_columns(
            ext=pl.col("url").map_elements(guess_ext, return_dtype=pl.Utf8),
            bond_hint=pl.col("link_note").map_elements(bond_hint, return_dtype=pl.Utf8),
            on_justia=pl.col("url").map_elements(is_justia_codes, return_dtype=pl.Boolean),
        )
        .select(
            "state_abbr", "state_name", "GO", "Rev",
            "url", "domain", "source_type", "ext", "bond_hint", "on_justia", "link_note",
        )
        .with_columns(
            pl.col("state_abbr").cast(pl.Enum(FINAL15)).to_physical().alias("_ord")
        )
        .sort(["_ord", "url"])
        .drop("_ord")
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(fin.write_csv(), encoding="utf-8-sig")  # UTF-8 + BOM for Excel

    print(f"Input : {SEED_IN}")
    print(f"Output: {OUT}")
    print(f"Final-15 rows: {fin.height} across {fin['state_abbr'].n_unique()} states")
    by_state = (
        fin.group_by("state_abbr")
        .agg(
            n_links=pl.len(),
            n_primary=(pl.col("source_type") == "primary").sum(),
            n_secondary=(pl.col("source_type") == "secondary").sum(),
            n_justia_codes=pl.col("on_justia").sum(),
            n_pdf=(pl.col("ext") == "pdf").sum(),
            domains=pl.col("domain").unique().str.join(", "),
        )
        .with_columns(pl.col("state_abbr").cast(pl.Enum(FINAL15)).to_physical().alias("_o"))
        .sort("_o")
        .drop("_o")
    )
    with pl.Config(tbl_rows=30, fmt_str_lengths=70, tbl_width_chars=200):
        print(by_state)
    missing = [s for s in FINAL15 if s not in set(fin["state_abbr"].to_list())]
    print("Final-15 states with NO seed rows:", missing or "(none)")
    no_justia = sorted(set(FINAL15) - set(
        fin.filter(pl.col("on_justia"))["state_abbr"].to_list()))
    print("Final-15 states with NO Justia /codes/ seed (need by-name title lookup):",
          no_justia or "(none)")


if __name__ == "__main__":
    main()
