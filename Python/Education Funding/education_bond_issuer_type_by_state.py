"""
Summarize who issues education-purpose municipal bonds by state.

This script uses the cleaned Mergent CUSIP-level file and asks, among bonds
whose use of proceeds is education, what fraction are issued by school
districts, cities, counties, or other issuer types.
"""

from pathlib import Path

import pandas as pd


ROOT = Path("/Users/kmunevar/Dropbox/Voting on Bonds")
# Use the broader city/county/school CUSIP-level file, not the city-only
# issuer-level regression file, because this exercise is about institutional
# assignment of education issuance across issuer types.
INPUT_FILE = ROOT / "Data/Mergent/Clean/250605_citycountyschool_cusiplevel_statereq_purpose.dta"
OUT_DIR = ROOT / "Data/Mergent/Education Funding"
OUT_DIR.mkdir(parents=True, exist_ok=True)

SUMMARY_FILE = OUT_DIR / "260707_education_bond_issuer_type_by_state.csv"
STATE_DETAIL_FILE = OUT_DIR / "260707_education_bond_issuer_type_state_details.csv"


def safe_flag(frame: pd.DataFrame, col: str) -> pd.Series:
    if col not in frame.columns:
        return pd.Series(False, index=frame.index)
    return frame[col].fillna(0).astype(float).eq(1)


def main() -> None:
    usecols = [
        "state",
        "cusip",
        "issue_id",
        "seed_issuer",
        "seed_issuer_id",
        "issuer_type",
        "city",
        "county",
        "school",
        "amount",
        "use_proceeds",
        "purp_broad",
        "purp_broad_educ",
        "purpose_csed",
        "purpose_hied",
        "purpose_oted",
        "purpose_psed",
    ]

    data = pd.read_stata(INPUT_FILE, columns=usecols)

    detailed_education = (
        safe_flag(data, "purpose_csed")
        | safe_flag(data, "purpose_hied")
        | safe_flag(data, "purpose_oted")
        | safe_flag(data, "purpose_psed")
    )
    broad_education = safe_flag(data, "purp_broad_educ") | data["purp_broad"].fillna("").eq("educ")
    data["education_bond"] = broad_education | detailed_education

    education = data.loc[data["education_bond"]].copy()
    education["amount"] = education["amount"].fillna(0)

    education["issuer_group"] = "Other"
    education.loc[safe_flag(education, "school"), "issuer_group"] = "School"
    education.loc[safe_flag(education, "county"), "issuer_group"] = "County"
    education.loc[safe_flag(education, "city"), "issuer_group"] = "City"

    # If multiple flags are ever set, keep a diagnostic rather than hiding it.
    education["n_issuer_flags"] = (
        safe_flag(education, "school").astype(int)
        + safe_flag(education, "county").astype(int)
        + safe_flag(education, "city").astype(int)
    )

    group_summary = (
        education.groupby(["state", "issuer_group"], dropna=False)
        .agg(
            n_bonds=("cusip", "size"),
            n_issues=("issue_id", "nunique"),
            n_issuers=("seed_issuer_id", "nunique"),
            amount=("amount", "sum"),
        )
        .reset_index()
    )

    state_totals = (
        education.groupby("state", dropna=False)
        .agg(
            state_n_bonds=("cusip", "size"),
            state_n_issues=("issue_id", "nunique"),
            state_n_issuers=("seed_issuer_id", "nunique"),
            state_amount=("amount", "sum"),
            n_multiple_issuer_flags=("n_issuer_flags", lambda s: int((s > 1).sum())),
            n_missing_issuer_flags=("n_issuer_flags", lambda s: int((s == 0).sum())),
        )
        .reset_index()
    )

    summary = group_summary.merge(state_totals, on="state", how="left")
    summary["pct_bonds"] = 100 * summary["n_bonds"] / summary["state_n_bonds"]
    summary["pct_amount"] = 100 * summary["amount"] / summary["state_amount"]

    wide_counts = summary.pivot(index="state", columns="issuer_group", values="n_bonds").fillna(0)
    wide_pcts = summary.pivot(index="state", columns="issuer_group", values="pct_bonds").fillna(0)
    wide_amount_pcts = summary.pivot(index="state", columns="issuer_group", values="pct_amount").fillna(0)

    for col in ["School", "City", "County", "Other"]:
        if col not in wide_counts:
            wide_counts[col] = 0
        if col not in wide_pcts:
            wide_pcts[col] = 0
        if col not in wide_amount_pcts:
            wide_amount_pcts[col] = 0

    state_detail = state_totals.set_index("state").join(
        wide_counts[["School", "City", "County", "Other"]].add_prefix("n_bonds_")
    )
    state_detail = state_detail.join(
        wide_pcts[["School", "City", "County", "Other"]].add_prefix("pct_bonds_")
    )
    state_detail = state_detail.join(
        wide_amount_pcts[["School", "City", "County", "Other"]].add_prefix("pct_amount_")
    )
    state_detail = state_detail.reset_index()
    state_detail["mostly_non_school_education_issuance"] = state_detail["pct_bonds_School"].lt(50)

    round_cols = [c for c in summary.columns if c.startswith("pct_")]
    summary[round_cols] = summary[round_cols].round(2)
    round_cols = [c for c in state_detail.columns if c.startswith("pct_")]
    state_detail[round_cols] = state_detail[round_cols].round(2)

    summary = summary.sort_values(["state", "issuer_group"])
    state_detail = state_detail.sort_values(["pct_bonds_School", "state"])

    summary.to_csv(SUMMARY_FILE, index=False)
    state_detail.to_csv(STATE_DETAIL_FILE, index=False)

    print(f"Input file: {INPUT_FILE}")
    print(f"Wrote {SUMMARY_FILE}")
    print(f"Wrote {STATE_DETAIL_FILE}")
    print("\nStates with mostly non-school education bond issuance:")
    cols = [
        "state",
        "state_n_bonds",
        "pct_bonds_School",
        "pct_bonds_City",
        "pct_bonds_County",
        "pct_bonds_Other",
        "mostly_non_school_education_issuance",
    ]
    print(state_detail.loc[state_detail["mostly_non_school_education_issuance"], cols].to_string(index=False))


if __name__ == "__main__":
    main()
