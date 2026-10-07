"""Part 3 verification: for each 260717 fetch, assert the KEY grounding section is
present WITH body prose (not a TOC stub or a Cloudflare error page). Prints a
fetch-results table: item -> landed? -> key section found? -> gap closed?"""
from pathlib import Path
import re

RAW = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\raw")

# (file, human label, [key regexes that MUST appear in a body], row it grounds)
CHECKS = [
    ("TX/260717_texas_government-code-chapter-1251.txt", "TX Gov Code ch.1251",
     [r"1251\.003", r"notice", r"majority"], "TX GO procedure + note_pubnotice"),
    ("TX/260717_texas_government-code-chapter-1502.txt", "TX Gov Code ch.1502",
     [r"revenue bond", r"public utilit"], "TX rev row (only valid grounding)"),
    ("OK/260717_oklahoma_title-60-public-trust-act-176-180.txt", "OK Title 60 Public Trust Act",
     [r"60-176", r"trust", r"bond"], "OK rev no-vote route"),
    ("OH/260717_ohio_revised-code-chapter-133.txt", "OH Rev Code ch.133",
     [r"133\.18", r"133\.05", r"electors", r"net indebtedness"], "OH GO voted/unvoted + net-debt"),
    ("OH/260717_ohio_revised-code-chapter-5705-key.txt", "OH Rev Code ch.5705 (key)",
     [r"5705\.02", r"5705\.03", r"5705\.19", r"ten mill|10 mill"], "OH millage framework"),
    ("IL/260717_illinois_chapter-65-act-5-article-11.txt", "IL 65 ILCS 5 Article 11",
     [r"11-139", r"11-71", r"11-141", r"waterworks", r"revenue bond"], "IL rev row (Art 11 divisions)"),
    ("FL/260717_florida_statutes-section-100-342.txt", "FL Stat 100.342",
     [r"100\.342|Notice", r"publish|newspaper"], "FL GO note_pubnotice"),
    ("CA/260717_california_elections-code-division-13-ballot.txt", "CA Elec Div 13 (ballot)",
     [r"13247", r"ballot"], "CA GO note_textreq (ballot label)"),
    ("WA/260717_washington_rcw-29a-52-355.txt", "WA RCW 29A.52.355",
     [r"29A\.52\.355|notice", r"publi"], "WA GO note_pubnotice"),
    ("IN/260717_indiana_ic-6-1-1-20-controlled-projects.txt", "IN IC 6-1.1-20",
     [r"6-1\.1-20-3\.1|20-3\.1", r"6-1\.1-20-3\.5|20-3\.5", r"referendum|petition"], "IN GO controlled-projects"),
    ("IL/260717_illinois_30-ilcs-350-debt-reform-act.txt", "IL 30 ILCS 350 Debt Reform Act",
     [r"backdoor referendum|Debt Reform", r"petition", r"alternate bond|limited bond"], "IL note_petition thresholds"),
    ("OK/260717_oklahoma_title-26-election-code-bondnotice.txt", "OK Title 26 Election Code",
     [r"notice", r"publi"], "OK GO/rev note_pubnotice"),
    ("WA/260717_washington_rcw-29a-04-330.txt", "WA RCW 29A.04.330",
     [r"29A\.04\.330|special election|election"], "WA LOW special-election dates"),
    ("WA/260717_washington_rcw-84-52-056.txt", "WA RCW 84.52.056",
     [r"84\.52\.056|excess|levy"], "WA LOW excess levy"),
    ("WA/260717_washington_rcw-35-67-030.txt", "WA RCW 35.67.030",
     [r"35\.67\.030|sewer|election"], "WA LOW sewerage election"),
    ("MO/260717_missouri_chapter-115-election-notice.txt", "MO ch.115 Elections",
     [r"notice", r"publi"], "MO LOW city publication cadence"),
    ("NV/260717_nevada_constitution.txt", "NV Constitution",
     [r"Art(icle)?\.?\s*8|Sec(tion)?\.?\s*9", r"debt|indebtedness"], "NV GO const ceiling (art 8)"),
    ("OK/260717_oklahoma_constitution-article-x-bodies.txt", "OK Const art X bodies",
     [r"X-27", r"X-27A", r"indebtedness|water"], "OK const utility/water"),
    ("UT/260717_utah_constitution-article-xiv-bodies.txt", "UT Const art XIV bodies",
     [r"Section 3|Section 4", r"indebtedness|taxes"], "UT const debt limit"),
]

CF_MARKERS = ("Just a moment", "Enable JavaScript and cookies", "cf-error")


def entries(txt):
    """yield body text of each entry (after each 'URL:' + SUB divider)."""
    blocks = re.split(r"\n={80}\n", txt)
    return blocks


print(f"{'ITEM':40s} {'bytes':>8} {'ent':>4} {'prose':>6} {'keys':>9}  gap-closed?")
print("-" * 100)
allok = True
for rel, label, keys, grounds in CHECKS:
    p = RAW / rel
    if not p.exists():
        print(f"{label:40s}  !! FILE MISSING")
        allok = False
        continue
    txt = p.read_text(encoding="utf-8", errors="replace")
    b = len(txt.encode("utf-8"))
    nent = txt.count("\nURL: ")
    cf = any(m in txt for m in CF_MARKERS)
    # prose: total lowercase-heavy body length
    body = re.sub(r"\s+", " ", txt)
    prose = sum(c.islower() for c in body) >= 200
    keyhits = sum(1 for k in keys if re.search(k, txt, re.IGNORECASE))
    closed = (not cf) and prose and keyhits == len(keys)
    if not closed:
        allok = False
    flag = "" if closed else "  <-- CHECK"
    cfx = " CF-PAGE!" if cf else ""
    print(f"{label:40s} {b:>8} {nent:>4} {str(prose):>6} {keyhits}/{len(keys):<7}  "
          f"{'YES' if closed else 'NO':>3}{flag}{cfx}")

print("-" * 100)
print("ALL GAPS CLOSED" if allok else "SOME CHECKS NEED REVIEW (see <-- CHECK)")
