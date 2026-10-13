"""Create Texas city and ISD panels with overlapping-ISD election exposure."""

#%% Paths and exposure definitions
import argparse
import re
import unicodedata
from pathlib import Path

import numpy as np
import pandas as pd
import polars as pl


ROOT = Path(__file__).resolve().parents[4]
OUT_DIR = ROOT / "Data" / "Clean_Intermediate" / "TX" / "Election_Exposure"
ELECTION_FILE = ROOT / "Data" / "TX" / "20240510_TX_local_election.csv"
CITY_MONTH_FILE = ROOT / "Data" / "Clean_Intermediate" / "TX" / "City_Month_Elections_News_WithFailed.csv"
WEBSITE_PANEL_FILE = (
    ROOT / "Data" / "Clean_Intermediate" / "Websites" / "Texas" / "time_series_website_data.csv"
)

# 360 months covers the full observed election history (the raw file begins
# in 1995), so it provides an "any prior recorded failure" sensitivity test.
HORIZONS = (12, 24, 36, 60, 360)
REJECTION_RISK_HORIZON_MONTHS = 60
SIMPLE_RISK_MIN_CITY_AREA_SHARE = 0.20


def canonical_name(value: object) -> str:
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


def add_prior_failure_exposure(
    frame: pd.DataFrame,
    group_column: str,
    date_column: str,
    failures: pd.DataFrame,
    failure_group_column: str,
    failure_date_column: str,
    share_column: str | None = None,
) -> pd.DataFrame:
    """Apply the same calendar-month exposure rule to one analysis panel."""
    out = frame.copy()
    for horizon in HORIZONS:
        out[f"prior_failure_count_{horizon}m"] = 0
        out[f"prior_failure_any_{horizon}m"] = 0
        if share_column:
            out[f"prior_failure_max_area_share_{horizon}m"] = 0.0

    failure_groups = {
        group: values.sort_values(failure_date_column)
        for group, values in failures.groupby(failure_group_column, sort=False)
    }
    for group, index in out.groupby(group_column, sort=False).groups.items():
        history = failure_groups.get(group)
        if history is None or history.empty:
            continue
        dates = history[failure_date_column].to_numpy(dtype="datetime64[ns]")
        shares = history[share_column].to_numpy(dtype=float) if share_column else None
        for row_index in index:
            outcome_date = out.at[row_index, date_column]
            if pd.isna(outcome_date):
                continue
            right = np.searchsorted(dates, np.datetime64(outcome_date), side="left")
            for horizon in HORIZONS:
                left_date = outcome_date - pd.DateOffset(months=horizon)
                left = np.searchsorted(dates, np.datetime64(left_date), side="left")
                count = right - left
                out.at[row_index, f"prior_failure_count_{horizon}m"] = count
                out.at[row_index, f"prior_failure_any_{horizon}m"] = int(count > 0)
                if share_column and count > 0:
                    out.at[row_index, f"prior_failure_max_area_share_{horizon}m"] = shares[left:right].max()
    return out


def add_prior_rejection_risk(
    frame: pd.DataFrame,
    group_column: str,
    date_column: str,
    propositions: pd.DataFrame,
    proposition_group_column: str,
    proposition_date_column: str,
    horizon_months: int | None = REJECTION_RISK_HORIZON_MONTHS,
    column_suffix: str | None = None,
) -> pd.DataFrame:
    """Add local rejection-risk measures from prior ISD propositions.

    The area-weighted measure weights each ISD proposition by the share of the
    city inside the ISD. The simple measure gives equal weight to propositions
    from ISDs covering at least 20 percent of the city. Both remain missing
    when there is no qualifying proposition in the lookback window: no local
    election is absence of revealed voter risk, not evidence of zero risk.
    A ``None`` horizon uses all available prior records.
    """
    out = frame.copy()
    suffix = column_suffix or f"{horizon_months}m"
    weighted_column = f"prior_weighted_failure_rate_{suffix}"
    simple_column = f"prior_simple_failure_rate_{round(SIMPLE_RISK_MIN_CITY_AREA_SHARE * 100)}pct_{suffix}"
    out[weighted_column] = np.nan
    out[simple_column] = np.nan

    proposition_groups = {
        group: values.sort_values(proposition_date_column)
        for group, values in propositions.groupby(proposition_group_column, sort=False)
    }
    for group, index in out.groupby(group_column, sort=False).groups.items():
        history = proposition_groups.get(group)
        if history is None or history.empty:
            continue
        dates = history[proposition_date_column].to_numpy(dtype="datetime64[ns]")
        failures = history["failed"].to_numpy(dtype=float)
        area_shares = history["city_area_share"].to_numpy(dtype=float)
        for row_index in index:
            outcome_date = out.at[row_index, date_column]
            if pd.isna(outcome_date):
                continue
            right = np.searchsorted(dates, np.datetime64(outcome_date), side="left")
            if horizon_months is None:
                left = 0
            else:
                left_date = outcome_date - pd.DateOffset(months=horizon_months)
                left = np.searchsorted(dates, np.datetime64(left_date), side="left")
            window_failures = failures[left:right]
            window_area_shares = area_shares[left:right]
            if len(window_failures) > 0:
                out.at[row_index, weighted_column] = np.average(
                    window_failures, weights=window_area_shares
                )
            simple_mask = window_area_shares >= SIMPLE_RISK_MIN_CITY_AREA_SHARE
            if simple_mask.any():
                out.at[row_index, simple_column] = window_failures[simple_mask].mean()
    return out


OUT_DIR.mkdir(parents=True, exist_ok=True)


#%% Build the city and ISD exposure panels
parser = argparse.ArgumentParser()
parser.add_argument(
    "--area-overlap-threshold",
    type=float,
    default=0.80,
    help="Minimum city-area share covered by an ISD; use 0 for any positive overlap (default: 0.80).",
)
arguments = parser.parse_args()
overlap_threshold = arguments.area_overlap_threshold

if not 0 <= overlap_threshold <= 1:
    raise ValueError("The area-overlap threshold must be between 0 and 1.")

threshold_percent = round(overlap_threshold * 100)
threshold_tag = "any_overlap" if overlap_threshold == 0 else f"{threshold_percent}pct"

# Preserve the original 80-percent output names, which are inputs to the
# existing validation script. Alternative thresholds receive their own
# files so sensitivity analyses cannot overwrite the baseline.
if overlap_threshold == 0.80:
    exposure_events_file = "city_isd_failed_proposition_exposure_events.csv"
    city_month_file = "city_month_high_overlap_isd_failure_exposure.csv"
    city_props_file = "city_propositions_high_overlap_isd_failure_exposure.csv"
    website_city_year_file = "website_city_year_high_overlap_isd_failure_exposure.csv"
    coverage_file = "isd_failure_exposure_coverage.csv"
else:
    exposure_events_file = f"city_isd_failed_proposition_exposure_events_{threshold_tag}.csv"
    city_month_file = f"city_month_isd_failure_exposure_{threshold_tag}.csv"
    city_props_file = f"city_propositions_isd_failure_exposure_{threshold_tag}.csv"
    website_city_year_file = f"website_city_year_isd_failure_exposure_{threshold_tag}.csv"
    coverage_file = f"isd_failure_exposure_coverage_{threshold_tag}.csv"

#%% Step 1: Clean the proposition-level Texas election data
# Polars handles all regular tabular work. Pandas is used only for the
# repeated rolling date windows, where its DateOffset behavior defines the
# existing exposure measures.
elections = (
    pl.read_csv(ELECTION_FILE)
    .with_columns(
        pl.col("ElectionDate")
        .str.strptime(pl.Date, format="%m/%d/%Y", strict=False)
        .alias("election_date")
    )
    .filter(
        pl.col("election_date").is_between(
            pl.date(1995, 1, 1), pl.date(2024, 12, 31)
        )
    )
    .with_columns(
        pl.col("election_date").dt.year().alias("year"),
        pl.col("GovernmentName")
        .map_elements(canonical_name, return_dtype=pl.String)
        .alias("government_name_key"),
        (pl.col("Result") == "Defeated").cast(pl.Int64).alias("failed"),
        (
            pl.col("VotesFor").fill_null(0)
            + pl.col("VotesAgainst").fill_null(0)
        ).alias("vote_total"),
    )
    .with_columns(
        pl.when(pl.col("year") <= 2004)
        .then(pl.lit(2000))
        .when(pl.col("year") <= 2014)
        .then(pl.lit(2010))
        .otherwise(pl.lit(2020))
        .cast(pl.Int64)
        .alias("boundary_vintage"),
        pl.when(pl.col("vote_total") > 0)
        .then(
            (pl.col("VotesFor").fill_null(0) - pl.col("VotesAgainst").fill_null(0))
            / pl.col("vote_total")
        )
        .otherwise(None)
        .alias("vote_margin_signed"),
    )
    .select(
        pl.exclude(
            "election_date",
            "year",
            "boundary_vintage",
            "government_name_key",
            "failed",
            "vote_total",
            "vote_margin_signed",
        ),
        "election_date",
        "year",
        "boundary_vintage",
        "government_name_key",
        "failed",
        "vote_total",
        "vote_margin_signed",
    )
)

#%% Step 2: Attach the Census boundary matches created by Script 02
city_matches = pl.read_csv(OUT_DIR / "city_place_boundary_matches.csv")
city_keys = city_matches.select("seed_key", "city_name_key").unique(
    maintain_order=True
)

isd_matches = (
    pl.read_csv(OUT_DIR / "isd_election_boundary_matches.csv")
    .filter(pl.col("match_status") == "exact_normalized")
    .select(
        "boundary_vintage",
        "isd_name_key",
        pl.col("isd_name_key").alias("matched_isd_name_key"),
        pl.col("isd_geoid").cast(pl.Float64),
        "isd_name",
    )
    .unique(subset=["boundary_vintage", "isd_name_key"], maintain_order=True)
)

isd_props = elections.filter(pl.col("GovernmentType") == "ISD").join(
    isd_matches,
    left_on=["boundary_vintage", "government_name_key"],
    right_on=["boundary_vintage", "isd_name_key"],
    how="left",
    validate="m:1",
    maintain_order="left",
).rename(
    {"matched_isd_name_key": "isd_name_key"}
).with_columns(
    pl.when(pl.col("isd_geoid").is_not_null())
    .then(pl.lit("matched"))
    .otherwise(pl.lit("unmatched"))
    .alias("boundary_match")
)
isd_props.to_pandas().to_csv(
    OUT_DIR / "isd_propositions_with_boundary_match.csv", index=False
)

isd_failures = (
    isd_props.filter(
        (pl.col("failed") == 1) & pl.col("isd_geoid").is_not_null()
    )
    .select(
        "isd_geoid",
        "isd_name",
        "election_date",
        "boundary_vintage",
        "GovernmentName",
        "Amount",
        "Purpose",
    )
    .rename(
        {
            "election_date": "failure_date",
            "GovernmentName": "failure_issuer_name",
        }
    )
)
isd_failures.to_pandas().to_csv(
    OUT_DIR / "isd_failed_propositions_matched.csv", index=False
)

#%% Step 3: Map ISD propositions to every overlapping city
overlaps = pl.read_csv(
    OUT_DIR / "city_isd_overlap_area_all_vintages.csv"
).filter(pl.col("city_area_share") > 0)
overlap_keys = overlaps.select(
    "seed_key",
    pl.col("isd_geoid").cast(pl.Float64),
    "boundary_vintage",
    "city_area_share",
)
city_isd_failures = isd_failures.join(
    overlap_keys,
    on=["isd_geoid", "boundary_vintage"],
    how="inner",
    validate="m:m",
    maintain_order="left_right",
)
if overlap_threshold == 0:
    meets_overlap_threshold = pl.col("city_area_share") > 0
else:
    meets_overlap_threshold = pl.col("city_area_share") >= overlap_threshold
city_isd_failures = city_isd_failures.with_columns(
    meets_overlap_threshold.cast(pl.Int64).alias(
        "meets_area_overlap_threshold"
    )
)
city_isd_failures.to_pandas().to_csv(
    OUT_DIR / exposure_events_file, index=False
)

# Rejection risk is calculated from all prior ISD propositions, not just
# failures. A rate conditions failures on the number of locally relevant
# opportunities for voter rejection.
city_isd_propositions = isd_props.filter(
    pl.col("isd_geoid").is_not_null() & (pl.col("vote_total") > 0)
).select(
    "isd_geoid", "election_date", "boundary_vintage", "failed"
).join(
    overlap_keys,
    on=["isd_geoid", "boundary_vintage"],
    how="inner",
    validate="m:m",
    maintain_order="left_right",
)

# Convert only the frames used by the repeated pandas date-window helper.
elections = elections.to_pandas()
elections["election_date"] = pd.to_datetime(elections["election_date"])
city_matches = city_matches.to_pandas()
city_keys = city_keys.to_pandas()
isd_props = isd_props.to_pandas()
isd_props["election_date"] = pd.to_datetime(isd_props["election_date"])
isd_failures = isd_failures.to_pandas()
isd_failures["failure_date"] = pd.to_datetime(isd_failures["failure_date"])
city_isd_failures = city_isd_failures.to_pandas()
city_isd_failures["failure_date"] = pd.to_datetime(
    city_isd_failures["failure_date"]
)
city_isd_propositions = city_isd_propositions.to_pandas()
city_isd_propositions["election_date"] = pd.to_datetime(
    city_isd_propositions["election_date"]
)

#%% Step 4: Create city-month exposure for election and media models
city_month = pl.read_csv(
    CITY_MONTH_FILE,
    schema_overrides={"rp_entity_id": pl.Utf8},
).to_pandas()
city_month["seed_key"] = city_month["seed_issuer"].str.strip().str.lower()
city_month["month_date"] = pd.to_datetime(
    dict(year=city_month["year"], month=city_month["month"], day=1)
)
city_month = add_prior_failure_exposure(
    city_month,
    "seed_key",
    "month_date",
    city_isd_failures.loc[city_isd_failures["meets_area_overlap_threshold"].eq(1)],
    "seed_key",
    "failure_date",
    "city_area_share",
)
city_month = add_prior_rejection_risk(
    city_month,
    "seed_key",
    "month_date",
    city_isd_propositions,
    "seed_key",
    "election_date",
)
city_month.to_csv(OUT_DIR / city_month_file, index=False)

city_month_risk_columns = [
    "seed_key", "year", "month",
    f"prior_weighted_failure_rate_{REJECTION_RISK_HORIZON_MONTHS}m",
    f"prior_simple_failure_rate_{round(SIMPLE_RISK_MIN_CITY_AREA_SHARE * 100)}pct_"
    f"{REJECTION_RISK_HORIZON_MONTHS}m",
]
city_month[city_month_risk_columns].to_csv(
    OUT_DIR / "city_month_isd_rejection_risk.csv", index=False
)

#%% Step 5: Create city-proposition exposure for validation
# Conditional on a city proposition being offered, this panel tests whether
# it failed more often after a nearby ISD failure.
city_props = elections.loc[elections["GovernmentType"].eq("CITY")].merge(
    city_keys,
    left_on="government_name_key",
    right_on="city_name_key",
    how="left",
    validate="many_to_many",
)
city_fips = city_month[["seed_key", "fips"]].drop_duplicates("seed_key")
city_props = city_props.merge(city_fips, on="seed_key", how="left", validate="many_to_one")
city_props = add_prior_failure_exposure(
    city_props,
    "seed_key",
    "election_date",
    city_isd_failures.loc[city_isd_failures["meets_area_overlap_threshold"].eq(1)],
    "seed_key",
    "failure_date",
    "city_area_share",
)
city_props = add_prior_rejection_risk(
    city_props,
    "seed_key",
    "election_date",
    city_isd_propositions,
    "seed_key",
    "election_date",
)
city_props.to_csv(OUT_DIR / city_props_file, index=False)

#%% Step 6: Create city-year exposure for the website panel
# This deliberately starts with the full website city universe, rather
# than the RavenPack city-month panel.  In an election year, exposure is
# measured immediately before each recorded city election and takes the
# maximum across that year's election dates. In a non-election year, it is
# measured on December 1, matching the previous city-year aggregation.
website_city_year = (
    pl.read_csv(WEBSITE_PANEL_FILE, columns=["seed_issuer", "year"])
    .filter(pl.col("seed_issuer").is_not_null() & (pl.col("seed_issuer").str.strip_chars() != ""))
    .select([
        pl.col("seed_issuer").str.strip_chars().str.to_lowercase().alias("seed_key"),
        pl.col("year").cast(pl.Int64),
    ])
    .unique(maintain_order=True)
    .to_pandas()
)
city_election_dates = city_props[["seed_key", "year", "election_date"]].dropna().drop_duplicates()
website_outcome_dates = website_city_year.merge(
    city_election_dates,
    on=["seed_key", "year"],
    how="left",
    validate="one_to_many",
)
website_outcome_dates["exposure_date"] = website_outcome_dates["election_date"]
no_city_election = website_outcome_dates["exposure_date"].isna()
website_outcome_dates.loc[no_city_election, "exposure_date"] = pd.to_datetime(
    website_outcome_dates.loc[no_city_election, "year"].astype(str) + "-12-01"
)
website_outcome_dates = add_prior_failure_exposure(
    website_outcome_dates,
    "seed_key",
    "exposure_date",
    city_isd_failures.loc[city_isd_failures["meets_area_overlap_threshold"].eq(1)],
    "seed_key",
    "failure_date",
    "city_area_share",
)
website_outcome_dates = add_prior_rejection_risk(
    website_outcome_dates,
    "seed_key",
    "exposure_date",
    city_isd_propositions,
    "seed_key",
    "election_date",
)
exposure_columns = [
    column for column in website_outcome_dates.columns
    if column.startswith("prior_failure_")
]
rejection_risk_columns = [
    f"prior_weighted_failure_rate_{REJECTION_RISK_HORIZON_MONTHS}m",
    f"prior_simple_failure_rate_{round(SIMPLE_RISK_MIN_CITY_AREA_SHARE * 100)}pct_"
    f"{REJECTION_RISK_HORIZON_MONTHS}m",
]
website_city_year_exposure = website_outcome_dates.groupby(
    ["seed_key", "year"], as_index=False
)[exposure_columns + rejection_risk_columns].max()

# A zero is valid only when the place boundary needed to evaluate the
# relevant historical period is observed.  Retain one audit flag per
# horizon so the regression script can stop rather than silently coding
# unmatched cities as unexposed.
city_boundary_matches = city_matches.loc[
    city_matches["match_status"].eq("exact_normalized"),
    ["seed_key", "boundary_vintage"],
].drop_duplicates()
matched_vintages = {
    seed_key: set(values["boundary_vintage"])
    for seed_key, values in city_boundary_matches.groupby("seed_key", sort=False)
}

def has_observed_boundary_history(
    seed_key: str, outcome_date: pd.Timestamp, horizon: int
) -> int:
    first_date = max(
        pd.Timestamp("1995-01-01"), outcome_date - pd.DateOffset(months=horizon)
    )
    required_vintages = set(
        elections.loc[
            elections["election_date"].between(first_date, outcome_date, inclusive="left"),
            "boundary_vintage",
        ].unique()
    )
    return int(required_vintages.issubset(matched_vintages.get(seed_key, set())))

for horizon in HORIZONS:
    availability_column = f"spatial_exposure_observed_{horizon}m"
    website_outcome_dates[availability_column] = [
        has_observed_boundary_history(seed_key, outcome_date, horizon)
        for seed_key, outcome_date in zip(
            website_outcome_dates["seed_key"], website_outcome_dates["exposure_date"]
        )
    ]
    availability = website_outcome_dates.groupby(
        ["seed_key", "year"], as_index=False
    )[availability_column].min()
    website_city_year_exposure = website_city_year_exposure.merge(
        availability,
        on=["seed_key", "year"],
        how="left",
        validate="one_to_one",
    )
website_city_year_exposure.to_csv(OUT_DIR / website_city_year_file, index=False)
website_city_year_exposure.to_csv(
    OUT_DIR / "website_city_year_isd_rejection_risk.csv", index=False
)

# The 2017 outstanding-debt cross section uses all recorded local ISD
# elections through 2016, reflecting debt issuance accumulated before 2017.
city_2017_risk = city_keys[["seed_key"]].drop_duplicates().copy()
city_2017_risk["risk_date"] = pd.Timestamp("2017-01-01")
city_2017_risk = add_prior_rejection_risk(
    city_2017_risk,
    "seed_key",
    "risk_date",
    city_isd_propositions,
    "seed_key",
    "election_date",
)
city_2017_risk = add_prior_rejection_risk(
    city_2017_risk,
    "seed_key",
    "risk_date",
    city_isd_propositions,
    "seed_key",
    "election_date",
    horizon_months=None,
    column_suffix="all_history_pre2017",
)
city_2017_risk.to_csv(OUT_DIR / "city_2017_isd_rejection_risk.csv", index=False)

#%% Step 7: Create the same-ISD persistence validation sample
# Use only later propositions by the same matched ISD and exclude failures
# on the same election date.
isd_history = isd_props.loc[isd_props["isd_geoid"].notna()].copy()
isd_history = add_prior_failure_exposure(
    isd_history,
    "isd_geoid",
    "election_date",
    isd_history.loc[isd_history["failed"].eq(1), ["isd_geoid", "election_date"]],
    "isd_geoid",
    "election_date",
)
isd_history.to_csv(OUT_DIR / "isd_proposition_failure_persistence_sample.csv", index=False)

#%% Step 8: Save a coverage report before running regressions
coverage = pd.DataFrame([
    {
        "isd_propositions": len(isd_props),
        "isd_propositions_with_boundary_match": int(isd_props["isd_geoid"].notna().sum()),
        "failed_isd_propositions": int(isd_props["failed"].sum()),
        "failed_isd_propositions_matched": len(isd_failures),
        "city_propositions": len(city_props),
        "city_propositions_with_analysis_city": int(city_props["seed_key"].notna().sum()),
        "city_isd_failure_exposure_events": len(city_isd_failures),
        "city_isd_proposition_exposure_events": len(city_isd_propositions),
        "area_overlap_threshold": overlap_threshold,
        "area_overlap_failure_exposure_events": int(city_isd_failures["meets_area_overlap_threshold"].sum()),
        "website_cities": int(website_city_year_exposure["seed_key"].nunique()),
        "website_city_years": len(website_city_year_exposure),
        "website_city_years_with_observed_spatial_exposure_360m": int(
            website_city_year_exposure["spatial_exposure_observed_360m"].sum()
        ),
    }
])
coverage.to_csv(OUT_DIR / coverage_file, index=False)
print(coverage.to_string(index=False))
