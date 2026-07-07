#!/usr/bin/env python3
r"""
260611_repair_ky_pdfs.py  --  Debt by Democracy: state statute AI task

KY-only corpus repair. Kentucky's Justia code pages render the statute text as an
EMBEDDED PDF (div#codes-content is empty), so the initial HTML crawl captured empty
bodies for all 1,537 KY statute sections. Each cached KY page links the PDF, e.g.
  https://statecodesfiles.justia.com/kentucky/2025/chapter-96/section-96-640/section-96-640.pdf
This script parses that link from each cached page, fetches the PDF (curl_cffi,
Cloudflare-safe), extracts text (pymupdf), and rebuilds KY's consolidated .txt
files. Other 9 states are unaffected (full HTML text already).

Resumable: fetched PDFs are cached under raw\KY\_cache_pdf\... and skipped on
re-run. Robust per-section (a bad PDF is logged and skipped, not fatal).

Usage:
  ...\venv\Scripts\python.exe -u ...\260611_repair_ky_pdfs.py [--chapters chapter-96,chapter-66] [--delay 0.8]
Writes: rebuilt raw\KY\kentucky_<div>.txt + raw\KY\ky_statutes.txt,
        raw\260611_ky_repair_manifest.csv
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import sys
import time
from pathlib import Path

import fitz  # pymupdf
import polars as pl
from curl_cffi import requests as creq

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = Path(__file__).resolve().parent
HOME = Path(r"C:\Users\juneh\Dropbox (Personal)\Voting on Bonds")
STAT = HOME / "Data" / "Statutes"
RAW = STAT / "raw"
MANIFEST = RAW / "260611_download_manifest.csv"
REPAIR_MAN = RAW / "260611_ky_repair_manifest.csv"

_spec = importlib.util.spec_from_file_location("dl", HERE / "260611_download_statutes.py")
dl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dl)

PDF_RE = re.compile(r"https://statecodesfiles\.justia\.com[^\"'<> ]+\.pdf", re.I)
HDR = "=" * 80
SUB = "-" * 80
IMPERSONATE = "chrome124"


def fetch_pdf(url: str, tries: int = 4) -> bytes:
    last = None
    for i in range(tries):
        try:
            r = creq.get(url, impersonate=IMPERSONATE, timeout=60)
            if r.status_code == 200 and r.content[:4] == b"%PDF":
                return r.content
            last = f"status={r.status_code}"
        except Exception as e:  # noqa: BLE001
            last = repr(e)
        time.sleep(2 * (i + 1))
    raise RuntimeError(f"pdf fetch failed {url}: {last}")


def pdf_text(content: bytes) -> str:
    doc = fitz.open(stream=content, filetype="pdf")
    raw = "\n".join(p.get_text() for p in doc)
    doc.close()
    # Light cleanup: drop page-number lines, collapse blank runs.
    lines = [ln.rstrip() for ln in raw.splitlines()]
    lines = [ln for ln in lines if not re.fullmatch(r"\s*Page \d+ of \d+\s*", ln)]
    txt = "\n".join(lines)
    return re.sub(r"\n{3,}", "\n\n", txt).strip()


def pdf_cache_path(html_cache_rel: str) -> Path:
    # mirror the html cache path but under _cache_pdf and .pdf
    rel = Path(html_cache_rel)
    parts = list(rel.parts)
    parts[parts.index("_cache")] = "_cache_pdf"
    return STAT / Path(*parts).with_suffix(".pdf")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chapters", default="", help="comma div_slugs, e.g. chapter-96,chapter-66")
    ap.add_argument("--delay", type=float, default=0.8)
    ap.add_argument("--task-name", default="", help="if set, unregister this scheduled task on completion")
    ap.add_argument("--log", default="", help="append stdout/stderr to this file (for detached runs)")
    args = ap.parse_args()
    if args.log:
        fh = open(args.log, "a", encoding="utf-8", buffering=1)
        sys.stdout = fh
        sys.stderr = fh
    only = {c.strip() for c in args.chapters.split(",") if c.strip()} or None

    man = pl.read_csv(MANIFEST).filter(
        (pl.col("state_abbr") == "KY") & (pl.col("http_status") == 200))
    if only:
        man = man.filter(pl.col("div_slug").is_in(list(only)))
    rows = man.to_dicts()
    print(f"KY repair: {len(rows)} sections"
          + (f" in {sorted(only)}" if only else " (all KY)") + f", delay {args.delay}s")

    rec, by_div = [], {}
    t0 = time.time()
    for i, r in enumerate(rows, 1):
        html_path = STAT / r["cache_path"]
        html = html_path.read_text(encoding="utf-8", errors="replace")
        heading, hbody, year = dl.extract(html)
        if hbody.strip():                       # already has HTML text
            body, src = hbody, "html"
        else:
            mpdf = PDF_RE.search(html)
            if not mpdf:
                body, src = "", "no-pdf-link"
            else:
                pdf_url = mpdf.group(0)
                cp = pdf_cache_path(r["cache_path"])
                cp.parent.mkdir(parents=True, exist_ok=True)
                try:
                    content = cp.read_bytes() if (cp.exists() and cp.stat().st_size > 0) \
                        else None
                    if content is None:
                        content = fetch_pdf(pdf_url)
                        cp.write_bytes(content)
                        time.sleep(args.delay)
                    body, src = pdf_text(content), "pdf"
                except Exception as e:  # noqa: BLE001
                    body, src = "", f"error:{e}"
        by_div.setdefault(r["div_slug"], []).append(
            (r["section_url"], heading, body))
        rec.append({"section_url": r["section_url"], "div_slug": r["div_slug"],
                    "heading": heading, "source": src, "text_len": len(body)})
        if i % 50 == 0 or i == len(rows):
            el = time.time() - t0
            eta = el / i * (len(rows) - i)
            print(f"  {i}/{len(rows)}  elapsed {el:4.0f}s eta ~{eta:4.0f}s")

    # rebuild consolidated per-div + master
    statefiles = []
    for div, items in by_div.items():
        items.sort(key=lambda x: dl._natkey(x[0]))
        parts = [f"{HDR}\nKY {div}\n{HDR}\n"]
        for url, heading, body in items:
            parts.append(f"{HDR}\n{heading}\nURL: {url}\n{SUB}\n{body}\n")
        outp = RAW / "KY" / f"kentucky_{div}.txt"
        outp.write_text("\n".join(parts), encoding="utf-8")
        statefiles.append(outp)
        print(f"  rebuilt {outp.relative_to(STAT)} ({len(items)} sections)")
    if not only:  # only rebuild master on a full pass
        master = RAW / "KY" / "ky_statutes.txt"
        master.write_text(f"\n\n{HDR}\n{HDR}\n\n".join(
            f.read_text(encoding="utf-8") for f in sorted(statefiles)), encoding="utf-8")
        print(f"  rebuilt master {master.relative_to(STAT)}")

    rm = pl.DataFrame(rec)
    REPAIR_MAN.write_text(rm.write_csv())
    bad = rm.filter(pl.col("text_len") == 0)
    print(f"\nDone: {rm.height} sections, "
          f"{int((rm['source']=='pdf').sum())} from PDF, {bad.height} empty/failed.")
    if bad.height:
        print(bad.select('section_url', 'source').head(10))
    if args.task_name:
        import subprocess
        subprocess.run(["schtasks", "/Delete", "/TN", args.task_name, "/F"],
                       capture_output=True)
        print(f"unregistered scheduled task '{args.task_name}'")


if __name__ == "__main__":
    main()
