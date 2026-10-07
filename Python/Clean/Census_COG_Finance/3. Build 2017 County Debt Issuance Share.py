'''
Build 2017 county identifiers, state policy flags, and BEA economic controls.

The county universe includes municipal/township and nonmunicipal governments.
R/Clean/09_census_county_debt_issuance_share_2017.R uses these controls and
separately constructs city and non-city outstanding debt from Census data.
County demographics use 2016 BEA data, and strict debt limits come from
the current state-policy comparison. The historical output filename is
retained for that downstream reader.
'''

#%% -----------------------------------------------------------------------
# set up
# -------------------------------------------------------------------------
import os
from pathlib import Path

import pandas as pd
import polars as pl


root = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
processed_dir = root / 'Data' / 'Clean_Intermediate' / 'Census COG Finance' / 'processed'
bea_dir = root / 'Data' / 'BEA'

city_panel_file = processed_dir / 'census_cog_city_debt_panel.csv'
noncity_file = processed_dir / 'census_cog_county_nonmunicipal_debt_summary.csv'
policy_file = processed_dir / 'no_refundings' / 'census_mergent_debt_cross_section_2017.csv'
state_policy_file = root / 'Data' / 'State Policies' / '20260929_state_policy_comparison.csv'
output_file = Path(os.getenv(
    'COUNTY_DEBT_SHARE_INPUT_OUTPUT',
    str(processed_dir / 'census_cog_county_debt_issuance_2017.csv')
)).expanduser()

target_year = 2017
demographic_year = target_year - 1
policy_columns = [
    'city_go_vote',
    'state_go_vote',
    'state_utgo_allowed',
    'state_ltgo_allowed',
    'glm_proactive',
]


#%% -----------------------------------------------------------------------
# build the county universe
# -------------------------------------------------------------------------
print('Loading 2017 county identifiers...')

city_county_keys = (
    pl.read_csv(city_panel_file, infer_schema_length=10000)
    .filter(
        pl.col('year').eq(target_year)
        & pl.col('government_type').cast(pl.Utf8).is_in(['2', '3'])
    )
    .select([
        'year',
        pl.col('state').cast(pl.Utf8),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
    ])
    .unique()
)

# Include counties represented only by nonmunicipal governments as well.
noncity_county_keys = (
    pl.read_csv(noncity_file, infer_schema_length=10000)
    .filter(pl.col('year').eq(target_year))
    .select([
        'year',
        pl.col('state').cast(pl.Utf8),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
    ])
    .unique()
)

county_data = pl.concat([city_county_keys, noncity_county_keys]).unique()


#%% -----------------------------------------------------------------------
# attach the paper's state policy sample and county economic controls
# -------------------------------------------------------------------------
print('Attaching state policies and county economic controls...')

raw_policy = (
    pl.read_csv(policy_file, infer_schema_length=10000)
    .with_columns(pl.col(policy_columns).cast(pl.Float64, strict=False))
    .select([
        'state',
        'insample',
        'insample_allgo',
        'insample_utgo_only',
        *policy_columns,
    ])
)

state_policy = (
    raw_policy
    .group_by('state')
    .agg([
        pl.col('insample').max().alias('insample_state'),
        pl.col('insample_allgo').max().alias('insample_allgo_state'),
        pl.col('insample_utgo_only').max().alias('insample_utgo_only_state'),
        *[
            pl.col(column).drop_nulls().first().alias(column)
            for column in policy_columns
        ],
    ])
    .filter(pl.col('insample_state').eq(1))
)

# Strict debt limits are state-level controls. Read the authoritative policy
# file rather than retaining an older value embedded in a cross section.
strict_debt_limits = (
    pl.read_csv(state_policy_file, infer_schema_length=10000)
    .select([
        pl.col('state_abbr').alias('state'),
        pl.col('strict_municipal_debt_limit').cast(pl.Float64),
    ])
)
if strict_debt_limits.height != 50 or strict_debt_limits['state'].n_unique() != 50:
    raise ValueError('State policy must contain one row for each of the 50 states.')
state_policy = state_policy.join(strict_debt_limits, on='state', how='left', validate='1:1')
if state_policy['strict_municipal_debt_limit'].null_count():
    raise ValueError('A regression-sample state is missing its strict debt-limit control.')

# Use the same BEA county series as the main Census point-in-time construction.
county_demographics = (
    pl.from_pandas(pd.read_stata(
        bea_dir / 'countydemos_1999_2026.dta',
        columns=['fips', 'year', 'gdp', 'pop', 'pers_inc'],
        convert_categoricals=False,
    ))
    .filter(pl.col('year').eq(demographic_year))
    .select([
        pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5).alias('county_fips'),
        pl.col('year').cast(pl.Int64).alias('demographic_year'),
        pl.col('gdp', 'pop', 'pers_inc').cast(pl.Float64),
    ])
)

county_data = (
    county_data
    .join(state_policy, on='state', how='inner', validate='m:1')
    .join(county_demographics, on='county_fips', how='left', validate='m:1')
    .with_columns([
        pl.when(pl.col('gdp') > 0).then(pl.col('gdp').log()).alias('ln_county_gdp'),
        pl.when(pl.col('pop') > 0).then(pl.col('pop').log()).alias('ln_county_population'),
        pl.when(pl.col('pers_inc') > 0).then(pl.col('pers_inc').log()).alias('ln_county_pers_inc'),
    ])
    .sort(['state', 'county_fips'])
)


#%% -----------------------------------------------------------------------
# validate and write
# -------------------------------------------------------------------------
if county_data.select(pl.struct(['year', 'state', 'county_fips']).is_duplicated().any()).item():
    raise ValueError('County-year identifiers are not unique in the output.')

output_file.parent.mkdir(parents=True, exist_ok=True)
county_data.write_csv(output_file)

print(f'Wrote {county_data.height:,} county observations to {output_file}')
print(
    county_data.select([
        pl.col('state').n_unique().alias('states'),
        pl.col('county_fips').n_unique().alias('counties'),
    ])
)
