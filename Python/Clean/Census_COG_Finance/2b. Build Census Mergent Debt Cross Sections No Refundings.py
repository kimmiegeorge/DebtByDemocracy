"""Build Census--Mergent debt cross sections from the paper's July city data.

Use the preserved submission's 260716 city CUSIP dataset, existing issuance
ratings and voting-law controls, and original NC yield-spread input. Bonds
remain at original par from offering through contractual maturity; no
redemption or BONDINFO balance adjustments enter this construction.

Keep two extensions to the submitted construction: county demographics are
matched to the year before each cross section, and additional other-debt,
lease/rent/loan, and tax-backed/non-tax revenue categories are reported.
The July file's blank bond-type rows are retained as other debt; they do not
enter the paper's GO/revenue totals or weighted averages.

Outputs go to processed/no_refundings and diagnostics/no_refundings. Script
2a separately constructs the refunding-inclusive, redemption-adjusted stock.
"""

#%% -----------------------------------------------------------------------
# set up
# -----------------------------------------------------------------------
import os
from datetime import date
from pathlib import Path
import pandas as pd
import polars as pl


root = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
data_dir = root / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
census_dir = data_dir / 'Census COG Finance'
mergent_dir = data_dir / 'Mergent' / 'Clean'
clean_census_dir = clean_data_dir / 'Census COG Finance'
border_dir = clean_data_dir / 'Border States'
out_dir = clean_census_dir / 'processed'
diag_dir = clean_census_dir / 'diagnostics'
other_table_dir = Path(os.path.expanduser(
    '~/Dropbox/Apps/Overleaf/Voting on Bonds/tables/clean/raw'
))

out_dir.mkdir(parents=True, exist_ok=True)
diag_dir.mkdir(parents=True, exist_ok=True)

# Save the July-sample construction in its own output directories.
build_out_dir = out_dir / 'no_refundings'
build_diag_dir = diag_dir / 'no_refundings'
build_out_dir.mkdir(parents=True, exist_ok=True)
build_diag_dir.mkdir(parents=True, exist_ok=True)

target_years = [2012, 2017]

census_panel_file = out_dir / 'census_cog_city_debt_panel.csv'
county_nonmunicipal_file = out_dir / 'census_cog_county_nonmunicipal_debt_summary.csv'
census_mergent_match_file = diag_dir / 'census_cog_2022_mergent_exact_matches.csv'
border_file = border_dir / 'Border Matches All Mergent Data Expanded Set Buffer 100000.csv'

# Use the exact city-bond source and NC spread input from the submitted script.
# The July dataset already contains its sample screens and issuance ratings.
bond_file = mergent_dir / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
county_demographics_file = data_dir / 'BEA' / 'countydemos_1999_2026.dta'
yield_spread_file = clean_data_dir / 'Mergent' / 'Clean' / 'bond_level_off_yield_spread.csv'

high_state_tax_privilege_states = {
    'CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN', 'NC', 'ID', 'NY',
    'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE',
}

#%% -----------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------
def read_stata_columns(path, columns):
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

# join by state-county-name match
census_county = (
    county_matches
    .join(
        census_panel,
        on=['state', 'county_fips', 'census_city_clean'],
        how='inner',
    )
)

matched_census_keys = census_county.select(['year', 'gov_id']).unique()

# for remaining, join by state-name match
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
# attach county demographics for the year before each Census cross section
# -----------------------------------------------------------------------
# Read BEA levels directly instead of taking demographics from an arbitrary
# legacy bond row. The 2012 cross section uses 2011; 2017 uses 2016.
county_demographics = (
    read_stata_columns(county_demographics_file, ['fips', 'year', 'gdp', 'pop', 'pers_inc'])
    .with_columns([
        pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5).alias('county_fips'),
        pl.col('year').cast(pl.Int64).alias('demographic_year'),
        (pl.col('year').cast(pl.Int64) + 1).alias('year'),
    ])
    .filter(pl.col('year').is_in(target_years))
    .with_columns([
        pl.when(pl.col(col) > 0)
        .then(pl.col(col).log())
        .otherwise(None)
        .alias(f'ln_{col}')
        for col in ['gdp', 'pop', 'pers_inc']
    ])
    .select(['county_fips', 'year', 'demographic_year', 'ln_gdp', 'ln_pop', 'ln_pers_inc'])
)

# Match on the Census cross section's county and year. Unmatched or nonpositive
# BEA values stay missing; do not substitute another year or a legacy value.
# Census municipal population remains the separate, contemporaneous measure.
census_cross_section = (
    census_cross_section
    .join(county_demographics, on=['county_fips', 'year'], how='left', validate='m:1')
)


#%% -----------------------------------------------------------------------
# load Mergent bond-level data, controls, and outstanding debt measures
# -----------------------------------------------------------------------
print('Loading July city Mergent bond-level file...')
bond_cols = [
    'cusip',
    'issue_id',
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'fips',
    'state_name',
    'offering_date',
    'maturity_date',
    'amount',
    'bond_type',
    'security_code',
    'source_of_repayment',
    'temp_salestax',
    'temp_excisetax',
    'go_unlim',
    'go_lim',
    'rev',
    'insured',
    'callable',
    'sinkable',
    'rating_issue_max',
    'city_go_vote',
    'city_rev_vote',
    'nh_city',
    'state_go_vote',
    'state_utgo_allowed',
    'state_ltgo_allowed',
    'glm_proactive',
]

# Sample restrictions, GO/revenue classifications, ratings, and issuer controls
# are already in this source. Do not reapply the expanded-file screens or
# reconstruct ratings from raw agency fields.
raw_bonds = read_stata_columns(bond_file, bond_cols)

# Match the submitted script's NC spread series using issue ID and CUSIP.
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

# Preserve the submitted GO/revenue universe and keep otherwise unclassified
# July-file bonds for the additional debt categories. In this source, those
# rows have a blank bond_type and no GO/revenue flag; classify them as other.
bonds = (
    raw_bonds
    .pipe(normalize_id_columns)
    .with_columns([
        pl.col('issue_id').cast(pl.Int64, strict=False),
        pl.col('amount').cast(pl.Float64),
        pl.col('rating_issue_max').cast(pl.Float64).fill_null(0),
        pl.col('offering_yield_spread').cast(pl.Float64),
        pl.col('offering_yield_spread_nc').cast(pl.Float64),
        pl.col('security_code').cast(pl.Utf8),
        pl.col('bond_type').cast(pl.Utf8).fill_null('').str.strip_chars()
        .replace('', 'other').alias('bond_type'),
        pl.col('go_unlim').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('go_lim').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('rev').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('insured').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('callable').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('sinkable').fill_null(0).cast(pl.Int8, strict=False),
        pl.col('offering_date').cast(pl.Date),
        pl.col('maturity_date').cast(pl.Date),
    ])
    .filter(
        pl.col('seed_issuer_id').is_not_null()
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
        (
            pl.col('security_code').is_in(['C', 'N'])
            & ~(pl.col('go_unlim').eq(1) | pl.col('go_lim').eq(1))
        ).alias('lease_rent_loan_agreement'),
    ])
)

# Separate debt-composition partition: retain existing GO classifications,
# split revenue into tax/non-tax backing, and exclude ambiguous double-barreled
# bonds. Null categories contribute to none of the taxsplit amounts or shares.
bonds = bonds.with_columns(
    pl.when(
        pl.col('security_code').eq('A').fill_null(False)
        | pl.col('source_of_repayment').eq('A').fill_null(False)
    )
    .then(pl.lit(None).cast(pl.Utf8))
    .when(pl.col('utgo'))
    .then(pl.lit('utgo'))
    .when(pl.col('ltgo'))
    .then(pl.lit('ltgo'))
    .when(
        ~pl.col('all_go')
        & (
            (
                pl.col('bond_type').eq('other')
                & pl.col('security_code').is_in(['B', 'H', 'I', 'J', 'Q'])
            )
            | (
                pl.col('security_code').eq('G')
                & (
                    pl.col('temp_salestax').eq(1).fill_null(False)
                    | pl.col('temp_excisetax').eq(1).fill_null(False)
                )
            )
        )
    )
    .then(pl.lit('revenue_tax'))
    .when(
        ~pl.col('all_go')
        & (
            pl.col('revenue')
            | (
                pl.col('bond_type').eq('other')
                & pl.col('security_code').is_in(['C', 'M', 'N', 'P', 'R'])
            )
        )
    )
    .then(pl.lit('revenue_nontax'))
    .otherwise(pl.lit(None).cast(pl.Utf8))
    .alias('bond_type_taxsplit')
)


#%% -----------------------------------------------------------------------
# summarize other bonds before restricting to a year-end outstanding portfolio
# -----------------------------------------------------------------------
security_code_labels = {
    'A': 'Double-barreled', 'B': 'Fuel/vehicle tax', 'C': 'Lease/rent',
    'D': 'Limited GO', 'E': 'Other', 'F': 'Public improvement',
    'G': 'Revenue', 'H': 'Sales/excise tax', 'I': 'Special assessment',
    'J': 'Tax allocation', 'K': 'Unlimited GO', 'L': 'U.S. government',
    'M': 'Sales agreement', 'N': 'Loan agreement', 'P': 'Tuition agreement',
    'Q': 'Special tax', 'R': 'Mortgage loan',
}

# Labels describe the security codes retained in the July city dataset.
# temp_salestax is the existing description flag (contains SALE and TAX).
other_bonds = (
    bonds
    .filter(pl.col('bond_type').eq('other'))
    .with_columns([
        pl.col('security_code').fill_null('').str.strip_chars()
        .replace('', 'Missing').alias('security_code'),
        pl.col('temp_salestax').eq(1).fill_null(False).alias('sales_tax_flag'),
    ])
)
other_summary = (
    other_bonds
    .group_by('security_code')
    .agg([
        pl.len().alias('bond_count'),
        pl.col('amount').sum().alias('amount'),
        pl.col('sales_tax_flag').sum().alias('sales_tax_bond_count'),
    ])
    .with_columns([
        (100 * pl.col('bond_count') / pl.col('bond_count').sum()).alias('bond_pct'),
        (pl.col('amount') / 1_000_000).alias('amount_mil'),
        (100 * pl.col('amount') / pl.col('amount').sum()).alias('amount_pct'),
    ])
    .sort('security_code')
)

other_table_lines = [
    r'\begingroup',
    r'\centering',
    r'\small',
    r'\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}llrrrrr}',
    r'\toprule',
    r'Code & Security & Bonds & Bond \% & Amount (\$m) & Amount \% & Sales tax \\',
    r'\midrule',
]
for row in other_summary.iter_rows(named=True):
    code = row['security_code']
    label = security_code_labels.get(code, 'Unmapped' if code != 'Missing' else 'Missing')
    other_table_lines.append(
        f"{code} & {label} & {row['bond_count']:,} & {row['bond_pct']:.1f} & "
        f"{row['amount_mil']:,.1f} & {row['amount_pct']:.1f} & "
        f"{row['sales_tax_bond_count']:,}" + r' \\'
    )
other_table_lines.extend([
    r'\midrule',
    f" & Total & {other_bonds.height:,} & "
    + ('100.0' if other_bonds.height else '--')
    + f" & {other_bonds['amount'].sum() / 1_000_000:,.1f} & "
    + ('100.0' if other_bonds.height else '--')
    + f" & {other_bonds['sales_tax_flag'].sum():,}" + r' \\',
    r'\bottomrule',
    r'\end{tabular*}',
    r'\endgroup',
])
other_table_dir.mkdir(parents=True, exist_ok=True)
other_table_path = other_table_dir / 'mergent_newmoney_other_bonds_security_summary.tex'
try:
    other_table_path.write_text('\n'.join(other_table_lines) + '\n')
    print(f'Wrote other-bond composition table to {other_table_path}')
except PermissionError:
    # The linked Overleaf directory is outside the project workspace in some
    # environments.  It is an auxiliary table only, so do not prevent the
    # reproducible cross-section data build from completing when unavailable.
    print(f'Skipped auxiliary other-bond table (no permission): {other_table_path}')


mergent_years = []

for year in target_years:
    as_of = date(year, 12, 31)
    print(f'Computing July-sample original-par debt as of 12/31/{year}...')

    eligible_bonds = bonds.filter(
        (pl.col('offering_date') <= as_of)
        & (pl.col('maturity_date') > as_of)
    )

    # Use the submitted offering/maturity screen with original par amounts.
    # The July source already supplies the paper sample; no new-money screen
    # is added here, and no redemption or reported-balance reductions apply.
    outstanding = (
        eligible_bonds
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
    other = pl.col('bond_type').eq('other')
    utgo = pl.col('utgo')
    ltgo = pl.col('ltgo')
    lease_rent_loan_agreement = pl.col('lease_rent_loan_agreement')
    all_bonds = pl.lit(True)

    agg = (
        outstanding
        .group_by('issuer_key')
        .agg([
            amount_expr(all_bonds, 'mergent_total_outstanding_debt'),
            # Only classified bonds enter this partition's denominator.
            amount_expr(
                pl.col('bond_type_taxsplit').is_not_null(),
                'mergent_taxsplit_outstanding_debt',
            ),
            amount_expr(
                pl.col('bond_type_taxsplit').eq('utgo'),
                'mergent_utgo_taxsplit_outstanding_debt',
            ),
            amount_expr(
                pl.col('bond_type_taxsplit').eq('ltgo'),
                'mergent_ltgo_taxsplit_outstanding_debt',
            ),
            amount_expr(
                pl.col('bond_type_taxsplit').eq('revenue_tax'),
                'mergent_revenue_tax_taxsplit_outstanding_debt',
            ),
            amount_expr(
                pl.col('bond_type_taxsplit').eq('revenue_nontax'),
                'mergent_revenue_nontax_taxsplit_outstanding_debt',
            ),
            amount_expr(any_go_or_revenue, 'mergent_go_revenue_outstanding_debt'),
            amount_expr(all_go, 'mergent_all_go_outstanding_debt'),
            amount_expr(revenue, 'mergent_revenue_outstanding_debt'),
            amount_expr(other, 'mergent_other_outstanding_debt'),
            amount_expr(utgo, 'mergent_utgo_outstanding_debt'),
            amount_expr(ltgo, 'mergent_ltgo_outstanding_debt'),
            amount_expr(
                lease_rent_loan_agreement,
                'mergent_lease_rent_loan_agreement_outstanding_debt',
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
            # Include other bonds in the original-par-weighted all-bond spread.
            weighted_spread_expr(all_bonds, 'mergent_wavg_yield_spread_all'),
            weighted_spread_expr(any_go_or_revenue, 'mergent_wavg_yield_spread_go_revenue'),
            weighted_spread_expr(revenue, 'mergent_wavg_yield_spread_revenue'),
            weighted_spread_expr(all_go, 'mergent_wavg_yield_spread_all_go'),
            weighted_spread_expr(utgo, 'mergent_wavg_yield_spread_utgo'),
            weighted_spread_expr(ltgo, 'mergent_wavg_yield_spread_ltgo'),
            weighted_spread_expr(other, 'mergent_wavg_yield_spread_other'),
            weighted_spread_expr(lease_rent_loan_agreement, 'mergent_wavg_yield_spread_lease_rent_loan_agreement'),
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
                other,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_other',
            ),
            weighted_average_expr(
                lease_rent_loan_agreement,
                'original_maturity_years',
                'mergent_wavg_original_maturity_years_lease_rent_loan_agreement',
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
            weighted_average_zero_missing_expr(
                other,
                'rating_issue_max',
                'mergent_wavg_rating_other_zero_unrated',
            ),
            weighted_average_zero_missing_expr(
                lease_rent_loan_agreement,
                'rating_issue_max',
                'mergent_wavg_rating_lease_rent_loan_agreement_zero_unrated',
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
                    (other, 'other'),
                    (lease_rent_loan_agreement, 'lease_rent_loan_agreement'),
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
            for suffix in [
                'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
                'other', 'lease_rent_loan_agreement',
            ]
        ])
        .with_columns([
            pl.col(f'mergent_wavg_{feature}_{suffix}')
            .gt(0)
            .cast(pl.Int8)
            .alias(f'mergent_any_{feature}_{suffix}')
            for feature in ['insured', 'callable', 'sinkable']
            for suffix in [
                'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
                'other', 'lease_rent_loan_agreement',
            ]
        ])
        .with_columns(pl.lit(year).alias('year'))
    )

    mergent_years.append(agg)

mergent_outstanding = pl.concat(mergent_years, how='diagonal')

mergent_amount_cols = [
    'mergent_taxsplit_outstanding_debt',
    'mergent_utgo_taxsplit_outstanding_debt',
    'mergent_ltgo_taxsplit_outstanding_debt',
    'mergent_revenue_tax_taxsplit_outstanding_debt',
    'mergent_revenue_nontax_taxsplit_outstanding_debt',
    'mergent_total_outstanding_debt',
    'mergent_go_revenue_outstanding_debt',
    'mergent_all_go_outstanding_debt',
    'mergent_revenue_outstanding_debt',
    'mergent_other_outstanding_debt',
    'mergent_utgo_outstanding_debt',
    'mergent_ltgo_outstanding_debt',
    'mergent_lease_rent_loan_agreement_outstanding_debt',
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


# Census total debt not represented by the issuer's outstanding Mergent bonds.
# Both input measures are in millions of dollars.
full_panel = full_panel.with_columns(
    (
        pl.col('census_total_debt_mil')
        - pl.col('mergent_total_outstanding_debt_mil')
    ).alias('total_nonmergent_census_debt_mil')
)

# Debt-composition shares for the July-sample original-par construction. The
# original shares partition the paper's GO + strict-revenue measure. The `_wrl`
# versions add lease/rent and loan-agreement debt to the denominator and include
# its corresponding share. The `_all` versions use total Mergent debt,
# including other bonds. GO includes UTGO and LTGO, so its share overlaps theirs.
# A zero denominator is recorded as missing.
go_revenue_plus_lease_rent_loan_agreement = (
    pl.col('mergent_go_revenue_outstanding_debt')
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
        pl.col('mergent_revenue_outstanding_debt')
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
    pl.when(pl.col('mergent_total_outstanding_debt') > 0)
    .then(
        pl.col('mergent_all_go_outstanding_debt')
        / pl.col('mergent_total_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_go_outstanding_all'),
    pl.when(pl.col('mergent_total_outstanding_debt') > 0)
    .then(
        pl.col('mergent_utgo_outstanding_debt')
        / pl.col('mergent_total_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_utgo_outstanding_all'),
    pl.when(pl.col('mergent_total_outstanding_debt') > 0)
    .then(
        pl.col('mergent_ltgo_outstanding_debt')
        / pl.col('mergent_total_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_ltgo_outstanding_all'),
    pl.when(pl.col('mergent_total_outstanding_debt') > 0)
    .then(
        pl.col('mergent_revenue_outstanding_debt')
        / pl.col('mergent_total_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_rev_outstanding_all'),
    pl.when(pl.col('mergent_total_outstanding_debt') > 0)
    .then(
        pl.col('mergent_other_outstanding_debt')
        / pl.col('mergent_total_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_other_outstanding_all'),
    # Taxsplit shares use the same four-category denominator.
    pl.when(pl.col('mergent_taxsplit_outstanding_debt') > 0)
    .then(
        pl.col('mergent_utgo_taxsplit_outstanding_debt')
        / pl.col('mergent_taxsplit_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_utgo_outstanding_taxsplit'),
    pl.when(pl.col('mergent_taxsplit_outstanding_debt') > 0)
    .then(
        pl.col('mergent_ltgo_taxsplit_outstanding_debt')
        / pl.col('mergent_taxsplit_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_ltgo_outstanding_taxsplit'),
    pl.when(pl.col('mergent_taxsplit_outstanding_debt') > 0)
    .then(
        pl.col('mergent_revenue_tax_taxsplit_outstanding_debt')
        / pl.col('mergent_taxsplit_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_revenue_tax_outstanding_taxsplit'),
    pl.when(pl.col('mergent_taxsplit_outstanding_debt') > 0)
    .then(
        pl.col('mergent_revenue_nontax_taxsplit_outstanding_debt')
        / pl.col('mergent_taxsplit_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_revenue_nontax_outstanding_taxsplit'),
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
    'demographic_year',
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
    'total_nonmergent_census_debt_mil',
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
    'mergent_wavg_yield_spread_all',
    'mergent_lease_rent_loan_agreement_outstanding_debt',
    'mergent_lease_rent_loan_agreement_outstanding_debt_mil',
    'frac_utgo_outstanding',
    'frac_ltgo_outstanding',
    'frac_rev_outstanding',
    'frac_utgo_outstanding_wrl',
    'frac_ltgo_outstanding_wrl',
    'frac_rev_outstanding_wrl',
    'frac_lease_rent_loan_agreement_outstanding_wrl',
    'frac_go_outstanding_all',
    'frac_utgo_outstanding_all',
    'frac_ltgo_outstanding_all',
    'frac_rev_outstanding_all',
    'frac_other_outstanding_all',
    *[
        f'frac_{category}_outstanding_taxsplit'
        for category in ['utgo', 'ltgo', 'revenue_tax', 'revenue_nontax']
    ],
    *[
        f'mergent_{category}_outstanding_debt{unit}'
        for category in [
            'taxsplit', 'utgo_taxsplit', 'ltgo_taxsplit',
            'revenue_tax_taxsplit', 'revenue_nontax_taxsplit',
        ]
        for unit in ['', '_mil']
    ],
    *[
        f'mergent_{suffix}_outstanding_debt{unit}'
        for suffix in ['go_revenue', 'all_go', 'revenue', 'other', 'utgo', 'ltgo']
        for unit in ['', '_mil']
    ],
    *[
        f'mergent_{suffix}_bonds_outstanding'
        for suffix in [
            'total', 'lease_rent_loan_agreement', 'go_revenue',
            'all_go', 'revenue', 'utgo', 'ltgo',
        ]
    ],
    *[
        f'mergent_wavg_{feature}_{suffix}'
        for feature in ['yield_spread', 'original_maturity_years']
        for suffix in [
            'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
            'other', 'lease_rent_loan_agreement',
        ]
    ],
    *[
        f'mergent_wavg_rating_{suffix}_zero_unrated'
        for suffix in [
            'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
            'other', 'lease_rent_loan_agreement',
        ]
    ],
    *[
        f'mergent_wavg_{feature}_{suffix}'
        for feature in ['insured', 'callable', 'sinkable']
        for suffix in [
            'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
            'other', 'lease_rent_loan_agreement',
        ]
    ],
    *[
        f'mergent_none_{feature}_{suffix}'
        for feature in ['insured', 'callable', 'sinkable']
        for suffix in [
            'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
            'other', 'lease_rent_loan_agreement',
        ]
    ],
    *[
        f'mergent_any_{feature}_{suffix}'
        for feature in ['insured', 'callable', 'sinkable']
        for suffix in [
            'go_revenue', 'all_go', 'utgo', 'ltgo', 'revenue',
            'other', 'lease_rent_loan_agreement',
        ]
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

    full_path = build_out_dir / f'census_mergent_debt_cross_section_{year}.csv'
    border_path = build_out_dir / f'census_mergent_debt_cross_section_{year}_border_sample.csv'

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

diagnostics.write_csv(build_diag_dir / 'census_mergent_debt_cross_section_diagnostics.csv')
print(diagnostics)

# %%
