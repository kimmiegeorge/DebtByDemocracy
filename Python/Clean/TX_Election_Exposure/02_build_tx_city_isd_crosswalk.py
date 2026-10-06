"""Build auditable city--ISD area-overlap crosswalks for 2000, 2010, and 2020.

The crosswalk uses Census incorporated-place polygons and unified-school-district
polygons.  It measures jurisdictional area overlap, not population or voters.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path

import geopandas as gpd
import pandas as pd
import polars as pl


ROOT = Path(__file__).resolve().parents[4]
RAW_DIR = ROOT / "Data" / "Geography" / "Texas" / "raw" / "census_tiger"
OUT_DIR = ROOT / "Data" / "Clean_Intermediate" / "TX" / "Election_Exposure"
ELECTION_FILE = ROOT / "Data" / "TX" / "20240510_TX_local_election.csv"
CITY_PANEL_FILE = ROOT / "Data" / "Clean_Intermediate" / "TX" / "City_Month_Elections_News_WithFailed.csv"
WEBSITE_PANEL_FILE = (
    ROOT / "Data" / "Clean_Intermediate" / "Websites" / "Texas" / "time_series_website_data.csv"
)
SEED_CROSSWALK_FILE = ROOT / "Data" / "TX" / "241120_tx_uniquegovt_fuzzymatch_crosswalk.csv"

VINTAGES = {
    2000: ("tl_2010_48_place00.zip", "tl_2010_48_unsd00.zip"),
    2010: ("tl_2010_48_place10.zip", "tl_2010_48_unsd10.zip"),
    2020: ("tl_2020_48_place.zip", "tl_2020_48_unsd.zip"),
}
AREA_CRS = "EPSG:3083"  # NAD83 / Texas Centric Albers Equal Area

# These are name changes/abbreviations in the source panels, documented here
# rather than handled with a fuzzy geographic match.  The key is the Census
# boundary vintage because Spring Valley's Census place name changed after 2000.
CITY_PLACE_NAME_ALIASES = {
    2000: {"BUNKER HILL": "BUNKER HILL VILLAGE"},
    2010: {
        "BUNKER HILL": "BUNKER HILL VILLAGE",
        "SPRING VALLEY": "SPRING VALLEY VILLAGE",
    },
    2020: {
        "BUNKER HILL": "BUNKER HILL VILLAGE",
        "SPRING VALLEY": "SPRING VALLEY VILLAGE",
    },
}


def canonical_name(value: object) -> str:
    """Normalize names while retaining meaningful municipal name components."""
    if pd.isna(value):
        return ""
    text = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode()
    text = text.upper().replace("&", " AND ")
    text = re.sub(r"\bCITY OF\b|\bTOWN OF\b|\bVILLAGE OF\b", " ", text)
    text = re.sub(r"\bCONSOLIDATED INDEPENDENT SCHOOL DISTRICT\b", " CISD ", text)
    text = re.sub(r"\bINDEPENDENT SCHOOL DISTRICT\b", " ISD ", text)
    text = re.sub(r"\bCOMMON SCHOOL DISTRICT\b", " CSD ", text)
    text = re.sub(r"[^A-Z0-9]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def first_column(frame: gpd.GeoDataFrame, candidates: list[str]) -> str:
    for candidate in candidates:
        if candidate in frame.columns:
            return candidate
    raise KeyError(f"None of {candidates} found in {list(frame.columns)}")


def standardize_boundaries(path: Path, geography: str) -> gpd.GeoDataFrame:
    frame = gpd.read_file(f"zip://{path}")
    name_col = first_column(frame, ["NAME", "NAME10", "NAME00"])
    if geography == "place":
        geoid_col = first_column(frame, ["GEOID", "GEOID10", "PLCIDFP00"])
        out = frame[[geoid_col, name_col, "geometry"]].rename(
            columns={geoid_col: "place_geoid", name_col: "place_name"}
        )
        out["place_name_key"] = out["place_name"].map(canonical_name)
    else:
        geoid_col = first_column(frame, ["GEOID", "GEOID10", "UNSDIDFP00"])
        out = frame[[geoid_col, name_col, "geometry"]].rename(
            columns={geoid_col: "isd_geoid", name_col: "isd_name"}
        )
        out["isd_name_key"] = out["isd_name"].map(canonical_name)
    return out.to_crs(AREA_CRS)


def build_city_universe() -> pd.DataFrame:
    # Step 1A. Retain the city-month panel cities used for the media and
    # election-incidence outcomes.  This was the original spatial universe.
    city_month_seeds = (
        pl.read_csv(CITY_PANEL_FILE, columns=["seed_issuer"])
        .select(pl.col("seed_issuer").str.strip_chars().str.to_lowercase().alias("seed_key"))
        .unique()
    )

    # Step 1B. Attach the existing Texas city-name crosswalk to those cities.
    seed_xwalk = (
        pl.read_csv(SEED_CROSSWALK_FILE)
        .select([
            pl.col("seed_issuer").str.strip_chars().str.to_lowercase().alias("seed_key"),
            pl.col("muni_upper").str.strip_chars().alias("city_name_source"),
        ])
        .unique(subset=["seed_key"], keep="first")
    )
    city_month_cities = (
        city_month_seeds
        .join(seed_xwalk, on="seed_key", how="left")
        .with_columns(pl.lit("city_month").alias("city_universe_source"))
    )

    # Step 1C. Add every city that appears in the website-disclosure panel,
    # including cities without a RavenPack match.  GovernmentName is the
    # municipal name in the website data, so it can be matched directly to a
    # Census place boundary.  For the 151 cities shared by the two panels, the
    # existing crosswalk and GovernmentName agree; the website name is used
    # here for the full city universe.
    website_cities = (
        pl.read_csv(WEBSITE_PANEL_FILE, columns=["seed_issuer", "GovernmentName"])
        .filter(pl.col("seed_issuer").is_not_null() & (pl.col("seed_issuer").str.strip_chars() != ""))
        .select([
            pl.col("seed_issuer").str.strip_chars().str.to_lowercase().alias("seed_key"),
            pl.col("GovernmentName").str.strip_chars().alias("city_name_source"),
            pl.lit("website").alias("city_universe_source"),
        ])
        .unique(subset=["seed_key"], keep="first")
    )

    # Step 1D. The union is the full city universe for the three outcomes.
    # Website names take precedence because the website panel is the outcome
    # sample that previously lost cities when the RavenPack-only universe was
    # used to construct spatial exposure.
    city_month_only = city_month_cities.join(
        website_cities.select("seed_key"), on="seed_key", how="anti"
    )
    cities = pl.concat([website_cities, city_month_only], how="vertical").to_pandas()

    # Step 1E. Create a name key for matching to Census place names.
    cities["city_name_key"] = cities["city_name_source"].map(canonical_name)
    # The historical website panel labels BURNET TEX as Burkburnett.  This is
    # a documented source-data error; correct only that issuer.  Other shared
    # municipal names (for example, two website records for El Paso) are kept
    # as separate outcome-panel records and can legitimately share a boundary.
    cities.loc[cities["seed_key"].eq("burnet tex"), "city_name_source"] = "BURNET"
    cities["city_name_key"] = cities["city_name_source"].map(canonical_name)
    return cities


def build_isd_universe() -> pd.DataFrame:
    # Step 1D. Pull the distinct ISD names directly from the election data.
    isds = (
        pl.read_csv(ELECTION_FILE)
        .filter(pl.col("GovernmentType") == "ISD")
        .select(pl.col("GovernmentName").alias("isd_election_name"))
        .unique()
        .to_pandas()
    )
    isds["isd_name_key"] = isds["isd_election_name"].map(canonical_name)
    return isds


def name_match(
    source: pd.DataFrame,
    target: gpd.GeoDataFrame,
    source_key: str,
    target_key: str,
    target_id: str,
    target_name: str,
) -> pd.DataFrame:
    target_lookup = target[[target_key, target_id, target_name]].drop_duplicates(target_key)
    matched = source.merge(target_lookup, left_on=source_key, right_on=target_key, how="left")
    matched["match_status"] = matched[target_id].notna().map({True: "exact_normalized", False: "unmatched"})
    return matched


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # ========================================================================
    # STEP 1: Define the city and ISD names we need to locate in Census files.
    # ========================================================================
    cities = build_city_universe()
    isd_elections = build_isd_universe()
    all_city_diagnostics: list[pd.DataFrame] = []
    all_isd_diagnostics: list[pd.DataFrame] = []
    all_overlaps: list[pd.DataFrame] = []

    for vintage, (place_file, isd_file) in VINTAGES.items():
        # ====================================================================
        # STEP 2: Read one historical Census vintage and match names.
        # ====================================================================
        print(f"Building {vintage} city--ISD overlap crosswalk")
        places = standardize_boundaries(RAW_DIR / place_file, "place")
        isds = standardize_boundaries(RAW_DIR / isd_file, "isd")

        city_match_input = cities.copy()
        city_match_input["city_name_match_key"] = city_match_input["city_name_key"].replace(
            CITY_PLACE_NAME_ALIASES.get(vintage, {})
        )
        city_match = name_match(
            city_match_input,
            places,
            "city_name_match_key",
            "place_name_key",
            "place_geoid",
            "place_name",
        )
        city_match["boundary_vintage"] = vintage
        all_city_diagnostics.append(city_match)

        isd_match = name_match(
            isd_elections, isds, "isd_name_key", "isd_name_key", "isd_geoid", "isd_name"
        )
        isd_match["boundary_vintage"] = vintage
        all_isd_diagnostics.append(isd_match)

        # ====================================================================
        # STEP 3: Overlay matched cities and ISDs to calculate area shares.
        # ====================================================================
        matched_cities = city_match.loc[city_match["match_status"].eq("exact_normalized")].merge(
            places[["place_geoid", "geometry"]], on="place_geoid", how="left", validate="many_to_one"
        )
        city_geo = gpd.GeoDataFrame(matched_cities, geometry="geometry", crs=AREA_CRS)
        city_geo["city_area_sq_m"] = city_geo.geometry.area

        overlap = gpd.overlay(
            city_geo[["seed_key", "city_name_source", "place_geoid", "city_area_sq_m", "geometry"]],
            isds[["isd_geoid", "isd_name", "geometry"]],
            how="intersection",
            keep_geom_type=False,
        )
        overlap["intersection_area_sq_m"] = overlap.geometry.area
        overlap = overlap.loc[overlap["intersection_area_sq_m"] > 0].copy()
        overlap["city_area_share"] = overlap["intersection_area_sq_m"] / overlap["city_area_sq_m"]
        overlap["boundary_vintage"] = vintage
        overlap = overlap.drop(columns="geometry")
        all_overlaps.append(pd.DataFrame(overlap))

        overlap.to_csv(OUT_DIR / f"city_isd_overlap_area_{vintage}.csv", index=False)
        print(
            f"  matched cities: {city_match['place_geoid'].notna().sum():,}/{len(city_match):,}; "
            f"matched ISD election names: {isd_match['isd_geoid'].notna().sum():,}/{len(isd_match):,}; "
            f"overlap rows: {len(overlap):,}"
        )

    # ========================================================================
    # STEP 4: Save crosswalks and all unmatched names for manual audit.
    # ========================================================================
    city_diagnostics = pd.concat(all_city_diagnostics, ignore_index=True)
    isd_diagnostics = pd.concat(all_isd_diagnostics, ignore_index=True)
    overlaps = pd.concat(all_overlaps, ignore_index=True)
    city_diagnostics.to_csv(OUT_DIR / "city_place_boundary_matches.csv", index=False)
    isd_diagnostics.to_csv(OUT_DIR / "isd_election_boundary_matches.csv", index=False)
    city_diagnostics.loc[city_diagnostics["match_status"].eq("unmatched")].to_csv(
        OUT_DIR / "city_place_boundary_unmatched.csv", index=False
    )
    isd_diagnostics.loc[isd_diagnostics["match_status"].eq("unmatched")].to_csv(
        OUT_DIR / "isd_election_boundary_unmatched.csv", index=False
    )
    overlaps.to_csv(OUT_DIR / "city_isd_overlap_area_all_vintages.csv", index=False)


if __name__ == "__main__":
    main()
