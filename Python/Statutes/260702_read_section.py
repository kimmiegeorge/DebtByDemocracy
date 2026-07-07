#!/usr/bin/env python3
r"""
260702_read_section.py -- Debt by Democracy: Phase 3-4 FINAL-14 extraction helper.

Same as 260624_read_section.py but globs the FINAL-14 corpus files, which carry the
260625_ date prefix (the expansion helper globbed 260615_). Pulls individual statute
sections out of the per-division consolidated .txt files under Data\Statutes\raw\<st>\.

Usage:
  python 260702_read_section.py <state_folder> <query> [--max N] [--list] [--file SUBSTR]
    <state_folder>  raw subfolder, case-insensitive (CT, il, ny, ...)
    <query>         substring matched against the block HEADER+URL (a section number
                    '7-369', a slug 'section-8102', or a keyword like 'referendum').
    --list          only print matching headers (no body), for scanning a division.
    --max N         cap bodies printed (default 8).
    --file SUBSTR   restrict to consolidated files whose name contains SUBSTR.
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
    for chunk in text.split(SEP):
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
    file_substr = None
    if "--file" in sys.argv:
        file_substr = sys.argv[sys.argv.index("--file") + 1].lower()

    sdir = find_state_dir(state)
    files = sorted(sdir.glob("260625_*.txt"))
    files = [f for f in files if not f.name.endswith("_statutes.txt")]
    if file_substr:
        files = [f for f in files if file_substr in f.name.lower()]

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
