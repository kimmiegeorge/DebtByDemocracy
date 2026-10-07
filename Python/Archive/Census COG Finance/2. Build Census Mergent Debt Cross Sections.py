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
census_dir = data_dir / 'Census COG Finance'
mergent_dir = data_dir / 'Mergent' / 'Clean'
border_dir = data_dir / 'Border States'
out_dir = census_dir / 'processed'
diag_dir = census_dir / 'diagnostics'

out_dir.mkdir(parents=True, exist_ok=True)
diag_dir.mkdir(parents=True, exist_ok=True)

target_years = [2012, 2017]

census_panel_file = out_dir / 'census_cog_city_debt_panel.csv'
county_nonmunicipal_file = out_dir / 'census_cog_county_nonmunicipal_debt_summary.csv'
census_mergent_match_file = diag_dir / 'census_cog_2022_mergent_exact_matches.csv'
border_file = border_dir / 'Border Matches All Mergent Data Expanded Set Buffer 100000 20260611.csv'

bond_file = mergent_dir / '260709_city_cusiplevel_statereq_purpose_yieldspread.dta'

high_state_tax_privilege_states = {
    'CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN', 'NC', 'ID', 'NY',
    'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE',
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
            pl.col('seed_issuer_id').cast(pl.Float64).cast(pl.Int64),
            pl.col('state').cast(pl.Utf8).str.to_uppercase(),
            pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5),
        ])
    )


def weighted_spread_expr(mask, name):
    valid = mask & pl.col('offering_yield_spread').is_not_null()
    numerator = (
        pl.when(valid)
        .then(pl.col('amount') * pl.col('offering_yield_spread'))
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


def first_non_null_expr(col):
    return pl.col(col).drop_nulls().first().alias(col)


#%% -----------------------------------------------------------------------
# load Census-Mergent match and Census panel
# -----------------------------------------------------------------------
print('Loading Census-Mergent exact match file...')
matches = (
    pl.read_csv(census_mergent_match_file, infer_schema_length=10000)
    .with_columns([
        pl.col('seed_issuer_id').cast(pl.Float64).cast(pl.Int64),
        pl.col('city_go_vote').cast(pl.Float64).cast(pl.Int64, strict=False),
        pl.col('insample').cast(pl.Int64, strict=False),
        pl.col('insample_allgo').cast(pl.Int64, strict=False),
        pl.col('insample_utgo_only').cast(pl.Int64, strict=False),
        pl.col('county_fips').cast(pl.Utf8).str.zfill(5),
    ])
    .filter(pl.col('city_go_vote').is_not_null())
    .unique(subset=['seed_issuer_id'], keep='first')
)

county_matches = (
    matches
    .filter(pl.col('match_type').eq('state_county_name'))
    .select([
        'seed_issuer_id',
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
        'seed_issuer_id',
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
    .unique(subset=['year', 'seed_issuer_id'], keep='first')
    .select([
        'year',
        'seed_issuer_id',
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
# load Mergent bond-level file, controls, and outstanding debt measures
# -----------------------------------------------------------------------
print('Loading Mergent bond-level file...')
bond_cols = [
    'cusip',
    'issue_id',
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'state_name',
    'fips',
    'offering_date',
    'maturity_date',
    'amount',
    'go_unlim',
    'go_lim',
    'rev',
    'rating_issue_max',
    'offering_yield_spread',
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

raw_bonds = read_stata_columns(bond_file, bond_cols)

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
    .with_columns([
        pl.col('seed_issuer_id').cast(pl.Float64).cast(pl.Int64),
        pl.col('state').cast(pl.Utf8).str.to_uppercase(),
        pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5),
    ])
    .group_by('seed_issuer_id')
    .agg([first_non_null_expr(col) for col in issuer_control_cols if col != 'seed_issuer_id'])
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
    .with_columns([
        pl.col('seed_issuer_id').cast(pl.Float64).cast(pl.Int64),
        pl.col('issue_id').cast(pl.Int64, strict=False),
        pl.col('state').cast(pl.Utf8).str.to_uppercase(),
        pl.col('amount').cast(pl.Float64),
        pl.col('rating_issue_max').cast(pl.Float64),
        pl.col('offering_yield_spread').cast(pl.Float64),
        pl.col('go_unlim').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('go_lim').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('rev').cast(pl.Int8, strict=False),
        pl.col('offering_date').cast(pl.Date),
        pl.col('maturity_date').cast(pl.Date),
    ])
    .filter(
        pl.col('seed_issuer_id').is_not_null()
        & pl.col('rev').is_not_null()
        & pl.col('amount').is_not_null()
        & (pl.col('amount') > 0)
        & pl.col('offering_date').is_not_null()
        & pl.col('maturity_date').is_not_null()
    )
    .with_columns([
        (pl.col('go_unlim').eq(1) | pl.col('go_lim').eq(1)).alias('all_go'),
        pl.col('go_unlim').eq(1).alias('utgo'),
        pl.col('go_lim').eq(1).alias('ltgo'),
        pl.col('rev').eq(1).alias('revenue'),
    ])
)

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

    agg = (
        outstanding
        .group_by('seed_issuer_id')
        .agg([
            amount_expr(any_go_or_revenue, 'mergent_go_revenue_outstanding_debt'),
            amount_expr(all_go, 'mergent_all_go_outstanding_debt'),
            amount_expr(revenue, 'mergent_revenue_outstanding_debt'),
            amount_expr(utgo, 'mergent_utgo_outstanding_debt'),
            amount_expr(ltgo, 'mergent_ltgo_outstanding_debt'),
            count_expr(any_go_or_revenue, 'mergent_go_revenue_bonds_outstanding'),
            count_expr(all_go, 'mergent_all_go_bonds_outstanding'),
            count_expr(revenue, 'mergent_revenue_bonds_outstanding'),
            count_expr(utgo, 'mergent_utgo_bonds_outstanding'),
            count_expr(ltgo, 'mergent_ltgo_bonds_outstanding'),
            weighted_spread_expr(any_go_or_revenue, 'mergent_wavg_yield_spread_go_revenue'),
            weighted_spread_expr(revenue, 'mergent_wavg_yield_spread_revenue'),
            weighted_spread_expr(all_go, 'mergent_wavg_yield_spread_all_go'),
            weighted_spread_expr(utgo, 'mergent_wavg_yield_spread_utgo'),
            weighted_spread_expr(ltgo, 'mergent_wavg_yield_spread_ltgo'),
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
            weighted_average_expr(
                any_go_or_revenue,
                'rating_issue_max',
                'mergent_wavg_rating_go_revenue_rated',
            ),
            weighted_average_expr(
                all_go,
                'rating_issue_max',
                'mergent_wavg_rating_all_go_rated',
            ),
            weighted_average_expr(
                utgo,
                'rating_issue_max',
                'mergent_wavg_rating_utgo_rated',
            ),
            weighted_average_expr(
                ltgo,
                'rating_issue_max',
                'mergent_wavg_rating_ltgo_rated',
            ),
            weighted_average_expr(
                revenue,
                'rating_issue_max',
                'mergent_wavg_rating_revenue_rated',
            ),
        ])
        .with_columns(pl.lit(year).alias('year'))
    )

    mergent_years.append(agg)

mergent_outstanding = pl.concat(mergent_years, how='diagonal')

mergent_amount_cols = [
    'mergent_go_revenue_outstanding_debt',
    'mergent_all_go_outstanding_debt',
    'mergent_revenue_outstanding_debt',
    'mergent_utgo_outstanding_debt',
    'mergent_ltgo_outstanding_debt',
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
    .join(issuers, on='seed_issuer_id', how='left', suffix='_issuer')
    .join(mergent_outstanding, on=['seed_issuer_id', 'year'], how='left')
)

for col in mergent_amount_cols:
    full_panel = full_panel.with_columns(pl.col(col).fill_null(0))
    full_panel = full_panel.with_columns(pl.col(col.replace('_debt', '_debt_mil')).fill_null(0))

border_memberships = (
    pl.read_csv(border_file, infer_schema_length=10000)
    .with_columns(pl.col('seed_issuer_id').cast(pl.Float64).cast(pl.Int64))
    .select([
        'seed_issuer_id',
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
    .group_by('seed_issuer_id')
    .agg([
        pl.lit(1).alias('border_sample'),
        pl.col('border_group').n_unique().alias('border_group_count'),
    ])
)

full_panel = (
    full_panel
    .join(border_flags, on='seed_issuer_id', how='left')
    .with_columns([
        pl.col('border_sample').fill_null(0),
        pl.col('border_group_count').fill_null(0),
    ])
)

border_panel = (
    full_panel
    .filter(pl.col('border_sample').eq(1))
    .drop('border_sample')
    .join(border_memberships, on='seed_issuer_id', how='inner')
)

ordered_cols_base = [
    'year',
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
    'mergent_wavg_original_maturity_years_go_revenue',
    'mergent_wavg_original_maturity_years_all_go',
    'mergent_wavg_original_maturity_years_utgo',
    'mergent_wavg_original_maturity_years_ltgo',
    'mergent_wavg_original_maturity_years_revenue',
    'mergent_wavg_rating_go_revenue_rated',
    'mergent_wavg_rating_all_go_rated',
    'mergent_wavg_rating_utgo_rated',
    'mergent_wavg_rating_ltgo_rated',
    'mergent_wavg_rating_revenue_rated',
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
        pl.col('mergent_wavg_yield_spread_go_revenue').is_not_null().sum().alias('issuers_with_mergent_yield_spread'),
    ])
    .sort('year')
)

diagnostics.write_csv(diag_dir / 'census_mergent_debt_cross_section_diagnostics.csv')
print(diagnostics)
