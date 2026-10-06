"""Prepare full and border-state RavenPack data for R/Clean/02_media_coverage.R."""
#%% Paths and sample configuration
import os
import re
from pathlib import Path

import polars as pl
import pyreadstat

code_dir = Path(__file__).resolve().parents[3]
data_dir = code_dir.parent / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
output_dir = Path(os.getenv(
    'MEDIA_REGRESSION_DIR', str(clean_data_dir / 'News')
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)

border_pair_config = pl.read_csv(code_dir / 'Config/border_state_pairs.csv')
paper_pair_config = border_pair_config.filter(pl.col('include_in_paper') == 1)
paper_border_pairs = paper_pair_config.get_column('group').to_list()
supermajority_text = (code_dir / 'R/Clean/00_state_policy_definitions.R').read_text()
supermajority_states = re.findall(r"'([A-Z]{2})'", supermajority_text)

#%% Issuer metadata and election requirements from the full Mergent bond file
# pyreadstat only decodes Stata; all tabular transformations use Polars.
bond_raw, _ = pyreadstat.read_dta(
    data_dir / 'Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta',
    usecols=['seed_issuer_id', 'fips', 'issuer_long_name',
             'state', 'city_go_vote', 'city_rev_vote'],
    output_format='dict'
)
full_data = pl.DataFrame(bond_raw)
# Preserve R's first observed metadata, including a missing first value.
issuers = full_data.group_by('seed_issuer_id', maintain_order=True).agg(
    pl.col('fips').first(), pl.col('issuer_long_name').first()
)

#%% Load full and border-state issuance coverage
issuance_lvl = pl.read_csv(
    clean_data_dir / 'News/Issuance_Lvl_News_With_Lagged_News.csv',
    infer_schema_length=10000, null_values=['NA', 'NaN']
).rename({'fips': 'i.fips'})
# R's issuers[issuance_lvl] keeps every news row and names its original FIPS
# i.fips. Keep the same column names and row order for inspection and lags.
news_columns = issuance_lvl.columns
issuance_lvl = issuance_lvl.join(
    issuers, on='seed_issuer_id', how='left', validate='m:1',
    nulls_equal=True, maintain_order='left'
).select('seed_issuer_id', 'fips', 'issuer_long_name',
         *[column for column in news_columns if column != 'seed_issuer_id']).filter(
    pl.col('city_go_vote').is_not_null(), pl.col('ln_employment').is_not_null()
).with_columns(
    pl.col('state').is_in(supermajority_states).fill_null(False)
    .cast(pl.Int64).alias('super_majority')
)
border_articles = pl.read_csv(
    clean_data_dir / 'Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv',
    infer_schema_length=10000, null_values=['NA', 'NaN']
).filter(pl.col('ln_employment').is_not_null())
if issuance_lvl.is_empty() or border_articles.is_empty():
    raise ValueError('A media analysis sample is empty.')

#%% Prior issuance within 12 months, computed independently in each sample
# As in R, compute lags BEFORE restricting paper border pairs. Duplicate
# issuer-months remain separate rows and may have a zero-month difference.
issuance_lvl = issuance_lvl.sort(
    'seed_issuer_id', 'issuance_year_month_id', nulls_last=False,
    maintain_order=True
).with_columns(
    pl.col('issuance_year_month_id').shift(1).over('seed_issuer_id').alias('lag_issuance_ym_id')
).with_columns(
    (pl.col('issuance_year_month_id') - pl.col('lag_issuance_ym_id')).alias('diff')
).with_columns(
    (pl.col('diff') <= 12).fill_null(False).cast(pl.Int64).alias('bond_prior_12')
)
border_articles = border_articles.sort(
    'seed_issuer_id', 'issuance_year_month_id', nulls_last=False,
    maintain_order=True
).with_columns(
    pl.col('issuance_year_month_id').shift(1).over('seed_issuer_id').alias('lag_issuance_ym_id')
).with_columns(
    (pl.col('issuance_year_month_id') - pl.col('lag_issuance_ym_id')).alias('diff')
).with_columns(
    (pl.col('diff') <= 12).fill_null(False).cast(pl.Int64).alias('bond_prior_12')
).filter(pl.col('group').is_in(paper_border_pairs)).with_columns(
    pl.concat_str('state', pl.col('year').cast(pl.String), separator='.').alias('state_year')
)

#%% Logged source count and shared empirical winsorization caps
issuance_lvl = issuance_lvl.with_columns(pl.col('unique_sources_12').log1p().alias('log_sources'))
border_articles = border_articles.with_columns(pl.col('unique_sources_12').log1p().alias('log_sources'))
# Match R quantile(type = 1): estimate caps in the full UTGO/positive-background
# coverage sample and apply the same caps to both prepared dataframes.
cap_sample = issuance_lvl.filter(
    pl.col('go_unlim_bond_issuance') == 1,
    pl.col('rolling_sum_monthly_article_count_12') > 0
).get_column('total_rp_articles_12_0')
if cap_sample.is_empty() or cap_sample.null_count():
    raise ValueError('Media percentile sample is empty or contains missing outcomes.')
lower_cap = cap_sample.quantile(0.01, interpolation='equiprobable')
upper_cap = cap_sample.quantile(0.99, interpolation='equiprobable')
issuance_lvl = issuance_lvl.with_columns(
    pl.col('total_rp_articles_12_0').clip(lower_cap, upper_cap).alias('total_articles_12_0_win')
)
border_articles = border_articles.with_columns(
    pl.col('total_rp_articles_12_0').clip(lower_cap, upper_cap).alias('total_articles_12_0_win')
)

#%% Revenue-vote missing-value convention and robustness-sample indicators
# These fields were previously prepared after the descriptives in R. Moving
# them here also removes the later dependency on the raw Mergent bond file.
issuance_lvl = issuance_lvl.with_columns(pl.col('city_rev_vote').fill_null(1)).with_columns(
    ((pl.col('city_go_vote') == 1) & (pl.col('city_rev_vote') == 1))
    .cast(pl.Int64).alias('dark_green')
)
border_articles = border_articles.with_columns(pl.col('city_rev_vote').fill_null(1))
state_election_rules = full_data.select('state', 'city_go_vote', 'city_rev_vote').unique()
treated_pair_rules = paper_pair_config.select(
    'group', pl.col('state1').alias('state')
).join(state_election_rules, on='state', how='left', validate='m:1')
if treated_pair_rules.filter(
    pl.col('city_go_vote').is_null() & pl.col('city_rev_vote').is_null()
).height:
    raise ValueError('A treated state is missing from the Mergent election-requirements data.')
drop_dark_green_groups = treated_pair_rules.filter(
    (pl.col('city_go_vote') == 1) & (pl.col('city_rev_vote') == 0)
).get_column('group').to_list()
border_articles = border_articles.with_columns(
    pl.col('group').is_in(drop_dark_green_groups).cast(pl.Int64).alias('keep_drop_dark_green')
)

#%% Save analysis data without changing the step-05 or border intermediates
issuance_lvl.write_csv(output_dir / 'media_full_sample_regression_data.csv')
border_articles.write_csv(output_dir / 'media_border_state_regression_data.csv')
pl.DataFrame({
    'full_sample_rows': [issuance_lvl.height],
    'border_sample_rows': [border_articles.height],
    'restricted_border_rows': [border_articles.filter(pl.col('keep_drop_dark_green') == 1).height],
    'article_cap_sample_rows': [len(cap_sample)],
    'article_cap_p1': [lower_cap], 'article_cap_p99': [upper_cap]
}).write_csv(output_dir / 'media_regression_data_diagnostics.csv')
print(f'Wrote {issuance_lvl.height:,} full-sample rows and {border_articles.height:,} border-state rows to {output_dir}')
print(f'Shared article caps: {lower_cap:g}, {upper_cap:g}')
