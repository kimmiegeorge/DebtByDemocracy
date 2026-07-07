#!/usr/bin/env python3
r"""
260613_select_titles.py  --  Debt by Democracy: state statute AI task

Phase 1, step 2 for the EXPANSION batch (25 states). For each state, list the
top-level divisions (titles, or chapters for chapter-based states) of the latest
Justia code edition and flag which are likely RELEVANT to municipal bond
referendum requirements; add a constitution row. Writes a review CSV the user vets
BEFORE any Phase 2 crawl. Same logic as the pilot's 260611_select_titles.py.

RESUMABLE: appends per state and skips states already present in the output CSV, so
a death mid-run (e.g. the Claude app/session being switched, which reaps shell-
spawned jobs) is recovered by simply re-running. Intended to run DETACHED via the
Windows Task Scheduler for the same reason.

Justia notes (documentation\findings.md):
- Justia is behind Cloudflare; fetched via curl_cffi impersonate=chrome124.
- /codes/<slug>/<year>/ lists titles; title links are un-dated (= latest).
- Some states nest titles under part-/subtitle- containers; descend one level.

Inputs : Data\Statutes\documentation\260613_expansion_seed_manifest.csv  (step 1)
Outputs: Data\Statutes\documentation\260613_expansion_title_selection.csv (review)
Log    : Data\Statutes\documentation\260613_select_titles_log.txt (when detached)

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260613_select_titles.py
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
SEED_IN = DOCS / "260613_expansion_seed_manifest.csv"
OUT = DOCS / "260613_expansion_title_selection.csv"
LOG = DOCS / "260613_select_titles_log.txt"


class _Tee:
    """Write prints to both the console and the log file, so a DETACHED Task
    Scheduler run (no console) still leaves a readable progress log to monitor."""

    def __init__(self, *streams):
        self.streams = streams

    def write(self, s):
        for st in self.streams:
            try:
                st.write(s)
                st.flush()
            except Exception:
                pass

    def flush(self):
        for st in self.streams:
            try:
                st.flush()
            except Exception:
                pass


def _start_logging() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    fh = open(LOG, "a", encoding="utf-8")
    sys.stdout = _Tee(sys.stdout, fh)
    sys.stderr = sys.stdout


def write_csv_bom(df: pl.DataFrame, path: Path) -> None:
    """Write the review CSV as UTF-8 WITH BOM (utf-8-sig). Excel on Windows defaults
    to cp1252 and otherwise mangles non-ASCII into mojibake (the 'A-hat'/'a-euro'
    glyphs); the BOM makes Excel decode UTF-8, so statute symbols like the section
    sign and curly apostrophes (e.g. Oregon's "People's Utility Districts") render
    correctly. polars read_csv strips the BOM, so the resumable re-reads are safe."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(df.write_csv(), encoding="utf-8-sig")

# --- Expansion states: abbr -> (name, justia slug) -----------------------------
EXPANSION = {
    "AR": ("Arkansas", "arkansas"),       "CA": ("California", "california"),
    "CO": ("Colorado", "colorado"),       "FL": ("Florida", "florida"),
    "GA": ("Georgia", "georgia"),         "ID": ("Idaho", "idaho"),
    "LA": ("Louisiana", "louisiana"),     "ME": ("Maine", "maine"),
    "MI": ("Michigan", "michigan"),       "MO": ("Missouri", "missouri"),
    "MT": ("Montana", "montana"),         "NE": ("Nebraska", "nebraska"),
    "NM": ("New Mexico", "new-mexico"),   "NC": ("North Carolina", "north-carolina"),
    "ND": ("North Dakota", "north-dakota"), "OH": ("Ohio", "ohio"),
    "OK": ("Oklahoma", "oklahoma"),       "OR": ("Oregon", "oregon"),
    "SD": ("South Dakota", "south-dakota"), "TX": ("Texas", "texas"),
    "UT": ("Utah", "utah"),               "VT": ("Vermont", "vermont"),
    "WA": ("Washington", "washington"),   "WV": ("West Virginia", "west-virginia"),
    "WY": ("Wyoming", "wyoming"),
}

# Topic keywords, tiered (same as pilot).
STRONG = [
    "municipal", "municipalit", "cities", "town", "village",
    "local government", "finance", "fiscal", "debt", "bond", "indebted",
    "borrow", "revenue",
]
MEDIUM = ["election", "referend", "ballot", "utilit", "public works", "improvement"]
WEAK = ["county", "counties", "local", "taxation", "general provision", "borough"]

PREFIX_RE = re.compile(r"/((?:title|chapter)-[^/]+)/?$")
CONTAINER_RE = re.compile(r"/codes/[a-z0-9-]+/(?:\d{4}/)?(part|subtitle)-[^/]+/?$")
SEED_DIV_RE = re.compile(r"/codes/[a-z0-9-]+/(?:\d{4}/)?((?:title|chapter)-[^/]+)")
IMPERSONATE = "chrome124"


def fetch(url: str, tries: int = 4) -> str:
    last = None
    for i in range(tries):
        try:
            r = creq.get(url, impersonate=IMPERSONATE, timeout=45)
            if r.status_code == 200 and "Just a moment" not in r.text:
                return r.text
            last = f"status={r.status_code} challenge={'Just a moment' in r.text}"
        except Exception as e:
            last = repr(e)
        time.sleep(2 * (i + 1))
    raise RuntimeError(f"fetch failed for {url}: {last}")


def latest_year(slug: str) -> str:
    html = fetch(f"https://law.justia.com/codes/{slug}/")
    years = sorted(re.findall(rf"/codes/{slug}/(\d{{4}})/?", html), reverse=True)
    return years[0] if years else ""


def _divisions_in(html: str) -> list[tuple[str, str]]:
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
    html = fetch(f"https://law.justia.com/codes/{slug}/{year}/")
    divs = _divisions_in(html)
    if divs:
        return divs
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
    divs = set()
    for url in seed.filter(pl.col("state_abbr") == abbr)["url"].to_list():
        if not url or "law.justia.com/codes/" not in url:
            continue
        m = SEED_DIV_RE.search(url)
        if m:
            divs.add(m.group(1).lower())
    return divs


def classify_div(name: str, is_seed: bool) -> tuple[str, str, str]:
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


def done_states() -> set[str]:
    """States already written to OUT (resume support)."""
    if not OUT.exists():
        return set()
    try:
        return set(pl.read_csv(OUT)["state_abbr"].to_list())
    except Exception:
        return set()


def rows_for_state(abbr: str, name: str, slug: str, seed: pl.DataFrame) -> list[dict]:
    """All review rows (statutes + constitution) for one state."""
    year = latest_year(slug)
    time.sleep(2)
    sdivs = seed_divisions(seed, abbr)
    try:
        titles = titles_for(slug, year)
    except RuntimeError as e:
        print("   !! title list failed:", e)
        titles = []
    time.sleep(2)

    rows, n_core, n_maybe = [], 0, 0
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
    print(f"     {abbr} titles: {len(titles)}  core: {n_core}  maybe: {n_maybe}  "
          f"seed-divs: {sorted(sdivs)}  constitution: {cstatus}  year: {year}")
    return rows


def main() -> None:
    if not SEED_IN.exists():
        raise SystemExit(f"Run 260613_build_seed_manifest.py first; missing {SEED_IN}")
    seed = pl.read_csv(SEED_IN)

    already = done_states()
    if already:
        print("Resuming; already done:", sorted(already))

    states = [(a, nm, sl) for a, (nm, sl) in EXPANSION.items() if a not in already]
    t0 = time.time()
    for idx, (abbr, name, slug) in enumerate(states, 1):
        el = time.time() - t0
        eta = (el / (idx - 1) * (len(states) - idx + 1)) if idx > 1 else 0
        print(f"[{idx}/{len(states)}] {name} ({slug})  elapsed {el:5.1f}s  eta ~{eta:4.0f}s")
        rows = rows_for_state(abbr, name, slug, seed)

        # Append this state's rows immediately (resumable, crash-safe).
        df_new = pl.DataFrame(rows)
        if OUT.exists():
            df_new = pl.concat([pl.read_csv(OUT), df_new], how="vertical_relaxed")
        write_csv_bom(df_new, OUT)  # UTF-8 + BOM so Excel renders non-ASCII cleanly

    # --- Final summary ---------------------------------------------------------
    if not OUT.exists():
        print("No output produced.")
        return
    df = pl.read_csv(OUT)
    order = list(EXPANSION)
    print("\nWrote:", OUT, " rows:", df.height,
          " states:", df["state_abbr"].n_unique())
    summary = (
        df.filter(pl.col("kind") == "statute")
        .group_by("state_abbr")
        .agg(
            n_titles=pl.len(),
            n_core=(pl.col("tier") == "core").sum(),
            n_maybe=(pl.col("tier") == "maybe").sum(),
        )
        .with_columns(pl.col("state_abbr").cast(pl.Enum(order)).to_physical().alias("_o"))
        .sort("_o").drop("_o")
    )
    with pl.Config(tbl_rows=30):
        print(summary)
    # Flag any constitution index that did not resolve.
    chk = df.filter((pl.col("kind") == "constitution") & (pl.col("kw_hits") == "CHECK"))
    if chk.height:
        print("Constitution index needs manual check for:",
              chk["state_abbr"].to_list())
    print("DONE_SELECT_TITLES")


if __name__ == "__main__":
    _start_logging()
    print(f"\n===== 260613_select_titles start @ "
          f"{__import__('datetime').datetime.now().isoformat(timespec='seconds')} =====")
    main()
