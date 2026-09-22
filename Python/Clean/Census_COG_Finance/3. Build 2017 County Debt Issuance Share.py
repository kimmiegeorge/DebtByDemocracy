'''
Build 2017 county identifiers, state policy flags, and BEA economic controls.

The county universe includes municipal/township and nonmunicipal governments.
R/Clean/09_census_county_debt_issuance_share_2017.R uses these controls and
separately constructs city and non-city outstanding debt from Census data.
The historical output filename is retained for that downstream reader.
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
policy_file = processed_dir / 'census_mergent_debt_cross_section_2017.csv'
output_file = processed_dir / 'census_cog_county_debt_issuance_2017.csv'

target_year = 2017
policy_columns = [
    'city_go_vote',
    'state_go_vote',
    'state_utgo_allowed',
    'state_ltgo_allowed',
    'glm_proactive',
]


def read_bea_county_file(path: Path, value_column: str) -> pl.DataFrame:
    """Read one BEA county panel and retain the target-year county values."""
    frame = pd.read_stata(
        path,
        columns=['fips', 'year', value_column],
        convert_categoricals=False,
    )
    return (
        pl.from_pandas(frame)
        .filter(pl.col('year').eq(target_year))
        .with_columns([
            pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5),
            pl.col(value_column).cast(pl.Float64),
        ])
        .rename({'fips': 'county_fips'})
        .select(['county_fips', value_column])
    )


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
    .select([
        'state',
        'insample',
        'insample_allgo',
        'insample_utgo_only',
        *policy_columns,
    ])
)

policy_consistency = raw_policy.group_by('state').agg([
    pl.col(column).drop_nulls().n_unique().alias(column)
    for column in policy_columns
])
inconsistent = policy_consistency.filter(
    pl.any_horizontal([pl.col(column) > 1 for column in policy_columns])
)
if inconsistent.height > 0:
    raise ValueError(f'Policy values vary within state:\n{inconsistent}')

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

gdp = read_bea_county_file(bea_dir / 'gdp_2001_2022.dta', 'gdp')
population = read_bea_county_file(bea_dir / 'pop_2001_2022.dta', 'pop')
personal_income = read_bea_county_file(bea_dir / 'pers_inc_2001_2022.dta', 'pers_inc')

county_data = (
    county_data
    .join(state_policy, on='state', how='inner')
    .join(gdp, on='county_fips', how='left')
    .join(population, on='county_fips', how='left')
    .join(personal_income, on='county_fips', how='left')
    .with_columns([
        pl.col('gdp').log().alias('ln_county_gdp'),
        pl.col('pop').log().alias('ln_county_population'),
        pl.col('pers_inc').log().alias('ln_county_pers_inc'),
    ])
    .sort(['state', 'county_fips'])
)


#%% -----------------------------------------------------------------------
# validate and write
# -------------------------------------------------------------------------
if county_data.select(pl.struct(['year', 'state', 'county_fips']).is_duplicated().any()).item():
    raise ValueError('County-year identifiers are not unique in the output.')

county_data.write_csv(output_file)

print(f'Wrote {county_data.height:,} county observations to {output_file}')
print(
    county_data.select([
        pl.col('state').n_unique().alias('states'),
        pl.col('county_fips').n_unique().alias('counties'),
    ])
)
