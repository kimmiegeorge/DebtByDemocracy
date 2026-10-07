#!/usr/bin/env python3
r"""
260625_select_titles.py  --  Debt by Democracy: state statute AI task

Phase 1, step 2 for the FINAL 15 states. For each state, list the top-level Justia
code divisions and flag which are likely RELEVANT to municipal bond referendum
requirements; add a constitution row. Writes a review CSV the user vets BEFORE any
Phase 2 crawl (Checkpoint 1). Same review schema as the expansion
(260613_expansion_title_selection.csv) so the 260625_ count/narrow scripts reuse it.

Cloudflare: as of 2026-06-25 Justia is in always-challenge mode, so this fetches via
the shared cookie-aware helper (260625_justia_fetch.py) -- NOT the cookie-less fetch()
the expansion's 260613_select_titles.py used (that now 403s). The cookie daemon must
be running and the user must have solved the Turnstile checkbox.

Per-state STRUCTURE (see findings.md "FINAL 15 batch Phase 1 -- Justia structure map"):
  - "title"  : top-level title-/chapter- divisions (CT DE IL IN IA KS NV PA RI SC VA).
               IL chapters (chapter-65 Municipalities, chapter-30 Finance, chapter-10
               Elections, ...) and chapter-based KS/NV all fit here; classify on name.
  - "ranges" : MN groups chapters into chapters-AAA-BBB containers -> descend one level
               to chapter-N divisions (like OR volumes -> chapters).
  - "named"  : MD (named articles: local-government, tax-property, election-law, ...)
               and NY (consolidated laws by abbreviation: lfn Local Finance, gmu
               General Municipal, eln Election, ...). Single-segment undated divisions;
               classify on the LINK TEXT (the slug is opaque, e.g. "lfn").
  HAWAII IS EXCLUDED (no independent city governments; user-confirmed 2026-06-25).

Classifier (bakes in the expansion's user-pruning refinements, findings.md
"Classifier refinements"): STRONG/MEDIUM/WEAK topic tiers, but a DENY name
(court/surety/bail/official-bond/oath/contractor/collection-agency/consumer-finance/
probate) downgrades even a STRONG hit out of core (include=N) -- those are fidelity/
surety/court bonds, not municipal debt. A curated SEED division always stays core.

RESUMABLE: appends per state, skips states already in the output, so a cookie-expiry
death is recovered by re-running. Self-logs via a Tee.

Inputs : Data\Statutes\documentation\260625_final15_seed_manifest.csv
Outputs: Data\Statutes\documentation\260625_final15_title_selection.csv  (review)
Log    : Data\Statutes\documentation\260625_select_titles_log.txt

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260625_select_titles.py
  ...\260625_select_titles.py --states NY,MD     (subset)
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import sys
import time
from datetime import datetime
from pathlib import Path

import polars as pl
from bs4 import BeautifulSoup

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# --- Paths ---------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
SEED_IN = DOCS / "260625_final15_seed_manifest.csv"
OUT = DOCS / "260625_final15_title_selection.csv"
LOG = DOCS / "260625_select_titles_log.txt"

# Shared cookie-aware Justia fetch layer.
_spec = importlib.util.spec_from_file_location("jf", HERE / "260625_justia_fetch.py")
jf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(jf)
BASE = jf.BASE
DeadLink, Blocked = jf.DeadLink, jf.Blocked

DELAY = 1.5   # polite delay between index-page fetches (cookie mode is gentle)

# --- State config: abbr -> (name, slug, structure) -----------------------------
STATES = {
    "CT": ("Connecticut", "connecticut", "title"),
    "DE": ("Delaware", "delaware", "title"),
    "IL": ("Illinois", "illinois", "title"),        # top level = chapter-N (ILCS topics)
    "IN": ("Indiana", "indiana", "title"),
    "IA": ("Iowa", "iowa", "title"),                # roman-numeral title-ix etc.
    "KS": ("Kansas", "kansas", "title"),            # chapter-based
    "MD": ("Maryland", "maryland", "named"),        # named articles
    "MN": ("Minnesota", "minnesota", "ranges"),     # chapters-AAA-BBB -> chapter-N
    "NV": ("Nevada", "nevada", "title"),            # chapter-based, statute- leaves
    "NY": ("New York", "new-york", "named"),        # consolidated laws by abbr
    "PA": ("Pennsylvania", "pennsylvania", "title"),
    "RI": ("Rhode Island", "rhode-island", "title"),
    "SC": ("South Carolina", "south-carolina", "title"),
    "VA": ("Virginia", "virginia", "title"),
}
ORDER = list(STATES)

# --- Topic keywords (same tiers as pilot/expansion) ----------------------------
STRONG = [
    "municipal", "municipalit", "cities", "town", "village",
    "local government", "finance", "fiscal", "debt", "bond", "indebted",
    "borrow", "revenue",
]
MEDIUM = ["election", "referend", "ballot", "utilit", "public works", "improvement",
          "streets and highways"]
WEAK = ["county", "counties", "local", "taxation", "general provision", "borough"]
# DENY: downgrade even a STRONG hit OUT of core (fidelity/surety/court/private finance,
# not municipal debt). From the expansion's user-prune refinements (findings.md).
DENY = ["court", "bondsm", "bail", "surety", "contractor", "oath",
        "collection agenc", "consumer finance", "probate", "notaries", "notary"]

PREFIX_RE = re.compile(r"/((?:title|chapter)-[^/]+)/?$")          # title-/chapter- division
RANGE_RE = re.compile(r"/(chapters-[^/]+)/?$")                    # MN chapters-AAA-BBB container
RANGE_CHAP_RE = re.compile(r"/chapters-[^/]+/(chapter-[^/]+)/?$")  # chapter under a range


def write_csv_bom(df: pl.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(df.write_csv(), encoding="utf-8-sig")


class _Tee:
    def __init__(self, *st):
        self.st = st

    def write(self, s):
        for x in self.st:
            try:
                x.write(s); x.flush()
            except Exception:
                pass

    def flush(self):
        for x in self.st:
            try:
                x.flush()
            except Exception:
                pass


def _start_logging() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    fh = open(LOG, "a", encoding="utf-8")
    sys.stdout = _Tee(sys.stdout, fh)
    sys.stderr = sys.stdout


def _abs(href: str) -> str:
    return BASE + href if href.startswith("/") else href


def latest_year(slug: str) -> str:
    html = jf.fetch(f"{BASE}/codes/{slug}/")
    years = sorted(re.findall(rf"/codes/{slug}/(\d{{4}})/?", html), reverse=True)
    return years[0] if years else ""


def _links(html: str, pattern: re.Pattern) -> list[tuple[str, str]]:
    """(text, absolute_url) for anchors whose href matches pattern; de-duped, order kept."""
    soup = BeautifulSoup(html, "lxml")
    out, seen = [], set()
    for a in soup.find_all("a", href=True):
        if not pattern.search(a["href"]):
            continue
        href = _abs(a["href"])
        if href in seen:
            continue
        seen.add(href)
        out.append((a.get_text(strip=True), href))
    return out


def divisions_for(slug: str, struct: str, year: str) -> list[tuple[str, str]]:
    """(name, url) top-level statute divisions for one state."""
    yidx = f"{BASE}/codes/{slug}/{year}/" if year else f"{BASE}/codes/{slug}/"
    html = jf.fetch(yidx)

    if struct == "title":
        return _links(html, PREFIX_RE)

    if struct == "ranges":   # MN: chapters-AAA-BBB containers -> chapter-N divisions
        out, seen = [], set()
        for _, curl in _links(html, RANGE_RE):
            time.sleep(DELAY)
            try:
                sub = jf.fetch(curl)
            except (DeadLink, Blocked):
                continue
            for name, href in _links(sub, RANGE_CHAP_RE):
                if href not in seen:
                    seen.add(href)
                    out.append((name, href))
        return out

    if struct == "named":    # MD / NY: single-segment named divisions (undated)
        pat = re.compile(rf"/codes/{slug}/[^/]+/?$")
        divs = _links(html, pat)
        # Drop the year link itself and any pure-digit (year) segment.
        clean = []
        for name, url in divs:
            last = url.rstrip("/").split("/")[-1]
            if last.isdigit() or last == slug:
                continue
            clean.append((name, url))
        return clean

    return []


def justia_seed_urls(seed: pl.DataFrame, abbr: str) -> list[str]:
    urls = []
    for url in seed.filter(pl.col("state_abbr") == abbr)["url"].to_list():
        if url and "law.justia.com/codes/" in url:
            urls.append(url.rstrip("/"))
    return urls


def div_slug_of(url: str) -> str:
    segs = [s for s in url.rstrip("/").split("/") if s]
    return segs[-1] if segs else ""


def classify_div(name: str, is_seed: bool) -> tuple[str, str, str]:
    low = name.lower()
    strong = [k for k in STRONG if k in low]
    medium = [k for k in MEDIUM if k in low]
    weak = [k for k in WEAK if k in low]
    deny = [k for k in DENY if k in low]
    hits = ";".join(strong + medium + weak)
    if is_seed:
        tier = "core"                       # curated seed always stays core
    elif strong and not deny:
        tier = "core"
    elif strong and deny:
        tier = "weak"                       # downgraded surety/court/etc. -> default OUT
    elif medium and not deny:
        tier = "maybe"
    elif weak:
        tier = "weak"
    else:
        tier = ""
    matched = ";".join(filter(None, [
        "seed" if is_seed else "",
        "strong" if strong else "", "medium" if medium else "", "weak" if weak else "",
        "DENY" if deny else "",
    ]))
    return tier, matched, hits


def done_states() -> set[str]:
    if not OUT.exists():
        return set()
    try:
        return set(pl.read_csv(OUT)["state_abbr"].to_list())
    except Exception:
        return set()


def rows_for_state(abbr: str, name: str, slug: str, struct: str,
                   seed: pl.DataFrame) -> list[dict]:
    year = latest_year(slug)
    time.sleep(DELAY)
    jseeds = justia_seed_urls(seed, abbr)
    try:
        divs = divisions_for(slug, struct, year)
    except (DeadLink, Blocked) as e:
        print("   !! division list failed:", e)
        divs = []
    time.sleep(DELAY)

    rows, n_core, n_maybe = [], 0, 0
    for dname, durl in divs:
        durl_n = durl.rstrip("/")
        # Require a path boundary so a slug doesn't prefix-match a longer one (e.g.
        # title-i must NOT match a seed under title-ix; chapter-1 not chapter-10).
        is_seed = any(s == durl_n or s.startswith(durl_n + "/") for s in jseeds)
        tier, matched, kw = classify_div(dname, is_seed)
        include = "Y" if tier in ("core", "maybe") else "N"
        n_core += tier == "core"
        n_maybe += tier == "maybe"
        rows.append({
            "state_abbr": abbr, "state_name": name, "slug": slug,
            "latest_year": year, "kind": "statute", "div_slug": div_slug_of(durl),
            "name": dname, "url": durl, "tier": tier,
            "matched_by": matched, "kw_hits": kw, "include": include,
        })

    curl = f"{BASE}/constitution/{slug}/"
    try:
        jf.fetch(curl)
        cstatus = "ok"
    except (DeadLink, Blocked):
        cstatus = "CHECK"
    rows.append({
        "state_abbr": abbr, "state_name": name, "slug": slug,
        "latest_year": year, "kind": "constitution", "div_slug": "",
        "name": f"{name} Constitution", "url": curl, "tier": "core",
        "matched_by": "always", "kw_hits": cstatus, "include": "Y",
    })
    time.sleep(DELAY)
    print(f"     {abbr} ({struct}) divisions: {len(divs)}  core: {n_core}  maybe: {n_maybe}  "
          f"seed-urls: {len(jseeds)}  constitution: {cstatus}  year: {year}")
    return rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--states", default="", help="comma list e.g. NY,MD (default all 14)")
    args = ap.parse_args()

    if not SEED_IN.exists():
        raise SystemExit(f"Run 260625_build_seed_manifest.py first; missing {SEED_IN}")
    seed = pl.read_csv(SEED_IN)

    jf.start_cookie_mode()   # 2026-06-25: IP is challenged; skip the doomed plain attempt

    only = {s.strip().upper() for s in args.states.split(",") if s.strip()} or None
    already = done_states()
    if already:
        print("Resuming; already done:", sorted(already))

    todo = []
    for abbr, (nm, sl, st) in STATES.items():
        if abbr in already:
            continue
        if only and abbr not in only:
            continue
        todo.append((abbr, nm, sl, st))

    t0 = time.time()
    for idx, (abbr, name, slug, struct) in enumerate(todo, 1):
        el = time.time() - t0
        eta = (el / (idx - 1) * (len(todo) - idx + 1)) if idx > 1 else 0
        print(f"[{idx}/{len(todo)}] {name} ({slug}, {struct})  elapsed {el:5.1f}s  eta ~{eta:4.0f}s")
        rows = rows_for_state(abbr, name, slug, struct, seed)
        df_new = pl.DataFrame(rows)
        if OUT.exists():
            df_new = pl.concat([pl.read_csv(OUT), df_new], how="vertical_relaxed")
        write_csv_bom(df_new, OUT)

    if not OUT.exists():
        print("No output produced.")
        return
    df = pl.read_csv(OUT)
    print("\nWrote:", OUT, " rows:", df.height, " states:", df["state_abbr"].n_unique())
    summary = (
        df.filter(pl.col("kind") == "statute")
        .group_by("state_abbr")
        .agg(n_div=pl.len(),
             n_core=(pl.col("tier") == "core").sum(),
             n_maybe=(pl.col("tier") == "maybe").sum(),
             n_include=(pl.col("include") == "Y").sum())
        .with_columns(pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o"))
        .sort("_o").drop("_o")
    )
    with pl.Config(tbl_rows=30):
        print(summary)
    chk = df.filter((pl.col("kind") == "constitution") & (pl.col("kw_hits") == "CHECK"))
    if chk.height:
        print("Constitution index needs manual check for:", chk["state_abbr"].to_list())
    print("DONE_SELECT_TITLES")


if __name__ == "__main__":
    _start_logging()
    print(f"\n===== 260625_select_titles start @ "
          f"{datetime.now().isoformat(timespec='seconds')} =====")
    main()
