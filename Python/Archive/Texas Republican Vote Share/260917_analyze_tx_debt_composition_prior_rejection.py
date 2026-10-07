"""Texas point-in-time UTGO share and prior bond-rejection incidence.

The script starts from the already prepared 2017 Texas point-in-time debt
sample, merges Texas city bond proposition outcomes strictly before 2017, and
tests whether the fraction of outstanding debt that is UTGO varies with prior
rejection experience. Standard errors are clustered by county.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf


OUTPUT_DATE = "260917"
PROJECT_DIR = Path(__file__).resolve().parents[3]
DATA_DIR = PROJECT_DIR / "Data"
RESULTS_DIR = PROJECT_DIR / "Results" / "TX Republican Vote Share"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

POINT_IN_TIME_TX_FILE = (
    DATA_DIR
    / "TX"
    / "Republican Vote Share"
    / f"tx_city_debt_composition_with_republican_share_{OUTPUT_DATE}.csv"
)
ELECTION_FILE = (
    DATA_DIR
    / "Clean_Intermediate"
    / "TX"
    / "News"
    / "Election_Level_With_News_WithFailed.csv"
)

MERGED_OUTPUT = (
    DATA_DIR
    / "TX"
    / "Republican Vote Share"
    / f"tx_point_in_time_debt_with_prior_rejection_{OUTPUT_DATE}.csv"
)
MODEL_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_prior_rejection_models_{OUTPUT_DATE}.csv"
)
GROUP_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_prior_rejection_groups_{OUTPUT_DATE}.csv"
)
SUMMARY_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_prior_rejection_summary_{OUTPUT_DATE}.md"
)


def standardize(series: pd.Series) -> pd.Series:
    return (series - series.mean()) / series.std(ddof=1)


def fit_model(
    data: pd.DataFrame,
    formula: str,
    model_name: str,
    focal_term: str,
) -> dict:
    result = smf.ols(formula, data=data).fit(
        cov_type="cluster",
        cov_kwds={"groups": data["fips"], "use_correction": True},
    )
    estimate = float(result.params[focal_term])
    std_error = float(result.bse[focal_term])
    return {
        "model": model_name,
        "focal_term": focal_term,
        "estimate": estimate,
        "std_error": std_error,
        "t_stat": float(result.tvalues[focal_term]),
        "p_value": float(result.pvalues[focal_term]),
        "ci_95_low": estimate - 1.96 * std_error,
        "ci_95_high": estimate + 1.96 * std_error,
        "n_cities": int(result.nobs),
        "n_counties": int(data["fips"].nunique()),
        "r_squared": float(result.rsquared),
        "adjusted_r_squared": float(result.rsquared_adj),
        "formula": formula,
    }


# The input is the screened 2017 Texas sample produced by the point-in-time
# Republican-share analysis. It already contains frac_utgo_outstanding and all
# controls from the Census/Mergent cross section.
debt = pd.read_csv(POINT_IN_TIME_TX_FILE)
debt["seed_issuer_key"] = debt["seed_issuer"].str.lower().str.strip()

elections = pd.read_csv(ELECTION_FILE)
elections = elections.loc[elections["year"] < 2017].copy()
elections["seed_issuer_key"] = elections["seed_issuer"].str.lower().str.strip()
elections["failed"] = elections["failed"].astype(int)

# The election crosswalk contains six duplicate Burkburnett propositions
# incorrectly assigned to Burnet as well. Retain the correct Burkburnett rows.
bad_burkburnett_crosswalk = (
    elections["GovernmentName"].str.lower().eq("burkburnett")
    & elections["seed_issuer_key"].eq("burnet tex")
)
elections = elections.loc[~bad_burkburnett_crosswalk].copy()

prior = (
    elections.groupby("seed_issuer_key", as_index=False)
    .agg(
        prior_propositions=("election_id", "nunique"),
        prior_election_dates=("ElectionDate", "nunique"),
        prior_rejections=("failed", "sum"),
        first_prior_election_year=("year", "min"),
        last_prior_election_year=("year", "max"),
    )
)
prior["any_prior_rejection"] = (prior["prior_rejections"] > 0).astype(int)
prior["prior_rejection_rate"] = (
    prior["prior_rejections"] / prior["prior_propositions"]
)

analysis = debt.merge(prior, on="seed_issuer_key", how="left", validate="one_to_one")
count_columns = [
    "prior_propositions",
    "prior_election_dates",
    "prior_rejections",
    "any_prior_rejection",
]
analysis[count_columns] = analysis[count_columns].fillna(0)
analysis["any_prior_election"] = (analysis["prior_propositions"] > 0).astype(int)
analysis["ln_1p_prior_propositions"] = np.log1p(analysis["prior_propositions"])
analysis["prior_rejections_sd"] = standardize(analysis["prior_rejections"])

election_city_sample = analysis.loc[analysis["any_prior_election"].eq(1)].copy()
election_city_sample["prior_rejection_rate_sd"] = standardize(
    election_city_sample["prior_rejection_rate"]
)

economic_controls = (
    "ln_gdp + ln_census_population + ln_pers_inc + "
    "ln_1p_county_nonmunicipal_total_debt"
)

model_specs = [
    (
        analysis,
        "frac_utgo_outstanding ~ any_prior_rejection",
        "any_rejection_bivariate",
        "any_prior_rejection",
    ),
    (
        analysis,
        "frac_utgo_outstanding ~ any_prior_rejection + ln_1p_prior_propositions",
        "any_rejection_election_exposure",
        "any_prior_rejection",
    ),
    (
        analysis,
        "frac_utgo_outstanding ~ any_prior_rejection + "
        f"ln_1p_prior_propositions + {economic_controls}",
        "any_rejection_controls",
        "any_prior_rejection",
    ),
    (
        analysis,
        "frac_utgo_outstanding ~ prior_rejections_sd + "
        f"ln_1p_prior_propositions + {economic_controls}",
        "rejection_count_controls",
        "prior_rejections_sd",
    ),
    (
        election_city_sample,
        "frac_utgo_outstanding ~ prior_rejection_rate_sd",
        "rejection_rate_bivariate_election_cities",
        "prior_rejection_rate_sd",
    ),
    (
        election_city_sample,
        "frac_utgo_outstanding ~ prior_rejection_rate_sd + "
        f"ln_1p_prior_propositions + {economic_controls}",
        "rejection_rate_controls_election_cities",
        "prior_rejection_rate_sd",
    ),
    (
        election_city_sample,
        "frac_utgo_outstanding ~ prior_rejection_rate_sd + "
        "ln_1p_prior_propositions + republican_share_2016_sd + "
        f"{economic_controls}",
        "rejection_rate_controls_and_republican_share",
        "prior_rejection_rate_sd",
    ),
]

model_rows = [
    fit_model(model_data, formula, name, focal)
    for model_data, formula, name, focal in model_specs
]
model_results = pd.DataFrame(model_rows)
model_results.to_csv(MODEL_OUTPUT, index=False)

group_summary = (
    analysis.groupby(
        ["any_prior_election", "any_prior_rejection"],
        as_index=False,
    )
    .agg(
        n_cities=("seed_issuer", "size"),
        n_counties=("fips", "nunique"),
        mean_frac_utgo_outstanding=("frac_utgo_outstanding", "mean"),
        mean_prior_propositions=("prior_propositions", "mean"),
        mean_prior_rejections=("prior_rejections", "mean"),
    )
)
group_summary.to_csv(GROUP_OUTPUT, index=False)

analysis.to_csv(MERGED_OUTPUT, index=False)


def model_row(name: str) -> pd.Series:
    return model_results.set_index("model").loc[name]


any_raw = model_row("any_rejection_bivariate")
any_controlled = model_row("any_rejection_controls")
rate_controlled = model_row("rejection_rate_controls_election_cities")
rate_republican = model_row("rejection_rate_controls_and_republican_share")

summary_lines = [
    "# Texas point-in-time UTGO share and prior rejection incidence",
    "",
    (
        f"- Point-in-time sample: {len(analysis):,} Texas cities in "
        f"{analysis['fips'].nunique():,} counties."
    ),
    (
        f"- Cities with a recorded pre-2017 bond proposition: "
        f"{int(analysis['any_prior_election'].sum()):,}."
    ),
    (
        f"- Cities with at least one pre-2017 rejection: "
        f"{int(analysis['any_prior_rejection'].sum()):,}."
    ),
    (
        f"- Matched pre-2017 propositions: {int(analysis['prior_propositions'].sum()):,}; "
        f"rejections: {int(analysis['prior_rejections'].sum()):,}."
    ),
    "",
    "## Regression results",
    "",
    (
        "- Any prior rejection, bivariate: "
        f"{any_raw['estimate']:.3f} (p = {any_raw['p_value']:.3f}; "
        f"95% CI [{any_raw['ci_95_low']:.3f}, {any_raw['ci_95_high']:.3f}])."
    ),
    (
        "- Any prior rejection, controlling for election exposure and point-in-time "
        f"economic/debt controls: {any_controlled['estimate']:.3f} "
        f"(p = {any_controlled['p_value']:.3f}; 95% CI "
        f"[{any_controlled['ci_95_low']:.3f}, {any_controlled['ci_95_high']:.3f}])."
    ),
    (
        "- Rejection rate among cities with prior elections, per one SD, with "
        f"controls: {rate_controlled['estimate']:.3f} "
        f"(p = {rate_controlled['p_value']:.3f})."
    ),
    (
        "- Rejection rate with the 2016 Republican share added: "
        f"{rate_republican['estimate']:.3f} "
        f"(p = {rate_republican['p_value']:.3f})."
    ),
    "",
    (
        "All election measures use proposition outcomes strictly before 2017. "
        "Standard errors are clustered by county."
    ),
]
SUMMARY_OUTPUT.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

print("\n".join(summary_lines))
print("\nSaved:")
print(f"- {MERGED_OUTPUT}")
print(f"- {MODEL_OUTPUT}")
print(f"- {GROUP_OUTPUT}")
print(f"- {SUMMARY_OUTPUT}")
