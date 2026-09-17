"""
260717_stub_sweep.py  --  Part 1 corpus-only stub sweep (NO network).

Detects three defects across every per-division / constitution reading file
produced by the 260625_ and 260615_ pipelines:

  (1) WHOLE-FILE STUB   -- the file is header-only (e.g. NV constitution: banner
                           + source_url, then nothing). Caught by "0 body entries"
                           / tiny total body.
  (2) ARTICLE-LEVEL STUB -- an individual entry (Article/Division/Chapter) whose
                           body after the '---' divider is empty or trivially short
                           (e.g. IL 65 ILCS 5 Article 11: banner + URL + article
                           heading, then jumps to the next article). This sits
                           INSIDE an otherwise-healthy multi-MB file, so file-size
                           sweeps miss it -- we walk entry boundaries within files.
  (3) POSSIBLE TOC-ONLY  -- reported via avg WORDS/LINE over body prose (~6-9 =
                           wrapped body prose; a title-only TOC runs far lower).
                           NOTE: we deliberately DO NOT use a "lines longer than N
                           chars" heuristic -- it falsely flagged IA/IL/IN/MN/RI
                           (they are merely hard-wrapped, fully intact).

Entry format (identical in both pipelines, HDR='='*80, SUB='-'*80):
  file header block:  HDR \n name (dslug) \n source_url: url \n HDR
  each entry:         HDR \n heading \n URL: surl \n SUB \n body

Usage:
  <venv>\Scripts\python.exe 260717_stub_sweep.py
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\raw")
HDR = "=" * 80
SUB = "-" * 80

# a container index URL ends in /article-<n>/, /division-<n>/, /part-<n>/,
# /subdivision-<n>/, /chapter-<n>/ (Roman or arabic). Leaf sections end /section-*/.
CONTAINER_RE = re.compile(
    r"/(article|division|subdivision|part|chapter)-[0-9ivxlcdm]+/?\s*$",
    re.IGNORECASE)

# an empty container whose heading/body contains any of these is EXPECTED empty
# (structural, not a crawl failure) -- the text lives elsewhere or was never codified.
# a catchline / TOC index line. Several Justia layouts:
#   OK/TX: "Section X-1: Fiscal year."         (Section <label>: title)
#   UT:    "Article XIV,  Section 3"           (Article <n>, Section <n> index)
#          "[Certain debt of counties ...]"    (bracketed catchline title)
#   generic: "Sec. 5."
# (Healthy article section headers are ALL-CAPS "SECTION 1." and get stripped as
# heading-echo before this test, so they don't inflate the ratio.)
CATCHLINE_RE = re.compile(
    r"^(Section\b[^\n]*:"
    r"|Sec\.\s"
    r"|Article\s+[\w-]+,\s*Section\b"
    r"|\[[^\]]+\]\s*$)"
)
# nav / structural lines to drop before scoring an article body
TOC_NAV_LINES = ("Articles in the Constitution", "[Previous]", "[Next]", "[Up]", "[Top]")

BENIGN_EMPTY = (
    "amendatory", "uncodified", "compiled at", "compiled elsewhere", "is compiled",
    "text omitted", "renumber", "repeal", "obsolete", "reserved", "(blank)",
    "effective date", "severability", "short title", "findings", "per diem",
)

# residual prose (heading-echo stripped) shorter than this = stub candidate.
# A real heading-only stub collapses to ~0 chars; a genuinely short leaf section
# keeps a full sentence (70+ chars). 60 catches the former, spares the latter.
SHORT_BODY_CHARS = 60
# words/line below this over a large-ish file is a TOC-only candidate.
TOC_WPL = 4.0
TOC_MIN_LINES = 120


def split_entries(text: str):
    """Yield (heading, url, body) for each non-header entry in a reading file.

    The file header block is the first HDR-delimited block containing 'source_url:';
    we skip it (but return it separately so the caller can see file-level content)."""
    # Normalize newlines.
    lines = text.split("\n")
    # Find indices of banner lines.
    banner_idx = [i for i, ln in enumerate(lines) if ln == HDR]
    entries = []
    header_block = None
    # Blocks are the spans between consecutive banners.
    for b in range(len(banner_idx)):
        start = banner_idx[b] + 1
        end = banner_idx[b + 1] if b + 1 < len(banner_idx) else len(lines)
        block = lines[start:end]
        if not block:
            continue
        # Is this the file-header block? (has a 'source_url:' line, no 'URL:' entry line)
        joined_head = "\n".join(block[:3])
        if "source_url:" in joined_head and not any(l.startswith("URL: ") for l in block[:3]):
            header_block = block
            continue
        # An entry block: heading on block[0], 'URL:' on block[1], SUB on block[2], body after.
        if len(block) >= 2 and block[1].startswith("URL: "):
            heading = block[0].strip()
            url = block[1][len("URL: "):].strip()
            # body is everything after the SUB divider line within this block
            body_lines = block
            if len(block) >= 3 and block[2] == SUB:
                body_lines = block[3:]
            else:
                body_lines = block[2:]
            body = "\n".join(body_lines)
            entries.append((heading, url, body))
    return header_block, entries


def residual_prose(body: str, heading: str) -> str:
    """Return the body with heading-echo lines removed, so a heading-only stub
    (IL Art 11: '(65 ILCS 5/Art. 11 heading)' / 'ARTICLE 11' / 'CORPORATE POWERS
    AND FUNCTIONS') collapses to empty, while a genuinely short leaf section
    (a one-sentence constitution provision) keeps its sentence-case prose.

    Dropped as heading-echo:
      - blank lines
      - lines equal to / contained in the entry heading
      - fully UPPERCASE lines (ARTICLE 11, CORPORATE POWERS...)
      - parenthetical-only citation lines  ( ... )
      - ARTICLE / DIVISION / SUBDIVISION / PART / TITLE / CHAPTER heading lines
    """
    head_norm = re.sub(r"\s+", " ", heading).strip().lower()
    keep = []
    for raw in body.split("\n"):
        ln = raw.strip()
        if not ln:
            continue
        low = ln.lower()
        if low in head_norm or head_norm in low:
            continue
        # parenthetical-only line, e.g. "(65 ILCS 5/Art. 11 heading)"
        if ln.startswith("(") and ln.endswith(")"):
            continue
        # fully uppercase (allow digits/punct) -> heading echo
        letters = [c for c in ln if c.isalpha()]
        if letters and all(c.isupper() for c in letters):
            continue
        if re.match(r"^(ARTICLE|DIVISION|SUBDIVISION|PART|TITLE|CHAPTER)\b",
                    ln, re.IGNORECASE):
            continue
        keep.append(ln)
    return " ".join(keep)


def avg_words_per_line(text: str) -> float:
    lines = [l for l in text.split("\n") if l.strip()]
    if not lines:
        return 0.0
    words = sum(len(l.split()) for l in lines)
    return words / len(lines)


def main():
    files = []
    for st_dir in sorted(ROOT.iterdir()):
        if not st_dir.is_dir() or st_dir.name in ("_secondary",):
            continue
        for f in sorted(st_dir.glob("*.txt")):
            name = f.name
            if not (name.startswith("260625_") or name.startswith("260615_")):
                continue
            # skip the aggregated master (e.g. 260625_il_statutes.txt / nv_statutes.txt)
            if re.match(r"^2606\d\d_[a-z]{2}_statutes\.txt$", name):
                continue
            files.append(f)

    print(f"Scanning {len(files)} per-division/constitution files under {ROOT}\n")

    from collections import defaultdict
    whole_file_stubs = []
    container_by_act = defaultdict(list)  # (rel, act_url) -> [(heading,url,resid_len,repealed)]
    toc_candidates = []
    parse_notes = []

    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            parse_notes.append(f"READ FAIL {f}: {e}")
            continue
        rel = f.relative_to(ROOT)
        header_block, entries = split_entries(text)
        n_lines = text.count("\n") + 1
        size = f.stat().st_size

        # (1) whole-file stub: no entries at all, or all entry bodies empty
        total_body = sum(len(b.strip()) for _, _, b in entries)
        if len(entries) == 0 or total_body < 50:
            whole_file_stubs.append((rel, size, n_lines, len(entries), total_body))
            continue  # don't also article-flag a whole-file stub

        # (2) article-level stubs. The IL Art 11 signature is a CONTAINER entry
        #     (an article/division index page) whose body is only heading-echo,
        #     sitting among HEALTHY sibling containers in the same Act. We ignore
        #     leaf /section-*/ entries (legitimately short one-liners) and we
        #     group container empties by Act so we can tell a one-off crawl failure
        #     (minority empty among full siblings -> SUSPECT) from an amendatory /
        #     appropriation act whose articles are genuinely empty on Justia
        #     (all/most empty -> expected, summarised not itemised).
        for heading, url, body in entries:
            m = CONTAINER_RE.search(url)
            if not m:
                continue  # leaf section or non-container -> not an article-stub class
            act = url[:m.start()]  # everything up to '/article-N/' == the Act index
            resid = residual_prose(body, heading)
            # An empty container is EXPECTED (not a crawl failure) when the heading
            # or body explains the emptiness: amendatory/uncodified provisions,
            # text compiled elsewhere, renumbered/repealed, text omitted, etc.
            probe = (heading + " " + body[:300]).lower()
            benign = any(k in probe for k in BENIGN_EMPTY)
            container_by_act[(str(rel), act)].append(
                (heading, url, len(resid), benign))

        # (3) TOC-only ARTICLE detector (catchline-ratio).
        #     Words/line does NOT catch a title-TOC (OK art X titles are 8-9 words
        #     each), so instead we measure what fraction of an article's content
        #     lines are catchline index entries ("Section X-1: ...", "Sec. 5."):
        #     a TOC article is ~all catchlines with no normative prose; a healthy
        #     article has a few "SECTION 1." headers and many prose lines.
        #     Runs on constitution files (the class where this defect lives).
        if "constitution" in f.name.lower():
            for heading, url, body in entries:
                content = []
                for ln in body.split("\n"):
                    s = ln.strip()
                    if not s:
                        continue
                    if s in TOC_NAV_LINES:
                        continue
                    # drop heading-echo lines (ALL CAPS / ARTICLE ...)
                    letters = [c for c in s if c.isalpha()]
                    if letters and all(c.isupper() for c in letters):
                        continue
                    content.append(s)
                if len(content) < 6:
                    continue
                catch = sum(1 for s in content
                            if CATCHLINE_RE.match(s))
                ratio = catch / len(content)
                if ratio >= 0.55:
                    toc_candidates.append((rel, heading, round(ratio, 2),
                                           catch, len(content)))

    # ---- report ----
    print("=" * 100)
    print("(1) WHOLE-FILE STUBS  (header-only / no body) -- RE-FETCH WHOLE FILE")
    print("=" * 100)
    if not whole_file_stubs:
        print("  none")
    for rel, size, nl, ne, tb in whole_file_stubs:
        print(f"  {str(rel):55s} size={size:>8}  lines={nl:>4}  entries={ne}  body_chars={tb}")

    print()
    print("=" * 100)
    print("(2) ARTICLE-LEVEL STUB CANDIDATES  (container entry -> empty body among healthy siblings)")
    print("    Only CONTAINER entries (/article-N/, /division-N/, /part-N/) are considered here;")
    print("    leaf /section-*/ one-liners are excluded. Grouped by Act.")
    print("    SUSPECT = a MINORITY of empty articles among full siblings (the IL Art 11 pattern).")
    print("    Uniformly-empty Acts (amendatory/appropriation; genuinely empty on Justia) are summarised.")
    print("=" * 100)
    # r = (heading, url, resid_len, benign)
    suspect_acts = []            # empty & NON-benign containers -> real crawl-failure candidates
    benign_empty_total = 0
    for (rel, act), rows in container_by_act.items():
        full = [r for r in rows if r[2] >= SHORT_BODY_CHARS]
        empty = [r for r in rows if r[2] < SHORT_BODY_CHARS]
        suspicious = [r for r in empty if not r[3]]   # empty AND no benign explanation
        benign_empty_total += len(empty) - len(suspicious)
        if suspicious:
            suspect_acts.append((rel, act, suspicious, full))

    if not suspect_acts:
        print("\n  none")
    for rel, act, suspicious, full in sorted(suspect_acts, key=lambda x: (str(x[0]), x[1])):
        print(f"\n  {rel}")
        print(f"    Act: {act}")
        print(f"    -> {len(full)} full sibling article(s); {len(suspicious)} EMPTY with NO benign reason:")
        for heading, url, blen, benign in suspicious:
            print(f"       [**STUB?**] {heading[:72]}")
            print(f"                   {url}")

    print()
    print(f"  (summary) {benign_empty_total} other empty container entries were EXPECTED-empty")
    print(f"            (heading/body said amendatory / compiled elsewhere / renumbered / text")
    print(f"            omitted / short-title / effective-date etc.) -> NOT crawl failures, not fetched.")

    print()
    print("=" * 100)
    print("(3) TOC-ONLY ARTICLES  (constitution article body = mostly catchline titles, no prose)")
    print("    ** catchline-ratio >= 0.55. Confirm with a known-section body grep before acting. **")
    print("=" * 100)
    if not toc_candidates:
        print("  none")
    from collections import defaultdict as _dd
    toc_by_file = _dd(list)
    for rel, heading, ratio, catch, ncontent in toc_candidates:
        toc_by_file[str(rel)].append((heading, ratio, catch, ncontent))
    for rel in sorted(toc_by_file):
        print(f"\n  {rel}")
        for heading, ratio, catch, ncontent in toc_by_file[rel]:
            print(f"    ratio={ratio:<5} ({catch}/{ncontent} lines are catchlines)  {heading[:55]}")

    if parse_notes:
        print("\nPARSE NOTES:")
        for n in parse_notes:
            print("  " + n)


if __name__ == "__main__":
    main()
