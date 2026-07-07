'''
Build Purpose-Category Panels

This script creates bond-, issue-, and issuer-level purpose-category panels for
testing whether cities in vote-requiring states substitute toward revenue bonds
in project categories where revenue financing is more plausible.
'''

# SET DATE FOR OUTPUT FILES
output_date = '260707'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
from pathlib import Path

import pandas as pd
import polars as pl


project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
data_dir = project_dir / 'Data'

dpc_uop_dir = data_dir / 'DPC Data' / 'Use Of Proceeds'
output_dir = dpc_uop_dir / 'Purposes Substitution'
output_dir.mkdir(parents=True, exist_ok=True)

merged_bond_input = dpc_uop_dir / '260622_dpc_use_proceeds_merged_debt_choice_bonds.csv'
issuer_input = data_dir / 'Mergent' / 'Clean' / '260611_city_issuerlevel_yieldspread.dta'

cusip_category_output = output_dir / f'{output_date}_dpc_purpose_substitution_cusip_category_panel.csv'
issue_category_output = output_dir / f'{output_date}_dpc_purpose_substitution_issue_category_panel.csv'
issuer_category_output = output_dir / f'{output_date}_dpc_purpose_substitution_issuer_category_panel.csv'
issuer_category_wide_output = output_dir / f'{output_date}_dpc_purpose_substitution_issuer_category_wide.csv'
category_dictionary_output = output_dir / f'{output_date}_dpc_purpose_substitution_category_dictionary.csv'


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Category definitions
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# These are collapsed, non-exclusive categories. A bond can enter multiple
# category rows if its DPC labels indicate multiple project types.
category_defs = {
    'education': {
        'label': 'Education',
        'raw_vars': ['educ'],
        'revenue_feasible': 0,
    },
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
    'economic_development': {
        'label': 'Economic development',
        'raw_vars': ['econdev'],
        'revenue_feasible': 1,
    },
    'other_public_buildings': {
        'label': 'Other public buildings',
        'raw_vars': ['otherpubbldg'],
        'revenue_feasible': 0,
    },
    'other': {
        'label': 'Other',
        'raw_vars': ['other'],
        'revenue_feasible': 0,
    },
}

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


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load DPC-Mergent merged bond file
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
print('Loading DPC-Mergent merged bond file...')

bond = pl.read_csv(
    merged_bond_input,
    infer_schema_length=10000,
    try_parse_dates=True
)

print(f'Input bonds: {bond.shape}')

raw_purpose_vars = sorted({
    raw_var
    for category in category_defs.values()
    for raw_var in category['raw_vars']
})

for col in raw_purpose_vars + ['dpc_match', 'go_unlim', 'go_lim', 'rev', 'sample_allgo', 'sample_utgo_only']:
    if col in bond.columns:
        bond = bond.with_columns(pl.col(col).fill_null(0).cast(pl.Int64))

bond = bond.with_columns(pl.col('seed_issuer_id').cast(pl.Int64))
if 'security_code' not in bond.columns:
    security_code_input = data_dir / 'Mergent' / 'Clean' / '260610_city_cusiplevel_statereq_purpose_yieldspread.dta'
    security_code = pl.DataFrame(pd.read_stata(security_code_input, columns=['cusip', 'security_code', 'source_of_repayment']))
    bond = bond.join(security_code, on='cusip', how='left')
elif 'source_of_repayment' not in bond.columns:
    source_input = data_dir / 'Mergent' / 'Clean' / '260610_city_cusiplevel_statereq_purpose_yieldspread.dta'
    source = pl.DataFrame(pd.read_stata(source_input, columns=['cusip', 'source_of_repayment']))
    bond = bond.join(source, on='cusip', how='left')


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create collapsed category indicators
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
for category, spec in category_defs.items():
    raw_exprs = [pl.col(raw_var).eq(1) for raw_var in spec['raw_vars']]
    category_expr = raw_exprs[0]
    for expr in raw_exprs[1:]:
        category_expr = category_expr | expr
    bond = bond.with_columns(category_expr.cast(pl.Int64).alias(category))

bond = (
    bond
    .with_columns(
        (pl.col('go_unlim').eq(1) | pl.col('go_lim').eq(1)).cast(pl.Int64).alias('go_any'),
        pl.col('rev').eq(1).cast(pl.Int64).alias('revenue_bond'),
        (pl.col('rev').eq(1) & pl.col('security_code').eq('G')).cast(pl.Int64).alias('revenue_bond_security_g'),
        (
            pl.col('rev').eq(1) &
            pl.col('security_code').eq('G') &
            pl.col('source_of_repayment').eq('G')
        ).cast(pl.Int64).alias('revenue_bond_security_g_source_g'),
        pl.when(pl.col('vote_group').eq('No vote')).then(0)
        .when(pl.col('vote_group').is_in(['GO vote', 'UTGO-only vote'])).then(1)
        .otherwise(None)
        .cast(pl.Int64)
        .alias('vote_required'),
        pl.when(pl.col('vote_group').eq('GO vote')).then(1).otherwise(0).cast(pl.Int64).alias('go_vote_group'),
        pl.when(pl.col('vote_group').eq('UTGO-only vote')).then(1).otherwise(0).cast(pl.Int64).alias('utgo_only_vote_group'),
    )
    .filter(pl.col('dpc_match').eq(1))
    .filter(pl.col('vote_required').is_not_null())
)

print(f'DPC matched debt-choice-sample bonds: {bond.shape}')


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Merge issuer-level controls from debt-choice regression sample
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
print('Loading issuer-level controls...')

issuer_cols = [
    'seed_issuer_id',
    'fips',
    'state',
    'city_go_vote',
    'city_rev_vote',
    'state_go_vote',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'ln_county_debt_other',
    'glm_proactive',
    'insample',
    'insample_allgo',
    'insample_utgo_only',
]

issuer = pl.DataFrame(pd.read_stata(issuer_input, columns=issuer_cols))
issuer = (
    issuer
    .with_columns(
        pl.col('seed_issuer_id').cast(pl.Int64),
        pl.when(pl.col('state').eq('MO')).then(1).otherwise(pl.col('city_rev_vote')).alias('city_rev_vote'),
        pl.when(pl.col('state').eq('RI')).then(None).otherwise(pl.col('city_go_vote')).alias('city_go_vote'),
    )
    .filter(pl.col('city_go_vote').is_not_null())
    .filter(pl.col('ln_pop').is_not_null())
    .filter(pl.col('ln_county_debt_other').is_not_null())
    .filter(pl.col('insample').eq(1))
    .unique(subset=['seed_issuer_id'])
)

high_state_tax_privilege_states = [
    'CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN', 'NC',
    'ID', 'NY', 'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE'
]

issuer = issuer.with_columns(
    pl.col('state').is_in(high_state_tax_privilege_states).cast(pl.Int64).alias('high_state_tax_privilege')
)

bond = bond.join(
    issuer.drop(['state', 'city_go_vote', 'city_rev_vote']),
    on='seed_issuer_id',
    how='left'
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Stack to CUSIP-category panel
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
category_cols = list(category_defs.keys())

id_cols = [
    'cusip',
    'state',
    'seed_issuer',
    'seed_issuer_id',
    'year',
    'issue_id',
    'offering_date',
    'amount',
    'vote_group',
    'vote_required',
    'go_vote_group',
    'utgo_only_vote_group',
    'go_any',
    'go_unlim',
    'go_lim',
    'revenue_bond',
    'revenue_bond_security_g',
    'revenue_bond_security_g_source_g',
    'security_code',
    'source_of_repayment',
    'fips',
    'state_go_vote',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'ln_county_debt_other',
    'glm_proactive',
    'high_state_tax_privilege',
]

cusip_category = (
    bond
    .select(id_cols + category_cols)
    .melt(
        id_vars=id_cols,
        value_vars=category_cols,
        variable_name='purpose_category',
        value_name='has_purpose_category'
    )
    .filter(pl.col('has_purpose_category').eq(1))
    .drop('has_purpose_category')
    .join(category_dictionary, on='purpose_category', how='left')
    .with_columns(
        (pl.col('vote_required') * pl.col('revenue_feasible')).alias('vote_x_revenue_feasible')
    )
)

print(f'CUSIP-category panel: {cusip_category.shape}')
cusip_category.write_csv(cusip_category_output)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create issue-category panel
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# CUSIPs within an issue usually share debt type and purpose. This issue-level
# panel prevents large serial maturities from mechanically dominating results.
issue_group_cols = [
    'issue_id',
    'purpose_category',
    'purpose_category_label',
    'revenue_feasible',
    'state',
    'seed_issuer',
    'seed_issuer_id',
    'year',
    'vote_group',
    'vote_required',
    'go_vote_group',
    'utgo_only_vote_group',
    'fips',
    'state_go_vote',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'ln_county_debt_other',
    'glm_proactive',
    'high_state_tax_privilege',
]

issue_category = (
    cusip_category
    .group_by(issue_group_cols)
    .agg(
        pl.len().alias('n_cusips'),
        pl.col('cusip').n_unique().alias('n_unique_cusips'),
        pl.col('amount').sum().alias('issue_category_amount'),
        pl.col('revenue_bond').mean().alias('revenue_cusip_share'),
        pl.col('revenue_bond_security_g').mean().alias('revenue_security_g_cusip_share'),
        pl.col('revenue_bond_security_g_source_g').mean().alias('revenue_security_g_source_g_cusip_share'),
        pl.col('revenue_bond').max().alias('any_revenue_cusip'),
        pl.col('revenue_bond_security_g').max().alias('any_revenue_security_g_cusip'),
        pl.col('revenue_bond_security_g_source_g').max().alias('any_revenue_security_g_source_g_cusip'),
        pl.col('go_any').max().alias('any_go_cusip'),
        pl.col('go_unlim').max().alias('any_utgo_cusip'),
        pl.col('go_lim').max().alias('any_ltgo_cusip'),
    )
    .with_columns(
        # Primary outcome for issue-level LPMs. This should normally equal
        # revenue_cusip_share because debt type is usually constant within issue.
        pl.col('any_revenue_cusip').alias('revenue_issue'),
        pl.col('any_revenue_security_g_cusip').alias('revenue_issue_security_g'),
        pl.col('any_revenue_security_g_source_g_cusip').alias('revenue_issue_security_g_source_g'),
        (pl.col('vote_required') * pl.col('revenue_feasible')).alias('vote_x_revenue_feasible')
    )
)

print(f'Issue-category panel: {issue_category.shape}')
issue_category.write_csv(issue_category_output)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create issuer-category panel
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# This aggregates to the issuer x purpose-category level. The revenue share
# outcomes are defined among bonds/issues in that category; issuer-category
# cells with no issuance in a category are therefore absent from the long panel.
issuer_group_cols = [
    'purpose_category',
    'purpose_category_label',
    'revenue_feasible',
    'state',
    'seed_issuer',
    'seed_issuer_id',
    'vote_group',
    'vote_required',
    'go_vote_group',
    'utgo_only_vote_group',
    'fips',
    'state_go_vote',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'ln_county_debt_other',
    'glm_proactive',
    'high_state_tax_privilege',
]

issuer_category = (
    cusip_category
    .with_columns(
        (pl.col('amount') * pl.col('revenue_bond')).alias('revenue_bond_amount'),
        (pl.col('amount') * pl.col('revenue_bond_security_g')).alias('revenue_security_g_bond_amount'),
        (pl.col('amount') * pl.col('revenue_bond_security_g_source_g')).alias('revenue_security_g_source_g_bond_amount'),
        (pl.col('go_any').eq(1) | pl.col('revenue_bond_security_g_source_g').eq(1)).cast(pl.Int64).alias('go_or_revenue_security_g_source_g'),
        (
            pl.when(pl.col('go_any').eq(1) | pl.col('revenue_bond_security_g_source_g').eq(1))
            .then(pl.col('amount'))
            .otherwise(0)
        ).alias('go_or_revenue_security_g_source_g_amount')
    )
    .group_by(issuer_group_cols)
    .agg(
        pl.len().alias('n_cusip_category_rows'),
        pl.col('cusip').n_unique().alias('n_bonds'),
        pl.col('issue_id').n_unique().alias('n_issues'),
        pl.col('amount').sum().alias('total_category_amount'),
        pl.col('revenue_bond').sum().alias('n_revenue_bonds'),
        pl.col('revenue_bond_security_g').sum().alias('n_revenue_security_g_bonds'),
        pl.col('revenue_bond_security_g_source_g').sum().alias('n_revenue_security_g_source_g_bonds'),
        pl.col('go_or_revenue_security_g_source_g').sum().alias('n_go_or_revenue_security_g_source_g_bonds'),
        pl.col('revenue_bond_amount').sum().alias('revenue_category_amount'),
        pl.col('revenue_security_g_bond_amount').sum().alias('revenue_security_g_category_amount'),
        pl.col('revenue_security_g_source_g_bond_amount').sum().alias('revenue_security_g_source_g_category_amount'),
        pl.col('go_or_revenue_security_g_source_g_amount').sum().alias('go_or_revenue_security_g_source_g_amount'),
    )
    .with_columns(
        (pl.col('n_revenue_bonds') / pl.col('n_bonds')).alias('share_revenue_bonds'),
        (pl.col('n_revenue_security_g_bonds') / pl.col('n_bonds')).alias('share_revenue_security_g_bonds'),
        (pl.col('n_revenue_security_g_source_g_bonds') / pl.col('n_bonds')).alias('share_revenue_security_g_source_g_bonds'),
        pl.when(pl.col('n_go_or_revenue_security_g_source_g_bonds').gt(0))
        .then(pl.col('n_revenue_security_g_source_g_bonds') / pl.col('n_go_or_revenue_security_g_source_g_bonds'))
        .otherwise(None)
        .alias('share_revenue_security_g_source_g_vs_go_bonds'),
        pl.when(pl.col('total_category_amount').gt(0))
        .then(pl.col('revenue_category_amount') / pl.col('total_category_amount'))
        .otherwise(None)
        .alias('share_revenue_amount'),
        pl.when(pl.col('total_category_amount').gt(0))
        .then(pl.col('revenue_security_g_category_amount') / pl.col('total_category_amount'))
        .otherwise(None)
        .alias('share_revenue_security_g_amount'),
        pl.when(pl.col('total_category_amount').gt(0))
        .then(pl.col('revenue_security_g_source_g_category_amount') / pl.col('total_category_amount'))
        .otherwise(None)
        .alias('share_revenue_security_g_source_g_amount'),
        pl.when(pl.col('go_or_revenue_security_g_source_g_amount').gt(0))
        .then(pl.col('revenue_security_g_source_g_category_amount') / pl.col('go_or_revenue_security_g_source_g_amount'))
        .otherwise(None)
        .alias('share_revenue_security_g_source_g_vs_go_amount'),
        (pl.col('vote_required') * pl.col('revenue_feasible')).alias('vote_x_revenue_feasible')
    )
)

print(f'Issuer-category panel: {issuer_category.shape}')
issuer_category.write_csv(issuer_category_output)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create issuer-level wide file with category outcomes
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# This file has one row per issuer and separate revenue-share outcomes for each
# category. It is convenient for specifications that treat categories as
# separate issuer-level outcomes.
issuer_id_cols = [
    'state',
    'seed_issuer',
    'seed_issuer_id',
    'vote_group',
    'vote_required',
    'go_vote_group',
    'utgo_only_vote_group',
    'fips',
    'state_go_vote',
    'state_ltgo_allowed',
    'ln_gdp',
    'ln_pop',
    'ln_pers_inc',
    'ln_county_debt_other',
    'glm_proactive',
    'high_state_tax_privilege',
]

issuer_base = issuer_category.select(issuer_id_cols).unique(subset=['seed_issuer_id'])

wide_components = [issuer_base]
for value_col in [
    'share_revenue_bonds',
    'share_revenue_amount',
    'share_revenue_security_g_bonds',
    'share_revenue_security_g_amount',
    'share_revenue_security_g_source_g_bonds',
    'share_revenue_security_g_source_g_amount',
    'share_revenue_security_g_source_g_vs_go_bonds',
    'share_revenue_security_g_source_g_vs_go_amount',
    'n_bonds',
    'n_issues',
    'total_category_amount',
    'n_go_or_revenue_security_g_source_g_bonds',
    'go_or_revenue_security_g_source_g_amount',
]:
    wide_component = (
        issuer_category
        .select(['seed_issuer_id', 'purpose_category', value_col])
        .pivot(
            values=value_col,
            index='seed_issuer_id',
            columns='purpose_category',
            aggregate_function='first'
        )
        .rename({
            category: f'{value_col}_{category}'
            for category in category_cols
            if category in issuer_category['purpose_category'].unique().to_list()
        })
    )
    wide_components.append(wide_component)

issuer_category_wide = wide_components[0]
for wide_component in wide_components[1:]:
    issuer_category_wide = issuer_category_wide.join(wide_component, on='seed_issuer_id', how='left')

print(f'Issuer-category wide panel: {issuer_category_wide.shape}')
issuer_category_wide.write_csv(issuer_category_wide_output)

print(f'Wrote {cusip_category_output}')
print(f'Wrote {issue_category_output}')
print(f'Wrote {issuer_category_output}')
print(f'Wrote {issuer_category_wide_output}')
print(f'Wrote {category_dictionary_output}')
