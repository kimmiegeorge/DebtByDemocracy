#!/usr/bin/env python3
r"""
260613_select_chapters.py  --  Debt by Democracy: state statute AI task

Phase 2, step 2b for the EXPANSION batch. The count pass (260613_count_sections.py
-> 260613_expansion_count.csv) found 42 MEGA-divisions (>=800 sections) that hold
~56k of the ~100k expansion sections -- whole municipal/county codes, Revenue &
Taxation titles, Public Utilities titles, and Election codes. Per the pilot's
decision, we keep small/on-point divisions WHOLE but NARROW these megas to the
chapters governing bonds / debt / finance / elections.

This script walks each mega, groups its sections by CHAPTER, flags chapters whose
NAME or whose section HEADINGS carry bond/finance/election language, and writes:

  documentation\260613_megachapter_selection.csv   (chapter-level review summary)
  documentation\260613_megachapter_sections.csv    (per-section allowlist)

The user prunes the `include` column of the review CSV, then
260613_finalize_chapters.py applies the tight name rule and writes selected_final.

Chapter grouping handles every expansion structure (see findings.md):
  - URL-chaptered (most titles, incl. TX/CA deep named codes and VT charter
    appendix): the section URL contains `/chapter-<X>/` -> key = chapter-<X>, name
    from the chapter index link text.
  - LOUISIANA flat `rs-<title>-<n>`: no chapter in the URL, but the title page
    interleaves `CHAPTER/PART/SUBPART` headings -> group sections by the nearest
    preceding chapter heading (document order).
  - NEBRASKA `statute-<chap>-<n>` flat with NO headings (e.g. chapter-77 Rev&Tax):
    falls to a single "(flat)" group -> section-level heading selection.

RESUMABLE (skips megas already in the output) + DETACHED via Task Scheduler, since
a full uncapped walk of 42 megas fetches every intermediate index page (~hours).
Self-logs via Tee to 260613_select_chapters_log.txt. CSVs written UTF-8+BOM.

Reuses fetch/segs/abs_url + SECTION_RE/PDF_CHAPTER_STATES from
260613_count_sections.py.

Run (project venv):
  Code\Python\venv\Scripts\python.exe Code\Python\Statutes\260613_select_chapters.py
  ...\260613_select_chapters.py --states LA,TX     (subset; for spot-checks)
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import polars as pl
from bs4 import BeautifulSoup

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
DOCS = HOME / "Data" / "Statutes" / "documentation"
COUNT_CSV = DOCS / "260613_expansion_count.csv"
SEED_CSV = DOCS / "260613_expansion_seed_manifest.csv"
REVIEW_OUT = DOCS / "260613_megachapter_selection.csv"
ALLOW_OUT = DOCS / "260613_megachapter_sections.csv"
LOG = DOCS / "260613_select_chapters_log.txt"
TASK_NAME = "DbD_ExpandChapters"

MEGA_THRESHOLD = 800            # divisions at/above this (from the count) are narrowed
# Per-division index-page cap for the walk. Full election titles need <=~700 pages
# (CA code-elec = 670) and complete; only giant tax codes we drop ~entirely (CA
# code-rtc = California Revenue & Taxation Code) hit the cap, capturing their
# top-level chapters without a 100-min runaway. A capped walk yields a partial
# section list -- acceptable for the drop-mostly RevTax codes.
MAX_PAGES = 1500

# Load the count module for shared helpers (fetch, segs, abs_url, SECTION_RE, ...).
_spec = importlib.util.spec_from_file_location("cnt", HERE / "260613_count_sections.py")
cnt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cnt)
cnt.DELAY = 0.7
fetch, segs, abs_url = cnt.fetch, cnt.segs, cnt.abs_url
SECTION_RE, PDF_CHAPTER_STATES = cnt.SECTION_RE, cnt.PDF_CHAPTER_STATES
FetchError = cnt.FetchError

# Chapter NAME -> include the whole chapter (bonds/finance/elections core).
NAME_CORE = ["bond", "debt", "borrow", "indebted", "obligation", "warrant",
             "financ", "fiscal", "sinking fund", "referend", "election", "ballot",
             "improvement", "municipal", "cities", "town", "village",
             "local government", "public works", "streets and highways"]
# Chapter NAME -> deny even if a core word also appears (surety/court/private finance;
# mirrors the user's classifier refinements in findings.md).
NAME_DENY = ["officer", "surety", "bail", "bondsm", "contractor", "court", "oath",
             "collection agenc", "consumer finance", "probate", "campaign",
             "agricultur", "criminal", "penal", "motor vehicle", "insurance",
             "repeal"]
# Tight SECTION-heading keywords for section-level selection inside generic chapters.
HEAD_KW = ["bond", "debt", "borrow", "indebted", "referend", "ballot",
           "election", "sinking fund", "bonded", "obligation"]


class _Tee:
    def __init__(self, *st): self.st = st
    def write(self, s):
        for x in self.st:
            try:
                x.write(s); x.flush()
            except Exception:
                pass
    def flush(self):
        for x in self.st:
            try:
                x.flush()
            except Exception:
                pass


def _start_logging() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    fh = open(LOG, "a", encoding="utf-8")
    sys.stdout = _Tee(sys.stdout, fh)
    sys.stderr = sys.stdout


def write_bom(df: pl.DataFrame, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(df.write_csv(), encoding="utf-8-sig")


def hits(text: str, kws) -> str:
    low = (text or "").lower()
    return ";".join(k for k in kws if k in low)


# --- Chapter grouping ----------------------------------------------------------
# LA-style chapter headings live in class-less <p> tags ("CHAPTER 4. BONDED
# INDEBTEDNESS AND SPECIAL TAXES"), not <h*>.
_HEAD_CHAP_RE = re.compile(r"\bCHAPTER\s+([0-9A-Za-z.\-]+)\b\.?\s*(.*)", re.I)


def chapter_key_for(url: str, mega_depth: int) -> str | None:
    """Group key for a section URL = the division LEVEL BELOW the mega, made unique
    by its full path slice. Resolution order:
      - the first `chapter-*` segment strictly below the mega (so TX/CA named codes
        group by their real chapter -- e.g. title-7/subtitle-a/chapter-211 -- and
        title-based states by chapter-705; the path prefix avoids chapter-number
        collisions across titles);
      - else the segment immediately below the mega if it is structural (so chapter-
        based states like NM group by `article-N`, not by the mega chapter itself);
      - else None -> flat/heading grouping (LA `rs-*`, NE `statute-*`)."""
    ss = segs(url)
    for i in range(mega_depth, len(ss)):
        if ss[i].startswith("chapter-"):
            return "/".join(ss[mega_depth:i + 1])
    if len(ss) > mega_depth and not SECTION_RE.match(ss[mega_depth]):
        return ss[mega_depth]
    return None


def walk(div_url: str, state: str):
    """Return (sections, chap_names).
      sections   : list of (section_url, heading, chapter_key)
      chap_names : {chapter_key: chapter_name}"""
    mega_depth = len(segs(div_url))
    pdf_state = state in PDF_CHAPTER_STATES
    visited, stack = set(), [div_url]
    sections: list[tuple[str, str, str]] = []
    chap_names: dict[str, str] = {}
    n_pages = 0
    while stack:
        u = stack.pop()
        if u in visited:
            continue
        visited.add(u)
        n_pages += 1
        if n_pages > MAX_PAGES:
            print(f"   !! MAX_PAGES {MAX_PAGES} hit walking {div_url} (partial)")
            break
        if n_pages % 200 == 0:
            print(f"     ... {n_pages} index pages, {len(sections)} sections so far")
        try:
            html = fetch(u)
        except FetchError as e:
            print(f"   !! dead index page: {e}")
            continue
        time.sleep(cnt.DELAY)
        base = segs(u); bl = len(base)
        soup = BeautifulSoup(html, "lxml")

        sect_links_here = []
        for a in soup.find_all("a", href=True):
            h = abs_url(a["href"]); s = segs(h)
            if len(s) != bl + 1 or s[:bl] != base:
                continue
            seg, text = s[-1], a.get_text(strip=True)
            is_sec = bool(SECTION_RE.match(seg)) or (pdf_state and seg.startswith("chapter-"))
            if not is_sec:                              # structural child: record name
                chap_names.setdefault("/".join(s[mega_depth:]), text)
            if is_sec:
                sect_links_here.append((h, seg, text))
            elif cnt.SKIP_SEG_RE.search(seg):
                continue
            elif h not in visited:
                stack.append(h)                         # recurse into sub-division

        if not sect_links_here:
            continue

        keyed, flat = [], []
        for h, seg, text in sect_links_here:
            ck = chapter_key_for(h, mega_depth)
            if ck is None:
                flat.append((h, seg, text))
            else:
                sections.append((h, text, ck))
        if flat:                                        # LA/NE: group by <p> headings
            sections.extend(_assign_by_heading(soup, flat, chap_names))
    return sections, chap_names


def _assign_by_heading(soup, flat, chap_names) -> list[tuple[str, str, str]]:
    """Sweep the page in document order; track the current CHAPTER heading (class-less
    <p>) and assign each flat section link to it. Falls back to '(flat)' before the
    first heading / when there are no chapter headings (e.g. NE chapter-77)."""
    flat_hrefs = {h for h, _, _ in flat}
    by_href = {h: text for h, _, text in flat}
    cur_key = "(flat)"
    out, seen = [], set()
    for el in soup.find_all(["h1", "h2", "h3", "h4", "h5", "p", "strong", "b", "a"]):
        if el.name == "a":
            href = abs_url(el.get("href", ""))
            if href in flat_hrefs and href not in seen:
                seen.add(href)
                out.append((href, by_href[href], cur_key))
        else:
            t = el.get_text(" ", strip=True)
            if len(t) < 120:                            # headings are short
                m = _HEAD_CHAP_RE.search(t)
                if m:
                    cur_key = "ch-" + m.group(1).lower()
                    chap_names.setdefault(cur_key, t[:90])
    for h, _, text in flat:
        if h not in seen:
            out.append((h, text, "(flat)"))
    return out


# --- Inputs --------------------------------------------------------------------
_CAT_REVTAX = re.compile(r"revenue|taxation|\btax\b", re.I)
_CAT_ELEC = re.compile(r"election|ballot|referend|voting", re.I)


def cat_of(name: str) -> str:
    if _CAT_REVTAX.search(name or ""):
        return "RevTax"
    if _CAT_ELEC.search(name or ""):
        return "Elections"
    return "other"


def mega_divisions(states: set[str] | None) -> pl.DataFrame:
    """Divisions to WALK + narrow: every mega (>= MEGA_THRESHOLD) PLUS every
    Elections/Revenue&Taxation division regardless of size (the user chose to
    narrow those categories; finalize_chapters applies tighter category rules)."""
    df = pl.read_csv(COUNT_CSV).filter(pl.col("kind") == "statute")
    df = df.with_columns(pl.col("name").map_elements(cat_of, return_dtype=pl.Utf8).alias("category"))
    df = df.filter(
        (pl.col("n_sections") >= MEGA_THRESHOLD)
        | (pl.col("category").is_in(["Elections", "RevTax"]))
    )
    if states:
        df = df.filter(pl.col("state_abbr").is_in(list(states)))
    return df.sort(["state_abbr", "div_slug"])


def seed_urls() -> set[str]:
    if not SEED_CSV.exists():
        return set()
    try:
        return {u.rstrip("/") for u in pl.read_csv(SEED_CSV)["url"].to_list() if u}
    except Exception:
        return set()


def done_megas() -> set[str]:
    if not REVIEW_OUT.exists():
        return set()
    try:
        return set(pl.read_csv(REVIEW_OUT)["div_url"].to_list())
    except Exception:
        return set()


# --- Classification ------------------------------------------------------------
def classify_chapter(cname: str, n_head: int) -> tuple[str, str]:
    """(tier, include) from chapter NAME + whether any section heading matched.
    DENY overrides a core hit (per the user's classifier refinements: surety/court/
    officer/repealed etc. are excluded even when a bond/finance word also appears);
    seed force-include is applied by the caller on top of this."""
    if hits(cname, NAME_DENY):
        return "deny", "N"
    if hits(cname, NAME_CORE):
        return "core", "Y"
    if n_head > 0:
        return "section", "Y"   # generic chapter, but holds bond/debt sections
    return "none", "N"


def process_mega(r: dict, seeds: set[str]) -> tuple[list[dict], list[dict]]:
    st, slug, url, dname = r["state_abbr"], r["div_slug"], r["url"], r["name"]
    print(f"\n== {st} {slug}  {dname[:55]}")
    t0 = time.time()
    sections, chap_names = walk(url, st)
    print(f"   {len(sections)} sections, {len(chap_names)} chapters ({time.time()-t0:.0f}s)")

    groups: dict[str, list[tuple[str, str]]] = {}
    for surl, heading, ckey in sections:
        groups.setdefault(ckey, []).append((surl, heading))

    category = cat_of(dname)
    single_flat = len(groups) == 1 and "(flat)" in groups
    review, allow = [], []
    for ckey, items in sorted(groups.items()):
        cname = chap_names.get(ckey, "")
        if not cname and ckey == "(flat)":
            # a division that is itself one flat chapter (e.g. an OR election
            # chapter): classify on the DIVISION name, not a blank.
            cname = dname if single_flat else "(individual sections)"
        n_head = sum(1 for _, h in items if hits(h, HEAD_KW))
        tier, include = classify_chapter(cname, n_head)
        has_seed = any(u.rstrip("/") in seeds for u, _ in items)
        if has_seed:
            tier, include = ("seed" if tier in ("none", "deny") else tier), "Y"
        trig = hits(cname, NAME_CORE) or "; ".join(
            h[:34] for u, h in items if hits(h, HEAD_KW))[:140]
        review.append({
            "state_abbr": st, "div_slug": slug, "div_url": url, "div_name": dname,
            "category": category, "chapter_key": ckey, "chapter_name": cname[:80],
            "n_sections": len(items), "n_head_hits": n_head,
            "name_core": hits(cname, NAME_CORE), "name_deny": hits(cname, NAME_DENY),
            "has_seed": has_seed, "tier": tier, "include": include, "triggers": trig,
        })
        for surl, heading in items:
            sec_sel = "Y" if (tier in ("core", "seed")) else (
                "Y" if (tier == "section" and hits(heading, HEAD_KW)) else "N")
            allow.append({
                "state_abbr": st, "div_slug": slug, "chapter_key": ckey,
                "chapter_name": cname[:80], "section_url": surl, "heading": heading,
                "tier": tier, "prelim_selected": sec_sel,
            })
    return review, allow


def append(rows_r: list[dict], rows_a: list[dict]) -> None:
    if rows_r:
        dr = pl.DataFrame(rows_r)
        if REVIEW_OUT.exists():
            dr = pl.concat([pl.read_csv(REVIEW_OUT), dr], how="vertical_relaxed")
        write_bom(dr, REVIEW_OUT)
    if rows_a:
        da = pl.DataFrame(rows_a)
        if ALLOW_OUT.exists():
            da = pl.concat([pl.read_csv(ALLOW_OUT), da], how="vertical_relaxed")
        write_bom(da, ALLOW_OUT)


def maybe_cleanup_task() -> None:
    try:
        subprocess.run(["schtasks", "/Delete", "/TN", TASK_NAME, "/F"],
                       capture_output=True, text=True, timeout=30)
    except Exception:
        pass


def print_summary() -> None:
    if not REVIEW_OUT.exists():
        print("No review output.")
        return
    rev = pl.read_csv(REVIEW_OUT)
    alw = pl.read_csv(ALLOW_OUT)
    by = (rev.group_by("state_abbr").agg(
        megas=pl.col("div_slug").n_unique(),
        chapters=pl.len(),
        chapters_incl=(pl.col("include") == "Y").sum(),
        sections=pl.col("n_sections").sum(),
    ).sort("state_abbr"))
    with pl.Config(tbl_rows=40):
        print("\nPer-state chapter review:\n", by)
    tot = alw.height
    sel = int((alw["prelim_selected"] == "Y").sum())
    print(f"\nMEGA sections total: {tot}  | PRELIM selected: {sel}  "
          f"({100*sel/tot:.0f}% kept)")
    print("Review   :", REVIEW_OUT)
    print("Allowlist:", ALLOW_OUT)


def run(states: set[str] | None) -> None:
    megas = mega_divisions(states)
    seeds = seed_urls()
    done = done_megas()
    todo = megas.filter(~pl.col("url").is_in(list(done))) if done else megas
    print(f"Megas: {megas.height}  done: {len(done & set(megas['url'].to_list()))}  "
          f"to do: {todo.height}" + (f"  states {sorted(states)}" if states else ""))
    t0 = time.time()
    for i, r in enumerate(todo.iter_rows(named=True), 1):
        rows_r, rows_a = process_mega(r, seeds)
        append(rows_r, rows_a)
        el = time.time() - t0
        eta = el / i * (todo.height - i)
        print(f"   [{i}/{todo.height}] done  elapsed {el:.0f}s  eta ~{eta:.0f}s")
    print(f"\nAll megas walked in {(time.time()-t0)/60:.1f} min.")
    print_summary()
    print("DONE_SELECT_CHAPTERS")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--states", default="")
    ap.add_argument("--summary-only", action="store_true")
    ap.add_argument("--no-task-cleanup", action="store_true")
    args = ap.parse_args()
    if args.summary_only:
        print_summary()
        return
    states = {s.strip().upper() for s in args.states.split(",") if s.strip()} or None
    run(states)
    if not args.no_task_cleanup:
        maybe_cleanup_task()


if __name__ == "__main__":
    _start_logging()
    print(f"\n===== 260613_select_chapters start @ "
          f"{datetime.now().isoformat(timespec='seconds')} =====")
    main()
