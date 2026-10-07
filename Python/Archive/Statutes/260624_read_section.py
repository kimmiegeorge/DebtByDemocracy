#!/usr/bin/env python3
r"""
260624_read_section.py -- Debt by Democracy: Phase 3-4 expansion extraction helper.

Utility to pull individual statute sections out of the per-division consolidated
.txt files under Data\Statutes\raw\<st>\ (built by 260615_download_statutes.py).
Each file is a sequence of blocks delimited by a line of '=' characters:

    ================================================================================
    <State> Code Sec. <cite> (<year>) - <heading>
    URL: https://law.justia.com/codes/.../section-.../
    --------------------------------------------------------------------------------
    <section text...>

Usage:
  python 260624_read_section.py <state_folder> <query> [--max N] [--list]
    <state_folder>  raw subfolder, case-insensitive (AR, mo, nc, ...)
    <query>         substring matched against the block HEADER+URL (e.g. a section
                    number '14-72-606', a slug 'section-29901', or a keyword).
    --list          only print matching headers (no body), for scanning a division.
    --max N         cap bodies printed (default 8).
"""
from __future__ import annotations
import sys
from pathlib import Path

RAW = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\raw")
SEP = "=" * 80


def find_state_dir(name: str) -> Path:
    for p in RAW.iterdir():
        if p.is_dir() and p.name.lower() == name.lower():
            return p
    raise SystemExit(f"no state folder {name!r} under {RAW}")


def iter_blocks(text: str):
    # blocks are separated by a line of '=' (length 80). The header line follows
    # each separator; split on the separator and regroup.
    parts = text.split(SEP)
    for chunk in parts:
        chunk = chunk.strip("\n")
        if chunk.strip():
            yield chunk


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    state = sys.argv[1]
    query = sys.argv[2].lower()
    listonly = "--list" in sys.argv
    maxn = 8
    if "--max" in sys.argv:
        maxn = int(sys.argv[sys.argv.index("--max") + 1])

    sdir = find_state_dir(state)
    files = sorted(sdir.glob("260615_*.txt"))
    # skip the per-state master to avoid double hits
    files = [f for f in files if not f.name.endswith("_statutes.txt")]

    hits = 0
    bodies = 0
    for f in files:
        text = f.read_text(encoding="utf-8", errors="replace")
        for blk in iter_blocks(text):
            lines = blk.splitlines()
            header = "\n".join(lines[:3]).lower()
            if query in header or query in blk.lower()[:400]:
                hits += 1
                hdr = lines[0] if lines else ""
                url = next((l for l in lines if l.startswith("URL:")), "")
                if listonly:
                    print(f"[{f.name}] {hdr}  {url}")
                else:
                    if bodies < maxn:
                        print(SEP)
                        print(f"FILE: {f.name}")
                        print(blk)
                        print()
                        bodies += 1
    print(f"\n--- {hits} matching block(s); {min(bodies, maxn)} bodies shown ---",
          file=sys.stderr)


if __name__ == "__main__":
    main()
