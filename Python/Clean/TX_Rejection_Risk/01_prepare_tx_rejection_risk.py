"""Prepare analysis panels for the Texas ISD rejection-risk regressions."""

#%% Paths and shared helpers
from datetime import date
from pathlib import Path

import pandas as pd
import polars as pl


ROOT = Path(__file__).resolve().parents[4]
DATA = ROOT / "Data"
CLEAN = DATA / "Clean_Intermediate"
REGRESSION = CLEAN / "TX" / "Regression"
EXPOSURE = CLEAN / "TX" / "Election_Exposure"
OUTPUT = CLEAN / "TX" / "Rejection_Risk"


def read_csv(path: Path) -> pl.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Required input file does not exist: {path}")
    return pl.read_csv(path, infer_schema_length=None, try_parse_dates=True)


def key(column: str) -> pl.Expr:
    return pl.col(column).cast(pl.String).str.strip_chars().str.to_lowercase()


def parsed_date(column: str, date_format: str | None = None) -> pl.Expr:
    return pl.col(column).cast(pl.String).str.to_date(
        format=date_format, strict=False
    )


def add_risk_flags(
    dates: pl.DataFrame,
    events: pl.DataFrame,
    keys: list[str],
    *,
    all_history: bool,
) -> pl.DataFrame:
    matches = dates.join(events, on="seed_issuer", how="inner")
    ten_year = matches.filter(
        (pl.col("failure_date") < pl.col("risk_date"))
        & (pl.col("failure_date") >= pl.col("risk_date_10yr"))
    )
    ten_year = ten_year.group_by(keys).agg(
        pl.lit(1, dtype=pl.Int64).alias("failure_50pct_10yr")
    )

    flags = dates.select(keys).unique(maintain_order=True).join(
        ten_year, on=keys, how="left"
    )
    if all_history:
        history = (
            matches.filter(pl.col("failure_date") < pl.col("risk_date"))
            .group_by(keys)
            .agg(pl.lit(1, dtype=pl.Int64).alias("failure_50pct_all_history"))
        )
        flags = flags.join(history, on=keys, how="left")

    fill = ["failure_50pct_10yr"]
    if all_history:
        fill.append("failure_50pct_all_history")
    return flags.with_columns(pl.col(fill).fill_null(0).cast(pl.Int64))


def add_threshold_flags(
    dates: pl.DataFrame,
    events: pl.DataFrame,
    keys: list[str],
    *,
    all_history: bool,
) -> pl.DataFrame:
    threshold_matches = dates.join(events, on="seed_issuer", how="inner")
    prior = threshold_matches.filter(pl.col("failure_date") < pl.col("risk_date"))
    if not all_history:
        prior = prior.filter(
            pl.col("failure_date") >= pl.col("risk_date_10yr")
        )
    flags = prior.group_by([*keys, "threshold_key"]).agg(
        pl.lit(1, dtype=pl.Int64).alias("prior_failure")
    )
    names = {
        "any": "failure_any",
        "20pct": "failure_20pct",
        "25pct": "failure_25pct",
        "80pct": "failure_80pct",
    }
    suffix = "_all_history" if all_history else "_10yr"
    flags = (
        flags.pivot(
            on="threshold_key",
            index=keys,
            values="prior_failure",
            aggregate_function="max",
        )
        .rename(
            {
                column: f"{names[column]}{suffix}"
                for column in names
                if column in flags.get_column("threshold_key").unique().to_list()
            }
        )
    )
    output_columns = [f"{names[column]}{suffix}" for column in names]
    return (
        dates.select(keys)
        .unique(maintain_order=True)
        .join(flags, on=keys, how="left")
        .with_columns(pl.col(output_columns).fill_null(0).cast(pl.Int64))
    )


def normalize_city_year(frame: pl.DataFrame) -> pl.DataFrame:
    return frame.with_columns(
        key("seed_issuer").alias("seed_issuer"),
        pl.col("year").cast(pl.Int64),
    )


#%% Build every rejection-risk analysis panel
def main() -> None:
    #%% Step 1: Load the three outcome panels and spatial inputs
    website_city_year = normalize_city_year(
        read_csv(REGRESSION / "website_city_year_regression_ready.csv")
    )
    city_month = normalize_city_year(
        read_csv(REGRESSION / "city_month_media_regression_ready.csv")
    )
    debt_choice = normalize_city_year(
        read_csv(
            CLEAN
            / "Census COG Finance"
            / "processed"
            / "texas_2017_debt_choice_rejection_risk.csv"
        )
    ).with_columns(
        pl.col("census_population").log().alias("ln_census_population")
    )
    city_propositions = read_csv(
        EXPOSURE / "city_propositions_high_overlap_isd_failure_exposure.csv"
    ).with_columns(
        key("seed_key").alias("seed_key"),
        parsed_date("election_date").alias("election_date"),
    )
    isd_failures = read_csv(
        EXPOSURE / "isd_failed_propositions_matched.csv"
    ).with_columns(
        parsed_date("failure_date").alias("failure_date"),
        pl.col("isd_geoid").cast(pl.Int64, strict=False),
    )
    city_isd_overlaps = read_csv(
        EXPOSURE / "city_isd_overlap_area_all_vintages.csv"
    ).with_columns(
        key("seed_key").alias("seed_key"),
        pl.col("isd_geoid").cast(pl.Int64, strict=False),
    )
    city_boundary_matches = read_csv(
        EXPOSURE / "city_place_boundary_matches.csv"
    ).with_columns(key("seed_key").alias("seed_key"))

    #%% Step 2: Attach same-month controls to city propositions
    # This matches the timing convention in the original R preparation script.
    proposition_controls = (
        city_month.select(
            "seed_issuer",
            "year",
            "month",
            "ln_county_gdp_prior",
            "ln_county_pop_prior",
            "ln_county_pers_inc_prior",
        )
        .unique(maintain_order=True)
    )
    city_propositions = (
        city_propositions.with_columns(
            pl.col("election_date").dt.month().cast(pl.Int64).alias("election_month")
        )
        .join(
            proposition_controls,
            left_on=["seed_key", "year", "election_month"],
            right_on=["seed_issuer", "year", "month"],
            how="left",
        )
        .with_columns(pl.col("Amount").log1p().alias("ln_amount"))
    )

    #%% Step 3: Create a balanced city-year panel for the no-news outcomes
    # Keep cities with a successful boundary match in all three Census vintages.
    complete_spatial_cities = (
        city_boundary_matches.filter(
            (pl.col("match_status") == "exact_normalized")
            & pl.col("place_geoid").is_not_null()
        )
        .group_by("seed_key")
        .agg(pl.col("boundary_vintage").n_unique().alias("n_boundary_vintages"))
        .filter(pl.col("n_boundary_vintages") == 3)
        .select(pl.col("seed_key").alias("seed_issuer"))
    )
    annual_city_universe = (
        debt_choice.select(
            "seed_issuer",
            pl.col("seed_issuer_id").cast(pl.Float64),
            pl.col("fips").cast(pl.Int64).cast(pl.String).str.pad_start(5, "0"),
        )
        .unique(maintain_order=True)
        .join(complete_spatial_cities, on="seed_issuer", how="inner")
    )
    years = pl.DataFrame({"year": range(1996, 2024)}, schema={"year": pl.Int64})
    annual_election = annual_city_universe.join(years, how="cross")

    #%% Step 4: Create annual city election outcomes
    # Link city propositions to the balanced panel by mapped issuer and year.
    tx_elections = read_csv(DATA / "TX" / "20240510_TX_local_election.csv")
    seed_crosswalk = read_csv(
        DATA / "TX" / "241120_tx_uniquegovt_fuzzymatch_crosswalk.csv"
    )
    municipality_crosswalk = seed_crosswalk.select(
        key("muni_upper").alias("muni_key"),
        key("seed_issuer").alias("seed_issuer"),
    ).unique(maintain_order=True)
    election_outcomes = (
        tx_elections.with_columns(
            parsed_date("ElectionDate", "%m/%d/%Y").alias("election_date"),
            key("GovernmentName").alias("muni_key"),
        )
        .join(municipality_crosswalk, on="muni_key", how="inner")
        .filter(
            (pl.col("GovernmentType") == "CITY")
            & pl.col("Result").is_in(["Carried", "Defeated"])
            & pl.col("election_date").is_not_null()
        )
        .group_by(
            "seed_issuer",
            pl.col("election_date").dt.year().alias("year"),
        )
        .agg(pl.lit(1, dtype=pl.Int64).alias("city_bond_election_year"))
    )
    annual_election = (
        annual_election.join(
            election_outcomes, on=["seed_issuer", "year"], how="left"
        )
        .with_columns(
            pl.col("city_bond_election_year").fill_null(0).cast(pl.Int64)
        )
    )

    #%% Step 5: Attach beginning-of-year debt and lagged county controls
    outstanding_debt = read_csv(
        DATA
        / "Mergent"
        / "Outstanding Debt"
        / "260709_issuer_year_outstanding_debt.csv"
    )
    outstanding_debt = (
        outstanding_debt.filter(pl.col("state") == "TX")
        .select(
            pl.col("seed_issuer_id").cast(pl.Float64),
            (pl.col("year").cast(pl.Int64) + 1).alias("year"),
            pl.col("ln_1p_total_outstanding_debt").alias(
                "ln_1p_outstanding_debt_lag1"
            ),
        )
    )
    if outstanding_debt.select(
        pl.struct("seed_issuer_id", "year").n_unique()
    ).item() != outstanding_debt.height:
        raise ValueError("Outstanding-debt input has duplicate issuer-year keys.")
    annual_election = annual_election.join(
        outstanding_debt, on=["seed_issuer_id", "year"], how="left"
    )

    county_demos = read_csv(DATA / "BEA" / "countydemos_1999_2026.csv")
    county_demos = (
        county_demos.with_columns(
            pl.col("fips")
            .cast(pl.Int64, strict=False)
            .cast(pl.String)
            .str.pad_start(5, "0")
            .alias("fips"),
            (pl.col("year").cast(pl.Int64) + 1).alias("year"),
            pl.col("gdp").log().alias("ln_county_gdp_prior"),
            pl.col("pop").log().alias("ln_county_pop_prior"),
            pl.col("pers_inc").log().alias("ln_county_pers_inc_prior"),
        )
        .filter(
            pl.col("fips").str.starts_with("48")
            & pl.col("ln_county_pop_prior").is_finite()
            & pl.col("ln_county_pers_inc_prior").is_finite()
        )
        .select(
            "fips",
            "year",
            "ln_county_gdp_prior",
            "ln_county_pop_prior",
            "ln_county_pers_inc_prior",
        )
    )
    county_gdp_2001 = county_demos.filter(pl.col("year") == 2002).select(
        "fips", pl.col("ln_county_gdp_prior").alias("ln_county_gdp_2001_fallback")
    )
    annual_election = (
        annual_election.join(county_demos, on=["fips", "year"], how="left")
        .join(county_gdp_2001, on="fips", how="left")
        .with_columns(
            pl.when(
                (pl.col("year") == 2001)
                & pl.col("ln_county_gdp_prior").is_null()
            )
            .then(pl.col("ln_county_gdp_2001_fallback"))
            .otherwise(pl.col("ln_county_gdp_prior"))
            .alias("ln_county_gdp_prior")
        )
        .drop("ln_county_gdp_2001_fallback")
    )

    #%% Step 6: Recover annual issuance outcomes from the bond panel
    # Pandas only decodes the Stata file; all filtering and aggregation use Polars.
    city_issuance_pdf = pd.read_stata(
        DATA
        / "Mergent"
        / "Clean"
        / "260716_city_cusiplevel_statereq_purpose_yieldspread.dta",
        columns=["state", "seed_issuer", "year", "go_unlim", "go_lim", "rev"],
        convert_categoricals=False,
    )
    city_issuance = pl.from_pandas(city_issuance_pdf).with_columns(
        key("seed_issuer").alias("seed_issuer"),
        pl.col("year").cast(pl.Int64),
    )
    city_go_issuance = (
        city_issuance.filter(
            (pl.col("state") == "TX")
            & ((pl.col("go_unlim") == 1) | (pl.col("go_lim") == 1))
        )
        .group_by("seed_issuer", "year")
        .agg(pl.lit(1, dtype=pl.Int64).alias("go_bond_issuance_year"))
    )
    city_any_issuance = (
        city_issuance.filter(pl.col("state") == "TX")
        .group_by("seed_issuer", "year")
        .agg(pl.lit(1, dtype=pl.Int64).alias("any_debt_issuance_year"))
    )
    city_revenue_issuance = (
        city_issuance.filter(
            (pl.col("state") == "TX") & (pl.col("rev") == 1)
        )
        .group_by("seed_issuer", "year")
        .agg(pl.lit(1, dtype=pl.Int64).alias("revenue_bond_issuance_year"))
    )
    issuance_frames = (
        city_go_issuance,
        city_any_issuance,
        city_revenue_issuance,
    )
    for issuance in issuance_frames:
        annual_election = annual_election.join(
            issuance, on=["seed_issuer", "year"], how="left"
        )
    issuance_columns = [
        "go_bond_issuance_year",
        "any_debt_issuance_year",
        "revenue_bond_issuance_year",
    ]
    annual_election = annual_election.with_columns(
        pl.col(issuance_columns).fill_null(0).cast(pl.Int64)
    )

    #%% Step 7: Build the primary 50-percent-overlap rejection-risk indicators
    failure_events = (
        isd_failures.join(
            city_isd_overlaps.filter(pl.col("city_area_share") >= 0.50).select(
                "seed_key", "isd_geoid", "boundary_vintage"
            ),
            on=["isd_geoid", "boundary_vintage"],
            how="inner",
        )
        .select(
            key("seed_key").alias("seed_issuer"),
            "failure_date",
        )
        .unique(maintain_order=True)
    )
    city_month_dates = (
        city_month.select("seed_issuer", "year", "month")
        .unique(maintain_order=True)
        .with_columns(
            pl.date(pl.col("year"), pl.col("month"), pl.lit(1)).alias("risk_date"),
            pl.date(
                pl.col("year") - 10, pl.col("month"), pl.lit(1)
            ).alias("risk_date_10yr"),
        )
    )
    city_month_flags = add_risk_flags(
        city_month_dates,
        failure_events,
        ["seed_issuer", "year", "month"],
        all_history=True,
    )
    city_month = city_month.join(
        city_month_flags,
        on=["seed_issuer", "year", "month"],
        how="left",
    )

    #%% Step 8: Build the RavenPack-linked January panel
    # Keep the original sample used for the rate-measure specifications.
    annual_news_election_outcome = (
        city_month.filter(pl.col("year").is_between(1996, 2023, closed="both"))
        .group_by("seed_issuer", "year")
        .agg(
            (pl.col("has_bond_election") == 1)
            .any()
            .cast(pl.Int64)
            .alias("city_bond_election_year_outcome")
        )
    )
    annual_news_election = (
        city_month.filter(
            (pl.col("month") == 1)
            & pl.col("year").is_between(1996, 2023, closed="both")
        )
        .join(
            annual_news_election_outcome,
            on=["seed_issuer", "year"],
            how="left",
        )
        .rename({"city_bond_election_year_outcome": "city_bond_election_year"})
        .with_columns(pl.col("seed_issuer_id").cast(pl.Float64))
        .join(
            outstanding_debt,
            on=["seed_issuer_id", "year"],
            how="left",
        )
    )
    for issuance in issuance_frames:
        annual_news_election = annual_news_election.join(
            issuance, on=["seed_issuer", "year"], how="left"
        )
    annual_news_election = annual_news_election.with_columns(
        pl.col(issuance_columns).fill_null(0).cast(pl.Int64)
    )

    #%% Step 9: Add rejection risk to the balanced annual panel
    # The no-news annual panel uses January 1 outcome dates.
    annual_dates = annual_election.select("seed_issuer", "year").with_columns(
        pl.date(pl.col("year"), pl.lit(1), pl.lit(1)).alias("risk_date"),
        pl.date(pl.col("year") - 10, pl.lit(1), pl.lit(1)).alias(
            "risk_date_10yr"
        ),
    )
    annual_flags = add_risk_flags(
        annual_dates,
        failure_events,
        ["seed_issuer", "year"],
        all_history=True,
    )
    annual_election = annual_election.join(
        annual_flags, on=["seed_issuer", "year"], how="left"
    )

    #%% Step 10: Add rejection risk to the website panel
    # Use the city proposition date, or December 1 when there is no election.
    election_dates = city_propositions.filter(
        pl.col("seed_key").is_not_null()
    ).select(
        pl.col("seed_key").alias("seed_issuer"),
        "year",
        "election_date",
    ).unique(maintain_order=True)
    website_dates = (
        website_city_year.select("seed_issuer", "year")
        .unique(maintain_order=True)
        .join(election_dates, on=["seed_issuer", "year"], how="left")
        .with_columns(
            pl.coalesce(
                "election_date",
                pl.date(pl.col("year"), pl.lit(12), pl.lit(1)),
            ).alias("risk_date")
        )
        .with_columns(
            pl.col("risk_date").dt.offset_by("-10y").alias("risk_date_10yr")
        )
    )
    website_flags = add_risk_flags(
        website_dates,
        failure_events,
        ["seed_issuer", "year", "risk_date"],
        all_history=True,
    )
    website_flags = website_flags.group_by("seed_issuer", "year").agg(
        pl.col("failure_50pct_10yr").max(),
        pl.col("failure_50pct_all_history").max(),
    )
    website_city_year = website_city_year.join(
        website_flags, on=["seed_issuer", "year"], how="left"
    )

    #%% Step 11: Build indicators for alternative city-area overlap cutoffs
    thresholds = pl.DataFrame(
        {
            "threshold_key": ["any", "20pct", "25pct", "80pct"],
            "minimum_area_share": [0.0, 0.20, 0.25, 0.80],
        }
    )
    threshold_events = (
        isd_failures.join(
            city_isd_overlaps.select(
                "seed_key",
                "isd_geoid",
                "boundary_vintage",
                "city_area_share",
            ),
            on=["isd_geoid", "boundary_vintage"],
            how="inner",
        )
        .join(thresholds, how="cross")
        .filter(pl.col("city_area_share") >= pl.col("minimum_area_share"))
        .select(
            key("seed_key").alias("seed_issuer"),
            "failure_date",
            "threshold_key",
        )
        .unique(maintain_order=True)
    )

    annual_threshold_10yr = add_threshold_flags(
        annual_dates,
        threshold_events,
        ["seed_issuer", "year"],
        all_history=False,
    )
    annual_threshold_history = add_threshold_flags(
        annual_dates,
        threshold_events,
        ["seed_issuer", "year"],
        all_history=True,
    )
    annual_election = annual_election.join(
        annual_threshold_10yr, on=["seed_issuer", "year"], how="left"
    ).join(annual_threshold_history, on=["seed_issuer", "year"], how="left")

    month_threshold_10yr = add_threshold_flags(
        city_month_dates,
        threshold_events,
        ["seed_issuer", "year", "month"],
        all_history=False,
    )
    month_threshold_history = add_threshold_flags(
        city_month_dates,
        threshold_events,
        ["seed_issuer", "year", "month"],
        all_history=True,
    )
    city_month = city_month.join(
        month_threshold_10yr,
        on=["seed_issuer", "year", "month"],
        how="left",
    ).join(
        month_threshold_history,
        on=["seed_issuer", "year", "month"],
        how="left",
    )

    website_threshold_10yr = add_threshold_flags(
        website_dates,
        threshold_events,
        ["seed_issuer", "year", "risk_date"],
        all_history=False,
    )
    website_threshold_history = add_threshold_flags(
        website_dates,
        threshold_events,
        ["seed_issuer", "year", "risk_date"],
        all_history=True,
    )
    website_thresholds = website_threshold_10yr.join(
        website_threshold_history,
        on=["seed_issuer", "year", "risk_date"],
        how="left",
        suffix="_history",
    )
    website_thresholds = website_thresholds.group_by(
        "seed_issuer", "year"
    ).agg(pl.exclude("risk_date", "seed_issuer", "year").max())
    website_city_year = website_city_year.join(
        website_thresholds, on=["seed_issuer", "year"], how="left"
    )

    # Preserve the established CSV column order. Polars pivot columns otherwise
    # follow the order in which threshold values happen to appear in each panel.
    threshold_columns = [
        f"failure_{threshold}_{window}"
        for window in ("10yr", "all_history")
        for threshold in ("any", "20pct", "25pct", "80pct")
    ]
    annual_threshold_order = [
        "failure_25pct_10yr",
        "failure_20pct_10yr",
        "failure_80pct_10yr",
        "failure_any_10yr",
        "failure_80pct_all_history",
        "failure_20pct_all_history",
        "failure_25pct_all_history",
        "failure_any_all_history",
    ]
    month_threshold_order = [
        "failure_25pct_10yr",
        "failure_any_10yr",
        "failure_80pct_10yr",
        "failure_20pct_10yr",
        "failure_any_all_history",
        "failure_25pct_all_history",
        "failure_80pct_all_history",
        "failure_20pct_all_history",
    ]
    website_threshold_order = [
        "failure_20pct_10yr",
        "failure_80pct_10yr",
        "failure_25pct_10yr",
        "failure_any_10yr",
        "failure_80pct_all_history",
        "failure_any_all_history",
        "failure_25pct_all_history",
        "failure_20pct_all_history",
    ]
    annual_election = annual_election.select(
        pl.exclude(threshold_columns), *annual_threshold_order
    ).sort("seed_issuer", "year")
    city_month = city_month.select(
        pl.exclude(threshold_columns), *month_threshold_order
    )
    website_city_year = website_city_year.select(
        pl.exclude(threshold_columns), *website_threshold_order
    )

    #%% Step 12: Add pre-2017 risk to the debt-choice and issuance samples
    debt_choice_dates = debt_choice.select("seed_issuer").unique(
        maintain_order=True
    ).with_columns(
        pl.lit(date(2017, 1, 1)).alias("risk_date"),
        pl.lit(date(2007, 1, 1)).alias("risk_date_10yr"),
    )
    debt_choice_flags = add_risk_flags(
        debt_choice_dates,
        failure_events,
        ["seed_issuer"],
        all_history=True,
    )
    debt_choice = debt_choice.join(
        debt_choice_flags, on="seed_issuer", how="left"
    )

    issuer_aggregate_pdf = pd.read_stata(
        DATA / "Mergent" / "Clean" / "260716_city_issuerlevel_yieldspread.dta",
        convert_categoricals=False,
    )
    issuer_aggregate = pl.from_pandas(issuer_aggregate_pdf).with_columns(
        key("seed_issuer").alias("seed_issuer")
    )
    issuer_nc_spreads = read_csv(
        CLEAN / "Mergent" / "Clean" / "issuer_level_nc_yield_spreads.csv"
    ).with_columns(key("seed_issuer").alias("seed_issuer"))
    issuer_aggregate = (
        issuer_aggregate.join(
            issuer_nc_spreads.select("state", "seed_issuer", "issuer_spread_nc"),
            on=["state", "seed_issuer"],
            how="left",
        )
        .with_columns(pl.col("issuer_spread_nc").alias("issuer_spread"))
        .filter((pl.col("state") == "TX") & (pl.col("insample") == 1))
        .join(
            debt_choice_flags.select(
                "seed_issuer",
                "failure_50pct_10yr",
                "failure_50pct_all_history",
            ),
            on="seed_issuer",
            how="left",
        )
        .with_columns(
            pl.col("failure_50pct_10yr").fill_null(0),
            pl.col("failure_50pct_all_history").fill_null(0),
        )
    )

    #%% Step 13: Identify the original media-election regression universe
    election_media = read_csv(
        REGRESSION / "election_media_regression_ready.csv"
    )
    media_issuers = election_media.filter(
        pl.col("unique_sources_12m_prior") > 0
    ).select(key("seed_issuer").alias("seed_issuer")).unique(
        maintain_order=True
    )
    media_panel_indicator = city_month.join(
        media_issuers, on="seed_issuer", how="inner"
    ).filter(
        (pl.col("year") >= 2003)
        & pl.col("fips").is_not_null()
        & pl.col("ln_county_gdp_prior").is_not_null()
        & pl.col("ln_county_pop_prior").is_not_null()
        & pl.col("ln_county_pers_inc_prior").is_not_null()
    )

    #%% Step 14: Write all regression inputs
    outputs = {
        "website_city_year_analysis.csv": website_city_year,
        "city_month_analysis.csv": city_month,
        "annual_election_analysis.csv": annual_election,
        "annual_news_election_analysis.csv": annual_news_election,
        "city_propositions_analysis.csv": city_propositions,
        "debt_choice_analysis.csv": debt_choice,
        "full_issuance_debt_choice_analysis.csv": issuer_aggregate,
        "media_panel_indicator_analysis.csv": media_panel_indicator,
    }
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for filename, frame in outputs.items():
        frame.write_csv(OUTPUT / filename, float_precision=17)
        print(f"Wrote {filename}: {frame.height:,} rows, {frame.width:,} columns.")


if __name__ == "__main__":
    main()
