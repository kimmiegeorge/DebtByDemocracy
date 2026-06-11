#!/usr/bin/env python3
r"""
260611_download_statutes.py  --  Debt by Democracy: state statute AI task

Phase 2. Crawl the APPROVED Justia divisions (see include_final in
260611_title_selection.csv) for the 10 pilot states and download the FULL text of
every section, plus each state constitution. Justia sits behind Cloudflare, so all
fetches go through curl_cffi (impersonate=chrome124).

Two modes
---------
  --mode count     (default) Enumerate every section URL without downloading text;
                   write a section inventory + print totals and a full-crawl ETA.
                   Run this FIRST to size the job.
  --mode download  Fetch + cache each section, extract text, build consolidated
                   reading files, and write a per-section manifest. Resumable:
                   sections already cached on disk are skipped.

File architecture (download mode)
---------------------------------
  raw\<state>\_cache\<corpus>\<path>.html     raw per-section HTML (mirrors hierarchy)
  raw\<state>\<state>_<divslug>.txt           per-title consolidated text (headers)
  raw\<state>\<state>_constitution.txt        constitution consolidated text
  raw\<state>\<state>_statutes.txt            per-state master (all titles concatenated)
  raw\260611_download_manifest.csv            one row per section

Section text: heading from <title>, body from div#codes-content (statutes) or the
constitution content block. Effective year parsed from the heading (e.g. "(2025)").

Run (project venv):
  ...\venv\Scripts\python.exe ...\260611_download_statutes.py --mode count
  ...\venv\Scripts\python.exe ...\260611_download_statutes.py --mode download [--states AK,AZ]
"""
from __future__ import annotations

import argparse
import hashlib
import re
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
STAT = HOME / "Data" / "Statutes"
DOCS = STAT / "documentation"
RAW = STAT / "raw"
TITLE_CSV = DOCS / "260611_title_selection.csv"
INVENTORY = DOCS / "260611_section_inventory.csv"
ALLOWLIST = DOCS / "260611_megatitle_sections.csv"   # narrowed mega-title sections
MANIFEST = RAW / "260611_download_manifest.csv"

# Mega-titles whose sections come from the ALLOWLIST (selected_final == "Y")
# instead of a full enumerate. Everything else is crawled whole.
MEGA_DIVS = {("AL", "title-11"), ("AZ", "title-11"), ("MA", "title-vii"),
             ("NH", "title-iii"), ("NJ", "title-40"), ("NJ", "title-40a"),
             ("TN", "title-6"), ("TN", "title-7")}

BASE = "https://law.justia.com"
IMPERSONATE = "chrome124"
INDEX_PREFIXES = {"chapter", "article", "part", "subtitle", "subchapter",
                  "division", "subdivision", "subpart", "title"}
ORDER = ["AL", "AK", "AZ", "KY", "MA", "MS", "NH", "NJ", "TN", "WI"]

# Global politeness delay (seconds); overridable via --delay.
DELAY = 0.8
_fetch_times: list[float] = []  # rolling fetch latencies for ETA


# --- Justia fetch (Cloudflare via curl_cffi) -----------------------------------
class FetchError(Exception):
    def __init__(self, url: str, status, msg: str):
        super().__init__(f"fetch failed for {url}: {msg}")
        self.url, self.status, self.msg = url, status, msg


def fetch(url: str, tries: int = 4) -> str:
    """Fetch one page. Permanent 4xx (404/410/gone) raise immediately (no retry);
    Cloudflare challenges / 5xx / network errors retry with backoff."""
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


# --- Section discovery (BFS one level deeper, same path prefix) ----------------
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


def _is_leaf(url: str) -> bool:
    """A content (section/provision) page vs a structural index page.
    Codes: final segment `section-*`. Constitutions vary by state: `section-*`
    dirs (TN/WI), `*.html` (AL), or `*.htm` (AZ article pages)."""
    last = segs(url)[-1] if segs(url) else ""
    return last.startswith("section-") or url.endswith(".html") or url.endswith(".htm")


def enumerate_sections(div_url: str, max_pages: int = 8000):
    """Return (sorted_section_urls, n_index_pages_walked) for a division.

    Codes use a strict depth+1 walk (uniform hierarchy); recurse into ANY
    non-section sub-division (covers TN's named charter dirs). Constitutions use
    a looser walk: collect every deeper same-prefix content page (handles AZ's
    depth-skipping .htm layout) and recurse into structural dirs only."""
    codes = _is_codes(div_url)
    div_base = segs(div_url)
    dl = len(div_base)
    sections, visited, stack, idx_pages = set(), set(), [div_url], 0
    while stack:
        u = stack.pop()
        if u in visited:
            continue
        visited.add(u)
        idx_pages += 1
        if idx_pages > max_pages:
            print(f"   !! max_pages cap hit at {div_url}")
            break
        html = fetch(u)
        time.sleep(DELAY)
        if codes:
            for seg, curl in _children(u, html):  # strict depth+1
                if seg.startswith("section-"):
                    sections.add(curl)
                elif curl not in visited:          # any sub-division -> recurse
                    stack.append(curl)
        else:
            soup = BeautifulSoup(html, "lxml")
            for a in soup.find_all("a", href=True):
                h = abs_url(a["href"])
                s = segs(h)
                if "law.justia.com" not in h or len(s) <= dl or s[:dl] != div_base:
                    continue
                if _is_leaf(h):
                    sections.add(h)
                elif h not in visited:             # structural dir -> recurse
                    stack.append(h)
    if not codes and not sections:
        # Single-page constitution (MA/MS/NJ): the root URL itself is the document.
        sections.add(div_url)
    return sorted(sections, key=_natkey), idx_pages - 1  # minus the div page itself


def _natkey(url: str):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", url)]


# --- Section text extraction ---------------------------------------------------
def extract(html: str) -> tuple[str, str, str]:
    """Return (heading, body_text, effective_year).

    Statutes use div#codes-content (clean). Constitutions have no codes-content;
    their text lives in div#maincontent / div.primary-content (carries some
    breadcrumb chrome, tolerable for downstream reading)."""
    soup = BeautifulSoup(html, "lxml")
    heading = soup.title.get_text(strip=True) if soup.title else ""
    heading = heading.split("::")[0].strip()
    body_el = (soup.select_one("div#codes-content")
               or soup.select_one("div.text-block")
               or soup.select_one("div#maincontent")
               or soup.select_one("div.primary-content"))
    body = body_el.get_text("\n", strip=True) if body_el else ""
    ym = re.search(r"\((\d{4})\)", heading) or re.search(r"\b(19|20)\d{2}\b", heading)
    year = ym.group(0).strip("()") if ym else ""
    return heading, body, year


# --- Inputs --------------------------------------------------------------------
def approved_divisions() -> pl.DataFrame:
    df = pl.read_csv(TITLE_CSV)
    if "include_final" not in df.columns:
        raise SystemExit("Run 260611_finalize_titles.py first (no include_final column).")
    return df.filter(pl.col("include_final") == "Y").with_columns(
        pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o")
    ).sort(["_o", "kind", "div_slug"]).drop("_o")


def slug_for(row) -> str:
    return row["div_slug"] if row["kind"] == "statute" else "constitution"


# --- Count mode ----------------------------------------------------------------
def run_count(div: pl.DataFrame) -> None:
    rows = []
    t0 = time.time()
    total_div = div.height
    for i, r in enumerate(div.iter_rows(named=True), 1):
        secs, idx_pages = enumerate_sections(r["url"])
        rows.append({
            "state_abbr": r["state_abbr"], "kind": r["kind"],
            "div_slug": slug_for(r), "name": r["name"], "url": r["url"],
            "n_sections": len(secs), "n_index_pages": idx_pages,
        })
        el = time.time() - t0
        eta = el / i * (total_div - i)
        print(f"[{i:2d}/{total_div}] {r['state_abbr']} {slug_for(r):14s} "
              f"sections={len(secs):4d} idx={idx_pages:3d}  elapsed {el:5.0f}s eta ~{eta:4.0f}s")

    inv = pl.DataFrame(rows)
    inv.write_csv(INVENTORY)

    n_sec = int(inv["n_sections"].sum())
    n_idx = int(inv["n_index_pages"].sum())
    avg = (sum(_fetch_times) / len(_fetch_times)) if _fetch_times else 0.5
    per_page = avg + DELAY
    est_dl = (n_sec + n_idx) * per_page

    by_state = (inv.group_by("state_abbr").agg(
        sections=pl.col("n_sections").sum(),
        index_pages=pl.col("n_index_pages").sum(),
    ).with_columns(pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o"))
        .sort("_o").drop("_o"))
    with pl.Config(tbl_rows=20):
        print("\nPer-state section counts:\n", by_state)
    print(f"\nTOTAL sections to download: {n_sec}")
    print(f"TOTAL index pages walked:  {n_idx}")
    print(f"Measured avg fetch: {avg:.2f}s  + delay {DELAY:.2f}s = {per_page:.2f}s/page")
    print(f"Estimated full-download time: ~{est_dl/60:.0f} min "
          f"({est_dl/3600:.1f} h) at current delay")
    print("Inventory written:", INVENTORY)


# --- Download mode -------------------------------------------------------------
def cache_path(state: str, url: str) -> Path:
    corpus = "codes" if _is_codes(url) else "constitution"
    parts = segs(url)
    # drop ["codes"/"constitution", "<slug>"] prefix; keep the rest as the tree
    tail = parts[2:] if len(parts) > 2 else parts[-1:]
    rel = "/".join(tail)
    if not (rel.endswith(".html") or rel.endswith(".htm")):
        rel = rel + ".html"
    return RAW / state / "_cache" / corpus / rel


HDR = "=" * 80
SUB = "-" * 80


def load_allowlist() -> dict[tuple, list[str]]:
    """(state, div_slug) -> ordered list of selected section URLs for mega-titles."""
    if not ALLOWLIST.exists():
        raise SystemExit("Mega-title allowlist missing; run 260611_select_chapters.py "
                         "and 260611_finalize_chapters.py first.")
    a = pl.read_csv(ALLOWLIST).filter(pl.col("selected_final") == "Y")
    out: dict[tuple, list[str]] = {}
    for r in a.iter_rows(named=True):
        out.setdefault((r["state_abbr"], r["div_slug"]), []).append(r["section_url"])
    return {k: sorted(v, key=_natkey) for k, v in out.items()}


def run_download(div: pl.DataFrame, states: set[str] | None) -> None:
    if states:
        div = div.filter(pl.col("state_abbr").is_in(list(states)))
    allow = load_allowlist()
    man_rows = []
    t0 = time.time()
    total_div = div.height
    # group consolidation by state
    state_titlefiles: dict[str, list[Path]] = {}

    for di, r in enumerate(div.iter_rows(named=True), 1):
        state = r["state_abbr"].lower()
        statename = r["state_name"].lower().replace(" ", "-")
        dslug = slug_for(r)
        if (r["state_abbr"], dslug) in MEGA_DIVS:           # narrowed mega-title
            secs, idx_pages = allow.get((r["state_abbr"], dslug), []), 0
        else:                                                # crawl whole
            try:
                secs, idx_pages = enumerate_sections(r["url"])
            except FetchError as e:
                print(f"   !! enumerate failed for {dslug}: {e}; skipping division")
                continue
        print(f"[div {di}/{total_div}] {r['state_abbr']} {dslug}: {len(secs)} sections"
              + ("  (allowlist)" if (r['state_abbr'], dslug) in MEGA_DIVS else ""))

        consolidated = [f"{HDR}\n{r['name']}  ({dslug})\nsource_url: {r['url']}\n{HDR}\n"]
        n_fail = 0
        for si, surl in enumerate(secs, 1):
            cpath = cache_path(r["state_abbr"], surl)
            cpath.parent.mkdir(parents=True, exist_ok=True)
            if cpath.exists() and cpath.stat().st_size > 0:
                html = cpath.read_text(encoding="utf-8", errors="replace")
                status, fetched = 200, False
            else:
                try:
                    html = fetch(surl)
                except FetchError as e:                       # dead/blocked link: log + skip
                    n_fail += 1
                    man_rows.append({
                        "state_abbr": r["state_abbr"], "kind": r["kind"], "div_slug": dslug,
                        "section_url": surl, "heading": "", "effective_year": "",
                        "cache_path": "", "http_status": e.status or -1, "bytes": 0,
                        "sha256_16": "", "fetched_now": False,
                        "timestamp": datetime.now().isoformat(timespec="seconds"),
                    })
                    continue
                cpath.write_text(html, encoding="utf-8", errors="replace")
                status, fetched = 200, True
                time.sleep(DELAY)
            heading, body, year = extract(html)
            sha = hashlib.sha256(html.encode("utf-8", "replace")).hexdigest()[:16]
            consolidated.append(f"{HDR}\n{heading}\nURL: {surl}\n{SUB}\n{body}\n")
            man_rows.append({
                "state_abbr": r["state_abbr"], "kind": r["kind"], "div_slug": dslug,
                "section_url": surl, "heading": heading, "effective_year": year,
                "cache_path": str(cpath.relative_to(STAT)), "http_status": status,
                "bytes": len(html), "sha256_16": sha, "fetched_now": fetched,
                "timestamp": datetime.now().isoformat(timespec="seconds"),
            })
            if si % 50 == 0:
                el = time.time() - t0
                print(f"     {si}/{len(secs)} sections  elapsed {el:.0f}s")

        # write per-title consolidated file
        fname = f"{statename}_{dslug}.txt"
        outp = RAW / r["state_abbr"].lower() / fname
        outp.parent.mkdir(parents=True, exist_ok=True)
        outp.write_text("\n".join(consolidated), encoding="utf-8")
        if r["kind"] == "statute":
            state_titlefiles.setdefault(r["state_abbr"], []).append(outp)
        print(f"     wrote {outp.relative_to(STAT)}" + (f"  ({n_fail} dead links skipped)" if n_fail else ""))

    # per-state master (statutes only)
    for st, files in state_titlefiles.items():
        statename = files[0].parent.name
        master = RAW / st.lower() / f"{st.lower()}_statutes.txt"
        parts = []
        for f in files:
            parts.append(f.read_text(encoding="utf-8"))
        master.write_text(f"\n\n{HDR}\n{HDR}\n\n".join(parts), encoding="utf-8")
        print(f"master: {master.relative_to(STAT)} ({len(files)} titles)")

    man = pl.DataFrame(man_rows)
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    man.write_csv(MANIFEST)
    el = time.time() - t0
    n_dead = int((man["http_status"] != 200).sum()) if man.height else 0
    print(f"\nDownloaded {man.height - n_dead} sections ({n_dead} dead/blocked skipped) "
          f"in {el/60:.1f} min. Manifest:", MANIFEST)


# --- CLI -----------------------------------------------------------------------
def main() -> None:
    global DELAY
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["count", "download"], default="count")
    ap.add_argument("--states", default="", help="comma list e.g. AK,AZ (default all)")
    ap.add_argument("--only-slugs", default="",
                    help="comma list of div slugs to keep, e.g. constitution,title-6")
    ap.add_argument("--delay", type=float, default=DELAY)
    args = ap.parse_args()
    DELAY = args.delay

    RAW.mkdir(parents=True, exist_ok=True)
    div = approved_divisions()
    states = {s.strip().upper() for s in args.states.split(",") if s.strip()} or None
    only = {s.strip().lower() for s in args.only_slugs.split(",") if s.strip()} or None
    if states and args.mode == "count":
        div = div.filter(pl.col("state_abbr").is_in(list(states)))
    if only:
        div = div.with_columns(
            pl.when(pl.col("kind") == "constitution").then(pl.lit("constitution"))
            .otherwise(pl.col("div_slug")).alias("_slug")
        ).filter(pl.col("_slug").is_in(list(only))).drop("_slug")

    print(f"Mode: {args.mode}  | divisions: {div.height}  | delay: {DELAY}s"
          + (f"  | states: {sorted(states)}" if states else ""))
    if args.mode == "count":
        run_count(div)
    else:
        run_download(div, states)


if __name__ == "__main__":
    main()
