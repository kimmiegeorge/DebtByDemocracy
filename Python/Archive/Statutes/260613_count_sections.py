#!/usr/bin/env python3
r"""
260613_count_sections.py  --  Debt by Democracy: state statute AI task

Phase 2 COUNT-ONLY pass for the 25 EXPANSION states. For each APPROVED division
(include=='Y' in the user-curated 260613_expansion_title_selection_revised.csv),
enumerate every section URL WITHOUT downloading the section text, and record the
count. Purpose: size the full crawl and spot mega-divisions that need chapter-level
narrowing BEFORE the Phase 2 download (same gate the pilot used).

Adapted from the pilot's 260611_download_statutes.py --mode count. Justia sits
behind Cloudflare, so all fetches go through curl_cffi (impersonate=chrome124).

Section-leaf detection (verified by spot-check 2026-06-13)
---------------------------------------------------------
  - Standard title/chapter states + TX/CA named codes + OR volumes: sections are
    `section-*` slugs, reached by recursing through structural containers of mixed
    depth (title -> subtitle -> chapter -> subchapter -> article -> section, in any
    combination). The BFS recurses into ANY non-section child (pilot logic), so
    mixed nesting and TX/CA's deep named-code trees are handled uniformly.
  - LOUISIANA: revised-statutes titles list sections FLAT as `rs-<title>-<n>`
    directly under the title (e.g. title-33 = 4117 `rs-33-*` in ONE index fetch).
    These are leaves, NOT structural -> detected via the rs-<digit> pattern so we
    do not try to recurse into each of thousands of section pages.
  Index pages are the only thing fetched; section URLs are counted from links
  without being fetched (cheap), so even LA's 4000+ flat titles cost one fetch.

RESUMABLE + DETACHED
--------------------
  - Appends one row per division and skips divisions already present in the output
    CSV, so a death mid-run (Task Scheduler kill / app-session switch reaping bash
    jobs) is recovered by simply re-running. Run DETACHED via Windows Task Scheduler
    (NOT the bash background tool) because it fetches every intermediate index page
    across 25 states (~30-60 min).
  - Self-logs via a Tee to 260613_count_log.txt so a console-less detached run
    still leaves a readable progress log.
  - Output CSV written UTF-8 WITH BOM (utf-8-sig) so Excel renders non-ASCII names
    (e.g. Oregon "People's Utility Districts") cleanly.

Inputs : Data\Statutes\documentation\260613_expansion_title_selection_revised.csv
Output : Data\Statutes\documentation\260613_expansion_count.csv
         (state, kind, div_slug, name, url, n_sections, n_index_pages, latest_year)
Log    : Data\Statutes\documentation\260613_count_log.txt

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260613_count_sections.py
  ...\260613_count_sections.py --states TX,CA      (subset, e.g. for the spot-check)
  ...\260613_count_sections.py --summary-only      (re-print summary from the CSV)
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

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
SEL_CSV = DOCS / "260613_expansion_title_selection_revised.csv"
OUT = DOCS / "260613_expansion_count.csv"
LOG = DOCS / "260613_count_log.txt"

TASK_NAME = "DbD_ExpandCount"  # self-cleanup target when run detached

BASE = "https://law.justia.com"
IMPERSONATE = "chrome124"
DELAY = 0.8                      # polite delay between index-page fetches
# Per-division index-page cap. A division that hits the cap reports a FLOOR count
# (capped=True) -- enough to flag it as a mega to narrow, without spending 600+
# fetches enumerating a whole municipal code we will narrow anyway. Divisions we'd
# keep whole are well under the cap and get an EXACT count. A division reaching ~150
# index pages already holds >=~1100 sections -- well above the pilot's keep-whole
# range (largest kept ~500) -- so 150 floors every true mega while leaving exact
# counts for keep-whole candidates.
MAX_PAGES = 150

# State output order (matches the expansion batch list).
ORDER = ["AR", "CA", "CO", "FL", "GA", "ID", "LA", "ME", "MI", "MO", "MT", "NE",
         "NM", "NC", "ND", "OH", "OK", "OR", "SD", "TX", "UT", "VT", "WA", "WV", "WY"]

# A child slug is a SECTION leaf (counted, never recursed) if it matches this.
# `section-*` covers most states; `rs-<digit>` is Louisiana's flat revised-statutes
# section slug (rs-33-1, rs-39-1351, ...); `statute-<digit>` is Nebraska's flat
# section slug (statute-13-1001) listed directly under each chapter.
SECTION_RE = re.compile(r"^(?:section-|rs-\d|statute-\d)")

# States that embed one PDF per CHAPTER (no per-section HTML URLs), like the pilot's
# Kentucky but bundled at chapter granularity. For these the enumerable download
# unit is the chapter PDF, so we count `chapter-*` as the leaf (n_sections here = the
# number of chapter PDFs; true section counts require parsing the PDFs later, as KY
# was repaired in the pilot).
PDF_CHAPTER_STATES = {"ND"}
# Non-content sidebar links that share a division's path prefix but are not law
# (e.g. Washington's "rcw-dispositions-title-29a"). Skip to avoid wasted fetches.
SKIP_SEG_RE = re.compile(r"disposition")

_fetch_times: list[float] = []


# --- Justia fetch (Cloudflare via curl_cffi) -----------------------------------
class FetchError(Exception):
    def __init__(self, url: str, status, msg: str):
        super().__init__(f"fetch failed for {url}: {msg}")
        self.url, self.status, self.msg = url, status, msg


def fetch(url: str, tries: int = 4) -> str:
    """Fetch one page. Permanent 4xx (404/410) raise immediately (no retry); a
    Cloudflare challenge / 5xx / network error retries with backoff."""
    last = None
    for i in range(tries):
        try:
            t0 = time.time()
            r = creq.get(url, impersonate=IMPERSONATE, timeout=45)
            dt = time.time() - t0
            if r.status_code == 200 and "Just a moment" not in r.text:
                _fetch_times.append(dt)
                return r.text
            if r.status_code in (404, 410):           # dead link -> don't retry
                raise FetchError(url, r.status_code, f"status={r.status_code}")
            last = f"status={r.status_code} challenge={'Just a moment' in r.text}"
        except FetchError:
            raise
        except Exception as e:
            last = repr(e)
        time.sleep(2 * (i + 1))
    raise FetchError(url, None, last)


def abs_url(href: str) -> str:
    return BASE + href if href.startswith("/") else href


def segs(url: str) -> list[str]:
    return [s for s in urlparse(url).path.strip("/").split("/") if s]


def _natkey(url: str):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", url)]


# --- Section discovery (BFS one level deeper, same path prefix) ----------------
def _children(page_url: str, html: str) -> list[tuple[str, str]]:
    """(last_segment, absolute_url) for every link exactly one path segment deeper
    than page_url and sharing its prefix (strict depth+1, uniform-hierarchy walk)."""
    base = segs(page_url)
    bl = len(base)
    soup = BeautifulSoup(html, "lxml")
    out, seen = [], set()
    for a in soup.find_all("a", href=True):
        h = abs_url(a["href"])
        s = segs(h)
        if len(s) == bl + 1 and s[:bl] == base and h not in seen:
            seen.add(h)
            out.append((s[-1], h))
    return out


def _is_codes(url: str) -> bool:
    return "/codes/" in url


def _is_const_leaf(url: str) -> bool:
    last = segs(url)[-1] if segs(url) else ""
    return last.startswith("section-") or url.endswith(".html") or url.endswith(".htm")


def enumerate_sections(div_url: str, state: str = ""):
    """Return (n_sections, n_index_pages_walked, capped) for one division.
    `capped` is True if the per-division MAX_PAGES cap was hit (n_sections is then
    a FLOOR -- the division is a mega to narrow before download).

    Codes: strict depth+1 walk; a child is a SECTION leaf if SECTION_RE matches
    (`section-*` everywhere, plus LA `rs-<digit>`), else recurse into it. Sections
    are collected from links WITHOUT fetching them, so flat LA titles (thousands of
    rs-* leaves) cost a single index fetch.

    Constitutions: looser walk (collect every deeper same-prefix content page,
    recurse structural dirs); root-as-leaf if the index has no sub-pages."""
    codes = _is_codes(div_url)
    div_base = segs(div_url)
    dl = len(div_base)
    sections, visited, stack, idx_pages = set(), set(), [div_url], 0
    capped = False
    while stack:
        u = stack.pop()
        if u in visited:
            continue
        visited.add(u)
        idx_pages += 1
        if idx_pages > MAX_PAGES:
            print(f"   !! MAX_PAGES cap ({MAX_PAGES}) hit at {div_url}; count is a FLOOR")
            capped = True
            break
        if idx_pages % 200 == 0:
            print(f"     ... {idx_pages} index pages, {len(sections)} sections so far")
        try:
            html = fetch(u)
        except FetchError as e:
            print(f"   !! dead index page skipped: {e}")
            continue
        time.sleep(DELAY)
        if codes:
            pdf_chapters = state in PDF_CHAPTER_STATES
            for seg, curl in _children(u, html):       # strict depth+1
                if SECTION_RE.match(seg):
                    sections.add(curl)                  # leaf: count, never fetch
                elif pdf_chapters and seg.startswith("chapter-"):
                    sections.add(curl)                  # ND: chapter PDF is the leaf
                elif SKIP_SEG_RE.search(seg):
                    continue                            # non-content sidebar link
                elif curl not in visited:               # any sub-division -> recurse
                    stack.append(curl)
        else:
            soup = BeautifulSoup(html, "lxml")
            for a in soup.find_all("a", href=True):
                h = abs_url(a["href"])
                s = segs(h)
                if "law.justia.com" not in h or len(s) <= dl or s[:dl] != div_base:
                    continue
                if _is_const_leaf(h):
                    sections.add(h)
                elif h not in visited:
                    stack.append(h)
    if not codes and not sections:
        sections.add(div_url)                           # single-page constitution
    return len(sections), idx_pages - 1, capped         # minus the div root page


# --- Inputs --------------------------------------------------------------------
def approved_divisions(states: set[str] | None) -> pl.DataFrame:
    df = pl.read_csv(SEL_CSV)
    df = df.filter(pl.col("include") == "Y")
    if states:
        df = df.filter(pl.col("state_abbr").is_in(list(states)))
    # statutes carry div_slug; constitutions have an empty slug -> label it.
    return df.with_columns(
        pl.when(pl.col("kind") == "constitution").then(pl.lit("constitution"))
        .otherwise(pl.col("div_slug")).alias("div_slug")
    ).with_columns(
        pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o")
    ).sort(["_o", "kind", "div_slug"]).drop("_o")


def done_urls() -> set[str]:
    if not OUT.exists():
        return set()
    try:
        return set(pl.read_csv(OUT)["url"].to_list())
    except Exception:
        return set()


def append_row(row: dict) -> None:
    df_new = pl.DataFrame([row])
    if OUT.exists():
        df_new = pl.concat([pl.read_csv(OUT), df_new], how="vertical_relaxed")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(df_new.write_csv(), encoding="utf-8-sig")  # UTF-8 + BOM for Excel


# --- Summary -------------------------------------------------------------------
def print_summary() -> None:
    if not OUT.exists():
        print("No output CSV yet.")
        return
    inv = pl.read_csv(OUT)
    n_sec = int(inv["n_sections"].sum())
    n_idx = int(inv["n_index_pages"].sum())
    avg = (sum(_fetch_times) / len(_fetch_times)) if _fetch_times else 0.6
    per_page = avg + DELAY
    est_dl = (n_sec + n_idx) * per_page

    by_state = (inv.group_by("state_abbr").agg(
        divisions=pl.len(),
        sections=pl.col("n_sections").sum(),
        index_pages=pl.col("n_index_pages").sum(),
    ).with_columns(pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o"))
        .sort("_o").drop("_o"))
    with pl.Config(tbl_rows=40, fmt_str_lengths=40):
        print("\nPer-state section counts:\n", by_state)

    cap_col = "capped" if "capped" in inv.columns else None
    mega = inv.filter(pl.col("n_sections") >= 800).sort("n_sections", descending=True)
    sel = ["state_abbr", "div_slug", "name", "n_sections"] + ([cap_col] if cap_col else [])
    with pl.Config(tbl_rows=80, fmt_str_lengths=50):
        print("\nMEGA-DIVISIONS (n_sections >= 800) -- candidates to narrow"
              " (capped=True means the count is a FLOOR):\n", mega.select(sel))

    n_floor = int(inv["capped"].sum()) if cap_col else 0
    print(f"\nGRAND TOTAL sections: {n_sec}"
          + (f"  (>= ; {n_floor} divisions are FLOOR counts -- capped megas)" if n_floor else ""))
    print(f"Index pages walked:   {n_idx}")
    print(f"Avg fetch {avg:.2f}s + delay {DELAY:.2f}s = {per_page:.2f}s/page")
    print(f"Estimated FULL-download time: ~{est_dl/60:.0f} min ({est_dl/3600:.1f} h)")
    print("Count CSV:", OUT)


def maybe_cleanup_task() -> None:
    """If launched as the detached Task Scheduler job, unregister it on clean exit
    (mirrors the pilot's supervisor2 self-cleanup). No-op when run interactively."""
    try:
        subprocess.run(["schtasks", "/Delete", "/TN", TASK_NAME, "/F"],
                       capture_output=True, text=True, timeout=30)
    except Exception:
        pass


# --- Main ----------------------------------------------------------------------
def run(states: set[str] | None) -> None:
    div = approved_divisions(states)
    already = done_urls()
    todo = div.filter(~pl.col("url").is_in(list(already))) if already else div
    print(f"Divisions selected: {div.height}  | already counted: {len(already & set(div['url'].to_list()))}"
          f"  | to do: {todo.height}"
          + (f"  | states: {sorted(states)}" if states else ""))

    t0 = time.time()
    total = todo.height
    for i, r in enumerate(todo.iter_rows(named=True), 1):
        try:
            n_sec, idx_pages, capped = enumerate_sections(r["url"], r["state_abbr"])
        except FetchError as e:
            print(f"   !! enumerate failed for {r['state_abbr']} {r['div_slug']}: {e}; recording -1")
            n_sec, idx_pages, capped = -1, 0, False
        append_row({
            "state_abbr": r["state_abbr"], "kind": r["kind"],
            "div_slug": r["div_slug"], "name": r["name"], "url": r["url"],
            "n_sections": n_sec, "n_index_pages": idx_pages, "capped": capped,
            "latest_year": r.get("latest_year", ""),
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        })
        el = time.time() - t0
        eta = el / i * (total - i)
        flag = ("  <-- MEGA(floor)" if capped else "  <-- MEGA") if n_sec >= 800 else ""
        print(f"[{i:3d}/{total}] {r['state_abbr']} {r['div_slug']:26s} "
              f"sections={n_sec:5d} idx={idx_pages:4d}{'C' if capped else ' '}  "
              f"elapsed {el:5.0f}s eta ~{eta:5.0f}s{flag}")

    print(f"\nAll divisions counted in {(time.time()-t0)/60:.1f} min.")
    print_summary()
    print("DONE_COUNT")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--states", default="", help="comma list e.g. TX,CA (default all 25)")
    ap.add_argument("--summary-only", action="store_true",
                    help="re-print the summary from the existing CSV and exit")
    ap.add_argument("--no-task-cleanup", action="store_true",
                    help="do not unregister the scheduled task on exit")
    args = ap.parse_args()

    if args.summary_only:
        print_summary()
        return

    states = {s.strip().upper() for s in args.states.split(",") if s.strip()} or None
    run(states)
    if not args.no_task_cleanup:
        maybe_cleanup_task()


def _start_logging() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    fh = open(LOG, "a", encoding="utf-8")

    class _Tee:
        def __init__(self, *st): self.st = st
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

    sys.stdout = _Tee(sys.stdout, fh)
    sys.stderr = sys.stdout


if __name__ == "__main__":
    _start_logging()
    print(f"\n===== 260613_count_sections start @ "
          f"{datetime.now().isoformat(timespec='seconds')} =====")
    main()
