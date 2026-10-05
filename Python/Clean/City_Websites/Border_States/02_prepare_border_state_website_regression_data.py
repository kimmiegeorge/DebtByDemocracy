"""Prepare the border-state website sample for R/Clean/01_websites.R."""
#%% Paths and sample configuration
import os
from pathlib import Path
import pandas as pd
import polars as pl

code_dir = Path(__file__).resolve().parents[4]
data_dir = code_dir.parent / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
output_file = Path(os.getenv(
    'WEBSITE_REGRESSION_DATA',
    str(clean_data_dir / 'Websites' / 'border_state_website_regression_data.csv')
)).expanduser()

border_pair_config = pl.read_csv(code_dir / 'Config/border_state_pairs.csv')
paper_pair_config = border_pair_config.filter(pl.col('include_in_paper') == 1)
paper_border_pairs = paper_pair_config.get_column('group').to_list()

#%% Retain the same city-year sample used in the website regressions.
data = pl.read_csv(
    clean_data_dir / 'Websites/border_state_website_data_with_recovered.csv',
    infer_schema_length=10000
).filter(
    pl.col('group').is_in(paper_border_pairs),
    pl.col('total_subs') == 50,
    pl.col('city_go_vote').is_not_null(),
    pl.col('seed_issuer') != 'BONDUEL WIS'
)
if data.is_empty():
    raise ValueError('The website regression sample is empty.')

# Use the shared composite issuer key because numeric seed IDs are reused.
data = data.with_columns(
    pl.col('year').cast(pl.Int64).alias('year_int'),
    pl.concat_str([
        (pl.col('seed_issuer_id').cast(pl.Float64) * 10).round(0)
        .cast(pl.Int64).cast(pl.String),
        pl.col('state').str.strip_chars().str.to_uppercase(),
        pl.col('seed_issuer').str.strip_chars().str.replace_all(r'\s+', ' ').str.to_uppercase(),
    ], separator='|').alias('issuer_key'),
    pl.concat_str(['state', 'year'], separator='.').alias('state_year')
)

#%% Merge debt outstanding at the end of the preceding calendar year.
debt_panel = pl.read_csv(
    clean_data_dir / 'Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv',
    columns=['issuer_key', 'year', 'total_outstanding_debt', 'ln_1p_total_outstanding_debt']
).with_columns(
    (pl.col('year').cast(pl.Int64) + 1).alias('year_int')
).drop('year').rename({
    'total_outstanding_debt': 'total_outstanding_debt_lag1',
    'ln_1p_total_outstanding_debt': 'ln_1p_outstanding_debt_lag1',
})
if debt_panel.select(['issuer_key', 'year_int']).is_duplicated().any():
    raise ValueError('The shared outstanding-debt panel has duplicate issuer-year keys.')
data = data.join(debt_panel, on=['issuer_key', 'year_int'], how='left', validate='m:1')
if data.get_column('ln_1p_outstanding_debt_lag1').null_count() > 0:
    raise ValueError('The shared outstanding-debt panel is missing website issuer-years.')

#%% Merge state fiscal-monitoring adoption years; pre-sample adoption is 2009.
state_policy = pl.read_csv(
    data_dir / 'State Monitoring Policy/state_enforcement_adoption_years.csv'
).rename({'Abbreviation': 'state'}).with_columns(
    pl.col('AdoptionYear').replace('before_sample', '2009').cast(pl.Int64)
)
data = data.join(state_policy, on='state', how='left', validate='m:1').with_columns(
    (pl.col('year_int') >= pl.col('AdoptionYear')).fill_null(False)
    .cast(pl.Int64).alias('state_monitor')
)

#%% Cap counts at observed order statistics, matching R quantile(type = 1).
# Polars' equiprobable interpolation implements the inverse empirical CDF.
# Compute caps over the complete regression sample.
website_count_variables = [
    'fiscal_url', 'fiscal_count', 'bond_url', 'bond_count', 'financial_pdf_urls'
]
for variable in website_count_variables:
    counts = data.get_column(variable).drop_nulls()
    if counts.is_empty():
        raise ValueError(f'No observed values for {variable}.')
    lower_cap = counts.quantile(0.01, interpolation='equiprobable')
    upper_cap = counts.quantile(0.99, interpolation='equiprobable')
    data = data.with_columns(pl.col(variable).clip(lower_cap, upper_cap))

#%% Identify complete pairs for the revenue-vote robustness regression.
# Pandas only reads Stata; all tabular transformations use Polars.
state_election_rules = pl.from_pandas(pd.read_stata(
    data_dir / 'Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta',
    columns=['state', 'city_go_vote', 'city_rev_vote'],
    convert_categoricals=False
)).unique()
treated_pair_rules = paper_pair_config.select(
    'group', pl.col('state1').alias('state')
).join(state_election_rules, on='state', how='left', validate='m:1')
if treated_pair_rules.filter(
    pl.col('city_go_vote').is_null() & pl.col('city_rev_vote').is_null()
).height > 0:
    raise ValueError('A treated state is missing from the election-requirements file.')
drop_dark_green_groups = treated_pair_rules.filter(
    (pl.col('city_go_vote') == 1) & (pl.col('city_rev_vote') == 0)
).get_column('group').to_list()

# Preserve the current interaction's definition from the canonical pair config.
dark_green_groups = paper_pair_config.filter(
    pl.col('include_debt_yield') == 0
).get_column('group').to_list()
data = data.with_columns(
    pl.col('group').is_in(drop_dark_green_groups).cast(pl.Int64)
    .alias('keep_drop_dark_green'),
    (pl.col('group').is_in(dark_green_groups) & (pl.col('city_go_vote') == 1))
    .cast(pl.Int64).alias('dark_green')
)

#%% Add the full state-level policy comparison for prospective controls.
# Retain original names, source text, and missing values. Dated policy measures
# and GFOA period averages are repeated across years, not historical panels.
state_comparison = pl.read_csv(
    data_dir / 'State Policies/20260929_state_policy_comparison.csv',
    infer_schema_length=10000
).rename({'state_abbr': 'state'})
if (state_comparison.height != 50
        or state_comparison.get_column('state').null_count() > 0
        or state_comparison.get_column('state').n_unique() != 50):
    raise ValueError('The state-policy comparison must contain one row for each of the 50 states.')
policy_columns = [column for column in state_comparison.columns if column != 'state']
policy_collisions = set(policy_columns).intersection(data.columns)
if policy_collisions:
    raise ValueError(f'State-policy columns already exist in website data: {sorted(policy_collisions)}')
missing_policy_states = data.select('state').unique().join(
    state_comparison.select('state'), on='state', how='anti'
)
if missing_policy_states.height > 0:
    raise ValueError(f'Website states are missing from the policy comparison: {missing_policy_states}')
data = data.join(state_comparison, on='state', how='left', validate='m:1')

#%% Save the regression-ready sample without changing the step-01 intermediate.
output_file.parent.mkdir(parents=True, exist_ok=True)
data.write_csv(output_file)
print(f'Saved {data.height:,} rows and {data.width} columns to {output_file}')
