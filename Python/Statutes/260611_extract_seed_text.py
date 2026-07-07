#!/usr/bin/env python3
r"""
260611_extract_seed_text.py  --  Debt by Democracy: state statute AI task

Phase 4 helper. For a pilot state, produce a markdown "reading packet" that grounds
the source-level classification in the actual downloaded text:
  (A) SEED SECTIONS  -- full clean text of each curated seed pointer
      (from 260611_pilot_seed_manifest.csv) that we have in the corpus.
  (B) VOTE-LANGUAGE SCAN -- every downloaded section for the state whose text
      mentions voting/elections/referendum/approval, with the matching snippet,
      so the operative provisions (and their absence) are easy to confirm.

Seeds that are non-Justia / not in the corpus (e.g. league PDFs) are listed as
gaps to fetch or classify separately.

Reuses extract() from 260611_download_statutes.py.

Usage:
  ...\venv\Scripts\python.exe ...\260611_extract_seed_text.py AK KY
Writes: documentation\260611_seedtext_<STATE>.md  (one per state)
"""
from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

import polars as pl

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
STAT = HOME / "Data" / "Statutes"
DOCS = STAT / "documentation"
RAW = STAT / "raw"
SEED = DOCS / "260611_pilot_seed_manifest.csv"
MANIFEST = RAW / "260611_download_manifest.csv"

_spec = importlib.util.spec_from_file_location("dl", HERE / "260611_download_statutes.py")
dl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dl)

# Voting / approval language to surface. Word-boundary-ish, case-insensitive.
VOTE_RE = re.compile(
    r"\b(vote[ds]?|voters?|voting|election|referend\w*|elector\w*|ballot|"
    r"majority|two-thirds|three-fifths|3/5|2/3|60\s?percent|sixty percent|"
    r"qualified electors|approv\w+ by the|submitted to the (?:voters|electors|qualified))\b",
    re.I,
)


def clean_body(cache_rel: str) -> tuple[str, str]:
    p = STAT / cache_rel
    if not p.exists():
        return "", ""
    html = p.read_text(encoding="utf-8", errors="replace")
    heading, body, _ = dl.extract(html)
    return heading, body


def sentences(body: str) -> list[str]:
    # crude sentence split good enough for snippets
    return re.split(r"(?<=[.;:])\s+(?=[A-Z(0-9])", body)


def snippet_for(body: str, max_snips: int = 2) -> list[str]:
    out = []
    for s in sentences(body):
        if VOTE_RE.search(s):
            out.append(re.sub(r"\s+", " ", s).strip()[:300])
        if len(out) >= max_snips:
            break
    return out


def write_state(abbr: str) -> None:
    seed = pl.read_csv(SEED).filter(pl.col("state_abbr") == abbr)
    man = pl.read_csv(MANIFEST).filter(pl.col("state_abbr") == abbr)
    man_by_url = {r["section_url"]: r for r in man.iter_rows(named=True)}

    out = [f"# Seed-grounded reading packet: {abbr}", ""]

    # (A) seed sections
    out.append("## (A) Curated seed pointers")
    for r in seed.iter_rows(named=True):
        url, note, stype = r["url"], r["link_note"] or "", r["source_type"]
        out.append(f"\n### seed [{stype}] {note or '(no note)'}\n- url: {url}")
        if url in man_by_url:
            cr = man_by_url[url]
            h, b = clean_body(cr["cache_path"])
            out.append(f"- in corpus: {cr['cache_path']}  (effective_year {cr['effective_year']})")
            out.append(f"- HEADING: {h}")
            out.append("\n```\n" + (b[:4000] if b else "(empty)") + "\n```")
        else:
            out.append("- NOT in Justia corpus (non-Justia seed: secondary site / PDF "
                       "or covered by a Justia chapter). Read the consolidated chapter "
                       "file or fetch separately.")

    # (B) vote-language scan over all downloaded sections for the state
    scan_lines: list[str] = []
    hits = 0
    for r in man.filter(pl.col("http_status") == 200).iter_rows(named=True):
        h, b = clean_body(r["cache_path"])
        if not b:
            continue
        snips = snippet_for(b)
        if snips:
            hits += 1
            scan_lines.append(f"\n- **{h[:90]}**  ({r['div_slug']})")
            scan_lines.append(f"  - {r['section_url']}")
            for s in snips:
                scan_lines.append(f"  - …{s}…")
    out.append("\n## (B) Vote/election language scan (downloaded sections)")
    out.append(f"\n_{hits} sections contain vote/election language._")
    out.extend(scan_lines)

    dest = DOCS / f"260611_seedtext_{abbr}.md"
    dest.write_text("\n".join(out), encoding="utf-8")
    print(f"{abbr}: seeds={seed.height}  corpus_sections={man.height}  "
          f"vote_hits={hits}  ->  {dest.name}")


def main() -> None:
    states = [s.upper() for s in sys.argv[1:]] or ["AK", "KY"]
    for st in states:
        write_state(st)


if __name__ == "__main__":
    main()
