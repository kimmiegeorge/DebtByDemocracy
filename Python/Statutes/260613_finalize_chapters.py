#!/usr/bin/env python3
r"""
260613_finalize_chapters.py  --  Debt by Democracy: state statute AI task

Phase 2, step 2c for the EXPANSION batch. Applies CATEGORY-AWARE narrowing to the
walked-chapter output (260613_select_chapters.py) and writes a `selected_final`
flag onto both the chapter review and the per-section allowlist. Local only
(no network); re-runnable; iterate the keyword rules here freely.

Per the user's tightening decision (2026-06-14):
  - ELECTIONS divisions: keep ONLY chapters about putting a question to voters
    (referendum / initiative / special election / ballot / bond-or-debt election);
    drop general machinery (registration, primary, conduct, administration,
    contests/recounts, campaign finance, absentee, canvass). Inside dropped
    chapters, still keep individual sections whose heading is bond/debt-specific.
  - REVENUE & TAXATION divisions: keep ONLY bond / debt / special-assessment /
    debt-service / improvement chapters; drop general tax administration. Section-
    level bond/debt rescue inside dropped chapters.
  - ALL OTHER megas (Muni/Local, Public Finance, Utilities, charters, misc): the
    standard rule -- keep CORE chapters by name (bond/finance/election/municipal),
    drop deny (surety/court/officer/repealed/...), section-level bond rescue in
    generic chapters.
  - Any curated SEED section force-includes its whole chapter.

Non-mega Muni/Local, Public-Finance, Utilities and 'Other' (incl. constitutions)
divisions are NOT walked and are downloaded WHOLE; this script reports the projected
total = (those whole divisions) + (selected_final sections here).

Inputs : 260613_megachapter_selection.csv, 260613_megachapter_sections.csv,
         260613_expansion_count.csv, 260613_expansion_seed_manifest.csv
Outputs: same review + allowlist CSVs, with a `selected_final` column (UTF-8+BOM).

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260613_finalize_chapters.py
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
REVIEW = DOCS / "260613_megachapter_selection.csv"
ALLOW = DOCS / "260613_megachapter_sections.csv"
COUNT = DOCS / "260613_expansion_count.csv"
SEED = DOCS / "260613_expansion_seed_manifest.csv"

# Reuse helpers + keyword sets from the walk script.
_spec = importlib.util.spec_from_file_location("sc", HERE / "260613_select_chapters.py")
sc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sc)
hits, cat_of = sc.hits, sc.cat_of
NAME_CORE, NAME_DENY = sc.NAME_CORE, sc.NAME_DENY

# Category-specific KEEP-whole-chapter name rules. For elections we keep ONLY the
# chapters about putting a QUESTION to voters (referendum/initiative/local/special/
# consolidated elections, ballot measures, bond/debt elections) -- NOT general
# ballot mechanics, registration, primaries, conduct. Bare "ballot" is too broad
# (matches ballot-printing/forms), so we require "ballot measure"/"ballot question".
ELECTION_KEEP = ["referend", "initiative", "special election", "special district",
                 "local election", "consolidated election", "ballot measure",
                 "ballot question", "ballot proposition", "measure", "proposition",
                 "local option", "bond election", "bond", "election on",
                 "submission", "questions submitted"]
ELECTION_DENY = ["campaign", "conduct of election", "administration", "contest",
                 "recount", "registration", "primary", "absentee", "canvass",
                 "precinct", "voting machine", "qualification of", "poll",
                 "ethics", "challenge", "printing", "supplies", "vote by mail",
                 "voter", "ballot order", "forms of ballot"]
REVTAX_KEEP = ["bond", "debt", "special assessment", "assessment", "sinking fund",
               "debt service", "improvement", "local improvement"]

# Section-heading rescue sets (financial-only; election/ballot are ambient in
# election codes and would defeat narrowing there).
FIN_HEAD = ["bond", "debt", "indebted", "bonded", "sinking fund", "borrow"]
OTHER_HEAD = FIN_HEAD + ["referend", "ballot", "election"]   # ok in non-election titles


def chapter_decision(category: str, cname: str) -> str:
    """'core' (keep whole), 'section' (keep only rescued sections), or 'deny'."""
    if hits(cname, NAME_DENY):
        return "deny"
    if category == "Elections":
        if hits(cname, ELECTION_KEEP) and not hits(cname, ELECTION_DENY):
            return "core"
        return "section"
    if category == "RevTax":
        if hits(cname, REVTAX_KEEP):
            return "core"
        return "section"
    if hits(cname, NAME_CORE):
        return "core"
    return "section"


def head_set(category: str):
    return FIN_HEAD if category in ("Elections", "RevTax") else OTHER_HEAD


def main() -> None:
    rev = pl.read_csv(REVIEW)
    alw = pl.read_csv(ALLOW)
    seeds = {u.rstrip("/") for u in pl.read_csv(SEED)["url"].to_list() if u} \
        if SEED.exists() else set()

    # (state, div_slug, chapter_key) -> (category, chapter_name)
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
        return "Y" if hits(r["heading"], head_set(category)) else "N"   # section rescue

    alw = alw.with_columns(
        pl.struct(["state_abbr", "div_slug", "chapter_key", "section_url", "heading"])
        .map_elements(decide_section, return_dtype=pl.Utf8).alias("selected_final")
    )

    # roll up to chapters
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

    # ---- projected total ------------------------------------------------------
    cnt = pl.read_csv(COUNT)
    cnt = cnt.with_columns(pl.col("name").map_elements(cat_of, return_dtype=pl.Utf8).alias("cat"))
    whole = cnt.filter(
        (pl.col("kind") == "constitution")
        | ((pl.col("kind") == "statute") & (pl.col("n_sections") < 800)
           & (pl.col("cat") == "other")))
    whole_sec = int(whole["n_sections"].clip(0).sum())
    narrowed_kept = int((alw["selected_final"] == "Y").sum())
    narrowed_full = alw.height

    print("Walked divisions:", rev["div_url"].n_unique(),
          "| chapters:", rev.height, "| sections in walked:", narrowed_full)
    bycat = (rev.group_by("category").agg(
        chapters=pl.len(),
        kept_chapters=(pl.col("selected_final") == "Y").sum()).sort("category"))
    with pl.Config(tbl_rows=10):
        print(bycat)
    print(f"\nWalked/narrowed sections kept: {narrowed_kept} of {narrowed_full} "
          f"({100*narrowed_kept/narrowed_full:.0f}%)")
    print(f"Non-walked divisions kept WHOLE: {whole.height} divisions, {whole_sec} sections")
    print(f"PROJECTED DOWNLOAD = {whole_sec} (whole) + {narrowed_kept} (narrowed) "
          f"= {whole_sec + narrowed_kept} sections")
    print("Review   :", REVIEW)
    print("Allowlist:", ALLOW)
    print("DONE_FINALIZE")


if __name__ == "__main__":
    main()
