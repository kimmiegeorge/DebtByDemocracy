#!/usr/bin/env python3
"""
Extract source links from column F threaded comments in the
"City bond referendum laws by state" workbook (Sheet1) and write an
editable long-format CSV (one row per state + link).

What each output row contains:
- state_abbr / state_name : the state (column B)
- GO  : the workbook's column C value (city GO-bond vote rule), repeated on every row for the state
- Rev : the workbook's column D value (revenue-bond vote rule),  repeated on every row for the state
- sheet_row / cell        : the source row and the F-cell the comment came from
- url / link_note / domain / source_type : the extracted link and its classification
- full_comment            : the raw F-cell comment text (first row of each state only)
- user_notes              : free column for manual annotations

Notes:
- The links live in the THREADED comments (xl/threadedComments/threadedComment1.xml),
  not the legacy xl/comments1.xml (which is just a fallback mirror).
- States with no column-F comment are still written. Four such gaps are filled
  from the column-F citation text via MANUAL_SOURCES below (NM, NY, NC) or flagged
  n/a (HI). These embedded fills make the output reproducible and survive re-runs.
  If you later add a real column-F comment for one of these states in the workbook,
  the workbook comment automatically takes precedence over the manual fill.

Usage:
    python extract_column_F_sources.py [input.xlsx] [output.csv]
Defaults point at the absolute paths below, so it can be run from anywhere.
"""
import csv
import html
import re
import sys
import zipfile
from urllib.parse import urlparse

# --- Absolute paths (script lives in Code\Python\Statutes; data lives in Bonds) ---
BONDS = r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Institutional\Legal\Bonds"
DEFAULT_IN = BONDS + r"\2025-10-13_City bond referendum laws by state.xlsx"
DEFAULT_OUT = BONDS + r"\state_source_links.csv"

SHEET = "xl/worksheets/sheet1.xml"
TCOMMENTS = "xl/threadedComments/threadedComment1.xml"

# 50 states + DC. Only column B values in this map are treated as states.
STATES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
    "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
    "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia", "HI": "Hawaii",
    "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
    "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
    "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
    "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
    "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
    "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
    "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
    "WI": "Wisconsin", "WY": "Wyoming",
}

# Manual fills for states with NO column-F threaded comment, sourced from the
# column-F citation text. Each entry: (url, link_note, domain, source_type, full_comment, user_notes).
# GO/Rev/sheet_row/cell are filled from the workbook at runtime, not hard-coded here.
MANUAL_SOURCES = {
    "HI": [
        ("", "No independent city governments (excluded per user)", "", "n/a",
         "Hawai'i does not have independent city governments",
         "Excluded per user: no independent city governments"),
    ],
    "NM": [
        ("https://law.justia.com/constitution/new-mexico/article-ix/section-12/",
         "NM Constitution, Article IX (sec. 12 municipal indebtedness; vote required)",
         "law.justia.com", "primary",
         "NM Constitution, Article IX\nNM Stat sec. 3-30-06 (2023)",
         "Added from col F citation; pinpointed sec. 12 within Art. IX"),
        ("https://law.justia.com/codes/new-mexico/chapter-3/article-30/section-3-30-6/",
         "NM Stat sec. 3-30-06 (2023) - bond election; notice; publication",
         "law.justia.com", "primary", "", "Added from col F citation"),
    ],
    "NY": [
        ("https://law.justia.com/codes/new-york/lfn/article-2/title-3/34-00/",
         "NY Loc Fin L sec. 34.00 (2023) - bond resolution referendum; cities",
         "law.justia.com", "primary", "NY Loc Fin L sec. 34.00 (2023)",
         "Added from col F citation"),
    ],
    "NC": [
        ("https://ncleg.gov/Laws/Constitution/Article5",
         "NC Constitution, Article V, Section 4 - limits on local government debt",
         "ncleg.gov", "primary", "NC Constitution, Article 5, Section 4",
         "Added from col F citation; official NC General Assembly source"),
    ],
}

# Domains that point at primary law (statutes / constitutions). Justia mirrors
# primary law, so it is treated as primary for sourcing purposes.
PRIMARY_HINTS = ("justia.com", "legislature", "revisor", "statutes",
                 "lawserver", "casetext", "legis", "ncleg")
URL_RE = re.compile(r'https?://[^\s<>"\)]+')

COLUMNS = ["state_abbr", "state_name", "GO", "Rev", "sheet_row", "cell",
           "url", "link_note", "domain", "source_type", "full_comment", "user_notes"]


def load_shared_strings(z):
    xml = z.read("xl/sharedStrings.xml").decode("utf-8", "replace")
    out = []
    for si in re.findall(r"<si>(.*?)</si>", xml, re.S):
        parts = re.findall(r"<t[^>]*>(.*?)</t>", si, re.S)
        out.append(html.unescape("".join(parts)))
    return out


def _cell_value(body, col, rnum, shared):
    """Read a single cell value (resolving shared strings) from a row's XML body."""
    m = re.search(r'<c r="%s%s"([^>]*)>(.*?)</c>' % (col, rnum), body, re.S)
    if not m:
        return ""
    attrs, cell = m.group(1), m.group(2)
    v = re.search(r"<v>(.*?)</v>", cell, re.S)
    if not v:
        return ""
    val = v.group(1)
    if 't="s"' in attrs:
        val = shared[int(val)]
    return html.unescape(val).strip()


def state_rows(z, shared):
    """Return row->abbr plus row->GO (col C) and row->Rev (col D) for state rows."""
    xml = z.read(SHEET).decode("utf-8", "replace")
    rowmap, go, rev, unknown = {}, {}, {}, []
    for rnum, body in re.findall(r'<row[^>]*r="(\d+)"[^>]*>(.*?)</row>', xml, re.S):
        b = _cell_value(body, "B", rnum, shared)
        if b in STATES:
            r = int(rnum)
            rowmap[r] = b
            go[r] = _cell_value(body, "C", rnum, shared)
            rev[r] = _cell_value(body, "D", rnum, shared)
        elif re.fullmatch(r"[A-Z]{2}", b):
            unknown.append((int(rnum), b))
    return rowmap, go, rev, unknown


def f_comments(z):
    """Return {row_number: raw_comment_text} for column F threaded comments."""
    xml = z.read(TCOMMENTS).decode("utf-8", "replace")
    out = {}
    for attrs, body in re.findall(r"<threadedComment\b([^>]*)>(.*?)</threadedComment>", xml, re.S):
        mref = re.search(r'ref="F(\d+)"', attrs)
        if not mref:
            continue
        texts = re.findall(r"<text[^>]*>(.*?)</text>", body, re.S)
        if not texts:
            continue
        txt = html.unescape("\n".join(texts)).strip()
        r = int(mref.group(1))
        out[r] = (out[r] + "\n" + txt).strip() if r in out else txt
    return out


def classify(url):
    net = urlparse(url).netloc.lower()
    if net.startswith("www."):
        net = net[4:]
    if not net:
        return "", "unknown"
    if net.endswith(".gov") or any(h in net for h in PRIMARY_HINTS):
        return net, "primary"
    return net, "secondary"


def parse_pairs(text):
    """Split comment text into (note, url) pairs; note = label before the URL."""
    pairs = []
    last = 0
    for m in URL_RE.finditer(text):
        url = m.group(0).rstrip(').,;')
        seg = text[last:m.start()]
        lines = [ln.strip() for ln in seg.splitlines() if ln.strip()]
        note = lines[-1] if lines else ""
        pairs.append((note, url))
        last = m.end()
    return pairs


def main():
    inp = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_IN
    outp = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT

    z = zipfile.ZipFile(inp)
    shared = load_shared_strings(z)
    rowmap, go, rev, unknown = state_rows(z, shared)
    fcom = f_comments(z)

    rows = []
    have = set()        # states with >=1 link from a column-F comment
    filled = set()      # gap states filled from MANUAL_SOURCES
    n_links = n_primary = n_secondary = 0

    def head(abbr, name, r):
        """Common leading fields (incl. GO/Rev from the workbook) for a state row."""
        return {"state_abbr": abbr, "state_name": name,
                "GO": go.get(r, ""), "Rev": rev.get(r, ""),
                "sheet_row": r, "cell": "F%d" % r}

    for r in sorted(rowmap):
        abbr = rowmap[r]
        name = STATES[abbr]
        text = fcom.get(r, "").strip()
        pairs = parse_pairs(text) if text else []

        if pairs:                                   # workbook comment wins
            have.add(abbr)
            for i, (note, url) in enumerate(pairs):
                dom, stype = classify(url)
                n_links += 1
                if stype == "primary":
                    n_primary += 1
                elif stype == "secondary":
                    n_secondary += 1
                row = head(abbr, name, r)
                row.update({"url": url, "link_note": note, "domain": dom,
                            "source_type": stype,
                            "full_comment": text if i == 0 else "", "user_notes": ""})
                rows.append(row)
        elif abbr in MANUAL_SOURCES:                # embedded manual fill
            filled.add(abbr)
            for (url, note, dom, stype, full, unotes) in MANUAL_SOURCES[abbr]:
                row = head(abbr, name, r)
                row.update({"url": url, "link_note": note, "domain": dom,
                            "source_type": stype, "full_comment": full,
                            "user_notes": unotes})
                rows.append(row)
        else:                                       # still-empty gap -> blank row
            row = head(abbr, name, r)
            row.update({"url": "", "link_note": "", "domain": "",
                        "source_type": "", "full_comment": "", "user_notes": ""})
            rows.append(row)

    with open(outp, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        for row in rows:
            w.writerow(row)

    still_missing = [STATES[rowmap[r]] for r in sorted(rowmap)
                     if rowmap[r] not in have and rowmap[r] not in filled]
    print("Input :", inp)
    print("Output:", outp)
    print("State rows:", len(rowmap),
          "| with column-F links:", len(have),
          "| manual-filled:", ", ".join(sorted(filled)) if filled else "(none)")
    if unknown:
        print("  NON-STANDARD column B codes (not written):", unknown)
    print("Extracted links: %d (primary %d, secondary %d)" % (n_links, n_primary, n_secondary))
    print("Still missing a source:", ", ".join(still_missing) if still_missing else "(none)")
    print("CSV rows written:", len(rows))


if __name__ == "__main__":
    main()
