#!/usr/bin/env python3
r"""
260717_fetch_dependencies.py  --  Debt by Democracy: TARGETED fetch of out-of-corpus
dependencies + repair of heading-only stubs (prompt 260716_prompt_fetch_dependencies.md).

This is NOT a re-crawl. It fetches only the specific chapters / sections / constitution
bodies that sourcelevel rows depend on but were never downloaded (or came down as
heading-only stubs). It reuses the proven fetch + extract layer from
260625_download_statutes.py (shared curl_cffi/Cloudflare session via 260625_justia_fetch),
so it starts on the fast PLAIN method (clean IP, no cookie) and auto-escalates to the
cookie daemon only if challenged.

KEY REPAIR INSIGHT (2026-07-17): the IL Art 11 + NV constitution stubs were HTTP-200
crawl failures. IL Art 11's *current/undated* Justia page renders only the article
heading (69 chars); the **year-dated** URL (.../2024/.../article-11/) renders the full
2.1 MB inline. So for the inline-IL targets we hit the DATED url. NV's page uses
div#maincontent (not div#codes-content) and is fully present now -> one fetch repairs it.

Gentleness: ~2-2.8 s between every request (dl.DELAY=2.0 + JITTER). Verify asserts on
BODY PROSE, not exit status (a landed-but-empty fetch is the exact failure this fixes).

Modes per target:
  single         one page; extract_html (codes-content -> maincontent fallback).
  const_sections explicit list of constitution section pages (maincontent).
  walk_all       enumerate an index -> fetch every leaf section.
  walk_filter    enumerate an index -> fetch only leaves whose URL matches a regex.
  index_anchor   fetch an index page, keep section links whose ANCHOR TEXT matches a
                 keyword set (for huge election-code titles where we want only the
                 bond/notice/publication sections).

Output: raw\<ST>\260717_<statename>_<slug>.txt in the standard consolidated format
(HDR / heading / URL: / SUB / body). New dated files; existing 260625_/260615_ files
are left intact (Part 3 integrates/re-grounds).

Run detached (Task Scheduler). Progress -> 260717_fetch_log.txt (the runner tees stdout).
"""
from __future__ import annotations
import importlib.util
import re
import sys
import time
import traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
RAW = HOME / "Data" / "Statutes" / "raw"

# --- reuse the download module's fetch + extract + enumerate layer ----------------
_spec = importlib.util.spec_from_file_location("dl", HERE / "260625_download_statutes.py")
dl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dl)
from bs4 import BeautifulSoup  # noqa: E402

HDR, SUB = dl.HDR, dl.SUB
DeadLink, Blocked = dl.DeadLink, dl.Blocked

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def log(msg=""):
    print(msg, flush=True)


# ------------------------------------------------------------------ target table
# each target: dict(state, statename, slug, mode, url|urls, [filter], [selector],
#                    grounds, [dated])
TARGETS = [
    # ============================ PART 2a HIGH ============================
    dict(state="TX", statename="texas", slug="government-code-chapter-1251",
         mode="walk_all",
         url="https://law.justia.com/codes/texas/government-code/title-9/subtitle-c/chapter-1251/",
         grounds="TX GO row: bond-election procedure/majority + note_pubnotice (esp. Gov.Code 1251.003)."),
    dict(state="TX", statename="texas", slug="government-code-chapter-1502",
         mode="walk_all",
         url="https://law.justia.com/codes/texas/government-code/title-9/subtitle-j/chapter-1502/",
         grounds="TX rev row: the ONLY valid general grounding (municipal utility/revenue bonds)."),
    dict(state="OK", statename="oklahoma", slug="title-60-public-trust-act-176-180",
         mode="walk_filter",
         url="https://law.justia.com/codes/oklahoma/title-60/",
         filter=re.compile(r"/section-60-1(7[6-9]|80)(-\d+)?/?$"),
         grounds="OK rev row: Public Trust Act (general municipal revenue financing, no vote)."),
    dict(state="OH", statename="ohio", slug="revised-code-chapter-133",
         mode="walk_all",
         url="https://law.justia.com/codes/ohio/title-1/chapter-133/",
         grounds="OH GO/rev: Uniform Public Securities Law (voted/unvoted GO; net-indebtedness)."),
    dict(state="OH", statename="ohio", slug="revised-code-chapter-5705-key",
         mode="walk_filter",
         url="https://law.justia.com/codes/ohio/title-57/chapter-5705/",
         filter=re.compile(r"/section-5705-(01|02|03|04|05|06|09|10|19|191|199)/?$"),
         grounds="OH GO: inside/outside millage framework (ten-mill limit; voted excess levies)."),
    dict(state="IL", statename="illinois", slug="chapter-65-act-5-article-11",
         mode="single",
         url="https://law.justia.com/codes/illinois/2024/chapter-65/act-65-ilcs-5/article-11/",
         selector="div#codes-content",
         grounds="IL rev row: Article 11 utility/enterprise revenue-bond divisions "
                 "(11-139/71/141/129/119/118). REPAIRS the heading-only stub in "
                 "260625_illinois_chapter-65.txt."),

    # ============================ PART 2a MEDIUM =========================
    dict(state="FL", statename="florida", slug="statutes-section-100-342",
         mode="single",
         url="https://law.justia.com/codes/florida/title-ix/chapter-100/section-100-342/",
         grounds="FL GO row note_pubnotice: notice manner for bond referenda (xref by 100.211)."),
    dict(state="CA", statename="california", slug="elections-code-division-13-ballot",
         mode="walk_filter",
         url="https://law.justia.com/codes/california/code-elec/division-13/",
         filter=re.compile(r"/section-13(1[0-2][0-9]|2[0-6][0-9])/?$"),
         grounds="CA GO (§43608) note_textreq: ballot-label / proposition-text wording (incl. §13247)."),
    dict(state="WA", statename="washington", slug="rcw-29a-52-355",
         mode="single",
         url="https://law.justia.com/codes/washington/title-29a/chapter-29a-52/section-29a-52-355/",
         grounds="WA GO note_pubnotice: notice-of-election publication cadence (xref by RCW 39.36.050)."),
    dict(state="IN", statename="indiana", slug="ic-6-1-1-20-controlled-projects",
         mode="walk_all",
         url="https://law.justia.com/codes/indiana/2023/title-6/article-1-1/chapter-20/",
         grounds="IN GO row: controlled-projects referendum (6-1.1-20-3.1 petition/remonstrance; "
                 "-3.5 mandatory referendum). Title 6 never downloaded."),
    dict(state="IL", statename="illinois", slug="30-ilcs-350-debt-reform-act",
         mode="single",
         url="https://law.justia.com/codes/illinois/2024/chapter-30/act-30-ilcs-350/",
         selector="div#codes-content",
         grounds="IL note_petition (both rows): Local Government Debt Reform Act "
                 "(backdoor-referendum thresholds/timing; alternate bonds)."),
    dict(state="OK", statename="oklahoma", slug="title-26-election-code-bondnotice",
         mode="index_anchor",
         url="https://law.justia.com/codes/oklahoma/title-26/",
         keywords=("bond", "notice", "publication", "proclamation", "canvass"),
         grounds="OK GO/rev note_pubnotice: operative bond-election notice authority (Election Code)."),

    # ============================ PART 2a LOW ============================
    dict(state="WA", statename="washington", slug="rcw-29a-04-330",
         mode="single",
         url="https://law.justia.com/codes/washington/title-29a/chapter-29a-04/section-29a-04-330/",
         grounds="WA LOW: special-election dates (xref by RCW 39.36.050)."),
    dict(state="WA", statename="washington", slug="rcw-84-52-056",
         mode="single",
         url="https://law.justia.com/codes/washington/title-84/chapter-84-52/section-84-52-056/",
         grounds="WA LOW: excess property tax levy for bond retirement (xref by RCW 39.36.050)."),
    dict(state="WA", statename="washington", slug="rcw-35-67-030",
         mode="single",
         url="https://law.justia.com/codes/washington/title-35/chapter-35-67/section-35-67-030/",
         grounds="WA LOW: sewerage-systems election (parallel to 35.92.070 already grounding rev row)."),
    dict(state="MO", statename="missouri", slug="chapter-115-election-notice",
         mode="index_anchor",
         url="https://law.justia.com/codes/missouri/title-ix/chapter-115/",
         keywords=("notice", "publication", "bond", "ballot", "canvass"),
         grounds="MO LOW: city publication cadence for a bond election (Elections, Title IX)."),

    # ==================== PART 2b constitution / stub bodies =============
    dict(state="NV", statename="nevada", slug="constitution",
         mode="single",
         url="https://law.justia.com/constitution/nevada/",
         selector="div#maincontent",
         grounds="NV constitution REPAIR (was a 258-byte stub). art.8 §§9-10 muni debt; art.9 §3. "
                 "May add a note_exception constitutional ceiling to the NV GO row."),
    dict(state="OK", statename="oklahoma", slug="constitution-article-x-bodies",
         mode="const_sections",
         urls=[
             "https://law.justia.com/constitution/oklahoma/X-25.html",
             "https://law.justia.com/constitution/oklahoma/X-26.html",
             "https://law.justia.com/constitution/oklahoma/X-27.html",
             "https://law.justia.com/constitution/oklahoma/X-27A.html",
             "https://law.justia.com/constitution/oklahoma/X-27B.html",  # 404-expected; logged
             "https://law.justia.com/constitution/oklahoma/X-35.html",
         ],
         selector="div#maincontent",
         grounds="OK art X debt/utility bodies (TOC-only in corpus). §27 utility indebtedness, "
                 "§27A water facilities = where a general muni utility revenue-vote rule would live."),
    dict(state="UT", statename="utah", slug="constitution-article-xiv-bodies",
         mode="const_sections",
         urls=[
             "https://law.justia.com/constitution/utah/htm/CO_0F004.html",  # = Art XIV Sec 3
             "https://law.justia.com/constitution/utah/htm/CO_0F005.html",  # = Art XIV Sec 4
         ],
         selector="div#maincontent",
         grounds="UT art XIV §3 (debt not to exceed taxes) + §4 (limit of indebtedness). TOC-only in corpus."),
]

# NOTE (left FLAGGED, NOT fetched): TX constitution art XI §§4-5 bodies are TOC-only on
# Justia (cn001100.html renders section TITLES only; no per-section body pages exist) ->
# genuinely unavailable there; TX rows are grounded via Gov.Code ch.1251/1502 instead.
# Also NOT fetched (prompt-scoped): NY Public Authorities Law (LOW/optional, huge) and
# DE municipal charters (special acts, not in Title 22; prompt: probably not worth it).


# ------------------------------------------------------------------ helpers
def write_consolidated(state: str, statename: str, slug: str, source_url: str,
                       entries: list[tuple[str, str, str]]) -> Path:
    """entries = [(heading, url, body)]. Writes the standard consolidated file."""
    out = RAW / state / f"260717_{statename}_{slug}.txt"
    out.parent.mkdir(parents=True, exist_ok=True)
    parts = [f"{HDR}\n{statename.title()} -- {slug}  (260717 targeted fetch)\n"
             f"source_url: {source_url}\n{HDR}\n"]
    for heading, url, body in entries:
        parts.append(f"{HDR}\n{heading}\nURL: {url}\n{SUB}\n{body}\n")
    out.write_text("\n".join(parts), encoding="utf-8")
    return out


def fetch_one(state: str, url: str, selector: str | None):
    """Fetch+extract one page. Returns (heading, body, year). Honors an explicit
    selector (e.g. div#maincontent for constitutions, div#codes-content for inline IL);
    falls back to dl.extract_html otherwise. Caches raw HTML via dl.get_section path."""
    # reuse dl.get_section's caching, but it uses dl.extract_html's selector order.
    # For an explicit selector we fetch+cache ourselves then select.
    cp = dl.cache_path(state, url)
    cp.parent.mkdir(parents=True, exist_ok=True)
    if cp.exists() and cp.stat().st_size > 0:
        html = cp.read_text(encoding="utf-8", errors="replace")
        fetched = False
    else:
        html = dl.fetch(url)              # DeadLink/Blocked per taxonomy
        cp.write_text(html, encoding="utf-8", errors="replace")
        fetched = True
    soup = BeautifulSoup(html, "lxml")
    heading = soup.title.get_text(strip=True).split("::")[0].strip() if soup.title else ""
    if selector:
        el = soup.select_one(selector)
        body = el.get_text("\n", strip=True) if el else ""
    else:
        heading2, body, _ = dl.extract_html(html)
        heading = heading or heading2
    if fetched:
        dl._polite()
    return heading, body


def index_links_with_text(url: str):
    """Fetch an index page; return [(abs_url, anchor_text)] for section links."""
    html = dl.fetch(url)
    dl._polite()
    soup = BeautifulSoup(html, "lxml")
    out = []
    for a in soup.find_all("a", href=True):
        h = dl.abs_url(a["href"]).split("#")[0]
        if re.search(r"/(section-|statute-)", h):
            out.append((h, a.get_text(" ", strip=True)))
    # dedupe preserving order
    seen, uniq = set(), []
    for h, t in out:
        if h not in seen:
            seen.add(h)
            uniq.append((h, t))
    return uniq


def has_prose(body: str) -> bool:
    """A real body has sentence prose, not just heading echo. Heuristic: >=200 chars
    after collapsing whitespace, and at least one lowercase-rich sentence."""
    b = re.sub(r"\s+", " ", body).strip()
    return len(b) >= 200 and sum(c.islower() for c in b) >= 80


# ------------------------------------------------------------------ per-target run
def run_target(t: dict) -> dict:
    state, statename, slug = t["state"], t["statename"], t["slug"]
    mode = t["mode"]
    log(f"\n{'='*90}\n[{state}] {slug}  ({mode})\n  grounds: {t['grounds']}")
    entries: list[tuple[str, str, str]] = []
    landed, dead, note = 0, 0, ""

    try:
        if mode == "single":
            heading, body = fetch_one(state, t["url"], t.get("selector"))
            entries.append((heading, t["url"], body))
            landed = 1 if has_prose(body) else 0
            log(f"  fetched: {heading[:70]}  body={len(body)} prose={has_prose(body)}")

        elif mode == "const_sections":
            for u in t["urls"]:
                try:
                    heading, body = fetch_one(state, u, t.get("selector"))
                except DeadLink as e:
                    dead += 1
                    log(f"  DEAD (expected/ok if 404): {u}  ({e})")
                    continue
                entries.append((heading, u, body))
                ok = has_prose(body)
                landed += 1 if ok else 0
                log(f"  fetched: {heading[:60]}  body={len(body)} prose={ok}")

        elif mode in ("walk_all", "walk_filter"):
            leaves, nidx = dl.enumerate_urls(t["url"], state)
            if mode == "walk_filter":
                flt = t["filter"]
                leaves = [u for u in leaves if flt.search(u)]
            log(f"  enumerated {nidx} index page(s) -> {len(leaves)} leaf section(s) to fetch")
            for i, u in enumerate(leaves, 1):
                try:
                    heading, body, year, nb, was_fetched, src = dl.get_section(state, u)
                except DeadLink as e:
                    dead += 1
                    log(f"    [{i}/{len(leaves)}] DEAD {u} ({e})")
                    continue
                entries.append((heading, u, body))
                if has_prose(body):
                    landed += 1
                if i % 10 == 0 or i == len(leaves):
                    log(f"    [{i}/{len(leaves)}] last: {heading[:55]}  body={len(body)}")

        elif mode == "index_anchor":
            links = index_links_with_text(t["url"])
            kw = t["keywords"]
            keep = [(u, txt) for (u, txt) in links
                    if any(k in txt.lower() for k in kw)]
            log(f"  index had {len(links)} section link(s); {len(keep)} match keywords {kw}")
            for i, (u, txt) in enumerate(keep, 1):
                try:
                    heading, body, year, nb, was_fetched, src = dl.get_section(state, u)
                except DeadLink as e:
                    dead += 1
                    log(f"    [{i}/{len(keep)}] DEAD {u} ({e})")
                    continue
                entries.append((heading, u, body))
                if has_prose(body):
                    landed += 1
                if i % 10 == 0 or i == len(keep):
                    log(f"    [{i}/{len(keep)}] last: {heading[:55]}  body={len(body)}")

        else:
            raise ValueError(f"unknown mode {mode}")

    except Blocked as e:
        note = f"BLOCKED mid-target: {e}"
        log(f"  !! {note}")
    except Exception as e:
        note = f"ERROR: {e}"
        log(f"  !! {note}\n{traceback.format_exc()}")

    src_url = t.get("url") or (t.get("urls") or [""])[0]
    if entries:
        out = write_consolidated(state, statename, slug, src_url, entries)
        total_body = sum(len(b) for _, _, b in entries)
        log(f"  WROTE {out.name}: {len(entries)} entries, {total_body} body chars, "
            f"{landed} with prose, {dead} dead")
        return dict(target=slug, state=state, file=str(out), entries=len(entries),
                    landed=landed, dead=dead, body=total_body, note=note)
    else:
        log(f"  NO entries written ({note or 'empty'})")
        return dict(target=slug, state=state, file="", entries=0,
                    landed=0, dead=dead, body=0, note=note or "no entries")


def main():
    only = set(sys.argv[1:]) or None    # optional: run only these slugs
    log(f"260717 targeted dependency fetch  START  {time.strftime('%Y-%m-%d %H:%M:%S')}")
    log(f"targets: {len(TARGETS)}  (filter={only})")
    results = []
    t0 = time.time()
    for t in TARGETS:
        if only and t["slug"] not in only:
            continue
        results.append(run_target(t))
    log(f"\n{'#'*90}\nSUMMARY  ({(time.time()-t0)/60:.1f} min)")
    log(f"{'target':45s} {'entries':>7} {'prose':>6} {'dead':>5}  note")
    for r in results:
        log(f"{r['target']:45s} {r['entries']:>7} {r['landed']:>6} {r['dead']:>5}  {r['note']}")
    nblocked = sum(1 for r in results if 'BLOCK' in (r['note'] or ''))
    log(f"\nDONE_FETCH  blocked_targets={nblocked}  {time.strftime('%Y-%m-%d %H:%M:%S')}")


if __name__ == "__main__":
    main()
