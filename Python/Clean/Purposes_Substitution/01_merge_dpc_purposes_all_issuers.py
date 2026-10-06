"""Merge DPC purposes onto the full bond input without issuer-sample screens."""

#%% Inputs and output location
import os
from pathlib import Path

import pandas as pd
import polars as pl

code_dir = Path(__file__).resolve().parents[3]
data_dir = code_dir.parent / 'Data'
output_dir = Path(os.getenv(
    'PURPOSE_REGRESSION_DIR', str(data_dir / 'DPC Data/Use Of Proceeds/Purposes Substitution')
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)

purpose_vars = [
    'educ', 'wtrswr', 'fire', 'police', 'parksrec', 'pubtransit', 'street',
    'elec', 'waste', 'sport', 'health', 'gas', 'libarts', 'econdev',
    'refund', 'otherpubbldg', 'other'
]
bond_vars = [
    'cusip', 'state', 'seed_issuer', 'seed_issuer_id', 'year', 'issue_id',
    'offering_date', 'city_go_vote', 'city_rev_vote', 'go_unlim', 'go_lim',
    'rev', 'security_code', 'source_of_repayment', 'amount', 'purp_broad'
]
# Use the same bond and DPC sources as the archived R merge. Pandas only decodes
# Stata; all transformations and joins use Polars. Do not screen on insample,
# revenue-vote rules, or legacy issuer-level demographic availability.
bond = pl.from_pandas(pd.read_stata(
    data_dir / 'Mergent/Clean/260610_city_cusiplevel_statereq_purpose_yieldspread.dta',
    columns=bond_vars, convert_categoricals=False
)).with_columns(
    pl.col('cusip').str.to_uppercase().str.replace_all(r'[^A-Z0-9]', '').alias('cusip_norm'),
    pl.when(pl.col('state') == 'MO').then(1).otherwise(pl.col('city_rev_vote'))
    .alias('city_rev_vote'),
    pl.when(pl.col('state') == 'RI').then(None).otherwise(pl.col('city_go_vote'))
    .alias('city_go_vote')
)

#%% Collapse repeated DPC documents to one set of purpose indicators per CUSIP
dpc = pl.read_csv(
    data_dir / 'DPC Data/Use Of Proceeds/260223_dpcdata_cusip_purpose.csv',
    infer_schema_length=100000
).with_columns(
    pl.col('CUSIP').str.to_uppercase().str.replace_all(r'[^A-Z0-9]', '').alias('cusip_norm'),
    *[(pl.col(column).fill_null(0) > 0).cast(pl.Int64).alias(column)
      for column in purpose_vars]
).group_by('cusip_norm', maintain_order=True).agg(
    pl.len().alias('n_dpc_rows'),
    pl.col('DOCID').cast(pl.String).fill_null('NA').unique(maintain_order=True)
    .str.join(';').alias('dpc_docids'),
    *[pl.col(column).max() for column in purpose_vars]
).with_columns(pl.lit(1).alias('dpc_match'))

#%% Preserve unmatched bonds for review; the panel step selects DPC matches
merged = bond.join(
    dpc, on='cusip_norm', how='left', validate='m:1', maintain_order='left'
).with_columns(
    pl.col('dpc_match', *purpose_vars).fill_null(0),
).with_columns(
    ((pl.col('pubtransit') == 1) | (pl.col('street') == 1))
    .cast(pl.Int64).alias('transport')
)
output_file = output_dir / 'dpc_use_proceeds_all_issuers_bonds.csv'
merged.write_csv(output_file)
print(f'Wrote {output_file}: {merged.height:,} bonds')
