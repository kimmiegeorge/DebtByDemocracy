#!/usr/bin/env python3
r"""
260625_count_sections.py  --  Debt by Democracy: state statute AI task

Phase 2 COUNT-ONLY pass for the FINAL 14 states (CT DE IL IN IA KS MD MN NV NY PA RI
SC VA). For each APPROVED division (include=='Y' in the user-pruned title selection),
enumerate every section URL WITHOUT downloading text, and record the count. Purpose:
size the crawl and flag mega-divisions that need chapter-level narrowing BEFORE the
download (same gate the pilot + expansion used). Adapted from 260613_count_sections.py.

Cloudflare: fetches via the shared COOKIE-AWARE helper 260625_justia_fetch.py (the
2026-06-25 always-challenge reality; the expansion's cookie-less fetch() now 403s).
A Blocked (challenge survived all retries) PROPAGATES and crashes the pass -- it must
NOT be swallowed, or a blocked run could finish 'clean' with silently-missing divisions.

Section-leaf detection for THIS batch (SECTION_RE)
  - section-*            : everywhere (CT DE IL IN IA KS MD MN PA RI SC VA, IL deep
                          under act-/article-, MD under named-article/title/subtitle).
  - statute-<digit>      : Nevada (NV) flat `statute-350-020` (NE-style).
  - rs-<digit>           : carried from LA (not expected here, harmless).
  - <digit>+-<digit>     : NEW -- New York consolidated-law leaves are `NN-NN`
                          (e.g. lfn/article-2/title-3/34-00). Starts with a digit, so it
                          never collides with structural slugs (title-/chapter-/article-/
                          subtitle-/named-article, all letter-initial) in these 14 states.
No PDF-chapter states in this batch (ND was the only one). DE may render text as a PDF
like KY -- irrelevant to COUNT (we only enumerate); spot-check at download.

RESUMABLE (skip divisions already in the output) + self-logging (Tee) + DETACHED-capable
via Task Scheduler. Output CSV UTF-8 + BOM.

Inputs : Data\Statutes\documentation\260625_final15_title_selection*.csv  (pruned)
Output : Data\Statutes\documentation\260625_final15_count.csv
Log    : Data\Statutes\documentation\260625_count_log.txt

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260625_count_sections.py
  ...\260625_count_sections.py --selection <path>   (explicit pruned file)
  ...\260625_count_sections.py --states NY,MN       (subset)
  ...\260625_count_sections.py --summary-only
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

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
OUT = DOCS / "260625_final15_count.csv"
LOG = DOCS / "260625_count_log.txt"
TASK_NAME = "DbD_Final15Count"

# Candidate pruned-selection inputs, in priority order (first existing wins unless
# --selection is given). Mirrors the expansion's _revised / _jh convention.
SEL_CANDIDATES = [
    DOCS / "260625_final15_title_selection_revised.csv",
    DOCS / "260625_final15_title_selection_jh.csv",
    DOCS / "260625_final15_title_selection.csv",
]

# Shared cookie-aware fetch layer.
_spec = importlib.util.spec_from_file_location("jf", HERE / "260625_justia_fetch.py")
jf = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(jf)
BASE = jf.BASE
DeadLink, Blocked = jf.DeadLink, jf.Blocked

DELAY = 1.5
MAX_PAGES = 150   # per-division index-page cap -> FLOOR count for megas (narrow later)

ORDER = ["CT", "DE", "IL", "IN", "IA", "KS", "MD", "MN", "NV", "NY",
         "PA", "RI", "SC", "VA"]

# A child slug is a SECTION leaf (counted, never recursed) if it matches this.
SECTION_RE = re.compile(r"^(?:section-|rs-\d|statute-\d|\d+-\d)")
SKIP_SEG_RE = re.compile(r"disposition")

_fetch_times: list[float] = []


# --- helpers (mirror 260613_count_sections.py, but cookie-aware fetch) ----------
def fetch(url: str) -> str:
    t0 = time.time()
    html = jf.fetch(url)          # DeadLink on 404/410; Blocked propagates
    _fetch_times.append(time.time() - t0)
    return html


def abs_url(href: str) -> str:
    return BASE + href if href.startswith("/") else href


def segs(url: str) -> list[str]:
    return [s for s in urlparse(url).path.strip("/").split("/") if s]


def _natkey(url: str):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", url)]


def _children(page_url: str, html: str) -> list[tuple[str, str]]:
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
    """(n_sections, n_index_pages_walked, capped) for one division. capped=True -> the
    MAX_PAGES cap was hit and n_sections is a FLOOR (a mega to narrow). A Blocked
    propagates (must not silently truncate)."""
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
        except DeadLink as e:
            print(f"   !! dead index page skipped: {e}")
            continue
        time.sleep(DELAY)
        if codes:
            for seg, curl in _children(u, html):
                if SECTION_RE.match(seg):
                    sections.add(curl)
                elif SKIP_SEG_RE.search(seg):
                    continue
                elif curl not in visited:
                    stack.append(curl)
        else:
            soup = BeautifulSoup(html, "lxml")
            for a in soup.find_all("a", href=True):
                h = abs_url(a["href"]).split("#")[0]
                s = segs(h)
                if "law.justia.com" not in h or len(s) <= dl or s[:dl] != div_base:
                    continue
                if _is_const_leaf(h):
                    sections.add(h)
                elif h not in visited:
                    stack.append(h)
    if not codes and not sections:
        sections.add(div_url)
    return len(sections), idx_pages - 1, capped


# --- inputs --------------------------------------------------------------------
def selection_path(explicit: str) -> Path:
    if explicit:
        p = Path(explicit)
        if not p.exists():
            raise SystemExit(f"--selection file not found: {p}")
        return p
    for c in SEL_CANDIDATES:
        if c.exists():
            return c
    raise SystemExit("No title-selection CSV found (run 260625_select_titles.py / prune first).")


def approved_divisions(sel: Path, states: set[str] | None) -> pl.DataFrame:
    df = pl.read_csv(sel)
    # The user's pruned jh file carries an `include_jh` column holding "N" ONLY where
    # they switched an original Y to N; BLANK means unchanged -> fall back to `include`.
    # So effective-include = "N" where include_jh=="N", else the original `include`.
    if "include_jh" in df.columns:
        df = df.with_columns(
            pl.when(pl.col("include_jh") == "N").then(pl.lit("N"))
            .otherwise(pl.col("include")).alias("include")
        )
    df = df.filter(pl.col("include") == "Y")
    if states:
        df = df.filter(pl.col("state_abbr").is_in(list(states)))
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
    OUT.write_text(df_new.write_csv(), encoding="utf-8-sig")


# --- summary -------------------------------------------------------------------
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
              " (capped=True means FLOOR):\n", mega.select(sel))
    n_floor = int(inv["capped"].sum()) if cap_col else 0
    print(f"\nGRAND TOTAL sections: {n_sec}"
          + (f"  ({n_floor} FLOOR counts -- capped megas)" if n_floor else ""))
    print(f"Index pages walked:   {n_idx}")
    print(f"Avg fetch {avg:.2f}s + delay {DELAY:.2f}s = {per_page:.2f}s/page")
    print(f"Estimated FULL-download time: ~{est_dl/60:.0f} min ({est_dl/3600:.1f} h)")
    print("Count CSV:", OUT)


def maybe_cleanup_task() -> None:
    try:
        subprocess.run(["schtasks", "/Delete", "/TN", TASK_NAME, "/F"],
                       capture_output=True, text=True, timeout=30)
    except Exception:
        pass


def run(sel: Path, states: set[str] | None) -> None:
    div = approved_divisions(sel, states)
    already = done_urls()
    todo = div.filter(~pl.col("url").is_in(list(already))) if already else div
    print(f"Selection: {sel.name} | divisions: {div.height} | already counted: "
          f"{len(already & set(div['url'].to_list()))} | to do: {todo.height}"
          + (f" | states {sorted(states)}" if states else ""))

    t0 = time.time()
    total = todo.height
    for i, r in enumerate(todo.iter_rows(named=True), 1):
        n_sec, idx_pages, capped = enumerate_sections(r["url"], r["state_abbr"])
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
    ap.add_argument("--selection", default="", help="explicit pruned title-selection CSV")
    ap.add_argument("--states", default="", help="comma list e.g. NY,MN (default all 14)")
    ap.add_argument("--summary-only", action="store_true")
    ap.add_argument("--no-task-cleanup", action="store_true")
    args = ap.parse_args()
    if args.summary_only:
        print_summary()
        return
    jf.start_cookie_mode()   # 2026-06-25 always-challenge: skip the doomed plain attempt
    sel = selection_path(args.selection)
    states = {s.strip().upper() for s in args.states.split(",") if s.strip()} or None
    run(sel, states)
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
    print(f"\n===== 260625_count_sections start @ "
          f"{datetime.now().isoformat(timespec='seconds')} =====")
    main()
