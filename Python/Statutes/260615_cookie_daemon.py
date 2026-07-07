#!/usr/bin/env python3
r"""
260615_cookie_daemon.py  --  Debt by Democracy: Cloudflare clearance auto-refresher

Keeps Data\Statutes\documentation\260615_cf_clearance.json populated with a FRESH
cf_clearance cookie so the long Justia crawl never has to be hand-refreshed.

Why this exists: Justia put this IP into INTERACTIVE Cloudflare challenge mode. The
cf_clearance cookie a real browser earns by solving the "verify you are a human"
checkbox lasts only ~30 min, and Chrome 149 encrypts its cookie store (App-Bound
Encryption) so it can't be read from disk. So we attach to a live Chrome via the
DevTools Protocol (Playwright connect_over_cdp), read the cookie straight from the
running browser, and write it to the JSON. We also RELOAD a Justia page on a timer so
Cloudflare keeps renewing the clearance for this trusted browser session (renewal
happens on navigation; an idle tab would just expire).

How it works
------------
  1. Launches a DEDICATED Chrome instance (its own profile, so it never disturbs your
     normal browsing) with --remote-debugging-port, pointed at a Justia page.
  2. YOU solve the checkbox once in that window (only when Cloudflare prompts it).
  3. Every ~30 s it reads cf_clearance from the live browser and, if changed, writes it
     (atomically) to the JSON + the matching User-Agent. The crawler picks it up.
  4. Every ~8 min it reloads the page so Cloudflare re-issues clearance before the old
     one expires. If a reload re-prompts the checkbox, it prints an ACTION NEEDED line
     (and the Chrome window shows the checkbox) -- just click it.

The crawler (260615_download_statutes.py) re-reads the JSON on every challenge AND
whenever the file changes, so fresh cookies flow through without restarting anything.

Run (project venv) -- keep it running alongside the crawl:
  Code\Python\venv\Scripts\python.exe -u Code\Python\Statutes\260615_cookie_daemon.py
"""
from __future__ import annotations

import json
import os
import random
import subprocess
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

from playwright.sync_api import sync_playwright

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
CF_FILE = DOCS / "260615_cf_clearance.json"
LOG = DOCS / "260615_cookie_daemon_log.txt"

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PROFILE = HOME / "Code" / "Python" / ".chrome_cf_profile"   # dedicated, persistent
PORT = 9222
START_URL = "https://law.justia.com/codes/arkansas/"
COOKIE_DOMAIN_URL = "https://law.justia.com"

POLL_S = 30           # how often to read + sync the cookie
RELOAD_EVERY_S = 480  # reload the page to renew clearance (well under the ~30-min TTL)
MAX_AUTO_SOLVE = 4    # consecutive auto-solve attempts before falling back to alerting the user
                      # (don't hammer Cloudflare -- repeated failed solves could harden the block)


def log(msg: str) -> None:
    line = f"{datetime.now().isoformat(timespec='seconds')}  {msg}"
    print(line, flush=True)
    try:
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass


_last_alert = 0.0


def alert_action_needed() -> None:
    """Log (no sound) that the user needs to click the Cloudflare checkbox."""
    global _last_alert
    now = time.time()
    if now - _last_alert < 18:
        return
    _last_alert = now
    log("ACTION NEEDED: click the 'Verify you are human' checkbox in the dedicated "
        "Chrome window. The crawl auto-resumes within ~30s of the click.")


def cdp_up() -> bool:
    try:
        with urllib.request.urlopen(f"http://localhost:{PORT}/json/version", timeout=3) as r:
            return r.status == 200
    except Exception:
        return False


def launch_chrome() -> subprocess.Popen:
    PROFILE.mkdir(parents=True, exist_ok=True)
    args = [CHROME, f"--remote-debugging-port={PORT}", f"--user-data-dir={PROFILE}",
            "--no-first-run", "--no-default-browser-check",
            "--disable-popup-blocking", START_URL]
    log(f"launching dedicated Chrome (profile {PROFILE.name}, port {PORT})")
    p = subprocess.Popen(args)
    for _ in range(40):
        if cdp_up():
            log("Chrome DevTools endpoint is up")
            return p
        time.sleep(0.5)
    log("WARNING: CDP endpoint did not come up in 20s (continuing to try)")
    return p


def write_cf(cf: str, ua: str) -> None:
    note = ("Auto-maintained by 260615_cookie_daemon.py (reads the live cf_clearance "
            "from the dedicated Chrome via CDP). To refresh manually instead, stop the "
            "daemon and paste cf_clearance + user_agent here.")
    data = {"cf_clearance": cf, "user_agent": ua, "_note": note}
    tmp = CF_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.replace(tmp, CF_FILE)            # atomic: the crawler never reads a half-written file


def get_justia_page(context):
    for pg in context.pages:
        try:
            if "justia.com" in (pg.url or ""):
                return pg
        except Exception:
            continue
    pg = context.pages[0] if context.pages else context.new_page()
    try:
        pg.goto(START_URL, timeout=60000)
    except Exception:
        pass
    return pg


def is_challenge(page) -> bool:
    try:
        t = (page.title() or "").lower()
        if "just a moment" in t or "attention required" in t:
            return True
        body = page.inner_text("body", timeout=2000).lower()
        return "verify you are human" in body or "checking your browser" in body
    except Exception:
        return False


CF_IFRAME = ("iframe[src*='challenges.cloudflare.com'], iframe[title*='Cloudflare'], "
             "iframe[title*='challenge'], iframe[title*='human'], iframe[title*='Widget']")


def try_solve_challenge(page) -> bool:
    """Attempt to click the Turnstile checkbox ourselves, human-like. Our Chrome is
    launched plainly (navigator.webdriver=false), so a trusted mouse click on the
    checkbox often clears the managed challenge. Returns True if the challenge cleared.
    Best-effort; on failure the caller falls back to alerting the user."""
    time.sleep(random.uniform(1.2, 2.6))                      # let the widget render + look human
    clicked = False
    # 1) mouse-click the checkbox by the iframe's on-screen box (checkbox sits left-center)
    try:
        el = page.wait_for_selector(CF_IFRAME, timeout=8000)
        box = el.bounding_box() if el else None
        if box:
            x = box["x"] + 32 + random.uniform(-4, 4)
            y = box["y"] + box["height"] / 2 + random.uniform(-3, 3)
            page.mouse.move(x - 50, y - 25)
            time.sleep(random.uniform(0.15, 0.4))
            page.mouse.move(x, y)
            time.sleep(random.uniform(0.1, 0.3))
            page.mouse.click(x, y)
            clicked = True
            log("auto-solve: clicked the Turnstile checkbox by coordinates")
    except Exception as e:  # noqa: BLE001
        log(f"auto-solve coordinate click failed: {e}")
    # 2) also try clicking an actual checkbox/label inside the challenge iframe
    if not clicked:
        try:
            fl = page.frame_locator(CF_IFRAME).first
            fl.locator("input[type='checkbox'], label, .cb-lb").first.click(timeout=4000)
            clicked = True
            log("auto-solve: clicked the checkbox inside the challenge iframe")
        except Exception:
            pass
    if not clicked:
        return False
    for _ in range(8):                                        # wait up to ~16s for it to clear
        time.sleep(2)
        if not is_challenge(page):
            log("auto-solve: challenge cleared")
            return True
    return False


def run_session() -> None:
    """One connected session; returns (to be relaunched) if Chrome/CDP drops."""
    with sync_playwright() as pw:
        browser = pw.chromium.connect_over_cdp(f"http://localhost:{PORT}")
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = get_justia_page(context)
        log("attached to Chrome via CDP; watching cf_clearance")
        last_cf = ""
        last_reload = time.time()
        warned_challenge = False
        solve_fails = 0                                       # consecutive auto-solve failures
        while True:
            if not cdp_up():
                log("CDP endpoint gone (Chrome closed?) -- will relaunch")
                return
            # reload periodically to renew clearance
            if time.time() - last_reload >= RELOAD_EVERY_S:
                try:
                    page.reload(timeout=60000)
                    log("reloaded page to renew clearance")
                except Exception as e:  # noqa: BLE001
                    log(f"reload failed: {e}")
                last_reload = time.time()

            if is_challenge(page):
                # Auto-clicking is unreliable: Cloudflare's Turnstile re-loops a
                # programmatic click (behavioral bot detection). So we ALERT the user to
                # click it themselves -- loudly, so they needn't watch the window.
                alert_action_needed()
                time.sleep(POLL_S)
                continue

            # not a challenge (or just cleared) -> read + sync the cookie
            warned_challenge = False
            try:
                cookies = context.cookies(COOKIE_DOMAIN_URL)
                cf = next((c["value"] for c in cookies if c["name"] == "cf_clearance"), "")
                if cf and cf != last_cf:
                    ua = page.evaluate("() => navigator.userAgent")
                    write_cf(cf, ua)
                    last_cf = cf
                    log(f"updated cf_clearance ({len(cf)} chars) -> {CF_FILE.name}")
            except Exception as e:  # noqa: BLE001
                log(f"cookie read failed: {e}")
            time.sleep(POLL_S)


def main() -> None:
    log("=" * 60)
    log("cookie daemon start")
    if not Path(CHROME).exists():
        log(f"FATAL: Chrome not found at {CHROME}")
        return
    chrome_proc = None
    while True:
        try:
            if not cdp_up():
                chrome_proc = launch_chrome()
            run_session()
        except Exception as e:  # noqa: BLE001
            log(f"session error: {e!r}; retrying in 10s")
        time.sleep(10)


if __name__ == "__main__":
    main()
