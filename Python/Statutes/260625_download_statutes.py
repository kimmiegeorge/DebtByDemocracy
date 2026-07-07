#!/usr/bin/env python3
r"""
260625_download_statutes.py  --  Debt by Democracy: state statute AI task

Phase 2c DOWNLOAD for the FINAL 14 states (CT DE IL IN IA KS MD MN NV NY PA RI SC VA;
Hawaii excluded). Completing these = all 50 states covered. Adapts the proven
expansion downloader 260615_download_statutes.py -- most logic ports directly
(enumerate at true size, cache, manifest fragments + assembly, per-state masters,
division-level resume checkpoint, process_division, extract_html). Two differences:

  1. FETCH LAYER -- uses the shared cookie-aware helper 260625_justia_fetch.py
     (Firefox path: impersonate=firefox135 + FF UA, park-on-challenge), NOT 260615's
     inline Chrome-cookie code. We import 260625_count_sections.py for the leaf/URL
     helpers and reuse ITS already-loaded jf instance (cs.jf) so there is exactly ONE
     fetch session / cookie state.
  2. SELECTION -- the authoritative whole-division keep/drop is the user's
     260625_final15_title_selection_jh.csv (effective-include = "N" where
     include_jh=="N", else the original `include`). The count CSV alone is NOT the
     whole-list: 5 false-includes (IA title-i, PA title-5, RI title-4, KS chapter-1,
     NV chapter-35) are still rows in the count CSV but were flipped to include_jh=N,
     so they MUST be excluded here.

What gets downloaded
--------------------
  (1) WHOLE divisions -- every count-CSV row that is (a) effective-INCLUDED in the
      title_selection_jh AND (b) NOT one of the 6 walked megas. = 157 statutes
      (incl. the muni/local-gov megas kept whole: VA title-15-2, KS chapter-12/13,
      RI title-45, CT title-7, IN title-36, IA title-ix) + 14 constitutions = 171
      divisions. Sections enumerated LIVE at TRUE size (not the count floor) via
      enumerate_urls() -- the count CSV holds FLOORS for the capped muni megas.
  (2) NARROWED sections -- from 260625_megachapter_sections.csv (the 6 walked
      Elections/Utilities megas), keep a section iff its chapter is effective-kept in
      260625_megachapter_selection_jh.csv (selected_final_jh != "N" [blank kept] AND
      selected_final == "Y") AND the section's own selected_final == "Y".
      EDGE (whole-chapter promotion): a kept chapter with ZERO Y sections -> download
      it whole. In the current jh file there are ZERO such chapters (defensive no-op).

Justia structures in this batch
-------------------------------
  - Normal HTML sections (div#codes-content) for nearly all states/leaves:
      section-* ; NV flat statute-<n> ; NY consolidated-law NN-NN ; IL act->article->
      section ; MD named-article->title->subtitle->section ; MN range->chapter->section.
  - DE (Delaware) MAY render section text as an embedded PDF like the pilot's KY
    (div#codes-content empty, a statecodesfiles...pdf link in the page). get_section
    handles this GENERICALLY: if the HTML body is empty and a statecodesfiles PDF link
    is present, fetch the PDF and extract text with pymupdf. (Spot-check DE before the
    full run; see the task notes.) No ND-style per-CHAPTER PDF states in this batch.

File architecture (all outputs date-prefixed 260625_)
-----------------------------------------------------
  raw\<st>\_cache\<corpus>\<path>.html         raw per-section HTML (mirrors hierarchy)
  raw\<st>\_cache_pdf\<path>.pdf               per-section PDFs (DE/KY-style, if any)
  raw\<st>\260625_<statename>_<divslug>.txt     per-division consolidated text
  raw\<st>\260625_<statename>_constitution.txt  constitution consolidated text
  raw\<st>\260625_<st>_statutes.txt             per-state master (statute divisions)
  raw\260625_download_manifest.csv              one row per section (UTF-8+BOM)

RESUMABLE + DETACHED
--------------------
  Cached pages/PDFs are reused; per-division manifest fragments + a done-divisions
  checkpoint make a death mid-run cheap to resume. Run DETACHED via Windows Task
  Scheduler under 260625_supervisor.py (crash/hang auto-restart), ALONGSIDE the
  Firefox cookie harvester (DbD_FoxCookie). Park-on-challenge means a cookie expiry
  just PAUSES the crawl (no crash); the supervisor only handles native crashes/hangs.

Run (project venv):
  ...\venv\Scripts\python.exe 260625_download_statutes.py --plan        (size only, no net)
  ...\venv\Scripts\python.exe 260625_download_statutes.py --probe <url1,url2,...>  (spot-check)
  ...\venv\Scripts\python.exe 260625_download_statutes.py --download [--states DE,NY] [--delay 2.0]
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import random
import re
import sys
import time
from datetime import datetime
from pathlib import Path

import fitz  # pymupdf
import polars as pl
from bs4 import BeautifulSoup

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# --- Paths ---------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
STAT = HOME / "Data" / "Statutes"
DOCS = STAT / "documentation"
RAW = STAT / "raw"

COUNT_CSV = DOCS / "260625_final15_count.csv"                       # div url + n_sections (floors) + latest_year
SEL_JH_CSV = DOCS / "260625_final15_title_selection_jh.csv"        # USER whole-division keep/drop
REVIEW_CSV = DOCS / "260625_megachapter_selection_jh.csv"          # the 6 walked megas (div_url) + chapter keep/drop
ALLOW_CSV = DOCS / "260625_megachapter_sections.csv"               # per-section allowlist (selected_final)
MANIFEST = RAW / "260625_download_manifest.csv"

DATE = "260625"   # output file prefix

# Reuse the count crawler's leaf/URL helpers AND its already-loaded cookie-aware fetch
# (cs.jf) so the whole download shares one curl_cffi session + cookie state.
_spec = importlib.util.spec_from_file_location("cs", HERE / "260625_count_sections.py")
cs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cs)
jf = cs.jf                                              # the SAME shared fetch instance
DeadLink, Blocked = jf.DeadLink, jf.Blocked
segs, abs_url, _natkey = cs.segs, cs.abs_url, cs._natkey
_children, _is_codes, _is_const_leaf = cs._children, cs._is_codes, cs._is_const_leaf
SECTION_RE, SKIP_SEG_RE = cs.SECTION_RE, cs.SKIP_SEG_RE
ORDER = cs.ORDER
BASE = cs.BASE

DELAY = 2.0                  # steady-state polite delay (s). ~2-2.5s avoids re-hardening
JITTER = 0.8                 # the Cloudflare block; added random 0..JITTER per fetch.
MAX_PAGES_DL = 6000          # whole-division index-page safety cap (true megas are walked, not here)
PDF_RE = re.compile(r"https://statecodesfiles\.justia\.com[^\"'<> ]+\.pdf", re.I)
HDR = "=" * 80
SUB = "-" * 80

# Extra leaf patterns the count's SECTION_RE missed -> 14 effective-included divisions
# (all 7 IL statute divisions + 8-9 core NY laws incl. General Municipal Law) enumerated
# to 0 sections in the count, which would have silently downloaded EMPTY. Confirmed live
# 2026-06-26 (spot-check). Scoped per-state so a bare number / "article-" can't be
# misread as a leaf in the other 12 states (their sections are section-/statute-/NN-NN,
# their structural nodes are letter-prefixed).
#  - NY consolidated laws: the section leaf is a BARE NUMBER (e.g. .../gmu/article-1/1/,
#    body "§ 1. Short title..."). eln/lfn/vil use hyphenated NN-NN (already matched);
#    gmu/mhr/scc/twn/stf/dcd/pvh/slg/mha use bare numbers.
#  - IL has TWO leaf styles under chapter-N -> act-N (verified live 2026-06-26):
#      (a) Municipal Code (act-65-ilcs-5): act -> article-N, and the ARTICLE page renders
#          the whole article text INLINE (no per-section pages; article-1 = 94KB). So
#          under an act-* the article-* IS the content leaf.
#      (b) Election/Finance/etc. (act-10-ilcs-91): act -> per-section pages slugged with
#          the full ILCS citation, e.g. 10-ilcs-91-15-36 (= 10 ILCS 91/15-36). These start
#          with a digit + "-ilcs-" and are NOT matched by SECTION_RE's \d+-\d (the 2nd
#          char after the first hyphen is a letter), so they were being recursed into and
#          LOST. Acts are slugged "act-NN-ilcs-NN" (letter-initial) so they never collide.
BARE_NUM_RE = re.compile(r"^\d+$")
IL_SEC_RE = re.compile(r"^\d+-ilcs-\d")          # IL ILCS-citation section slug (10-ilcs-91-15-36)


def _is_section_leaf(seg: str, parent_url: str) -> bool:
    """Whether a depth+1 child `seg` (under `parent_url`) is a downloadable content leaf
    (collect + stop) rather than a structural index page (recurse)."""
    if SECTION_RE.match(seg):
        return True
    if "/new-york/" in parent_url and BARE_NUM_RE.match(seg):
        return True                                  # NY bare-number section
    if "/illinois/" in parent_url:
        if "/act-" in parent_url and seg.startswith("article-"):
            return True                              # IL inline-article leaf (Municipal Code)
        if IL_SEC_RE.match(seg):
            return True                              # IL ILCS-citation section leaf
    return False


def _polite() -> None:
    time.sleep(DELAY + random.uniform(0, JITTER))


# --- Section URL enumeration (returns the actual leaf URLs, TRUE size) ----------
def enumerate_urls(div_url: str, state: str = "") -> tuple[list[str], int]:
    """Return (sorted_leaf_urls, n_index_pages_walked) for one WHOLE division.

    Mirrors 260625_count_sections.enumerate_sections but COLLECTS the leaf URLs (the
    counter only counts) and uses MAX_PAGES_DL (not the 150-page count floor) so the
    capped muni megas are enumerated at their TRUE size. Codes: strict depth+1 walk; a
    child is a leaf if SECTION_RE matches (section-/statute-<d>/rs-<d>/NN-NN);
    otherwise recurse. Constitutions: looser walk (collect every deeper same-prefix
    content page, #fragment stripped; root-as-leaf if no sub-pages).

    Enumeration is CACHED to raw\<st>\_enum\<hash>.txt (the index walk costs network
    fetches -- e.g. ~5 min for a constitution -- and would otherwise be redone on every
    supervisor restart). Written only after a COMPLETE walk (a Blocked mid-walk raises
    before the write), so it never persists a partial."""
    ecache = _enum_cache_path(state, div_url)
    if ecache.exists() and ecache.stat().st_size > 0:
        urls = [ln.strip() for ln in ecache.read_text(encoding="utf-8").splitlines() if ln.strip()]
        return sorted(set(urls), key=_natkey), 0
    codes = _is_codes(div_url)
    div_base = segs(div_url)
    dl = len(div_base)
    leaves, visited, stack, idx_pages = set(), set(), [div_url], 0
    while stack:
        u = stack.pop()
        if u in visited:
            continue
        visited.add(u)
        idx_pages += 1
        if idx_pages > MAX_PAGES_DL:
            print(f"   !! MAX_PAGES_DL cap ({MAX_PAGES_DL}) hit at {div_url}")
            break
        if idx_pages % 100 == 0:                            # keep the log warm (stall watchdog)
            print(f"     ... enumerating {div_url}: {idx_pages} index pages, "
                  f"{len(leaves)} leaves so far", flush=True)
        try:
            html = fetch(u)
        except DeadLink as e:
            print(f"   !! dead index page skipped: {e}")
            continue
        # Blocked propagates: a transient block must NOT silently truncate a division.
        _polite()
        if codes:
            for seg, curl in _children(u, html):            # strict depth+1
                if _is_section_leaf(seg, u):
                    leaves.add(curl)
                elif SKIP_SEG_RE.search(seg):
                    continue
                elif curl not in visited:
                    stack.append(curl)
        else:
            soup = BeautifulSoup(html, "lxml")
            for a in soup.find_all("a", href=True):
                h = abs_url(a["href"]).split("#")[0]        # drop #section anchors
                if not h:
                    continue
                s = segs(h)
                if "law.justia.com" not in h or len(s) <= dl or s[:dl] != div_base:
                    continue
                if _is_const_leaf(h):
                    leaves.add(h)
                elif h not in visited:
                    stack.append(h)
    if not codes and not leaves:
        leaves.add(div_url)                                 # single-page constitution
    out = sorted(leaves, key=_natkey)
    ecache.parent.mkdir(parents=True, exist_ok=True)
    ecache.write_text("\n".join(out), encoding="utf-8")     # cache the complete walk
    return out, idx_pages - 1


def fetch(url: str) -> str:
    """Thin wrapper over the shared cookie-aware fetch (DeadLink on 404/410; Blocked on
    a transient that survived the wait; parks on a Cloudflare challenge)."""
    return jf.fetch(url)


def fetch_pdf(url: str) -> bytes:
    return jf.fetch_pdf(url)


# --- Caching --------------------------------------------------------------------
def cache_path(state: str, url: str) -> Path:
    corpus = "codes" if _is_codes(url) else "constitution"
    parts = segs(url)
    tail = parts[2:] if len(parts) > 2 else parts[-1:]
    rel = "/".join(tail)
    if not (rel.endswith(".html") or rel.endswith(".htm")):
        rel = rel + ".html"
    return RAW / state.lower() / "_cache" / corpus / rel


def pdf_cache_path(html_cache: Path) -> Path:
    parts = list(html_cache.parts)
    parts[parts.index("_cache")] = "_cache_pdf"
    return Path(*parts).with_suffix(".pdf")


def _enum_cache_path(state: str, div_url: str) -> Path:
    h = hashlib.sha1(div_url.encode("utf-8")).hexdigest()[:16]
    return RAW / state.lower() / "_enum" / f"{h}.txt"


# --- Resume checkpoint (skip COMPLETED divisions across restarts) ----------------
DONE_FILE = RAW / "260625_done_divisions.txt"
COMPLETE_FRAC = 0.95   # bootstrap: an existing output file counts as "done" only if it
                       # already holds >= this fraction of its EXPECTED sections.


def output_path(r: dict) -> Path:
    slug = "constitution" if r["kind"] == "constitution" else r["div_slug"]
    return RAW / r["state_abbr"].lower() / f"{DATE}_{r['statename']}_{slug}.txt"


def sections_in_file(p: Path) -> int:
    if not p.exists():
        return 0
    return p.read_text(encoding="utf-8", errors="replace").count("\nURL: ")


def expected_count(r: dict, narrowed: dict) -> int:
    if r["walked"]:
        return len(narrowed.get((r["state_abbr"], r["div_slug"]), []))
    return max(0, int(r["n_sections"]))     # count-CSV size for whole divisions (a floor if capped)


def load_done() -> set[str]:
    if DONE_FILE.exists():
        return {ln.strip() for ln in DONE_FILE.read_text(encoding="utf-8").splitlines() if ln.strip()}
    return set()


def mark_done(url: str, done: set[str]) -> None:
    if url in done:
        return
    done.add(url)
    DONE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(DONE_FILE, "a", encoding="utf-8") as fh:
        fh.write(url + "\n")


# Per-division manifest fragments + assembly (complete across restarts; see 260615).
MAN_COLS = ["state_abbr", "kind", "div_slug", "section_url", "heading",
            "effective_year", "src", "cache_path", "http_status", "bytes",
            "sha256_16", "fetched_now", "timestamp"]


def _frag_path(r: dict) -> Path:
    h = hashlib.sha1(r["url"].encode("utf-8")).hexdigest()[:16]
    return RAW / r["state_abbr"].lower() / "_manifest" / f"{h}.csv"


def write_manifest_fragment(r: dict, rows: list[dict]) -> None:
    if not rows:
        return
    fp = _frag_path(r)
    fp.parent.mkdir(parents=True, exist_ok=True)
    pl.DataFrame(rows).select(MAN_COLS).write_csv(fp)


def assemble_manifest() -> None:
    # Scope to THIS batch's 14 state folders only. The 25-state expansion (260615) left
    # its own per-division fragments in raw\<st>\_manifest\ too; a bare RAW.glob would
    # fold those in (disjoint states, so no double-count, but it pollutes this batch's
    # manifest). ORDER is the final-14 state list.
    dfs = []
    for st in ORDER:
        for f in sorted((RAW / st.lower()).glob("_manifest/*.csv")):
            try:
                d = pl.read_csv(f, infer_schema_length=0)    # all-str: robust concat
                if d.height:
                    dfs.append(d)
            except Exception:  # noqa: BLE001
                pass
    man = pl.concat(dfs, how="vertical_relaxed") if dfs else pl.DataFrame({c: [] for c in MAN_COLS})
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(man.write_csv(), encoding="utf-8-sig")    # UTF-8 + BOM
    print(f"manifest: {MANIFEST.relative_to(STAT)} ({man.height} sections)")


def rebuild_masters(statenames: dict[str, str]) -> None:
    for st, statename in statenames.items():
        files = sorted(p for p in (RAW / st.lower()).glob(f"{DATE}_{statename}_*.txt")
                       if not p.name.endswith("_constitution.txt"))
        if not files:
            continue
        master = RAW / st.lower() / f"{DATE}_{st.lower()}_statutes.txt"
        parts = [p.read_text(encoding="utf-8") for p in files]
        master.write_text(f"\n\n{HDR}\n{HDR}\n\n".join(parts), encoding="utf-8")
        print(f"master: {master.relative_to(STAT)} ({len(files)} divisions)")


# --- Text extraction ------------------------------------------------------------
def extract_html(html: str) -> tuple[str, str, str]:
    """(heading, body_text, year) for a normal HTML statute/constitution page."""
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


def pdf_text(content: bytes) -> str:
    doc = fitz.open(stream=content, filetype="pdf")
    raw = "\n".join(p.get_text() for p in doc)
    doc.close()
    lines = [ln.rstrip() for ln in raw.splitlines()]
    lines = [ln for ln in lines if not re.fullmatch(r"\s*Page \d+ of \d+\s*", ln)]
    txt = "\n".join(lines)
    return re.sub(r"\n{3,}", "\n\n", txt).strip()


def get_section(state: str, url: str) -> tuple[str, str, str, int, bool, str]:
    """Fetch+extract one leaf. Returns (heading, body, year, bytes, fetched_now, src).
    Resumable: cached HTML (and any per-section PDF) are reused. GENERIC PDF fallback:
    if the HTML body is empty AND the page links a statecodesfiles PDF (DE/KY-style),
    fetch+parse that PDF with pymupdf. Raises DeadLink (caller logs+skips) or Blocked
    (caller lets it propagate)."""
    cp = cache_path(state, url)
    cp.parent.mkdir(parents=True, exist_ok=True)
    if cp.exists() and cp.stat().st_size > 0:
        html = cp.read_text(encoding="utf-8", errors="replace")
        fetched = False
    else:
        html = fetch(url)                                   # DeadLink/Blocked per taxonomy
        cp.write_text(html, encoding="utf-8", errors="replace")
        fetched = True
        _polite()
    heading, body, year = extract_html(html)
    nbytes = len(html.encode("utf-8", "replace"))

    if not body.strip():                                    # empty HTML -> maybe embedded PDF
        m = PDF_RE.search(html)
        if m:
            pdf_url = m.group(0)
            pcp = pdf_cache_path(cp)
            pcp.parent.mkdir(parents=True, exist_ok=True)
            if pcp.exists() and pcp.stat().st_size > 0:
                content = pcp.read_bytes()
            else:
                content = fetch_pdf(pdf_url)
                pcp.write_bytes(content)
                _polite()
            body = pdf_text(content)
            nbytes = len(content)
            return heading, body, year, nbytes, fetched, "pdf"
        return heading, body, year, nbytes, fetched, "empty"
    return heading, body, year, nbytes, fetched, "html"


# --- Selection inputs -----------------------------------------------------------
def statename_of(url: str) -> str:
    s = segs(url)
    return s[1] if len(s) > 1 else "unknown"


def _effective_included_urls() -> set[str]:
    """URLs the user effective-INCLUDED in the title selection: include = "N" where
    include_jh=="N", else the original `include`. (Honors the 5 false-includes that
    were flipped to include_jh=N -- they are still rows in the count CSV but excluded.)"""
    sel = pl.read_csv(SEL_JH_CSV)
    if "include_jh" in sel.columns:
        sel = sel.with_columns(
            pl.when(pl.col("include_jh") == "N").then(pl.lit("N"))
            .otherwise(pl.col("include")).alias("include")
        )
    return set(sel.filter(pl.col("include") == "Y")["url"].to_list())


def load_divisions() -> pl.DataFrame:
    """The download universe: count-CSV divisions filtered to the user's effective-
    included set, tagged walked (the 6 megas) vs whole, with statename for filenames."""
    cnt = pl.read_csv(COUNT_CSV)
    inc = _effective_included_urls()
    walked = set(pl.read_csv(REVIEW_CSV)["div_url"].unique().to_list())
    return cnt.filter(pl.col("url").is_in(list(inc))).with_columns([
        pl.col("url").is_in(list(walked)).alias("walked"),
        pl.col("url").map_elements(statename_of, return_dtype=pl.Utf8).alias("statename"),
        pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o"),
    ]).sort(["_o", "kind", "div_slug"]).drop("_o")


def load_narrowed() -> dict[tuple[str, str], list[str]]:
    """(state_abbr, div_slug) -> ordered selected section URLs for the 6 walked megas.
    Keep a section iff its chapter is effective-kept (selected_final_jh != "N" [blank
    kept] AND selected_final == "Y") AND the section's own selected_final == "Y".
    Whole-chapter-promotion edge: a kept chapter with zero Y sections -> keep ALL its
    allowlist sections."""
    jh = pl.read_csv(REVIEW_CSV)
    alw = pl.read_csv(ALLOW_CSV)
    keep_chaps = {(r["state_abbr"], r["div_slug"], r["chapter_key"])
                  for r in jh.with_columns(
                      ((pl.col("selected_final_jh").fill_null("") != "N")
                       & (pl.col("selected_final") == "Y")).alias("_k")
                  ).filter(pl.col("_k")).iter_rows(named=True)}
    by_chap: dict[tuple, list[tuple[str, str]]] = {}     # chapter -> [(url, sf)]
    for r in alw.iter_rows(named=True):
        key = (r["state_abbr"], r["div_slug"], r["chapter_key"])
        if key in keep_chaps:
            by_chap.setdefault(key, []).append((r["section_url"], r["selected_final"]))

    out: dict[tuple[str, str], list[str]] = {}
    promoted = 0
    for (st, dslug, _chap), rows in by_chap.items():
        kept = [u for u, sf in rows if sf == "Y"]
        if not kept:                                      # edge: promote whole chapter
            kept = [u for u, _ in rows]
            promoted += 1
        out.setdefault((st, dslug), []).extend(kept)
    if promoted:
        print(f"  (whole-chapter promotion applied to {promoted} jh-kept chapters with no Y sections)")
    return {k: sorted(set(v), key=_natkey) for k, v in out.items()}


# --- Plan (size only) -----------------------------------------------------------
def run_plan() -> None:
    div = load_divisions()
    narrowed = load_narrowed()
    whole = div.filter(~pl.col("walked"))
    walked = div.filter(pl.col("walked"))
    whole_floor = int(whole["n_sections"].clip(0).sum())
    n_narrowed = sum(len(v) for v in narrowed.values())
    capped = whole.filter(pl.col("capped") == True)        # noqa: E712
    print(f"WHOLE divisions: {whole.height}  (floor sections {whole_floor}; "
          f"{capped.height} floored -> true size larger, enumerated live at download)")
    if capped.height:
        with pl.Config(tbl_rows=40, fmt_str_lengths=45):
            print(capped.select("state_abbr", "div_slug", "name", "n_sections"))
    print(f"WALKED megas: {walked.height}  (narrowed via allowlist)")
    print(f"WALKED divisions with kept sections: {len(narrowed)}")
    print(f"NARROWED sections kept: {n_narrowed}")
    print(f"PROJECTED TOTAL (floor): {whole_floor + n_narrowed} sections "
          f"(true higher -- capped muni megas)")
    yrs = (div.group_by("latest_year").len().sort("latest_year"))
    print("Editions (latest_year):", {r["latest_year"]: r["len"] for r in yrs.iter_rows(named=True)})
    per = 0.6 + DELAY + JITTER / 2   # ~fetch + polite delay + avg jitter
    print(f"Estimated full crawl: ~{(whole_floor + n_narrowed) * per / 3600:.1f} h "
          f"at {DELAY}s delay (excludes index-page walks)")


# --- Probe (spot-check extraction on given URLs) --------------------------------
def run_probe(urls: list[str]) -> None:
    jf.start_cookie_mode()
    for u in urls:
        st = _state_from_url(u)
        print(f"\n{'='*70}\nPROBE [{st}] {u}")
        try:
            heading, body, year, nbytes, fetched, src = get_section(st, u)
        except (DeadLink, Blocked) as e:
            print(f"  FETCH FAILED: {e}")
            continue
        print(f"  src={src}  year={year}  bytes={nbytes}  fetched_now={fetched}")
        print(f"  heading: {heading}")
        snippet = re.sub(r"\s+", " ", body)[:500]
        print(f"  body[{len(body)} chars]: {snippet}")


_SLUG2ABBR = None


def _state_from_url(url: str) -> str:
    global _SLUG2ABBR
    if _SLUG2ABBR is None:
        cnt = pl.read_csv(COUNT_CSV)
        _SLUG2ABBR = {statename_of(r["url"]): r["state_abbr"]
                      for r in cnt.iter_rows(named=True)}
    return _SLUG2ABBR.get(statename_of(url), "")


# --- Download -------------------------------------------------------------------
def run_download(states: set[str] | None, only_slugs: set[str] | None) -> None:
    # 2026-06-26 always-challenge reality: skip the doomed plain attempt and go straight
    # to the Firefox cookie path (impersonate/UA come from the harvested cf_clearance).
    jf.start_cookie_mode()
    print("method: COOKIE (Firefox cf_clearance harvest, park-on-challenge)", flush=True)
    div = load_divisions()
    narrowed = load_narrowed()
    if states:
        div = div.filter(pl.col("state_abbr").is_in(list(states)))
    if only_slugs:
        div = div.filter(pl.col("div_slug").is_in(list(only_slugs)))

    # --- resume checkpoint: bootstrap the done-set from existing complete output ---
    done = load_done()
    booted = 0
    for r in div.iter_rows(named=True):
        if r["url"] in done:
            continue
        exp = expected_count(r, narrowed)
        if exp > 0 and sections_in_file(output_path(r)) >= max(1, int(COMPLETE_FRAC * exp)):
            mark_done(r["url"], done)
            booted += 1
    statenames = {r["state_abbr"]: r["statename"] for r in div.iter_rows(named=True)}
    pending = [r for r in div.iter_rows(named=True) if r["url"] not in done]
    print(f"resume: {len(done)} divisions already complete (+{booted} just bootstrapped); "
          f"{len(pending)} to do this pass")

    t0 = time.time()
    total_div = div.height
    try:
        for di, r in enumerate(div.iter_rows(named=True), 1):
            if r["url"] in done:
                continue                                      # already complete (prior pass)
            process_division(r, di, total_div, done, narrowed, t0)
    finally:
        # Keep the corpus-wide master + manifest current even if a Blocked crashes
        # mid-pass (then re-raise so the supervisor retries).
        rebuild_masters(statenames)
        assemble_manifest()

    el = time.time() - t0
    print(f"\nPass finished in {el/60:.1f} min. {len(done)} divisions complete.")
    print("DONE_DOWNLOAD")


def process_division(r: dict, di: int, total_div: int, done: set[str],
                     narrowed: dict, t0: float) -> None:
    """Download one division. On full completion writes the consolidated .txt + manifest
    fragment and marks the division done. A Blocked propagates BEFORE any of that, so a
    partial division is never recorded as complete."""
    st, dslug, kind = r["state_abbr"], r["div_slug"], r["kind"]
    if r["walked"]:
        secs, source = narrowed.get((st, dslug), []), "allowlist"
    else:
        # Blocked propagates (fatal) so a Cloudflare block can never truncate a whole
        # division to 0 and let the run finish 'clean' with it missing.
        secs, _idx = enumerate_urls(r["url"], st)
        source = "whole"

    if not secs:
        print(f"[div {di}/{total_div}] {st} {dslug}: 0 sections "
              f"({'dropped' if r['walked'] else 'empty'}) -- skipped")
        mark_done(r["url"], done)                              # don't re-evaluate/re-enumerate next pass
        return
    print(f"[div {di}/{total_div}] {st} {dslug}: {len(secs)} sections ({source})")

    consolidated = [f"{HDR}\n{r['name']}  ({dslug})\nsource_url: {r['url']}\n{HDR}\n"]
    div_rows: list[dict] = []
    n_fail = 0
    for si, surl in enumerate(secs, 1):
        try:
            heading, body, year, nbytes, fetched, src = get_section(st, surl)
        except DeadLink as e:                                # genuinely gone -> log + skip
            n_fail += 1
            div_rows.append({
                "state_abbr": st, "kind": kind, "div_slug": dslug,
                "section_url": surl, "heading": "", "effective_year": "",
                "src": "dead", "cache_path": "", "http_status": e.status or -1,
                "bytes": 0, "sha256_16": "", "fetched_now": False,
                "timestamp": datetime.now().isoformat(timespec="seconds"),
            })
            continue
        # Blocked is NOT caught here: it propagates, fails the attempt, and the
        # supervisor retries from cache -- never marking a real section dead.
        cpath = cache_path(st, surl)
        sha = hashlib.sha256(body.encode("utf-8", "replace")).hexdigest()[:16]
        consolidated.append(f"{HDR}\n{heading}\nURL: {surl}\n{SUB}\n{body}\n")
        div_rows.append({
            "state_abbr": st, "kind": kind, "div_slug": dslug,
            "section_url": surl, "heading": heading, "effective_year": year,
            "src": src, "cache_path": str(cpath.relative_to(STAT)),
            "http_status": 200, "bytes": nbytes, "sha256_16": sha,
            "fetched_now": fetched,
            "timestamp": datetime.now().isoformat(timespec="seconds"),
        })
        if si % 25 == 0:
            print(f"     {si}/{len(secs)} sections  elapsed {time.time()-t0:.0f}s", flush=True)

    # Section loop completed without a Blocked -> the division is COMPLETE.
    outp = output_path(r)
    outp.parent.mkdir(parents=True, exist_ok=True)
    outp.write_text("\n".join(consolidated), encoding="utf-8")
    write_manifest_fragment(r, div_rows)
    mark_done(r["url"], done)
    print(f"     wrote {outp.relative_to(STAT)}"
          + (f"  ({n_fail} dead links skipped)" if n_fail else ""))


# --- CLI ------------------------------------------------------------------------
def main() -> None:
    global DELAY
    ap = argparse.ArgumentParser()
    ap.add_argument("--download", action="store_true", help="run the full download")
    ap.add_argument("--plan", action="store_true", help="print projected size only (no net)")
    ap.add_argument("--probe", default="", help="comma-list of leaf URLs to test-extract")
    ap.add_argument("--states", default="", help="comma list e.g. DE,NY (download subset)")
    ap.add_argument("--only-slugs", default="", help="comma list of div_slugs to keep")
    ap.add_argument("--delay", type=float, default=DELAY)
    args = ap.parse_args()
    DELAY = args.delay

    if args.probe:
        run_probe([u.strip() for u in args.probe.split(",") if u.strip()])
        return
    if args.plan:
        run_plan()
        return
    if args.download:
        RAW.mkdir(parents=True, exist_ok=True)
        states = {s.strip().upper() for s in args.states.split(",") if s.strip()} or None
        only = {s.strip() for s in args.only_slugs.split(",") if s.strip()} or None
        print(f"DOWNLOAD start | delay {DELAY}s"
              + (f" | states {sorted(states)}" if states else "")
              + (f" | slugs {sorted(only)}" if only else ""))
        run_download(states, only)
        return
    ap.error("choose one of --download / --plan / --probe")


if __name__ == "__main__":
    main()
