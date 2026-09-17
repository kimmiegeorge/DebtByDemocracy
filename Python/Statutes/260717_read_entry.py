"""Print specific entry bodies from a 260717 fetched file, matched by a substring in
the entry heading. Usage: python 260717_read_entry.py <file> <match1> [match2 ...]
Prints heading + body for each entry whose heading contains a match (case-insensitive),
trimmed to MAXB chars."""
import sys, re
from pathlib import Path

RAW = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\raw")
MAXB = int(__import__("os").environ.get("MAXB", "1400"))

f = sys.argv[1]
matches = [m.lower() for m in sys.argv[2:]]
p = Path(f)
if not p.is_absolute():
    p = RAW / f
txt = p.read_text(encoding="utf-8", errors="replace")
# split into entries on the 80-char banner
blocks = re.split(r"\n={80}\n", txt)
for blk in blocks:
    lines = blk.split("\n")
    if len(lines) < 2 or not lines[1].startswith("URL: "):
        continue
    heading = lines[0].strip()
    if matches and not any(m in heading.lower() for m in matches):
        continue
    body = "\n".join(lines[3:]) if len(lines) > 3 else ""
    body = re.sub(r"[ \t]+", " ", body).strip()
    print("=" * 80)
    print(heading)
    print("-" * 80)
    print(body[:MAXB])
    print()
