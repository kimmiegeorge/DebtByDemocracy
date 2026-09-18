'''
Build Census-Mergent municipal debt cross sections for COG years.

For each target year, this script creates one row per matched Mergent issuer.
It keeps Census of Governments debt and population measures for that year and
adds Mergent bond-level debt outstanding as of December 31 of the same year.

Mergent debt outstanding treats a bond as outstanding when:
    offering_date <= December 31 of target year
    maturity_date > December 31 of target year

Weighted-average yield spreads use amount outstanding as weights and exclude
bonds with missing offering_yield_spread from the denominator.

Weighted-average ratings use amount outstanding as weights after replacing a
missing issuance-level rating with zero. The issuance-level measure is the
maximum bond-level rating_num within an issuance. The script reconstructs it
from the raw Moody's, S&P, and Fitch fields using the prior Stata rules.
Unrated issuances therefore remain in both the numerator (with a zero
contribution) and denominator.
'''

#%% -----------------------------------------------------------------------
# set up
# -----------------------------------------------------------------------
import os
from datetime import date
from pathlib import Path

import polars as pl

try:
    import pandas as pd
except ImportError:
    pd = None


root = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
data_dir = root / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
census_dir = data_dir / 'Census COG Finance'
mergent_dir = data_dir / 'Mergent' / 'Clean'
clean_census_dir = clean_data_dir / 'Census COG Finance'
border_dir = clean_data_dir / 'Border States'
out_dir = clean_census_dir / 'processed'
diag_dir = clean_census_dir / 'diagnostics'

out_dir.mkdir(parents=True, exist_ok=True)
diag_dir.mkdir(parents=True, exist_ok=True)

target_years = [2012, 2017]

census_panel_file = out_dir / 'census_cog_city_debt_panel.csv'
county_nonmunicipal_file = out_dir / 'census_cog_county_nonmunicipal_debt_summary.csv'
census_mergent_match_file = diag_dir / 'census_cog_2022_mergent_exact_matches.csv'
border_file = border_dir / 'Border Matches All Mergent Data Expanded Set Buffer 100000.csv'

# This is the primary Mergent source for every bond-level construction below.
# It includes all bonds associated with the matched city issuers, including
# valid issuer-name matches added in `newmatch`.
bond_file = mergent_dir / '260917_city_cusiplevel_finsample_allbonds.dta'
# The expanded file does not retain several static controls or the legacy Gao
# spread. These are temporarily read from the prior file only as lookups; all
# bond classifications and aggregations use the expanded file above.
legacy_bond_file = mergent_dir / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
# Rebuilt from the expanded all-bonds file by
# Python/Clean/Yield_Spreads/Compute Yield Spreads.py.
yield_spread_file = clean_data_dir / 'Mergent' / 'Clean' / 'bond_level_off_yield_spread_allbonds.csv'

high_state_tax_privilege_states = {
    'CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN', 'NC', 'ID', 'NY',
    'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE',
}

moody_rating_num = {
    'Aaa': 16, 'Aa1': 15, 'Aa2': 14, 'Aa3': 13, 'A1': 12, 'A2': 11,
    'A3': 10, 'Baa1': 9, 'Baa2': 8, 'Baa3': 7, 'Ba1': 6, 'Ba2': 5,
    'Ba3': 4, 'WR': 1,
}

sp_rating_num = {
    'AAA': 16, 'AA+': 15, 'AA': 14, 'AA-': 13, 'A+': 12, 'A': 11,
    'A-': 10, 'BBB+': 9, 'BBB': 8, 'BBB-': 7, 'BB+': 6, 'BB': 5,
    'BB-': 4, 'B+': 3, 'B': 2,
}

fitch_rating_num = {
    'AAA': 16, 'AA+': 15, 'AA': 14, 'AA-': 13, 'A+': 12, 'A': 11,
    'A-': 10, 'BBB+': 9, 'BBB': 8, 'BBB-': 7, 'BB+': 6, 'BB': 5,
    'BB-': 4, 'B+': 3, 'B': 2, 'W': 1,
}


#%% -----------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------
def require_pandas() -> None:
    if pd is None:
        raise ImportError('pandas is required to read the Mergent Stata files.')


def read_stata_columns(path, columns):
    require_pandas()
    return pl.from_pandas(pd.read_stata(path, columns=columns, convert_categoricals=False))


def normalize_id_columns(df):
    return (
        df
        .with_columns([
            pl.col('seed_issuer_id').cast(pl.Float64).round(1),
            pl.col('seed_issuer').cast(pl.Utf8).str.strip_chars(),
            pl.col('state').cast(pl.Utf8).str.to_uppercase(),
            pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5),
        ])
        .with_columns(
            pl.concat_str([
                (pl.col('seed_issuer_id') * 10).round(0).cast(pl.Int64).cast(pl.Utf8),
                pl.col('state'),
                pl.col('seed_issuer').str.to_uppercase().str.replace_all(r'\s+', ' '),
            ], separator='|').alias('issuer_key')
        )
    )


def weighted_spread_expr(mask, name, value_col='offering_yield_spread'):
    valid = mask & pl.col(value_col).is_not_null()
    numerator = (
        pl.when(valid)
        .then(pl.col('amount') * pl.col(value_col))
        .otherwise(0)
        .sum()
    )
    denominator = (
        pl.when(valid)
        .then(pl.col('amount'))
        .otherwise(0)
        .sum()
    )

    return (
        pl.when(denominator > 0)
        .then(numerator / denominator)
        .otherwise(None)
        .alias(name)
    )


def amount_expr(mask, name):
    return (
        pl.when(mask)
        .then(pl.col('amount'))
        .otherwise(0)
        .sum()
        .alias(name)
    )


def count_expr(mask, name):
    return (
        pl.col('cusip')
        .filter(mask)
        .n_unique()
        .alias(name)
    )


def weighted_average_expr(mask, value_col, name):
    valid = mask & pl.col(value_col).is_not_null()
    numerator = (
        pl.when(valid)
        .then(pl.col('amount') * pl.col(value_col))
        .otherwise(0)
        .sum()
    )
    denominator = (
        pl.when(valid)
        .then(pl.col('amount'))
        .otherwise(0)
        .sum()
    )

    return (
        pl.when(denominator > 0)
        .then(numerator / denominator)
        .otherwise(None)
        .alias(name)
    )


def weighted_average_zero_missing_expr(mask, value_col, name):
    numerator = (
        pl.when(mask)
        .then(pl.col('amount') * pl.col(value_col).fill_null(0))
        .otherwise(0)
        .sum()
    )
    denominator = (
        pl.when(mask)
        .then(pl.col('amount'))
        .otherwise(0)
        .sum()
    )

    return (
        pl.when(denominator > 0)
        .then(numerator / denominator)
        .otherwise(None)
        .alias(name)
    )


def first_non_null_expr(col):
    return pl.col(col).drop_nulls().first().alias(col)


#%% -----------------------------------------------------------------------
# load Census-Mergent match and Census panel
# -----------------------------------------------------------------------
print('Loading Census-Mergent exact match file...')
matches = (
    pl.read_csv(census_mergent_match_file, infer_schema_length=10000)
    .with_columns([
        pl.col('seed_issuer_id').cast(pl.Float64).round(1),
        pl.col('city_go_vote').cast(pl.Float64).cast(pl.Int64, strict=False),
        pl.col('insample').cast(pl.Int64, strict=False),
        pl.col('insample_allgo').cast(pl.Int64, strict=False),
        pl.col('insample_utgo_only').cast(pl.Int64, strict=False),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
    ])
    .filter(pl.col('city_go_vote').is_not_null())
    .unique(subset=['issuer_key'], keep='first')
)

county_matches = (
    matches
    .filter(pl.col('match_type').eq('state_county_name'))
    .select([
        'issuer_key',
        'seed_issuer_id',
        'seed_issuer',
        'state',
        'county_fips',
        pl.col('issuer_city_clean').alias('census_city_clean'),
        'match_type',
    ])
)

state_matches = (
    matches
    .filter(pl.col('match_type').eq('state_name'))
    .select([
        'issuer_key',
        'seed_issuer_id',
        'seed_issuer',
        'state',
        pl.col('issuer_city_clean').alias('census_city_clean'),
        'match_type',
    ])
)

print('Loading Census COG municipal panel...')
census_panel = (
    pl.read_csv(census_panel_file, infer_schema_length=10000)
    .filter(pl.col('year').is_in(target_years))
    .with_columns([
        pl.col('year').cast(pl.Int64),
        pl.col('state').cast(pl.Utf8),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
        pl.col('population').cast(pl.Float64),
        pl.col('end_lt_debt_outstanding_dollars').cast(pl.Float64),
        pl.col('total_end_debt_outstanding_dollars').cast(pl.Float64),
    ])
    .with_columns([
        (pl.col('end_lt_debt_outstanding_dollars') / 1_000_000).alias('census_lt_debt_mil'),
        (pl.col('total_end_debt_outstanding_dollars') / 1_000_000).alias('census_total_debt_mil'),
        pl.when(pl.col('population') > 0)
        .then(pl.col('end_lt_debt_outstanding_dollars') / pl.col('population'))
        .otherwise(None)
        .alias('census_lt_debt_per_capita'),
        pl.when(pl.col('population') > 0)
        .then(pl.col('total_end_debt_outstanding_dollars') / pl.col('population'))
        .otherwise(None)
        .alias('census_total_debt_per_capita'),
        pl.col('population').alias('census_population'),
    ])
)

county_nonmunicipal = (
    pl.read_csv(county_nonmunicipal_file, infer_schema_length=10000)
    .filter(pl.col('year').is_in(target_years))
    .with_columns([
        pl.col('year').cast(pl.Int64),
        pl.col('state').cast(pl.Utf8),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
        pl.col('county_nonmunicipal_end_lt_debt_outstanding_dollars').cast(pl.Float64),
        pl.col('county_nonmunicipal_end_short_term_debt_outstanding_dollars').cast(pl.Float64),
        pl.col('county_nonmunicipal_total_end_debt_outstanding_dollars').cast(pl.Float64),
        pl.col('county_nonmunicipal_lt_debt_issued_dollars').cast(pl.Float64),
    ])
    .with_columns([
        (pl.col('county_nonmunicipal_end_lt_debt_outstanding_dollars') / 1_000_000)
        .alias('county_nonmunicipal_lt_debt_mil'),
        (pl.col('county_nonmunicipal_total_end_debt_outstanding_dollars') / 1_000_000)
        .alias('county_nonmunicipal_total_debt_mil'),
        (pl.col('county_nonmunicipal_lt_debt_issued_dollars') / 1_000_000)
        .alias('county_nonmunicipal_lt_debt_issued_mil'),
        (pl.col('county_nonmunicipal_total_end_debt_outstanding_dollars') + 1)
        .log()
        .alias('ln_1p_county_nonmunicipal_total_debt'),
    ])
    .select([
        'year',
        'state',
        'county_fips',
        'county_nonmunicipal_governments',
        'county_nonmunicipal_governments_with_end_debt',
        'county_nonmunicipal_end_lt_debt_outstanding_dollars',
        'county_nonmunicipal_end_short_term_debt_outstanding_dollars',
        'county_nonmunicipal_total_end_debt_outstanding_dollars',
        'county_nonmunicipal_lt_debt_issued_dollars',
        'county_nonmunicipal_lt_debt_mil',
        'county_nonmunicipal_total_debt_mil',
        'county_nonmunicipal_lt_debt_issued_mil',
        'ln_1p_county_nonmunicipal_total_debt',
    ])
)

census_county = (
    county_matches
    .join(
        census_panel,
        on=['state', 'county_fips', 'census_city_clean'],
        how='inner',
    )
)

matched_census_keys = census_county.select(['year', 'gov_id']).unique()
remaining_census = census_panel.join(
    matched_census_keys,
    on=['year', 'gov_id'],
    how='anti',
)

census_state = (
    state_matches
    .join(
        remaining_census,
        on=['state', 'census_city_clean'],
        how='inner',
    )
)

census_cross_section = (
    pl.concat([census_county, census_state], how='diagonal')
    .unique(subset=['year', 'issuer_key'], keep='first')
    .select([
        'year',
        'issuer_key',
        'seed_issuer_id',
        'seed_issuer',
        'gov_id',
        'census_name',
        'government_type',
        'government_type_label',
        'state',
        'county_fips',
        'county_name',
        'place_fips_full',
        'census_city_clean',
        'match_type',
        'census_population',
        'census_lt_debt_mil',
        'census_total_debt_mil',
        'census_lt_debt_per_capita',
        'census_total_debt_per_capita',
    ])
)

county_nonmunicipal_cols = [
    'county_nonmunicipal_governments',
    'county_nonmunicipal_governments_with_end_debt',
    'county_nonmunicipal_end_lt_debt_outstanding_dollars',
    'county_nonmunicipal_end_short_term_debt_outstanding_dollars',
    'county_nonmunicipal_total_end_debt_outstanding_dollars',
    'county_nonmunicipal_lt_debt_issued_dollars',
    'county_nonmunicipal_lt_debt_mil',
    'county_nonmunicipal_total_debt_mil',
    'county_nonmunicipal_lt_debt_issued_mil',
]

census_cross_section = (
    census_cross_section
    .join(county_nonmunicipal, on=['year', 'state', 'county_fips'], how='left')
    .with_columns([
        pl.col(col).fill_null(0).alias(col)
        for col in county_nonmunicipal_cols
    ])
    .with_columns([
        (pl.col('county_nonmunicipal_total_end_debt_outstanding_dollars') + 1)
        .log()
        .alias('ln_1p_county_nonmunicipal_total_debt'),
    ])
)


#%% -----------------------------------------------------------------------
# load Mergent bond-level data, controls, and outstanding debt measures
# -----------------------------------------------------------------------
print('Loading expanded Mergent bond-level file...')
bond_cols = [
    'cusip',
    'issue_id',
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'fips',
    'offering_date',
    'maturity_date',
    'amount',
    'bond_type',
    'security_code',
    'go_unlim',
    'go_lim',
    'rev',
    'insured',
    'callable',
    'sinkable',
    'rated',
    'rating_f',
    'rating_m',
    'rating_s',
    'city_go_vote',
    'city_rev_vote',
]

raw_bonds = read_stata_columns(bond_file, bond_cols)

# The expanded file lacks a few static issuer controls and the legacy Gao
# spread. Preserve those values for the existing CUSIPs while the expanded
# file supplies every bond-level classification and characteristic.
legacy_control_cols = [
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'fips',
    'state_name',
    'nh_city',
    'state_go_vote',
    'state_utgo_allowed',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'glm_proactive',
]

print('Loading legacy issuer-control and Gao-spread lookups...')
legacy_controls = (
    read_stata_columns(legacy_bond_file, legacy_control_cols)
    .pipe(normalize_id_columns)
    .group_by('issuer_key')
    .agg([
        first_non_null_expr(col)
        for col in legacy_control_cols
        if col not in {'seed_issuer_id', 'seed_issuer', 'state', 'fips'}
    ])
)

legacy_gao_spreads = (
    read_stata_columns(
        legacy_bond_file,
        ['issue_id', 'cusip', 'offering_yield_spread'],
    )
    .rename({'offering_yield_spread': 'offering_yield_spread_gao'})
    .with_columns([
        pl.col('issue_id').cast(pl.Int64),
        pl.col('cusip').cast(pl.Utf8),
        pl.col('offering_yield_spread_gao').cast(pl.Float64),
    ])
    .unique(subset=['issue_id', 'cusip'])
)

# The NC spread is rebuilt for the expanded all-bonds universe by
# Python/Clean/Yield_Spreads/Compute Yield Spreads.py.
nc_spreads = (
    pl.read_csv(yield_spread_file, infer_schema_length=10000)
    .select([
        pl.col('issue_id').cast(pl.Int64),
        pl.col('cusip').cast(pl.Utf8),
        pl.col('offering_yield_spread_nc').cast(pl.Float64),
    ])
    .unique(subset=['issue_id', 'cusip'])
)

raw_bonds = (
    raw_bonds
    .pipe(normalize_id_columns)
    .with_columns([
        pl.col('issue_id').cast(pl.Int64),
        pl.col('cusip').cast(pl.Utf8),
    ])
    .join(legacy_controls, on='issuer_key', how='left')
    .join(legacy_gao_spreads, on=['issue_id', 'cusip'], how='left')
    .join(nc_spreads, on=['issue_id', 'cusip'], how='left')
    .with_columns(
        pl.col('offering_yield_spread_nc').alias('offering_yield_spread')
    )
)

issuer_control_cols = [
    'seed_issuer_id',
    'seed_issuer',
    'fips',
    'state',
    'state_name',
    'city_go_vote',
    'city_rev_vote',
    'nh_city',
    'state_go_vote',
    'state_utgo_allowed',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'glm_proactive',
]

issuers = (
    raw_bonds
    .select(issuer_control_cols)
    .filter(pl.col('seed_issuer_id').is_not_null())
    .pipe(normalize_id_columns)
    .group_by(['issuer_key', 'seed_issuer_id', 'seed_issuer', 'state'])
    .agg([
        first_non_null_expr(col)
        for col in issuer_control_cols
        if col not in {'seed_issuer_id', 'seed_issuer', 'state'}
    ])
    .with_columns([
        pl.col('state')
        .is_in(high_state_tax_privilege_states)
        .cast(pl.Int8)
        .alias('high_state_tax_privilege'),
        (
            pl.col('city_go_vote').eq(0)
            & pl.col('city_rev_vote').eq(0)
        ).fill_null(False).cast(pl.Int8).alias('control'),
        pl.col('state').is_in(['WA', 'MI', 'OH']).cast(pl.Int8).alias('utgo_only'),
    ])
    .with_columns([
        (
            pl.col('city_go_vote').eq(1)
            & pl.col('city_rev_vote').eq(0)
            & pl.col('utgo_only').eq(0)
        ).fill_null(False).cast(pl.Int8).alias('allgo_only'),
    ])
    .with_columns([
        (
            pl.col('control').eq(1)
            | pl.col('utgo_only').eq(1)
            | pl.col('allgo_only').eq(1)
        ).cast(pl.Int8).alias('insample'),
        (
            pl.col('control').eq(1)
            | pl.col('allgo_only').eq(1)
        ).cast(pl.Int8).alias('insample_allgo'),
        (
            pl.col('control').eq(1)
            | pl.col('utgo_only').eq(1)
        ).cast(pl.Int8).alias('insample_utgo_only'),
    ])
)

bonds = (
    raw_bonds
    .pipe(normalize_id_columns)
    .with_columns([
        pl.col('issue_id').cast(pl.Int64, strict=False),
        pl.col('amount').cast(pl.Float64),
        pl.col('offering_yield_spread').cast(pl.Float64),
        pl.col('offering_yield_spread_nc').cast(pl.Float64),
        pl.col('offering_yield_spread_gao').cast(pl.Float64),
        pl.col('security_code').cast(pl.Utf8),
        pl.col('bond_type').cast(pl.Utf8),
        pl.col('go_unlim').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('go_lim').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('rated').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('insured').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('callable').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('sinkable').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('rating_f').cast(pl.Utf8).str.strip_chars(),
        pl.col('rating_m').cast(pl.Utf8).str.strip_chars(),
        pl.col('rating_s').cast(pl.Utf8).str.strip_chars(),
        pl.col('offering_date').cast(pl.Date),
        pl.col('maturity_date').cast(pl.Date),
    ])
    # The historical Stata rating construction found Moody's and S&P stored
    # in the opposite raw fields, so preserve that correction here.
    .with_columns([
        pl.col('rating_s').alias('rating_m'),
        pl.col('rating_m').alias('rating_s'),
    ])
    .with_columns(
        pl.when(pl.col('rating_m').eq('#Aaa'))
        .then(pl.lit('Aaa'))
        .otherwise(pl.col('rating_m'))
        .alias('rating_m')
    )
    .with_columns(
        pl.coalesce([
            pl.col('rating_m').replace_strict(moody_rating_num, default=None),
            pl.col('rating_s').replace_strict(sp_rating_num, default=None),
            pl.col('rating_f').replace_strict(fitch_rating_num, default=None),
        ]).cast(pl.Float64).alias('rating_num')
    )
    .with_columns(
        pl.when(pl.col('rated').eq(0))
        .then(pl.lit(0.0))
        .otherwise(pl.col('rating_num'))
        .alias('rating_num')
    )
    .filter(
        pl.col('seed_issuer_id').is_not_null()
        & pl.col('amount').is_not_null()
        & (pl.col('amount') > 0)
        & pl.col('offering_date').is_not_null()
        & pl.col('maturity_date').is_not_null()
    )
    .with_columns([
        pl.col('bond_type').eq('go').alias('all_go'),
        (pl.col('bond_type').eq('go') & pl.col('go_unlim').eq(1)).alias('utgo'),
        (pl.col('bond_type').eq('go') & pl.col('go_lim').eq(1)).alias('ltgo'),
        pl.col('bond_type').eq('rev').alias('revenue'),
        (
            pl.col('security_code').is_in(['C', 'N'])
            & ~pl.col('bond_type').eq('go')
        ).alias('lease_rent_loan_agreement'),
        (
            pl.col('bond_type').eq('rev')
            & ~pl.col('security_code').is_in(['C', 'N'])
        ).alias('revenue_non_lease_rent_loan_agreement'),
    ])
)

rating_issues = (
    bonds
    .group_by('issue_id')
    .agg([
        pl.col('rating_num').max().alias('rating_issue_max_raw'),
        pl.col('insured').max().alias('insured_issue'),
    ])
    .with_columns([
        (
            pl.col('rating_issue_max_raw').eq(0)
            & pl.col('insured_issue').eq(0)
        ).cast(pl.Int8).alias('issue_unrated'),
        pl.when(
            pl.col('rating_issue_max_raw').eq(0)
            & pl.col('insured_issue').eq(1)
        )
        .then(pl.lit(16.0))
        .when(pl.col('rating_issue_max_raw').eq(0))
        .then(pl.lit(None).cast(pl.Float64))
        .otherwise(pl.col('rating_issue_max_raw'))
        .alias('rating_issue_max'),
    ])
    .select(['issue_id', 'issue_unrated', 'rating_issue_max'])
)

bonds = bonds.join(rating_issues, on='issue_id', how='left')

mergent_years = []

for year in target_years:
    as_of = date(year, 12, 31)
    print(f'Computing Mergent outstanding debt as of 12/31/{year}...')

    outstanding = (
        bonds
        .filter(
            (pl.col('offering_date') <= as_of)
            & (pl.col('maturity_date') > as_of)
        )
        .with_columns(
            (
                (pl.col('maturity_date') - pl.col('offering_date'))
                .dt.total_days()
                / 365.25
            ).alias('original_maturity_years')
        )
    )

    any_go_or_revenue = pl.col('all_go') | pl.col('revenue')
    all_go = pl.col('all_go')
    revenue = pl.col('revenue')
    utgo = pl.col('utgo')
    ltgo = pl.col('ltgo')
    lease_rent_loan_agreement = pl.col('lease_rent_loan_agreement')
    revenue_non_lease_rent_loan_agreement = pl.col('revenue_non_lease_rent_loan_agreement')
    go_revenue_for_composition = all_go | revenue_non_lease_rent_loan_agreement
    all_bonds = pl.lit(True)

    agg = (
        outstanding
        .group_by('issuer_key')
        .agg([
            amount_expr(all_bonds, 'mergent_total_outstanding_debt'),
            amount_expr(any_go_or_revenue, 'mergent_go_revenue_outstanding_debt'),
            amount_expr(all_go, 'mergent_all_go_outstanding_debt'),
            amount_expr(revenue, 'mergent_revenue_outstanding_debt'),
            amount_expr(utgo, 'mergent_utgo_outstanding_debt'),
            amount_expr(ltgo, 'mergent_ltgo_outstanding_debt'),
            amount_expr(
                lease_rent_loan_agreement,
                'mergent_lease_rent_loan_agreement_outstanding_debt',
            ),
            amount_expr(
                go_revenue_for_composition,
                'mergent_go_revenue_for_composition_outstanding_debt',
            ),
            amount_expr(
                revenue_non_lease_rent_loan_agreement,
                'mergent_revenue_non_lease_rent_loan_agreement_outstanding_debt',
            ),
            count_expr(all_bonds, 'mergent_total_bonds_outstanding'),
            count_expr(any_go_or_revenue, 'mergent_go_revenue_bonds_outstanding'),
            count_expr(all_go, 'mergent_all_go_bonds_outstanding'),
            count_expr(revenue, 'mergent_revenue_bonds_outstanding'),
            count_expr(utgo, 'mergent_utgo_bonds_outstanding'),
            count_expr(ltgo, 'mergent_ltgo_bonds_outstanding'),
            count_expr(
                lease_rent_loan_agreement,
                'mergent_lease_rent_loan_agreement_bonds_outstanding',
            ),
            weighted_spread_expr(any_go_or_revenue, 'mergent_wavg_yield_spread_go_revenue'),
            weighted_spread_expr(revenue, 'mergent_wavg_yield_spread_revenue'),
            weighted_spread_expr(all_go, 'mergent_wavg_yield_spread_all_go'),
            weighted_spread_expr(utgo, 'mergent_wavg_yield_spread_utgo'),
            weighted_spread_expr(ltgo, 'mergent_wavg_yield_spread_ltgo'),
            weighted_spread_expr(
                any_go_or_revenue,
                'mergent_wavg_yield_spread_go_revenue_nc',
                'offering_yield_spread_nc',
            ),
            weighted_spread_expr(
                revenue,
                'mergent_wavg_yield_spread_revenue_nc',
                'offering_yield_spread_nc',
            ),
            weighted_spread_expr(
                all_go,
                'mergent_wavg_yield_spread_all_go_nc',
                'offering_yield_spread_nc',
            ),
            weighted_spread_expr(
                utgo,
                'mergent_wavg_yield_spread_utgo_nc',
                'offering_yield_spread_nc',
            ),
            weighted_spread_expr(
                ltgo,
                'mergent_wavg_yield_spread_ltgo_nc',
                'offering_yield_spread_nc',
            ),
            weighted_spread_expr(
                any_go_or_revenue,
                'mergent_wavg_yield_spread_go_revenue_gao',
                'offering_yield_spread_gao',
            ),
            weighted_spread_expr(
                revenue,
                'mergent_wavg_yield_spread_revenue_gao',
                'offering_yield_spread_gao',
            ),
            weighted_spread_expr(
                all_go,
                'mergent_wavg_yield_spread_all_go_gao',
                'offering_yield_spread_gao',
            ),
            weighted_spread_expr(
                utgo,
                'mergent_wavg_yield_spread_utgo_gao',
                'offering_yield_spread_gao',
            ),
            weighted_spread_expr(
                ltgo,
                'mergent_wavg_yield_spread_ltgo_gao',
                'offering_yield_spread_gao',
            ),
            weighted_average_expr(
                any_go_or_revenue,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_go_revenue',
            ),
            weighted_average_expr(
                all_go,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_all_go',
            ),
            weighted_average_expr(
                utgo,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_utgo',
            ),
            weighted_average_expr(
                ltgo,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_ltgo',
            ),
            weighted_average_expr(
                revenue,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_revenue',
            ),
            weighted_average_zero_missing_expr(
                any_go_or_revenue,
                'rating_issue_max',
                'mergent_wavg_rating_go_revenue_zero_unrated',
            ),
            weighted_average_zero_missing_expr(
                all_go,
                'rating_issue_max',
                'mergent_wavg_rating_all_go_zero_unrated',
            ),
            weighted_average_zero_missing_expr(
                utgo,
                'rating_issue_max',
                'mergent_wavg_rating_utgo_zero_unrated',
            ),
            weighted_average_zero_missing_expr(
                ltgo,
                'rating_issue_max',
                'mergent_wavg_rating_ltgo_zero_unrated',
            ),
            weighted_average_zero_missing_expr(
                revenue,
                'rating_issue_max',
                'mergent_wavg_rating_revenue_zero_unrated',
            ),
            *[
                weighted_average_zero_missing_expr(
                    mask,
                    feature,
                    f'mergent_wavg_{feature}_{suffix}',
                )
                for feature in ['insured', 'callable', 'sinkable']
                for mask, suffix in [
                    (any_go_or_revenue, 'go_revenue'),
                    (all_go, 'all_go'),
                    (utgo, 'utgo'),
                    (ltgo, 'ltgo'),
                    (revenue, 'revenue'),
                ]
            ],
        ])
        # The weighted averages are par shares because the underlying bond
        # characteristics are binary. A share of zero is also recorded as a
        # separate nonlinear "none of the outstanding bonds" indicator.
        .with_columns([
            pl.col(f'mergent_wavg_{feature}_{suffix}')
            .eq(0)
            .cast(pl.Int8)
            .alias(f'mergent_none_{feature}_{suffix}')
            for feature in ['insured', 'callable', 'sinkable']
            for suffix in ['go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue']
        ])
        .with_columns([
            pl.col(f'mergent_wavg_{feature}_{suffix}')
            .gt(0)
            .cast(pl.Int8)
            .alias(f'mergent_any_{feature}_{suffix}')
            for feature in ['insured', 'callable', 'sinkable']
            for suffix in ['go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue']
        ])
        .with_columns(pl.lit(year).alias('year'))
    )

    mergent_years.append(agg)

mergent_outstanding = pl.concat(mergent_years, how='diagonal')

mergent_amount_cols = [
    'mergent_total_outstanding_debt',
    'mergent_go_revenue_outstanding_debt',
    'mergent_all_go_outstanding_debt',
    'mergent_revenue_outstanding_debt',
    'mergent_utgo_outstanding_debt',
    'mergent_ltgo_outstanding_debt',
    'mergent_lease_rent_loan_agreement_outstanding_debt',
    'mergent_go_revenue_for_composition_outstanding_debt',
    'mergent_revenue_non_lease_rent_loan_agreement_outstanding_debt',
]

mergent_outstanding = mergent_outstanding.with_columns([
    (pl.col(col) / 1_000_000).alias(col.replace('_debt', '_debt_mil'))
    for col in mergent_amount_cols
])


#%% -----------------------------------------------------------------------
# merge and save full and border samples
# -----------------------------------------------------------------------
print('Merging Census, Mergent outstanding debt, and controls...')
full_panel = (
    census_cross_section
    .join(issuers, on='issuer_key', how='left', suffix='_issuer')
    .join(mergent_outstanding, on=['issuer_key', 'year'], how='left')
)

for col in mergent_amount_cols:
    full_panel = full_panel.with_columns(pl.col(col).fill_null(0))
    full_panel = full_panel.with_columns(pl.col(col.replace('_debt', '_debt_mil')).fill_null(0))

# Debt-composition shares used in the point-in-time debt-choice analysis. The
# original shares partition the paper's GO + strict-revenue measure. The `_wrl`
# versions add lease/rent and loan-agreement debt to the denominator and include
# its corresponding share. A zero denominator is recorded as missing.
go_revenue_plus_lease_rent_loan_agreement = (
    pl.col('mergent_go_revenue_for_composition_outstanding_debt')
    + pl.col('mergent_lease_rent_loan_agreement_outstanding_debt')
)

full_panel = full_panel.with_columns([
    pl.when(pl.col('mergent_go_revenue_outstanding_debt') > 0)
    .then(
        pl.col('mergent_utgo_outstanding_debt')
        / pl.col('mergent_go_revenue_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_utgo_outstanding'),
    pl.when(pl.col('mergent_go_revenue_outstanding_debt') > 0)
    .then(
        pl.col('mergent_ltgo_outstanding_debt')
        / pl.col('mergent_go_revenue_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_ltgo_outstanding'),
    pl.when(pl.col('mergent_go_revenue_outstanding_debt') > 0)
    .then(
        pl.col('mergent_revenue_outstanding_debt')
        / pl.col('mergent_go_revenue_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_rev_outstanding'),
    pl.when(go_revenue_plus_lease_rent_loan_agreement > 0)
    .then(
        pl.col('mergent_utgo_outstanding_debt')
        / go_revenue_plus_lease_rent_loan_agreement
    )
    .otherwise(None)
    .alias('frac_utgo_outstanding_wrl'),
    pl.when(go_revenue_plus_lease_rent_loan_agreement > 0)
    .then(
        pl.col('mergent_ltgo_outstanding_debt')
        / go_revenue_plus_lease_rent_loan_agreement
    )
    .otherwise(None)
    .alias('frac_ltgo_outstanding_wrl'),
    pl.when(go_revenue_plus_lease_rent_loan_agreement > 0)
    .then(
        pl.col('mergent_revenue_non_lease_rent_loan_agreement_outstanding_debt')
        / go_revenue_plus_lease_rent_loan_agreement
    )
    .otherwise(None)
    .alias('frac_rev_outstanding_wrl'),
    pl.when(go_revenue_plus_lease_rent_loan_agreement > 0)
    .then(
        pl.col('mergent_lease_rent_loan_agreement_outstanding_debt')
        / go_revenue_plus_lease_rent_loan_agreement
    )
    .otherwise(None)
    .alias('frac_lease_rent_loan_agreement_outstanding_wrl'),
])

border_memberships = (
    pl.read_csv(border_file, infer_schema_length=10000)
    .pipe(normalize_id_columns)
    .select([
        'issuer_key',
        'seed_issuer_id',
        'seed_issuer',
        'state',
        pl.col('group').alias('border_group'),
        pl.col('category').alias('border_category'),
    ])
    .filter(
        pl.col('seed_issuer_id').is_not_null()
        & pl.col('border_group').is_not_null()
    )
    .unique()
    .with_columns(pl.lit(1).alias('border_sample'))
)

border_flags = (
    border_memberships
    .group_by('issuer_key')
    .agg([
        pl.lit(1).alias('border_sample'),
        pl.col('border_group').n_unique().alias('border_group_count'),
    ])
)

full_panel = (
    full_panel
    .join(border_flags, on='issuer_key', how='left')
    .with_columns([
        pl.col('border_sample').fill_null(0),
        pl.col('border_group_count').fill_null(0),
    ])
)

border_panel = (
    full_panel
    .filter(pl.col('border_sample').eq(1))
    .drop('border_sample')
    .join(border_memberships, on='issuer_key', how='inner', suffix='_border')
)

ordered_cols_base = [
    'year',
    'issuer_key',
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'state_name',
    'fips',
    'city_go_vote',
    'city_rev_vote',
    'nh_city',
    'control',
    'utgo_only',
    'allgo_only',
    'insample',
    'insample_allgo',
    'insample_utgo_only',
    'state_go_vote',
    'state_utgo_allowed',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'glm_proactive',
    'high_state_tax_privilege',
    'gov_id',
    'census_name',
    'government_type',
    'government_type_label',
    'county_fips',
    'county_name',
    'place_fips_full',
    'census_city_clean',
    'match_type',
    'census_population',
    'census_lt_debt_mil',
    'census_total_debt_mil',
    'census_lt_debt_per_capita',
    'census_total_debt_per_capita',
    'county_nonmunicipal_governments',
    'county_nonmunicipal_governments_with_end_debt',
    'county_nonmunicipal_lt_debt_mil',
    'county_nonmunicipal_total_debt_mil',
    'county_nonmunicipal_lt_debt_issued_mil',
    'ln_1p_county_nonmunicipal_total_debt',
    'mergent_total_outstanding_debt',
    'mergent_total_outstanding_debt_mil',
    'mergent_lease_rent_loan_agreement_outstanding_debt',
    'mergent_lease_rent_loan_agreement_outstanding_debt_mil',
    'mergent_go_revenue_for_composition_outstanding_debt',
    'mergent_go_revenue_for_composition_outstanding_debt_mil',
    'mergent_revenue_non_lease_rent_loan_agreement_outstanding_debt',
    'mergent_revenue_non_lease_rent_loan_agreement_outstanding_debt_mil',
    'frac_utgo_outstanding',
    'frac_ltgo_outstanding',
    'frac_rev_outstanding',
    'frac_utgo_outstanding_wrl',
    'frac_ltgo_outstanding_wrl',
    'frac_rev_outstanding_wrl',
    'frac_lease_rent_loan_agreement_outstanding_wrl',
    'mergent_go_revenue_outstanding_debt',
    'mergent_go_revenue_outstanding_debt_mil',
    'mergent_all_go_outstanding_debt',
    'mergent_all_go_outstanding_debt_mil',
    'mergent_revenue_outstanding_debt',
    'mergent_revenue_outstanding_debt_mil',
    'mergent_utgo_outstanding_debt',
    'mergent_utgo_outstanding_debt_mil',
    'mergent_ltgo_outstanding_debt',
    'mergent_ltgo_outstanding_debt_mil',
    'mergent_total_bonds_outstanding',
    'mergent_lease_rent_loan_agreement_bonds_outstanding',
    'mergent_go_revenue_bonds_outstanding',
    'mergent_all_go_bonds_outstanding',
    'mergent_revenue_bonds_outstanding',
    'mergent_utgo_bonds_outstanding',
    'mergent_ltgo_bonds_outstanding',
    'mergent_wavg_yield_spread_go_revenue',
    'mergent_wavg_yield_spread_revenue',
    'mergent_wavg_yield_spread_all_go',
    'mergent_wavg_yield_spread_utgo',
    'mergent_wavg_yield_spread_ltgo',
    'mergent_wavg_yield_spread_go_revenue_nc',
    'mergent_wavg_yield_spread_revenue_nc',
    'mergent_wavg_yield_spread_all_go_nc',
    'mergent_wavg_yield_spread_utgo_nc',
    'mergent_wavg_yield_spread_ltgo_nc',
    'mergent_wavg_yield_spread_go_revenue_gao',
    'mergent_wavg_yield_spread_revenue_gao',
    'mergent_wavg_yield_spread_all_go_gao',
    'mergent_wavg_yield_spread_utgo_gao',
    'mergent_wavg_yield_spread_ltgo_gao',
    'mergent_wavg_original_maturity_years_go_revenue',
    'mergent_wavg_original_maturity_years_all_go',
    'mergent_wavg_original_maturity_years_utgo',
    'mergent_wavg_original_maturity_years_ltgo',
    'mergent_wavg_original_maturity_years_revenue',
    'mergent_wavg_rating_go_revenue_zero_unrated',
    'mergent_wavg_rating_all_go_zero_unrated',
    'mergent_wavg_rating_utgo_zero_unrated',
    'mergent_wavg_rating_ltgo_zero_unrated',
    'mergent_wavg_rating_revenue_zero_unrated',
    *[
        f'mergent_wavg_{feature}_{suffix}'
        for feature in ['insured', 'callable', 'sinkable']
        for suffix in ['go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue']
    ],
    *[
        f'mergent_none_{feature}_{suffix}'
        for feature in ['insured', 'callable', 'sinkable']
        for suffix in ['go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue']
    ],
    *[
        f'mergent_any_{feature}_{suffix}'
        for feature in ['insured', 'callable', 'sinkable']
        for suffix in ['go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue']
    ],
    'border_sample',
    'border_group_count',
    'border_group',
    'border_category',
]

ordered_cols = [col for col in ordered_cols_base if col in full_panel.columns]
border_ordered_cols = [col for col in ordered_cols_base if col in border_panel.columns]

for year in target_years:
    full_out = full_panel.filter(pl.col('year').eq(year)).select(ordered_cols)
    border_out = border_panel.filter(pl.col('year').eq(year)).select(border_ordered_cols)

    full_path = out_dir / f'census_mergent_debt_cross_section_{year}.csv'
    border_path = out_dir / f'census_mergent_debt_cross_section_{year}_border_sample.csv'

    full_out.write_csv(full_path)
    border_out.write_csv(border_path)

    print(f'Wrote {full_path}: {full_out.height:,} rows')
    print(f'Wrote {border_path}: {border_out.height:,} rows')


#%% -----------------------------------------------------------------------
# diagnostics
# -----------------------------------------------------------------------
diagnostics = (
    full_panel
    .group_by('year')
    .agg([
        pl.len().alias('matched_issuers'),
        (pl.len() - pl.col('gov_id').n_unique()).alias('duplicate_census_gov_rows'),
        pl.col('border_sample').sum().alias('border_matched_issuers'),
        pl.col('border_group_count').sum().alias('border_expanded_rows'),
        pl.col('city_go_vote').eq(0).sum().alias('control_issuers'),
        pl.col('city_go_vote').eq(1).sum().alias('treat_issuers'),
        (pl.col('mergent_go_revenue_outstanding_debt') > 0).sum().alias('issuers_with_mergent_debt'),
        (pl.col('mergent_total_outstanding_debt') > 0).sum().alias('issuers_with_total_mergent_debt'),
        pl.col('mergent_wavg_yield_spread_go_revenue').is_not_null().sum().alias('issuers_with_mergent_yield_spread'),
    ])
    .sort('year')
)

diagnostics.write_csv(diag_dir / 'census_mergent_debt_cross_section_diagnostics.csv')
print(diagnostics)
