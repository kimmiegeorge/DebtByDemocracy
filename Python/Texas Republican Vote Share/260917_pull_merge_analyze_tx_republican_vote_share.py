"""
Pull county presidential returns, construct a strictly lagged Republican
two-party vote share, merge it to Texas city bond elections, and test whether
the share predicts bond proposition rejection.

Sources
-------
2000-2024: MIT Election Data and Science Lab, Harvard Dataverse
            DOI 10.7910/DVN/VOQCHQ
1992-1996: Texas Secretary of State historical county result pages

The share assigned to a bond election always comes from the most recent
presidential election strictly before the bond election year. Multi-county
bond geographies are aggregated using the component counties' raw Republican
and Democratic vote totals before calculating the share.
"""

# %% Setup

from __future__ import annotations

import json
import os
import re
import time
from io import BytesIO
from pathlib import Path

SCRIPT_PROJECT_DIR = Path(__file__).resolve().parents[3]
MATPLOTLIB_CACHE_DIR = SCRIPT_PROJECT_DIR / "tmp" / "matplotlib"
FONT_CACHE_DIR = SCRIPT_PROJECT_DIR / "tmp" / "fontconfig"
MATPLOTLIB_CACHE_DIR.mkdir(parents=True, exist_ok=True)
FONT_CACHE_DIR.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("MPLCONFIGDIR", str(MATPLOTLIB_CACHE_DIR))
os.environ.setdefault("XDG_CACHE_HOME", str(FONT_CACHE_DIR))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
import polars as pl
import requests
import statsmodels.formula.api as smf
from bs4 import BeautifulSoup


OUTPUT_DATE = "260917"

PROJECT_DIR = SCRIPT_PROJECT_DIR
DATA_DIR = PROJECT_DIR / "Data"
RAW_DIR = DATA_DIR / "TX" / "Republican Vote Share" / "raw"
OUTPUT_DATA_DIR = DATA_DIR / "TX" / "Republican Vote Share"
RESULTS_DIR = PROJECT_DIR / "Results" / "TX Republican Vote Share"

ELECTION_FILE = (
    DATA_DIR
    / "Clean_Intermediate"
    / "TX"
    / "News"
    / "Election_Level_With_News_WithFailed.csv"
)

DATAVERSE_METADATA_URL = (
    "https://dataverse.harvard.edu/api/datasets/:persistentId/"
    "?persistentId=doi:10.7910/DVN/VOQCHQ"
)
DATAVERSE_FILE_NAME = "countypres_2000-2024.tab"
MIT_MIRROR_DOWNLOAD_URL = (
    "https://raw.githubusercontent.com/dlb8685/us_county_election_results/"
    "main/data/raw_data/mit_election_labs__countypres_2000-2024.csv"
)
TX_SOS_BASE_URL = "https://elections.sos.state.tx.us"
TX_SOS_ELECTION_IDS = {1992: 5, 1996: 56}

RAW_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DATA_DIR.mkdir(parents=True, exist_ok=True)
RESULTS_DIR.mkdir(parents=True, exist_ok=True)


# %% Helpers for county names and HTTP requests

def normalize_county_name(value: str) -> str:
    """Create a stable county-name key across project and source files."""

    value = value.upper().replace(" COUNTY", "")
    return re.sub(r"[^A-Z0-9]", "", value)


def component_counties(value: str) -> list[str]:
    """Split project multi-county labels such as Dallas-Collin."""

    return [item.strip() for item in re.split(r"[-,]", value) if item.strip()]


session = requests.Session()
session.headers.update(
    {
        "User-Agent": (
            "Voting-on-Bonds academic replication script; "
            "county presidential returns"
        )
    }
)


def get_url(url: str, timeout: int = 90) -> requests.Response:
    """Request a URL with short retries and a clear terminal failure."""

    last_error = None
    for attempt in range(1, 4):
        try:
            response = session.get(url, timeout=timeout)
            response.raise_for_status()
            return response
        except requests.RequestException as error:
            last_error = error
            if attempt < 3:
                time.sleep(attempt)

    raise RuntimeError(f"Failed to download {url}") from last_error


# %% Load the Texas city bond election sample

print(f"Loading Texas bond elections from {ELECTION_FILE}")
bond_elections = pl.read_csv(ELECTION_FILE, try_parse_dates=False)
bond_elections = bond_elections.with_columns(
    pl.col("ElectionDate").str.strptime(pl.Date, format="%m/%d/%Y").alias("election_date"),
    pl.col("year").cast(pl.Int64),
    pl.col("failed").cast(pl.Int64),
    pl.col("passed").cast(pl.Int64),
)

county_labels = bond_elections.get_column("County").unique().sort().to_list()
county_bridge_rows = []
for county_label in county_labels:
    for county_name in component_counties(county_label):
        county_bridge_rows.append(
            {
                "County": county_label,
                "county_name": county_name,
                "county_key": normalize_county_name(county_name),
            }
        )

county_bridge = pl.DataFrame(county_bridge_rows)
required_county_keys = set(county_bridge.get_column("county_key").to_list())


# %% Pull MIT Election Lab county returns for 2000-2024

print("Resolving the current MIT Election Lab Dataverse file...")
mit_raw_path = RAW_DIR / "countypres_2000-2024.csv"
metadata_path = RAW_DIR / "countypres_2000-2024_metadata.json"
if mit_raw_path.exists() and metadata_path.exists():
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
else:
    metadata_response = get_url(DATAVERSE_METADATA_URL)
    metadata = metadata_response.json()

dataverse_files = metadata["data"]["latestVersion"]["files"]
matching_files = [
    item for item in dataverse_files if item.get("label") == DATAVERSE_FILE_NAME
]
if len(matching_files) != 1:
    raise RuntimeError(
        f"Expected one Dataverse file named {DATAVERSE_FILE_NAME}; "
        f"found {len(matching_files)}"
    )

dataverse_file_id = matching_files[0]["dataFile"]["id"]

if mit_raw_path.exists():
    print(f"Using cached MIT returns at {mit_raw_path}")
    mit_content = mit_raw_path.read_bytes()
else:
    print(
        f"Downloading the public GitHub mirror of MIT returns file id "
        f"{dataverse_file_id}..."
    )
    # Harvard Dataverse requires an interactive guestbook response for this
    # file. The mirror preserves the original MIT CSV and documents the DOI.
    mit_response = get_url(MIT_MIRROR_DOWNLOAD_URL, timeout=180)
    mit_content = mit_response.content
    mit_raw_path.write_bytes(mit_content)
metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")

mit_returns = pl.read_csv(BytesIO(mit_content), infer_schema_length=10000)
mit_returns = (
    mit_returns
    .filter(
        (pl.col("state_po") == "TX")
        & pl.col("party").is_in(["DEMOCRAT", "REPUBLICAN"])
    )
    .with_columns(
        pl.col("year").cast(pl.Int64),
        pl.col("candidatevotes").cast(pl.Int64),
        pl.col("county_name")
        .map_elements(normalize_county_name, return_dtype=pl.String)
        .alias("county_key"),
    )
    .group_by(["year", "county_key"])
    .agg(
        pl.col("candidatevotes")
        .filter(pl.col("party") == "REPUBLICAN")
        .sum()
        .alias("republican_votes"),
        pl.col("candidatevotes")
        .filter(pl.col("party") == "DEMOCRAT")
        .sum()
        .alias("democratic_votes"),
        pl.col("county_fips").drop_nulls().first().alias("county_fips"),
    )
    .filter(pl.col("county_key").is_in(required_county_keys))
    .with_columns(pl.lit("MIT Election Data and Science Lab").alias("source"))
)


# %% Pull official Texas county returns for 1992 and 1996

tx_sos_raw_path = RAW_DIR / "tx_sos_presidential_county_1992_1996.csv"
if tx_sos_raw_path.exists():
    tx_sos_returns = pl.read_csv(tx_sos_raw_path)
    cached_pairs = set(
        tx_sos_returns.select(["year", "county_key"]).iter_rows()
    )
    expected_pairs = {
        (year, county_key)
        for year in TX_SOS_ELECTION_IDS
        for county_key in required_county_keys
    }
    if cached_pairs != expected_pairs:
        raise RuntimeError(
            "The cached Texas SOS file is incomplete. Delete it and rerun: "
            f"{tx_sos_raw_path}"
        )
    print(f"Using cached Texas SOS returns at {tx_sos_raw_path}")
else:
    tx_sos_rows = []
    for presidential_year, election_id in TX_SOS_ELECTION_IDS.items():
        print(f"Pulling official Texas SOS county returns for {presidential_year}...")
        select_url = f"{TX_SOS_BASE_URL}/elchist{election_id}_countyselect.htm"
        select_soup = BeautifulSoup(get_url(select_url).text, "html.parser")

        county_id_map = {}
        for option in select_soup.find_all("option"):
            # The legacy HTML does not close OPTION tags. The first text node
            # is the county name; get_text() concatenates every later option.
            county_name = next(option.stripped_strings)
            county_id_map[normalize_county_name(county_name)] = option.get("value")

        missing_counties = sorted(required_county_keys - set(county_id_map))
        if missing_counties:
            raise RuntimeError(
                f"Texas SOS county lookup failed for {presidential_year}: "
                + ", ".join(missing_counties)
            )

        for county_key in sorted(required_county_keys):
            county_id = county_id_map[county_key]
            county_url = (
                f"{TX_SOS_BASE_URL}/elchist{election_id}_county{county_id}.htm"
            )
            county_soup = BeautifulSoup(get_url(county_url).text, "html.parser")
            table = county_soup.find("table")
            if table is None:
                raise RuntimeError(f"No results table found at {county_url}")

            in_presidential_race = False
            party_votes = {}
            for row in table.find_all("tr"):
                cells = [
                    cell.get_text(" ", strip=True) for cell in row.find_all("td")
                ]
                if not cells:
                    continue

                if "President/Vice-President" in cells[0]:
                    in_presidential_race = True
                    continue

                if in_presidential_race and "Race Total" in cells:
                    break

                if (
                    in_presidential_race
                    and len(cells) >= 4
                    and cells[2] in {"REP", "DEM"}
                ):
                    party_votes[cells[2]] = int(cells[3].replace(",", ""))

            if set(party_votes) != {"REP", "DEM"}:
                raise RuntimeError(
                    f"Could not parse Republican and Democratic votes at {county_url}"
                )

            tx_sos_rows.append(
                {
                    "year": presidential_year,
                    "county_key": county_key,
                    "republican_votes": party_votes["REP"],
                    "democratic_votes": party_votes["DEM"],
                    "county_fips": None,
                    "source": "Texas Secretary of State",
                }
            )
            time.sleep(0.03)

    tx_sos_returns = pl.DataFrame(tx_sos_rows)
    tx_sos_returns.write_csv(tx_sos_raw_path)


# %% Combine county returns and build two-party Republican shares

county_returns = pl.concat([tx_sos_returns, mit_returns], how="diagonal_relaxed")
county_returns = (
    county_returns
    .with_columns(
        (
            pl.col("republican_votes")
            / (pl.col("republican_votes") + pl.col("democratic_votes"))
        ).alias("republican_two_party_share")
    )
    .sort(["year", "county_key"])
)

county_returns_path = (
    OUTPUT_DATA_DIR / f"tx_county_presidential_returns_{OUTPUT_DATE}.csv"
)
county_returns.write_csv(county_returns_path)


# %% Aggregate component counties to the bond-election geography labels

geography_returns = (
    county_bridge
    .join(county_returns, on="county_key", how="left", validate="m:m")
    .group_by(["County", "year"])
    .agg(
        pl.col("republican_votes").sum().alias("republican_votes"),
        pl.col("democratic_votes").sum().alias("democratic_votes"),
        pl.col("county_key").n_unique().alias("number_component_counties"),
    )
    .with_columns(
        (
            pl.col("republican_votes")
            / (pl.col("republican_votes") + pl.col("democratic_votes"))
        ).alias("republican_two_party_share")
    )
    .rename({"year": "presidential_year"})
)


# %% Merge the strictly preceding presidential election into bond elections

bond_elections = bond_elections.with_columns(
    (4 * ((pl.col("year") - 1) // 4)).alias("prior_presidential_year")
)
bond_elections = bond_elections.join(
    geography_returns,
    left_on=["County", "prior_presidential_year"],
    right_on=["County", "presidential_year"],
    how="left",
    validate="m:1",
)

missing_share = bond_elections.filter(pl.col("republican_two_party_share").is_null())
if missing_share.height > 0:
    missing_pairs = missing_share.select(
        ["County", "prior_presidential_year"]
    ).unique()
    raise RuntimeError(
        "Missing Republican shares after merge:\n" + str(missing_pairs)
    )

share_mean = bond_elections.get_column("republican_two_party_share").mean()
share_sd = bond_elections.get_column("republican_two_party_share").std()
bond_elections = bond_elections.with_columns(
    (
        (pl.col("republican_two_party_share") - share_mean) / share_sd
    ).alias("republican_share_sd"),
    (pl.col("votestotal") + 1).log().alias("log_votes"),
)

merged_path = (
    OUTPUT_DATA_DIR
    / f"tx_bond_elections_with_lagged_republican_share_{OUTPUT_DATE}.csv"
)
bond_elections.write_csv(merged_path)


# %% Create prior-rejection status without treating same-day propositions as prior

analysis = bond_elections.to_pandas()
analysis["election_date"] = pd.to_datetime(analysis["election_date"])
analysis["failure_date"] = analysis["election_date"].where(analysis["failed"] == 1)
analysis["first_failure_date"] = analysis.groupby("seed_issuer")[
    "failure_date"
].transform("min")
analysis["prior_rejection"] = (
    analysis["first_failure_date"].notna()
    & (analysis["election_date"] > analysis["first_failure_date"])
).astype(int)
analysis["purp_broad_new"] = analysis["purp_broad_new"].fillna("Missing")
analysis.drop(columns=["failure_date", "first_failure_date"]).to_csv(
    merged_path,
    index=False,
)


# %% Estimate explicit linear-probability specifications

model_1 = smf.ols(
    "failed ~ republican_share_sd",
    data=analysis,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": analysis["County"], "use_correction": True},
)

model_2 = smf.ols(
    "failed ~ republican_share_sd + ln_amount + log_votes + prior_rejection "
    "+ C(year) + C(purp_broad_new)",
    data=analysis,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": analysis["County"], "use_correction": True},
)

model_3_data = analysis.dropna(
    subset=["ln_county_pop_prior", "ln_county_percap_inc_prior"]
).copy()
model_3 = smf.ols(
    "failed ~ republican_share_sd + ln_amount + log_votes + prior_rejection "
    "+ C(year) + C(purp_broad_new)",
    data=model_3_data,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": model_3_data["County"], "use_correction": True},
)

model_4 = smf.ols(
    "failed ~ republican_share_sd + ln_amount + log_votes + prior_rejection "
    "+ ln_county_pop_prior + ln_county_percap_inc_prior "
    "+ C(year) + C(purp_broad_new)",
    data=model_3_data,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": model_3_data["County"], "use_correction": True},
)

model_5 = smf.ols(
    "failed ~ republican_share_sd + ln_amount + log_votes + prior_rejection "
    "+ C(year) + C(purp_broad_new) + C(seed_issuer)",
    data=analysis,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": analysis["County"], "use_correction": True},
)

single_county_data = analysis.loc[
    ~analysis["County"].str.contains(r"[-,]", regex=True)
].copy()
model_6 = smf.ols(
    "failed ~ republican_share_sd + ln_amount + log_votes + prior_rejection "
    "+ C(year) + C(purp_broad_new)",
    data=single_county_data,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": single_county_data["County"], "use_correction": True},
)

post_2000_data = analysis.loc[analysis["year"] >= 2001].copy()
model_7 = smf.ols(
    "failed ~ republican_share_sd + ln_amount + log_votes + prior_rejection "
    "+ C(year) + C(purp_broad_new)",
    data=post_2000_data,
).fit(
    cov_type="cluster",
    cov_kwds={"groups": post_2000_data["County"], "use_correction": True},
)


# %% Save regression coefficients and a readable summary

model_rows = []
for model_name, model in [
    ("1. Republican share only", model_1),
    ("2. Bond controls and year/purpose FE", model_2),
    ("3. Model 2 in nonmissing county-controls sample", model_3),
    ("4. Add county economic controls", model_4),
    ("5. Add city FE", model_5),
    ("6. Exclude multi-county labels", model_6),
    ("7. Elections after 2000", model_7),
]:
    model_rows.append(
        {
            "model": model_name,
            "coefficient": model.params["republican_share_sd"],
            "standard_error": model.bse["republican_share_sd"],
            "p_value": model.pvalues["republican_share_sd"],
            "conf_low_95": model.conf_int().loc["republican_share_sd", 0],
            "conf_high_95": model.conf_int().loc["republican_share_sd", 1],
            "observations": int(model.nobs),
            "r_squared": model.rsquared,
            "clusters": int(model.model.data.frame["County"].nunique()),
        }
    )

model_results = pd.DataFrame(model_rows)
model_results_path = (
    RESULTS_DIR / f"tx_republican_share_failure_models_{OUTPUT_DATE}.csv"
)
model_results.to_csv(model_results_path, index=False)

analysis["republican_share_quartile"] = pd.qcut(
    analysis["republican_two_party_share"],
    q=4,
    labels=["Q1: least Republican", "Q2", "Q3", "Q4: most Republican"],
    duplicates="drop",
)
quartile_summary = (
    analysis
    .groupby("republican_share_quartile", observed=True)
    .agg(
        propositions=("failed", "size"),
        failures=("failed", "sum"),
        failure_rate=("failed", "mean"),
        mean_republican_share=("republican_two_party_share", "mean"),
    )
    .reset_index()
)
quartile_path = RESULTS_DIR / f"tx_republican_share_quartiles_{OUTPUT_DATE}.csv"
quartile_summary.to_csv(quartile_path, index=False)

figure, axis = plt.subplots(figsize=(8, 5))
axis.bar(
    quartile_summary["republican_share_quartile"].astype(str),
    100 * quartile_summary["failure_rate"],
    color="#7A0019",
)
axis.set_ylabel("Bond proposition failure rate (%)")
axis.set_xlabel("Lagged county Republican two-party presidential vote share")
axis.set_title("Texas city bond-election failure rates by Republican-share quartile")
axis.spines[["top", "right"]].set_visible(False)
figure.tight_layout()
figure_path = RESULTS_DIR / f"tx_republican_share_failure_quartiles_{OUTPUT_DATE}.png"
figure.savefig(figure_path, dpi=300)
plt.close(figure)

summary_path = RESULTS_DIR / f"tx_republican_share_failure_summary_{OUTPUT_DATE}.md"
with summary_path.open("w", encoding="utf-8") as summary_file:
    summary_file.write("# Texas Republican vote share and bond rejection\n\n")
    summary_file.write(
        f"The merged sample contains {len(analysis):,} propositions, "
        f"{int(analysis['failed'].sum()):,} failures, "
        f"{analysis['seed_issuer'].nunique():,} cities, and "
        f"{analysis['County'].nunique():,} county geographies.\n\n"
    )
    summary_file.write(
        "Republican share is the two-party county presidential vote share from "
        "the most recent presidential election strictly before the bond-election "
        "year. Coefficients below are percentage-point changes in failure "
        "probability for a one-standard-deviation increase in Republican share. "
        "Standard errors are clustered by county geography.\n\n"
    )
    summary_file.write("| Model | Effect (pp) | SE (pp) | p-value | N |\n")
    summary_file.write("|---|---:|---:|---:|---:|\n")
    for row in model_rows:
        summary_file.write(
            f"| {row['model']} | {100 * row['coefficient']:.2f} | "
            f"{100 * row['standard_error']:.2f} | {row['p_value']:.3f} | "
            f"{row['observations']:,} |\n"
        )

print("\nRegression results for a one-SD increase in Republican share:")
print(model_results.to_string(index=False))
print("\nQuartile failure rates:")
print(quartile_summary.to_string(index=False))
print(f"\nSaved merged data to {merged_path}")
print(f"Saved regression summary to {summary_path}")
