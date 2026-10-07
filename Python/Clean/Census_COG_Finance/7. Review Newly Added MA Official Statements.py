"""Write manual tax-pledge reviews for the 2026-09-29 OS download batch.

Classification rule: if any portion of an issuance is supported by taxes that
may be levied without limit as to rate or amount, classify the entire Mergent
issue as UTGO.  The review uses the security paragraph/title in each official
statement; documents that state the bonds are subject only to Proposition 2 1/2
are classified LTGO.
"""

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
OS_DIR = ROOT / "Data/MA LTGO Bonds/OS"
QUEUE = OS_DIR / "ma_2017_go_lim_official_statement_review.csv"
REVIEW_CUTOFF = pd.Timestamp("2026-09-29 08:30:00").timestamp()

# These six offerings' security clauses state that payment is subject to the
# Proposition 2 1/2 levy limit, with no unlimited-tax portion described.
LTGO_CUSIPS = {
    "054141GS9": "LTGO - security clause says payment is subject to the Proposition 2 1/2 levy limit.",
    "108655LV1": "LTGO - security clause says payment is subject to the Proposition 2 1/2 levy limit.",
    "601090JF1": "LTGO - introduction says payment is subject to the Proposition 2 1/2 levy limit.",
    "630191QW7": "LTGO - security clause says payment is subject to the Proposition 2 1/2 levy limit.",
    "841246PC9": "LTGO - security clause says payment is subject to the Proposition 2 1/2 levy limit.",
    "841246QF1": "LTGO - security clause says payment is subject to the Proposition 2 1/2 levy limit.",
}

# These official statements expressly identify both a limited and an unlimited
# portion. Under the project rule, the issue is UTGO because the latter exists.
MIXED_CUSIPS = {
    "005104GP3": "UTGO - OS says the Town voted to exempt a portion of debt service from Proposition 2 1/2.",
    "077401FB8": "UTGO - OS says the Town voted to exempt a portion of debt service from Proposition 2 1/2.",
    "550408JC3": "UTGO - OS identifies $2.158m of Series A as payable without limit as to rate or amount.",
    "655745JE8": "UTGO - OS identifies $4.116m as payable without limitation as to rate or amount.",
    "755077GD0": "UTGO - OS says the Town voted to exempt a portion of debt service from Proposition 2 1/2.",
    "819649VH4": "UTGO - OS identifies $2.650m as exempt from the Proposition 2 1/2 limit.",
    "951631PF1": "UTGO - OS says the Town voted to exempt a portion of debt service from Proposition 2 1/2.",
    "961165Y50": "UTGO - OS says the Town voted to exempt a portion of debt service from Proposition 2 1/2.",
    "961369FD2": "UTGO - OS identifies $8.000m as payable without limit as to rate or amount.",
}


def main() -> None:
    queue = pd.read_csv(QUEUE, dtype={"representative_cusip": str})
    queue["representative_cusip"] = queue["representative_cusip"].str.upper().str.strip()
    for column in [
        "official_statement_file", "official_statement_url", "os_tax_pledge",
        "corrected_classification", "review_status", "reviewer_notes",
    ]:
        queue[column] = queue[column].fillna("").astype(str)
    if "os_review_evidence" not in queue.columns:
        queue["os_review_evidence"] = ""
    else:
        queue["os_review_evidence"] = queue["os_review_evidence"].fillna("").astype(str)

    batch = {
        path.stem.upper(): path
        for path in OS_DIR.glob("*.pdf")
        if path.stat().st_mtime > REVIEW_CUTOFF
    }
    matching = queue["representative_cusip"].isin(batch).sum()
    if len(batch) != 49 or matching != 49:
        raise ValueError(f"Expected the 49-file new batch; found {len(batch)} files and {matching} queue matches.")

    for cusip, path in batch.items():
        idx = queue.index[queue["representative_cusip"].eq(cusip)]
        if len(idx) != 1:
            raise ValueError(f"Expected one queue row for {cusip}; found {len(idx)}")
        row = idx[0]
        queue.loc[row, "official_statement_file"] = path.name
        queue.loc[row, "review_status"] = "Reviewed"
        if cusip in LTGO_CUSIPS:
            queue.loc[row, "os_tax_pledge"] = "LTGO"
            queue.loc[row, "corrected_classification"] = "LTGO"
            queue.loc[row, "os_review_evidence"] = LTGO_CUSIPS[cusip]
        else:
            queue.loc[row, "os_tax_pledge"] = "UTGO"
            queue.loc[row, "corrected_classification"] = "UTGO"
            if cusip in MIXED_CUSIPS:
                queue.loc[row, "os_review_evidence"] = MIXED_CUSIPS[cusip]
            else:
                queue.loc[row, "os_review_evidence"] = (
                    "UTGO - OS security clause states taxes may be levied without limitation as to rate or amount."
                )

    queue.to_csv(QUEUE, index=False)
    reviewed = queue[queue["review_status"].eq("Reviewed")]
    print(f"New batch reviewed: {len(batch)}")
    print(reviewed["corrected_classification"].value_counts().to_string())
    print(f"Queue rows with a linked OS file: {queue['official_statement_file'].ne('').sum()}")


if __name__ == "__main__":
    main()
