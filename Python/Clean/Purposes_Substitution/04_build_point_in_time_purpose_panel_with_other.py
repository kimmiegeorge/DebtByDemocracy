"""Build the 2017 point-in-time purpose panel including Other public debt.

The panel mirrors the main purpose-substitution input, but uses the v2020
all-public-debt Mergent file and keeps only new-money bonds. Within every
issuer-purpose cell, GO, Revenue, and Other (COO/COP plus residual Other) form
an exhaustive denominator. The output supports R step 06c.
"""

#%% Set up
import os
from datetime import date
from pathlib import Path

import pandas as pd
import polars as pl


code_dir = Path(__file__).resolve().parents[3]
root = code_dir.parent
data_dir = root / 'Data'
dpc_uop_dir = data_dir / 'DPC Data' / 'Use Of Proceeds'
output_dir = Path(os.getenv(
    'PURPOSE_WITH_OTHER_DIR',
    str(dpc_uop_dir / 'Purposes Substitution' / 'with_other'),
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)

mergent_file = Path(os.getenv(
    'MERGENT_ALLPUBDEBT_FILE',
    str(
        data_dir / 'Mergent' / 'Clean'
        / '261013_city_cusiplevel_finsample_allpubdebt_v2020.dta'
    ),
)).expanduser()
dpc_file = dpc_uop_dir / '260223_dpcdata_cusip_purpose.csv'
cross_section_file = (
    data_dir / 'Clean_Intermediate' / 'Census COG Finance' / 'processed'
    / 'no_refundings' / 'census_mergent_debt_cross_section_2017.csv'
)
state_policy_file = (
    data_dir / 'State Policies' / '20260929_state_policy_comparison.csv'
)
output_file = (
    output_dir
    / '261013_dpc_point_in_time_purpose_substitution_2017_issuer_category_panel_with_other.csv'
)
summary_file = output_dir / '261013_purpose_with_other_build_summary.csv'

as_of = date(2017, 12, 31)


#%% Purpose definitions
category_defs = {
    'transportation': {
        'label': 'Transportation',
        'raw_vars': ['pubtransit', 'street'],
        'revenue_feasible': 1,
    },
    'utilities': {
        'label': 'Utilities',
        'raw_vars': ['wtrswr', 'elec', 'gas', 'waste'],
        'revenue_feasible': 1,
    },
    'public_safety': {
        'label': 'Public safety',
        'raw_vars': ['fire', 'police'],
        'revenue_feasible': 0,
    },
    'recreation_amenities': {
        'label': 'Recreation/amenities',
        'raw_vars': ['parksrec', 'libarts', 'health', 'sport'],
        'revenue_feasible': 1,
    },
    'other_public_buildings': {
        'label': 'Other public buildings',
        'raw_vars': ['otherpubbldg'],
        'revenue_feasible': 0,
    },
    'other': {
        'label': 'Other',
        'raw_vars': ['other', 'educ', 'econdev'],
        'revenue_feasible': 0,
    },
}
category_cols = list(category_defs)
raw_purpose_vars = sorted({
    raw_var
    for category in category_defs.values()
    for raw_var in category['raw_vars']
})
category_dictionary = pl.DataFrame([
    {
        'purpose_category': category,
        'purpose_category_label': spec['label'],
        'raw_dpc_vars': ';'.join(spec['raw_vars']),
        'revenue_feasible': spec['revenue_feasible'],
    }
    for category, spec in category_defs.items()
])


#%% Load and screen the expanded Mergent bonds
bond_columns = [
    'issue_id',
    'cusip',
    'seed_issuer_id',
    'seed_issuer',
    'state',
    'offering_date',
    'maturity_date',
    'amount',
    'go_unlim',
    'go_lim',
    'rev',
    'bond_type',
    'debt_type',
    'new_money',
]

print('Loading expanded all-public-debt Mergent file...')
bonds = pl.from_pandas(pd.read_stata(
    mergent_file,
    columns=bond_columns,
    convert_categoricals=False,
))

bonds = (
    bonds
    .with_columns([
        pl.col('issue_id').cast(pl.Int64, strict=False),
        pl.col('cusip').cast(pl.Utf8).str.to_uppercase()
        .str.replace_all(r'[^A-Z0-9]', '').alias('cusip_norm'),
        pl.col('seed_issuer_id').cast(pl.Float64),
        pl.col('seed_issuer').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        pl.col('state').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        pl.col('offering_date').cast(pl.Date),
        pl.col('maturity_date').cast(pl.Date),
        pl.col('amount').cast(pl.Float64),
        pl.col('go_unlim').fill_null(0).cast(pl.Int8),
        pl.col('go_lim').fill_null(0).cast(pl.Int8),
        pl.col('rev').fill_null(0).cast(pl.Int8),
        pl.col('bond_type').cast(pl.Utf8).str.strip_chars().str.to_lowercase(),
        pl.col('debt_type').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        pl.col('new_money').fill_null(0).cast(pl.Int8),
    ])
    .with_columns(
        pl.concat_str([
            pl.col('state'),
            pl.lit('|'),
            pl.col('seed_issuer'),
        ]).alias('issuer_match_key')
    )
    # Apply the new-money restriction before constructing any outcome.
    .filter(pl.col('new_money') == 1)
    .filter(pl.col('seed_issuer_id').is_not_null())
    .filter(pl.col('issuer_match_key').is_not_null())
    .filter(pl.col('amount').is_not_null() & (pl.col('amount') > 0))
    .filter(
        (pl.col('offering_date') <= as_of)
        & (pl.col('maturity_date') > as_of)
    )
    .with_columns([
        (pl.col('go_unlim').eq(1) | pl.col('go_lim').eq(1))
        .cast(pl.Int8).alias('go_bond'),
        pl.col('rev').eq(1).cast(pl.Int8).alias('revenue_bond'),
        pl.col('bond_type').is_in(['cop', 'other'])
        .cast(pl.Int8).alias('other_bond'),
    ])
    .with_columns(
        (
            pl.col('go_bond')
            + pl.col('revenue_bond')
            + pl.col('other_bond')
        ).alias('debt_category_count')
    )
)

invalid_partition = bonds.filter(pl.col('debt_category_count') != 1)
if invalid_partition.height > 0:
    raise ValueError(
        f'{invalid_partition.height:,} new-money bonds do not map uniquely to '
        'GO, Revenue, or Other.'
    )
if bonds.filter(pl.col('new_money') != 1).height > 0:
    raise ValueError('Refunding/non-new-money bonds remain after the screen.')


#%% Attach DPC purpose indicators
print('Loading and collapsing DPC purpose indicators...')
dpc = (
    pl.read_csv(dpc_file, infer_schema_length=100000)
    .with_columns([
        pl.col('CUSIP').cast(pl.Utf8).str.to_uppercase()
        .str.replace_all(r'[^A-Z0-9]', '').alias('cusip_norm'),
        *[
            (pl.col(column).fill_null(0) > 0).cast(pl.Int8).alias(column)
            for column in raw_purpose_vars
        ],
    ])
    .group_by('cusip_norm', maintain_order=True)
    .agg([
        pl.len().alias('n_dpc_rows'),
        *[pl.col(column).max() for column in raw_purpose_vars],
    ])
    .with_columns(pl.lit(1).cast(pl.Int8).alias('dpc_match'))
)

bonds = (
    bonds
    .join(dpc, on='cusip_norm', how='left', validate='m:1')
    .with_columns([
        pl.col('dpc_match').fill_null(0),
        *[pl.col(column).fill_null(0) for column in raw_purpose_vars],
    ])
)

for category, spec in category_defs.items():
    bonds = bonds.with_columns(
        pl.any_horizontal([
            pl.col(raw_var).eq(1)
            for raw_var in spec['raw_vars']
        ]).cast(pl.Int8).alias(category)
    )


#%% Load the 2017 issuer cross section and controls
cross_section_columns = [
    'year',
    'issuer_key',
    'seed_issuer_id',
    'seed_issuer',
    'state',
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
    'state_ltgo_allowed',
    'demographic_year',
    'ln_gdp',
    'census_population',
    'ln_pers_inc',
    'ln_1p_county_nonmunicipal_total_debt',
    'glm_proactive',
    'strict_municipal_debt_limit',
]

cross_section = (
    pl.read_csv(
        cross_section_file,
        columns=cross_section_columns,
        infer_schema_length=100000,
    )
    .with_columns([
        pl.col('seed_issuer_id').cast(pl.Float64),
        pl.col('seed_issuer').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        pl.col('state').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5),
        pl.when(pl.col('census_population') > 0)
        .then(pl.col('census_population').log())
        .otherwise(None)
        .alias('ln_census_population'),
    ])
    .with_columns(
        pl.concat_str([
            pl.col('state'),
            pl.lit('|'),
            pl.col('seed_issuer'),
        ]).alias('issuer_match_key')
    )
)

# Refresh the state controls from the same policy comparison used by the main
# purpose-substitution builder. In particular, the older Census cross section
# leaves Nebraska's strict-debt-limit field missing.
state_policy_columns = [
    'state_go_vote',
    'state_ltgo_allowed',
    'glm_proactive',
    'strict_municipal_debt_limit',
]
state_policy = (
    pl.read_csv(
        state_policy_file,
        columns=['state_abbr', *state_policy_columns],
        infer_schema_length=10000,
    )
    .rename({'state_abbr': 'state'})
    .with_columns(
        pl.col('state').cast(pl.Utf8).str.strip_chars().str.to_uppercase()
    )
)
if (
    state_policy.height != 50
    or state_policy['state'].null_count() > 0
    or state_policy['state'].n_unique() != 50
):
    raise ValueError(
        'State-policy comparison must contain one row for each of the 50 states.'
    )

cross_section = (
    cross_section
    .drop(*state_policy_columns)
    .join(state_policy, on='state', how='left', validate='m:1')
)
if cross_section.select(state_policy_columns).null_count().sum_horizontal().sum() > 0:
    raise ValueError('The refreshed 2017 state-policy controls contain missing values.')

issuer_key_cols = ['issuer_match_key']
duplicate_issuers = (
    cross_section.group_by(issuer_key_cols).len().filter(pl.col('len') > 1)
)
if duplicate_issuers.height > 0:
    raise ValueError('The 2017 cross section has duplicate state/name issuer keys.')


#%% Construct issuer-purpose outcomes
issuer_bond_counts = (
    bonds
    .group_by(issuer_key_cols)
    .agg(
        pl.col('cusip_norm').n_unique().alias('mergent_total_bonds_outstanding')
    )
)

matched_bonds = bonds.filter(pl.col('dpc_match') == 1)
issuer_dpc_coverage = (
    matched_bonds
    .group_by(issuer_key_cols)
    .agg(
        pl.col('amount').sum().alias('dpc_matched_all_public_amount')
    )
)

bond_id_cols = [
    *issuer_key_cols,
    'cusip_norm',
    'issue_id',
    'amount',
    'go_bond',
    'revenue_bond',
    'other_bond',
]
cusip_category = (
    matched_bonds
    .select(bond_id_cols + category_cols)
    .unpivot(
        index=bond_id_cols,
        on=category_cols,
        variable_name='purpose_category',
        value_name='has_purpose_category',
    )
    .filter(pl.col('has_purpose_category') == 1)
    .drop('has_purpose_category')
)

issuer_category_amount = (
    cusip_category
    .group_by([*issuer_key_cols, 'purpose_category'])
    .agg([
        pl.col('amount').sum().alias('all_public_category_amount'),
        pl.col('amount').filter(pl.col('go_bond') == 1)
        .sum().alias('go_category_amount'),
        pl.col('amount').filter(pl.col('revenue_bond') == 1)
        .sum().alias('revenue_category_amount'),
        pl.col('amount').filter(pl.col('other_bond') == 1)
        .sum().alias('other_category_amount'),
        pl.col('cusip_norm').n_unique().alias('all_public_category_bonds'),
        pl.col('cusip_norm').filter(pl.col('go_bond') == 1)
        .n_unique().alias('go_category_bonds'),
        pl.col('cusip_norm').filter(pl.col('revenue_bond') == 1)
        .n_unique().alias('revenue_category_bonds'),
        pl.col('cusip_norm').filter(pl.col('other_bond') == 1)
        .n_unique().alias('other_category_bonds'),
        pl.col('issue_id').n_unique().alias('category_issues'),
    ])
)

issuer_category_grid = cross_section.select(issuer_key_cols).join(
    pl.DataFrame({'purpose_category': category_cols}),
    how='cross',
)
amount_columns = [
    'all_public_category_amount',
    'go_category_amount',
    'revenue_category_amount',
    'other_category_amount',
]
count_columns = [
    'all_public_category_bonds',
    'go_category_bonds',
    'revenue_category_bonds',
    'other_category_bonds',
    'category_issues',
]

issuer_category = (
    issuer_category_grid
    .join(
        issuer_category_amount,
        on=[*issuer_key_cols, 'purpose_category'],
        how='left',
    )
    .join(issuer_dpc_coverage, on=issuer_key_cols, how='left')
    .join(issuer_bond_counts, on=issuer_key_cols, how='left')
    .with_columns([
        pl.col(column).fill_null(0)
        for column in amount_columns + count_columns
    ])
    .with_columns([
        pl.col('mergent_total_bonds_outstanding').fill_null(0),
        pl.col('dpc_matched_all_public_amount').is_not_null().cast(pl.Int8)
        .alias('dpc_purpose_observed'),
    ])
    .with_columns([
        pl.when(pl.col('dpc_purpose_observed') == 1)
        .then(pl.col(column))
        .otherwise(None)
        .alias(column)
        for column in amount_columns + count_columns
    ])
    .with_columns([
        pl.when(pl.col('all_public_category_amount') > 0)
        .then(
            pl.col('revenue_category_amount')
            / pl.col('all_public_category_amount')
        )
        .otherwise(None)
        .alias('share_revenue_of_all_public_amount'),
        pl.when(pl.col('all_public_category_amount') > 0)
        .then(
            pl.col('other_category_amount')
            / pl.col('all_public_category_amount')
        )
        .otherwise(None)
        .alias('share_other_of_all_public_amount'),
        pl.when(pl.col('all_public_category_amount') > 0)
        .then(
            pl.col('go_category_amount')
            / pl.col('all_public_category_amount')
        )
        .otherwise(None)
        .alias('share_go_of_all_public_amount'),
    ])
    .join(category_dictionary, on='purpose_category', how='left')
    .join(cross_section, on=issuer_key_cols, how='left', suffix='_cs')
)


#%% Validate and write the regression panel
positive_categories = issuer_category.filter(
    pl.col('all_public_category_amount') > 0
)
share_error = positive_categories.select(
    (
        pl.col('share_go_of_all_public_amount')
        + pl.col('share_revenue_of_all_public_amount')
        + pl.col('share_other_of_all_public_amount')
        - 1
    ).abs().max()
).item()
if share_error is not None and share_error > 1e-10:
    raise ValueError(f'GO, Revenue, and Other shares do not sum to one: {share_error}')

expected_rows = cross_section.height * len(category_cols)
if issuer_category.height != expected_rows:
    raise ValueError(
        f'Expected {expected_rows:,} issuer-category rows; '
        f'found {issuer_category.height:,}.'
    )

output_columns = [
    'year',
    'issuer_key',
    'issuer_match_key',
    'seed_issuer_id',
    'seed_issuer',
    'state',
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
    'state_ltgo_allowed',
    'demographic_year',
    'ln_gdp',
    'ln_census_population',
    'ln_pers_inc',
    'ln_1p_county_nonmunicipal_total_debt',
    'glm_proactive',
    'strict_municipal_debt_limit',
    'mergent_total_bonds_outstanding',
    'dpc_purpose_observed',
    'purpose_category',
    'purpose_category_label',
    'revenue_feasible',
    'all_public_category_amount',
    'go_category_amount',
    'revenue_category_amount',
    'other_category_amount',
    'share_go_of_all_public_amount',
    'share_revenue_of_all_public_amount',
    'share_other_of_all_public_amount',
    'all_public_category_bonds',
    'go_category_bonds',
    'revenue_category_bonds',
    'other_category_bonds',
    'category_issues',
]
issuer_category = issuer_category.select(output_columns)
issuer_category.write_csv(output_file)

build_summary = pl.DataFrame({
    'metric': [
        'new_money_outstanding_bonds',
        'new_money_outstanding_issuers',
        'dpc_matched_bonds',
        'dpc_observed_issuers',
        'regression_panel_rows',
        'positive_issuer_purpose_cells',
    ],
    'value': [
        bonds.select(pl.col('cusip_norm').n_unique()).item(),
        bonds.select(issuer_key_cols).unique().height,
        matched_bonds.select(pl.col('cusip_norm').n_unique()).item(),
        issuer_dpc_coverage.height,
        issuer_category.height,
        positive_categories.height,
    ],
})
build_summary.write_csv(summary_file)

print(build_summary)
print(f'Wrote {output_file}')
print(f'Wrote {summary_file}')
