'''
Build point-in-time DPC purpose substitution cross sections.

This script uses DPC use-of-proceeds categories and Mergent outstanding bonds
to create issuer x purpose-category panels as of 12/31/2012 and 12/31/2017.
It mirrors the Census/Mergent point-in-time debt framework.
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


output_date = '260719'

root = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
data_dir = root / 'Data'
dpc_uop_dir = data_dir / 'DPC Data' / 'Use Of Proceeds'
purpose_dir = dpc_uop_dir / 'Purposes Substitution'
mergent_dir = data_dir / 'Mergent' / 'Clean'
census_processed_dir = (
    data_dir / 'Clean_Intermediate' / 'Census COG Finance' / 'processed'
)

purpose_dir.mkdir(parents=True, exist_ok=True)

merged_bond_input = dpc_uop_dir / '260622_dpc_use_proceeds_merged_debt_choice_bonds.csv'
mergent_bond_file = mergent_dir / '260709_city_cusiplevel_statereq_purpose_yieldspread.dta'

target_years = [2012, 2017]

category_output_template = (
    purpose_dir / f'{output_date}_dpc_point_in_time_purpose_substitution_{{year}}_issuer_category_panel.csv'
)
wide_output_template = (
    purpose_dir / f'{output_date}_dpc_point_in_time_purpose_substitution_{{year}}_issuer_category_wide.csv'
)
category_dictionary_output = (
    purpose_dir / f'{output_date}_dpc_point_in_time_purpose_substitution_category_dictionary.csv'
)


#%% -----------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------
def require_pandas() -> None:
    if pd is None:
        raise ImportError('pandas is required to read Mergent Stata files.')


def read_stata_columns(path, columns):
    require_pandas()
    return pl.from_pandas(pd.read_stata(path, columns=columns, convert_categoricals=False))


def zero_if_missing(col):
    return pl.col(col).fill_null(0).cast(pl.Int64)


def issuer_match_key_expr():
    '''Match legacy DPC bonds to current cross sections without numeric issuer IDs.'''
    return pl.concat_str([
        pl.col('state').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        pl.lit('|'),
        pl.col('seed_issuer').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
    ])


#%% -----------------------------------------------------------------------
# category definitions
# -----------------------------------------------------------------------
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

category_cols = list(category_defs.keys())

category_dictionary = pl.DataFrame([
    {
        'purpose_category': key,
        'purpose_category_label': value['label'],
        'raw_dpc_vars': ';'.join(value['raw_vars']),
        'revenue_feasible': value['revenue_feasible'],
    }
    for key, value in category_defs.items()
])
category_dictionary.write_csv(category_dictionary_output)


#%% -----------------------------------------------------------------------
# load DPC-Mergent merged bonds and Mergent maturity/debt details
# -----------------------------------------------------------------------
print('Loading DPC-Mergent merged bonds...')

bond = pl.read_csv(
    merged_bond_input,
    infer_schema_length=10000,
    try_parse_dates=True,
)

raw_purpose_vars = sorted({
    raw_var
    for category in category_defs.values()
    for raw_var in category['raw_vars']
})

for col in raw_purpose_vars + ['dpc_match']:
    if col in bond.columns:
        bond = bond.with_columns(zero_if_missing(col))

print('Loading Mergent dates and security details...')
mergent_cols = [
    'cusip',
    'maturity_date',
    'go_unlim',
    'go_lim',
    'rev',
    'security_code',
    'source_of_repayment',
]

mergent = read_stata_columns(mergent_bond_file, mergent_cols)
mergent = (
    mergent
    .with_columns([
        pl.col('cusip').cast(pl.Utf8),
        pl.col('maturity_date').cast(pl.Date),
        pl.col('go_unlim').fill_null(0).cast(pl.Int64),
        pl.col('go_lim').fill_null(0).cast(pl.Int64),
        pl.col('rev').cast(pl.Int64),
        pl.col('security_code').cast(pl.Utf8),
        pl.col('source_of_repayment').cast(pl.Utf8),
    ])
    .unique(subset=['cusip'], keep='first')
)

bond = (
    bond
    .with_columns([
        pl.col('cusip').cast(pl.Utf8),
        pl.col('issue_id').cast(pl.Int64, strict=False),
        pl.col('state').cast(pl.Utf8).str.to_uppercase(),
        pl.col('amount').cast(pl.Float64),
        pl.col('offering_date').cast(pl.Date),
        issuer_match_key_expr().alias('issuer_match_key'),
    ])
    .join(mergent, on='cusip', how='left', suffix='_mergent')
)

# Use the current Mergent classifications rather than the older copies in the
# DPC merge. In particular, the current `rev` field excludes the same
# sales/excise-tax and other non-strict revenue bonds as the point-in-time
# debt-choice pipeline. That pipeline also restricts its bond universe to
# nonmissing `rev` (0 for GO, 1 for strict revenue), so apply the same screen.
bond = (
    bond
    .with_columns([
        pl.col('go_unlim_mergent').alias('go_unlim'),
        pl.col('go_lim_mergent').alias('go_lim'),
        pl.col('rev_mergent').alias('rev'),
        pl.col('security_code_mergent').alias('security_code'),
        pl.col('source_of_repayment_mergent').alias('source_of_repayment'),
    ])
    .drop([
        'go_unlim_mergent',
        'go_lim_mergent',
        'rev_mergent',
        'security_code_mergent',
        'source_of_repayment_mergent',
    ])
    .filter(pl.col('rev').is_not_null())
)


#%% -----------------------------------------------------------------------
# create category and debt-type indicators
# -----------------------------------------------------------------------
for category, spec in category_defs.items():
    raw_exprs = [pl.col(raw_var).eq(1) for raw_var in spec['raw_vars']]
    category_expr = raw_exprs[0]
    for expr in raw_exprs[1:]:
        category_expr = category_expr | expr
    bond = bond.with_columns(category_expr.cast(pl.Int64).alias(category))

bond = (
    bond
    .with_columns([
        (pl.col('go_unlim').eq(1) | pl.col('go_lim').eq(1)).cast(pl.Int64).alias('go_any'),
        pl.col('go_unlim').eq(1).cast(pl.Int64).alias('utgo'),
        pl.col('go_lim').eq(1).cast(pl.Int64).alias('ltgo'),
        pl.col('rev').eq(1).cast(pl.Int64).alias('revenue_bond'),
    ])
    .filter(pl.col('dpc_match').eq(1))
    .filter(pl.col('issuer_match_key').is_not_null())
    .filter(pl.col('offering_date').is_not_null())
    .filter(pl.col('maturity_date').is_not_null())
    .filter(pl.col('amount').is_not_null())
    .filter(pl.col('amount') > 0)
)


#%% -----------------------------------------------------------------------
# build year-specific point-in-time issuer-category panels
# -----------------------------------------------------------------------
for year in target_years:
    print(f'Building point-in-time purpose panel for {year}...')
    as_of = date(year, 12, 31)

    cross_section_file = (
        census_processed_dir / f'census_mergent_debt_cross_section_{year}.csv'
    )
    cross_section = (
        pl.read_csv(cross_section_file, infer_schema_length=10000)
        .with_columns([
            pl.col('seed_issuer_id').cast(pl.Float64),
            pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5),
            issuer_match_key_expr().alias('issuer_match_key'),
            pl.when(pl.col('census_population') > 0)
            .then(pl.col('census_population').log())
            .otherwise(None)
            .alias('ln_census_population'),
            ((pl.col('census_total_debt_mil') * 1000000) + 1)
            .log()
            .alias('ln_1p_census_total_debt'),
        ])
        .filter(pl.col('issuer_match_key').is_not_null())
    )

    duplicate_match_keys = (
        cross_section
        .group_by('issuer_match_key')
        .len()
        .filter(pl.col('len') > 1)
    )
    if duplicate_match_keys.height > 0:
        raise ValueError(
            f'Current {year} cross section contains duplicate state/name issuer keys.'
        )

    outstanding = (
        bond
        .filter(
            (pl.col('offering_date') <= as_of)
            & (pl.col('maturity_date') > as_of)
        )
        .filter(
            pl.col('issuer_match_key').is_in(
                cross_section['issuer_match_key'].to_list()
            )
        )
        .with_columns([
            (
                pl.when(pl.col('go_any').eq(1) | pl.col('revenue_bond').eq(1))
                .then(pl.col('amount'))
                .otherwise(0)
            ).alias('go_or_revenue_amount'),
            (
                pl.when(pl.col('revenue_bond').eq(1))
                .then(pl.col('amount'))
                .otherwise(0)
            ).alias('revenue_amount'),
        ])
    )

    id_cols = [
        'cusip',
        'issue_id',
        'issuer_match_key',
        'amount',
        'go_any',
        'revenue_bond',
        'go_or_revenue_amount',
        'revenue_amount',
    ]

    cusip_category = (
        outstanding
        .select(id_cols + category_cols)
        .unpivot(
            index=id_cols,
            on=category_cols,
            variable_name='purpose_category',
            value_name='has_purpose_category',
        )
        .filter(pl.col('has_purpose_category').eq(1))
        .drop('has_purpose_category')
        .join(category_dictionary, on='purpose_category', how='left')
    )

    issuer_denominator = (
        outstanding
        .group_by('issuer_match_key')
        .agg([
            pl.col('go_or_revenue_amount').sum().alias('total_go_or_revenue_amount'),
            pl.col('cusip')
            .filter((pl.col('go_any').eq(1)) | (pl.col('revenue_bond').eq(1)))
            .n_unique()
            .alias('total_go_or_revenue_bonds'),
        ])
        .filter(pl.col('total_go_or_revenue_amount') > 0)
    )

    issuer_category_amount = (
        cusip_category
        .group_by(['issuer_match_key', 'purpose_category'])
        .agg([
            pl.col('go_or_revenue_amount').sum().alias('category_amount'),
            pl.col('go_or_revenue_amount').sum().alias('go_or_revenue_category_amount'),
            pl.col('revenue_amount').sum().alias('revenue_category_amount'),
            pl.col('cusip').n_unique().alias('category_bonds'),
            pl.col('issue_id').n_unique().alias('category_issues'),
            pl.col('cusip')
            .filter((pl.col('go_any').eq(1)) | (pl.col('revenue_bond').eq(1)))
            .n_unique()
            .alias('go_or_revenue_category_bonds'),
            pl.col('cusip')
            .filter(pl.col('revenue_bond').eq(1))
            .n_unique()
            .alias('revenue_category_bonds'),
        ])
    )

    issuer_category_grid = pl.DataFrame({
        'issuer_match_key': issuer_denominator['issuer_match_key'].to_list()
    }).join(
        pl.DataFrame({'purpose_category': category_cols}),
        how='cross',
    )

    issuer_category = (
        issuer_category_grid
        .join(
            issuer_category_amount,
            on=['issuer_match_key', 'purpose_category'],
            how='left',
        )
        .with_columns([
            pl.col('category_amount').fill_null(0),
            pl.col('go_or_revenue_category_amount').fill_null(0),
            pl.col('revenue_category_amount').fill_null(0),
            pl.col('category_bonds').fill_null(0),
            pl.col('category_issues').fill_null(0),
            pl.col('go_or_revenue_category_bonds').fill_null(0),
            pl.col('revenue_category_bonds').fill_null(0),
        ])
        .join(issuer_denominator, on='issuer_match_key', how='left')
        .join(category_dictionary, on='purpose_category', how='left')
        .with_columns([
            (pl.col('category_amount') / pl.col('total_go_or_revenue_amount'))
            .alias('category_amount_share_of_go_or_revenue'),
            pl.when(pl.col('go_or_revenue_category_amount') > 0)
            .then(pl.col('revenue_category_amount') / pl.col('go_or_revenue_category_amount'))
            .otherwise(None)
            .alias('share_revenue_vs_go_amount'),
            pl.when(pl.col('go_or_revenue_category_bonds') > 0)
            .then(pl.col('revenue_category_bonds') / pl.col('go_or_revenue_category_bonds'))
            .otherwise(None)
            .alias('share_revenue_vs_go_bonds'),
            pl.lit(year).alias('year'),
        ])
        .join(cross_section, on='issuer_match_key', how='left', suffix='_cs')
    )

    column_order = [
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
        'ln_gdp',
        'ln_census_population',
        'ln_pers_inc',
        'ln_1p_census_total_debt',
        'ln_1p_county_nonmunicipal_total_debt',
        'glm_proactive',
        'high_state_tax_privilege',
        'mergent_go_revenue_bonds_outstanding',
        'purpose_category',
        'purpose_category_label',
        'revenue_feasible',
        'category_amount_share_of_go_or_revenue',
        'share_revenue_vs_go_amount',
        'share_revenue_vs_go_bonds',
        'category_amount',
        'go_or_revenue_category_amount',
        'revenue_category_amount',
        'total_go_or_revenue_amount',
        'category_bonds',
        'category_issues',
        'go_or_revenue_category_bonds',
        'revenue_category_bonds',
        'total_go_or_revenue_bonds',
    ]

    issuer_category = issuer_category.select([
        col for col in column_order if col in issuer_category.columns
    ])

    category_output = Path(str(category_output_template).format(year=year))
    issuer_category.write_csv(category_output)

    wide_base = (
        issuer_category
        .select([
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
            'ln_gdp',
            'ln_census_population',
            'ln_pers_inc',
            'ln_1p_census_total_debt',
            'ln_1p_county_nonmunicipal_total_debt',
            'glm_proactive',
            'high_state_tax_privilege',
            'mergent_go_revenue_bonds_outstanding',
        ])
        .unique(subset=['issuer_match_key'])
    )

    wide_components = [wide_base]
    for value_col in [
        'category_amount_share_of_go_or_revenue',
        'share_revenue_vs_go_amount',
        'share_revenue_vs_go_bonds',
        'category_amount',
        'go_or_revenue_category_amount',
        'revenue_category_amount',
        'category_bonds',
        'category_issues',
    ]:
        wide_component = (
            issuer_category
            .select(['issuer_match_key', 'purpose_category', value_col])
            .pivot(
                values=value_col,
                index='issuer_match_key',
                on='purpose_category',
                aggregate_function='first',
            )
            .rename({
                category: f'{value_col}_{category}'
                for category in category_cols
                if category in issuer_category['purpose_category'].unique().to_list()
            })
        )
        wide_components.append(wide_component)

    issuer_wide = wide_components[0]
    for wide_component in wide_components[1:]:
        issuer_wide = issuer_wide.join(
            wide_component,
            on='issuer_match_key',
            how='left',
        )

    wide_output = Path(str(wide_output_template).format(year=year))
    issuer_wide.write_csv(wide_output)

    print(f'Wrote {category_output}')
    print(f'Wrote {wide_output}')

print(f'Wrote {category_dictionary_output}')
