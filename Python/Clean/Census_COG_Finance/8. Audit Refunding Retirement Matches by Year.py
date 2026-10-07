"""Measure observed Mergent retirement matches for refunding issues by issuance year.

The principal series follows the earlier 2017-stock audit: a refunding issue is
an issue with ``new_money == 0``.  It is matched if an issue from the same
Mergent issuer has a positive REDEMPTN event whose redemption date or
refunding-issue settlement date is within +/- 365 days of the focal issue's
offering date.  Unlike the earlier audit, this uses the full issue universe
and is not restricted to bonds outstanding at 2017-12-31.
"""

from pathlib import Path

import numpy as np
import pandas as pd
import polars as pl


ROOT = Path(__file__).resolve().parents[4]
MERGENT = ROOT / "Data/Mergent/Clean/260923_cusiplevel_allbonds_inclrefund.dta"
REDEMPTION = ROOT / "Data/Mergent/Raw/REDEMPTN.DLM"
OUTPUT_DIR = ROOT / "Data/Mergent/Clean/audit"
OUTPUT = OUTPUT_DIR / "refunding_retirement_matches_by_issuance_year.csv"


def load_issues() -> pd.DataFrame:
    """Stream maturity records and construct one record per Mergent issue."""
    columns = [
        "issue_id", "issuer_name_id", "offering_date", "amount", "new_money", "issue_description",
    ]
    chunks = []
    reader = pd.read_stata(MERGENT, columns=columns, convert_categoricals=False, chunksize=250_000)
    for chunk in reader:
        chunk["issue_id"] = pd.to_numeric(chunk["issue_id"], errors="coerce").astype("Int64")
        chunk["offering_date"] = pd.to_datetime(chunk["offering_date"], errors="coerce")
        chunk["amount"] = pd.to_numeric(chunk["amount"], errors="coerce").fillna(0.0)
        chunk["new_money"] = pd.to_numeric(chunk["new_money"], errors="coerce")
        chunk["issuer_name_id"] = chunk["issuer_name_id"].fillna("").astype(str).str.strip()
        chunk["explicit_refunding_label"] = chunk["issue_description"].fillna("").astype(str).str.contains(
            "REFUND", case=False, regex=False
        )
        chunks.append(
            chunk.groupby("issue_id", dropna=True, as_index=False).agg(
                issuer_name_id=("issuer_name_id", "first"),
                offering_date=("offering_date", "min"),
                original_par=("amount", "sum"),
                new_money=("new_money", "first"),
                explicit_refunding_label=("explicit_refunding_label", "max"),
            )
        )

    issues = pd.concat(chunks, ignore_index=True)
    issues = issues.groupby("issue_id", as_index=False).agg(
        issuer_name_id=("issuer_name_id", "first"),
        offering_date=("offering_date", "min"),
        original_par=("original_par", "sum"),
        new_money=("new_money", "first"),
        explicit_refunding_label=("explicit_refunding_label", "max"),
    )
    issues["issue_id"] = issues["issue_id"].astype("int64")
    return issues


def load_redemption_dates(issues: pd.DataFrame) -> pd.DataFrame:
    """Return positive REDEMPTN dates with the redeemed issue's Mergent issuer."""
    redemptions = (
        pl.scan_csv(REDEMPTION, separator="|", null_values=[""], infer_schema_length=10_000)
        .select([
            pl.col("issue_id_l").cast(pl.Int64, strict=False).alias("issue_id"),
            pl.col("redemption_amt_f").cast(pl.Float64, strict=False).alias("redemption_amount"),
            pl.col("redemption_date_d").cast(pl.Utf8).str.strptime(pl.Date, "%Y%m%d", strict=False)
            .alias("redemption_date"),
            pl.col("ref_issue_settlement_date_d").cast(pl.Utf8).str.strptime(pl.Date, "%Y%m%d", strict=False)
            .alias("refunding_settlement_date"),
        ])
        .filter(pl.col("issue_id").is_not_null() & (pl.col("redemption_amount") > 0))
        .collect()
        .to_pandas()
    )
    events = pd.concat([
        redemptions[["issue_id", "redemption_date"]].rename(columns={"redemption_date": "event_date"}),
        redemptions[["issue_id", "refunding_settlement_date"]].rename(
            columns={"refunding_settlement_date": "event_date"}
        ),
    ], ignore_index=True)
    events["event_date"] = pd.to_datetime(events["event_date"], errors="coerce")
    events = events.dropna(subset=["event_date"])
    issuer_lookup = issues[["issue_id", "issuer_name_id"]].drop_duplicates("issue_id")
    events = events.merge(issuer_lookup, on="issue_id", how="inner", validate="many_to_one")
    events = events[events["issuer_name_id"].ne("")].drop_duplicates(["issuer_name_id", "event_date"])
    return events[["issuer_name_id", "event_date"]]


def add_match_flag(refundings: pd.DataFrame, events: pd.DataFrame) -> pd.DataFrame:
    """Mark any same-issuer redemption/settlement event occurring within +/- 365 days."""
    event_days = {
        issuer: np.sort(group["event_date"].to_numpy(dtype="datetime64[D]").astype("int64"))
        for issuer, group in events.groupby("issuer_name_id", sort=False)
    }
    matched = np.zeros(len(refundings), dtype=bool)
    for issuer, positions in refundings.groupby("issuer_name_id", sort=False).indices.items():
        dates = event_days.get(issuer)
        if dates is None:
            continue
        focal = refundings.iloc[positions]["offering_date"].to_numpy(dtype="datetime64[D]").astype("int64")
        loc = np.searchsorted(dates, focal)
        right = np.full(len(focal), np.iinfo(np.int64).max)
        left = np.full(len(focal), np.iinfo(np.int64).max)
        has_right = loc < len(dates)
        has_left = loc > 0
        right[has_right] = np.abs(dates[loc[has_right]] - focal[has_right])
        left[has_left] = np.abs(dates[loc[has_left] - 1] - focal[has_left])
        matched[positions] = np.minimum(left, right) <= 365
    refundings = refundings.copy()
    refundings["retirement_match_within_365_days"] = matched
    return refundings


def summarize(refundings: pd.DataFrame, definition: str) -> pd.DataFrame:
    frame = refundings.copy()
    frame["issuance_year"] = frame["offering_date"].dt.year
    frame["unmatched"] = ~frame["retirement_match_within_365_days"]
    annual = frame.groupby("issuance_year", as_index=False).agg(
        refunding_issues=("issue_id", "size"),
        matched_issues=("retirement_match_within_365_days", "sum"),
        unmatched_issues=("unmatched", "sum"),
        refunding_par=("original_par", "sum"),
        matched_par=("original_par", lambda x: x[frame.loc[x.index, "retirement_match_within_365_days"]].sum()),
        unmatched_par=("original_par", lambda x: x[frame.loc[x.index, "unmatched"]].sum()),
    )
    annual["unmatched_issue_share"] = annual["unmatched_issues"] / annual["refunding_issues"]
    annual["unmatched_par_share"] = annual["unmatched_par"] / annual["refunding_par"]
    annual.insert(0, "refunding_definition", definition)
    return annual


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    issues = load_issues()
    events = load_redemption_dates(issues)
    focal = issues[
        issues["offering_date"].notna()
        & issues["issuer_name_id"].ne("")
        & issues["offering_date"].dt.year.ge(2010)
        & issues["new_money"].eq(0)
    ].copy()
    focal = add_match_flag(focal, events)
    all_non_new_money = summarize(focal, "new_money_eq_0")
    labeled_refundings = summarize(focal[focal["explicit_refunding_label"]], "description_contains_refund")
    out = pd.concat([all_non_new_money, labeled_refundings], ignore_index=True)
    out.to_csv(OUTPUT, index=False)

    print(f"Full issue universe: {len(issues):,} issues; max offering year: {issues['offering_date'].dt.year.max():.0f}")
    print(f"Positive redemption-event dates: {len(events):,}")
    print(f"Wrote {OUTPUT}")
    print(all_non_new_money.to_string(index=False, formatters={
        "refunding_par": "${:,.0f}".format, "matched_par": "${:,.0f}".format,
        "unmatched_par": "${:,.0f}".format, "unmatched_issue_share": "{:.1%}".format,
        "unmatched_par_share": "{:.1%}".format,
    }))


if __name__ == "__main__":
    main()
