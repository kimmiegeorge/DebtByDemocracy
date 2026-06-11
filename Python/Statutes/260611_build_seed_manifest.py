#!/usr/bin/env python3
r"""
260611_build_seed_manifest.py  --  Debt by Democracy: state statute AI task

Phase 1, step 1. Filter the curated, long-format source list
(state_source_links.csv) down to the 10 PILOT states and write a tidy manifest.

Why this exists
---------------
state_source_links.csv holds one row per (state, link) for all 50 states, pulled
from threaded comments in the laws workbook. For the pilot we only need the 10
pilot states. This manifest does two jobs downstream:
  1. Tells the title-selection step which Justia titles are already known to be
     relevant (every seed section lives inside some title).
  2. Tags the exact pinpoint sections to revisit when filling 260611_sourcelevel.

This script is LOCAL only (no network) and is safe to re-run; it overwrites its
output deterministically.

Inputs
------
  Data\Statutes\state_source_links.csv

Outputs
-------
  Data\Statutes\documentation\260611_pilot_seed_manifest.csv

Run (from anywhere, using the project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260611_build_seed_manifest.py
"""
from __future__ import annotations

import sys
from pathlib import Path
from urllib.parse import urlparse

import polars as pl

# Windows consoles default to cp1252; force UTF-8 so polars' table glyphs print.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# --- Absolute project paths (script lives in Code\Python\Statutes) -------------
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
MAIN = HOME / "Data" / "Statutes"
SEED_IN = MAIN / "state_source_links.csv"
OUT = MAIN / "documentation" / "260611_pilot_seed_manifest.csv"

# --- Pilot scope (from 260611_dummystructure_sourcelevel.xlsx) -----------------
# 10 pilot states; 7 of them are self-designated "control" states (cities do NOT
# need voter approval for GO or revenue bonds).
PILOT = ["AL", "AK", "AZ", "KY", "MA", "MS", "NH", "NJ", "TN", "WI"]
CONTROL = {"KY", "MA", "MS", "NH", "NJ", "TN", "WI"}


def guess_ext(url: str) -> str:
    """File extension we expect to save for a URL: pdf for PDFs, else html."""
    if not url:
        return ""
    path = urlparse(url).path.lower()
    return "pdf" if path.endswith(".pdf") else "html"


def bond_hint(link_note: str) -> str:
    """Coarse GO/rev hint parsed from the human link note (best-effort, may be '')."""
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

    pilot = (
        df.filter(pl.col("state_abbr").is_in(PILOT))
        .with_columns(
            is_control=pl.col("state_abbr").is_in(list(CONTROL)).cast(pl.Int8),
            ext=pl.col("url").map_elements(guess_ext, return_dtype=pl.Utf8),
            bond_hint=pl.col("link_note").map_elements(bond_hint, return_dtype=pl.Utf8),
        )
        # Keep the columns useful for title selection + later sourcing.
        .select(
            "state_abbr", "state_name", "is_control", "GO", "Rev",
            "url", "domain", "source_type", "ext", "bond_hint", "link_note",
        )
        # Stable, readable ordering: pilot order, then by url.
        .with_columns(
            pl.col("state_abbr").cast(pl.Enum(PILOT)).to_physical().alias("_ord")
        )
        .sort(["_ord", "url"])
        .drop("_ord")
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    pilot.write_csv(OUT)

    # --- Console summary -------------------------------------------------------
    print(f"Input : {SEED_IN}")
    print(f"Output: {OUT}")
    print(f"Pilot rows: {pilot.height} across {pilot['state_abbr'].n_unique()} states")
    by_state = (
        pilot.group_by("state_abbr")
        .agg(
            n_links=pl.len(),
            n_primary=(pl.col("source_type") == "primary").sum(),
            n_secondary=(pl.col("source_type") == "secondary").sum(),
            n_pdf=(pl.col("ext") == "pdf").sum(),
            domains=pl.col("domain").unique().str.join(", "),
        )
        .with_columns(pl.col("state_abbr").cast(pl.Enum(PILOT)).to_physical().alias("_o"))
        .sort("_o")
        .drop("_o")
    )
    with pl.Config(tbl_rows=20, fmt_str_lengths=80, tbl_width_chars=180):
        print(by_state)
    missing = [s for s in PILOT if s not in set(pilot["state_abbr"].to_list())]
    print("Pilot states with NO seed rows:", missing or "(none)")


if __name__ == "__main__":
    main()
