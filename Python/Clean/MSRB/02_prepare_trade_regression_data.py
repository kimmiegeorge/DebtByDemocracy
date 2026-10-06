"""Prepare the full and border samples loaded by 04_trade_before_maturity.R."""

#%% Paths and shared policy definitions
import os
from pathlib import Path

import polars as pl

code_dir = Path(__file__).resolve().parents[3]
clean_data_dir = code_dir.parent / 'Data/Clean_Intermediate'
processed_dir = Path(os.getenv(
    'MSRB_PROCESSED_DIR', str(clean_data_dir / 'MSRB/Processed')
)).expanduser()
output_dir = Path(os.getenv(
    'MSRB_REGRESSION_DIR', str(clean_data_dir / 'MSRB/Regression')
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)
excluded_state = os.getenv('EXCLUDE_STATE', '')

tax_states = pl.read_csv(code_dir / 'Config/low_state_tax_privilege_states.csv')
low_tax_states = tax_states.get_column('state').to_list()
border_pairs = pl.read_csv(code_dir / 'Config/border_state_pairs.csv').filter(
    pl.col('include_in_paper') == 1
).get_column('group').to_list()

#%% Full sample restrictions and regression variables
data = pl.read_csv(
    processed_dir / 'bond_trade_before_maturity.csv',
    infer_schema_length=100000, null_values=['NA', 'NaN']
).filter(
    pl.col('city') == 1, pl.col('city_go_vote').is_not_null(),
    pl.col('go_unlim') == 1, pl.col('callable').is_not_null()
)
if 'rating_fe' not in data.columns or data['rating_fe'].null_count():
    raise ValueError('rating_fe is required and cannot contain missing values')

data = data.with_columns(
    pl.col('seed_issuer_id').cast(pl.Float64).round(1, mode='half_to_even'),
    pl.col('state').is_in(low_tax_states).fill_null(False).cast(pl.Int32)
    .alias('low_state_tax_privilege'),
    pl.col('traded_before_maturity_raw').alias('traded_before_maturity'),
    pl.col('retail_traded_before_maturity_raw').alias('retail_traded_before_maturity'),
    pl.col('institutional_traded_before_maturity_raw')
    .alias('institutional_traded_before_maturity'),
    pl.col('disclosed_before_maturity').alias('disclosure_control'),
    pl.concat_str('state', pl.col('year').cast(pl.Int64).cast(pl.String),
                  separator='.').alias('state_year')
).filter(pl.col('year') > 2004)

# Keep the fields used by regressions, descriptives, and sample identification.
# Missing controls stay in the file: fixest handles each model's missingness.
regression_columns = [
    'cusip', 'seed_issuer_id', 'seed_issuer', 'state', 'year', 'state_year',
    'city_go_vote', 'traded_before_maturity', 'retail_traded_before_maturity',
    'institutional_traded_before_maturity', 'low_state_tax_privilege',
    'disclosure_control', 'ln_amount', 'ln_maturity_mths', 'callable',
    'sinkable', 'insured', 'rating_num', 'rating_fe', 'ln_gdp', 'ln_pop',
    'ln_pers_inc', 'purp_broad'
]
data = data.select(regression_columns)

#%% Border sample, preserving one bond row for each matching border group
border_matches = pl.read_csv(
    clean_data_dir / 'Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv',
    infer_schema_length=100000, null_values=['NA', 'NaN']
).filter(pl.col('group').is_in(border_pairs), pl.col('go_unlim') == 1)
# Match the former R override: EXCLUDE_STATE affects only the border sample.
if excluded_state:
    border_matches = border_matches.filter(pl.col('state') != excluded_state)
border_matches = border_matches.select('state', 'seed_issuer', 'group').unique(
    maintain_order=True
)
border_data = border_matches.join(
    data, on=['state', 'seed_issuer'], how='left', nulls_equal=True,
    maintain_order='left_right'
).filter(pl.col('cusip').is_not_null()).select(*regression_columns, 'group')

#%% Write the two analysis inputs
data.write_csv(output_dir / 'trade_full_sample_regression_ready.csv')
border_data.write_csv(output_dir / 'trade_border_sample_regression_ready.csv')
print(f'Full sample: {data.height:,} bonds')
print(f'Border sample: {border_data.height:,} bond/group rows')
print(f'Output directory: {output_dir}')
