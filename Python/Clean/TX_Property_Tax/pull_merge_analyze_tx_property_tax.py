"""Build Texas city property-tax rates and test disclosure heterogeneity.

Sources
-------
Texas Comptroller, Property Tax Assistance Division, *City Rates and Levies*
annual workbooks.  Workbooks from 2021 onward are downloaded from the current
Comptroller site.  The script uses the Internet Archive CDX index only to
retrieve preserved copies of the same Comptroller workbooks that the agency no
longer links on its current page (2011--2020).

The focal tax measure is the total city property-tax rate -- M&O plus I&S --
in dollars per $100 of taxable value.  This is deliberately a city-government
rate, not a geographically complete property-tax bill that would require
parcel-level overlaps with school, county, and special districts.
"""

from __future__ import annotations

import io
import re
import sys
import unicodedata
from pathlib import Path
from urllib.parse import quote

import numpy as np
import pandas as pd
import requests
import statsmodels.formula.api as smf


FIRST_YEAR = 2011
LAST_YEAR = 2025
REQUEST_TIMEOUT = 90
ROOT = Path(__file__).resolve().parents[4]
DATA_DIR = ROOT / "Data" / "TX" / "Property Tax"
RAW_DIR = DATA_DIR / "raw"
RESULTS_DIR = ROOT / "Results" / "TX Property Tax Rejection Risk"
TAX_PANEL_PATH = DATA_DIR / f"tx_city_property_tax_rates_{FIRST_YEAR}_{LAST_YEAR}.csv"
MERGED_PANEL_PATH = DATA_DIR / "tx_website_disclosure_with_property_tax.csv"
ELECTION_MERGED_PATH = DATA_DIR / "tx_bond_elections_with_property_tax.csv"
MATCH_DIAGNOSTICS_PATH = DATA_DIR / "tx_website_property_tax_match_diagnostics.csv"
MODEL_PATH = RESULTS_DIR / "tx_property_tax_disclosure_models.csv"
EFFECT_PATH = RESULTS_DIR / "tx_property_tax_disclosure_election_effects.csv"
REJECTION_MODEL_PATH = RESULTS_DIR / "tx_property_tax_rejection_risk_models.csv"
SUMMARY_PATH = RESULTS_DIR / "tx_property_tax_disclosure_summary.md"
WEBSITE_INPUT = (
    ROOT
    / "Data"
    / "Clean_Intermediate"
    / "TX"
    / "Regression"
    / "website_city_year_regression_ready.csv"
)
ELECTION_INPUT = (
    ROOT
    / "Data"
    / "Clean_Intermediate"
    / "TX"
    / "Regression"
    / "election_media_regression_ready.csv"
)

CURRENT_BASE_URL = "https://comptroller.texas.gov/taxes/property-tax/docs"
ARCHIVE_CDX_URL = "https://web.archive.org/cdx/search/cdx"
SESSION = requests.Session()
SESSION.headers.update({"User-Agent": "Texas-property-tax-research/1.0"})


def filename_for_year(year: int) -> str:
    """Return the Comptroller's historical filename convention."""

    if year == 2011:
        return "2011_City_Rates_Levies.xls"
    if 2012 <= year <= 2015:
        return f"{year}_City_Rates_Levies.xls"
    if year == 2016:
        return "2016-city-rates-levies.xls"
    return f"{year}-city-rates-levies.xlsx"


def comptroller_url(year: int) -> str:
    return f"{CURRENT_BASE_URL}/{filename_for_year(year)}"


def archived_comptroller_url(year: int) -> str:
    """Return the historic URL form indexed by the Internet Archive.

    The Comptroller changed both hostname and filename casing over time.  Using
    the known historic form avoids several costly CDX misses before reaching the
    actual preserved official workbook.
    """

    host = "https://comptroller.texas.gov"
    if year in {2011, 2018}:
        host = "https://www.comptroller.texas.gov"
    elif 2012 <= year <= 2015:
        host = "http://www.comptroller.texas.gov"
    return f"{host}/taxes/property-tax/docs/{filename_for_year(year)}"


def cached_workbook(year: int) -> Path:
    return RAW_DIR / filename_for_year(year)


def get_archive_snapshot(source_url: str) -> tuple[str, bytes]:
    """Find the newest successful archived version of an official workbook."""

    response = SESSION.get(
        ARCHIVE_CDX_URL,
        params={
            "url": source_url,
            "output": "json",
            "filter": "statuscode:200",
            "fl": "timestamp,original,statuscode",
            "collapse": "digest",
        },
        timeout=REQUEST_TIMEOUT,
    )
    response.raise_for_status()
    rows = response.json()
    snapshots: list[dict[str, str]] = []
    if len(rows) > 1:
        header = rows[0]
        snapshots.extend(dict(zip(header, row)) for row in rows[1:])

    if not snapshots:
        raise RuntimeError(f"No archived Comptroller workbook found for {source_url}")

    snapshot = max(snapshots, key=lambda row: row["timestamp"])
    replay_url = (
        f"https://web.archive.org/web/{snapshot['timestamp']}id_/"
        f"{snapshot['original']}"
    )
    response = SESSION.get(replay_url, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return replay_url, response.content


def download_workbook(year: int) -> tuple[Path, str, str]:
    """Cache a workbook and return its path, source URL, and access route."""

    path = cached_workbook(year)
    source_url = comptroller_url(year) if year >= 2021 else archived_comptroller_url(year)
    route = (
        "current_comptroller_site"
        if year >= 2021
        else "internet_archive_preserved_comptroller_workbook"
    )
    if path.exists() and path.stat().st_size > 10_000:
        return path, source_url, route

    if year >= 2021:
        response = SESSION.get(source_url, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        payload = response.content
    else:
        _, payload = get_archive_snapshot(archived_comptroller_url(year))

    path.write_bytes(payload)
    return path, source_url, route


def normalized_column(value: object) -> str:
    return re.sub(r"[^A-Z0-9]+", " ", str(value).upper()).strip()


def find_header_row(path: Path) -> int:
    """Locate the header despite a title block in recent workbooks."""

    preview = pd.read_excel(path, header=None, nrows=15)
    for index, row in preview.iterrows():
        values = {normalized_column(value) for value in row.dropna()}
        has_city_name = (
            "CITY NAME" in values or "TAXING UNIT NAME" in values or "TU NAME" in values
        )
        has_rate = any("TAX RATE" in value for value in values) or "TOTAL RATE" in values
        if has_city_name and has_rate:
            return int(index)
    raise ValueError(f"Could not locate header row in {path.name}")


def first_matching_column(columns: list[str], candidates: list[str]) -> str | None:
    normalized = {normalized_column(column): column for column in columns}
    for candidate in candidates:
        if candidate in normalized:
            return normalized[candidate]
    return None


def normalize_city_name(value: object) -> str:
    """Normalize names while retaining enough information for exact matching."""

    text = unicodedata.normalize("NFKD", str(value)).encode("ascii", "ignore").decode()
    text = text.upper().replace("*", "")
    text = re.sub(r"^(CITY|TOWN|VILLAGE) OF THE ", "", text)
    text = re.sub(r"^(CITY|TOWN|VILLAGE) OF ", "", text)
    text = re.sub(r"\b(CITY|TOWN|VILLAGE|TEXAS)\b", " ", text)
    return re.sub(r"[^A-Z0-9]", "", text)


def weighted_mean(values: pd.Series, weights: pd.Series) -> float:
    usable = values.notna()
    if not usable.any():
        return np.nan
    values = values[usable]
    weights = weights[usable].fillna(0)
    if weights.sum() > 0:
        return float(np.average(values, weights=weights))
    return float(values.mean())


def parse_city_workbook(path: Path, year: int, source_url: str, route: str) -> pd.DataFrame:
    header_row = find_header_row(path)
    raw = pd.read_excel(path, header=header_row)
    raw.columns = [str(column).strip() for column in raw.columns]
    raw = raw.dropna(how="all")

    city_col = first_matching_column(
        raw.columns.tolist(), ["CITY NAME", "TAXING UNIT NAME", "TU NAME"]
    )
    city_id_col = first_matching_column(
        raw.columns.tolist(), ["CITY", "CITY #", "TAXING UNIT ID", "TU #"]
    )
    taxable_col = first_matching_column(raw.columns.tolist(), ["TAXABLE VALUE"])
    total_rate_col = first_matching_column(raw.columns.tolist(), ["TOTAL TAX RATE", "TOTAL RATE"])
    mo_rate_col = first_matching_column(
        raw.columns.tolist(), ["M O TAX RATE", "M&O TAX RATE", "MO RATE", "M O RATE"]
    )
    is_rate_col = first_matching_column(
        raw.columns.tolist(), ["I S TAX RATE", "I&S TAX RATE", "IS RATE", "I S RATE"]
    )
    effective_rate_col = first_matching_column(
        raw.columns.tolist(), ["EFFECTIVE TAX RATE", "NO NEW REVENUE RATE", "EFFECTIVE RATE"]
    )

    if city_col is None or total_rate_col is None:
        raise ValueError(f"Required city or total-rate column missing in {path.name}")

    result = pd.DataFrame(
        {
            "tax_year": year,
            "source_city_name": raw[city_col].astype(str).str.strip(),
            "source_city_id": raw[city_id_col].astype(str).str.strip() if city_id_col else pd.NA,
            "taxable_value": pd.to_numeric(raw[taxable_col], errors="coerce") if taxable_col else np.nan,
            "city_total_tax_rate": pd.to_numeric(raw[total_rate_col], errors="coerce"),
            "city_mo_tax_rate": pd.to_numeric(raw[mo_rate_col], errors="coerce") if mo_rate_col else np.nan,
            "city_is_tax_rate": pd.to_numeric(raw[is_rate_col], errors="coerce") if is_rate_col else np.nan,
            "city_effective_tax_rate": pd.to_numeric(raw[effective_rate_col], errors="coerce") if effective_rate_col else np.nan,
            "source_url": source_url,
            "source_access": route,
        }
    )
    result = result[result["source_city_name"].notna() & (result["source_city_name"] != "")]
    result["city_name_key"] = result["source_city_name"].map(normalize_city_name)
    result = result[result["city_name_key"] != ""]

    rate_columns = [
        "city_total_tax_rate",
        "city_mo_tax_rate",
        "city_is_tax_rate",
        "city_effective_tax_rate",
    ]
    grouped_rows = []
    for (tax_year, city_key), group in result.groupby(["tax_year", "city_name_key"], sort=False):
        row = {
            "tax_year": tax_year,
            "city_name_key": city_key,
            "source_city_name": group["source_city_name"].iloc[0],
            "source_city_id": group["source_city_id"].dropna().iloc[0]
            if group["source_city_id"].notna().any()
            else pd.NA,
            "taxable_value": group["taxable_value"].sum(min_count=1),
            "source_url": source_url,
            "source_access": route,
            "source_rows_collapsed": len(group),
        }
        for column in rate_columns:
            row[column] = weighted_mean(group[column], group["taxable_value"])
        grouped_rows.append(row)
    return pd.DataFrame(grouped_rows)


def build_tax_panel() -> pd.DataFrame:
    panels = []
    for year in range(FIRST_YEAR, LAST_YEAR + 1):
        print(f"Downloading/parsing {year} city tax rates...", flush=True)
        path, source_url, route = download_workbook(year)
        panels.append(parse_city_workbook(path, year, source_url, route))
    panel = pd.concat(panels, ignore_index=True)
    panel = panel.sort_values(["city_name_key", "tax_year"]).reset_index(drop=True)
    return panel


def construct_disclosure_panel(tax_panel: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    website = pd.read_csv(WEBSITE_INPUT)
    website = website[website["seed_issuer"].notna() & (website["seed_issuer"] != "")].copy()
    website["year"] = pd.to_numeric(website["year"], errors="coerce").astype("Int64")
    website = website.dropna(subset=["year"]).copy()
    website["year"] = website["year"].astype(int)
    website["city_name_key"] = website["GovernmentName"].map(normalize_city_name)
    website = website.sort_values(["seed_issuer", "year"]).drop_duplicates(
        ["seed_issuer", "year"], keep="first"
    )
    website["bond_count"] = pd.to_numeric(website["bond_count"], errors="coerce")
    website["prior_bond_count"] = website.groupby("seed_issuer", sort=False)["bond_count"].shift(1)
    website["delta_bond_count"] = website["bond_count"] - website["prior_bond_count"]
    website["positive_delta_bond_count"] = np.where(
        website["delta_bond_count"].notna(),
        (website["delta_bond_count"] > 0).astype(int),
        np.nan,
    )
    website["prior_tax_year"] = website["year"] - 1

    tax_columns = [
        "tax_year",
        "city_name_key",
        "source_city_name",
        "city_total_tax_rate",
        "city_mo_tax_rate",
        "city_is_tax_rate",
        "city_effective_tax_rate",
        "taxable_value",
        "source_url",
        "source_access",
        "source_rows_collapsed",
    ]
    merged = website.merge(
        tax_panel[tax_columns],
        how="left",
        left_on=["city_name_key", "prior_tax_year"],
        right_on=["city_name_key", "tax_year"],
        validate="m:1",
    )
    merged["city_tax_rate_10_cents"] = merged["city_total_tax_rate"] * 10
    matched = merged["city_total_tax_rate"].notna()
    diagnostics = (
        merged.groupby(["year", "election"], dropna=False)
        .agg(
            city_years=("seed_issuer", "size"),
            matched_city_years=("city_total_tax_rate", lambda x: int(x.notna().sum())),
            match_rate=("city_total_tax_rate", lambda x: float(x.notna().mean())),
            elections=("election", "sum"),
        )
        .reset_index()
    )
    unmatched = merged.loc[~matched, ["GovernmentName", "seed_issuer", "year", "prior_tax_year"]].copy()
    unmatched["diagnostic"] = "no exact normalized prior-year Comptroller city match"
    diagnostics = pd.concat([diagnostics, unmatched], ignore_index=True, sort=False)
    return merged, diagnostics


def construct_election_panel(tax_panel: pd.DataFrame) -> pd.DataFrame:
    """Attach the predetermined city tax rate to each city bond proposition."""

    elections = pd.read_csv(ELECTION_INPUT)
    elections["year"] = pd.to_numeric(elections["year"], errors="coerce").astype("Int64")
    elections = elections.dropna(subset=["year", "GovernmentName"]).copy()
    elections["year"] = elections["year"].astype(int)
    elections["city_name_key"] = elections["GovernmentName"].map(normalize_city_name)
    elections["prior_tax_year"] = elections["year"] - 1
    tax_columns = [
        "tax_year",
        "city_name_key",
        "source_city_name",
        "city_total_tax_rate",
        "city_mo_tax_rate",
        "city_is_tax_rate",
        "city_effective_tax_rate",
        "taxable_value",
        "source_url",
        "source_access",
    ]
    merged = elections.merge(
        tax_panel[tax_columns],
        how="left",
        left_on=["city_name_key", "prior_tax_year"],
        right_on=["city_name_key", "tax_year"],
        validate="m:1",
    )
    return merged


def tidy_result(model, model_name: str) -> list[dict[str, object]]:
    confidence = model.conf_int()
    rows = []
    for term in model.params.index:
        rows.append(
            {
                "model": model_name,
                "term": term,
                "estimate": float(model.params[term]),
                "std_error": float(model.bse[term]),
                "t_stat": float(model.tvalues[term]),
                "p_value": float(model.pvalues[term]),
                "ci_95_low": float(confidence.loc[term, 0]),
                "ci_95_high": float(confidence.loc[term, 1]),
                "observations": int(model.nobs),
                "clusters": int(model.model.data.frame["fips"].nunique()),
                "r_squared": float(model.rsquared),
                "formula": model.model.formula,
            }
        )
    return rows


def estimate_disclosure_models(merged: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    needed = [
        "positive_delta_bond_count",
        "election",
        "city_total_tax_rate",
        "seed_issuer",
        "year",
        "fips",
    ]
    analysis = merged.dropna(subset=needed).copy()
    analysis["fips"] = analysis["fips"].astype(str)
    analysis["city_tax_rate_sd"] = (
        analysis["city_total_tax_rate"] - analysis["city_total_tax_rate"].mean()
    ) / analysis["city_total_tax_rate"].std(ddof=1)

    controls = [
        "issuance_year",
        "ln_county_gdp_prior",
        "ln_county_pop_prior",
        "ln_county_pers_inc_prior",
    ]
    controlled = analysis.dropna(subset=controls).copy()
    formula_base = (
        "positive_delta_bond_count ~ election * city_tax_rate_sd + "
        "C(seed_issuer) + C(year)"
    )
    formula_controls = (
        formula_base
        + " + issuance_year + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior"
    )
    model_base = smf.ols(formula_base, data=analysis).fit(
        cov_type="cluster", cov_kwds={"groups": analysis["fips"], "use_correction": True}
    )
    model_controls = smf.ols(formula_controls, data=controlled).fit(
        cov_type="cluster", cov_kwds={"groups": controlled["fips"], "use_correction": True}
    )
    models = pd.DataFrame(
        tidy_result(model_base, "city_year_fe")
        + tidy_result(model_controls, "city_year_fe_county_controls")
    )

    effect_rows = []
    for name, model, sample in [
        ("city_year_fe", model_base, analysis),
        ("city_year_fe_county_controls", model_controls, controlled),
    ]:
        beta = model.params
        covariance = model.cov_params()
        interaction = "election:city_tax_rate_sd"
        for label, value in [
            ("25th percentile", float(sample["city_tax_rate_sd"].quantile(0.25))),
            ("Median", float(sample["city_tax_rate_sd"].median())),
            ("75th percentile", float(sample["city_tax_rate_sd"].quantile(0.75))),
        ]:
            estimate = beta["election"] + value * beta[interaction]
            variance = (
                covariance.loc["election", "election"]
                + value**2 * covariance.loc[interaction, interaction]
                + 2 * value * covariance.loc["election", interaction]
            )
            effect_rows.append(
                {
                    "model": name,
                    "tax_rate_position": label,
                    "tax_rate_sd": value,
                    "city_tax_rate": float(
                        sample["city_total_tax_rate"].mean()
                        + value * sample["city_total_tax_rate"].std(ddof=1)
                    ),
                    "election_effect": float(estimate),
                    "std_error": float(np.sqrt(variance)),
                }
            )
    effects = pd.DataFrame(effect_rows)
    return analysis, models, effects


def estimate_rejection_risk_models(elections: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Test whether a high predetermined city tax rate predicts voter rejection."""

    needed = [
        "failed",
        "vote_margin",
        "city_total_tax_rate",
        "year",
        "purp_broad_new",
        "fips",
        "ln_amount",
    ]
    analysis = elections.dropna(subset=needed).copy()
    analysis["failed"] = analysis["failed"].astype(int)
    analysis["fips"] = analysis["fips"].astype(str)
    analysis["city_tax_rate_sd"] = (
        analysis["city_total_tax_rate"] - analysis["city_total_tax_rate"].mean()
    ) / analysis["city_total_tax_rate"].std(ddof=1)
    controls = [
        "ln_county_gdp_prior",
        "ln_county_pop_prior",
        "ln_county_pers_inc_prior",
    ]
    controlled = analysis.dropna(subset=controls).copy()
    failure_formula = "failed ~ city_tax_rate_sd + C(year) + C(purp_broad_new)"
    margin_formula = "vote_margin ~ city_tax_rate_sd + C(year) + C(purp_broad_new)"
    failure_controls_formula = (
        failure_formula
        + " + ln_amount + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior"
    )
    margin_controls_formula = (
        margin_formula
        + " + ln_amount + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior"
    )
    specs = [
        ("failure_year_purpose_fe", failure_formula, analysis),
        ("failure_year_purpose_fe_controls", failure_controls_formula, controlled),
        ("margin_year_purpose_fe", margin_formula, analysis),
        ("margin_year_purpose_fe_controls", margin_controls_formula, controlled),
    ]
    rows = []
    for model_name, formula, sample in specs:
        model = smf.ols(formula, data=sample).fit(
            cov_type="cluster", cov_kwds={"groups": sample["fips"], "use_correction": True}
        )
        rows.extend(tidy_result(model, model_name))
    return analysis, pd.DataFrame(rows)


def write_summary(
    tax_panel: pd.DataFrame,
    analysis: pd.DataFrame,
    models: pd.DataFrame,
    effects: pd.DataFrame,
    rejection_analysis: pd.DataFrame,
    rejection_models: pd.DataFrame,
) -> None:
    interaction = models.loc[
        (models["model"] == "city_year_fe_county_controls")
        & (models["term"] == "election:city_tax_rate_sd")
    ].iloc[0]
    main_election = models.loc[
        (models["model"] == "city_year_fe_county_controls")
        & (models["term"] == "election")
    ].iloc[0]
    rejection_failure = rejection_models.loc[
        (rejection_models["model"] == "failure_year_purpose_fe_controls")
        & (rejection_models["term"] == "city_tax_rate_sd")
    ].iloc[0]
    rejection_margin = rejection_models.loc[
        (rejection_models["model"] == "margin_year_purpose_fe_controls")
        & (rejection_models["term"] == "city_tax_rate_sd")
    ].iloc[0]
    lines = [
        "# Texas city property-tax-rate heterogeneity",
        "",
        "## Measure and timing",
        "",
        "The moderator is the Comptroller-reported total **city** property-tax rate "
        "(M&O plus I&S), in dollars per $100 of taxable value. It is merged by "
        "normalized city name and uses the prior tax year for each website city-year.",
        "",
        f"The rate panel contains {len(tax_panel):,} city-year observations for "
        f"{tax_panel['city_name_key'].nunique():,} cities from {FIRST_YEAR} through {LAST_YEAR}.",
        "",
        "## Rejection-risk check",
        "",
        "Before using tax rates as a rejection-risk moderator, the city-bond-proposition "
        "sample tests whether the prior city tax rate predicts failure and vote margin. "
        "These models include election-year and purpose fixed effects, add issue amount "
        "and prior-year county economic controls, and cluster by county.",
        "",
        f"The matched election sample contains {len(rejection_analysis):,} propositions "
        f"from {rejection_analysis['year'].min()} through {rejection_analysis['year'].max()}.",
        "",
        f"A one-SD higher prior city tax rate is associated with a "
        f"{rejection_failure['estimate']:.3f} change in the failure probability "
        f"(SE {rejection_failure['std_error']:.3f}; p={rejection_failure['p_value']:.3f}) "
        f"and a {rejection_margin['estimate']:.3f} change in vote margin "
        f"(SE {rejection_margin['std_error']:.3f}; p={rejection_margin['p_value']:.3f}).",
        "",
        "## Disclosure-response specification",
        "",
        "Dependent variable: an indicator that the city's website bond-text count "
        "rose from the prior year. The model includes city and year fixed effects, "
        "adds issuance and prior-year county economic controls, and clusters standard "
        "errors by county. The property-tax-rate interaction is standardized within the analysis sample.",
        "",
        f"Analysis sample: {len(analysis):,} city-years, {analysis['seed_issuer'].nunique():,} cities, "
        f"and {analysis['fips'].nunique():,} county clusters.",
        "",
        "## Result",
        "",
        f"In the controlled specification, the election-year effect at the mean tax rate is "
        f"{main_election['estimate']:.3f} (SE {main_election['std_error']:.3f}; "
        f"p={main_election['p_value']:.3f}). The interaction with a one-SD higher prior "
        f"city tax rate is {interaction['estimate']:.3f} (SE {interaction['std_error']:.3f}; "
        f"p={interaction['p_value']:.3f}).",
        "",
        "Estimated election effects at selected prior-tax-rate positions:",
        "",
        "| Prior city tax-rate position | Rate ($ per $100) | Election effect | SE |",
        "|---|---:|---:|---:|",
    ]
    for row in effects[effects["model"] == "city_year_fe_county_controls"].itertuples(index=False):
        lines.append(
            f"| {row.tax_rate_position} | {row.city_tax_rate:.3f} | "
            f"{row.election_effect:.3f} | {row.std_error:.3f} |"
        )
    SUMMARY_PATH.write_text("\n".join(lines) + "\n")


def main() -> None:
    if not WEBSITE_INPUT.exists():
        raise FileNotFoundError(f"Missing website panel: {WEBSITE_INPUT}")
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    tax_panel = build_tax_panel()
    tax_panel.to_csv(TAX_PANEL_PATH, index=False)
    merged, diagnostics = construct_disclosure_panel(tax_panel)
    merged.to_csv(MERGED_PANEL_PATH, index=False)
    diagnostics.to_csv(MATCH_DIAGNOSTICS_PATH, index=False)
    election_merged = construct_election_panel(tax_panel)
    election_merged.to_csv(ELECTION_MERGED_PATH, index=False)
    rejection_analysis, rejection_models = estimate_rejection_risk_models(election_merged)
    rejection_models.to_csv(REJECTION_MODEL_PATH, index=False)
    analysis, models, effects = estimate_disclosure_models(merged)
    models.to_csv(MODEL_PATH, index=False)
    effects.to_csv(EFFECT_PATH, index=False)
    write_summary(
        tax_panel,
        analysis,
        models,
        effects,
        rejection_analysis,
        rejection_models,
    )

    print(f"Wrote tax panel: {TAX_PANEL_PATH}")
    print(f"Wrote merged disclosure panel: {MERGED_PANEL_PATH}")
    print(f"Wrote merged election panel: {ELECTION_MERGED_PATH}")
    print(f"Wrote model results: {MODEL_PATH}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
