#!/usr/bin/env python3
r"""
260611_extract_operative.py  --  Debt by Democracy: state statute AI task

Phase 4 helper. Pull the operative bond/vote sections (identified from the curated
seed pointers + dummy) out of the consolidated corpus files into ONE markdown
reading file, so all remaining states can be classified in a single pass.
Matches section blocks by id substring in the block heading.
Writes: documentation\260611_operative_sections.md
"""
from __future__ import annotations
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
RAW = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\raw")
OUT = RAW.parent / "documentation" / "260611_operative_sections.md"
SEP = "=" * 80

# (state, consolidated file, [id substrings to find in headings], chars to show)
TARGETS = [
    ("AL", "AL/alabama_constitution.txt", ["222.01", "SECTION 222 ", "SECTION 222\n"], 2500),
    ("AZ", "AZ/arizona_title-35.txt", ["35-452", "35-451", "35-511"], 2200),
    ("AZ", "AZ/arizona_title-9.txt", ["9-441.03", "9-523"], 1800),
    ("AZ", "AZ/arizona_title-11.txt", ["11-372"], 1800),
    ("MA", "MA/massachusetts_title-vii.txt", ["Chapter 44, Section 7 ", "Chapter 44, Section 8 ",
                                             "Chapter 44, Section 8A "], 2600),
    ("NH", "NH/new-hampshire_title-iii.txt", ["Section 33:8 (", "Section 33:8-e ("], 2200),
    ("TN", "TN/tennessee_title-9.txt", ["9-21-108", "9-21-205", "9-21-206"], 2200),
]


def blocks(text: str):
    cur = []
    for line in text.splitlines():
        if line.startswith(SEP):
            if cur:
                yield "\n".join(cur)
                cur = []
        else:
            cur.append(line)
    if cur:
        yield "\n".join(cur)


def main() -> None:
    out = ["# Operative bond/vote sections (for classification)\n"]
    for state, rel, ids, limit in TARGETS:
        p = RAW / rel
        if not p.exists():
            out.append(f"\n## {state} {rel} — FILE MISSING\n")
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        out.append(f"\n## {state}  ({rel})")
        found = set()
        for blk in blocks(text):
            for idsub in ids:
                if idsub in blk[:200] and idsub not in found:
                    found.add(idsub)
                    out.append(f"\n### match: {idsub}\n```\n{blk.strip()[:limit]}\n```")
        missing = [i for i in ids if i not in found]
        if missing:
            out.append(f"\n_(not found: {missing})_")
    OUT.write_text("\n".join(out), encoding="utf-8")
    print("wrote", OUT, "len", len(OUT.read_text(encoding='utf-8')))


if __name__ == "__main__":
    main()
