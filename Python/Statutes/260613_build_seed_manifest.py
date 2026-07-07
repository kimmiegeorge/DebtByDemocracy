#!/usr/bin/env python3
r"""
260613_build_seed_manifest.py  --  Debt by Democracy: state statute AI task

Phase 1, step 1 for the EXPANSION batch (25 states beyond the original 10-state
pilot). Filter the curated, long-format source list (state_source_links.csv) down
to the expansion states and write a tidy manifest, mirroring the pilot's
260611_build_seed_manifest.py.

Expansion states (2026-06-13): AR CA CO FL GA ID LA ME MI MO MT NE NM NC ND OH OK
OR SD TX UT VT WA WV WY. Control status is NOT yet designated for these (they are
not in the dummy structure), so this manifest omits the control flag; it exists
only to (1) tell title-selection which Justia titles already hold a seed section
and (2) tag pinpoint sections to revisit when filling the source-level dataset.

LOCAL only (no network); safe to re-run (overwrites its output deterministically).

Inputs : Data\Statutes\state_source_links.csv
Outputs: Data\Statutes\documentation\260613_expansion_seed_manifest.csv

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260613_build_seed_manifest.py
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
OUT = MAIN / "documentation" / "260613_expansion_seed_manifest.csv"

# Expansion scope (25 states). Order is preserved in the output for readability.
EXPANSION = ["AR", "CA", "CO", "FL", "GA", "ID", "LA", "ME", "MI", "MO", "MT",
             "NE", "NM", "NC", "ND", "OH", "OK", "OR", "SD", "TX", "UT", "VT",
             "WA", "WV", "WY"]


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


def main() -> None:
    if not SEED_IN.exists():
        raise SystemExit(f"Seed file not found: {SEED_IN}")

    df = pl.read_csv(SEED_IN)

    exp = (
        df.filter(pl.col("state_abbr").is_in(EXPANSION))
        .with_columns(
            ext=pl.col("url").map_elements(guess_ext, return_dtype=pl.Utf8),
            bond_hint=pl.col("link_note").map_elements(bond_hint, return_dtype=pl.Utf8),
        )
        .select(
            "state_abbr", "state_name", "GO", "Rev",
            "url", "domain", "source_type", "ext", "bond_hint", "link_note",
        )
        .with_columns(
            pl.col("state_abbr").cast(pl.Enum(EXPANSION)).to_physical().alias("_ord")
        )
        .sort(["_ord", "url"])
        .drop("_ord")
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    exp.write_csv(OUT)

    print(f"Input : {SEED_IN}")
    print(f"Output: {OUT}")
    print(f"Expansion rows: {exp.height} across {exp['state_abbr'].n_unique()} states")
    by_state = (
        exp.group_by("state_abbr")
        .agg(
            n_links=pl.len(),
            n_primary=(pl.col("source_type") == "primary").sum(),
            n_secondary=(pl.col("source_type") == "secondary").sum(),
            n_pdf=(pl.col("ext") == "pdf").sum(),
            domains=pl.col("domain").unique().str.join(", "),
        )
        .with_columns(pl.col("state_abbr").cast(pl.Enum(EXPANSION)).to_physical().alias("_o"))
        .sort("_o")
        .drop("_o")
    )
    with pl.Config(tbl_rows=30, fmt_str_lengths=70, tbl_width_chars=180):
        print(by_state)
    missing = [s for s in EXPANSION if s not in set(exp["state_abbr"].to_list())]
    print("Expansion states with NO seed rows:", missing or "(none)")


if __name__ == "__main__":
    main()
