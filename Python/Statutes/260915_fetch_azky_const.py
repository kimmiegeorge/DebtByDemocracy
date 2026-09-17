"""260915_fetch_azky_const.py -- targeted fetch of AZ Const. art. 9 and KY Const.
section BODIES, which Justia serves only at section-specific URLs (the crawled
title9.htm / list2.html pages are TOC-only, like the OK/UT constitutions). Writes
banner-format files matching the corpus so extract.py / read_entry.py can read them.

AZ art. 9 sections needed across the 3 dimensions:
  5 (state debt), 8 (LOCAL DEBT LIMIT; assent of taxpayers), 17 (expenditure
  commission/limit), 18 (residential ad valorem tax limits), 19 (levy limit),
  20 (EXPENDITURE LIMITATION), 22 (vote required to increase state revenues).
KY Const. Municipalities/General: 156 (classes), 157 (tax/debt max + vote),
  157b, 158 (max indebtedness), 159 (annual tax to pay debt).
"""
import importlib.util, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
RAW = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\raw")
spec = importlib.util.spec_from_file_location("m260914", HERE/"260914_fetch_taxlimits.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
try: sys.stdout.reconfigure(encoding="utf-8")
except Exception: pass
HDR = "=" * 80; SUB = "-" * 80

JOBS = [
    ("AZ", "arizona", "constitution-article-ix-bodies",
     "https://law.justia.com/constitution/arizona/9/title9.htm",
     [f"https://law.justia.com/constitution/arizona/9/{n}.htm" for n in (5, 8, 17, 18, 19, 20, 22)]),
    ("KY", "kentucky", "constitution-secs-156-159",
     "https://law.justia.com/constitution/kentucky/list2.html",
     [f"https://law.justia.com/constitution/kentucky/{n}.html" for n in (156, 157, 158, 159)]),
]

for state, statename, slug, srcurl, urls in JOBS:
    entries = []; landed = 0
    print(f"=== {state} {slug}: {len(urls)} sections ===")
    for u in urls:
        try:
            h, b, yr, nb, wf, src = m.dl.get_section(state, u)
            ok = m.has_prose(b)
            landed += ok
            entries.append((h, u, b))
            print(f"  {u.split('/')[-1]:12} prose={ok} heading={h[:60]!r} len={len(b)}")
        except Exception as e:
            print(f"  {u} -> ERROR {type(e).__name__}: {repr(e)[:90]}")
        m.dl._polite()
    out = RAW / state / f"260915_{statename}_{slug}.txt"
    parts = [f"{HDR}\n{statename.title()} -- {slug}  (260915 targeted fetch)\nsource_url: {srcurl}\n{HDR}\n"]
    for h, u, b in entries:
        parts.append(f"{HDR}\n{h}\nURL: {u}\n{SUB}\n{b}\n")
    out.write_text("\n".join(parts), encoding="utf-8")
    print(f"  wrote {out}  entries={len(entries)} prose={landed}\n")
print("DONE", time.strftime("%H:%M:%S"))
