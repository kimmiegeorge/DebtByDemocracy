#!/usr/bin/env python3
r"""
260611_select_chapters.py  --  Debt by Democracy: state statute AI task

Phase 2, step 2b. The pilot's "mega-titles" are entire municipal/county codes
(thousands of sections). Per the user's decision (2026-06-11) we keep small/
on-point titles WHOLE but NARROW these mega-titles to the chapters governing
bonds / debt / finance / elections. This script walks each mega-title, groups its
sections by chapter, flags chapters that contain bond/finance/election language,
and writes:

  documentation\260611_chapter_selection.csv   (chapter-level review summary)
  documentation\260611_megatitle_sections.csv  (section allowlist for the crawler)

Selection rule: include a CHAPTER whole if its name OR any of its section headings
matches the finance/vote keyword set. Granularity by structure:
  - chaptered titles (AL T11, MA T-VII, NH T-III, TN T6/T7): real chapters.
  - NJ T40/T40A flat: chapter = numeric component of the section id (40a-2-...).
  - AZ T11 flat counties: no clean chapter encoding -> section-level selection.

Reuses fetch/parse helpers from 260611_download_statutes.py. Re-runnable; pause
for user review of the chapter summary before the crawl.
"""
from __future__ import annotations

import importlib.util
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import polars as pl
from bs4 import BeautifulSoup

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
TITLE_CSV = DOCS / "260611_title_selection.csv"
REVIEW_OUT = DOCS / "260611_chapter_selection.csv"
ALLOW_OUT = DOCS / "260611_megatitle_sections.csv"

# Load the download module for shared helpers (fetch, segs, abs_url).
_spec = importlib.util.spec_from_file_location("dl", HERE / "260611_download_statutes.py")
dl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dl)
dl.DELAY = 0.6

# Mega-titles to narrow (state, div_slug). URLs are read from the title CSV.
MEGA = {("AL", "title-11"), ("AZ", "title-11"), ("MA", "title-vii"),
        ("NH", "title-iii"), ("NJ", "title-40"), ("NJ", "title-40a"),
        ("TN", "title-6"), ("TN", "title-7")}

# Heading/chapter-name keywords that mark a chapter as bond/finance/vote relevant.
KW = ["bond", "debt", "borrow", "indebted", "obligation", "financ", "fiscal",
      "referend", "election", "ballot", "sinking fund", "note", "loan",
      "revenue", "appropriat", "budget", "tax"]
# Tighter set for naming the trigger (avoid 'tax'/'budget' dominating display).
CORE_KW = ["bond", "debt", "borrow", "indebted", "obligation", "financ",
           "referend", "election", "ballot"]


def segs(u: str):
    return [s for s in urlparse(u).path.strip("/").split("/") if s]


def kw_hits(text: str, kws=KW) -> str:
    low = (text or "").lower()
    return ";".join(k for k in kws if k in low)


def chapter_key(url: str) -> str | None:
    """Group key for a section URL: real chapter dir, or NJ numeric chapter, else None."""
    m = re.search(r"/(chapter-[^/]+)/", url)
    if m:
        return m.group(1)
    # flat section id: section-<a>-<b>-<c...>  -> chapter = <a>-<b> (NJ style)
    m = re.search(r"/section-([0-9]+[a-z]?)-([0-9]+[a-z]?)-[0-9a-z.]+/?$", url)
    if m:
        return f"{m.group(1)}-{m.group(2)}"
    return None  # AZ-style 2-part id -> section-level


def _children_with_text(page_url: str, html: str):
    base = segs(page_url); bl = len(base)
    soup = BeautifulSoup(html, "lxml")
    out, seen = [], set()
    for a in soup.find_all("a", href=True):
        h = dl.abs_url(a["href"])
        s = segs(h)
        if len(s) == bl + 1 and s[:bl] == base and h not in seen:
            seen.add(h)
            out.append((s[-1], h, a.get_text(strip=True)))
    return out


def walk(div_url: str):
    """Return (sections, chap_names): sections=[(url,heading)], chap_names={key:name}."""
    visited, stack = set(), [div_url]
    sections, chap_names = [], {}
    while stack:
        u = stack.pop()
        if u in visited:
            continue
        visited.add(u)
        html = dl.fetch(u)
        time.sleep(dl.DELAY)
        for seg, curl, text in _children_with_text(u, html):
            if seg.startswith("section-"):
                sections.append((curl, text))
            else:
                if seg.startswith("chapter-"):
                    chap_names[seg] = text
                if curl not in visited:
                    stack.append(curl)
    return sections, chap_names


def main() -> None:
    tdf = pl.read_csv(TITLE_CSV)
    review_rows, allow_rows = [], []

    for st, slug in sorted(MEGA):
        row = tdf.filter((pl.col("state_abbr") == st) & (pl.col("div_slug") == slug))
        if row.height == 0:
            print(f"!! {st} {slug} not in title CSV; skipping")
            continue
        div_url = row["url"][0]
        name = row["name"][0]
        print(f"\n== {st} {slug}  {name[:50]}")
        t0 = time.time()
        sections, chap_names = walk(div_url)
        print(f"   {len(sections)} sections, {len(chap_names)} chapters ({time.time()-t0:.0f}s)")

        # group sections by chapter key
        groups: dict[str, list[tuple[str, str]]] = {}
        for url, heading in sections:
            groups.setdefault(chapter_key(url) or "(section-level)", []).append((url, heading))

        for ckey, items in groups.items():
            cname = chap_names.get(ckey, "")
            if ckey == "(section-level)":
                # AZ flat: select individual matched sections
                for url, heading in items:
                    hit = kw_hits(heading, CORE_KW)
                    sel = "Y" if hit else "N"
                    allow_rows.append({"state_abbr": st, "div_slug": slug,
                                       "chapter_key": ckey, "section_url": url,
                                       "heading": heading, "selected": sel})
                n_sel = sum(1 for u, h in items if kw_hits(h, CORE_KW))
                trig = "; ".join(h[:40] for u, h in items if kw_hits(h, CORE_KW))[:160]
                review_rows.append({"state_abbr": st, "div_slug": slug, "chapter_key": ckey,
                                    "chapter_name": "(individual sections)", "n_sections": len(items),
                                    "n_matched": n_sel, "selected": "Y" if n_sel else "N",
                                    "triggers": trig})
            else:
                matched = [(u, h) for u, h in items if kw_hits(h)]
                name_hit = kw_hits(cname)
                sel = "Y" if (matched or name_hit) else "N"
                for url, heading in items:
                    allow_rows.append({"state_abbr": st, "div_slug": slug,
                                       "chapter_key": ckey, "section_url": url,
                                       "heading": heading, "selected": sel})
                trig = name_hit or "; ".join(h[:40] for u, h in matched)[:160]
                review_rows.append({"state_abbr": st, "div_slug": slug, "chapter_key": ckey,
                                    "chapter_name": cname[:60], "n_sections": len(items),
                                    "n_matched": len(matched), "selected": sel,
                                    "triggers": trig})

    rev = pl.DataFrame(review_rows)
    alw = pl.DataFrame(allow_rows)
    rev.write_csv(REVIEW_OUT)
    alw.write_csv(ALLOW_OUT)

    sel_secs = int((alw["selected"] == "Y").sum())
    print("\n================ SUMMARY ================")
    by = (rev.group_by("state_abbr").agg(
        chapters=pl.len(),
        chapters_selected=(pl.col("selected") == "Y").sum(),
        sections_total=pl.col("n_sections").sum(),
    ).sort("state_abbr"))
    with pl.Config(tbl_rows=20):
        print(by)
    print(f"\nMega-title sections TOTAL: {alw.height} | SELECTED to crawl: {sel_secs}")
    print("Review file :", REVIEW_OUT)
    print("Allowlist   :", ALLOW_OUT)


if __name__ == "__main__":
    main()
