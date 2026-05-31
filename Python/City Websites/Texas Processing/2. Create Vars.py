'''
Create outcome variables pased on parsing
'''
# %%
import polars as pl
import os
from pathlib import Path
import pandas as pd

input_dir = os.path.expanduser(
    '/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Processed')
data_dir = '~/Dropbox/Voting on Bonds/Data'
output_date = '251209'
# %%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#load full election data including failed elections
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Load FULL Texas election data (includes failed elections)
print("Loading full TX election data including failed elections...")
full_election_data = pl.read_csv(f'{data_dir}/TX/20240510_TX_local_election.csv')

print(f"Full election data shape: {full_election_data.shape}")
print(f"Columns: {full_election_data.columns}")
print(f"Result distribution:")
print(full_election_data.select(pl.col('Result').value_counts()))

# Load the crosswalk to get seed_issuer mappings
crosswalk = pl.read_csv(f'{data_dir}/TX/241120_tx_uniquegovt_fuzzymatch_crosswalk.csv')
print(f"Crosswalk shape: {crosswalk.shape}")
print(f"Crosswalk columns: {crosswalk.columns}")

# Process full election data similar to Stata script
# CRITICAL FIX: Use lowercase governmentname matching like Stata does
election_data = (full_election_data
                # Create lowercase governmentname to exactly match Stata logic
                .with_columns(pl.col('GovernmentName').str.to_lowercase().alias('governmentname'))
                # Create step2-like crosswalk with lowercase governmentname (like Stata line 66)
                .join(crosswalk.with_columns(pl.col('muni_upper').str.to_lowercase().alias('governmentname'))
                        .select(['seed_issuer', 'governmentname']),
                      on='governmentname', how='inner')
                # Clean election date (using ElectionDate from CSV)
                .with_columns(pl.col('ElectionDate').str.strptime(pl.Date, format='%m/%d/%Y').alias('date_election'))
                .filter(pl.col('date_election').is_not_null())
                # Extract year/month and ensure Int64 type
                .with_columns(pl.col('date_election').dt.year().cast(pl.Int64).alias('year'),
                              pl.col('date_election').dt.month().cast(pl.Int64).alias('month'))
                # Keep elections from 1995-2024 (as in Stata script)
                .filter(pl.col('year').is_between(1995, 2024))
                # Drop elections that were cancelled
                .filter(pl.col('Result').is_in(['Carried', 'Defeated']))
                # Create passed/failed indicators
                .with_columns((pl.col('Result') == 'Carried').alias('passed'))
                .with_columns((pl.col('Result') == 'Defeated').alias('failed')))

print(f"Election data after processing: {election_data.shape}")
print(f"Elections by result:")
print(election_data.select(pl.col('Result').value_counts()))

# Clean voting data and create vote margin (using proper CSV column names)
election_data = (election_data
                .with_columns((pl.col('VotesFor') + pl.col('VotesAgainst')).alias('votestotal'))
                # Create vote margin (positive for wins, negative for losses)
                .with_columns(
                    pl.when(pl.col('Result') == 'Carried')
                    .then((pl.col('VotesFor') - pl.col('VotesAgainst')) / pl.col('votestotal'))
                    .when(pl.col('Result') == 'Defeated')
                    .then(-1 * (pl.col('VotesAgainst') - pl.col('VotesFor')) / pl.col('votestotal'))
                    .otherwise(None)
                    .alias('vote_margin'))
                # Create log amount (using Amount from CSV)
                .with_columns((pl.col('Amount') + 1).log().alias('ln_amount')))



# %%
# Load CSV files with schema normalization to avoid type conflicts
res_file_dfs = []
for f in Path(f'{input_dir}/res/').glob("*.csv"):
    try:
        df = pl.scan_csv(f).with_columns([
            pl.col('parent url').cast(pl.Utf8, strict = False),
            pl.col('URL').cast(pl.Utf8, strict = False),
            pl.col('original_url').cast(pl.Utf8, strict = False),
            pl.col('priority').cast(pl.Int64, strict = False)
        ]).select(['parent url', 'URL', 'original_url', 'priority'])
        res_file_dfs.append(df)
    except Exception as e:
        print(f"Warning: Could not load {f}: {e}")

res_files = (pl.concat(res_file_dfs, how = "diagonal")
             .collect(streaming = True)
             )

# get year
res_files = (res_files
             .with_columns(pl.col('parent url').str.slice(28, 4).alias('year')))

# count per url year
res_files = (res_files
             .with_columns(pl.col('URL').count().over(['parent url', 'year']).alias('total_subs')))

# search for bond
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase().str.contains('bond|debt').alias('bond_or_debt_url'),
                           pl.col('URL').str.to_lowercase().str.contains('bond').alias('bond_url'),
                           pl.col('URL').str.to_lowercase().str.contains('debt').alias('debt_url'),
                           pl.col('URL').str.to_lowercase().str.contains('tax').alias('tax_url'),
                           pl.col('URL').str.to_lowercase().str.contains('fiscal').alias('fiscal_url')))

res_files = (res_files
             .with_columns(pl.col('priority').fill_null(0)))
# check if contains any finance
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase()
                           .str.contains('bond|debt|finance|financial|credit|fiscal|capital|tax').alias(
    'all_finance_url')))

# aggregate
res_files_agg = (res_files
                 .group_by(['original_url', 'year'])
                 .agg(pl.col('total_subs').first(),
                      pl.col('bond_url').sum(),
                      pl.col('debt_url').sum(),
                      pl.col('tax_url').sum(),
                      pl.col('fiscal_url').sum(),
                      pl.col('bond_or_debt_url').sum(),
                      pl.col('all_finance_url').sum())
                 .with_columns(pl.col('bond_url').truediv(pl.col('total_subs')).alias('percent_bond_url'),
                               pl.col('debt_url').truediv(pl.col('total_subs')).alias('percent_debt_url'),
                               pl.col('bond_or_debt_url').truediv(pl.col('total_subs')).alias(
                                   'percent_bond_or_debt_url'),
                               pl.col('all_finance_url').truediv(pl.col('total_subs')).alias('percent_all_finance_url'),
                               pl.col('tax_url').truediv(pl.col('total_subs')).alias('percent_tax_url')))

# %% # now aggregate bow
# Load bow CSV files with schema normalization
bow_file_dfs = []
for f in Path(f'{input_dir}/bow/').glob("*.csv"):
    try:
        # First check what columns are available in this file
        temp_df = pl.scan_csv(f, n_rows = 1)
        available_cols = temp_df.collect_schema().names()

        # Skip files that don't have the required columns for bow analysis
        if not all(col in available_cols for col in ['url', 'word', 'count', 'original_url']):
            print(f"Skipping {f.name}: missing required columns. Has: {available_cols}")
            continue

        df = pl.scan_csv(f).with_columns([
            pl.col('url').cast(pl.Utf8, strict = False),
            pl.col('original_url').cast(pl.Utf8, strict = False),
            pl.col('word').cast(pl.Utf8, strict = False),
            pl.col('count').cast(pl.Int64, strict = False)
        ])
        bow_file_dfs.append(df)
    except Exception as e:
        print(f"Warning: Could not load bow file {f}: {e}")

if bow_file_dfs:
    bow_files = (pl.concat(bow_file_dfs, how = "diagonal")
                 .collect(streaming = True))
else:
    print("Warning: No valid bow files found!")
    # Create an empty dataframe with the expected schema
    bow_files = pl.DataFrame({
        'url': [],
        'word': [],
        'count': [],
        'original_url': []
    }, schema = {'url': pl.Utf8, 'word': pl.Utf8, 'count': pl.Int64, 'original_url': pl.Utf8})

bow_files = (bow_files
             .with_columns(pl.col('url').str.slice(28, 4).alias('year')))

bow_files = (bow_files
             .filter(pl.col('count').is_not_null())
             .filter(pl.col('original_url').ne('NA')))

bow_files = (bow_files
             .with_columns(pl.col('word').n_unique().over(['year', 'original_url']).alias('total_words'),
                           pl.col('count').sum().over(['year', 'original_url']).alias('total_count')))

# compute ranking of words within URL
bow_files = (bow_files
             .sort(['original_url', 'year', 'count'])
             .with_columns(pl.col('count').rank('dense').over(['year', 'original_url']).alias('word_rank'))
             .with_columns(pl.col('word_rank').max().over(['year', 'original_url']).alias('max_word_rank')))
# compute financi, bond, debt, fiscal, capital, credit
# financ
finance = (bow_files
           .filter(pl.col('word').eq(pl.lit('financ')))
           .rename({'count': 'finance_count'})
           .with_columns(pl.col('finance_count').truediv(pl.col('total_count')).alias('percent_finance'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_finance'))
           .select(['year', 'original_url', 'percent_finance', 'rank_percent_finance', 'finance_count']))

bond = (bow_files
        .filter(pl.col('word').eq(pl.lit('bond')))
        .rename({'count': 'bond_count'})
        .with_columns(pl.col('bond_count').truediv(pl.col('total_count')).alias('percent_bond'),
                      (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_bond'))
        .select(['year', 'original_url', 'percent_bond', 'rank_percent_bond', 'bond_count']))

debt = (bow_files
        .filter(pl.col('word').eq(pl.lit('debt')))
        .rename({'count': 'debt_count'})
        .with_columns(pl.col('debt_count').truediv(pl.col('total_count')).alias('percent_debt'),
                      (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_debt'))
        .select(['year', 'original_url', 'percent_debt', 'rank_percent_debt', 'debt_count']))

fiscal = (bow_files
          .filter(pl.col('word').eq(pl.lit('fiscal')))
          .rename({'count': 'fiscal_count'})
          .with_columns(pl.col('fiscal_count').truediv(pl.col('total_count')).alias('percent_fiscal'),
                        (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_fiscal'))
          .select(['year', 'original_url', 'percent_fiscal', 'rank_percent_fiscal', 'fiscal_count']))

tax = (bow_files
       .filter(pl.col('word').eq(pl.lit('tax')))
       .rename({'count': 'tax_count'})
       .with_columns(pl.col('tax_count').truediv(pl.col('total_count')).alias('percent_tax'),
                     (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_tax'))
       .select(['year', 'original_url', 'percent_tax', 'rank_percent_tax', 'tax_count']))

credit = (bow_files
          .filter(pl.col('word').eq(pl.lit('credit')))
          .rename({'count': 'credit_count'})
          .with_columns(pl.col('credit_count').truediv(pl.col('total_count')).alias('percent_credit'),
                        (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_credit'))
          .select(['year', 'original_url', 'percent_credit', 'rank_percent_credit', 'credit_count']))

capital = (bow_files
           .filter(pl.col('word').eq(pl.lit('capital')))
           .rename({'count': 'capital_count'})
           .with_columns(pl.col('capital_count').truediv(pl.col('total_count')).alias('percent_capital'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_capital'))
           .select(['year', 'original_url', 'percent_capital', 'rank_percent_capital', 'capital_count']))

budget = (bow_files
          .filter(pl.col('word').eq(pl.lit('budget')))
          .rename({'count': 'budget_count'})
          .with_columns(pl.col('budget_count').truediv(pl.col('total_count')).alias('percent_budget'),
                        (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_budget'))
          .select(['year', 'original_url', 'percent_budget', 'rank_percent_budget', 'budget_count']))

revenue = (bow_files
           .filter(pl.col('word').eq(pl.lit('revenue')))
           .rename({'count': 'revenue_count'})
           .with_columns(pl.col('revenue_count').truediv(pl.col('total_count')).alias('percent_revenue'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_revenue'))
           .select(['year', 'original_url', 'percent_revenue', 'rank_percent_revenue', 'revenue_count']))

expense = (bow_files
           .filter(pl.col('word').eq(pl.lit('expense')))
           .rename({'count': 'expense_count'})
           .with_columns(pl.col('expense_count').truediv(pl.col('total_count')).alias('percent_expense'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_expense'))
           .select(['year', 'original_url', 'percent_expense', 'rank_percent_expense', 'expense_count']))

# %% # merge bow with res
res_files_agg = (res_files_agg
                 .join(finance, on = ['original_url', 'year'], how = 'left')
                 .join(bond, on = ['year', 'original_url'], how = 'left')
                 .join(debt, on = ['year', 'original_url'], how = 'left')
                 .join(fiscal, on = ['year', 'original_url'], how = 'left')
                 .join(credit, on = ['year', 'original_url'], how = 'left')
                 .join(capital, on = ['year', 'original_url'], how = 'left')
                 .join(tax, on = ['year', 'original_url'], how = 'left')
                 .join(budget, on = ['year', 'original_url'], how = 'left')
                 .join(revenue, on = ['year', 'original_url'], how = 'left')
                 .join(expense, on = ['year', 'original_url'], how = 'left')
                 .fill_null(0)
                 .with_columns(pl.col('percent_finance').add(pl.col('percent_bond'))
                               .add(pl.col('percent_fiscal'))
                               .add(pl.col('percent_credit'))
                               .add(pl.col('percent_fiscal'))
                               .add(pl.col('percent_credit')).add(pl.col('percent_tax')).alias('percent_all_finance')))

# %% # merge with mergent data
sample_issuers = pl.read_csv('/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/City Website Collection.csv')
sample_issuers = sample_issuers.rename({'City Website': 'URL'})

# get one obs per year
year_list = [i for i in range(2000, 2021)]
obs = (sample_issuers.rename({'seed_issuer_id': 'GovernmentName'})
       .with_columns(year = year_list)
       .explode('year'))

# merge with res data
obs = (obs
       .rename({'URL': 'original_url'})
       .join(res_files_agg
             .with_columns(pl.col('year').cast(pl.Int64)), on = ['year', 'original_url'], how = 'left'))
# %%
# join with election indicators for time series observations
annual_election = (election_data
                   .with_columns(pl.col('ElectionDate').str.strptime(pl.Date, "%m/%d/%Y", strict=False).dt.year().alias('year'))
                   .select(['GovernmentName', 'year'])
                   .unique()
                   .with_columns(election = 1))

obs = (obs
       .join(annual_election.with_columns(pl.col('year').cast(pl.Int64)), on = ['GovernmentName', 'year'], how = 'left')
       .with_columns(pl.col('election').fill_null(0)))


seed_issuer = (election_data
               .select(['GovernmentName', 'seed_issuer'])
               .unique())

obs = (obs
       .join(seed_issuer, on = 'GovernmentName', how = 'left'))

# %%
# get aggregate number of bond issues for the city prior to the given year
mergent = pd.read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)
mergent = mergent.filter(pl.col("state").eq("TX"))

all_bonds = (mergent
            .filter(pl.col('seed_issuer').is_in(obs.select('seed_issuer')))
            #.filter(pl.col('go_unlim').eq(1))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            #.filter(pl.col('year').is_in(year_list))
           # .sort(['seed_issuer_id', 'issue_id', 'amount'])
            .group_by(['seed_issuer', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues_all'),
                 pl.col('issue_id').filter(pl.col('go_unlim').eq(1)).n_unique().alias('num_issues_unlim')))

# get cumulative issuances
all_bonds_obs_annual = (obs
              .select(['seed_issuer', 'year'])
              .unique()
              .join(all_bonds
                    .with_columns(pl.col('year').cast(pl.Int64)), on = ['seed_issuer', 'year'], how = 'left')
              .with_columns(pl.col('num_issues_all').fill_null(0),
                            pl.col('num_issues_unlim').fill_null(0))
              .sort(['seed_issuer', 'year'])
               .with_columns(pl.col('num_issues_all').cum_sum().over('seed_issuer').alias('cum_num_issues_all'),
                             pl.col('num_issues_unlim').cum_sum().over('seed_issuer').alias('cum_num_issues_unlim'))
                .with_columns(pl.col('cum_num_issues_all').sub(pl.col('num_issues_all')).alias('cum_num_issues_all'),
                              pl.col('cum_num_issues_unlim').sub(pl.col('num_issues_unlim')).alias('cum_num_issues_unlim')))


obs = (obs
       .join(all_bonds_obs_annual, on = ['seed_issuer', 'year'], how = 'left')
       .with_columns(pl.col('cum_num_issues_all').fill_null(0)))

# %%
# save
obs.write_csv(f'{data_dir}/Websites/Texas/time_series_website_data_{output_date}.csv')

# %%
# election level data

election_level = (election_data
                  .join(sample_issuers.rename({'seed_issuer_id': 'GovernmentName'}),
                        on = 'GovernmentName', how = 'inner')
                  .join(res_files_agg.rename({'original_url': 'URL'}).with_columns(pl.col('year').cast(pl.Int64)),
                        on = ['URL', 'year'], how = 'left')
                  .filter(pl.col('year').is_in(year_list)))

#%%
# merge with mergent purposes
mergent_purpose = (pl.read_csv(f'{data_dir}/TX/2025-03-24_texasbondpurpose_classify.csv')
                   .rename({'purposedescription':'PurposeDescription'})
                   .select(['purp_broad_new', 'PurposeDescription']))

election_level = (election_level
                  .join(mergent_purpose, on = 'PurposeDescription', how = 'left'))
#%%
# merge with demographic data
fips = (mergent
        .group_by(['seed_issuer', 'fips']).first())

election_level = (election_level
                  .join(fips, on = 'seed_issuer', how = 'left'))


election_level = (election_level
                  .with_columns(pl.when(pl.col('County').eq('El Paso'))
                                .then(pl.lit('48041'))
                                .otherwise(pl.when(pl.col('County').eq('Harris'))
                                           .then(pl.lit('48201'))
                                           .otherwise(pl.col('fips'))).alias('fips')))

# Load all demographic datasets
demo_files = {
    'employment': f'{data_dir}/BEA/employment_2001_2022.dta',
    'percap_inc': f'{data_dir}/BEA/percap_inc_2001_2022.dta',
    'pers_inc': f'{data_dir}/BEA/pers_inc_2001_2022.dta',
    'pop': f'{data_dir}/BEA/pop_2001_2022.dta',
    'gdp': f'{data_dir}/BEA/gdp_2001_2022.dta'
}

demo_data = {}
for name, file_path in demo_files.items():
    try:
        df = pl.DataFrame(pd.read_stata(file_path))
        # Convert FIPS to string for matching and ensure year is Int64
        df = df.with_columns(pl.col('fips').cast(pl.Utf8).str.zfill(5).alias('fips_str'),
                             pl.col('year').cast(pl.Int64))
        demo_data[name] = df
        print(f"Loaded {name}: {df.shape[0]} observations")
    except Exception as e:
        print(f"Error loading {name}: {e}")
        demo_data[name] = None

# Merge all demographic variables into single dataframe by FIPS and year
if all(v is not None for v in demo_data.values()):
    county_demographics = (demo_data['employment']
                           .select(['fips_str', 'year', 'geoname', 'employment'])
                           .join(demo_data['percap_inc'].select(['fips_str', 'year', 'percap_inc']),
                                 on = ['fips_str', 'year'], how = 'left')
                           .join(demo_data['pers_inc'].select(['fips_str', 'year', 'pers_inc']),
                                 on = ['fips_str', 'year'], how = 'left')
                           .join(demo_data['pop'].select(['fips_str', 'year', 'pop']),
                                 on = ['fips_str', 'year'], how = 'left')
                           .join(demo_data['gdp'].select(['fips_str', 'year', 'gdp']),
                                 on = ['fips_str', 'year'], how = 'left'))

    # Filter to Texas counties only (FIPS starting with 48)
    county_demographics = county_demographics.filter(pl.col('fips_str').str.starts_with('48'))

    print(f"Merged county demographics: {county_demographics.shape[0]} TX county-year observations")
    print(f"Years available: {sorted(county_demographics.select('year').unique().to_series().to_list())}")
    print(f"TX counties: {county_demographics.select('fips_str').n_unique()} unique counties")
else:
    print("Error: Could not load all demographic files")
    county_demographics = None

county_demographics = (county_demographics
                       .with_columns(pl.col('fips_str').cast(pl.Int64).alias('fips')))
election_level = (election_level
                  .with_columns(pl.col('fips').cast(pl.Int64)))

election_level = (election_level
                  .drop(['pop', 'gdp', 'pers_inc', 'percap_inc', 'emp',
                         'ln_pop', 'ln_gdp', 'ln_pers_inc', 'ln_percap_inc', 'ln_emp']))

election_level = (election_level
                  .join(county_demographics,
                        on = ['fips', 'year'], how = 'left')

 .with_columns(
    (pl.col('pop')).log().alias('ln_county_pop_prior'),
    (pl.col('gdp')).log().alias('ln_county_gdp_prior'),
    (pl.col('pers_inc')).log().alias('ln_county_pers_inc_prior'),
    (pl.col('percap_inc')).log().alias('ln_county_percap_inc_prior'),
    (pl.col('employment')).log().alias('ln_county_employment_prior')
)
)


election_level = (election_level
                  .join(all_bonds_obs_annual,
                        on = ['seed_issuer', 'year'], how = 'left')
                  .with_columns(pl.col('cum_num_issues_all')).fill_null(0))

election_level = (election_level
                  .with_columns(pl.col('cum_num_issues_all').add(1).log().alias('ln_cum_num_issues_all')))
# save
election_level.write_csv(f'{data_dir}/Websites/Texas/election_level_website_data_{output_date}.csv')