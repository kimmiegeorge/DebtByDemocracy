"""Build raw customer-trade and disclosure outcomes for the Table 6 bonds."""

#%% Paths and bond metadata
import os
from pathlib import Path

import pandas as pd
import polars as pl

code_dir = Path(__file__).resolve().parents[3]
data_dir = code_dir.parent / 'Data'
output_dir = Path(os.getenv(
    'MSRB_PROCESSED_DIR', str(data_dir / 'Clean_Intermediate/MSRB/Processed')
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)

# Pandas only decodes Stata, preserving its category labels as in the old builder.
mergent = pl.DataFrame(pd.read_stata(
    data_dir / 'Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
))
issuances = mergent.select('cusip', 'offering_date', 'maturity_date').with_columns(
    pl.col('offering_date', 'maturity_date').cast(pl.Date)
)
# The old daily panel included a bond only if at least one date remained after
# removing its first 30 days. Preserve that universe without expanding dates.
eligible_cusips = issuances.filter(
    pl.col('maturity_date') >= pl.col('offering_date') + pl.duration(days=30)
).select('cusip').unique()

#%% Customer trades from 2005--2023, between offering + 30 days and maturity
raw_trade_files = [
    data_dir / 'MSRB/Raw Files' / f'msrb_{year}.gzip'
    for year in range(2005, 2024)
]
missing_files = [path for path in raw_trade_files if not path.exists()]
if missing_files:
    raise FileNotFoundError(f'Missing MSRB raw trade files: {missing_files}')

# Scan only the columns needed for trade presence. No price, yield, interdealer
# match, or computed-markup restriction enters these regression outcomes.
trade_indicators = (
    pl.scan_parquet(raw_trade_files)
    .select('cusip', 'trade_date', 'trade_type_indicator', 'par_traded')
    .filter(pl.col('trade_type_indicator').is_in(['P', 'S']))
    .with_columns(
        pl.col('par_traded').replace('1MM+', '1000000')
        .cast(pl.Float64, strict=False)
    )
    .join(issuances.lazy(), on='cusip', how='inner')
    .filter(
        pl.col('trade_date') >= pl.col('offering_date') + pl.duration(days=30),
        pl.col('trade_date') <= pl.col('maturity_date')
    )
    .group_by('cusip')
    .agg(
        pl.lit(1).cast(pl.Int8).alias('traded_before_maturity_raw'),
        pl.col('par_traded').lt(100000).fill_null(False).any().cast(pl.Int8)
        .alias('retail_traded_before_maturity_raw'),
        pl.col('par_traded').ge(100000).fill_null(False).any().cast(pl.Int8)
        .alias('institutional_traded_before_maturity_raw')
    )
    .collect(engine='streaming')
)
print(f'Customer-trade indicators: {trade_indicators.height:,} bonds', flush=True)

#%% Any continuing disclosure during the same bond lifetime window
# Table 6 uses disclosure presence, so neither a daily panel nor disclosure
# counts are needed. Read only CUSIP and event date from the disclosure CSV.
disclosure_indicators = (
    pl.scan_csv(
        data_dir / 'Continuing Disclosure/cleaned_daily_disclosure_data.csv',
        infer_schema_length=100000, null_values='NA'
    )
    .select(pl.col('cusip_c').alias('cusip'),
            pl.col('disclosure_event_date').str.to_date().alias('date'))
    .join(issuances.lazy(), on='cusip', how='inner')
    .filter(
        pl.col('date') >= pl.col('offering_date') + pl.duration(days=30),
        pl.col('date') <= pl.col('maturity_date')
    )
    .select('cusip').unique()
    .with_columns(pl.lit(1).cast(pl.Int8).alias('disclosed_before_maturity'))
    .collect(engine='streaming')
)

#%% Merge outcomes into bond metadata; no observed trade or disclosure means zero
bond_data = (
    mergent.join(eligible_cusips, on='cusip', how='semi', maintain_order='left')
    .join(trade_indicators, on='cusip', how='left', validate='m:1',
          maintain_order='left')
    .join(disclosure_indicators, on='cusip', how='left', validate='m:1',
          maintain_order='left')
    .with_columns(pl.col(
        'traded_before_maturity_raw', 'retail_traded_before_maturity_raw',
        'institutional_traded_before_maturity_raw', 'disclosed_before_maturity'
    ).fill_null(0))
)
bond_data.write_csv(output_dir / 'bond_trade_before_maturity.csv')
print(f'Wrote bond_trade_before_maturity.csv: {bond_data.height:,} rows', flush=True)
