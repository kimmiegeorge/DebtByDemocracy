"""Build regression-ready Texas inputs used by 03_election_outcomes.R.

This script does not overwrite the existing intermediate files. It creates
four files in Data/Clean_Intermediate/TX/Regression that have a common county
FIPS assignment and exact prior-year county controls. The only exception is a
transparent 2001 county-GDP fallback because the BEA county-GDP series begins
in 2001 and contains no 2000 or earlier values.
The election-media output also includes coverage indicators, article and
financial logs, county-year identifiers, and absolute vote margins. All
elections remain in the export; analysis sample restrictions remain in R.
"""

from pathlib import Path

import polars as pl


# %% Step 1: Set paths
ROOT = Path(__file__).resolve().parents[4]
DATA = ROOT / "Data"
CLEAN = DATA / "Clean_Intermediate"
OUTPUT = CLEAN / "TX" / "Regression"

CITY_MONTH_INPUT = CLEAN / "TX" / "City_Month_Elections_News_WithFailed.csv"
ELECTION_MEDIA_INPUT = CLEAN / "TX" / "News" / "Election_Level_With_News_WithFailed.csv"
WEBSITE_YEAR_INPUT = CLEAN / "Websites" / "Texas" / "time_series_website_data.csv"
WEBSITE_ELECTION_INPUT = CLEAN / "Websites" / "Texas" / "election_level_website_data.csv"
COUNTY_DEMOS_INPUT = DATA / "BEA" / "countydemos_1999_2026.csv"
ISSUANCE_INPUT = DATA / "Mergent" / "Clean" / "260716_city_cusiplevel_statereq_purpose_yieldspread.dta"

CITY_MONTH_OUTPUT = OUTPUT / "city_month_media_regression_ready.csv"
ELECTION_MEDIA_OUTPUT = OUTPUT / "election_media_regression_ready.csv"
WEBSITE_YEAR_OUTPUT = OUTPUT / "website_city_year_regression_ready.csv"
WEBSITE_ELECTION_OUTPUT = OUTPUT / "website_election_regression_ready.csv"
DIAGNOSTICS_OUTPUT = OUTPUT / "county_control_diagnostics.csv"

CONTROL_SOURCE_COLUMNS = {
    "pop": "ln_county_pop_prior",
    "gdp": "ln_county_gdp_prior",
    "pers_inc": "ln_county_pers_inc_prior",
    "percap_inc": "ln_county_percap_inc_prior",
    "employment": "ln_county_employment_prior",
}
CONTROL_OUTPUT_COLUMNS = list(CONTROL_SOURCE_COLUMNS.values())


# %% Step 2: Define small helpers
def check_inputs() -> None:
    """Stop early when an upstream input is missing."""
    for path in [
        CITY_MONTH_INPUT,
        ELECTION_MEDIA_INPUT,
        WEBSITE_YEAR_INPUT,
        WEBSITE_ELECTION_INPUT,
        COUNTY_DEMOS_INPUT,
        ISSUANCE_INPUT,
    ]:
        if not path.exists():
            raise FileNotFoundError(f"Missing input: {path}")


def normalize_fips(column: str) -> pl.Expr:
    """Return a five-character county FIPS expression."""
    return (
        pl.col(column)
        .cast(pl.Int64, strict=False)
        .cast(pl.String)
        .str.zfill(5)
    )


def issuer_key(column: str = "seed_issuer") -> pl.Expr:
    """Create a stable issuer-name key for joins across source files."""
    return pl.col(column).cast(pl.String).str.strip_chars().str.to_lowercase()


def load_county_controls() -> tuple[pl.DataFrame, pl.DataFrame]:
    """Load Texas county controls and a county-name-to-FIPS crosswalk."""
    county_demos = pl.read_csv(COUNTY_DEMOS_INPUT)
    county_demos = county_demos.with_columns(
        normalize_fips("fips").alias("fips"),
        pl.col("year").cast(pl.Int64),
    ).filter(pl.col("fips").str.starts_with("48"))

    county_controls = county_demos.select(
        "fips",
        "year",
        *[
            pl.when(pl.col(source_column) > 0)
            .then(pl.col(source_column).log())
            .otherwise(None)
            .alias(output_column)
            for source_column, output_column in CONTROL_SOURCE_COLUMNS.items()
        ],
    )

    county_name_fips = (
        county_demos.select(
            pl.col("geoname").str.replace(", TX$", "").alias("County"),
            "fips",
        )
        .drop_nulls()
        .unique(subset="County", keep="first")
    )

    return county_controls, county_name_fips


def build_issuer_fips(city_month: pl.DataFrame) -> pl.DataFrame:
    """Use the city-month panel's stable city-to-county assignment."""
    return (
        city_month.select(
            issuer_key().alias("seed_issuer_key"),
            normalize_fips("fips").alias("fips_from_issuer"),
        )
        .drop_nulls()
        .unique(subset="seed_issuer_key", keep="first")
    )


def add_fips(
    data: pl.DataFrame,
    issuer_fips: pl.DataFrame,
    county_name_fips: pl.DataFrame | None = None,
) -> pl.DataFrame:
    """Keep an existing FIPS when available, then use issuer and county maps."""
    result = data.with_columns(issuer_key().alias("seed_issuer_key"))

    if "fips" in result.columns:
        result = result.with_columns(normalize_fips("fips").alias("fips"))
    else:
        result = result.with_columns(pl.lit(None, dtype=pl.String).alias("fips"))

    result = result.join(issuer_fips, on="seed_issuer_key", how="left")
    result = result.with_columns(
        pl.coalesce(["fips", "fips_from_issuer"]).alias("fips")
    ).drop("fips_from_issuer")

    if county_name_fips is not None and "County" in result.columns:
        result = result.join(
            county_name_fips.rename({"fips": "fips_from_county"}),
            on="County",
            how="left",
        )
        result = result.with_columns(
            pl.coalesce(["fips", "fips_from_county"]).alias("fips")
        ).drop("fips_from_county")

    return result


def add_prior_year_county_controls(
    data: pl.DataFrame,
    county_controls: pl.DataFrame,
) -> pl.DataFrame:
    """Attach prior-year controls with a 2001 same-year GDP fallback."""
    old_control_columns = [
        column
        for column in data.columns
        if column in CONTROL_OUTPUT_COLUMNS
        or column in CONTROL_SOURCE_COLUMNS
        or column.startswith("county_control_")
    ]
    result = data.drop(old_control_columns, strict=False)
    result = result.with_columns((pl.col("year").cast(pl.Int64) - 1).alias("county_control_year"))
    result = result.join(
        county_controls,
        left_on=["fips", "county_control_year"],
        right_on=["fips", "year"],
        how="left",
    )

    # County GDP begins in 2001. For observations in 2001, the requested
    # 2000 GDP does not exist, so use the earliest available value (2001).
    # This exception is limited to GDP and is flagged in the diagnostics.
    gdp_2001 = county_controls.filter(pl.col("year") == 2001).select(
        "fips",
        pl.col("ln_county_gdp_prior").alias("ln_county_gdp_2001_fallback"),
    )
    result = result.join(gdp_2001, on="fips", how="left")
    result = result.with_columns(
        (
            (pl.col("year") == 2001)
            & pl.col("ln_county_gdp_prior").is_null()
            & pl.col("ln_county_gdp_2001_fallback").is_not_null()
        ).alias("county_controls_imputed"),
        pl.when(
            (pl.col("year") == 2001)
            & pl.col("ln_county_gdp_prior").is_null()
            & pl.col("ln_county_gdp_2001_fallback").is_not_null()
        )
        .then(pl.col("ln_county_gdp_2001_fallback"))
        .otherwise(pl.col("ln_county_gdp_prior"))
        .alias("ln_county_gdp_prior"),
    )
    result = result.with_columns(
        pl.when(pl.col("county_controls_imputed"))
        .then(pl.lit(1))
        .otherwise(pl.lit(0))
        .cast(pl.Int8)
        .alias("county_control_max_distance"),
    )
    return result.drop("ln_county_gdp_2001_fallback")
    return result


def load_issuance_indicators() -> tuple[pl.DataFrame, pl.DataFrame, pl.DataFrame]:
    """Read Texas Mergent issuance dates and issuer FIPS mappings once."""
    # Polars does not read Stata files directly. Pandas is used only for this
    # input format conversion; all transformations below are Polars.
    import pandas as pd

    issues = pl.from_pandas(
        pd.read_stata(
            ISSUANCE_INPUT,
            columns=["state", "seed_issuer", "year", "month", "fips"],
        )
    )
    issues = issues.filter(pl.col("state") == "TX").with_columns(
        issuer_key().alias("seed_issuer_key"),
        pl.col("year").cast(pl.Int64),
        pl.col("month").cast(pl.Int64),
    )

    issue_month = issues.select("seed_issuer_key", "year", "month").unique()
    issue_year = issues.select("seed_issuer_key", "year").unique()
    issuer_fips = (
        issues.select(
            "seed_issuer_key",
            normalize_fips("fips").alias("fips_from_issuer"),
        )
        .drop_nulls()
        .unique(subset="seed_issuer_key", keep="first")
    )
    return issue_month, issue_year, issuer_fips


def add_city_month_windows(
    city_month: pl.DataFrame,
    issue_month: pl.DataFrame,
) -> pl.DataFrame:
    """Create the media regression's coverage, election, and issuance windows."""
    result = city_month.join(
        issue_month.with_columns(pl.lit(1).alias("issuance_this_month")),
        on=["seed_issuer_key", "year", "month"],
        how="left",
    ).with_columns(
        pl.col("issuance_this_month").fill_null(0).cast(pl.Int8),
        pl.col("has_bond_election").fill_null(0).cast(pl.Int8),
        (pl.col("rp_article_count") > 0).cast(pl.Int8).alias("covered"),
        (pl.col("year") * 12 + pl.col("month")).cast(pl.Int32).alias("year_month_id"),
    ).sort(["seed_issuer_key", "year", "month"])

    election_values = [
        pl.col("has_bond_election").shift(-months_ahead).over("seed_issuer_key").fill_null(0)
        for months_ahead in range(4)
    ]
    issuance_values = [
        pl.col("issuance_this_month").shift(-months_ahead).over("seed_issuer_key").fill_null(0)
        for months_ahead in range(4)
    ]

    return result.with_columns(
        pl.max_horizontal(election_values).cast(pl.Int8).alias("election_window"),
        pl.max_horizontal(issuance_values).cast(pl.Int8).alias("issuance_window"),
    )


def write_output(data: pl.DataFrame, path: Path) -> None:
    """Write a CSV and print a compact audit line."""
    data.write_csv(path)
    print(f"Wrote {path.name}: {data.height:,} rows, {data.width} columns")


def read_intermediate_csv(path: Path) -> pl.DataFrame:
    """Read mixed-type intermediate CSVs without guessing IDs as numbers."""
    return pl.read_csv(path, infer_schema_length=None)


# %% Step 3: Load the existing intermediate inputs and shared crosswalks
check_inputs()
OUTPUT.mkdir(parents=True, exist_ok=True)

city_month_source = read_intermediate_csv(CITY_MONTH_INPUT)
election_media_source = read_intermediate_csv(ELECTION_MEDIA_INPUT)
website_year_source = read_intermediate_csv(WEBSITE_YEAR_INPUT)
website_election_source = read_intermediate_csv(WEBSITE_ELECTION_INPUT)

county_controls, county_name_fips = load_county_controls()
city_month_issuer_fips = build_issuer_fips(city_month_source)
website_issuer_fips = build_issuer_fips(website_election_source)
issue_month, issue_year, mergent_issuer_fips = load_issuance_indicators()
issuer_fips = pl.concat(
    [city_month_issuer_fips, website_issuer_fips, mergent_issuer_fips]
).unique(subset="seed_issuer_key", keep="first")


# %% Step 4: Build the city-month media regression panel
city_month = add_fips(city_month_source, issuer_fips)
city_month = add_prior_year_county_controls(city_month, county_controls)
city_month = add_city_month_windows(city_month, issue_month)
write_output(city_month, CITY_MONTH_OUTPUT)


# %% Step 5: Build the election-level media regression panel
election_media = add_fips(election_media_source, issuer_fips, county_name_fips)
election_media = add_prior_year_county_controls(election_media, county_controls)
# Create election-level analysis variables before export. Keep all elections
# here; R retains the positive pre-election source-diversity sample restriction.
election_media = election_media.with_columns(
    pl.col("articles_election_month").log1p().alias("ln_election_month_articles"),
    pl.col("articles_2m_before_to_election").log1p().alias("ln_2m_election_articles"),
    pl.col("articles_6m_before_to_election").log1p().alias("ln_6m_election_articles"),
    (pl.col("articles_3m_before_to_election") > 0).cast(pl.Int32).alias("coverage_3"),
    (pl.col("articles_6m_before_to_election") > 0).cast(pl.Int32).alias("coverage_6"),
    pl.col("Amount").log().alias("ln_Amount"),
    pl.col("unique_sources_12m_prior").log().alias("log_sources"),
    pl.col("votestotal").log().alias("log_votes"),
    pl.concat_str(
        pl.col("County").fill_null("NA"),
        pl.col("year").cast(pl.Int64).cast(pl.String).fill_null("NA"),
        separator="",
    ).alias("county_year"),
    pl.col("vote_margin").abs().alias("abs_vote_margin"),
)
write_output(election_media, ELECTION_MEDIA_OUTPUT)


# %% Step 6: Build the website city-year regression panel
website_year = add_fips(website_year_source, issuer_fips)
website_year = add_prior_year_county_controls(website_year, county_controls)
website_year = website_year.join(
    issue_year.with_columns(pl.lit(1).alias("issuance_year")),
    on=["seed_issuer_key", "year"],
    how="left",
).with_columns(pl.col("issuance_year").fill_null(0).cast(pl.Int8))
write_output(website_year, WEBSITE_YEAR_OUTPUT)


# %% Step 7: Build the website-election regression panel
website_election = add_fips(website_election_source, issuer_fips, county_name_fips)
website_election = add_prior_year_county_controls(website_election, county_controls)
write_output(website_election, WEBSITE_ELECTION_OUTPUT)


# %% Step 8: Save transparent control-coverage diagnostics
diagnostics = pl.concat(
    [
        data.select(
            pl.lit(name).alias("panel"),
            pl.len().alias("observations"),
            pl.col("fips").is_null().sum().alias("missing_fips"),
            pl.col("county_controls_imputed").sum().alias("county_control_replacements"),
            pl.col("county_control_max_distance").max().alias("maximum_year_distance"),
            pl.any_horizontal([pl.col(column).is_null() for column in CONTROL_OUTPUT_COLUMNS])
            .sum()
            .alias("rows_still_missing_any_control"),
        )
        for name, data in [
            ("city_month_media", city_month),
            ("election_media", election_media),
            ("website_city_year", website_year),
            ("website_election", website_election),
        ]
    ]
)
diagnostics.write_csv(DIAGNOSTICS_OUTPUT)
print(diagnostics)
