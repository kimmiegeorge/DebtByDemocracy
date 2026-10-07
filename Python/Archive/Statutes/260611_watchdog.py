#!/usr/bin/env python3
r"""
260611_watchdog.py  --  Debt by Democracy: state statute AI task

Autonomous stall-watchdog for the download supervisor. The supervisor
(260611_run_download_resilient.py) restarts the downloader when it *exits*
(e.g. a native curl_cffi crash). It CANNOT detect a HANG -- a downloader process
that is alive but stuck on a socket that never returns. This watchdog closes that
gap: it watches the download log's last-write time and, if there has been no
progress for STALL_MINUTES, it kills the stuck downloader child so the supervisor
resurrects it from cache.

It only ever kills the DOWNLOADER child (cmdline contains 260611_download_statutes.py),
never the supervisor. It runs as long as the supervisor is alive, then exits.

Safe to run alongside an already-running supervisor.

Run (project venv):
  ...\venv\Scripts\python.exe ...\260611_watchdog.py
"""
from __future__ import annotations

import time
from datetime import datetime
from pathlib import Path

import psutil

DOCS = (Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
        / "Data" / "Statutes" / "documentation")
LOG = DOCS / "260611_download_log.txt"
WLOG = DOCS / "260611_watchdog_log.txt"

DOWNLOADER_TAG = "260611_download_statutes.py"
SUPERVISOR_TAG = "260611_run_download_resilient.py"

CHECK_INTERVAL_S = 60        # how often to poll
STALL_MINUTES = 12           # no log progress this long -> declare a hang
GRACE_AFTER_KILL_S = 90      # don't re-evaluate stall immediately after a kill


def log(msg: str) -> None:
    line = f"{datetime.now().isoformat(timespec='seconds')}  {msg}"
    print(line, flush=True)
    with open(WLOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def procs_with(tag: str) -> list[psutil.Process]:
    out = []
    for p in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            cl = " ".join(p.info["cmdline"] or [])
            if tag in cl:
                out.append(p)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return out


def log_mtime() -> float:
    try:
        return LOG.stat().st_mtime
    except FileNotFoundError:
        return 0.0


def main() -> None:
    stall_s = STALL_MINUTES * 60
    log(f"watchdog start (stall threshold {STALL_MINUTES} min, poll {CHECK_INTERVAL_S}s)")
    last_mtime = log_mtime()
    last_progress = time.time()

    # Wait briefly for the supervisor to appear (in case launched together).
    for _ in range(10):
        if procs_with(SUPERVISOR_TAG):
            break
        time.sleep(3)
    if not procs_with(SUPERVISOR_TAG):
        log("no supervisor process found at start; exiting.")
        return

    while True:
        time.sleep(CHECK_INTERVAL_S)

        if not procs_with(SUPERVISOR_TAG):
            log("supervisor process gone (download finished or stopped); watchdog exiting.")
            return

        m = log_mtime()
        if m > last_mtime:
            last_mtime = m
            last_progress = time.time()
            continue

        idle = time.time() - last_progress
        if idle >= stall_s:
            kids = procs_with(DOWNLOADER_TAG)
            if not kids:
                # No downloader child but supervisor alive: it's between attempts
                # (cooldown) -- give it time rather than acting.
                log(f"no log progress for {idle/60:.0f} min but no downloader child "
                    f"(supervisor likely restarting); waiting.")
                last_progress = time.time()
                continue
            for p in kids:
                try:
                    log(f"STALL detected: no log progress for {idle/60:.0f} min. "
                        f"Killing hung downloader PID {p.pid} so supervisor restarts it.")
                    p.kill()
                except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
                    log(f"  kill PID {p.pid} failed: {e}")
            time.sleep(GRACE_AFTER_KILL_S)
            last_mtime = log_mtime()
            last_progress = time.time()


if __name__ == "__main__":
    main()
