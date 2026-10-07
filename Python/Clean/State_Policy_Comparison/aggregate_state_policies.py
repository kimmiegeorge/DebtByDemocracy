"""Build state-level fiscal-policy variables and the Reviewer R3 comparison table.

The outputs are keyed by two-letter postal abbreviation (`state_abbr`).  Keep
the raw policy fields when merging: the binary indicators are useful for a
compact table, but state laws contain consequential exceptions and overrides.
"""

from __future__ import annotations

from pathlib import Path
import re

import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
STATUTES = ROOT / "Data" / "Statutes"
POLICY_DIR = ROOT / "Data" / "State Policies"
SCRIPT_DIR = Path(__file__).resolve().parent
ADDNL_POLICY_DIR = ROOT / "Data" / "Addnl State Policy Data"

VOTE_FILE = STATUTES / "2026-07-23_City laws by state.xlsx"
DEBT_FILE = STATUTES / "2026-09-26_City debt limits by state.xlsx"
MONITOR_FILE = ROOT / "Data" / "State Monitoring Policy" / "state_enforcement_adoption_years.csv"
TEL_FILE = ADDNL_POLICY_DIR / "wen_municipal_tel_index_2020.csv"
LINCOLN_FEATURES_FILE = ADDNL_POLICY_DIR / "lincoln_property_tax_limit_features_2024.csv"
GASB_FILE = ADDNL_POLICY_DIR / "gasb_municipal_gaap_requirements_2025.csv"
AUDIT_FILE = ADDNL_POLICY_DIR / "nasact_state_audit_requirements_2023.csv"
GFOA_AWARD_DIR = ROOT / "Data" / "GFOA Awards" / "analysis" / "city_year_pafr"
GFOA_AWARD_PANEL = GFOA_AWARD_DIR / "city_year_gfoa_awards_panel.csv"

STATE_NAMES = {
    "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
    "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
    "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho",
    "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
    "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
    "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
    "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
    "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
    "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
    "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
    "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
    "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
    "WI": "Wisconsin", "WY": "Wyoming",
}

LINCOLN_URL = (
    "https://apps.lincolninst.edu/data/significant-features-property-tax/"
    "access-database/tax-limits-truth-taxation/report"
)


def source_rows(path: Path, sheet: str, header_row: int) -> pd.DataFrame:
    """Read a workbook whose display header is below introductory rows."""
    # The statutory workbooks use literal `None` and `N/A` policy codes.  Do
    # not let pandas silently convert those substantive values to missing.
    return pd.read_excel(path, sheet_name=sheet, header=header_row, keep_default_na=False)


def clean_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = [str(c).strip() for c in df.columns]
    df = df.replace(r"^\s*$", pd.NA, regex=True)
    return df.dropna(how="all")


def make_vote_data() -> pd.DataFrame:
    vote = clean_columns(source_rows(VOTE_FILE, "Input", 4))
    vote = vote.loc[vote["State"].notna(), ["State", "GO", "Revenue", "Year began", "Control"]].copy()
    vote = vote.rename(columns={
        "State": "state_abbr", "GO": "go_vote_rule", "Revenue": "revenue_vote_rule",
        "Year began": "go_vote_year_began", "Control": "source_control_flag",
    })
    vote["state_abbr"] = vote["state_abbr"].str.strip()
    numeric_rule = pd.to_numeric(vote["go_vote_rule"], errors="coerce")
    vote["go_vote_required"] = (
        vote["go_vote_rule"].astype(str).str.contains(r"Majority|2/3|4/7|60%", regex=True)
        | numeric_rule.eq(0.6)
    ).astype("Int64")
    vote.loc[vote["go_vote_rule"].isin(["None", "Depends", "N/A", "60% to depends"]), "go_vote_required"] = pd.NA
    vote.loc[vote["go_vote_rule"].eq("None"), "go_vote_required"] = 0
    vote["eligible_go_vote_comparison"] = (
        vote["go_vote_rule"].isin(
        ["Majority", "2/3", "Majority for UTGO", "4/7 or 2/3", "60%", "60% for UTGO", "None"]
        ) | numeric_rule.eq(0.6)
    ).astype("Int64")
    vote["referendum_group"] = "within-state variation / not eligible"
    vote.loc[vote["go_vote_required"].eq(1), "referendum_group"] = "GO vote required"
    vote.loc[vote["go_vote_required"].eq(0), "referendum_group"] = "no GO vote required"
    return vote


def make_debt_data() -> pd.DataFrame:
    debt = clean_columns(source_rows(DEBT_FILE, "Input", 4))
    debt = debt.loc[debt["State"].notna(), [
        "State", "Debt limit", "Debt limit type", "Close-to-market or artificially lower",
        "Can exceed", "Vote required to exceed", "Details", "Exceptions", "Sources", "Source link",
    ]].copy()
    debt = debt.rename(columns={
        "State": "state_abbr", "Debt limit": "debt_limit_rule", "Debt limit type": "debt_limit_type",
        "Close-to-market or artificially lower": "debt_limit_valuation_basis",
        "Can exceed": "debt_limit_can_exceed", "Vote required to exceed": "debt_limit_vote_to_exceed",
        "Details": "debt_limit_details", "Exceptions": "debt_limit_exceptions",
        "Sources": "debt_limit_source", "Source link": "debt_limit_source_url",
    })
    debt["state_abbr"] = debt["state_abbr"].str.strip()
    debt["municipal_debt_limit"] = debt["debt_limit_rule"].eq("Yes").astype("Int64")
    debt.loc[debt["debt_limit_rule"].isin(["Depends", "N/A"]), "municipal_debt_limit"] = pd.NA
    debt["debt_limit_close_to_market_valuation"] = debt["debt_limit_valuation_basis"].eq("Close-to-market").astype("Int64")
    debt.loc[debt["municipal_debt_limit"].isna() | debt["municipal_debt_limit"].eq(0), "debt_limit_close_to_market_valuation"] = pd.NA
    debt["debt_limit_can_be_exceeded"] = debt["debt_limit_can_exceed"].eq("Yes").astype("Int64")
    debt.loc[~debt["debt_limit_can_exceed"].isin(["Yes", "No"]), "debt_limit_can_be_exceeded"] = pd.NA
    debt["debt_limit_voter_override"] = debt["debt_limit_vote_to_exceed"].eq("Yes").astype("Int64")
    debt.loc[~debt["debt_limit_vote_to_exceed"].isin(["Yes", "No"]), "debt_limit_voter_override"] = pd.NA
    # If the limit cannot be exceeded, a voter override is not available.
    debt.loc[debt["debt_limit_can_be_exceeded"].eq(0), "debt_limit_voter_override"] = 0
    debt["debt_limit_exempts_revenue_bonds"] = debt["debt_limit_exceptions"].str.contains("revenue bond", case=False, na=False).astype("Int64")
    debt.loc[debt["municipal_debt_limit"].isna() | debt["municipal_debt_limit"].eq(0), "debt_limit_exempts_revenue_bonds"] = pd.NA

    strict = clean_columns(source_rows(DEBT_FILE, "Output_Full", 1))
    strict = strict.loc[strict["State"].notna(), ["State", "Stricter debt limit (def. as <= 5% if market or <= 10% if below-market)"]]
    strict = strict.rename(columns={
        "State": "state_abbr",
        "Stricter debt limit (def. as <= 5% if market or <= 10% if below-market)": "strict_municipal_debt_limit",
    })
    strict["state_abbr"] = strict["state_abbr"].str.strip()
    debt = debt.merge(strict, on="state_abbr", how="left", validate="one_to_one")
    # Code Nebraska as non-strict to match the main debt-choice regressions.
    debt.loc[debt["state_abbr"].eq("NE"), "strict_municipal_debt_limit"] = 0
    return debt


def make_monitor_data() -> pd.DataFrame:
    monitor = pd.read_csv(MONITOR_FILE).rename(columns={
        "Abbreviation": "state_abbr", "AdoptionYear": "fiscal_monitor_adoption_year",
    })
    monitor = monitor[["state_abbr", "fiscal_monitor_adoption_year"]].copy()
    all_states = pd.DataFrame({"state_abbr": list(STATE_NAMES)})
    monitor = all_states.merge(monitor, on="state_abbr", how="left", validate="one_to_one")
    monitor["fiscal_monitor_adoption_year"] = monitor["fiscal_monitor_adoption_year"].fillna("not adopted")

    def in_force(year: int) -> pd.Series:
        numeric_year = pd.to_numeric(monitor["fiscal_monitor_adoption_year"], errors="coerce")
        return ((monitor["fiscal_monitor_adoption_year"].eq("before_sample")) | (numeric_year <= year)).astype("Int64")

    monitor["state_fiscal_monitor_2017"] = in_force(2017)
    monitor["state_fiscal_monitor_2020"] = in_force(2020)
    return monitor


def make_monitor_panel(monitor: pd.DataFrame) -> pd.DataFrame:
    years = pd.DataFrame({"year": range(2000, 2021)})
    panel = monitor[["state_abbr", "fiscal_monitor_adoption_year"]].merge(years, how="cross")
    adoption = pd.to_numeric(panel["fiscal_monitor_adoption_year"], errors="coerce")
    panel["state_fiscal_monitor"] = (
        panel["fiscal_monitor_adoption_year"].eq("before_sample") | (adoption <= panel["year"])
    ).astype("Int64")
    return panel


def make_gasb_municipal_gaap_data() -> pd.DataFrame:
    """Load GASB's city (municipal), not state-government, GAAP categories."""
    gasb = pd.read_csv(GASB_FILE)
    return gasb[[
        "state_abbr", "gasb_municipal_gaap_requirement_category",
        "gasb_municipal_gaap_required_any", "gasb_municipal_gaap_required_no_exception",
    ]]


def make_audit_data() -> pd.DataFrame:
    """Derive auditable binary indicators while retaining the source's full text."""
    audit = pd.read_csv(AUDIT_FILE, keep_default_na=False)
    audit = audit.rename(columns={
        "audits_local_governments": "nasact_audits_local_governments_raw",
        "cities_towns_&_villages": "nasact_audits_cities_towns_villages_raw",
        "gaap_required_for_local_government_financial_statements": "nasact_local_gaap_requirement_raw",
        "audit_standards_used": "nasact_audit_standards_raw",
    })

    def checkmark_indicator(values: pd.Series) -> pd.Series:
        result = pd.Series(pd.NA, index=values.index, dtype="Int64")
        result.loc[values.astype(str).str.contains("✓", regex=False)] = 1
        result.loc[values.astype(str).str.contains("✕", regex=False) & result.isna()] = 0
        return result

    audit["nasact_audits_local_governments"] = checkmark_indicator(
        audit["nasact_audits_local_governments_raw"]
    )
    audit["nasact_audits_cities_towns_villages"] = checkmark_indicator(
        audit["nasact_audits_cities_towns_villages_raw"]
    )
    return audit.drop(columns="state_name")


def make_gfoa_award_rate_data() -> tuple[pd.DataFrame, pd.DataFrame]:
    """Calculate annual and period-average GFOA rates in the GO-city universe.

    The COA public archive/AMS transition is incomplete in FY2019.  COA and
    either-award rates are therefore missing for that fiscal year rather than
    treating unmatched cities as nonrecipients.  PAFR is observed throughout
    FY2014--2020.  The state average is the unweighted mean of valid annual
    rates; this equals the pooled rate here because the city universe is a
    balanced panel within each state.
    """
    panel = pd.read_csv(GFOA_AWARD_PANEL)
    required_columns = {
        "city_id", "state", "fiscal_year", "coa_award", "pafr_award",
        "either_gfoa_award", "coa_award_coverage",
    }
    missing_columns = required_columns.difference(panel.columns)
    if missing_columns:
        raise ValueError(
            "GFOA city-year panel is missing required columns: "
            + ", ".join(sorted(missing_columns))
        )

    panel = panel.loc[panel["state"].notna()].copy()
    state_year = (
        panel.groupby(["state", "fiscal_year"], as_index=False)
        .agg(
            gfoa_go_city_count=("city_id", "size"),
            gfoa_coa_award_city_count=("coa_award", lambda values: values.eq(1).sum()),
            gfoa_pafr_award_city_count=("pafr_award", lambda values: values.eq(1).sum()),
            gfoa_either_award_city_count=("either_gfoa_award", lambda values: values.eq(1).sum()),
            gfoa_coa_award_rate=("coa_award", "mean"),
            gfoa_pafr_award_rate=("pafr_award", "mean"),
            gfoa_either_award_rate=("either_gfoa_award", "mean"),
            gfoa_coa_source_complete=(
                "coa_award_coverage",
                lambda values: values.eq("public_GFOA_source_collected").all(),
            ),
        )
        .rename(columns={"state": "state_abbr"})
    )
    state_year["gfoa_coa_source_complete"] = state_year["gfoa_coa_source_complete"].astype("Int64")
    incomplete_coa = state_year["gfoa_coa_source_complete"].eq(0)
    state_year.loc[incomplete_coa, ["gfoa_coa_award_rate", "gfoa_either_award_rate"]] = pd.NA

    # Hawaii has no city in the project's GO-issuance universe.  Retain its
    # seven state-year rows with a zero denominator and undefined rates so the
    # descriptive output has an explicit 50-state by seven-year grid.
    all_state_years = pd.MultiIndex.from_product(
        [list(STATE_NAMES), sorted(panel["fiscal_year"].unique())],
        names=["state_abbr", "fiscal_year"],
    ).to_frame(index=False)
    state_year = all_state_years.merge(
        state_year, on=["state_abbr", "fiscal_year"], how="left", validate="one_to_one"
    )
    count_columns = [
        "gfoa_go_city_count", "gfoa_coa_award_city_count",
        "gfoa_pafr_award_city_count", "gfoa_either_award_city_count",
    ]
    state_year[count_columns] = state_year[count_columns].fillna(0).astype("Int64")
    no_go_city_sample = state_year["gfoa_go_city_count"].eq(0)
    state_year.loc[no_go_city_sample, [
        "gfoa_coa_award_rate", "gfoa_pafr_award_rate", "gfoa_either_award_rate",
        "gfoa_coa_source_complete",
    ]] = pd.NA
    state_year["gfoa_coa_source_complete"] = state_year["gfoa_coa_source_complete"].astype("Int64")

    averages = (
        state_year.groupby("state_abbr", as_index=False)
        .agg(
            gfoa_go_city_count=("gfoa_go_city_count", "mean"),
            gfoa_coa_award_rate_mean_valid_fy2014_2020=("gfoa_coa_award_rate", "mean"),
            gfoa_coa_award_rate_years_observed=("gfoa_coa_award_rate", "count"),
            gfoa_pafr_award_rate_mean_fy2014_2020=("gfoa_pafr_award_rate", "mean"),
            gfoa_pafr_award_rate_years_observed=("gfoa_pafr_award_rate", "count"),
            gfoa_either_award_rate_mean_valid_fy2014_2020=("gfoa_either_award_rate", "mean"),
            gfoa_either_award_rate_years_observed=("gfoa_either_award_rate", "count"),
        )
    )
    averages["gfoa_go_city_count"] = averages["gfoa_go_city_count"].astype("Int64")
    return state_year.sort_values(["state_abbr", "fiscal_year"]), averages.sort_values("state_abbr")


def escape_tex(value: object) -> str:
    return str(value).replace("%", r"\%").replace("_", r"\_").replace("&", r"\&")


def render_table(state: pd.DataFrame) -> str:
    eligible = state.loc[state["eligible_go_vote_comparison"].eq(1)].copy()
    referendum = eligible.loc[eligible["go_vote_required"].eq(1)]
    control = eligible.loc[eligible["go_vote_required"].eq(0)]

    rows = [
        ("States", None, "count"),
        ("Debt-limit variables", None, "category"),
        ("Any municipal debt limit", "municipal_debt_limit", "share"),
        ("Strict municipal debt limit", "strict_municipal_debt_limit", "share"),
        ("Debt limit can be exceeded", "debt_limit_can_be_exceeded", "share"),
        ("Tax-related variables", None, "category"),
        ("Property-tax levy cap", "lincoln_property_tax_levy_cap_2024", "share"),
        ("Referendum required to exceed property-tax levy cap", "lincoln_property_tax_levy_override_requires_voter_approval_2024", "share"),
        ("Broad municipal revenue/expenditure cap", "lincoln_broad_municipal_budget_limit_2022", "share"),
        ("Truth-in-Taxation requirement", "lincoln_truth_in_taxation_2024", "share"),
        ("Governing-body vote for tax increase", "lincoln_governing_body_vote_for_tax_increase_2024", "share"),
        ("Financial reporting and oversight variables", None, "category"),
        ("State fiscal monitor in place by 2020", "state_fiscal_monitor_2020", "share"),
        ("Municipal GAAP required", "gasb_municipal_gaap_required_any", "share"),
        ("State auditor audits cities/towns/villages", "nasact_audits_cities_towns_villages", "share"),
        ("COA recipient rate among GO-bond cities (annual mean)", "gfoa_coa_award_rate_mean_valid_fy2014_2020", "share"),
        ("PAFR recipient rate among GO-bond cities (annual mean)", "gfoa_pafr_award_rate_mean_fy2014_2020", "share"),
    ]
    lines = [
        r"\begin{table}[!htbp]\centering",
        r"\caption{State-level fiscal-policy comparison}",
        r"\label{tab:r3_state_policy_comparison}",
        r"\small",
        r"\begin{tabular}{lccc}",
        r"\toprule",
        r" & GO-vote & No-GO-vote & Difference \\",
        r" & required & requirement & (GO vote $-$ no GO vote) \\",
        r"\midrule",
    ]
    row_end = r"\\"
    for label, column, kind in rows:
        if kind == "category":
            lines.extend([
                r"\addlinespace[2pt]",
                f"\\multicolumn{{4}}{{l}}{{\\textit{{{label}}}}} {row_end}",
            ])
        elif kind == "count":
            ref_value, control_value = len(referendum), len(control)
            difference = ref_value - control_value
            lines.append(f"{label} & {ref_value:d} & {control_value:d} & {difference:d} {row_end}")
        else:
            ref_value = referendum[column].mean()
            control_value = control[column].mean()
            difference = ref_value - control_value
            if kind == "share":
                ref_n = referendum[column].notna().sum()
                control_n = control[column].notna().sum()
                display = [
                    f"{100 * ref_value:.1f}\\% [N={ref_n}]",
                    f"{100 * control_value:.1f}\\% [N={control_n}]",
                    f"{100 * difference:.1f}\\%",
                ]
            else:
                display = [f"{value:.1f}" for value in (ref_value, control_value, difference)]
            lines.append(f"{label} & {display[0]} & {display[1]} & {display[2]} {row_end}")
    lines.extend([
        r"\bottomrule",
        r"\end{tabular}",
        r"\end{table}",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    POLICY_DIR.mkdir(parents=True, exist_ok=True)
    states = pd.DataFrame(
        {"state_abbr": list(STATE_NAMES.keys()), "state_name": list(STATE_NAMES.values())}
    )
    states = states.merge(make_vote_data(), on="state_abbr", how="left", validate="one_to_one")
    states = states.merge(make_debt_data(), on="state_abbr", how="left", validate="one_to_one")
    monitor = make_monitor_data()
    states = states.merge(monitor, on="state_abbr", how="left", validate="one_to_one")
    tel = pd.read_csv(TEL_FILE).rename(columns={"state": "state_abbr"})
    states = states.merge(tel, on="state_abbr", how="left", validate="one_to_one")
    states = states.merge(pd.read_csv(LINCOLN_FEATURES_FILE), on="state_abbr", how="left", validate="one_to_one")
    states = states.merge(make_gasb_municipal_gaap_data(), on="state_abbr", how="left", validate="one_to_one")
    states = states.merge(make_audit_data(), on="state_abbr", how="left", validate="one_to_one")
    state_year_awards, award_rate_averages = make_gfoa_award_rate_data()
    states = states.merge(award_rate_averages, on="state_abbr", how="left", validate="one_to_one")
    states = states.rename(columns={"source": "municipal_tel_source"})
    states["municipal_tel_any_2012"] = (states["municipal_tel_index"] > 0).astype("Int64")
    states["municipal_tel_source_url"] = LINCOLN_URL
    states["state_policy_build_date"] = "2026-09-29"

    # Keep a predictable merge key and then alphabetize the remaining fields.
    columns = ["state_abbr", "state_name"] + sorted(c for c in states.columns if c not in {"state_abbr", "state_name"})
    states = states[columns].sort_values("state_abbr")
    state_output = POLICY_DIR / "20260929_state_policy_comparison.csv"
    states.to_csv(state_output, index=False)

    state_year_award_output = GFOA_AWARD_DIR / "state_year_gfoa_award_rates.csv"
    state_year_awards.to_csv(state_year_award_output, index=False)
    state_award_average_output = GFOA_AWARD_DIR / "state_gfoa_award_rate_averages.csv"
    award_rate_averages.to_csv(state_award_average_output, index=False)

    panel_output = POLICY_DIR / "20260929_state_fiscal_monitor_2000_2020.csv"
    make_monitor_panel(monitor).sort_values(["state_abbr", "year"]).to_csv(panel_output, index=False)

    table_output = POLICY_DIR / "20260929_state_policy_comparison_table.tex"
    table_output.write_text(render_table(states), encoding="utf-8")

    expected_states = set(STATE_NAMES)
    if set(states["state_abbr"]) != expected_states:
        raise ValueError("State-level output does not contain exactly the 50 states.")
    if states["municipal_tel_index"].isna().any():
        raise ValueError("At least one state lacks a municipal TEL index.")
    print(f"Wrote {state_output}")
    print(f"Wrote {state_year_award_output}")
    print(f"Wrote {state_award_average_output}")
    print(f"Wrote {panel_output}")
    print(f"Wrote {table_output}")


if __name__ == "__main__":
    main()
