"""Attach local Texas ISD rejection-risk measures to the 2017 DPC panel.

The exposure builder creates city-level five-year risk as of December 31,
2017. This script keeps the Texas rows in the established issuer-by-purpose
cross section and adds the two analysis measures used in the Texas mechanism
tables: an area-weighted rate and an equal-weight rate for ISDs covering at
least 20 percent of city area.
"""

from pathlib import Path

import polars as pl


ROOT = Path(__file__).resolve().parents[4]
DATA = ROOT / "Data"
CLEAN = DATA / "Clean_Intermediate"
PURPOSE_INPUT = (
    DATA / "DPC Data" / "Use Of Proceeds" / "Purposes Substitution" /
    "260719_dpc_point_in_time_purpose_substitution_2017_issuer_category_panel.csv"
)
RISK_INPUT = CLEAN / "TX" / "Election_Exposure" / "city_2017_isd_rejection_risk.csv"
OUTPUT = (
    CLEAN / "Census COG Finance" / "processed" /
    "texas_2017_purpose_substitution_rejection_risk.csv"
)


def issuer_key(column: str) -> pl.Expr:
    """Return the normalized Texas city key shared with the exposure panel."""
    return pl.col(column).cast(pl.String).str.strip_chars().str.to_lowercase()


def main() -> None:
    if not PURPOSE_INPUT.exists():
        raise FileNotFoundError(f"Missing 2017 purpose panel: {PURPOSE_INPUT}")
    if not RISK_INPUT.exists():
        raise FileNotFoundError(f"Missing Texas risk panel: {RISK_INPUT}")

    purpose = (
        pl.read_csv(PURPOSE_INPUT, infer_schema_length=None)
        .filter(pl.col("state") == "TX")
        .with_columns(issuer_key("seed_issuer").alias("seed_key"))
    )
    risk = (
        pl.read_csv(RISK_INPUT, infer_schema_length=None)
        .select(
            issuer_key("seed_key").alias("seed_key"),
            "risk_date",
            "prior_weighted_failure_rate_60m",
            "prior_simple_failure_rate_20pct_60m",
        )
        .unique(subset="seed_key", keep="first")
    )

    if risk.height != risk.get_column("seed_key").n_unique():
        raise ValueError("The 2017 Texas rejection-risk panel has duplicate city keys.")

    output = purpose.join(risk, on="seed_key", how="left", validate="m:1")
    if output.height != purpose.height:
        raise ValueError("The risk merge changed the number of Texas purpose observations.")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.write_csv(OUTPUT)
    print(
        f"Wrote {OUTPUT.name}: {output.height:,} rows, "
        f"{output.get_column('seed_issuer').n_unique():,} Texas cities."
    )


if __name__ == "__main__":
    main()
