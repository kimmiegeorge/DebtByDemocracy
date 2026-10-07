"""Quick, gentle discovery probe: confirm each candidate Justia index/section URL
exists (HTTP 200, not a challenge) and show a sample of its deeper links so we can
pin the correct walk root before the detached fetch run. Read-only, ~throttled."""
from curl_cffi import requests as creq
from bs4 import BeautifulSoup
import re, time, random

S = creq.Session(impersonate="chrome124")

CANDIDATES = {
    # --- HIGH ---
    "TX ch1251 idx":  "https://law.justia.com/codes/texas/2023/government-code/title-9/chapter-1251/",
    "TX ch1502 idx":  "https://law.justia.com/codes/texas/2023/government-code/title-10/subtitle-c/chapter-1502/",
    "OK title60 idx": "https://law.justia.com/codes/oklahoma/title-60/",
    "OK title26 idx": "https://law.justia.com/codes/oklahoma/title-26/",
    "OH ch133 idx":   "https://law.justia.com/codes/ohio/title-1/chapter-133/",
    "OH ch5705 idx":  "https://law.justia.com/codes/ohio/title-57/chapter-5705/",
    "IL art11 2024":  "https://law.justia.com/codes/illinois/2024/chapter-65/act-65-ilcs-5/article-11/",
    # --- MEDIUM ---
    "FL 100.342":     "https://law.justia.com/codes/florida/2023/title-ix/chapter-100/part-i/section-100-342/",
    "CA elec div13":  "https://law.justia.com/codes/california/code-elec/division-13/",
    "WA 29a.52.355":  "https://law.justia.com/codes/washington/title-29a/chapter-29a-52/section-29a-52-355/",
    "IN 6-1.1-20":    "https://law.justia.com/codes/indiana/2023/title-6/article-1-1/chapter-20/",
    "IL 30ilcs350":   "https://law.justia.com/codes/illinois/2024/chapter-30/act-30-ilcs-350/",
    # --- LOW ---
    "WA 29a.04.330":  "https://law.justia.com/codes/washington/title-29a/chapter-29a-04/section-29a-04-330/",
    "WA 84.52.056":   "https://law.justia.com/codes/washington/title-84/chapter-84-52/section-84-52-056/",
    "WA 35.67.030":   "https://law.justia.com/codes/washington/title-35/chapter-35-67/section-35-67-030/",
    "MO ch115 idx":   "https://law.justia.com/codes/missouri/title-ix/chapter-115/",
    # --- 2b constitutions ---
    "OK const artX":  "https://law.justia.com/constitution/oklahoma/X.html",
    "TX const art11": "https://law.justia.com/constitution/texas/11.html",
    "UT const art14": "https://law.justia.com/constitution/utah/CO_0F.html",
    "NV const idx":   "https://law.justia.com/constitution/nevada/",
}


def probe(name, url):
    try:
        r = S.get(url, timeout=30)
    except Exception as e:
        return f"{name:16s} ERR {e!r}"
    jm = "Just a moment" in r.text
    soup = BeautifulSoup(r.text, "lxml")
    cc = soup.select_one("div#codes-content")
    cclen = len(cc.get_text(strip=True)) if cc else 0
    # deeper section-ish links
    links = [a["href"] for a in soup.find_all("a", href=True)]
    secish = sorted(set(h for h in links if re.search(r"/(section-|statute-|\d+-\d)", h)))
    samp = "; ".join(s.split("justia.com")[-1] for s in secish[:3])
    return (f"{name:16s} {r.status_code} chal={jm} cc={cclen:>7} "
            f"nsec~{len(secish):>3}  {samp}")


if __name__ == "__main__":
    for name, url in CANDIDATES.items():
        print(probe(name, url), flush=True)
        time.sleep(1.5 + random.uniform(0, 0.8))
