#!/usr/bin/env python3
r"""260914_fetch_taxlimits.py -- Debt by Democracy (2nd R&R): the SINGLE content crawl for the
tax-increase-vote dimension. Reads 260914_crawl_targets.json (built from the hand-reviewed
260914_fetch_targetlist_tax_FINAL.csv) and fetches each target's section bodies into
raw\<ST>\260914_<statename>_<slug>.txt (standard consolidated format).

Reuses the proven fetch/extract/enumerate layer (260625_download_statutes -> curl_cffi/Cloudflare,
plain-first auto-escalate). GENTLER pacing per user (DELAY=3.0 + JITTER up to 1.2). Verifies BODY
PROSE, not exit status. RESUMES: a target whose output already has prose is skipped. A transient
Cloudflare block is NEVER skipped -- escalating cooldown + retry the same target; if it survives all
cooldowns the run STOPS (non-zero) so it can't finish 'clean' with missing data.

Run DETACHED via Task Scheduler. Progress -> 260914_fetch_log.txt (runner tees stdout).
Modes: single | walk_all | walk_filter (regex 'filt') | pa_nonjustia (non-Justia single page).
"""
from __future__ import annotations
import importlib.util, json, re, sys, time, traceback
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
RAW  = HOME / "Data" / "Statutes" / "raw"
DOC  = HOME / "Data" / "Statutes" / "documentation"
TARGETS_JSON = DOC / "260914_crawl_targets.json"

_spec = importlib.util.spec_from_file_location("dl", HERE / "260625_download_statutes.py")
dl = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(dl)
from bs4 import BeautifulSoup
HDR, SUB = dl.HDR, dl.SUB
DeadLink, Blocked = dl.DeadLink, dl.Blocked

# --- gentler pacing (user request 2026-09-14) ---
dl.DELAY = 3.0
dl.JITTER = 1.2

COOLDOWNS = [300, 600, 1200, 1800, 1800]   # ride out an IP block instead of skipping

try: sys.stdout.reconfigure(encoding="utf-8")
except Exception: pass
def log(m=""): print(m, flush=True)

def keep_awake():
    """Prevent the PC sleeping mid-crawl (a sleep freezes the whole run)."""
    try:
        import ctypes
        ctypes.windll.kernel32.SetThreadExecutionState(0x80000000 | 0x00000001)  # ES_CONTINUOUS|ES_SYSTEM_REQUIRED
    except Exception as e:
        log(f"  (keep_awake unavailable: {e})")

def has_prose(body: str) -> bool:
    b = re.sub(r"\s+", " ", body or "").strip()
    return len(b) >= 200 and sum(c.islower() for c in b) >= 80

def out_path(state, statename, slug):
    return RAW / state / f"260914_{statename}_{slug}.txt"

def write_consolidated(state, statename, slug, source_url, entries):
    out = out_path(state, statename, slug)
    out.parent.mkdir(parents=True, exist_ok=True)
    parts = [f"{HDR}\n{statename.title()} -- {slug}  (260914 tax-limits fetch)\nsource_url: {source_url}\n{HDR}\n"]
    for heading, url, body in entries:
        parts.append(f"{HDR}\n{heading}\nURL: {url}\n{SUB}\n{body}\n")
    out.write_text("\n".join(parts), encoding="utf-8")
    return out

def already_done(state, statename, slug) -> bool:
    p = out_path(state, statename, slug)
    if not p.exists() or p.stat().st_size < 400:
        return False
    txt = p.read_text(encoding="utf-8", errors="replace")
    return has_prose(txt)

def fetch_single(state, url):
    heading, body, year, nb, was_fetched, src = dl.get_section(state, url)
    return heading, body

def do_target(t) -> dict:
    state, statename, slug, mode = t["state"], t["statename"], t["slug"], t["mode"]
    url = t.get("url", "")
    entries, landed, dead = [], 0, 0
    if mode == "single":
        try:
            h, b = fetch_single(state, url); entries.append((h, url, b)); landed += has_prose(b)
        except DeadLink as e:
            dead += 1; log(f"    DEAD {url} ({e})")
    elif mode in ("walk_all", "walk_filter"):
        leaves, nidx = dl.enumerate_urls(url, state)
        if mode == "walk_filter":
            flt = re.compile(t["filt"]); leaves = [u for u in leaves if flt.search(u)]
        log(f"    enumerated {nidx} idx page(s) -> {len(leaves)} leaves")
        for i, u in enumerate(leaves, 1):
            try:
                h, b, yr, nb, wf, src = dl.get_section(state, u); entries.append((h, u, b))
                if has_prose(b): landed += 1
            except DeadLink as e:
                dead += 1; log(f"    [{i}/{len(leaves)}] DEAD {u} ({e})")
            if i % 20 == 0 or i == len(leaves):
                log(f"    [{i}/{len(leaves)}] landed={landed} dead={dead}")
    elif mode == "pa_nonjustia":
        html = dl.fetch(url); dl._polite()
        soup = BeautifulSoup(html, "lxml")
        body = soup.get_text("\n", strip=True)
        entries.append((t.get("name", "PA Act 511"), url, body)); landed += has_prose(body)
    else:
        raise ValueError(f"unknown mode {mode}")
    out = write_consolidated(state, statename, slug, url, entries) if entries else None
    return dict(entries=len(entries), landed=landed, dead=dead, file=str(out) if out else "")

def main():
    keep_awake()
    targets = json.loads(TARGETS_JSON.read_text(encoding="utf-8"))
    log(f"260914 tax-limits crawl START {time.strftime('%Y-%m-%d %H:%M:%S')}  "
        f"targets={len(targets)}  DELAY={dl.DELAY}+U(0,{dl.JITTER})")
    t0 = time.time(); results = []; total_sections = 0
    for n, t in enumerate(targets, 1):
        tag = f"[{n}/{len(targets)}] {t['state']} {t['slug']} ({t['mode']})"
        if already_done(t["state"], t["statename"], t["slug"]):
            log(f"{tag}  SKIP (already has prose)"); continue
        log(f"\n{'='*84}\n{tag}\n  {t.get('note','')}")
        tries = 0
        while True:
            try:
                r = do_target(t)
                total_sections += r["landed"]
                log(f"  DONE entries={r['entries']} prose={r['landed']} dead={r['dead']}  "
                    f"(running section total={total_sections})")
                results.append(dict(slug=t["slug"], **r, note="")); break
            except Blocked as e:
                if tries >= len(COOLDOWNS):
                    log(f"  !! STILL BLOCKED after {tries} cooldowns: {e}  -- STOPPING (rerun to resume)")
                    log(f"BLOCKED_STOP {time.strftime('%H:%M:%S')}"); sys.exit(2)
                cd = COOLDOWNS[tries]; tries += 1
                log(f"  !! BLOCKED: {e}  cooldown {cd}s (retry {tries}/{len(COOLDOWNS)})")
                time.sleep(cd)
            except Exception as e:
                log(f"  !! ERROR: {e}\n{traceback.format_exc()}")
                results.append(dict(slug=t["slug"], entries=0, landed=0, dead=0, file="", note=f"ERROR {e}")); break
    log(f"\n{'#'*84}\nSUMMARY ({(time.time()-t0)/60:.1f} min)  targets_run={len(results)}  "
        f"total_sections_with_prose={total_sections}")
    for r in results:
        if r.get("note") or r["landed"] == 0:
            log(f"  CHECK {r['slug']}: entries={r['entries']} prose={r['landed']} {r.get('note','')}")
    log(f"DONE_TAXCRAWL {time.strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    main()
