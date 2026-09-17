"""Second probe: discover link structure for the URLs that 404'd or whose section
bodies live on child pages (TX Gov Code chapters, FL ch100, constitution sections)."""
from curl_cffi import requests as creq
from bs4 import BeautifulSoup
import re, time, random

S = creq.Session(impersonate="chrome124")


def links_matching(url, pat):
    try:
        r = S.get(url, timeout=30)
    except Exception as e:
        return f"ERR {e!r}", []
    soup = BeautifulSoup(r.text, "lxml")
    hrefs = sorted(set(a["href"] for a in soup.find_all("a", href=True)
                       if re.search(pat, a["href"])))
    return f"{r.status_code} ({len(hrefs)} matches)", hrefs


for name, url, pat in [
    ("TX govcode root", "https://law.justia.com/codes/texas/government-code/", r"chapter-125[12]|title-9|title-10"),
    ("FL ch100 root",   "https://law.justia.com/codes/florida/title-ix/chapter-100/", r"section-100-3"),
    ("OK const X TOC",  "https://law.justia.com/constitution/oklahoma/X.html", r"oklahoma/"),
    ("TX const root",   "https://law.justia.com/constitution/texas/", r"texas/"),
    ("UT const 14 TOC", "https://law.justia.com/constitution/utah/CO_0F.html", r"utah/"),
    ("NV const root",   "https://law.justia.com/constitution/nevada/", r"nevada/"),
]:
    status, hrefs = links_matching(url, pat)
    print(f"\n=== {name}  {url}\n    {status}")
    for h in hrefs[:30]:
        print("   ", h.split("justia.com")[-1] if "justia.com" in h else h)
    time.sleep(1.5 + random.uniform(0, 0.8))
