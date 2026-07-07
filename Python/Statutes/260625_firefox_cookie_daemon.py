#!/usr/bin/env python3
r"""
260625_firefox_cookie_daemon.py  --  Debt by Democracy: Firefox cf_clearance harvester

REPLACES the Chrome CDP daemon (260615_cookie_daemon.py). Why: Cloudflare's Turnstile
now hard-LOOPS the daemon's dedicated Chrome because it is launched with a remote-
debugging port (CDP) and does automated reloads -- both are automation signals. The
user's NORMAL browser passes the checkbox fine. So instead of driving a browser by
automation, we let the user solve the checkbox in a NORMAL Firefox tab and just READ
the resulting cf_clearance cookie off Firefox's on-disk cookie store.

Firefox (unlike Chrome 149) does NOT App-Bound-encrypt its cookies -- they sit in
plain SQLite at <profile>\cookies.sqlite -- so we can read cf_clearance (even though it
is HttpOnly) with zero automation in the browser itself. Nothing for Cloudflare to flag.

How it works
------------
  1. Launches your normal Firefox at a Justia page (default profile, your real browsing
     identity -> the session that already passes the challenge).
  2. YOU solve the "Verify you are human" checkbox in that Firefox tab when it appears
     (~every 30 min -- that is Cloudflare's cookie TTL, unavoidable with any method).
  3. Every POLL_S it copies cookies.sqlite (+ -wal/-shm) to a temp dir, reads the
     cf_clearance for justia, and -- if changed -- writes it ATOMICALLY to CF_FILE with
     the matching Firefox User-Agent and the curl_cffi impersonation target. The crawler
     re-reads CF_FILE on change, so fresh cookies flow through with no restart.

The crawler must impersonate Firefox (cf_clearance is bound to UA + IP + ~TLS). curl_cffi
has firefox133/firefox135; we pin the closest (firefox135) and send the real FF UA.
260625_justia_fetch.py reads the `impersonate` + `user_agent` fields from CF_FILE.

Run (project venv) -- keep running alongside the crawl:
  Code\Python\venv\Scripts\python.exe -u Code\Python\Statutes\260625_firefox_cookie_daemon.py
  ...\260625_firefox_cookie_daemon.py --no-launch   (don't auto-open Firefox; use your own)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
CF_FILE = DOCS / "260615_cf_clearance.json"          # SAME file the crawler reads
LOG = DOCS / "260625_firefox_cookie_log.txt"

FIREFOX = r"C:\Program Files\Mozilla Firefox\firefox.exe"
FF_BASE = Path(os.environ["APPDATA"]) / "Mozilla" / "Firefox"
START_URL = "https://law.justia.com/codes/connecticut/"

POLL_S = 30
IMPERSONATE = "firefox135"     # closest curl_cffi target to installed Firefox (152)


def log(msg: str) -> None:
    line = f"{datetime.now().isoformat(timespec='seconds')}  {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass


def firefox_version() -> str:
    """Best-effort installed Firefox major.minor (for the UA). Falls back to 152.0."""
    try:
        # application.ini in the install dir holds Version=
        ini = Path(FIREFOX).parent / "application.ini"
        if ini.exists():
            m = re.search(r"^Version=([\d.]+)", ini.read_text(encoding="utf-8", errors="ignore"), re.M)
            if m:
                return m.group(1)
    except Exception:
        pass
    return "152.0"


def firefox_ua() -> str:
    major = firefox_version().split(".")[0]
    # Desktop Firefox UA is deterministic from the major version.
    return (f"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:{major}.0) "
            f"Gecko/20100101 Firefox/{major}.0")


def default_profile() -> Path:
    """Resolve the profile Firefox uses on a normal launch, from profiles.ini's
    [InstallXXprefix] Default=, else the newest *.default-release, else any with a
    cookies.sqlite."""
    ini = FF_BASE / "profiles.ini"
    rel = None
    if ini.exists():
        txt = ini.read_text(encoding="utf-8", errors="ignore")
        m = re.search(r"^\[Install[0-9A-Fa-f]+\][^\[]*?^Default=(.+)$", txt, re.M | re.S)
        if m:
            rel = m.group(1).strip().splitlines()[0].strip()
    if rel:
        p = FF_BASE / rel.replace("/", os.sep)
        if (p / "cookies.sqlite").exists():
            return p
    cands = sorted((FF_BASE / "Profiles").glob("*.default-release"),
                   key=lambda d: (d / "cookies.sqlite").stat().st_mtime
                   if (d / "cookies.sqlite").exists() else 0, reverse=True)
    for c in cands:
        if (c / "cookies.sqlite").exists():
            return c
    for c in (FF_BASE / "Profiles").glob("*"):
        if (c / "cookies.sqlite").exists():
            return c
    raise SystemExit("No Firefox profile with cookies.sqlite found.")


def read_cf_clearance(profile: Path) -> tuple[str, int]:
    """Return (cf_clearance value, expiry_unix) for a justia host, or ('', 0). Reads a
    COPY of cookies.sqlite (+wal/-shm) so Firefox's lock/WAL is respected and recent
    writes are seen."""
    src = profile / "cookies.sqlite"
    if not src.exists():
        return "", 0
    tmpdir = Path(tempfile.mkdtemp(prefix="ffck_"))
    try:
        for suf in ("", "-wal", "-shm"):
            s = Path(str(src) + suf)
            if s.exists():
                shutil.copy2(s, tmpdir / s.name)
        db = tmpdir / "cookies.sqlite"
        con = sqlite3.connect(str(db))
        try:
            rows = con.execute(
                "SELECT value, host, expiry FROM moz_cookies "
                "WHERE name='cf_clearance' AND host LIKE '%justia%' "
                "ORDER BY expiry DESC"
            ).fetchall()
        finally:
            con.close()
        if not rows:
            return "", 0
        val, _host, exp = rows[0]
        exp = int(exp or 0)
        # Firefox stores `expiry` in seconds, but some builds record ms/us -- normalize
        # to seconds so the TTL/expiry check isn't nonsense.
        while exp > 32503680000:               # > year 3000 in seconds -> too-fine unit
            exp //= 1000
        return (val or ""), exp
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def write_cf(cf: str, ua: str) -> None:
    note = ("Auto-maintained by 260625_firefox_cookie_daemon.py (reads cf_clearance "
            "from Firefox's cookies.sqlite). Solve the checkbox in the Firefox tab; "
            "no copy-paste needed.")
    data = {"cf_clearance": cf, "user_agent": ua, "impersonate": IMPERSONATE, "_note": note}
    tmp = CF_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.replace(tmp, CF_FILE)


def launch_firefox() -> None:
    if not Path(FIREFOX).exists():
        log(f"WARNING: Firefox not found at {FIREFOX}; open Justia in Firefox yourself.")
        return
    try:
        subprocess.Popen([FIREFOX, "-new-tab", START_URL])
        log(f"opened Firefox tab at {START_URL} (solve the checkbox there if shown)")
    except Exception as e:
        log(f"could not launch Firefox: {e}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-launch", action="store_true", help="don't auto-open Firefox")
    args = ap.parse_args()

    log("=" * 60)
    log("firefox cookie harvester start")
    profile = default_profile()
    ua = firefox_ua()
    log(f"profile: {profile.name}")
    log(f"UA: {ua}  | impersonate: {IMPERSONATE}")
    if not args.no_launch:
        launch_firefox()

    last_cf = ""
    last_warn = 0.0
    while True:
        try:
            cf, exp = read_cf_clearance(profile)
            now = int(time.time())
            if not cf:
                if time.time() - last_warn > 60:
                    log("ACTION NEEDED: no cf_clearance yet -- open/refresh "
                        "law.justia.com in Firefox and solve the checkbox.")
                    last_warn = time.time()
            elif exp and exp < now:
                if time.time() - last_warn > 60:
                    log(f"ACTION NEEDED: cf_clearance EXPIRED ({exp-now}s ago) -- "
                        "refresh law.justia.com in Firefox and solve the checkbox.")
                    last_warn = time.time()
            elif cf != last_cf:
                write_cf(cf, ua)
                last_cf = cf
                ttl = (exp - now) if exp else 0
                log(f"updated cf_clearance ({len(cf)} chars, ~{ttl}s TTL) -> {CF_FILE.name}")
        except Exception as e:
            log(f"harvest error: {e!r}")
        time.sleep(POLL_S)


if __name__ == "__main__":
    main()
