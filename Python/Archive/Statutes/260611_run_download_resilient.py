#!/usr/bin/env python3
r"""
260611_run_download_resilient.py  --  Debt by Democracy: state statute AI task

Supervisor for 260611_download_statutes.py. The downloader can die from a NATIVE
crash in curl_cffi/libcurl (no Python traceback, not catchable in-process). Since
the download is resumable from the on-disk HTML cache, this wrapper simply re-runs
the downloader until one pass completes cleanly (exit 0), surviving intermittent
crashes. Each restart skips already-cached sections.

Output (stdout of each attempt) is appended to the shared download log.

Run (project venv):
  ...\venv\Scripts\python.exe ...\260611_run_download_resilient.py
"""
from __future__ import annotations

import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
PY = sys.executable  # the venv python running this wrapper
DOWNLOADER = HERE / "260611_download_statutes.py"
LOG = (Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
       / "Data" / "Statutes" / "documentation" / "260611_download_log.txt")

MAX_ATTEMPTS = 60
COOLDOWN_S = 8  # brief pause after a crash before resuming


def main() -> None:
    cmd = [PY, "-u", str(DOWNLOADER), "--mode", "download", "--delay", "0.8"]
    for attempt in range(1, MAX_ATTEMPTS + 1):
        with open(LOG, "a", encoding="utf-8") as fh:
            fh.write(f"\n===== supervisor attempt {attempt}/{MAX_ATTEMPTS} "
                     f"@ {datetime.now().isoformat(timespec='seconds')} =====\n")
            fh.flush()
            rc = subprocess.run(cmd, stdout=fh, stderr=subprocess.STDOUT).returncode
            fh.write(f"\n----- attempt {attempt} exited rc={rc} "
                     f"@ {datetime.now().isoformat(timespec='seconds')} -----\n")
            fh.flush()
        print(f"attempt {attempt} exited rc={rc}", flush=True)
        if rc == 0:
            print("download completed cleanly; supervisor done.", flush=True)
            return
        time.sleep(COOLDOWN_S)
    print(f"gave up after {MAX_ATTEMPTS} attempts; check the log.", flush=True)


if __name__ == "__main__":
    main()
