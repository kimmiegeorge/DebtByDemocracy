"""Audit Massachusetts Mergent GO classifications against DLS debt-exclusion votes.

The DLS debt-exclusion report records local Proposition 2 1/2 ballot outcomes,
including the vote date, project description, and department.  This script
downloads its public Excel export and produces an issue-level review file for
Massachusetts Mergent GO bonds.  A match is a *candidate* relationship, not a
legal reclassification: DLS debt exclusions concern levy-limit capacity, while
Mergent's GO flags describe the stated security.

Outputs (under Data/MA LTGO Bonds/audit):
    - dls_debt_exclusion_votes_raw.csv
    - ma_debt_exclusion_bond_candidates.csv
    - ma_debt_exclusion_bond_best_matches.csv
    - ma_debt_exclusion_classification_summary.csv

Run from the repository root:
    python3 'Code/Python/Clean/Census_COG_Finance/5. Audit Massachusetts Debt Exclusions.py'
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen

import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
MERGENT = ROOT / "Data" / "Mergent" / "Clean" / "260923_cusiplevel_allbonds_inclrefund.dta"
OUT = ROOT / "Data" / "MA LTGO Bonds" / "audit"
DLS_URL = (
    "https://dls-gw.dor.state.ma.us/reports/rdpage.aspx?"
    "rdReport=Votes.Prop2_5.DebtExclusionVotes&rdReportFormat=NativeExcel&"
    "rdExportTableID=tblProp2_5Votes&rdExportFilename=AllDebtExclusionResults&"
    "rdShowGridlines=True&rdExcelOutputFormat=Excel2007"
)
AS_OF = pd.Timestamp("2017-12-31")
MAX_VOTE_LAG_DAYS = 7 * 365

STOPWORDS = {
    "and", "the", "for", "of", "to", "a", "an", "in", "on", "by", "with",
    "bond", "bonds", "loan", "municipal", "purpose", "general", "obligation",
    "construct", "construction", "purchase", "acquire", "new", "project",
    "town", "city", "mass", "massachusetts",
}


def canonical_name(value: object) -> str:
    """Normalize a Massachusetts municipality or issuer name for exact matching."""
    text = unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode()
    text = text.upper()
    text = re.sub(r"\b(CITY|TOWN)\s+OF\b", "", text)
    text = re.sub(r"\b(MASSACHUSETTS|MASS|MA)\b", "", text)
    text = re.sub(r"\b(CITY|TOWN)\b", "", text)
    text = re.sub(r"[^A-Z0-9]+", " ", text)
    return " ".join(text.split())


def tokens(value: object) -> set[str]:
    text = unicodedata.normalize("NFKD", str(value or "")).encode("ascii", "ignore").decode().lower()
    return {word for word in re.findall(r"[a-z0-9]{3,}", text) if word not in STOPWORDS}


def issue_purpose_flags(text: str, use_proceeds: str) -> set[str]:
    text = f"{text} {use_proceeds}".lower()
    flags: set[str] = set()
    if "school" in text or "education" in text or "psed" in text:
        flags.add("school")
    if any(word in text for word in ("police", "fire", "safety", "pole", "gvpb")):
        flags.add("public_safety")
    if any(word in text for word in ("water", "sewer", "wtr", "swr")):
        flags.add("water_sewer")
    if any(word in text for word in ("library", "park", "recreation", "culture")):
        flags.add("culture_recreation")
    if any(word in text for word in ("road", "street", "bridge", "highway", "transport")):
        flags.add("transportation")
    return flags


def vote_purpose_flags(description: str, department: str) -> set[str]:
    text = f"{description} {department}".lower()
    flags: set[str] = set()
    if "school" in text or "education" in text:
        flags.add("school")
    if any(word in text for word in ("police", "fire", "safety")):
        flags.add("public_safety")
    if any(word in text for word in ("water", "sewer")):
        flags.add("water_sewer")
    if any(word in text for word in ("library", "park", "recreation", "culture")):
        flags.add("culture_recreation")
    if any(word in text for word in ("road", "street", "bridge", "highway", "transport")):
        flags.add("transportation")
    return flags


def read_dls_votes(source: str | None = None) -> pd.DataFrame:
    """Read and standardize DLS's statewide debt-exclusion export.

    ``source`` may be a local XLSX path or ``-`` for an XLSX piped on stdin.
    With no source it downloads the public DLS export directly.
    """
    if source == "-":
        payload = sys.stdin.buffer.read()
    elif source:
        payload = Path(source).read_bytes()
    else:
        with urlopen(DLS_URL, timeout=120) as response:
            payload = response.read()
    raw = pd.read_excel(BytesIO(payload))
    raw.columns = [str(column).strip().lower().replace(" ", "_").replace("/", "_") for column in raw.columns]
    needed = {
        "dor_code": "dor_code",
        "municipality": "municipality",
        "fiscal_year": "fiscal_year",
        "vote_date": "vote_date",
        "description": "vote_description",
        "department": "department",
        "win___loss": "win_loss",
        "number_yes": "yes_votes",
        "number_no": "no_votes",
    }
    missing = [column for column in needed if column not in raw.columns]
    if missing:
        raise ValueError(f"Unexpected DLS export columns; missing {missing}. Found {raw.columns.tolist()}")
    votes = raw.rename(columns=needed)[list(needed.values())].copy()
    votes["vote_date"] = pd.to_datetime(votes["vote_date"], errors="coerce")
    votes["fiscal_year"] = pd.to_numeric(votes["fiscal_year"], errors="coerce")
    votes["result"] = votes["win_loss"].astype(str).str.strip().str.upper()
    votes["municipality_key"] = votes["municipality"].map(canonical_name)
    votes["vote_tokens"] = (votes["vote_description"].fillna("") + " " + votes["department"].fillna("")).map(tokens)
    votes["vote_purpose_flags"] = votes.apply(
        lambda row: vote_purpose_flags(row["vote_description"], row["department"]), axis=1
    )
    return votes


def read_ma_issues() -> pd.DataFrame:
    """Read Mergent at maturity level and aggregate clean Massachusetts GO issues."""
    columns = [
        "issue_id", "issuer_long_name", "issue_description", "series", "offering_date",
        "maturity_date", "amount", "new_money", "state", "go_unlim", "go_lim", "rev",
        "use_proceeds", "security_code", "taxexempt_federal", "coupon_code",
    ]
    bonds = pd.read_stata(MERGENT, columns=columns, convert_categoricals=False)
    bonds = bonds[bonds["state"].fillna("").astype(str).str.upper().eq("MA")].copy()
    bonds["issue_id"] = pd.to_numeric(bonds["issue_id"], errors="coerce").astype("Int64")
    bonds["amount"] = pd.to_numeric(bonds["amount"], errors="coerce")
    bonds["offering_date"] = pd.to_datetime(bonds["offering_date"], errors="coerce")
    bonds["maturity_date"] = pd.to_datetime(bonds["maturity_date"], errors="coerce")
    for column in ["issuer_long_name", "issue_description", "series", "use_proceeds", "security_code"]:
        bonds[column] = bonds[column].fillna("").astype(str)
    for column in ["go_unlim", "go_lim", "rev", "new_money"]:
        bonds[column] = pd.to_numeric(bonds[column], errors="coerce")

    issues = (
        bonds.groupby("issue_id", dropna=True, as_index=False)
        .agg(
            issuer_long_name=("issuer_long_name", "first"),
            issue_description=("issue_description", "first"),
            series=("series", "first"),
            offering_date=("offering_date", "min"),
            final_maturity_date=("maturity_date", "max"),
            original_par=("amount", "sum"),
            new_money=("new_money", "first"),
            go_unlim=("go_unlim", "max"),
            go_lim=("go_lim", "max"),
            rev=("rev", "max"),
            use_proceeds=("use_proceeds", "first"),
            security_code=("security_code", "first"),
        )
    )
    issues = issues[(issues["go_unlim"].eq(1)) | (issues["go_lim"].eq(1))].copy()
    issues["municipality_key"] = issues["issuer_long_name"].map(canonical_name)
    issues["classification"] = "other_or_conflict"
    issues.loc[issues["go_unlim"].eq(1) & ~issues["go_lim"].eq(1), "classification"] = "go_unlim"
    issues.loc[issues["go_lim"].eq(1) & ~issues["go_unlim"].eq(1), "classification"] = "go_lim"
    issues["issue_tokens"] = (issues["issue_description"] + " " + issues["use_proceeds"]).map(tokens)
    issues["issue_purpose_flags"] = issues.apply(
        lambda row: issue_purpose_flags(row["issue_description"], row["use_proceeds"]), axis=1
    )
    issues["outstanding_at_2017"] = (
        issues["offering_date"].le(AS_OF) & issues["final_maturity_date"].gt(AS_OF)
    )
    return issues


def match_votes(issues: pd.DataFrame, votes: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Produce all plausible pairs and one highest-scoring record per bond issue."""
    wins = votes[votes["result"].eq("WIN")].copy()
    candidates = issues.merge(wins, on="municipality_key", how="inner", suffixes=("_bond", "_vote"))
    candidates["days_from_vote_to_issue"] = (candidates["offering_date"] - candidates["vote_date"]).dt.days
    candidates = candidates[
        candidates["days_from_vote_to_issue"].between(0, MAX_VOTE_LAG_DAYS, inclusive="both")
    ].copy()
    candidates["years_from_vote_to_issue"] = candidates["days_from_vote_to_issue"] / 365.25
    candidates["shared_purpose_tokens"] = candidates.apply(
        lambda row: "; ".join(sorted(row["issue_tokens"] & row["vote_tokens"])), axis=1
    )
    candidates["shared_purpose_token_count"] = candidates["shared_purpose_tokens"].map(
        lambda value: 0 if not value else len(value.split("; "))
    )
    candidates["shared_purpose_categories"] = candidates.apply(
        lambda row: "; ".join(sorted(row["issue_purpose_flags"] & row["vote_purpose_flags"])), axis=1
    )
    candidates["purpose_category_match"] = candidates["shared_purpose_categories"].ne("")
    candidates["match_score"] = 3
    candidates.loc[candidates["days_from_vote_to_issue"].le(3 * 365), "match_score"] += 3
    candidates.loc[candidates["purpose_category_match"], "match_score"] += 3
    candidates["match_score"] += candidates["shared_purpose_token_count"].clip(upper=3)
    candidates["match_confidence"] = "low"
    candidates.loc[
        candidates["purpose_category_match"] & candidates["days_from_vote_to_issue"].le(3 * 365),
        "match_confidence",
    ] = "high"
    candidates.loc[
        candidates["purpose_category_match"] | (
            candidates["shared_purpose_token_count"].ge(1) & candidates["days_from_vote_to_issue"].le(3 * 365)
        ),
        "match_confidence",
    ] = candidates.loc[
        candidates["purpose_category_match"] | (
            candidates["shared_purpose_token_count"].ge(1) & candidates["days_from_vote_to_issue"].le(3 * 365)
        ),
        "match_confidence",
    ].mask(lambda series: series.ne("high"), "medium")
    candidates = candidates.sort_values(
        ["issue_id", "match_score", "days_from_vote_to_issue", "vote_date"],
        ascending=[True, False, True, False],
    )
    best = candidates.drop_duplicates("issue_id", keep="first").copy()
    return candidates, best


def summary(issues: pd.DataFrame, best: pd.DataFrame) -> pd.DataFrame:
    merged = issues.merge(
        best[["issue_id", "match_confidence"]], on="issue_id", how="left"
    )
    merged["match_confidence"] = merged["match_confidence"].fillna("no_candidate")
    rows = []
    for stock_label, subset in [
        ("all_ma_go_issues", merged),
        ("outstanding_at_2017", merged[merged["outstanding_at_2017"]]),
    ]:
        for classification, group in subset.groupby("classification", dropna=False):
            for confidence, bucket in group.groupby("match_confidence", dropna=False):
                rows.append({
                    "stock_scope": stock_label,
                    "classification": classification,
                    "match_confidence": confidence,
                    "issues": len(bucket),
                    "original_par": bucket["original_par"].sum(),
                })
    return pd.DataFrame(rows).sort_values(["stock_scope", "classification", "match_confidence"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dls-xlsx",
        help="Local DLS export path, or '-' to read its XLSX export from standard input.",
    )
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    votes = read_dls_votes(args.dls_xlsx)
    issues = read_ma_issues()
    candidates, best = match_votes(issues, votes)
    out_summary = summary(issues, best)

    # Set-valued helper fields become human-readable audit columns on export.
    issues_export = issues.copy()
    for frame in [issues_export, candidates, best]:
        for column in ["issue_tokens", "issue_purpose_flags", "vote_tokens", "vote_purpose_flags"]:
            if column in frame:
                frame[column] = frame[column].map(
                    lambda value: "; ".join(sorted(value)) if isinstance(value, set) else value
                )

    votes.drop(columns=["vote_tokens", "vote_purpose_flags"]).to_csv(
        OUT / "dls_debt_exclusion_votes_raw.csv", index=False
    )
    candidates.to_csv(OUT / "ma_debt_exclusion_bond_candidates.csv", index=False)
    best.to_csv(OUT / "ma_debt_exclusion_bond_best_matches.csv", index=False)
    out_summary.to_csv(OUT / "ma_debt_exclusion_classification_summary.csv", index=False)
    issues_export.to_csv(OUT / "ma_go_issue_universe.csv", index=False)

    print(f"DLS votes: {len(votes):,} ({votes['result'].eq('WIN').sum():,} wins)")
    print(f"MA GO issues: {len(issues):,}; candidate pairs: {len(candidates):,}; best matches: {len(best):,}")
    print(out_summary.to_string(index=False))
    print(f"Wrote audit files to {OUT}")


if __name__ == "__main__":
    main()
