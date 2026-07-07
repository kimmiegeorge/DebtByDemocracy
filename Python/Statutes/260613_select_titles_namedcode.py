#!/usr/bin/env python3
r"""
260613_select_titles_namedcode.py  --  Debt by Democracy: state statute AI task

Phase 1, step 2 SUPPLEMENT for the 4 expansion states whose Justia code is NOT
organized as flat title-/chapter- slugs (so 260613_select_titles.py returned 0
statute divisions for them):

  TX  named codes, DATED url  : /codes/texas/<year>/<name>-code/
  CA  named codes, UNDATED url: /codes/california/code-<abbr>/
  LA  code SETS -> descend the "revised-statutes" set to its title-N divisions
      (the other 5 sets, e.g. civil-code, are added as single non-bond rows)
  OR  VOLUMES -> descend each volume-NN to its chapter-N divisions

Enumerates each state's real top-level (or one-level-deeper) divisions, classifies
them with the SAME keyword tiers as the main script, and APPENDS the statute rows
into the existing review CSV (260613_expansion_title_selection.csv). Idempotent:
it first drops any existing kind=="statute" rows for these 4 states, and it leaves
their already-written constitution rows (and all other states) untouched.

Run AFTER 260613_select_titles.py (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260613_select_titles_namedcode.py
"""
from __future__ import annotations

import sys
import time
import re
from pathlib import Path

import polars as pl
from bs4 import BeautifulSoup
from curl_cffi import requests as creq

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
SEED_IN = DOCS / "260613_expansion_seed_manifest.csv"
OUT = DOCS / "260613_expansion_title_selection.csv"

STRONG = [
    "municipal", "municipalit", "cities", "town", "village",
    "local government", "finance", "fiscal", "debt", "bond", "indebted",
    "borrow", "revenue",
]
MEDIUM = ["election", "referend", "ballot", "utilit", "public works", "improvement"]
WEAK = ["county", "counties", "local", "taxation", "general provision", "borough"]
IMPERSONATE = "chrome124"

# abbr -> (name, slug, structure). NOTE: for the LATEST edition Justia lists named
# codes / code-sets with UNDATED division URLs (e.g. /codes/texas/government-code/,
# /codes/louisiana/revised-statutes/), even though older years (2024) are dated.
TARGETS = {
    "CA": ("California", "california", "named_ca"),    # /codes/california/code-<abbr>/
    "LA": ("Louisiana", "louisiana", "codesets"),      # code sets; descend revised-statutes
    "OR": ("Oregon", "oregon", "volumes"),             # volume-NN -> chapter-N
    "TX": ("Texas", "texas", "named_tx"),              # /codes/texas/<name>-code/
}


def _seg(url: str) -> str:
    return url.rstrip("/").split("/")[-1]


def write_csv_bom(df: pl.DataFrame, path: Path) -> None:
    """Write the review CSV as UTF-8 WITH BOM (utf-8-sig) so Excel renders non-ASCII
    (section sign, curly apostrophes) cleanly instead of mojibake. polars read_csv
    strips the BOM, so re-reads are safe. Mirrors 260613_select_titles.py."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(df.write_csv(), encoding="utf-8-sig")


def fetch(url: str, tries: int = 4) -> str:
    last = None
    for i in range(tries):
        try:
            r = creq.get(url, impersonate=IMPERSONATE, timeout=45)
            if r.status_code == 200 and "Just a moment" not in r.text:
                return r.text
            last = f"status={r.status_code} challenge={'Just a moment' in r.text}"
        except Exception as e:
            last = repr(e)
        time.sleep(2 * (i + 1))
    raise RuntimeError(f"fetch failed for {url}: {last}")


def latest_year(slug: str) -> str:
    html = fetch(f"https://law.justia.com/codes/{slug}/")
    years = sorted(re.findall(rf"/codes/{slug}/(\d{{4}})/?", html), reverse=True)
    return years[0] if years else ""


def links_matching(html: str, pattern: re.Pattern) -> list[tuple[str, str]]:
    """(text, absolute_url) for anchors whose href matches pattern; de-duped."""
    soup = BeautifulSoup(html, "lxml")
    out, seen = [], set()
    for a in soup.find_all("a", href=True):
        if not pattern.search(a["href"]):
            continue
        href = a["href"]
        if href.startswith("/"):
            href = "https://law.justia.com" + href
        if href in seen:
            continue
        seen.add(href)
        out.append((a.get_text(strip=True), href))
    return out


def classify_div(name: str, is_seed: bool) -> tuple[str, str, str]:
    low = name.lower()
    strong = [k for k in STRONG if k in low]
    medium = [k for k in MEDIUM if k in low]
    weak = [k for k in WEAK if k in low]
    hits = ";".join(strong + medium + weak)
    if is_seed or strong:
        tier = "core"
    elif medium:
        tier = "maybe"
    elif weak:
        tier = "weak"
    else:
        tier = ""
    matched = ";".join(filter(None, [
        "seed" if is_seed else "",
        "strong" if strong else "", "medium" if medium else "", "weak" if weak else "",
    ]))
    return tier, matched, hits


def justia_seeds(seed: pl.DataFrame, abbr: str) -> list[str]:
    """Justia /codes/ seed URLs for a state (used for prefix-based seed flagging)."""
    urls = []
    for url in seed.filter(pl.col("state_abbr") == abbr)["url"].to_list():
        if url and "law.justia.com/codes/" in url:
            urls.append(url.rstrip("/"))
    return urls


def div_slug_of(url: str) -> str:
    """Final meaningful path segment (title-x / chapter-x / <name>-code / code-x)."""
    segs = [s for s in url.rstrip("/").split("/") if s]
    return segs[-1] if segs else ""


def enumerate_divisions(abbr: str, slug: str, struct: str, year: str) -> list[tuple[str, str]]:
    """(name, url) statute divisions for a named-code/volume state. The year index
    page is fetched, but the division links inside it are UNDATED for the latest
    edition."""
    year_index = f"https://law.justia.com/codes/{slug}/{year}/"

    if struct == "named_ca":  # CA: /codes/california/code-<abbr>/ (undated)
        html = fetch(year_index)
        pat = re.compile(rf"/codes/{slug}/code-[^/]+/?$")
        return links_matching(html, pat)

    if struct == "named_tx":  # TX: /codes/texas/<name>-code/ (undated)
        html = fetch(year_index)
        pat = re.compile(rf"/codes/{slug}/[^/]+/?$")
        divs = links_matching(html, pat)
        return [(n, u) for n, u in divs if not _seg(u).isdigit() and _seg(u) != slug]

    if struct == "codesets":  # LA: code sets (undated); descend revised-statutes -> titles
        html = fetch(year_index)
        setpat = re.compile(rf"/codes/{slug}/[^/]+/?$")
        sets = [(n, u) for n, u in links_matching(html, setpat)
                if not _seg(u).isdigit() and _seg(u) != slug]
        out = []
        for name, url in sets:
            if _seg(url) == "revised-statutes":
                time.sleep(2)
                sub = fetch(url)
                tpat = re.compile(r"/revised-statutes/title-[^/]+/?$")
                out.extend(links_matching(sub, tpat))
            else:
                out.append((name, url))  # non-RS code set: single row (classifies weak/N)
        return out

    if struct == "volumes":  # OR: volume-NN -> chapter-N
        html = fetch(f"https://law.justia.com/codes/{slug}/{year}/")
        vpat = re.compile(rf"/codes/{slug}/volume-[^/]+/?$")
        out = []
        for _, vurl in links_matching(html, vpat):
            time.sleep(2)
            try:
                sub = fetch(vurl)
            except RuntimeError:
                continue
            cpat = re.compile(rf"/codes/{slug}/volume-[^/]+/chapter-[^/]+/?$")
            out.extend(links_matching(sub, cpat))
        return out

    return []


def main() -> None:
    if not OUT.exists():
        raise SystemExit(f"Run 260613_select_titles.py first; missing {OUT}")
    seed = pl.read_csv(SEED_IN)
    existing = pl.read_csv(OUT)

    # Drop any prior statute rows for the target states (idempotent re-run).
    keep = existing.filter(
        ~((pl.col("state_abbr").is_in(list(TARGETS))) & (pl.col("kind") == "statute"))
    )

    new_rows = []
    for abbr, (name, slug, struct) in TARGETS.items():
        year = latest_year(slug)
        time.sleep(2)
        jseeds = justia_seeds(seed, abbr)
        try:
            divs = enumerate_divisions(abbr, slug, struct, year)
        except RuntimeError as e:
            print(f"   !! {abbr} enumeration failed:", e)
            divs = []
        n_core = n_maybe = 0
        for dname, durl in divs:
            durl_n = durl.rstrip("/")
            is_seed = any(s.startswith(durl_n) for s in jseeds)
            tier, matched, kw = classify_div(dname, is_seed)
            include = "Y" if tier in ("core", "maybe") else "N"
            n_core += tier == "core"
            n_maybe += tier == "maybe"
            new_rows.append({
                "state_abbr": abbr, "state_name": name, "slug": slug,
                "latest_year": year, "kind": "statute", "div_slug": div_slug_of(durl),
                "name": dname, "url": durl, "tier": tier,
                "matched_by": matched, "kw_hits": kw, "include": include,
            })
        print(f"{abbr} ({struct}) year {year}: {len(divs)} divisions  "
              f"core {n_core}  maybe {n_maybe}")
        time.sleep(2)

    combined = pl.concat([keep, pl.DataFrame(new_rows)], how="vertical_relaxed")
    # Stable sort: by expansion-ish order is not critical here; sort by state then kind.
    combined = combined.sort(["state_abbr", "kind", "div_slug"])
    write_csv_bom(combined, OUT)  # UTF-8 + BOM so Excel renders non-ASCII cleanly
    print("\nWrote:", OUT, " total rows:", combined.height,
          " states:", combined["state_abbr"].n_unique())
    summ = (combined.filter(pl.col("kind") == "statute")
            .group_by("state_abbr")
            .agg(n_titles=pl.len(),
                 n_core=(pl.col("tier") == "core").sum(),
                 n_maybe=(pl.col("tier") == "maybe").sum())
            .filter(pl.col("state_abbr").is_in(list(TARGETS)))
            .sort("state_abbr"))
    with pl.Config(tbl_rows=10):
        print(summ)
    print("DONE_NAMEDCODE")


if __name__ == "__main__":
    main()
