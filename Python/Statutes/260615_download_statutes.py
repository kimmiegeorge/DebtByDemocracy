#!/usr/bin/env python3
r"""
260615_download_statutes.py  --  Debt by Democracy: state statute AI task

Phase 2 DOWNLOAD for the 25 EXPANSION states (AR CA CO FL GA ID LA ME MI MO MT NE
NM NC ND OH OK OR SD TX UT VT WA WV WY). Fetches the full text of every selected
Justia section, builds per-division + per-state consolidated reading files, and
writes a manifest. Justia is behind Cloudflare, so all fetches go through curl_cffi
(impersonate=chrome124), reusing the count crawler's fetch/leaf logic.

What gets downloaded (per the 2026-06-15 checkpoint, TASK A)
-----------------------------------------------------------
  (1) WHOLE divisions -- every count-CSV row NOT walked by select_chapters
      (the 119 non-mega Muni/Local, Public Finance, Utilities, 'other' statute
      divisions) PLUS all 25 constitutions = 144 divisions. Their sections are
      enumerated live at TRUE size (not the count floor) via enumerate_urls().
  (2) NARROWED sections -- from 260613_megachapter_sections.csv, keep a section iff
      its chapter is kept in the USER's pruned file
      260613_megachapter_selection_jh.csv (selected_final_jh == 'Y') AND the
      section's own selected_final == 'Y'.
      EDGE (whole-chapter promotion): if the user set a chapter jh=Y but finalize had
      dropped ALL its sections, download that chapter WHOLE (all its allowlist
      sections). In the current jh file there are ZERO such chapters, so this is a
      defensive no-op, but it is implemented.

New Justia structures handled (verified by spot-check; see findings.md)
----------------------------------------------------------------------
  - ND (North Dakota): one embedded PDF per CHAPTER. The leaf is the chapter page
    (chapter-*); div#codes-content is empty. We fetch the chapter HTML, parse the
    statecodesfiles...chapter.pdf link, fetch the PDF, and extract text with pymupdf
    (same playbook as the pilot's 260611_repair_ky_pdfs.py). Keyed on state=="ND".
  - NE (Nebraska): sections are flat `statute-<chap>-<n>` HTML pages
    (div#codes-content). Normal HTML extract.
  - LA (Louisiana): flat `rs-<title>-<n>` HTML sections. Normal HTML extract.

File architecture (all outputs date-prefixed 260615_)
-----------------------------------------------------
  raw\<st>\_cache\<corpus>\<path>.html        raw per-section HTML (mirrors hierarchy)
  raw\<st>\_cache_pdf\<path>.pdf              ND chapter PDFs (mirrors the html tree)
  raw\<st>\260615_<statename>_<divslug>.txt    per-division consolidated text
  raw\<st>\260615_<statename>_constitution.txt constitution consolidated text
  raw\<st>\260615_<st>_statutes.txt            per-state master (statute divisions)
  raw\260615_download_manifest.csv             one row per section (UTF-8+BOM)

RESUMABLE + DETACHED
--------------------
  Cached pages/PDFs are reused, so a death mid-run (Task Scheduler kill / app-session
  switch reaping bash jobs / native curl_cffi crash) is recovered by re-running. Run
  DETACHED via Windows Task Scheduler under 260613_supervisor.py (NOT the bash bg
  tool), which restarts on crash/hang until a clean pass and self-unregisters.

Inputs (Data\Statutes\documentation\)
  260613_expansion_count.csv            -- the 222 divisions (whole vs walked)
  260613_megachapter_selection.csv      -- walked-chapter review (div_url => walked)
  260613_megachapter_selection_jh.csv   -- USER's authoritative chapter keep/drop
  260613_megachapter_sections.csv       -- per-section allowlist (selected_final)

Run (project venv):
  ...\venv\Scripts\python.exe 260613_download_statutes.py --plan        (size only, no net for whole floors)
  ...\venv\Scripts\python.exe 260613_download_statutes.py --probe <url1,url2,...>  (spot-check extraction)
  ...\venv\Scripts\python.exe 260613_download_statutes.py --download [--states ND,NE,LA] [--delay 0.8]
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
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

COUNT_CSV = DOCS / "260613_expansion_count.csv"
REVIEW_CSV = DOCS / "260613_megachapter_selection.csv"        # walked div_urls + chapter_key
JH_CSV = DOCS / "260613_megachapter_selection_jh.csv"         # USER authoritative keep/drop
ALLOW_CSV = DOCS / "260613_megachapter_sections.csv"          # per-section allowlist
MANIFEST = RAW / "260615_download_manifest.csv"
CF_FILE = DOCS / "260615_cf_clearance.json"                   # Cloudflare clearance cookie + UA

DATE = "260615"   # output file prefix

# Reuse the count crawler's fetch + leaf logic (single source of truth).
_spec = importlib.util.spec_from_file_location("cs", HERE / "260613_count_sections.py")
cs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cs)
creq = cs.creq
segs, abs_url, _natkey = cs.segs, cs.abs_url, cs._natkey
_children, _is_codes, _is_const_leaf = cs._children, cs._is_codes, cs._is_const_leaf
SECTION_RE, SKIP_SEG_RE = cs.SECTION_RE, cs.SKIP_SEG_RE
PDF_CHAPTER_STATES = cs.PDF_CHAPTER_STATES   # {"ND"}
ORDER = cs.ORDER
# Two crawl methods, chosen automatically (see fetch / COOKIE_MODE):
#  - PLAIN (default): the ORIGINAL method that ran 6h cleanly on a fresh IP -- bare
#    curl_cffi impersonate=chrome124, no cf_clearance cookie, no daemon. Fast + simple.
#  - COOKIE: inject the daemon's cf_clearance + the user's real UA (impersonate
#    chrome131, closest to Chrome/149 since cf_clearance is UA-bound). Only needed once
#    Cloudflare puts the IP into interactive-challenge mode.
# The downloader STARTS plain and auto-escalates to cookie on the first challenge, so a
# fresh IP runs the simple fast method and only falls back to cookies if challenged.
IMPERSONATE_PLAIN = "chrome124"
IMPERSONATE_COOKIE = "chrome131"
COOKIE_MODE = False           # start in the original plain method
BASE = cs.BASE

DELAY = 3.0                  # slow steady-state: 0.8s tripped a Cloudflare IP block ~6h/27k reqs in
                             # (2026-06-15); user chose ~3s to avoid re-blocking the remaining ~46k.
JITTER = 1.0                 # added random 0..JITTER s per fetch to avoid a regular cadence
MAX_PAGES_DL = 6000          # whole-division index-page safety cap (true megas are walked, not here)
PDF_RE = re.compile(r"https://statecodesfiles\.justia\.com[^\"'<> ]+\.pdf", re.I)
HDR = "=" * 80
SUB = "-" * 80

# Escalating per-fetch backoff (seconds) for transient failures (Cloudflare 403
# "Just a moment" challenge / 429 / 5xx / network). ~3.9 min total over 5 tries
# before declaring the fetch BLOCKED. We print before each sleep so the supervisor's
# log-mtime stall watchdog (12 min) does not false-kill us mid-backoff. A truly
# blocked state thus fails the attempt in ~4 min; the SUPERVISOR then waits out the
# block with its own escalating cooldown (cheap: the cache makes restarts skip fast).
BACKOFF = [5, 15, 30, 60, 120]


class DeadLink(Exception):
    """Permanent 404/410 -- the page is genuinely gone (safe to skip + log)."""
    def __init__(self, url: str, status):
        super().__init__(f"dead {url} (status={status})")
        self.url, self.status = url, status


class Blocked(Exception):
    """Transient block (Cloudflare challenge / 429 / 5xx / network) that survived all
    retries. FATAL to the attempt -- we must NOT skip the page and continue, or a
    blocked run could finish 'clean' with silently-missing sections/divisions. The
    supervisor restarts (from cache) after a cooldown so we resume once it lifts."""
    def __init__(self, url: str, detail: str):
        super().__init__(f"BLOCKED {url}: {detail}")
        self.url, self.detail = url, detail


# --- Cloudflare clearance (cf_clearance cookie + matching UA) -------------------
# Justia put this IP into INTERACTIVE-challenge mode (Turnstile "verify you are a
# human") after the heavy crawl -- curl_cffi can't tick that box, so every request
# 403s regardless of IP/impersonation. A real browser that solves the checkbox earns
# a cf_clearance cookie that lets requests through; we inject that cookie + the exact
# browser User-Agent (the cookie is bound to UA + IP). CF_FILE holds both and is
# RE-READ on every challenge, so the user can drop in a fresh cookie (when it expires)
# WITHOUT restarting the crawl. Keep the same home IP (VPN OFF) -- the cookie is IP-bound.
_session = None
_ua = ""
_cf_mtime = 0.0


def _get_session():
    global _session
    if _session is None:
        imp = IMPERSONATE_COOKIE if COOKIE_MODE else IMPERSONATE_PLAIN
        _session = creq.Session(impersonate=imp)
    return _session


def switch_to_cookie_mode() -> None:
    """Escalate from the plain (original) method to cookie mode after Cloudflare
    challenges. Rebuilds the session with the cookie impersonation + loads the
    daemon's cf_clearance. Idempotent."""
    global COOKIE_MODE, _session
    if COOKIE_MODE:
        return
    COOKIE_MODE = True
    _session = None                              # rebuild as a cookie (chrome131) session
    print("   ** Cloudflare challenged the plain method -> switching to COOKIE mode "
          "(needs the cookie daemon running) **", flush=True)
    load_clearance(verbose=True)


def load_clearance(verbose: bool = False) -> bool:
    """(Re)load cf_clearance + UA from CF_FILE into the session. Cheap; safe to call
    often. Returns True if a cookie was loaded."""
    global _ua, _cf_mtime
    try:
        d = json.loads(CF_FILE.read_text(encoding="utf-8"))
        cf = (d.get("cf_clearance") or "").strip()
        _ua = (d.get("user_agent") or "").strip().strip("'\"")
        if not cf:
            return False
        sess = _get_session()
        for dom in (".law.justia.com", "law.justia.com",
                    ".justia.com", "statecodesfiles.justia.com"):
            try:
                sess.cookies.set("cf_clearance", cf, domain=dom)
            except Exception:  # noqa: BLE001
                pass
        _cf_mtime = CF_FILE.stat().st_mtime
        if verbose:
            print(f"   loaded cf_clearance ({len(cf)} chars) + UA {_ua[:42]}...", flush=True)
        return True
    except Exception as e:  # noqa: BLE001
        if verbose:
            print(f"   !! could not load {CF_FILE.name}: {e}", flush=True)
        return False


def _maybe_reload_clearance() -> None:
    """Cheap stat: if the cookie daemon (or the user) rewrote CF_FILE, pick up the
    fresh cf_clearance proactively -- so we usually never even hit a challenge."""
    try:
        if CF_FILE.stat().st_mtime > _cf_mtime:
            load_clearance()
    except Exception:  # noqa: BLE001
        pass


CHALLENGE_WAIT_S = 1800   # how long to PATIENTLY wait out a challenge (re-reading the
                          # cookie) before giving up. A re-prompt that needs a human
                          # checkbox click is resolved by the daemon within seconds of
                          # the click; we just pause here instead of crashing, so the
                          # crawl resumes mid-division with no supervisor restart churn.


def fetch(url: str) -> str:
    """Fetch one page. Starts with the PLAIN method (bare chrome124, no cookie); on the
    first Cloudflare challenge it auto-escalates to COOKIE mode (daemon's cf_clearance +
    real UA). Returns HTML on 200; raises DeadLink on a permanent 404/410. A challenge/
    5xx/network error does NOT crash -- it retries (in cookie mode, re-reading CF_FILE so
    a daemon/user-refreshed cookie is picked up) for up to CHALLENGE_WAIT_S, printing
    each retry to keep the log warm; only then does it raise Blocked (supervisor restarts
    and waits again -- progress is preserved by the cache)."""
    last = None
    t0 = time.time()
    i = 0
    while True:
        if COOKIE_MODE:
            _maybe_reload_clearance()
        sess = _get_session()
        hdr = {"User-Agent": _ua} if (COOKIE_MODE and _ua) else {}
        try:
            r = sess.get(url, headers=hdr, timeout=45)
            if r.status_code == 200 and "Just a moment" not in r.text:
                return r.text
            if r.status_code in (404, 410):
                raise DeadLink(url, r.status_code)
            challenged = ("Just a moment" in r.text) or r.status_code in (403, 429, 503)
            last = f"status={r.status_code} challenge={challenged}"
            if challenged and not COOKIE_MODE:
                switch_to_cookie_mode()          # escalate; retry immediately with cookie
                continue
        except DeadLink:
            raise
        except Exception as e:  # noqa: BLE001  network/timeout/curl error
            last = repr(e)
        if time.time() - t0 >= CHALLENGE_WAIT_S:
            raise Blocked(url, last or "unknown")
        if COOKIE_MODE:
            load_clearance()                     # pick up a daemon/user-refreshed cookie
        wait = min(60, BACKOFF[min(i, len(BACKOFF) - 1)]) + random.uniform(0, 5)
        hint = " -- if the dedicated Chrome shows the checkbox, click it" if "challenge=True" in (last or "") else ""
        print(f"   .. retry ({last}) in {wait:.0f}s [{(time.time()-t0)/60:.0f}min]{hint}  {url}", flush=True)
        time.sleep(wait)
        i += 1


def _polite() -> None:
    time.sleep(DELAY + random.uniform(0, JITTER))


# --- Section URL enumeration (returns the actual leaf URLs, TRUE size) ----------
def enumerate_urls(div_url: str, state: str = "") -> tuple[list[str], int]:
    """Return (sorted_leaf_urls, n_index_pages_walked) for one WHOLE division.

    Mirrors 260613_count_sections.enumerate_sections but COLLECTS the leaf URLs
    (the counter only counts) and uses no floor cap. Codes: strict depth+1 walk; a
    child is a leaf if SECTION_RE matches (section-/rs-<d>/statute-<d>) or, for ND,
    it is a chapter-* PDF page; otherwise recurse. Constitutions: looser walk
    (collect every deeper same-prefix content page; root-as-leaf if no sub-pages).

    Enumeration result is CACHED to raw\<st>\_enum\<hash>.txt (the index walk costs
    network fetches -- e.g. ~5 min for a constitution -- and would otherwise be redone
    on every supervisor restart). The cache is written only after a COMPLETE walk
    (a Blocked mid-walk raises before the write), so it never persists a partial."""
    ecache = _enum_cache_path(state, div_url)
    if ecache.exists() and ecache.stat().st_size > 0:
        urls = [ln.strip() for ln in ecache.read_text(encoding="utf-8").splitlines() if ln.strip()]
        return sorted(set(urls), key=_natkey), 0
    codes = _is_codes(div_url)
    div_base = segs(div_url)
    dl = len(div_base)
    pdf_chapters = state in PDF_CHAPTER_STATES
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
            for seg, curl in _children(u, html):           # strict depth+1
                if SECTION_RE.match(seg):
                    leaves.add(curl)
                elif pdf_chapters and seg.startswith("chapter-"):
                    leaves.add(curl)                        # ND: chapter PDF leaf
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
                    leaves.add(h)                           # e.g. LA ArticleN.html (each = 1 article page)
                elif h not in visited:
                    stack.append(h)
    if not codes and not leaves:
        leaves.add(div_url)                                 # single-page constitution
    out = sorted(leaves, key=_natkey)
    ecache.parent.mkdir(parents=True, exist_ok=True)
    ecache.write_text("\n".join(out), encoding="utf-8")     # cache the complete walk
    return out, idx_pages - 1


# --- Caching --------------------------------------------------------------------
def cache_path(state: str, url: str) -> Path:
    corpus = "codes" if _is_codes(url) else "constitution"
    parts = segs(url)
    tail = parts[2:] if len(parts) > 2 else parts[-1:]
    rel = "/".join(tail)
    if not (rel.endswith(".html") or rel.endswith(".htm")):
        rel = rel + ".html"
    return RAW / state / "_cache" / corpus / rel


def pdf_cache_path(html_cache: Path) -> Path:
    parts = list(html_cache.parts)
    parts[parts.index("_cache")] = "_cache_pdf"
    return Path(*parts).with_suffix(".pdf")


def _enum_cache_path(state: str, div_url: str) -> Path:
    h = hashlib.sha1(div_url.encode("utf-8")).hexdigest()[:16]
    return RAW / state.lower() / "_enum" / f"{h}.txt"


# --- Resume checkpoint (skip COMPLETED divisions across restarts) ----------------
# The supervisor restarts the downloader every time the ~30-min Cloudflare clearance
# cookie expires. Without this, each restart re-walks the whole corpus from div 1
# (re-parsing the ~10k cached pages + re-enumerating whole divisions over the network),
# burning most of a cookie window before reaching new work. We checkpoint a division as
# DONE only when its full section loop completes (a Blocked crashes before that), keyed
# on its url, and skip done divisions on restart.
DONE_FILE = RAW / "260615_done_divisions.txt"
COMPLETE_FRAC = 0.95   # bootstrap: an existing output file counts as "done" only if it
                       # already holds >= this fraction of its EXPECTED sections. Stubs
                       # (0 sections, all-403 under the old code) fail this and get
                       # re-fetched; the small slack tolerates a few genuine dead (404)
                       # links so a complete division isn't re-walked forever.


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


# Per-division manifest fragments + assembly. The manifest must list every section
# across the WHOLE corpus, but with resume-skip each pass only processes a few
# divisions. So each completed division writes its own fragment CSV, and the full
# manifest is assembled from ALL fragments on disk -- complete regardless of which
# divisions ran this pass. Masters are likewise rebuilt from the per-division .txt on
# disk (not just this pass's).
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
    dfs = []
    for f in sorted(RAW.glob("*/_manifest/*.csv")):
        try:
            d = pl.read_csv(f, infer_schema_length=0)        # all-str: robust concat
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


def fetch_pdf(url: str) -> bytes:
    last = None
    t0 = time.time()
    i = 0
    while True:
        if COOKIE_MODE:
            _maybe_reload_clearance()
        sess = _get_session()
        hdr = {"User-Agent": _ua} if (COOKIE_MODE and _ua) else {}
        try:
            r = sess.get(url, headers=hdr, timeout=60)
            if r.status_code == 200 and r.content[:4] == b"%PDF":
                return r.content
            if r.status_code in (404, 410):
                raise DeadLink(url, r.status_code)
            challenged = ("Just a moment" in (getattr(r, "text", "") or "")) or r.status_code in (403, 429, 503)
            last = f"status={r.status_code}"
            if challenged and not COOKIE_MODE:
                switch_to_cookie_mode()
                continue
        except DeadLink:
            raise
        except Exception as e:  # noqa: BLE001
            last = repr(e)
        if time.time() - t0 >= CHALLENGE_WAIT_S:
            raise Blocked(url, last or "unknown")
        if COOKIE_MODE:
            load_clearance()
        wait = min(60, BACKOFF[min(i, len(BACKOFF) - 1)]) + random.uniform(0, 5)
        print(f"   .. PDF retry ({last}) in {wait:.0f}s [{(time.time()-t0)/60:.0f}min]  {url}", flush=True)
        time.sleep(wait)
        i += 1


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
    Resumable: cached HTML (and, for ND, cached PDF) are reused. ND chapter pages
    carry the text as an embedded PDF (div#codes-content empty), parsed with pymupdf.
    Raises DeadLink (caller logs+skips) or Blocked (caller lets it propagate)."""
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

    if state in PDF_CHAPTER_STATES and not body.strip():    # ND chapter PDF
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
        return heading, body, year, nbytes, fetched, "no-pdf-link"
    return heading, body, year, nbytes, fetched, "html"


# --- Selection inputs -----------------------------------------------------------
def statename_of(url: str) -> str:
    s = segs(url)
    return s[1] if len(s) > 1 else "unknown"


def load_divisions() -> pl.DataFrame:
    cnt = pl.read_csv(COUNT_CSV)
    walked = set(pl.read_csv(REVIEW_CSV)["div_url"].to_list())
    return cnt.with_columns([
        pl.col("url").is_in(list(walked)).alias("walked"),
        pl.col("url").map_elements(statename_of, return_dtype=pl.Utf8).alias("statename"),
        pl.col("state_abbr").cast(pl.Enum(ORDER)).to_physical().alias("_o"),
    ]).sort(["_o", "kind", "div_slug"]).drop("_o")


def load_narrowed() -> dict[tuple[str, str], list[str]]:
    """(state_abbr, div_slug) -> ordered selected section URLs for walked divisions.
    Keep section iff chapter jh=='Y' AND section selected_final=='Y'; if a jh-kept
    chapter has zero kept sections (whole-chapter promotion), keep ALL its sections."""
    jh = pl.read_csv(JH_CSV)
    alw = pl.read_csv(ALLOW_CSV)
    keep_chaps = {(r["state_abbr"], r["div_slug"], r["chapter_key"])
                  for r in jh.filter(pl.col("selected_final_jh") == "Y")
                  .iter_rows(named=True)}
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
          f"{capped.height} floored -> true size larger, enumerated at download)")
    if capped.height:
        with pl.Config(tbl_rows=10, fmt_str_lengths=45):
            print(capped.select("state_abbr", "div_slug", "name", "n_sections"))
    print(f"WALKED divisions with kept sections: {len(narrowed)} "
          f"(of {walked.height} walked)")
    print(f"NARROWED sections kept: {n_narrowed}")
    print(f"PROJECTED TOTAL (floor): {whole_floor + n_narrowed} sections")
    per = 0.6 + DELAY + JITTER / 2   # ~fetch + polite delay + avg jitter
    print(f"Estimated full crawl: ~{(whole_floor + n_narrowed) * per / 3600:.1f} h "
          f"at {DELAY}s delay (excludes index-page walks)")


# --- Probe (spot-check extraction on given URLs) --------------------------------
def run_probe(urls: list[str]) -> None:
    load_clearance(verbose=True)
    for u in urls:
        st = _state_from_url(u)                 # infer state from the justia slug
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
    # Start in the original PLAIN method (no cookie). fetch() auto-escalates to cookie
    # mode on the first Cloudflare challenge -- so a fresh/clean IP runs the simple fast
    # method (no daemon needed) and only a challenged IP falls back to cookies.
    if COOKIE_MODE:
        load_clearance(verbose=True)
    print(f"method: {'COOKIE (cf_clearance + daemon)' if COOKIE_MODE else 'PLAIN (original chrome124, no cookie)'}"
          f" | auto-escalates to cookie on challenge", flush=True)
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
        # Keep the corpus-wide master + manifest current even if a cookie-expiry
        # Blocked crashes mid-pass (then re-raise so the supervisor retries).
        rebuild_masters(statenames)
        assemble_manifest()

    el = time.time() - t0
    print(f"\nPass finished in {el/60:.1f} min. {len(done)} divisions complete.")
    print("DONE_DOWNLOAD")


def process_division(r: dict, di: int, total_div: int, done: set[str],
                     narrowed: dict, t0: float) -> None:
    """Download one division (skip-protected by the caller). On full completion it
    writes the consolidated .txt + manifest fragment and marks the division done. A
    Blocked (cookie expiry) propagates out BEFORE any of that, so a partial division
    is never recorded as complete."""
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
    global DELAY, COOKIE_MODE
    ap = argparse.ArgumentParser()
    ap.add_argument("--download", action="store_true", help="run the full download")
    ap.add_argument("--plan", action="store_true", help="print projected size only")
    ap.add_argument("--probe", default="", help="comma-list of leaf URLs to test-extract")
    ap.add_argument("--states", default="", help="comma list e.g. ND,NE,LA (download subset)")
    ap.add_argument("--only-slugs", default="", help="comma list of div_slugs to keep")
    ap.add_argument("--delay", type=float, default=DELAY)
    ap.add_argument("--cookie-start", action="store_true",
                    help="start in cookie mode (skip the plain attempt; for an already-"
                         "challenged IP). Default: start PLAIN + auto-escalate on challenge.")
    args = ap.parse_args()
    DELAY = args.delay
    if args.cookie_start:
        COOKIE_MODE = True

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
