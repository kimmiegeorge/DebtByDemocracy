#!/usr/bin/env python3
r"""
260611_supervisor2.py  --  Debt by Democracy: state statute AI task

Self-contained, detached-friendly supervisor for 260611_download_statutes.py.
Handles BOTH failure modes in ONE process (so there is only one thing to keep
alive), and is meant to be launched via the Windows Task Scheduler so it survives
the agent shell/session being recycled (which previously reaped the background
downloader + supervisor + watchdog together at ~20:07).

Per attempt it Popens the downloader and monitors:
  - child exits 0           -> done (clean full pass).
  - child exits non-zero    -> crash; restart from cache.
  - log stops advancing for STALL_MINUTES -> hang; kill child, restart from cache.
Repeats until a clean pass or MAX_ATTEMPTS.

Run (normally via Task Scheduler; see launch in chat):
  ...\venv\Scripts\python.exe -u ...\260611_supervisor2.py
"""
from __future__ import annotations

import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = sys.executable
DOWNLOADER = HERE / "260611_download_statutes.py"
DOCS = (Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
        / "Data" / "Statutes" / "documentation")
LOG = DOCS / "260611_download_log.txt"
SLOG = DOCS / "260611_supervisor_log.txt"

STALL_MINUTES = 12
POLL_S = 30
MAX_ATTEMPTS = 80
COOLDOWN_S = 8
TASK_NAME = "DbD_StatuteDownload"


def cleanup_task() -> None:
    """Unregister our own scheduled task so nothing lingers after completion."""
    try:
        subprocess.run(["schtasks", "/Delete", "/TN", TASK_NAME, "/F"],
                       capture_output=True)
        slog(f"unregistered scheduled task '{TASK_NAME}'")
    except Exception as e:  # noqa: BLE001
        slog(f"task self-cleanup failed (remove manually if needed): {e}")


def slog(msg: str) -> None:
    line = f"{datetime.now().isoformat(timespec='seconds')}  {msg}"
    print(line, flush=True)
    with open(SLOG, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def log_mtime() -> float:
    try:
        return LOG.stat().st_mtime
    except FileNotFoundError:
        return 0.0


def run_once() -> tuple[str, int | None]:
    """One downloader attempt. Returns (status, rc) where status in
    {done, crash, hang}."""
    stall_s = STALL_MINUTES * 60
    fh = open(LOG, "a", encoding="utf-8")
    fh.write(f"\n===== supervisor2 attempt @ {datetime.now().isoformat(timespec='seconds')} =====\n")
    fh.flush()
    p = subprocess.Popen([PY, "-u", str(DOWNLOADER), "--mode", "download",
                          "--delay", "0.8"], stdout=fh, stderr=subprocess.STDOUT)
    last_m, last_prog = log_mtime(), time.time()
    try:
        while True:
            time.sleep(POLL_S)
            rc = p.poll()
            if rc is not None:
                return ("done" if rc == 0 else "crash", rc)
            m = log_mtime()
            if m > last_m:
                last_m, last_prog = m, time.time()
            elif time.time() - last_prog >= stall_s:
                idle = (time.time() - last_prog) / 60
                slog(f"STALL: no log progress for {idle:.0f} min; killing hung "
                     f"downloader PID {p.pid}")
                p.kill()
                try:
                    p.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    pass
                return ("hang", None)
    finally:
        try:
            fh.close()
        except Exception:
            pass


def main() -> None:
    slog(f"supervisor2 start (stall {STALL_MINUTES} min, poll {POLL_S}s, "
         f"max {MAX_ATTEMPTS} attempts)")
    for attempt in range(1, MAX_ATTEMPTS + 1):
        status, rc = run_once()
        slog(f"attempt {attempt}: status={status} rc={rc}")
        if status == "done":
            slog("DOWNLOAD COMPLETE (clean pass). supervisor2 exiting.")
            cleanup_task()
            return
        time.sleep(COOLDOWN_S)
    slog(f"gave up after {MAX_ATTEMPTS} attempts.")
    cleanup_task()


if __name__ == "__main__":
    main()
