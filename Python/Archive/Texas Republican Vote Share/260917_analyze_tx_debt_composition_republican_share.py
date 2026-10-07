"""Texas point-in-time UTGO share and county Republican vote share.

This uses the same 2017 Census/Mergent cross section and sample restrictions as
Code/R/Clean/census_mergent_point_in_time_debt_choice.R. It filters to Texas,
uses the file's outstanding-debt variables and controls, merges the strictly
prior 2016 county Republican two-party presidential share, and regresses the
point-in-time UTGO share on Republican share with county-clustered errors.
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

POINT_IN_TIME_FILE = (
    DATA_DIR
    / "Clean_Intermediate"
    / "Census COG Finance"
    / "processed"
    / "census_mergent_debt_cross_section_2017.csv"
)
PRESIDENTIAL_FILE = (
    DATA_DIR
    / "TX"
    / "Republican Vote Share"
    / "raw"
    / "countypres_2000-2024.csv"
)

MERGED_OUTPUT = (
    DATA_DIR
    / "TX"
    / "Republican Vote Share"
    / f"tx_city_debt_composition_with_republican_share_{OUTPUT_DATE}.csv"
)
MODEL_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_republican_share_models_{OUTPUT_DATE}.csv"
)
QUARTILE_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_republican_share_quartiles_{OUTPUT_DATE}.csv"
)
HIGH_LOW_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_republican_share_high_low_{OUTPUT_DATE}.csv"
)
SUMMARY_OUTPUT = (
    RESULTS_DIR
    / f"tx_debt_composition_republican_share_summary_{OUTPUT_DATE}.md"
)


def format_fips(series: pd.Series) -> pd.Series:
    numeric = pd.to_numeric(series, errors="coerce").astype("Int64")
    return numeric.astype("string").str.zfill(5)


def fit_model(
    data: pd.DataFrame,
    formula: str,
    model_name: str,
    focal_term: str,
    joint_terms: list[str] | None = None,
) -> dict:
    result = smf.ols(formula, data=data).fit(
        cov_type="cluster",
        cov_kwds={"groups": data["fips"], "use_correction": True},
    )
    estimate = float(result.params[focal_term])
    std_error = float(result.bse[focal_term])
    joint_p_value = np.nan
    if joint_terms:
        hypothesis = ", ".join(f"{term} = 0" for term in joint_terms)
        joint_p_value = float(result.wald_test(hypothesis, scalar=True).pvalue)
    return {
        "model": model_name,
        "outcome": "frac_utgo_outstanding",
        "focal_term": focal_term,
        "estimate": estimate,
        "std_error": std_error,
        "t_stat": float(result.tvalues[focal_term]),
        "p_value": float(result.pvalues[focal_term]),
        "ci_95_low": estimate - 1.96 * std_error,
        "ci_95_high": estimate + 1.96 * std_error,
        "joint_p_value": joint_p_value,
        "n_cities": int(result.nobs),
        "n_counties": int(data["fips"].nunique()),
        "r_squared": float(result.rsquared),
        "adjusted_r_squared": float(result.rsquared_adj),
        "formula": formula,
    }


# Load the exact 2017 point-in-time cross section used by the R analysis.
data = pd.read_csv(POINT_IN_TIME_FILE)
data = data.loc[
    data["state"].eq("TX")
    & data["city_go_vote"].notna()
    & data["insample"].eq(1)
].copy()

# These are the same derived variables used in the source R analysis. All debt
# inputs and controls come directly from the saved point-in-time file.
data["frac_utgo_outstanding"] = (
    data["mergent_utgo_outstanding_debt"]
    / data["mergent_go_revenue_outstanding_debt"]
)
data.loc[
    data["mergent_go_revenue_outstanding_debt"] <= 0,
    "frac_utgo_outstanding",
] = np.nan
data["ln_census_population"] = np.log(data["census_population"])

# Reproduce the common control screen and the main debt-choice restriction of
# at least two outstanding GO/revenue CUSIPs.
screen_variables = [
    "ln_gdp",
    "ln_census_population",
    "ln_pers_inc",
    "ln_1p_county_nonmunicipal_total_debt",
    "glm_proactive",
    "state_ltgo_allowed",
    "state_go_vote",
    "mergent_go_revenue_bonds_outstanding",
    "frac_utgo_outstanding",
]
data = data.dropna(subset=screen_variables).copy()
data = data.loc[data["mergent_go_revenue_bonds_outstanding"] >= 2].copy()
data["fips"] = format_fips(data["fips"])

# County Republican two-party share from the presidential election strictly
# preceding the 2017 debt cross section.
presidential = pd.read_csv(PRESIDENTIAL_FILE)
presidential = presidential.loc[
    presidential["state_po"].eq("TX")
    & presidential["year"].eq(2016)
    & presidential["party"].isin(["REPUBLICAN", "DEMOCRAT"])
].copy()
county_votes = (
    presidential.groupby(["county_fips", "party"])["candidatevotes"]
    .sum()
    .unstack()
    .reset_index()
)
county_votes["republican_share_2016"] = county_votes["REPUBLICAN"] / (
    county_votes["REPUBLICAN"] + county_votes["DEMOCRAT"]
)
county_votes["fips"] = format_fips(county_votes["county_fips"])

data = data.merge(
    county_votes[["fips", "republican_share_2016"]],
    on="fips",
    how="left",
    validate="many_to_one",
)
if data["republican_share_2016"].isna().any():
    missing = sorted(data.loc[data["republican_share_2016"].isna(), "fips"].unique())
    raise RuntimeError(f"Missing 2016 Republican share for county FIPS: {missing}")

data["republican_share_2016_sd"] = (
    data["republican_share_2016"] - data["republican_share_2016"].mean()
) / data["republican_share_2016"].std(ddof=1)
median_republican_share = data["republican_share_2016"].median()
data["high_republican_share"] = (
    data["republican_share_2016"] >= median_republican_share
).astype(int)
data["republican_share_quartile"] = pd.qcut(
    data["republican_share_2016"],
    4,
    labels=["Q1", "Q2", "Q3", "Q4"],
)

quartile_factor = (
    "C(republican_share_quartile, Treatment(reference='Q1'))"
)
quartile_terms = [f"{quartile_factor}[T.Q{quartile}]" for quartile in (2, 3, 4)]
controls = (
    "ln_gdp + ln_census_population + ln_pers_inc + "
    "ln_1p_county_nonmunicipal_total_debt"
)

models = pd.DataFrame(
    [
        fit_model(
            data,
            "frac_utgo_outstanding ~ republican_share_2016_sd",
            "continuous_bivariate",
            "republican_share_2016_sd",
        ),
        fit_model(
            data,
            f"frac_utgo_outstanding ~ republican_share_2016_sd + {controls}",
            "continuous_controls",
            "republican_share_2016_sd",
        ),
        fit_model(
            data,
            "frac_utgo_outstanding ~ high_republican_share",
            "high_vs_low_bivariate",
            "high_republican_share",
        ),
        fit_model(
            data,
            f"frac_utgo_outstanding ~ high_republican_share + {controls}",
            "high_vs_low_controls",
            "high_republican_share",
        ),
        fit_model(
            data,
            f"frac_utgo_outstanding ~ {quartile_factor}",
            "quartiles_bivariate_q4_vs_q1",
            quartile_terms[-1],
            quartile_terms,
        ),
        fit_model(
            data,
            f"frac_utgo_outstanding ~ {quartile_factor} + {controls}",
            "quartiles_controls_q4_vs_q1",
            quartile_terms[-1],
            quartile_terms,
        ),
    ]
)
models.to_csv(MODEL_OUTPUT, index=False)

quartiles = (
    data.groupby("republican_share_quartile", observed=True)
    .agg(
        n_cities=("seed_issuer", "size"),
        n_counties=("fips", "nunique"),
        mean_republican_share=("republican_share_2016", "mean"),
        mean_frac_utgo_outstanding=("frac_utgo_outstanding", "mean"),
        median_frac_utgo_outstanding=("frac_utgo_outstanding", "median"),
    )
    .reset_index()
)
quartiles["description"] = [
    "least Republican",
    "",
    "",
    "most Republican",
]
quartiles.to_csv(QUARTILE_OUTPUT, index=False)

high_low = (
    data.groupby("high_republican_share", observed=True)
    .agg(
        n_cities=("seed_issuer", "size"),
        n_counties=("fips", "nunique"),
        mean_republican_share=("republican_share_2016", "mean"),
        mean_frac_utgo_outstanding=("frac_utgo_outstanding", "mean"),
        median_frac_utgo_outstanding=("frac_utgo_outstanding", "median"),
    )
    .reset_index()
)
high_low["group"] = high_low["high_republican_share"].map(
    {0: "below sample median", 1: "at or above sample median"}
)
high_low["sample_median_republican_share"] = median_republican_share
high_low.to_csv(HIGH_LOW_OUTPUT, index=False)

output_columns = [
    "year",
    "issuer_key",
    "seed_issuer_id",
    "seed_issuer",
    "fips",
    "county_name",
    "census_population",
    "mergent_go_revenue_bonds_outstanding",
    "mergent_go_revenue_outstanding_debt",
    "mergent_utgo_outstanding_debt",
    "frac_utgo_outstanding",
    "republican_share_2016",
    "republican_share_2016_sd",
    "high_republican_share",
    "republican_share_quartile",
    "ln_gdp",
    "ln_census_population",
    "ln_pers_inc",
    "ln_1p_county_nonmunicipal_total_debt",
]
data[output_columns].to_csv(MERGED_OUTPUT, index=False)

model_index = models.set_index("model")
bivariate = model_index.loc["continuous_bivariate"]
controlled = model_index.loc["continuous_controls"]
high_bivariate = model_index.loc["high_vs_low_bivariate"]
high_controlled = model_index.loc["high_vs_low_controls"]
quartile_bivariate = model_index.loc["quartiles_bivariate_q4_vs_q1"]
quartile_controlled = model_index.loc["quartiles_controls_q4_vs_q1"]
summary_lines = [
    "# Texas point-in-time UTGO share and county Republican vote share",
    "",
    (
        f"- Sample: {len(data):,} Texas cities in {data['fips'].nunique():,} "
        "counties from the 2017 Census/Mergent point-in-time cross section."
    ),
    (
        "- Outcome: 2017 UTGO outstanding debt divided by total outstanding "
        "GO plus revenue debt."
    ),
    "- Political measure: 2016 county Republican two-party presidential share.",
    "",
    "## Regression results",
    "",
    (
        "- Bivariate, per one-SD Republican share: "
        f"{bivariate['estimate']:.3f} (p = {bivariate['p_value']:.3f}; "
        f"95% CI [{bivariate['ci_95_low']:.3f}, {bivariate['ci_95_high']:.3f}])."
    ),
    (
        "- With the point-in-time economic/debt controls: "
        f"{controlled['estimate']:.3f} (p = {controlled['p_value']:.3f}; "
        f"95% CI [{controlled['ci_95_low']:.3f}, {controlled['ci_95_high']:.3f}])."
    ),
    (
        f"- At/above versus below the sample median ({median_republican_share:.3f}), "
        f"bivariate: {high_bivariate['estimate']:.3f} "
        f"(p = {high_bivariate['p_value']:.3f}); with controls: "
        f"{high_controlled['estimate']:.3f} "
        f"(p = {high_controlled['p_value']:.3f})."
    ),
    (
        "- Most- versus least-Republican quartile, bivariate: "
        f"{quartile_bivariate['estimate']:.3f} "
        f"(p = {quartile_bivariate['p_value']:.3f}); with controls: "
        f"{quartile_controlled['estimate']:.3f} "
        f"(p = {quartile_controlled['p_value']:.3f})."
    ),
    (
        "- Joint p-value for all Republican-share quartile indicators: "
        f"{quartile_bivariate['joint_p_value']:.3f} bivariate and "
        f"{quartile_controlled['joint_p_value']:.3f} with controls."
    ),
    "",
    (
        "Controls are county log GDP, city log population, county log personal "
        "income, and log county nonmunicipal debt. Standard errors are clustered "
        "by county."
    ),
]
SUMMARY_OUTPUT.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

print("\n".join(summary_lines))
print("\nSaved:")
print(f"- {MERGED_OUTPUT}")
print(f"- {MODEL_OUTPUT}")
print(f"- {QUARTILE_OUTPUT}")
print(f"- {HIGH_LOW_OUTPUT}")
print(f"- {SUMMARY_OUTPUT}")
