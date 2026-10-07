"""
Rebuild county-level BEA demographic controls.

This recreates Data/BEA/countydemos_2001_2022.dta with the same columns:
    fips, year, geoname, employment, gdp, percap_inc, pers_inc, pop

The script uses the newest local BEA source files it can find:
    - CAINC4.zip for personal income, population, and per-capita income
    - CAGDP1.zip for real GDP
    - employment_2001_2022.dta for employment, unless a newer local
      employment file is added later

BEA county GDP starts in 2001. With the current local files, income/population
variables run through 2024, GDP runs through 2024, and employment runs through
2022.
"""

from __future__ import annotations

import argparse
import re
import zipfile
from pathlib import Path

import pandas as pd


REPO_ROOT = Path(__file__).resolve().parents[3]
DATA_BEA = REPO_ROOT / "Data" / "BEA"

CAINC4_LINES = {
    10: "pers_inc",
    20: "pop",
    30: "percap_inc",
}

CAGDP1_LINES = {
    1: "gdp",
}

OUTPUT_COLUMNS = [
    "fips",
    "year",
    "geoname",
    "employment",
    "gdp",
    "percap_inc",
    "pers_inc",
    "pop",
]


def find_zip_member(zip_path: Path, pattern: str) -> str:
    regex = re.compile(pattern)
    with zipfile.ZipFile(zip_path) as zf:
        matches = [name for name in zf.namelist() if regex.fullmatch(Path(name).name)]

    if not matches:
        raise FileNotFoundError(f"No zip member matching {pattern!r} in {zip_path}")

    return sorted(matches)[-1]


def read_wide_bea_csv(zip_path: Path, member_pattern: str) -> pd.DataFrame:
    member = find_zip_member(zip_path, member_pattern)
    with zipfile.ZipFile(zip_path) as zf:
        with zf.open(member) as fh:
            return pd.read_csv(
                fh,
                dtype={"GeoFIPS": "string"},
                encoding="latin1",
                low_memory=False,
                on_bad_lines="skip",
            )


def normalize_fips(value: object) -> str | None:
    if pd.isna(value):
        return None

    text = str(value).strip().strip('"').strip()
    if not text:
        return None

    # BEA downloads may contain numeric FIPS or strings such as "01001".
    digits = re.sub(r"\D", "", text)
    if not digits:
        return None

    return digits.zfill(5)


def reshape_bea_lines(
    df: pd.DataFrame,
    line_map: dict[int, str],
    start_year: int,
    end_year: int,
) -> pd.DataFrame:
    year_cols = [
        col
        for col in df.columns
        if re.fullmatch(r"\d{4}", str(col)) and start_year <= int(col) <= end_year
    ]
    if not year_cols:
        raise ValueError("No year columns found in requested range.")

    keep = df[df["LineCode"].isin(line_map)].copy()
    keep["fips"] = keep["GeoFIPS"].map(normalize_fips)
    keep = keep[keep["fips"].notna() & keep["fips"].str.fullmatch(r"\d{5}")]
    keep["geoname"] = keep["GeoName"].astype("string").str.strip()

    long = keep.melt(
        id_vars=["fips", "geoname", "LineCode"],
        value_vars=year_cols,
        var_name="year",
        value_name="value",
    )
    long["year"] = long["year"].astype("int64")
    long["variable"] = long["LineCode"].map(line_map)
    long["value"] = pd.to_numeric(
        long["value"].astype("string").str.replace(",", "", regex=False),
        errors="coerce",
    )

    wide = (
        long.pivot_table(
            index=["fips", "year", "geoname"],
            columns="variable",
            values="value",
            aggfunc="first",
        )
        .reset_index()
        .rename_axis(columns=None)
    )

    return wide


def load_income_population(start_year: int, end_year: int) -> pd.DataFrame:
    df = read_wide_bea_csv(DATA_BEA / "CAINC4.zip", r"CAINC4__ALL_AREAS_1969_\d{4}\.csv")
    return reshape_bea_lines(df, CAINC4_LINES, start_year, end_year)


def load_gdp(start_year: int, end_year: int) -> pd.DataFrame:
    df = read_wide_bea_csv(DATA_BEA / "CAGDP1.zip", r"CAGDP1__ALL_AREAS_2001_\d{4}\.csv")
    return reshape_bea_lines(df, CAGDP1_LINES, start_year, end_year)


def load_employment(start_year: int, end_year: int) -> pd.DataFrame:
    path = DATA_BEA / "employment_2001_2022.dta"
    if not path.exists():
        return pd.DataFrame(columns=["fips", "year", "geoname", "employment"])

    df = pd.read_stata(path)
    df["fips"] = df["fips"].map(normalize_fips)
    df["year"] = df["year"].astype("int64")
    df = df[df["year"].between(start_year, end_year)].copy()
    return df[["fips", "year", "geoname", "employment"]]


def build_county_demos(start_year: int, end_year: int, include_empty_years: bool) -> pd.DataFrame:
    income_pop = load_income_population(start_year, end_year)
    gdp = load_gdp(start_year, end_year)
    employment = load_employment(start_year, end_year)

    out = income_pop.merge(gdp, on=["fips", "year"], how="outer", suffixes=("", "_gdp"))
    if "geoname_gdp" in out.columns:
        out["geoname"] = out["geoname"].combine_first(out["geoname_gdp"])
        out = out.drop(columns=["geoname_gdp"])

    out = out.merge(employment, on=["fips", "year"], how="outer", suffixes=("", "_employment"))
    if "geoname_employment" in out.columns:
        out["geoname"] = out["geoname"].combine_first(out["geoname_employment"])
        out = out.drop(columns=["geoname_employment"])

    if include_empty_years:
        fips_names = out[["fips", "geoname"]].dropna(subset=["fips"]).drop_duplicates("fips")
        years = pd.DataFrame({"year": list(range(start_year, end_year + 1))})
        panel = fips_names.merge(years, how="cross")
        out = panel.merge(out.drop(columns=["geoname"]), on=["fips", "year"], how="left")

    value_cols = ["employment", "gdp", "percap_inc", "pers_inc", "pop"]
    out = out[out["fips"].notna() & out["year"].between(start_year, end_year)].copy()
    if not include_empty_years:
        out = out[out[value_cols].notna().any(axis=1)].copy()

    for col in value_cols:
        out[col] = pd.to_numeric(out[col], errors="coerce")

    out = out[OUTPUT_COLUMNS].sort_values(["fips", "year"]).reset_index(drop=True)
    return out


def print_coverage(df: pd.DataFrame) -> None:
    value_cols = ["employment", "gdp", "percap_inc", "pers_inc", "pop"]
    summary = (
        df.groupby("year", dropna=False)
        .agg(
            N=("fips", "size"),
            employment=("employment", lambda x: x.notna().sum()),
            gdp=("gdp", lambda x: x.notna().sum()),
            percap_inc=("percap_inc", lambda x: x.notna().sum()),
            pers_inc=("pers_inc", lambda x: x.notna().sum()),
            pop=("pop", lambda x: x.notna().sum()),
        )
        .reset_index()
    )

    print("\nCoverage by year:")
    print(summary.to_string(index=False))

    print("\nAvailability by variable:")
    for col in value_cols:
        years = sorted(df.loc[df[col].notna(), "year"].unique())
        if years:
            print(f"  {col}: {min(years)}-{max(years)} ({len(years)} years)")
        else:
            print(f"  {col}: no non-missing data")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start-year", type=int, default=1999)
    parser.add_argument("--end-year", type=int, default=2026)
    parser.add_argument(
        "--output-stata",
        type=Path,
        default=DATA_BEA / "countydemos_1999_2026.dta",
    )
    parser.add_argument(
        "--output-csv",
        type=Path,
        default=DATA_BEA / "countydemos_1999_2026.csv",
    )
    parser.add_argument(
        "--include-empty-years",
        action="store_true",
        help="Include requested county-years even when all variables are missing.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    df = build_county_demos(args.start_year, args.end_year, args.include_empty_years)

    args.output_stata.parent.mkdir(parents=True, exist_ok=True)
    args.output_csv.parent.mkdir(parents=True, exist_ok=True)

    df.to_stata(args.output_stata, write_index=False, version=118)
    df.to_csv(args.output_csv, index=False)

    print(f"Wrote {len(df):,} rows to:")
    print(f"  {args.output_stata}")
    print(f"  {args.output_csv}")
    print_coverage(df)


if __name__ == "__main__":
    main()
