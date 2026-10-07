#!/usr/bin/env python3
r"""
260611_select_titles.py  --  Debt by Democracy: state statute AI task

Phase 1, step 2. For each of the 10 pilot states, list the top-level divisions
(titles, or chapters for KY/WI) of the latest (2025) Justia code edition, and flag
which ones are likely RELEVANT to municipal bond referendum requirements. Also add
a row for the state constitution. Writes a review CSV that the user vets BEFORE the
full crawl (Phase 2) runs.

Relevance flag = "keyword" (division name matches a topic keyword) and/or "seed"
(a curated seed URL from 260611_pilot_seed_manifest.csv falls inside that
division). A division is marked include=Y if either fires. Erring toward inclusion
is fine here because the user prunes the list; matched_by tells them why.

Justia notes (see documentation\findings.md):
- Justia is behind Cloudflare; fetched via curl_cffi impersonate=chrome124.
- /codes/<slug>/2025/ lists titles; title links are un-dated (= latest = 2025).
- KY/WI are chapter-based at the top level (chapter- instead of title-).

Inputs
------
  Data\Statutes\documentation\260611_pilot_seed_manifest.csv   (from step 1)

Outputs
-------
  Data\Statutes\documentation\260611_title_selection.csv       (for user review)

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260611_select_titles.py
"""
from __future__ import annotations

import sys
import time
import re
from pathlib import Path

import polars as pl
from bs4 import BeautifulSoup
from curl_cffi import requests as creq

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# --- Paths ---------------------------------------------------------------------
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
SEED_IN = DOCS / "260611_pilot_seed_manifest.csv"
OUT = DOCS / "260611_title_selection.csv"

# --- Pilot states: abbr -> (name, justia slug) ---------------------------------
PILOT = {
    "AL": ("Alabama", "alabama"), "AK": ("Alaska", "alaska"),
    "AZ": ("Arizona", "arizona"), "KY": ("Kentucky", "kentucky"),
    "MA": ("Massachusetts", "massachusetts"), "MS": ("Mississippi", "mississippi"),
    "NH": ("New Hampshire", "new-hampshire"), "NJ": ("New Jersey", "new-jersey"),
    "TN": ("Tennessee", "tennessee"), "WI": ("Wisconsin", "wisconsin"),
}

# Topic keywords, tiered so the (sometimes long) chapter lists sort themselves:
#   STRONG  -> tier "core"  : city government + borrowing/debt -> the heart of it
#   MEDIUM  -> tier "maybe"  : process/context (elections, utilities, public works)
#   WEAK    -> tier "weak"  : too broad to crawl on its own (county/tax/boilerplate)
# A division with only WEAK hits defaults to include=N (shown for awareness). A
# seed division is always "core". Word-ish matching on the lower-cased name.
STRONG = [
    "municipal", "municipalit", "cities", "town", "village",
    "local government", "finance", "fiscal", "debt", "bond", "indebted",
    "borrow", "revenue",
]
MEDIUM = ["election", "referend", "ballot", "utilit", "public works", "improvement"]
WEAK = ["county", "counties", "local", "taxation", "general provision", "borough"]

# Match a title-/chapter- division as the FINAL path segment, regardless of any
# intermediate containers (e.g. MA titles live under /part-i/title-vii/).
PREFIX_RE = re.compile(r"/((?:title|chapter)-[^/]+)/?$")
# Some states (e.g. MA) nest titles under parts; descend through these.
CONTAINER_RE = re.compile(r"/codes/[a-z0-9-]+/(?:\d{4}/)?(part|subtitle)-[^/]+/?$")
SEED_DIV_RE = re.compile(r"/codes/[a-z0-9-]+/(?:\d{4}/)?((?:title|chapter)-[^/]+)")
IMPERSONATE = "chrome124"


def fetch(url: str, tries: int = 4) -> str:
    """GET via curl_cffi (clears Cloudflare). Retry with backoff on challenge/error."""
    last = None
    for i in range(tries):
        try:
            r = creq.get(url, impersonate=IMPERSONATE, timeout=45)
            if r.status_code == 200 and "Just a moment" not in r.text:
                return r.text
            last = f"status={r.status_code} challenge={'Just a moment' in r.text}"
        except Exception as e:  # network / TLS errors
            last = repr(e)
        time.sleep(2 * (i + 1))
    raise RuntimeError(f"fetch failed for {url}: {last}")


def latest_year(slug: str) -> str:
    """Most recent year edition listed at /codes/<slug>/ (expected 2025)."""
    html = fetch(f"https://law.justia.com/codes/{slug}/")
    years = sorted(re.findall(rf"/codes/{slug}/(\d{{4}})/?", html), reverse=True)
    return years[0] if years else ""


def _divisions_in(html: str) -> list[tuple[str, str]]:
    """(name, absolute_url) for every title-/chapter- link in a page."""
    soup = BeautifulSoup(html, "lxml")
    out, seen = [], set()
    for a in soup.find_all("a", href=True):
        if not PREFIX_RE.search(a["href"]):
            continue
        href = a["href"]
        if href.startswith("/"):
            href = "https://law.justia.com" + href
        if href in seen:
            continue
        seen.add(href)
        out.append((a.get_text(strip=True), href))
    return out


def _containers_in(html: str) -> list[str]:
    """Absolute URLs of part-/subtitle- container links (states that nest, e.g. MA)."""
    soup = BeautifulSoup(html, "lxml")
    out, seen = [], set()
    for a in soup.find_all("a", href=True):
        if not CONTAINER_RE.search(a["href"]):
            continue
        href = a["href"]
        if href.startswith("/"):
            href = "https://law.justia.com" + href
        if href not in seen:
            seen.add(href)
            out.append(href)
    return out


def titles_for(slug: str, year: str) -> list[tuple[str, str]]:
    """Title/chapter divisions for the year edition. If the top level only has
    part/subtitle containers (MA), descend one level into them to reach chapters."""
    html = fetch(f"https://law.justia.com/codes/{slug}/{year}/")
    divs = _divisions_in(html)
    if divs:
        return divs
    # Nested layout: descend into each container and collect chapter-level divisions.
    out, seen = [], set()
    for curl in _containers_in(html):
        time.sleep(2)
        try:
            sub = fetch(curl)
        except RuntimeError:
            continue
        for name, href in _divisions_in(sub):
            if href not in seen:
                seen.add(href)
                out.append((name, href))
    return out


def seed_divisions(seed: pl.DataFrame, abbr: str) -> set[str]:
    """Set of division slugs (title-x/chapter-x) that curated seed URLs point into."""
    divs = set()
    for url in seed.filter(pl.col("state_abbr") == abbr)["url"].to_list():
        if not url or "law.justia.com/codes/" not in url:
            continue
        m = SEED_DIV_RE.search(url)
        if m:
            divs.add(m.group(1).lower())
    return divs


def classify_div(name: str, is_seed: bool) -> tuple[str, str, str]:
    """Return (tier, matched_by, kw_hits) for a division name.
    tier in {core, maybe, weak}; include is derived as Y for core/maybe."""
    low = name.lower()
    strong = [k for k in STRONG if k in low]
    medium = [k for k in MEDIUM if k in low]
    weak = [k for k in WEAK if k in low]
    hits = ";".join(strong + medium + weak)
    if is_seed or strong:
        tier = "core"
    elif medium:
        tier = "maybe"
    elif weak:
        tier = "weak"
    else:
        tier = ""
    matched = ";".join(filter(None, [
        "seed" if is_seed else "",
        "strong" if strong else "", "medium" if medium else "", "weak" if weak else "",
    ]))
    return tier, matched, hits


def main() -> None:
    if not SEED_IN.exists():
        raise SystemExit(f"Run 260611_build_seed_manifest.py first; missing {SEED_IN}")
    seed = pl.read_csv(SEED_IN)

    rows = []
    t0 = time.time()
    states = list(PILOT.items())
    for idx, (abbr, (name, slug)) in enumerate(states, 1):
        el = time.time() - t0
        eta = (el / (idx - 1) * (len(states) - idx + 1)) if idx > 1 else 0
        print(f"[{idx}/{len(states)}] {name} ({slug})  elapsed {el:5.1f}s  eta ~{eta:4.0f}s")

        year = latest_year(slug)
        time.sleep(2)
        sdivs = seed_divisions(seed, abbr)

        try:
            titles = titles_for(slug, year)
        except RuntimeError as e:
            print("   !! title list failed:", e)
            titles = []
        time.sleep(2)

        n_core = n_maybe = 0
        for tname, turl in titles:
            mslug = PREFIX_RE.search(turl)
            dslug = mslug.group(1).lower() if mslug else ""
            is_seed = dslug in sdivs
            tier, matched, kw = classify_div(tname, is_seed)
            include = "Y" if tier in ("core", "maybe") else "N"
            n_core += tier == "core"
            n_maybe += tier == "maybe"
            rows.append({
                "state_abbr": abbr, "state_name": name, "slug": slug,
                "latest_year": year, "kind": "statute", "div_slug": dslug,
                "name": tname, "url": turl, "tier": tier,
                "matched_by": matched, "kw_hits": kw, "include": include,
            })

        # Constitution row (small; always include). Confirm the index resolves.
        curl = f"https://law.justia.com/constitution/{slug}/"
        try:
            fetch(curl)
            cstatus = "ok"
        except RuntimeError:
            cstatus = "CHECK"
        rows.append({
            "state_abbr": abbr, "state_name": name, "slug": slug,
            "latest_year": year, "kind": "constitution", "div_slug": "",
            "name": f"{name} Constitution", "url": curl, "tier": "core",
            "matched_by": "always", "kw_hits": cstatus, "include": "Y",
        })
        time.sleep(2)
        print(f"     titles: {len(titles)}  core: {n_core}  maybe: {n_maybe}  "
              f"seed-divs: {sorted(sdivs)}  constitution: {cstatus}")

    df = pl.DataFrame(rows)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.write_csv(OUT)

    print("\nWrote:", OUT)
    summary = (
        df.filter(pl.col("kind") == "statute")
        .group_by("state_abbr")
        .agg(
            n_titles=pl.len(),
            n_core=(pl.col("tier") == "core").sum(),
            n_maybe=(pl.col("tier") == "maybe").sum(),
        )
        .with_columns(pl.col("state_abbr").cast(pl.Enum(list(PILOT))).to_physical().alias("_o"))
        .sort("_o").drop("_o")
    )
    with pl.Config(tbl_rows=20):
        print(summary)
    print("\nCORE statute titles (recommended crawl set, for review):")
    for r in df.filter((pl.col("kind") == "statute") & (pl.col("tier") == "core")).iter_rows(named=True):
        print(f"  {r['state_abbr']}  {r['name'][:46]:46s}  [{r['matched_by']}: {r['kw_hits']}]")


if __name__ == "__main__":
    main()
