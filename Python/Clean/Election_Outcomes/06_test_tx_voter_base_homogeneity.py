"""Cross-sectional Texas tests of partisan voter-base homogeneity.

This script uses the locally cached MIT Election Lab county presidential
returns already merged to the project's Texas analysis files.  Its focal
measure is two-party partisan concentration, not Republican leaning:

    abs(Republican votes - Democratic votes) / (Republican votes + Democratic votes)

The measure is zero in a 50-50 county and one in a unanimous two-party county.
It is attached to each bond proposition using the presidential election
strictly before the proposition's election year.  The point-in-time debt test
uses the 2016 returns that precede the 2017 debt cross section.

The direction-controlled specifications add signed Republican share.  They are
important in Texas because a more homogeneous county is often also more
Republican; without that control, a concentration coefficient can partly be a
partisan-direction coefficient.

Inputs are prepared, local project data:
* Texas bond propositions with strictly lagged county presidential returns;
* the 2017 Texas Census/Mergent debt cross section with 2016 county returns.

The main proposition analysis includes all observations with a lagged return.
The MIT-only sensitivity restricts election years to 2001 onward, so every
presidential return comes from the MIT Election Lab series (2000 onward),
rather than the supplemental 1992/1996 Texas Secretary of State returns.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf


OUTPUT_DATE = "260928"
ROOT = Path(__file__).resolve().parents[4]
DATA = ROOT / "Data"
RESULTS = ROOT / "Results" / "TX Voter Base Homogeneity"
OUTPUT_DATA = DATA / "TX" / "Voter Base Homogeneity"

ELECTION_INPUT = (
    DATA
    / "TX"
    / "Republican Vote Share"
    / "tx_bond_elections_with_lagged_republican_share_260917.csv"
)
DEBT_INPUT = (
    DATA
    / "TX"
    / "Republican Vote Share"
    / "tx_city_debt_composition_with_republican_share_260917.csv"
)

ELECTION_OUTPUT = OUTPUT_DATA / f"tx_bond_elections_homogeneity_{OUTPUT_DATE}.csv"
DEBT_OUTPUT = OUTPUT_DATA / f"tx_debt_cross_section_homogeneity_{OUTPUT_DATE}.csv"
MODEL_OUTPUT = RESULTS / f"tx_voter_base_homogeneity_models_{OUTPUT_DATE}.csv"
QUARTILE_OUTPUT = RESULTS / f"tx_election_homogeneity_quartiles_{OUTPUT_DATE}.csv"
SUMMARY_OUTPUT = RESULTS / f"tx_voter_base_homogeneity_summary_{OUTPUT_DATE}.md"


def standardize(series: pd.Series) -> pd.Series:
    """Return a sample-standardized series, retaining the original index."""

    return (series - series.mean()) / series.std(ddof=1)


def add_homogeneity(
    data: pd.DataFrame,
    share_column: str,
) -> pd.DataFrame:
    """Add party-blind two-party concentration and its standardized version."""

    result = data.copy()
    share = pd.to_numeric(result[share_column], errors="coerce")
    if share.dropna().lt(0).any() or share.dropna().gt(1).any():
        raise ValueError(f"{share_column} contains values outside [0, 1].")

    result["republican_two_party_share"] = share
    result["partisan_homogeneity"] = (2 * share - 1).abs()
    result["partisan_homogeneity_sd"] = standardize(result["partisan_homogeneity"])
    result["republican_share_sd"] = standardize(share)
    result["dominant_party"] = np.where(share >= 0.5, "Republican", "Democratic")
    return result


def fit_model(
    data: pd.DataFrame,
    formula: str,
    model: str,
    dataset: str,
    outcome: str,
    cluster: str,
) -> dict[str, object]:
    """Fit OLS with cluster-robust errors and return the focal estimate."""

    result = smf.ols(formula, data=data).fit(
        cov_type="cluster",
        cov_kwds={"groups": data[cluster], "use_correction": True},
    )
    focal = "partisan_homogeneity_sd"
    estimate = float(result.params[focal])
    std_error = float(result.bse[focal])
    interval = result.conf_int().loc[focal]
    return {
        "dataset": dataset,
        "model": model,
        "outcome": outcome,
        "focal_term": focal,
        "estimate_per_sd": estimate,
        "std_error": std_error,
        "t_stat": float(result.tvalues[focal]),
        "p_value": float(result.pvalues[focal]),
        "ci_95_low": float(interval.iloc[0]),
        "ci_95_high": float(interval.iloc[1]),
        "observations": int(result.nobs),
        "clusters": int(data[cluster].nunique()),
        "r_squared": float(result.rsquared),
        "formula": formula,
    }


def complete_cases(data: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    """Keep an explicit common sample so clustered groups stay aligned."""

    return data.dropna(subset=columns).copy()


def get_row(models: pd.DataFrame, model: str) -> pd.Series:
    return models.set_index("model").loc[model]


for input_path in (ELECTION_INPUT, DEBT_INPUT):
    if not input_path.exists():
        raise FileNotFoundError(f"Missing prepared input: {input_path}")

RESULTS.mkdir(parents=True, exist_ok=True)
OUTPUT_DATA.mkdir(parents=True, exist_ok=True)


# Election-outcome tests -------------------------------------------------------
elections = add_homogeneity(pd.read_csv(ELECTION_INPUT), "republican_two_party_share")
elections["abs_vote_margin"] = pd.to_numeric(elections["vote_margin"], errors="coerce").abs()
elections["purp_broad_new"] = elections["purp_broad_new"].fillna("Missing")
elections.to_csv(ELECTION_OUTPUT, index=False)

election_controls = (
    "ln_amount + log_votes + prior_rejection + C(year) + C(purp_broad_new)"
)
election_control_columns = [
    "ln_amount",
    "log_votes",
    "prior_rejection",
    "year",
    "purp_broad_new",
    "partisan_homogeneity_sd",
    "republican_share_sd",
    "County",
]

election_failure = complete_cases(elections, ["failed", *election_control_columns])
election_margin = complete_cases(elections, ["abs_vote_margin", *election_control_columns])
election_mit_only_failure = election_failure.loc[election_failure["year"] >= 2001].copy()
election_mit_only_margin = election_margin.loc[election_margin["year"] >= 2001].copy()

model_rows = [
    fit_model(
        complete_cases(elections, ["failed", "partisan_homogeneity_sd", "County"]),
        "failed ~ partisan_homogeneity_sd",
        "election_failure_bivariate",
        "Bond propositions",
        "Failure indicator",
        "County",
    ),
    fit_model(
        election_failure,
        f"failed ~ partisan_homogeneity_sd + {election_controls}",
        "election_failure_controls",
        "Bond propositions",
        "Failure indicator",
        "County",
    ),
    fit_model(
        election_failure,
        f"failed ~ partisan_homogeneity_sd + republican_share_sd + {election_controls}",
        "election_failure_controls_direction",
        "Bond propositions",
        "Failure indicator",
        "County",
    ),
    fit_model(
        election_mit_only_failure,
        f"failed ~ partisan_homogeneity_sd + {election_controls}",
        "election_failure_controls_mit_only",
        "Bond propositions, 2001 onward",
        "Failure indicator",
        "County",
    ),
    fit_model(
        complete_cases(elections, ["abs_vote_margin", "partisan_homogeneity_sd", "County"]),
        "abs_vote_margin ~ partisan_homogeneity_sd",
        "election_margin_bivariate",
        "Bond propositions",
        "Absolute bond vote margin",
        "County",
    ),
    fit_model(
        election_margin,
        f"abs_vote_margin ~ partisan_homogeneity_sd + {election_controls}",
        "election_margin_controls",
        "Bond propositions",
        "Absolute bond vote margin",
        "County",
    ),
    fit_model(
        election_margin,
        f"abs_vote_margin ~ partisan_homogeneity_sd + republican_share_sd + {election_controls}",
        "election_margin_controls_direction",
        "Bond propositions",
        "Absolute bond vote margin",
        "County",
    ),
    fit_model(
        election_mit_only_margin,
        f"abs_vote_margin ~ partisan_homogeneity_sd + {election_controls}",
        "election_margin_controls_mit_only",
        "Bond propositions, 2001 onward",
        "Absolute bond vote margin",
        "County",
    ),
]


# 2017 point-in-time debt cross-section ---------------------------------------
debt = add_homogeneity(pd.read_csv(DEBT_INPUT), "republican_share_2016")
debt.to_csv(DEBT_OUTPUT, index=False)

debt_controls = (
    "ln_gdp + ln_census_population + ln_pers_inc + "
    "ln_1p_county_nonmunicipal_total_debt"
)
debt_columns = [
    "frac_utgo_outstanding",
    "partisan_homogeneity_sd",
    "republican_share_sd",
    "ln_gdp",
    "ln_census_population",
    "ln_pers_inc",
    "ln_1p_county_nonmunicipal_total_debt",
    "fips",
]
debt_analysis = complete_cases(debt, debt_columns)

model_rows.extend(
    [
        fit_model(
            complete_cases(
                debt,
                ["frac_utgo_outstanding", "partisan_homogeneity_sd", "fips"],
            ),
            "frac_utgo_outstanding ~ partisan_homogeneity_sd",
            "debt_utgo_share_bivariate",
            "2017 debt cross section",
            "UTGO share of GO/revenue debt",
            "fips",
        ),
        fit_model(
            debt_analysis,
            f"frac_utgo_outstanding ~ partisan_homogeneity_sd + {debt_controls}",
            "debt_utgo_share_controls",
            "2017 debt cross section",
            "UTGO share of GO/revenue debt",
            "fips",
        ),
        fit_model(
            debt_analysis,
            f"frac_utgo_outstanding ~ partisan_homogeneity_sd + republican_share_sd + {debt_controls}",
            "debt_utgo_share_controls_direction",
            "2017 debt cross section",
            "UTGO share of GO/revenue debt",
            "fips",
        ),
    ]
)

models = pd.DataFrame(model_rows)
models.to_csv(MODEL_OUTPUT, index=False)

elections["homogeneity_quartile"] = pd.qcut(
    elections["partisan_homogeneity"],
    q=4,
    labels=["Q1: least homogeneous", "Q2", "Q3", "Q4: most homogeneous"],
    duplicates="drop",
)
quartiles = (
    elections.groupby("homogeneity_quartile", observed=True)
    .agg(
        propositions=("failed", "size"),
        counties=("County", "nunique"),
        mean_homogeneity=("partisan_homogeneity", "mean"),
        mean_republican_share=("republican_two_party_share", "mean"),
        failure_rate=("failed", "mean"),
        mean_absolute_bond_margin=("abs_vote_margin", "mean"),
    )
    .reset_index()
)
quartiles.to_csv(QUARTILE_OUTPUT, index=False)


# Write a compact handoff summary ---------------------------------------------
failure = get_row(models, "election_failure_controls")
failure_direction = get_row(models, "election_failure_controls_direction")
margin = get_row(models, "election_margin_controls")
margin_direction = get_row(models, "election_margin_controls_direction")
debt_controlled = get_row(models, "debt_utgo_share_controls")

summary = [
    "# Texas voter-base partisan homogeneity tests",
    "",
    "## Measure",
    "",
    (
        "Partisan homogeneity is the absolute two-party presidential margin: "
        "`abs(R - D) / (R + D)`. It ranges from 0 (evenly divided) to 1 "
        "(unanimous in the two-party vote). It measures aggregate county "
        "partisan concentration, not within-county demographic homogeneity or "
        "individual-level voter preferences."
    ),
    "",
    "## Samples",
    "",
    (
        f"- Bond propositions: {len(elections):,} observations in "
        f"{elections['County'].nunique():,} county geographies. Each receives "
        "the presidential result strictly before its election year."
    ),
    (
        f"- MIT-only bond-election sensitivity: {len(election_mit_only_failure):,} "
        "propositions from 2001 onward; it excludes observations using the "
        "supplemental 1992/1996 Texas Secretary of State returns."
    ),
    (
        f"- 2017 debt cross section: {len(debt_analysis):,} cities in "
        f"{debt_analysis['fips'].nunique():,} counties, using 2016 MIT returns."
    ),
    "",
    "## Controlled estimates (per one-SD increase in homogeneity)",
    "",
    (
        f"- Bond failure: {100 * failure['estimate_per_sd']:.2f} percentage points "
        f"(p = {failure['p_value']:.3f}). After adding signed Republican share: "
        f"{100 * failure_direction['estimate_per_sd']:.2f} pp "
        f"(p = {failure_direction['p_value']:.3f})."
    ),
    (
        f"- Absolute bond vote margin: {100 * margin['estimate_per_sd']:.2f} pp "
        f"(p = {margin['p_value']:.3f}). After adding signed Republican share: "
        f"{100 * margin_direction['estimate_per_sd']:.2f} pp "
        f"(p = {margin_direction['p_value']:.3f})."
    ),
    (
        f"- 2017 UTGO share: {100 * debt_controlled['estimate_per_sd']:.2f} pp "
        f"(p = {debt_controlled['p_value']:.3f})."
    ),
    "",
    "All models are OLS with cluster-robust standard errors by county. "
    "Election models include election-year and bond-purpose fixed effects; "
    "controlled election specifications also include log amount, log votes, "
    "and a prior-rejection indicator. The controlled debt specification uses "
    "the existing 2017 debt-cross-section economic and debt controls.",
    "",
    "Interpret the direction-controlled models as the cleaner evidence on "
    "homogeneity itself, because Texas partisan concentration and Republican "
    "lean are positively correlated.",
]
SUMMARY_OUTPUT.write_text("\n".join(summary) + "\n", encoding="utf-8")

print("\n".join(summary))
print("\nSaved:")
for path in [ELECTION_OUTPUT, DEBT_OUTPUT, MODEL_OUTPUT, QUARTILE_OUTPUT, SUMMARY_OUTPUT]:
    print(f"- {path}")
