#!/usr/bin/env python3
r"""
260625_justia_fetch.py  --  Debt by Democracy: shared Justia/Cloudflare fetch layer

The FINAL-15 batch (CT DE HI IL IN IA KS MD MN NV NY PA RI SC VA). As of 2026-06-25
Justia is in always-challenge Cloudflare mode: plain curl_cffi (impersonate=chrome124)
returns 403 "Just a moment" even on a code index page. The old Phase-1 scripts
(260613_select_titles.py / 260613_count_sections.py) use a cookie-LESS fetch() that
no longer passes. This module factors the cookie-aware fetch out of the expansion
downloader (260615_download_statutes.py) so EVERY new 260625_ script -- title
selection, count, megachapter, download -- shares one fetch path.

Method (identical to 260615_download_statutes.py)
  - PLAIN (chrome124, no cookie): the original fast method; works only on a clean IP.
  - COOKIE (chrome131 + cf_clearance + the user's real UA): needed under interactive
    challenge. The cookie is read live from a dedicated Chrome by the cookie daemon
    (260615_cookie_daemon.py / a 260625_ clone) and written to CF_FILE.
  fetch() STARTS plain and auto-escalates to cookie on the first challenge, re-reading
  CF_FILE each retry so a daemon/user-refreshed cookie is picked up WITHOUT a restart,
  and PATIENTLY waits out a challenge (up to CHALLENGE_WAIT_S) instead of crashing.
  Callers that already know the IP is challenged can call start_cookie_mode() first.

Exceptions: DeadLink (permanent 404/410 -> caller logs+skips) vs Blocked (transient
challenge/5xx/network that survived CHALLENGE_WAIT_S -> caller lets it propagate so a
block can never silently truncate a division).

This module performs NO polite delay itself -- callers throttle (see polite()).
"""
from __future__ import annotations

import json
import random
import re
import time
from pathlib import Path

from curl_cffi import requests as creq

# --- Paths / config ------------------------------------------------------------
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
# Reuse the EXISTING cookie file + daemon output (the daemon writes cf_clearance + UA
# here; no need for a second daemon if one is already maintaining it).
CF_FILE = DOCS / "260615_cf_clearance.json"

BASE = "https://law.justia.com"
IMPERSONATE_PLAIN = "chrome124"
IMPERSONATE_COOKIE = "chrome131"     # default cookie-mode TLS; OVERRIDDEN by CF_FILE's
                                     # "impersonate" field (the cookie harvester writes
                                     # the browser it harvested from, e.g. firefox135).

BACKOFF = [5, 15, 30, 60, 120]       # escalating per-retry sleep (s) for NON-challenge transients
CHALLENGE_WAIT_S = 1800              # max wait for a NON-challenge transient (5xx/network) -> Blocked
# On a Cloudflare CHALLENGE (stale cf_clearance) we do NOT hammer Justia with retries.
# Instead we PARK until the cookie file is refreshed (the harvester writes a new cookie
# after the user solves the checkbox), re-probing Justia at most once per SAFETY_REPING_S
# in case the block lifted without a cookie change. No deadline -> the crawl waits quietly
# (e.g. while the user is away) and resumes the instant a fresh cookie lands. This keeps an
# unattended challenge from generating a storm of pointless 403s (which can harden the block).
SAFETY_REPING_S = 900                # re-probe a parked challenge at most this often (15 min)
POLL_COOKIE_S = 5                    # how often to stat the cookie file while parked (local only)

PDF_RE = re.compile(r"https://statecodesfiles\.justia\.com[^\"'<> ]+\.pdf", re.I)

# --- module state --------------------------------------------------------------
COOKIE_MODE = False
_session = None
_ua = ""
_impersonate = IMPERSONATE_COOKIE     # cookie-mode TLS target; updated from CF_FILE
_cf_mtime = 0.0


class DeadLink(Exception):
    """Permanent 404/410 -- page genuinely gone (safe to skip + log)."""
    def __init__(self, url: str, status):
        super().__init__(f"dead {url} (status={status})")
        self.url, self.status = url, status


class Blocked(Exception):
    """Transient block (challenge/429/5xx/network) that survived all retries. FATAL to
    the attempt -- callers must NOT skip+continue, or a blocked run could finish 'clean'
    with silently-missing pages."""
    def __init__(self, url: str, detail: str):
        super().__init__(f"BLOCKED {url}: {detail}")
        self.url, self.detail = url, detail


def _get_session():
    global _session
    if _session is None:
        imp = _impersonate if COOKIE_MODE else IMPERSONATE_PLAIN
        _session = creq.Session(impersonate=imp)
    return _session


def load_clearance(verbose: bool = False) -> bool:
    """(Re)load cf_clearance + UA from CF_FILE into the session. Cheap; safe to call
    often. Returns True if a cookie was loaded."""
    global _ua, _impersonate, _session, _cf_mtime
    try:
        d = json.loads(CF_FILE.read_text(encoding="utf-8"))
        cf = (d.get("cf_clearance") or "").strip()
        _ua = (d.get("user_agent") or "").strip().strip("'\"")
        imp = (d.get("impersonate") or "").strip()
        if imp and imp != _impersonate:
            _impersonate = imp                 # cookie harvested from a different browser
            _session = None                    # rebuild the session with the new TLS target
            if verbose:
                print(f"   impersonation set to {imp} (from cookie file)", flush=True)
        if not cf:
            return False
        sess = _get_session()
        for dom in (".law.justia.com", "law.justia.com",
                    ".justia.com", "statecodesfiles.justia.com"):
            try:
                sess.cookies.set("cf_clearance", cf, domain=dom)
            except Exception:
                pass
        _cf_mtime = CF_FILE.stat().st_mtime
        if verbose:
            print(f"   loaded cf_clearance ({len(cf)} chars) + UA {_ua[:42]}...", flush=True)
        return True
    except Exception as e:
        if verbose:
            print(f"   !! could not load {CF_FILE.name}: {e}", flush=True)
        return False


def _maybe_reload_clearance() -> None:
    try:
        if CF_FILE.stat().st_mtime > _cf_mtime:
            load_clearance()
    except Exception:
        pass


def _wait_for_fresh_cookie(url: str) -> str:
    """Park (NO Justia traffic) on a Cloudflare challenge until CF_FILE is rewritten with a
    NEW cf_clearance (mtime increases beyond the one we last loaded), or until a long safety
    interval elapses. Polls the LOCAL file only and prints periodically so a supervisor's
    log-stall watchdog stays happy and the user sees the 'solve the checkbox' hint. Returns
    'updated' (new cookie landed) or 'safety' (time to re-probe in case the block lifted)."""
    start = time.time()
    last_print = 0.0
    base_mtime = _cf_mtime
    while True:
        try:
            m = CF_FILE.stat().st_mtime
        except Exception:
            m = base_mtime
        if m > base_mtime:
            print(f"   .. fresh cf_clearance detected -> resuming  {url}", flush=True)
            return "updated"
        if time.time() - start >= SAFETY_REPING_S:
            return "safety"
        if time.time() - last_print >= 45:
            print(f"   .. parked on Cloudflare challenge {(time.time()-start)/60:.0f}min; "
                  f"waiting for a fresh cf_clearance -- solve the checkbox in the Firefox "
                  f"tab (no requests sent meanwhile)  {url}", flush=True)
            last_print = time.time()
        time.sleep(POLL_COOKIE_S)


def switch_to_cookie_mode() -> None:
    """Escalate plain -> cookie after a challenge. Rebuilds the session with the cookie
    impersonation + loads cf_clearance. Idempotent."""
    global COOKIE_MODE, _session
    if COOKIE_MODE:
        return
    COOKIE_MODE = True
    _session = None
    print("   ** Cloudflare challenged the plain method -> switching to COOKIE mode "
          "(needs the cookie daemon running) **", flush=True)
    load_clearance(verbose=True)


def start_cookie_mode() -> None:
    """Force cookie mode from the start (for an already-challenged IP -- the 2026-06-25
    reality). Skips the doomed plain attempt."""
    global COOKIE_MODE, _session
    if not COOKIE_MODE:
        COOKIE_MODE = True
        _session = None
        load_clearance(verbose=True)


def fetch(url: str) -> str:
    """Fetch one HTML page. 200 -> text. Permanent 404/410 -> DeadLink. On a Cloudflare
    CHALLENGE (stale cookie) it auto-escalates to cookie mode, then PARKS until a fresh
    cf_clearance is written (no retry-pinging) and resumes. A NON-challenge transient
    (5xx/network) gets short escalating backoff for up to CHALLENGE_WAIT_S, then -> Blocked."""
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
            if challenged:
                if not COOKIE_MODE:
                    switch_to_cookie_mode()
                    continue
                # Stale cf_clearance: park (no requests) until the harvester writes a fresh
                # cookie, then retry. No deadline -> survives an unattended away period.
                _wait_for_fresh_cookie(url)
                load_clearance()
                t0, i = time.time(), 0        # reset the non-challenge transient budget
                continue
            last = f"status={r.status_code}"
        except DeadLink:
            raise
        except Exception as e:
            last = repr(e)
            # A redirect loop (curl 47 / TooManyRedirects) is a permanently bad URL, not a
            # rate block -- retrying never helps. Treat as DeadLink so callers skip it.
            if "curl: (47)" in last or "TooManyRedirects" in last or "redirects followed" in last:
                raise DeadLink(url, "redirect-loop(curl47)")
        if time.time() - t0 >= CHALLENGE_WAIT_S:
            raise Blocked(url, last or "unknown")
        wait = min(60, BACKOFF[min(i, len(BACKOFF) - 1)]) + random.uniform(0, 5)
        print(f"   .. retry ({last}) in {wait:.0f}s [{(time.time()-t0)/60:.0f}min]  {url}", flush=True)
        time.sleep(wait)
        i += 1


def fetch_pdf(url: str) -> bytes:
    """Fetch one PDF (statecodesfiles host). Same taxonomy as fetch()."""
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
            if challenged:
                if not COOKIE_MODE:
                    switch_to_cookie_mode()
                    continue
                _wait_for_fresh_cookie(url)
                load_clearance()
                t0, i = time.time(), 0
                continue
            last = f"status={r.status_code}"
        except DeadLink:
            raise
        except Exception as e:
            last = repr(e)
        if time.time() - t0 >= CHALLENGE_WAIT_S:
            raise Blocked(url, last or "unknown")
        wait = min(60, BACKOFF[min(i, len(BACKOFF) - 1)]) + random.uniform(0, 5)
        print(f"   .. PDF retry ({last}) in {wait:.0f}s [{(time.time()-t0)/60:.0f}min]  {url}", flush=True)
        time.sleep(wait)
        i += 1


if __name__ == "__main__":   # smoke test: python 260625_justia_fetch.py <url>
    import sys
    start_cookie_mode()
    u = sys.argv[1] if len(sys.argv) > 1 else "https://law.justia.com/codes/connecticut/"
    try:
        html = fetch(u)
        print(f"OK {len(html)} chars  cookie_mode={COOKIE_MODE}")
    except (DeadLink, Blocked) as e:
        print("FAIL", e)
