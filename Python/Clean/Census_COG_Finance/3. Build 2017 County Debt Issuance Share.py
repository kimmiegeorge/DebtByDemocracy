'''
Build the 2017 county-level Census debt issuance share dataset.

The unit of observation is a county. City issuance is the sum of Census item
29U (long-term debt issued) for municipal governments and townships (Census
government types 2 and 3). Non-city issuance is the corresponding sum for
county, special-district, and school-district governments (types 1, 4, and 5).

The primary outcome is:

    city long-term debt issued
    -----------------------------------------------
    city + non-city long-term debt issued

The share is undefined for counties in which no local government issued
long-term debt during 2017. Those counties remain in the output with a missing
share and an explicit zero-total-issuance flag.
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
        .unique(subset=['county_fips'], keep='first')
    )


#%% -----------------------------------------------------------------------
# aggregate municipal issuance
# -------------------------------------------------------------------------
print('Aggregating 2017 municipal long-term debt issuance to counties...')

city_county = (
    pl.read_csv(city_panel_file, infer_schema_length=10000)
    .filter(
        pl.col('year').eq(target_year)
        & pl.col('government_type').cast(pl.Utf8).is_in(['2', '3'])
    )
    .with_columns([
        pl.col('state').cast(pl.Utf8),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
        pl.col('lt_debt_issued').cast(pl.Float64).fill_null(0),
    ])
    .group_by(['year', 'state', 'county_fips'])
    .agg([
        pl.len().alias('city_governments'),
        (pl.col('lt_debt_issued') > 0).sum().alias('city_governments_with_issuance'),
        (pl.col('lt_debt_issued').sum() * 1000).alias('city_lt_debt_issued_dollars'),
    ])
)


#%% -----------------------------------------------------------------------
# load county non-city issuance and create the county universe
# -------------------------------------------------------------------------
print('Loading 2017 county non-city long-term debt issuance...')

noncity_county = (
    pl.read_csv(noncity_file, infer_schema_length=10000)
    .filter(pl.col('year').eq(target_year))
    .with_columns([
        pl.col('state').cast(pl.Utf8),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
        pl.col('county_nonmunicipal_lt_debt_issued_dollars')
        .cast(pl.Float64)
        .fill_null(0),
    ])
    .select([
        'year',
        'state',
        'county_fips',
        'county_nonmunicipal_governments',
        'county_nonmunicipal_governments_with_end_debt',
        'county_nonmunicipal_lt_debt_issued_dollars',
    ])
)

county_keys = (
    pl.concat([
        city_county.select(['year', 'state', 'county_fips']),
        noncity_county.select(['year', 'state', 'county_fips']),
    ])
    .unique()
)

county_data = (
    county_keys
    .join(city_county, on=['year', 'state', 'county_fips'], how='left')
    .join(noncity_county, on=['year', 'state', 'county_fips'], how='left')
    .with_columns([
        pl.col('city_governments').fill_null(0),
        pl.col('city_governments_with_issuance').fill_null(0),
        pl.col('city_lt_debt_issued_dollars').fill_null(0),
        pl.col('county_nonmunicipal_governments').fill_null(0),
        pl.col('county_nonmunicipal_governments_with_end_debt').fill_null(0),
        pl.col('county_nonmunicipal_lt_debt_issued_dollars').fill_null(0),
    ])
)


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
        (
            pl.col('city_lt_debt_issued_dollars')
            + pl.col('county_nonmunicipal_lt_debt_issued_dollars')
        ).alias('all_local_lt_debt_issued_dollars'),
        pl.col('gdp').log().alias('ln_county_gdp'),
        pl.col('pop').log().alias('ln_county_population'),
        pl.col('pers_inc').log().alias('ln_county_pers_inc'),
    ])
    .with_columns([
        (pl.col('all_local_lt_debt_issued_dollars') > 0)
        .cast(pl.Int8)
        .alias('any_local_lt_debt_issued'),
        pl.when(pl.col('all_local_lt_debt_issued_dollars') > 0)
        .then(
            pl.col('city_lt_debt_issued_dollars')
            / pl.col('all_local_lt_debt_issued_dollars')
        )
        .otherwise(None)
        .alias('city_lt_debt_issued_share'),
    ])
    .sort(['state', 'county_fips'])
)


#%% -----------------------------------------------------------------------
# validate and write
# -------------------------------------------------------------------------
if county_data.select(pl.struct(['year', 'state', 'county_fips']).is_duplicated().any()).item():
    raise ValueError('County-year identifiers are not unique in the output.')

if county_data.filter(
    (pl.col('city_lt_debt_issued_share') < 0)
    | (pl.col('city_lt_debt_issued_share') > 1)
).height > 0:
    raise ValueError('The city issuance share falls outside [0, 1].')

county_data.write_csv(output_file)

print(f'Wrote {county_data.height:,} county observations to {output_file}')
print(
    county_data.select([
        pl.col('state').n_unique().alias('states'),
        pl.col('county_fips').n_unique().alias('counties'),
        pl.col('any_local_lt_debt_issued').sum().alias('counties_with_issuance'),
        (pl.col('any_local_lt_debt_issued') == 0).sum().alias('counties_without_issuance'),
        pl.col('city_lt_debt_issued_dollars').sum().alias('city_issuance_dollars'),
        pl.col('county_nonmunicipal_lt_debt_issued_dollars')
        .sum()
        .alias('noncity_issuance_dollars'),
    ])
)
