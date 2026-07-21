"""Compute tax-adjusted, maturity-matched municipal bond yield spreads.

The primary (NC/Garrett et al.) construction is

    offering_yield / (1 - tau) - maturity-matched Treasury yield,

where tau is the Taxsim federal rate adjusted for state-tax deductibility plus
the Taxsim state rate when the bond is exempt from tax in the issuing state.
The Treasury match uses the same rounded integer maturity and the offering
date, or the next trading day for weekend/holiday offerings.

The source Mergent/Gao spread is retained as ``offering_yield_spread_gao``.
The new spread is stored as both ``offering_yield_spread_nc`` and the
backward-compatible ``offering_yield_spread`` used by downstream tables.
"""

from pathlib import Path
import os
import re

import pandas as pd
import polars as pl


ROOT = Path(os.path.expanduser("~/Dropbox/Voting on Bonds"))
DATA = ROOT / "Data"
BOND_FILE = DATA / "Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta"
TAX_FILE = DATA / "MSRB/taxsim_nber_max_state_income_rates_1977_2021.csv"
TREASURY_FILE = DATA / "Nominal Yield Curve/nominal_yield_curve.csv"
OUTPUT_DIR = DATA / "Clean_Intermediate/Mergent/Clean"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

BOND_OUTPUT = OUTPUT_DIR / "bond_level_off_yield_spread.csv"
ISSUER_OUTPUT = OUTPUT_DIR / "issuer_level_nc_yield_spreads.csv"

BOND_COLUMNS = [
    "issue_id",
    "cusip",
    "seed_issuer",
    "seed_issuer_id",
    "state",
    "state_name",
    "state_tax",
    "offering_date",
    "maturity_date",
    "offering_yield",
    "offering_yield_spread",
    "amount",
    "bond_type",
    "go_unlim",
    "go_lim",
    "rev",
]


def weighted_average(group: pd.DataFrame, mask: pd.Series) -> float:
    """Return an amount-weighted NC spread for the requested bond category."""
    valid = mask & group["offering_yield_spread_nc"].notna() & group["amount"].gt(0)
    if not valid.any():
        return float("nan")
    return (
        (group.loc[valid, "amount"] * group.loc[valid, "offering_yield_spread_nc"]).sum()
        / group.loc[valid, "amount"].sum()
    )


print("Loading Mergent bonds and preserving the Gao spread...")
bonds_pd = pd.read_stata(BOND_FILE, columns=BOND_COLUMNS, convert_categoricals=False)
bonds = (
    pl.from_pandas(bonds_pd)
    .rename({"offering_yield_spread": "offering_yield_spread_gao"})
    .with_columns([
        pl.col("issue_id").cast(pl.Int64),
        pl.col("cusip").cast(pl.Utf8),
        pl.col("offering_date").cast(pl.Date),
        pl.col("maturity_date").cast(pl.Date),
        pl.col("offering_yield").cast(pl.Float64),
        pl.col("offering_yield_spread_gao").cast(pl.Float64),
        pl.col("amount").cast(pl.Float64),
        pl.col("state_tax").cast(pl.Utf8).str.strip_chars(),
    ])
    .with_columns([
        pl.col("offering_date").dt.year().alias("year"),
        (
            (pl.col("maturity_date") - pl.col("offering_date")).dt.total_days()
            / 365.25
        ).alias("maturity_years"),
    ])
    .with_columns(
        pl.col("maturity_years").round(0).cast(pl.Int64).alias("maturity_years_rounded")
    )
)

print("Joining state-year Taxsim rates and applying the state exemption indicator...")
tax_rates = (
    pl.read_csv(TAX_FILE)
    .filter(pl.col("state") != "federal")
    .select([
        pl.col("year").cast(pl.Int64),
        pl.col("state").alias("state_name"),
        (pl.col("federal_rate").cast(pl.Float64) / 100).alias("federal_tax_rate"),
        (pl.col("state_rate").cast(pl.Float64) / 100).alias("state_income_tax_rate"),
    ])
)

bonds = (
    bonds
    .join(tax_rates, on=["year", "state_name"], how="left")
    .with_columns([
        pl.when(pl.col("state_tax") == "N")
        .then(1.0)
        .when(pl.col("state_tax") == "Y")
        .then(0.0)
        # When the state rate is zero, the unknown indicator cannot affect tau.
        .when(pl.col("state_income_tax_rate") == 0)
        .then(0.0)
        # Otherwise leave bonds with unknown state-tax status out of the NC
        # spread rather than imposing an exemption assumption.
        .otherwise(None)
        .alias("state_exemption_indicator"),
        pl.col("state_tax").is_in(["N", "Y"]).alias("state_tax_status_known"),
    ])
    .with_columns(
        (
            pl.col("federal_tax_rate")
            + pl.col("state_income_tax_rate") * pl.col("state_exemption_indicator")
        ).alias("combined_marginal_tax_rate")
    )
    .with_columns(
        (
            pl.col("offering_yield") / (1 - pl.col("combined_marginal_tax_rate"))
        ).alias("tax_adjusted_offering_yield")
    )
)

print("Matching rounded maturity to the Treasury zero-coupon curve...")
curve = pl.read_csv(TREASURY_FILE)
sveny_columns = [column for column in curve.columns if re.fullmatch(r"SVENY\d{2}", column)]
treasury = (
    curve
    .select(["Date", *sveny_columns])
    .with_columns(pl.col("Date").str.to_date(format="%m/%d/%y"))
    .unpivot(
        index="Date",
        on=sveny_columns,
        variable_name="treasury_maturity",
        value_name="treasury_yield",
    )
    .with_columns([
        pl.col("treasury_maturity").str.slice(-2).cast(pl.Int64).alias("maturity_years_rounded"),
        pl.col("treasury_yield").cast(pl.Float64, strict=False),
    ])
    .filter(pl.col("treasury_yield").is_not_null())
    .select([
        pl.col("Date").alias("treasury_date"),
        "maturity_years_rounded",
        "treasury_yield",
    ])
    .sort("treasury_date")
)

eligible = (
    bonds
    .filter(pl.col("maturity_years_rounded").is_between(1, 30))
    .sort("offering_date")
    .join_asof(
        treasury,
        left_on="offering_date",
        right_on="treasury_date",
        by="maturity_years_rounded",
        strategy="forward",
    )
    .with_columns(
        (
            pl.col("tax_adjusted_offering_yield") - pl.col("treasury_yield")
        ).alias("offering_yield_spread_nc")
    )
    .with_columns(
        pl.col("offering_yield_spread_nc").alias("offering_yield_spread")
    )
)

bond_output = eligible.select([
    "issue_id",
    "cusip",
    "offering_date",
    "maturity_date",
    "maturity_years",
    "maturity_years_rounded",
    "state_tax",
    "state_tax_status_known",
    "state_exemption_indicator",
    "federal_tax_rate",
    "state_income_tax_rate",
    "combined_marginal_tax_rate",
    "offering_yield",
    "tax_adjusted_offering_yield",
    "treasury_date",
    "treasury_yield",
    "offering_yield_spread_gao",
    "offering_yield_spread_nc",
    "offering_yield_spread",
])
bond_output.write_csv(BOND_OUTPUT)

print("Constructing issuer-level weighted averages for the full-period tables...")
issuer_bonds = (
    eligible
    .filter(
        pl.col("seed_issuer").is_not_null()
        & pl.col("rev").is_not_null()
        & pl.col("amount").is_not_null()
        & (pl.col("amount") > 0)
    )
    .to_pandas()
)

issuer_rows = []
for seed_issuer, group in issuer_bonds.groupby("seed_issuer", sort=False, dropna=False):
    all_rows = pd.Series(True, index=group.index)
    go = group["bond_type"].eq("go")
    utgo = group["go_unlim"].eq(1)
    ltgo = group["go_lim"].eq(1)
    revenue = group["rev"].eq(1)
    overall = weighted_average(group, all_rows)
    issuer_rows.append({
        "seed_issuer": seed_issuer,
        "state": group["state"].dropna().iloc[0] if group["state"].notna().any() else None,
        "issuer_spread_nc": overall,
        "issuer_yield_spread_nc": overall,
        "issuer_spread_go_nc": weighted_average(group, go),
        "issuer_spread_utgo_nc": weighted_average(group, utgo),
        "issuer_spread_ltgo_nc": weighted_average(group, ltgo),
        "issuer_spread_rev_nc": weighted_average(group, revenue),
    })

issuer_output = pd.DataFrame(issuer_rows)
issuer_output.to_csv(ISSUER_OUTPUT, index=False)

known_status = eligible.filter(pl.col("state_tax_status_known"))
print(f"Saved {bond_output.height:,} maturity-eligible bond rows to {BOND_OUTPUT}")
print(f"New spread available: {bond_output['offering_yield_spread_nc'].is_not_null().sum():,}")
print(f"Gao spread retained: {bond_output['offering_yield_spread_gao'].is_not_null().sum():,}")
print(f"Known state-tax status: {known_status.height:,}")
print(f"Saved {len(issuer_output):,} issuer aggregates to {ISSUER_OUTPUT}")
