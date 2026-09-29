'''
Build Census-Mergent municipal debt cross sections for COG years.

For each target year, this script creates one row per matched Mergent issuer.
It keeps Census of Governments debt and population measures for that year and
adds Mergent bond-level debt outstanding as of December 31 of the same year.

Before matching and aggregation, bonds are restricted using the issuer and
instrument screen from the legacy city-sample Stata construction
(`260918_mergent_getotherdebt.do`).  This keeps the updated series comparable
to the paper's city issuer universe while still retaining refunding bonds for
the stock calculation below.  In particular, it excludes authorities,
agencies, most corporations, non-school districts, state issuers, and the
legacy non-tax-exempt/nonstandard-coupon bonds.

Mergent debt outstanding starts with bonds for which:
    offering_date <= December 31 of target year
    maturity_date > December 31 of target year

It then subtracts dated full-redemption and partial-call principal from the
raw Mergent redemption files.  For a refunding event, the retirement date is
the earlier of the refunding bond's settlement date and the recorded
redemption/call date.  This retains active refunding bonds while removing the
predecessor bonds when Mergent records their economic retirement.
Where Mergent supplies a CUSIP-level outstanding balance dated no later than
the measurement date, that reported balance is also used as a conservative
upper bound; this captures retirements with no usable redemption event.

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

target_years = [2012, 2017]

census_panel_file = out_dir / 'census_cog_city_debt_panel.csv'
county_nonmunicipal_file = out_dir / 'census_cog_county_nonmunicipal_debt_summary.csv'
census_mergent_match_file = diag_dir / 'census_cog_2022_mergent_exact_matches.csv'
border_file = border_dir / 'Border Matches All Mergent Data Expanded Set Buffer 100000.csv'

# This is the primary Mergent source for every bond-level construction below.
# Unlike the prior file, it retains refunded issuances.  Redemptions are
# subsequently applied at the CUSIP/maturity level below to produce a
# point-in-time debt stock.
bond_file = mergent_dir / '260923_cusiplevel_allbonds_inclrefund.dta'
bondinfo_file = data_dir / 'Mergent' / 'Raw' / 'BONDINFO.DLM'
redemption_file = data_dir / 'Mergent' / 'Raw' / 'REDEMPTN.DLM'
partial_redemption_file = data_dir / 'Mergent' / 'Raw' / 'PARTREDM.DLM'
# The expanded file does not retain several static issuer controls. These
# are read from the prior file as lookups; all bond classifications and
# aggregations use the expanded file above.
legacy_bond_file = mergent_dir / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
county_demographics_file = data_dir / 'BEA' / 'countydemos_1999_2026.dta'
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


def apply_legacy_city_scope(df):
    """Apply the pre-match city-universe screen in 260918 Stata code.

    These exclusions were applied to *all* Mergent bonds before issuer
    matching in the paper's construction.  We reproduce them here before
    mapping the expanded refund-inclusive file to Census cities.  The legacy
    `drop if new_money == 0` is deliberately excluded: refunding bonds are
    necessary for a year-end debt stock, and their predecessor principal is
    handled by the redemption ledger instead.
    """
    issuer_name = pl.col('issuer_long_name').cast(pl.Utf8).fill_null('').str.to_uppercase()
    use_proceeds = pl.col('use_proceeds').cast(pl.Utf8).fill_null('').str.to_uppercase()
    coupon_code = pl.col('coupon_code').cast(pl.Utf8).fill_null('').str.to_uppercase()

    school_district = (
        issuer_name.str.contains('SCH DI', literal=True)
        | (issuer_name.str.contains('PUB', literal=True) & issuer_name.str.contains('SCH', literal=True))
        | (issuer_name.str.contains('SCH', literal=True) & issuer_name.str.contains('IND', literal=True))
        | (issuer_name.str.contains('REG', literal=True) & issuer_name.str.contains('SCH', literal=True))
        | (issuer_name.str.contains('SCHOOL', literal=True) & issuer_name.str.contains('DIST', literal=True))
        | issuer_name.str.contains('SCHS', literal=True)
        | issuer_name.str.contains('SCH SYS', literal=True)
        | issuer_name.str.contains('AREA SCH', literal=True)
    )
    state_issuer = issuer_name.str.ends_with(' ST') | issuer_name.str.contains(' ST ', literal=True)
    excluded_corporation = (
        issuer_name.str.contains('CORP', literal=True)
        & ~issuer_name.str.contains('CORPUS CHRISTI TEX', literal=True)
    ) | issuer_name.eq('CORPUS CHRISTI TEX BUSINESS & JOB DEV CORP SALES TAX RE')
    higher_ed = (
        (issuer_name.str.contains('UNIV', literal=True) | issuer_name.str.contains('COLLEGE', literal=True))
        & use_proceeds.eq('HIED')
    )

    keep = (
        ~state_issuer
        & ~issuer_name.str.contains('AUTH', literal=True)
        & ~excluded_corporation
        & ~issuer_name.str.contains('AGY', literal=True)
        & ~issuer_name.str.contains('AGENCY', literal=True)
        & ~(issuer_name.str.contains('DIST', literal=True) & ~school_district)
        & ~higher_ed
        & pl.col('taxexempt_federal').cast(pl.Float64, strict=False).eq(1)
        & coupon_code.is_in(['FXD', 'OID', 'OIP'])
    )
    return df.filter(keep)


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


def load_redemption_events():
    """Load dated principal-reduction events at Mergent's maturity level.

    `REDEMPTN.DLM` contains full redemptions, pre-refundings, and related
    events.  `PARTREDM.DLM` contains partial calls.  Both files key to
    BONDINFO through (`issue_id_l`, `maturity_id_l`).  Optional call schedules
    are deliberately not used: an option to call is not an actual redemption.

    Mergent's ``redemption_date_d`` often records the later contractual call
    date for a pre-refunded or escrowed maturity.  When
    ``ref_issue_settlement_date_d`` is available, use the earlier of it and
    the redemption date as the effective retirement date.  Taking the minimum
    preserves the recorded redemption date when settlement is missing or
    implausibly later.

    Mergent occasionally supplies a full-redemption event without a principal
    amount.  For unambiguously principal-retiring event types, retain a flag
    that removes the remaining CUSIP balance at the effective retirement date
    rather than silently treating it as still outstanding.  Types G
    (interest-only ETM), J (no redemption), and N (remarketing) do not reduce
    principal.
    """
    full_principal_types = ['A', 'B', 'C', 'D', 'E', 'F', 'H', 'L', 'O', 'P', 'Q']
    non_principal_types = ['G', 'J', 'N']

    full_events = (
        pl.scan_csv(
            redemption_file,
            separator='|',
            null_values=[''],
            infer_schema_length=10_000,
        )
        .select([
            pl.col('issue_id_l').cast(pl.Int64, strict=False).alias('issue_id'),
            pl.col('maturity_id_l').cast(pl.Int64, strict=False).alias('maturity_id'),
            pl.col('redemption_date_d')
            .cast(pl.Utf8)
            .str.strptime(pl.Date, '%Y%m%d', strict=False)
            .alias('redemption_date'),
            pl.col('ref_issue_settlement_date_d')
            .cast(pl.Utf8)
            .str.strptime(pl.Date, '%Y%m%d', strict=False)
            .alias('refunding_settlement_date'),
            pl.col('redemption_amt_f').cast(pl.Float64, strict=False).alias('redemption_amount'),
            pl.col('redemption_type_i').cast(pl.Utf8).alias('redemption_type'),
        ])
        .filter(
            pl.col('issue_id').is_not_null()
            & pl.col('maturity_id').is_not_null()
            & ~pl.col('redemption_type').is_in(non_principal_types)
        )
        .with_columns([
            pl.when(pl.col('redemption_date').is_null())
            .then(pl.col('refunding_settlement_date'))
            .when(pl.col('refunding_settlement_date').is_null())
            .then(pl.col('redemption_date'))
            .when(pl.col('refunding_settlement_date') < pl.col('redemption_date'))
            .then(pl.col('refunding_settlement_date'))
            .otherwise(pl.col('redemption_date'))
            .alias('event_date'),
            pl.col('redemption_amount').fill_null(0.0),
            (
                pl.col('redemption_amount').is_null()
                & pl.col('redemption_type').is_in(full_principal_types)
            )
            .cast(pl.Int8)
            .alias('unknown_full_redemption'),
        ])
        .filter(pl.col('event_date').is_not_null())
        .select([
            'issue_id', 'maturity_id', 'event_date', 'redemption_amount',
            'unknown_full_redemption',
        ])
    )

    partial_events = (
        pl.scan_csv(
            partial_redemption_file,
            separator='|',
            null_values=[''],
            infer_schema_length=10_000,
        )
        .select([
            pl.col('issue_id_l').cast(pl.Int64, strict=False).alias('issue_id'),
            pl.col('maturity_id_l').cast(pl.Int64, strict=False).alias('maturity_id'),
            pl.col('partial_call_date_d')
            .cast(pl.Utf8)
            .str.strptime(pl.Date, '%Y%m%d', strict=False)
            .alias('event_date'),
            pl.col('prtl_call_amt_f').cast(pl.Float64, strict=False).alias('redemption_amount'),
        ])
        .filter(
            pl.col('issue_id').is_not_null()
            & pl.col('maturity_id').is_not_null()
            & pl.col('event_date').is_not_null()
            & pl.col('redemption_amount').is_not_null()
            & (pl.col('redemption_amount') > 0)
        )
        .with_columns(pl.lit(0).cast(pl.Int8).alias('unknown_full_redemption'))
        .select([
            'issue_id', 'maturity_id', 'event_date', 'redemption_amount',
            'unknown_full_redemption',
        ])
    )

    events = pl.concat([full_events, partial_events], how='vertical').collect()
    print(f'Loaded {events.height:,} dated Mergent principal-redemption events.')
    return events


def load_raw_capital_purpose():
    """Load Mergent's maturity-level new-money/refunding classification.

    ``capital_purpose_c`` is the raw Mergent field, unlike the inherited
    binary ``new_money`` field in the cleaned Stata input.  It is keyed by
    issue and maturity, allowing a legacy-style construction to remove only
    CUSIPs marked ``REF`` while retaining ``NEW`` maturities in a mixed issue.
    """
    capital_purpose = (
        pl.scan_csv(
            bondinfo_file,
            separator='|',
            null_values=[''],
            infer_schema_length=10_000,
        )
        .select([
            pl.col('issue_id_l').cast(pl.Int64, strict=False).alias('issue_id'),
            pl.col('maturity_id_l').cast(pl.Int64, strict=False).alias('maturity_id'),
            pl.col('capital_purpose_c')
            .cast(pl.Utf8)
            .str.strip_chars()
            .str.to_uppercase()
            .alias('capital_purpose'),
        ])
        .filter(
            pl.col('issue_id').is_not_null()
            & pl.col('maturity_id').is_not_null()
        )
        .unique(subset=['issue_id', 'maturity_id'], keep='first')
        .collect()
    )
    print(
        'Loaded raw Mergent capital-purpose codes for '
        f'{capital_purpose.height:,} issue-maturity pairs.'
    )
    return capital_purpose


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
print('Loading expanded Mergent bond-level file...')
bond_cols = [
    'cusip',
    'issue_id',
    'maturity_id',
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'fips',
    'issuer_long_name',
    'offering_date',
    'maturity_date',
    'amount',
    'total_mat_amt_outstanding',
    'total_mat_amt_outstanding_date',
    'bond_type',
    'security_code',
    'temp_salestax',
    'temp_excisetax',
    'use_proceeds',
    'taxexempt_federal',
    'coupon_code',
    'new_money',
    'source_of_repayment',
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
]

raw_bonds = read_stata_columns(bond_file, bond_cols)
raw_bonds_before_scope = raw_bonds.height

raw_bonds = apply_legacy_city_scope(raw_bonds)
print(
    'Applied legacy city-scope screen: '
    f'{raw_bonds_before_scope:,} to {raw_bonds.height:,} CUSIP rows. '
    'Refunding bonds remain eligible for the debt-stock ledger.'
)
redemption_events = load_redemption_events()
raw_capital_purpose = load_raw_capital_purpose()

# Preserve the six issuance-level classification corrections applied in the
# legacy Stata build (260716_mergent_updatestatelaw_strictrevbond.do). Mergent
# reports varying security codes within these issuances, so the corrections
# must be made before any GO/revenue or UTGO/LTGO aggregation.
issue_id = pl.col('issue_id').cast(pl.Int64, strict=False)
raw_bonds = raw_bonds.with_columns([
    pl.when(issue_id.is_in([766088, 1223949, 642811, 640435]))
    .then(pl.lit(1))
    .when(issue_id.is_in([34328, 572223]))
    .then(pl.lit(0))
    .otherwise(pl.col('go_unlim'))
    .alias('go_unlim'),
    pl.when(issue_id.is_in([34328, 572223]))
    .then(pl.lit(1))
    .when(issue_id.is_in([766088, 642811, 640435]))
    .then(pl.lit(0))
    .otherwise(pl.col('go_lim'))
    .alias('go_lim'),
    pl.when(issue_id.eq(1223949))
    .then(pl.lit(0))
    .otherwise(pl.col('rev'))
    .alias('rev'),
    pl.when(issue_id.eq(1223949))
    .then(pl.lit('go'))
    .otherwise(pl.col('bond_type'))
    .alias('bond_type'),
])

# Preserve static issuer controls from the legacy file while the expanded
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
    'glm_proactive',
]

print('Loading legacy issuer-control lookup...')
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

# The refund-inclusive bond file does not retain the city referendum-history
# fields.  They are issuer-level attributes, so recover them from the exact
# Census--Mergent match table rather than requiring them on every CUSIP.
issuer_vote_controls = matches.select([
    'issuer_key',
    'city_go_vote',
    'city_rev_vote',
]).unique(subset=['issuer_key'], keep='first')

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
    .join(issuer_vote_controls, on='issuer_key', how='left')
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

bonds = (
    raw_bonds
    .pipe(normalize_id_columns)
    .with_columns([
        pl.col('issue_id').cast(pl.Int64, strict=False),
        pl.col('maturity_id').cast(pl.Int64, strict=False),
        pl.col('new_money').cast(pl.Int8, strict=False),
        pl.col('amount').cast(pl.Float64),
        pl.col('total_mat_amt_outstanding').cast(pl.Float64, strict=False),
        # This field is stored as a YYYYMMDD numeric value rather than a
        # Stata date, so parse it explicitly before comparing to `as_of`.
        pl.col('total_mat_amt_outstanding_date')
        .cast(pl.Int64, strict=False)
        .cast(pl.Utf8)
        .str.strptime(pl.Date, '%Y%m%d', strict=False)
        .alias('total_mat_amt_outstanding_date'),
        pl.col('offering_yield_spread').cast(pl.Float64),
        pl.col('offering_yield_spread_nc').cast(pl.Float64),
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
        # Match the paper's legacy Stata construction: GO type comes from
        # the unlimited/limited-GO flags, and revenue from `rev`, rather
        # than the refreshed file's broad `bond_type` label.  In the new
        # all-bonds source some valid GO CUSIPs have `bond_type != "go"`.
        # Requiring that label would mechanically recode their UTGO/LTGO
        # share to zero and break comparability with the published sample.
        (
            pl.col('go_unlim').eq(1)
            | pl.col('go_lim').eq(1)
        ).alias('all_go'),
        pl.col('go_unlim').eq(1).alias('utgo'),
        pl.col('go_lim').eq(1).alias('ltgo'),
        pl.col('rev').fill_null(0).cast(pl.Int8, strict=False).eq(1).alias('revenue'),
        (
            pl.col('security_code').is_in(['C', 'N'])
            & ~(
                pl.col('go_unlim').eq(1)
                | pl.col('go_lim').eq(1)
            )
        ).alias('lease_rent_loan_agreement'),
    ])
)

# Preserve the raw Mergent maturity-level capital-purpose code separately from
# the inherited binary `new_money` field.  A missing raw match is retained in
# the legacy-style robustness sample; only an explicit `REF` code is excluded.
bonds = bonds.join(
    raw_capital_purpose,
    on=['issue_id', 'maturity_id'],
    how='left',
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

# Labels follow the security-code tabulations in the expanded Stata build.
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
other_table_path = other_table_dir / 'mergent_other_bonds_security_summary.tex'
try:
    other_table_path.write_text('\n'.join(other_table_lines) + '\n')
    print(f'Wrote other-bond composition table to {other_table_path}')
except PermissionError:
    # The linked Overleaf directory is outside the project workspace in some
    # environments.  It is an auxiliary table only, so do not prevent the
    # reproducible cross-section data build from completing when unavailable.
    print(f'Skipped auxiliary other-bond table (no permission): {other_table_path}')


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


def aggregate_debt_composition_stock(stock, year, prefix, debt_suffix):
    """Aggregate a compact GO/revenue composition stock for the 2x2 audit.

    ``stock`` supplies either original CUSIP par (the static legacy-style
    screen) or point-in-time outstanding principal.  The caller controls the
    new-money/all-bonds screen.  Keeping this small aggregation separate from
    the primary series lets the audit change only those two dimensions.
    """
    any_go_or_revenue = pl.col('all_go') | pl.col('revenue')
    all_go = pl.col('all_go')
    revenue = pl.col('revenue')
    utgo = pl.col('utgo')
    ltgo = pl.col('ltgo')
    all_bonds = pl.lit(True)

    return (
        stock
        .group_by('issuer_key')
        .agg([
            amount_expr(all_bonds, f'{prefix}_total_{debt_suffix}'),
            amount_expr(any_go_or_revenue, f'{prefix}_go_revenue_{debt_suffix}'),
            amount_expr(all_go, f'{prefix}_all_go_{debt_suffix}'),
            amount_expr(revenue, f'{prefix}_revenue_{debt_suffix}'),
            amount_expr(utgo, f'{prefix}_utgo_{debt_suffix}'),
            amount_expr(ltgo, f'{prefix}_ltgo_{debt_suffix}'),
            count_expr(all_bonds, f'{prefix}_total_bonds'),
            count_expr(any_go_or_revenue, f'{prefix}_go_revenue_bonds'),
            count_expr(all_go, f'{prefix}_all_go_bonds'),
            count_expr(revenue, f'{prefix}_revenue_bonds'),
            count_expr(utgo, f'{prefix}_utgo_bonds'),
            count_expr(ltgo, f'{prefix}_ltgo_bonds'),
        ])
        .with_columns(pl.lit(year).alias('year'))
    )


def aggregate_bondinfo_balance_only_stock(eligible, year):
    """Aggregate a point-in-time stock using BONDINFO balances only.

    This is a robustness construction, not a replacement for the primary
    redemption-ledger stock.  It retains every eligible CUSIP/maturity at
    original par unless Mergent reports a lower ``total_mat_amt_outstanding``
    balance dated no later than the year-end cutoff.  It deliberately does not
    consult REDEMPTN.DLM or PARTREDM.DLM, so it does not infer any principal
    reduction from an actual redemption event.
    """
    any_go_or_revenue = pl.col('all_go') | pl.col('revenue')
    all_go = pl.col('all_go')
    revenue = pl.col('revenue')
    utgo = pl.col('utgo')
    ltgo = pl.col('ltgo')
    all_bonds = pl.lit(True)
    prefix = 'mergent_bondinfo_balance_only'
    as_of = date(year, 12, 31)

    balance_only = (
        eligible
        .with_columns(
            pl.when(
                pl.col('total_mat_amt_outstanding').is_not_null()
                & pl.col('total_mat_amt_outstanding_date').is_not_null()
                & (pl.col('total_mat_amt_outstanding_date') <= as_of)
            )
            .then(
                pl.min_horizontal(
                    pl.col('amount'),
                    pl.col('total_mat_amt_outstanding').clip(0.0, None),
                )
            )
            .otherwise(pl.col('amount'))
            .alias('amount')
        )
        .filter(pl.col('amount') > 0)
    )

    return (
        balance_only
        .group_by('issuer_key')
        .agg([
            amount_expr(all_bonds, f'{prefix}_total_outstanding_debt'),
            amount_expr(any_go_or_revenue, f'{prefix}_go_revenue_outstanding_debt'),
            amount_expr(all_go, f'{prefix}_all_go_outstanding_debt'),
            amount_expr(revenue, f'{prefix}_revenue_outstanding_debt'),
            amount_expr(utgo, f'{prefix}_utgo_outstanding_debt'),
            amount_expr(ltgo, f'{prefix}_ltgo_outstanding_debt'),
            count_expr(all_bonds, f'{prefix}_total_bonds_outstanding'),
            count_expr(any_go_or_revenue, f'{prefix}_go_revenue_bonds_outstanding'),
            count_expr(all_go, f'{prefix}_all_go_bonds_outstanding'),
            count_expr(revenue, f'{prefix}_revenue_bonds_outstanding'),
            count_expr(utgo, f'{prefix}_utgo_bonds_outstanding'),
            count_expr(ltgo, f'{prefix}_ltgo_bonds_outstanding'),
        ])
        .with_columns(pl.lit(year).alias('year'))
    )


mergent_years = []
newmoney_original_par_years = []
allbond_original_par_years = []
newmoney_point_in_time_years = []
bondinfo_balance_only_years = []
seed_issuer_name_audit_years = []

for year in target_years:
    as_of = date(year, 12, 31)
    print(f'Computing Mergent outstanding debt as of 12/31/{year}...')

    legacy_eligible = bonds.filter(
        (pl.col('offering_date') <= as_of)
        & (pl.col('maturity_date') > as_of)
    )
    # 2x2 audit, original-par row: the exact same offer/maturity screen for
    # new-money CUSIPs and for all CUSIPs.  No redemption or BONDINFO balance
    # information enters either cell.
    newmoney_original_par_years.append(
        aggregate_debt_composition_stock(
            legacy_eligible.filter(pl.col('new_money').eq(1)),
            year,
            'mergent_newmoney_original_par',
            'debt',
        )
    )
    allbond_original_par_years.append(
        aggregate_debt_composition_stock(
            legacy_eligible,
            year,
            'mergent_allbond_original_par',
            'debt',
        )
    )
    bondinfo_balance_only_years.append(
        aggregate_bondinfo_balance_only_stock(legacy_eligible, year)
    )

    redemptions_through_as_of = (
        redemption_events
        .filter(pl.col('event_date') <= as_of)
        .group_by(['issue_id', 'maturity_id'])
        .agg([
            pl.col('redemption_amount').sum().alias('redeemed_principal'),
            pl.col('unknown_full_redemption').max().alias('unknown_full_redemption'),
        ])
    )

    outstanding = (
        bonds
        .filter(
            (pl.col('offering_date') <= as_of)
            & (pl.col('maturity_date') > as_of)
        )
        .join(
            redemptions_through_as_of,
            on=['issue_id', 'maturity_id'],
            how='left',
        )
        .with_columns([
            pl.col('redeemed_principal').fill_null(0.0),
            pl.col('unknown_full_redemption').fill_null(0).cast(pl.Int8),
        ])
        # `amount` is the original CUSIP maturity offering amount.  The event
        # ledger provides one estimate of the remaining principal.  A dated
        # Mergent outstanding-balance observation is an additional upper bound
        # (and, importantly, can be zero when no dated redemption event exists).
        # Replace `amount` with the conservative remaining balance so every
        # aggregation and weighted average below uses principal still outstanding.
        .with_columns(
            pl.when(pl.col('unknown_full_redemption').eq(1))
            .then(pl.lit(0.0))
            .otherwise(
                pl.when(
                    pl.col('total_mat_amt_outstanding').is_not_null()
                    & pl.col('total_mat_amt_outstanding_date').is_not_null()
                    & (pl.col('total_mat_amt_outstanding_date') <= as_of)
                )
                .then(
                    pl.min_horizontal(
                        (pl.col('amount') - pl.col('redeemed_principal')).clip(0.0, None),
                        pl.col('total_mat_amt_outstanding').clip(0.0, None),
                    )
                )
                .otherwise(
                    (pl.col('amount') - pl.col('redeemed_principal')).clip(0.0, None)
                )
            )
            .alias('outstanding_amount')
        )
        .drop([
            'amount', 'redeemed_principal', 'unknown_full_redemption',
            'total_mat_amt_outstanding', 'total_mat_amt_outstanding_date',
        ])
        .rename({'outstanding_amount': 'amount'})
        .filter(pl.col('amount') > 0)
        .with_columns(
            (
                (pl.col('maturity_date') - pl.col('offering_date'))
                .dt.total_days()
                / 365.25
            ).alias('original_maturity_years')
        )
    )

    # Audit the issuer crosswalk using the *same* CUSIPs and outstanding
    # balances that feed the primary debt-stock measure.  Mergent's seeded
    # issuer identifier can occasionally pool similarly named municipalities
    # (for example, Dover and Andover, MA), so retain the raw issuer name and
    # its dollar contribution for every Census--Mergent match.
    seed_issuer_name_audit_years.append(
        outstanding
        .with_columns(
            pl.col('issuer_long_name')
            .cast(pl.Utf8)
            .fill_null('[MISSING]')
            .str.strip_chars()
            .str.to_uppercase()
            .alias('raw_issuer_long_name')
        )
        .group_by([
            'issuer_key', 'seed_issuer_id', 'seed_issuer', 'state',
            'raw_issuer_long_name',
        ])
        .agg([
            pl.col('cusip').n_unique().alias('outstanding_cusips'),
            pl.len().alias('outstanding_rows'),
            pl.col('amount').sum().alias('outstanding_debt'),
        ])
        .join(
            matches.select([
                'issuer_key', 'gov_id', 'census_name', 'government_type_label',
                'issuer_city_clean', 'match_type',
            ]).unique(subset=['issuer_key'], keep='first'),
            on='issuer_key',
            how='inner',
        )
        .with_columns([
            pl.lit(year).alias('year'),
            pl.col('issuer_city_clean')
            .cast(pl.Utf8)
            .fill_null('')
            .str.to_uppercase()
            .str.replace_all(r'[^A-Z0-9]+', ' ')
            .str.strip_chars()
            .alias('audit_census_city_name'),
            pl.col('raw_issuer_long_name')
            .str.replace_all(r'[^A-Z0-9]+', ' ')
            .str.strip_chars()
            .alias('audit_raw_issuer_name'),
        ])
        # Use bounded spaces so DOVER is not judged present merely because it
        # is a substring of ANDOVER.  This is a screening flag, not a claim
        # that every nonliteral issuer label is necessarily an incorrect match.
        .with_columns(
            pl.concat_str([
                pl.lit(' '), pl.col('audit_raw_issuer_name'), pl.lit(' '),
            ])
            .str.contains(
                pl.concat_str([
                    pl.lit(' '), pl.col('audit_census_city_name'), pl.lit(' '),
                ]),
                literal=True,
            )
            .alias('raw_name_contains_census_city')
        )
        .with_columns(
            pl.col('audit_raw_issuer_name')
            .str.starts_with(pl.col('audit_census_city_name'))
            .alias('raw_name_starts_with_census_city')
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
    # 2x2 audit, point-in-time row: retain only new-money CUSIPs while using
    # exactly the same redemption/BONDINFO balance adjustment as the primary
    # all-bond point-in-time stock.
    newmoney_point_in_time_years.append(
        aggregate_debt_composition_stock(
            outstanding.filter(pl.col('new_money').eq(1)),
            year,
            'mergent_newmoney_point_in_time',
            'outstanding_debt',
        )
    )

mergent_outstanding = pl.concat(mergent_years, how='diagonal')
newmoney_original_par = pl.concat(newmoney_original_par_years, how='diagonal')
allbond_original_par = pl.concat(allbond_original_par_years, how='diagonal')
newmoney_point_in_time = pl.concat(newmoney_point_in_time_years, how='diagonal')
bondinfo_balance_only = pl.concat(bondinfo_balance_only_years, how='diagonal')
seed_issuer_name_audit = pl.concat(seed_issuer_name_audit_years, how='diagonal')

# One row per city-year makes it easy to prioritize the groups whose
# nonmatching raw names account for material outstanding principal.  The
# companion detail file below retains one row per raw issuer label.
seed_issuer_name_audit_summary = (
    seed_issuer_name_audit
    .group_by([
        'year', 'issuer_key', 'seed_issuer_id', 'seed_issuer', 'state',
        'gov_id', 'census_name', 'government_type_label',
        'issuer_city_clean', 'match_type',
    ])
    .agg([
        pl.col('raw_issuer_long_name').n_unique().alias('raw_issuer_name_count'),
        pl.col('outstanding_cusips').sum().alias('outstanding_cusips'),
        pl.col('outstanding_rows').sum().alias('outstanding_rows'),
        pl.col('outstanding_debt').sum().alias('outstanding_debt'),
        pl.when(~pl.col('raw_name_contains_census_city'))
        .then(pl.col('outstanding_debt'))
        .otherwise(0.0)
        .sum()
        .alias('raw_name_nonmatching_debt'),
        pl.when(~pl.col('raw_name_starts_with_census_city'))
        .then(pl.col('outstanding_debt'))
        .otherwise(0.0)
        .sum()
        .alias('raw_name_nonprefix_debt'),
        pl.col('raw_name_contains_census_city').all().alias('all_raw_names_contain_census_city'),
        pl.col('raw_name_starts_with_census_city').all().alias('all_raw_names_start_with_census_city'),
    ])
    .with_columns([
        (pl.col('outstanding_debt') / 1_000_000).alias('outstanding_debt_mil'),
        (pl.col('raw_name_nonmatching_debt') / 1_000_000).alias('raw_name_nonmatching_debt_mil'),
        (pl.col('raw_name_nonprefix_debt') / 1_000_000).alias('raw_name_nonprefix_debt_mil'),
        pl.when(pl.col('outstanding_debt') > 0)
        .then(pl.col('raw_name_nonmatching_debt') / pl.col('outstanding_debt'))
        .otherwise(None)
        .alias('raw_name_nonmatching_debt_share'),
        pl.when(pl.col('outstanding_debt') > 0)
        .then(pl.col('raw_name_nonprefix_debt') / pl.col('outstanding_debt'))
        .otherwise(None)
        .alias('raw_name_nonprefix_debt_share'),
    ])
    .sort(['year', 'raw_name_nonprefix_debt_share', 'outstanding_debt'], descending=[False, True, True])
)

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


audit_stock_specs = [
    ('mergent_newmoney_original_par', newmoney_original_par, 'debt'),
    ('mergent_allbond_original_par', allbond_original_par, 'debt'),
    ('mergent_newmoney_point_in_time', newmoney_point_in_time, 'outstanding_debt'),
]
audit_stock_amount_cols = {
    prefix: [
        f'{prefix}_{suffix}_{debt_suffix}'
        for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
    ]
    for prefix, _, debt_suffix in audit_stock_specs
}
newmoney_original_par = newmoney_original_par.with_columns([
    (pl.col(col) / 1_000_000).alias(f'{col}_mil')
    for col in audit_stock_amount_cols['mergent_newmoney_original_par']
])
allbond_original_par = allbond_original_par.with_columns([
    (pl.col(col) / 1_000_000).alias(f'{col}_mil')
    for col in audit_stock_amount_cols['mergent_allbond_original_par']
])
newmoney_point_in_time = newmoney_point_in_time.with_columns([
    (pl.col(col) / 1_000_000).alias(f'{col}_mil')
    for col in audit_stock_amount_cols['mergent_newmoney_point_in_time']
])

bondinfo_balance_only_amount_cols = [
    f'mergent_bondinfo_balance_only_{suffix}_outstanding_debt'
    for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
]
bondinfo_balance_only = bondinfo_balance_only.with_columns([
    (pl.col(col) / 1_000_000).alias(col.replace('_debt', '_debt_mil'))
    for col in bondinfo_balance_only_amount_cols
])


#%% -----------------------------------------------------------------------
# merge and save full and border samples
# -----------------------------------------------------------------------
print('Merging Census, Mergent outstanding debt, and controls...')
full_panel = (
    census_cross_section
    .join(issuers, on='issuer_key', how='left', suffix='_issuer')
    .join(mergent_outstanding, on=['issuer_key', 'year'], how='left')
    .join(newmoney_original_par, on=['issuer_key', 'year'], how='left')
    .join(allbond_original_par, on=['issuer_key', 'year'], how='left')
    .join(newmoney_point_in_time, on=['issuer_key', 'year'], how='left')
    .join(bondinfo_balance_only, on=['issuer_key', 'year'], how='left')
)

for col in mergent_amount_cols:
    full_panel = full_panel.with_columns(pl.col(col).fill_null(0))
    full_panel = full_panel.with_columns(pl.col(col.replace('_debt', '_debt_mil')).fill_null(0))


for prefix, _, _ in audit_stock_specs:
    for col in audit_stock_amount_cols[prefix]:
        full_panel = full_panel.with_columns(pl.col(col).fill_null(0))
        full_panel = full_panel.with_columns(pl.col(f'{col}_mil').fill_null(0))
    for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']:
        full_panel = full_panel.with_columns(
            pl.col(f'{prefix}_{suffix}_bonds').fill_null(0)
        )

for col in bondinfo_balance_only_amount_cols:
    full_panel = full_panel.with_columns(pl.col(col).fill_null(0))
    full_panel = full_panel.with_columns(pl.col(col.replace('_debt', '_debt_mil')).fill_null(0))

for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']:
    full_panel = full_panel.with_columns(
        pl.col(f'mergent_bondinfo_balance_only_{suffix}_bonds_outstanding')
        .fill_null(0)
    )


# Census total debt not represented by the issuer's outstanding Mergent bonds.
# Both input measures are in millions of dollars.
full_panel = full_panel.with_columns(
    (
        pl.col('census_total_debt_mil')
        - pl.col('mergent_total_outstanding_debt_mil')
    ).alias('total_nonmergent_census_debt_mil')
)

# Debt-composition shares used in the point-in-time debt-choice analysis. The
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

# BONDINFO-only robustness: use the same classification and denominator as the
# primary debt-choice outcome, but do not use any redemption-file event.
full_panel = full_panel.with_columns([
    pl.when(pl.col('mergent_bondinfo_balance_only_go_revenue_outstanding_debt') > 0)
    .then(
        pl.col('mergent_bondinfo_balance_only_utgo_outstanding_debt')
        / pl.col('mergent_bondinfo_balance_only_go_revenue_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_utgo_bondinfo_balance_only_outstanding'),
    pl.when(pl.col('mergent_bondinfo_balance_only_go_revenue_outstanding_debt') > 0)
    .then(
        pl.col('mergent_bondinfo_balance_only_ltgo_outstanding_debt')
        / pl.col('mergent_bondinfo_balance_only_go_revenue_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_ltgo_bondinfo_balance_only_outstanding'),
    pl.when(pl.col('mergent_bondinfo_balance_only_go_revenue_outstanding_debt') > 0)
    .then(
        pl.col('mergent_bondinfo_balance_only_revenue_outstanding_debt')
        / pl.col('mergent_bondinfo_balance_only_go_revenue_outstanding_debt')
    )
    .otherwise(None)
    .alias('frac_rev_bondinfo_balance_only_outstanding'),
])

# Four-cell new-money/refunding × original-par/point-in-time audit.  The
# fourth cell is the primary ``frac_*_outstanding`` series already created
# above; these three sets of shares complete the 2x2.
audit_share_specs = [
    ('mergent_newmoney_original_par', 'newmoney_original_par', 'debt'),
    ('mergent_allbond_original_par', 'allbond_original_par', 'debt'),
    ('mergent_newmoney_point_in_time', 'newmoney_point_in_time_outstanding', 'outstanding_debt'),
]
full_panel = full_panel.with_columns([
    pl.when(pl.col(f'{prefix}_go_revenue_{debt_suffix}') > 0)
    .then(
        pl.col(f'{prefix}_{category}_{debt_suffix}')
        / pl.col(f'{prefix}_go_revenue_{debt_suffix}')
    )
    .otherwise(None)
    .alias(f'frac_{category}_{share_suffix}')
    for prefix, share_suffix, debt_suffix in audit_share_specs
    for category in ['utgo', 'ltgo', 'revenue']
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
        f'frac_{category}_{share_suffix}'
        for share_suffix in [
            'newmoney_original_par',
            'allbond_original_par',
            'newmoney_point_in_time_outstanding',
        ]
        for category in ['utgo', 'ltgo', 'revenue']
    ],
    'frac_utgo_bondinfo_balance_only_outstanding',
    'frac_ltgo_bondinfo_balance_only_outstanding',
    'frac_rev_bondinfo_balance_only_outstanding',
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
        f'{prefix}_{suffix}_debt{unit}'
        for prefix in [
            'mergent_newmoney_original_par',
            'mergent_allbond_original_par',
        ]
        for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
        for unit in ['', '_mil']
    ],
    *[
        f'mergent_newmoney_point_in_time_{suffix}_outstanding_debt{unit}'
        for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
        for unit in ['', '_mil']
    ],
    *[
        f'{prefix}_{suffix}_bonds'
        for prefix in [
            'mergent_newmoney_original_par',
            'mergent_allbond_original_par',
            'mergent_newmoney_point_in_time',
        ]
        for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
    ],
    *[
        f'mergent_bondinfo_balance_only_{suffix}_outstanding_debt{unit}'
        for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
        for unit in ['', '_mil']
    ],
    *[
        f'mergent_bondinfo_balance_only_{suffix}_bonds_outstanding'
        for suffix in ['total', 'go_revenue', 'all_go', 'revenue', 'utgo', 'ltgo']
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

    full_path = out_dir / f'census_mergent_debt_cross_section_{year}.csv'
    border_path = out_dir / f'census_mergent_debt_cross_section_{year}_border_sample.csv'

    full_out.write_csv(full_path)
    border_out.write_csv(border_path)

    # The balance-only alternative is kept in its own file so it cannot be
    # confused with the redemption-ledger stock used by the primary analysis.
    if year == 2017:
        balance_only_path = out_dir / (
            'census_mergent_debt_cross_section_2017_bondinfo_balance_only.csv'
        )
        full_out.write_csv(balance_only_path)

    print(f'Wrote {full_path}: {full_out.height:,} rows')
    print(f'Wrote {border_path}: {border_out.height:,} rows')
    if year == 2017:
        print(f'Wrote {balance_only_path}: {full_out.height:,} rows')


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
seed_issuer_name_audit.write_csv(
    diag_dir / 'census_mergent_seed_issuer_name_audit_detail.csv'
)
seed_issuer_name_audit_summary.write_csv(
    diag_dir / 'census_mergent_seed_issuer_name_audit_summary.csv'
)
print(diagnostics)

# %%
