#!/usr/bin/env python3
r"""
260625_finalize_chapters.py  --  Debt by Democracy: state statute AI task

Phase 2, step 2c for the FINAL 14 states. Applies CATEGORY-TIGHT narrowing to the
walked-chapter output (260625_select_chapters.py) and writes `selected_final` onto
both the chapter review and the per-section allowlist. Local only; re-runnable.

Per the user's decision (2026-06-26) ONLY the Elections + Utilities megas were walked:
  - ELECTIONS: keep chapters about putting a QUESTION to voters (referendum/initiative/
    local/special/consolidated election, ballot measure/question, bond election); drop
    machinery (registration, primary, conduct, contests, campaign, absentee, canvass,
    printing). Section-level bond/debt rescue inside dropped chapters.
  - UTILITIES: keep chapters about utility BONDS/FINANCE/DEBT/revenue obligations; drop
    rate regulation / PUC procedure / safety. Section-level bond/debt rescue.
  - Any curated SEED section force-includes its whole chapter.
The muni/local-government megas and every non-walked division are downloaded WHOLE; the
projected total = (all non-walked divisions) + (selected_final sections here).

Inputs : 260625_megachapter_selection.csv, 260625_megachapter_sections.csv,
         260625_final15_count.csv, 260625_final15_seed_manifest.csv
Outputs: same review + allowlist CSVs, with a `selected_final` column (UTF-8+BOM).

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260625_finalize_chapters.py
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import polars as pl

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
REVIEW = DOCS / "260625_megachapter_selection.csv"
ALLOW = DOCS / "260625_megachapter_sections.csv"
COUNT = DOCS / "260625_final15_count.csv"
SEED = DOCS / "260625_final15_seed_manifest.csv"
# User-pruned title selection (authoritative whole-division keep/drop). effective
# include = "N" where include_jh=="N", else the original `include`. Whole divisions in
# the projection (and the eventual download) are filtered to this set, so the 5
# false-include drops (IA title-i, PA title-5, RI title-4, KS chapter-1, NV chapter-35)
# don't inflate the total.
TITLE_JH = DOCS / "260625_final15_title_selection_jh.csv"

_spec = importlib.util.spec_from_file_location("sc", HERE / "260625_select_chapters.py")
sc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sc)
hits, cat_of = sc.hits, sc.cat_of
NAME_CORE, NAME_DENY = sc.NAME_CORE, sc.NAME_DENY

ELECTION_KEEP = ["referend", "initiative", "special election", "special district",
                 "local election", "consolidated election", "ballot measure",
                 "ballot question", "ballot proposition", "measure", "proposition",
                 "local option", "bond election", "bond", "election on",
                 "submission", "questions submitted", "municipal election"]
ELECTION_DENY = ["campaign", "conduct of election", "administration", "contest",
                 "recount", "registration", "primary", "absentee", "canvass",
                 "precinct", "voting machine", "qualification of", "poll",
                 "ethics", "challenge", "printing", "supplies", "vote by mail",
                 "ballot order", "forms of ballot"]
# Utilities: keep chapters about financing the utility, not regulating it.
UTIL_KEEP = ["bond", "debt", "borrow", "indebted", "obligation", "financ",
             "revenue bond", "sinking fund", "improvement", "assessment",
             "purchase", "acquisition", "municipal"]

FIN_HEAD = ["bond", "debt", "indebted", "bonded", "sinking fund", "borrow"]


def chapter_decision(category: str, cname: str) -> str:
    if hits(cname, NAME_DENY):
        return "deny"
    if category == "Elections":
        if hits(cname, ELECTION_KEEP) and not hits(cname, ELECTION_DENY):
            return "core"
        return "section"
    if category == "Utilities":
        if hits(cname, UTIL_KEEP):
            return "core"
        return "section"
    if hits(cname, NAME_CORE):
        return "core"
    return "section"


def main() -> None:
    rev = pl.read_csv(REVIEW)
    alw = pl.read_csv(ALLOW)
    seeds = {u.rstrip("/") for u in pl.read_csv(SEED)["url"].to_list() if u} \
        if SEED.exists() else set()

    meta = {(r["state_abbr"], r["div_slug"], r["chapter_key"]):
            (r.get("category") or cat_of(r["div_name"]), r["chapter_name"] or "")
            for r in rev.iter_rows(named=True)}

    def decide_section(r) -> str:
        key = (r["state_abbr"], r["div_slug"], r["chapter_key"])
        category, cname = meta.get(key, ("other", r.get("chapter_name") or ""))
        if r["section_url"].rstrip("/") in seeds:
            return "Y"
        dec = chapter_decision(category, cname)
        if dec == "core":
            return "Y"
        if dec == "deny":
            return "N"
        return "Y" if hits(r["heading"], FIN_HEAD) else "N"

    alw = alw.with_columns(
        pl.struct(["state_abbr", "div_slug", "chapter_key", "section_url", "heading"])
        .map_elements(decide_section, return_dtype=pl.Utf8).alias("selected_final"))

    chap_final = {(r["state_abbr"], r["div_slug"], r["chapter_key"]): r["sf"]
                  for r in alw.group_by(["state_abbr", "div_slug", "chapter_key"]).agg(
                      sf=pl.when((pl.col("selected_final") == "Y").any())
                      .then(pl.lit("Y")).otherwise(pl.lit("N"))).iter_rows(named=True)}
    rev = rev.with_columns(
        pl.struct(["state_abbr", "div_slug", "chapter_key"]).map_elements(
            lambda r: chap_final.get((r["state_abbr"], r["div_slug"], r["chapter_key"]), "N"),
            return_dtype=pl.Utf8).alias("selected_final"))

    sc.write_bom(rev, REVIEW)
    sc.write_bom(alw, ALLOW)

    # ---- projected total: all NON-walked divisions WHOLE + narrowed kept ----------
    walked = set(rev["div_url"].to_list())
    cnt = pl.read_csv(COUNT)
    # effective-included urls from the user's pruned title selection (honors include_jh)
    inc_urls = None
    if TITLE_JH.exists():
        ts = pl.read_csv(TITLE_JH).with_columns(
            pl.when(pl.col("include_jh") == "N").then(pl.lit("N"))
            .otherwise(pl.col("include")).alias("eff"))
        inc_urls = set(ts.filter(pl.col("eff") == "Y")["url"].to_list())
    whole = cnt.filter((pl.col("kind") == "constitution") | (~pl.col("url").is_in(list(walked))))
    if inc_urls is not None:    # drop divisions the user excluded (the 5 false-includes)
        whole = whole.filter(
            (pl.col("kind") == "constitution") | pl.col("url").is_in(list(inc_urls)))
    whole_sec = int(whole["n_sections"].clip(0).sum())
    narrowed_kept = int((alw["selected_final"] == "Y").sum())
    narrowed_full = alw.height

    print("Walked megas:", rev["div_url"].n_unique(),
          "| chapters:", rev.height, "| sections walked:", narrowed_full)
    bycat = (rev.group_by("category").agg(
        chapters=pl.len(),
        kept_chapters=(pl.col("selected_final") == "Y").sum()).sort("category"))
    with pl.Config(tbl_rows=10):
        print(bycat)
    print(f"\nWalked/narrowed sections kept: {narrowed_kept} of {narrowed_full} "
          f"({100*narrowed_kept/max(1,narrowed_full):.0f}%)")
    print(f"Non-walked divisions kept WHOLE: {whole.height} divisions, {whole_sec} sections "
          f"(FLOOR -- capped muni megas e.g. IN title-36 are larger at download)")
    print(f"PROJECTED DOWNLOAD = {whole_sec} (whole) + {narrowed_kept} (narrowed) "
          f"= {whole_sec + narrowed_kept} sections (floor)")
    print("Review   :", REVIEW)
    print("Allowlist:", ALLOW)
    print("DONE_FINALIZE")


if __name__ == "__main__":
    main()
