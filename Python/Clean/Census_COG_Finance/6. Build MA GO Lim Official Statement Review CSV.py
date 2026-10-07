"""Create an issue-level official-statement review queue for MA 2017 GO-limited debt.

The file has one deterministic representative CUSIP (earliest maturity, then CUSIP)
per Mergent issue.  It is intended for a manual check of Mergent's GO-limited
classification against the offering document.
"""

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
MERGENT = ROOT / "Data/Mergent/Clean/260923_cusiplevel_allbonds_inclrefund.dta"
AUDIT_DIR = ROOT / "Data/MA LTGO Bonds/audit"
OUTPUT = ROOT / "Data/MA LTGO Bonds/OS/ma_2017_go_lim_official_statement_review.csv"


def representative_cusips(issue_ids: set[int]) -> pd.DataFrame:
    """Stream the large maturity-level file and retain one CUSIP per target issue."""
    selected = []
    reader = pd.read_stata(
        MERGENT,
        columns=["issue_id", "cusip", "maturity_date", "amount"],
        convert_categoricals=False,
        chunksize=250_000,
    )
    for chunk in reader:
        chunk["issue_id"] = pd.to_numeric(chunk["issue_id"], errors="coerce").astype("Int64")
        chunk = chunk[chunk["issue_id"].isin(issue_ids)].copy()
        if chunk.empty:
            continue
        chunk["cusip"] = chunk["cusip"].fillna("").astype(str).str.upper().str.strip()
        chunk["maturity_date"] = pd.to_datetime(chunk["maturity_date"], errors="coerce")
        chunk["amount"] = pd.to_numeric(chunk["amount"], errors="coerce")
        selected.append(chunk)

    cusips = pd.concat(selected, ignore_index=True)
    cusips = cusips[cusips["cusip"].ne("")].copy()
    cusips = cusips.sort_values(["issue_id", "maturity_date", "cusip"], na_position="last")
    cusips = cusips.drop_duplicates("issue_id", keep="first")
    return cusips.rename(
        columns={
            "cusip": "representative_cusip",
            "maturity_date": "representative_cusip_maturity_date",
            "amount": "representative_cusip_par",
        }
    )


def main() -> None:
    issues = pd.read_csv(AUDIT_DIR / "ma_go_issue_universe.csv", parse_dates=["offering_date", "final_maturity_date"])
    issues = issues[(issues["outstanding_at_2017"]) & (issues["classification"].eq("go_lim"))].copy()
    issues["issue_id"] = pd.to_numeric(issues["issue_id"], errors="raise").astype(int)

    matches = pd.read_csv(AUDIT_DIR / "ma_debt_exclusion_bond_best_matches.csv", parse_dates=["vote_date"])
    matches = matches[[
        "issue_id", "match_confidence", "match_score", "vote_date", "vote_description", "department",
        "days_from_vote_to_issue", "purpose_category_match", "shared_purpose_tokens",
    ]]
    matches["issue_id"] = pd.to_numeric(matches["issue_id"], errors="raise").astype(int)
    issues = issues.merge(matches, on="issue_id", how="left", validate="one_to_one")
    issues = issues.merge(representative_cusips(set(issues["issue_id"])), on="issue_id", how="left", validate="one_to_one")

    if len(issues) != 1685:
        raise ValueError(f"Expected 1,685 MA 2017 go_lim issues; found {len(issues):,}.")
    if issues["representative_cusip"].isna().any():
        missing = issues.loc[issues["representative_cusip"].isna(), "issue_id"].tolist()
        raise ValueError(f"Missing representative CUSIP for issue(s): {missing}")

    issues["explicit_unlimited_tax_in_description"] = issues["issue_description"].str.contains(
        "UNLIMITED TAX", case=False, na=False
    )
    issues["explicit_refunding_label"] = issues["issue_description"].str.contains(
        "REFUND", case=False, na=False
    )
    issues["review_priority"] = "Standard review"
    issues.loc[issues["match_confidence"].eq("medium"), "review_priority"] = "Medium vote-project match"
    issues.loc[issues["match_confidence"].eq("high"), "review_priority"] = "High vote-project match"
    issues.loc[issues["explicit_unlimited_tax_in_description"], "review_priority"] = (
        "Mergent text says unlimited tax"
    )

    issues["official_statement_file"] = ""
    issues["official_statement_url"] = ""
    issues["os_tax_pledge"] = ""
    issues["corrected_classification"] = ""
    issues["review_status"] = "Not started"
    issues["reviewer_notes"] = ""

    columns = [
        "issue_id", "representative_cusip", "representative_cusip_maturity_date", "representative_cusip_par",
        "issuer_long_name", "issue_description", "series", "offering_date", "final_maturity_date", "original_par",
        "new_money", "explicit_refunding_label", "go_lim", "go_unlim", "security_code",
        "explicit_unlimited_tax_in_description", "review_priority", "match_confidence", "match_score",
        "vote_date", "vote_description", "department", "days_from_vote_to_issue",
        "purpose_category_match", "shared_purpose_tokens", "official_statement_file", "official_statement_url",
        "os_tax_pledge", "corrected_classification", "review_status", "reviewer_notes",
    ]
    output = issues[columns].sort_values(
        ["review_priority", "offering_date", "issuer_long_name", "issue_id"],
        ascending=[True, False, True, True],
    )
    date_cols = ["representative_cusip_maturity_date", "offering_date", "final_maturity_date", "vote_date"]
    for col in date_cols:
        output[col] = pd.to_datetime(output[col], errors="coerce").dt.strftime("%Y-%m-%d")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.to_csv(OUTPUT, index=False)
    print(f"Wrote {len(output):,} issues to {OUTPUT}")
    print(f"CUSIPs present: {output['representative_cusip'].notna().sum():,}")


if __name__ == "__main__":
    main()
