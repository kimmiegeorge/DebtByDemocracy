#!/usr/bin/env python3
r"""260915_repair_taxlimits.py -- repair the 27 zero-entry targets from the 260914 tax crawl.
Root causes (all diagnosed): NV section URLs use a 'statute-' prefix -> were mis-routed to walk_all
(a leaf can't be walked) -> refetch as SINGLE. ND & IL render every section INLINE on the chapter/act
page (no per-section leaves) -> SINGLE fetch of the chapter/act URL gets the whole body. NC article-8/41
undated URLs redirect-loop -> use the YEAR-DATED url + walk_all. NY GML sec 3-c is a genuine Justia gap
(skipped). Reuses 260914_fetch_taxlimits do_target(); writes raw\<ST>\260914_<statename>_<slug>.txt
(same naming, so the classify step sees them uniformly). Plain-first, gentle."""
import importlib.util, json, sys, time
from pathlib import Path

HERE=Path(__file__).resolve().parent
DOC=Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\documentation")
LOG=Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Data\Statutes\260914_fetch_log.txt")

spec=importlib.util.spec_from_file_location("m260914", HERE/"260914_fetch_taxlimits.py")
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
try: sys.stdout.reconfigure(encoding="utf-8")
except Exception: pass

import re
checks=set(re.findall(r"CHECK (\S+): entries=0", LOG.read_text(encoding="utf-8",errors="replace")))
orig={t["slug"]:t for t in json.loads((DOC/"260914_crawl_targets.json").read_text(encoding="utf-8"))}

repair=[]
for slug in sorted(checks):
    t=dict(orig[slug])
    st=t["state"]
    if st=="NV":
        t["mode"]="single"                      # statute- URL is a section leaf
    elif st in ("ND","IL"):
        t["mode"]="single"                      # sections render inline on the chapter/act page
    elif st=="NC":
        t["mode"]="walk_all"                    # dated URL avoids the redirect loop
        t["url"]=t["url"].replace("/codes/north-carolina/","/codes/north-carolina/2024/")
    elif st=="NY":
        print(f"SKIP NY {slug}: GML sec 3-c is a genuine Justia gap (documented)"); continue
    repair.append(t)

print(f"REPAIR START {time.strftime('%H:%M:%S')}  targets={len(repair)}  DELAY={m.dl.DELAY}+U(0,{m.dl.JITTER})")
ok=0; total=0
for n,t in enumerate(repair,1):
    tag=f"[{n}/{len(repair)}] {t['state']} {t['slug']} ({t['mode']})"
    try:
        r=m.do_target(t); total+=r["landed"]
        status="OK" if r["landed"]>0 else "STILL-EMPTY"
        ok+= r["landed"]>0
        print(f"{tag} -> {status} entries={r['entries']} prose={r['landed']} dead={r['dead']}")
    except Exception as e:
        print(f"{tag} -> ERROR {type(e).__name__}: {repr(e)[:100]}")
print(f"\nREPAIR DONE {time.strftime('%H:%M:%S')}  targets_ok={ok}/{len(repair)}  total_prose_sections={total}")
