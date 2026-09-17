"""Audit sensitivity of institutional trade flags to the exact $100,000 cutoff."""

from pathlib import Path

import pandas as pd
import polars as pl


project_dir = Path(__file__).resolve().parents[4]
data_dir = project_dir / "Data"
clean_msrb_dir = data_dir / "Clean_Intermediate" / "MSRB" / "Processed"
raw_trade_files = [
    str(data_dir / "MSRB" / "Raw Files" / f"msrb_{year}.gzip")
    for year in range(2005, 2024)
]

issuances = (
    pl.DataFrame(
        pd.read_stata(
            data_dir
            / "Mergent"
            / "Clean"
            / "260716_city_cusiplevel_statereq_purpose_yieldspread.dta"
        )
    )
    .select(["cusip", "offering_date", "maturity_date"])
    .with_columns(
        pl.col("offering_date").cast(pl.Date),
        pl.col("maturity_date").cast(pl.Date),
    )
)

bond_counts = (
    pl.scan_parquet(raw_trade_files)
    .select(["cusip", "trade_date", "trade_type_indicator", "par_traded"])
    .filter(pl.col("trade_type_indicator").is_in(["P", "S"]))
    .with_columns(
        pl.col("par_traded")
        .replace("1MM+", "1000000")
        .cast(pl.Float64, strict=False)
    )
    .join(issuances.lazy(), on="cusip", how="inner")
    .filter(pl.col("trade_date") >= pl.col("offering_date") + pl.duration(days=30))
    .filter(pl.col("trade_date") <= pl.col("maturity_date"))
    .group_by("cusip")
    .agg(
        pl.len().alias("customer_trades"),
        pl.col("par_traded").eq(100000).sum().alias("trades_eq_100k"),
        pl.col("par_traded").ge(100000).sum().alias("trades_ge_100k"),
        pl.col("par_traded").gt(100000).sum().alias("trades_gt_100k"),
        pl.col("trade_type_indicator").eq("S").sum().alias("customer_buys"),
        (
            pl.col("trade_type_indicator").eq("S")
            & pl.col("par_traded").eq(100000)
        ).sum().alias("buys_eq_100k"),
        (
            pl.col("trade_type_indicator").eq("S")
            & pl.col("par_traded").ge(100000)
        ).sum().alias("buys_ge_100k"),
        (
            pl.col("trade_type_indicator").eq("S")
            & pl.col("par_traded").gt(100000)
        ).sum().alias("buys_gt_100k"),
    )
    .collect()
    .with_columns(
        (pl.col("trades_ge_100k") > 0).cast(pl.Int8).alias("institutional_ge"),
        (pl.col("trades_gt_100k") > 0).cast(pl.Int8).alias("institutional_gt"),
        (pl.col("buys_ge_100k") > 0).cast(pl.Int8).alias("institutional_buys_ge"),
        (pl.col("buys_gt_100k") > 0).cast(pl.Int8).alias("institutional_buys_gt"),
    )
)

trade_summary = bond_counts.select(
    pl.sum("customer_trades", "trades_eq_100k", "trades_ge_100k", "trades_gt_100k"),
    pl.sum("customer_buys", "buys_eq_100k", "buys_ge_100k", "buys_gt_100k"),
).with_columns(
    (100 * pl.col("trades_eq_100k") / pl.col("customer_trades")).alias(
        "eq_100k_pct_all_customer_trades"
    ),
    (100 * pl.col("trades_eq_100k") / pl.col("trades_ge_100k")).alias(
        "eq_100k_pct_ge_100k_trades"
    ),
    (100 * pl.col("buys_eq_100k") / pl.col("customer_buys")).alias(
        "eq_100k_pct_all_customer_buys"
    ),
    (100 * pl.col("buys_eq_100k") / pl.col("buys_ge_100k")).alias(
        "eq_100k_pct_ge_100k_buys"
    ),
)

bond_summary = bond_counts.select(
    pl.sum("institutional_ge", "institutional_gt"),
    pl.sum("institutional_buys_ge", "institutional_buys_gt"),
).with_columns(
    (pl.col("institutional_ge") - pl.col("institutional_gt")).alias(
        "bonds_flipping_all_trades"
    ),
    (
        pl.col("institutional_buys_ge") - pl.col("institutional_buys_gt")
    ).alias("bonds_flipping_buys"),
)

analysis_columns = [
    "cusip", "city", "city_go_vote", "go_unlim", "callable", "year",
    "disclosed_before_maturity", "ln_amount", "ln_maturity_mths", "sinkable",
    "insured", "rating_num", "ln_gdp", "ln_pop", "ln_pers_inc", "purp_broad",
    "state",
]
analysis_sample = (
    pl.read_csv(
        clean_msrb_dir / "Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv",
        columns=analysis_columns,
        infer_schema_length=10000,
    )
    .filter(
        (pl.col("city") == 1)
        & pl.col("city_go_vote").is_not_null()
        & (pl.col("go_unlim") == 1)
        & pl.col("callable").is_not_null()
        & (pl.col("year") > 2004)
    )
    .drop_nulls(analysis_columns[1:])
    .join(
        bond_counts.select(
            "cusip", "institutional_ge", "institutional_gt",
            "institutional_buys_ge", "institutional_buys_gt",
        ),
        on="cusip",
        how="left",
    )
    .with_columns(
        pl.col(
            "institutional_ge", "institutional_gt", "institutional_buys_ge",
            "institutional_buys_gt",
        ).fill_null(0)
    )
)

sample_summary = analysis_sample.select(
    pl.len().alias("regression_sample_n"),
    pl.sum("institutional_ge", "institutional_gt"),
    pl.sum("institutional_buys_ge", "institutional_buys_gt"),
).with_columns(
    (pl.col("institutional_ge") - pl.col("institutional_gt")).alias(
        "sample_bonds_flipping_all_trades"
    ),
    (
        pl.col("institutional_buys_ge") - pl.col("institutional_buys_gt")
    ).alias("sample_bonds_flipping_buys"),
)

print("TRADE SUMMARY")
print(trade_summary.to_dicts()[0])
print("BOND SUMMARY")
print(bond_summary.to_dicts()[0])
print("FULL-SAMPLE REGRESSION SUMMARY")
print(sample_summary.to_dicts()[0])
