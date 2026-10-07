"""Download the Census boundary vintages used for Texas ISD-overlap exposure.

The files are deliberately cached under Data/Geography rather than mixed with
analysis outputs.  Each file's source URL and SHA-256 are saved in a manifest.
"""

from __future__ import annotations

import hashlib
import json
from datetime import date
from pathlib import Path

import requests


ROOT = Path(__file__).resolve().parents[4]
RAW_DIR = ROOT / "Data" / "Geography" / "Texas" / "raw" / "census_tiger"

FILES = {
    "place_2000": "https://www2.census.gov/geo/tiger/TIGER2010/PLACE/2000/tl_2010_48_place00.zip",
    "isd_2000": "https://www2.census.gov/geo/tiger/TIGER2010/UNSD/2000/tl_2010_48_unsd00.zip",
    "place_2010": "https://www2.census.gov/geo/tiger/TIGER2010/PLACE/2010/tl_2010_48_place10.zip",
    "isd_2010": "https://www2.census.gov/geo/tiger/TIGER2010/UNSD/2010/tl_2010_48_unsd10.zip",
    "place_2020": "https://www2.census.gov/geo/tiger/TIGER2020/PLACE/tl_2020_48_place.zip",
    "isd_2020": "https://www2.census.gov/geo/tiger/TIGER2020/UNSD/tl_2020_48_unsd.zip",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path) -> None:
    temporary = target.with_suffix(target.suffix + ".part")
    with requests.get(
        url,
        headers={"User-Agent": "Voting-on-Bonds research pipeline"},
        timeout=120,
        stream=True,
    ) as response, temporary.open("wb") as handle:
        response.raise_for_status()
        for chunk in response.iter_content(chunk_size=1024 * 1024):
            if chunk:
                handle.write(chunk)
    temporary.replace(target)


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, str | int]] = []
    for label, url in FILES.items():
        target = RAW_DIR / Path(url).name
        if target.exists() and target.stat().st_size > 0:
            print(f"Using cached {target.name}")
        else:
            print(f"Downloading {label}: {url}")
            download(url, target)
        manifest.append({
            "label": label,
            "url": url,
            "local_file": target.name,
            "bytes": target.stat().st_size,
            "sha256": sha256(target),
            "download_verified_on": str(date.today()),
        })

    (RAW_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {RAW_DIR / 'manifest.json'}")


if __name__ == "__main__":
    main()
