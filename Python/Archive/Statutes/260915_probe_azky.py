"""Probe: discover real Justia section-body URLs for AZ Const. art. 9 and KY Const.
Fetches the TOC/index pages and prints candidate section hrefs. Read-only probe."""
import importlib.util, re, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("m260914", HERE/"260914_fetch_taxlimits.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
from bs4 import BeautifulSoup
try: sys.stdout.reconfigure(encoding="utf-8")
except Exception: pass

def links(url):
    html = m.dl.fetch(url); m.dl._polite()
    soup = BeautifulSoup(html, "lxml")
    hrefs = []
    for a in soup.find_all("a", href=True):
        h = a["href"]
        if "constitution/arizona" in h or "constitution/kentucky" in h:
            hrefs.append((a.get_text(strip=True)[:50], h))
    return hrefs

for url in ["https://law.justia.com/constitution/arizona/9/title9.htm",
            "https://law.justia.com/constitution/arizona/",
            "https://law.justia.com/constitution/kentucky/"]:
    print("="*70); print("PROBE", url)
    try:
        for txt, h in links(url)[:60]:
            print(f"  {txt!r:52} {h}")
    except Exception as e:
        print("  ERR", type(e).__name__, repr(e)[:120])
