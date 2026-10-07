#!/usr/bin/env python3
r"""
260611_finalize_chapters.py  --  Debt by Democracy: state statute AI task

Phase 2, step 2c. Apply the REFINED (tight, name-based) narrowing rule to the
mega-title walk output and write a `selected_final` flag onto both:
  documentation\260611_chapter_selection.csv   (chapter review summary)
  documentation\260611_megatitle_sections.csv  (section allowlist for the crawler)

Rule (refined after the first keyword set proved far too broad):
  - Chaptered titles (AL T11, MA T-VII, NH T-III, TN T6/T7): select a chapter if
    its NAME matches a bond/finance/election keyword, EXCEPT surety-bond chapters
    ("...bonds of officers"). Whole selected chapters are kept (cross-refs intact).
  - NJ Title 40A (flat): select a numeric chapter group if any section heading has
    a tight bond/debt/referendum hit (group kept whole). NJ Title 40 is the
    pre-1987 SUPERSEDED title -> dropped (recommendation; override in review).
  - AZ Title 11 (flat counties): section-level tight bond-heading selection.
  - Any curated SEED section is force-included (and its group kept).

Local only (no network); re-runnable. Reads seed URLs from the pilot manifest.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import polars as pl

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DOCS = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
            r"\Data\Statutes\documentation")
REVIEW = DOCS / "260611_chapter_selection.csv"
ALLOW = DOCS / "260611_megatitle_sections.csv"
SEED = DOCS / "260611_pilot_seed_manifest.csv"

NAME_KW = ["bond", "debt", "borrow", "indebted", "obligation", "warrant",
           "finance", "fiscal", "election", "referend", "ballot", "improvement"]
NAME_DENY = ["officer"]            # surety bonds of officials, not municipal debt
HEAD_KW = ["bond", "debt", "borrow", "indebted", "referend"]
DROP_DIVS = {("NJ", "title-40")}   # superseded title


def hit(text: str, kws) -> bool:
    low = (text or "").lower()
    return any(k in low for k in kws)


def main() -> None:
    rev = pl.read_csv(REVIEW)
    alw = pl.read_csv(ALLOW)
    seed_urls = set(pl.read_csv(SEED)["url"].to_list())

    # chapter_key -> name (chaptered only)
    cname = {(r["state_abbr"], r["div_slug"], r["chapter_key"]): (r["chapter_name"] or "")
             for r in rev.iter_rows(named=True)}

    # NJ Title 40A: which numeric groups have a tight bond hit (keep whole)
    nj_grp_hit: dict[tuple, bool] = {}
    for r in alw.iter_rows(named=True):
        if (r["state_abbr"], r["div_slug"]) == ("NJ", "title-40a"):
            k = (r["div_slug"], r["chapter_key"])
            nj_grp_hit[k] = nj_grp_hit.get(k, False) or hit(r["heading"], HEAD_KW)

    def sec_selected(r) -> bool:
        st, dv = r["state_abbr"], r["div_slug"]
        if r["section_url"] in seed_urls:
            return True
        if (st, dv) in DROP_DIVS:
            return False
        nm = cname.get((st, dv, r["chapter_key"]), "")
        chaptered = nm not in ("", "(individual sections)")
        if chaptered:
            return hit(nm, NAME_KW) and not hit(nm, NAME_DENY)
        if (st, dv) == ("NJ", "title-40a"):
            return nj_grp_hit.get((dv, r["chapter_key"]), False)
        # AZ flat counties -> section-level
        return hit(r["heading"], HEAD_KW)

    alw = alw.with_columns(
        pl.struct(["state_abbr", "div_slug", "chapter_key", "section_url", "heading"])
        .map_elements(sec_selected, return_dtype=pl.Boolean).alias("sel")
    )
    alw = alw.with_columns(selected_final=pl.when(pl.col("sel")).then(pl.lit("Y"))
                           .otherwise(pl.lit("N"))).drop("sel")

    # roll selection up to the chapter review file
    chap_sel = {(r["state_abbr"], r["div_slug"], r["chapter_key"]): r["selected_final"]
                for r in alw.group_by(["state_abbr", "div_slug", "chapter_key"])
                .agg(selected_final=pl.when((pl.col("selected_final") == "Y").any())
                     .then(pl.lit("Y")).otherwise(pl.lit("N"))).iter_rows(named=True)}
    rev = rev.with_columns(
        pl.struct(["state_abbr", "div_slug", "chapter_key"])
        .map_elements(lambda r: chap_sel.get((r["state_abbr"], r["div_slug"], r["chapter_key"]), "N"),
                      return_dtype=pl.Utf8).alias("selected_final")
    )

    alw.write_csv(ALLOW)
    rev.write_csv(REVIEW)

    sel = alw.filter(pl.col("selected_final") == "Y")
    print("Mega-title sections total:", alw.height, "| SELECTED:", sel.height)
    by = (alw.group_by("state_abbr").agg(
        total=pl.len(), selected=(pl.col("selected_final") == "Y").sum()).sort("state_abbr"))
    with pl.Config(tbl_rows=20):
        print(by)
    print("\nSelected chapters/groups:")
    cs = (sel.group_by(["state_abbr", "div_slug", "chapter_key"]).agg(n=pl.len())
          .sort(["state_abbr", "div_slug", "chapter_key"]))
    for r in cs.iter_rows(named=True):
        nm = cname.get((r["state_abbr"], r["div_slug"], r["chapter_key"]), "")
        print(f"  {r['state_abbr']} {r['div_slug']:9s} {str(r['chapter_key']):16s} n={r['n']:4d} {nm[:44]}")


if __name__ == "__main__":
    main()
