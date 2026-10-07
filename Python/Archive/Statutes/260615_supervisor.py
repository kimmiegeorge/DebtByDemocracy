#!/usr/bin/env python3
r"""
260615_supervisor.py  --  Debt by Democracy: state statute AI task

Detached-friendly supervisor for 260615_download_statutes.py (EXPANSION 25-state
Phase 2 download). One process that handles BOTH failure modes so there is only one
thing to keep alive, launched via the Windows Task Scheduler so it survives the
Claude desktop app/session being recycled (which reaps bash-spawned background jobs
as a group -- the confirmed root cause from the pilot).

Per attempt it Popens the downloader and monitors:
  - child exits 0           -> done (clean full pass).
  - child exits non-zero    -> crash; restart from cache.
  - log stops advancing for STALL_MINUTES -> hang; kill child, restart from cache.
Repeats until a clean pass (downloader prints DONE_DOWNLOAD + exits 0) or
MAX_ATTEMPTS. The cache makes every restart cheap (already-fetched pages/PDFs are
skipped). On a clean pass it self-unregisters the scheduled task.

Run (normally via Task Scheduler; see the Register-ScheduledTask launch in chat):
  ...\venv\Scripts\python.exe -u ...\260615_supervisor.py
"""
from __future__ import annotations

import ctypes
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = sys.executable
DOWNLOADER = HERE / "260615_download_statutes.py"
DOCS = (Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
        / "Data" / "Statutes" / "documentation")
LOG = DOCS / "260615_download_log.txt"
SLOG = DOCS / "260615_supervisor_log.txt"

STALL_MINUTES = 12
POLL_S = 30
MAX_ATTEMPTS = 200
PROGRESS_COOLDOWN_S = 30        # attempt did real work then crashed/hung -> resume fast
PROGRESS_MIN_S = 600           # an attempt running >= this was making progress
# Escalating backoff (seconds) for FAST failures -- the Cloudflare-block signature
# (downloader Blocked-aborts on the first uncached fetch in ~5 min). Indexed by the
# consecutive fast-fail streak; ride the block out instead of hammering it.
COOLDOWNS = [300, 600, 1200, 1800, 1800]
TASK_NAME = "DbD_ExpandDownload"

# Keep the machine awake for the duration (the crawl died once when the PC slept).
ES_CONTINUOUS = 0x80000000
ES_SYSTEM_REQUIRED = 0x00000001


def keep_awake(on: bool) -> None:
    try:
        flags = (ES_CONTINUOUS | ES_SYSTEM_REQUIRED) if on else ES_CONTINUOUS
        ctypes.windll.kernel32.SetThreadExecutionState(flags)
    except Exception:  # noqa: BLE001
        pass


def cleanup_task() -> None:
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
    """One downloader attempt. Returns (status, rc, elapsed_s); status in
    {done, crash, hang}."""
    stall_s = STALL_MINUTES * 60
    t0 = time.time()
    fh = open(LOG, "a", encoding="utf-8")
    fh.write(f"\n===== supervisor attempt @ {datetime.now().isoformat(timespec='seconds')} =====\n")
    fh.flush()
    p = subprocess.Popen([PY, "-u", str(DOWNLOADER), "--download", "--delay", "3.0"],
                         stdout=fh, stderr=subprocess.STDOUT)
    last_m, last_prog = log_mtime(), time.time()
    try:
        while True:
            time.sleep(POLL_S)
            rc = p.poll()
            if rc is not None:
                return ("done" if rc == 0 else "crash", rc, time.time() - t0)
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
                return ("hang", None, time.time() - t0)
    finally:
        try:
            fh.close()
        except Exception:
            pass


def main() -> None:
    keep_awake(True)
    slog(f"supervisor start (stall {STALL_MINUTES} min, poll {POLL_S}s, "
         f"max {MAX_ATTEMPTS} attempts, escalating cooldown {COOLDOWNS})")
    fail_streak = 0
    try:
        for attempt in range(1, MAX_ATTEMPTS + 1):
            status, rc, elapsed = run_once()
            slog(f"attempt {attempt}: status={status} rc={rc} ran {elapsed/60:.1f} min "
                 f"(fail_streak {fail_streak})")
            if status == "done":
                slog("DOWNLOAD COMPLETE (clean pass). supervisor exiting.")
                cleanup_task()
                return
            # An attempt that ran a while was doing real work (a native crash / hang
            # mid-crawl) -> resume fast. A FAST failure is the block signature -> ride
            # it out with escalating backoff.
            if elapsed >= PROGRESS_MIN_S:
                fail_streak = 0
                cd = PROGRESS_COOLDOWN_S
                slog(f"made progress ({elapsed/60:.0f} min) then died; cooldown {cd}s")
            else:
                cd = COOLDOWNS[min(fail_streak, len(COOLDOWNS) - 1)]
                fail_streak += 1
                slog(f"fast fail -> likely Cloudflare block; cooldown {cd}s (backing off)")
            time.sleep(cd)
        slog(f"gave up after {MAX_ATTEMPTS} attempts.")
        cleanup_task()
    finally:
        keep_awake(False)


if __name__ == "__main__":
    main()
