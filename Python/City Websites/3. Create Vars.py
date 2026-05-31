'''
Create outcome variables pased on parsing
'''
#%%
import polars as pl
import os
from pathlib import Path
import pandas as pd
input_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Updated Scraping 202509/Processed')
data_dir = '~/Dropbox/Voting on Bonds/Data'
output_date = '251014'
#%%
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
                           pl.col('URL').str.to_lowercase().str.contains('tax').alias('tax_url')))

res_files = (res_files
             .with_columns(pl.col('priority').fill_null(0)))
# check if contains any finance
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase()
                           .str.contains('bond|debt|finance|financial|credit|fiscal|capital|tax').alias('all_finance_url')))

# aggregate
res_files_agg = (res_files
             .group_by(['original_url', 'year'])
                 .agg(pl.col('total_subs').first(),
                      pl.col('bond_url').sum(),
                      pl.col('debt_url').sum(),
                      pl.col('tax_url').sum(),
                      pl.col('bond_or_debt_url').sum(),
                      pl.col('all_finance_url').sum())
                 .with_columns(pl.col('bond_url').truediv(pl.col('total_subs')).alias('percent_bond_url'),
                                pl.col('debt_url').truediv(pl.col('total_subs')).alias('percent_debt_url'),
                                pl.col('bond_or_debt_url').truediv(pl.col('total_subs')).alias('percent_bond_or_debt_url'),
                               pl.col('all_finance_url').truediv(pl.col('total_subs')).alias('percent_all_finance_url'),
                               pl.col('tax_url').truediv(pl.col('total_subs')).alias('percent_tax_url')))


#%% # now aggregate bow
# Load bow CSV files with schema normalization
bow_file_dfs = []
for f in Path(f'{input_dir}/bow/').glob("*.csv"):
    try:
        # First check what columns are available in this file
        temp_df = pl.scan_csv(f, n_rows=1)
        available_cols = temp_df.collect_schema().names()
        
        # Skip files that don't have the required columns for bow analysis
        if not all(col in available_cols for col in ['url', 'word', 'count', 'original_url']):
            print(f"Skipping {f.name}: missing required columns. Has: {available_cols}")
            continue
            
        df = pl.scan_csv(f).with_columns([
            pl.col('url').cast(pl.Utf8, strict=False),
            pl.col('original_url').cast(pl.Utf8, strict=False),
            pl.col('word').cast(pl.Utf8, strict=False),
            pl.col('count').cast(pl.Int64, strict=False)
        ])
        bow_file_dfs.append(df)
    except Exception as e:
        print(f"Warning: Could not load bow file {f}: {e}")

if bow_file_dfs:
    bow_files = (pl.concat(bow_file_dfs, how="diagonal")
                .collect(streaming=True))
else:
    print("Warning: No valid bow files found!")
    # Create an empty dataframe with the expected schema
    bow_files = pl.DataFrame({
        'url': [],
        'word': [],
        'count': [],
        'original_url': []
    }, schema={'url': pl.Utf8, 'word': pl.Utf8, 'count': pl.Int64, 'original_url': pl.Utf8})

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
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_finance'))
           .select(['year', 'original_url', 'percent_finance', 'rank_percent_finance', 'finance_count']))

bond = (bow_files
           .filter(pl.col('word').eq(pl.lit('bond')))
           .rename({'count': 'bond_count'})
           .with_columns(pl.col('bond_count').truediv(pl.col('total_count')).alias('percent_bond'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_bond'))
           .select(['year', 'original_url', 'percent_bond', 'rank_percent_bond', 'bond_count']))

debt = (bow_files
           .filter(pl.col('word').eq(pl.lit('debt')))
           .rename({'count': 'debt_count'})
           .with_columns(pl.col('debt_count').truediv(pl.col('total_count')).alias('percent_debt'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_debt'))
           .select(['year', 'original_url', 'percent_debt', 'rank_percent_debt', 'debt_count']))



fiscal = (bow_files
           .filter(pl.col('word').eq(pl.lit('fiscal')))
           .rename({'count': 'fiscal_count'})
           .with_columns(pl.col('fiscal_count').truediv(pl.col('total_count')).alias('percent_fiscal'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_fiscal'))
           .select(['year', 'original_url', 'percent_fiscal', 'rank_percent_fiscal', 'fiscal_count']))

tax = (bow_files
           .filter(pl.col('word').eq(pl.lit('tax')))
           .rename({'count': 'tax_count'})
           .with_columns(pl.col('tax_count').truediv(pl.col('total_count')).alias('percent_tax'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_tax'))
           .select(['year', 'original_url', 'percent_tax', 'rank_percent_tax', 'tax_count']))

credit = (bow_files
           .filter(pl.col('word').eq(pl.lit('credit')))
           .rename({'count': 'credit_count'})
           .with_columns(pl.col('credit_count').truediv(pl.col('total_count')).alias('percent_credit'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_credit'))
           .select(['year', 'original_url', 'percent_credit', 'rank_percent_credit', 'credit_count']))

capital = (bow_files
           .filter(pl.col('word').eq(pl.lit('capital')))
           .rename({'count': 'capital_count'})
           .with_columns(pl.col('capital_count').truediv(pl.col('total_count')).alias('percent_capital'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_capital'))
           .select(['year', 'original_url', 'percent_capital', 'rank_percent_capital', 'capital_count']))


budget = (bow_files
           .filter(pl.col('word').eq(pl.lit('budget')))
           .rename({'count': 'budget_count'})
           .with_columns(pl.col('budget_count').truediv(pl.col('total_count')).alias('percent_budget'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_budget'))
           .select(['year', 'original_url', 'percent_budget', 'rank_percent_budget', 'budget_count']))


revenue = (bow_files
           .filter(pl.col('word').eq(pl.lit('revenue')))
           .rename({'count': 'revenue_count'})
           .with_columns(pl.col('revenue_count').truediv(pl.col('total_count')).alias('percent_revenue'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_revenue'))
           .select(['year', 'original_url', 'percent_revenue', 'rank_percent_revenue', 'revenue_count']))


expense = (bow_files
           .filter(pl.col('word').eq(pl.lit('expense')))
           .rename({'count': 'expense_count'})
           .with_columns(pl.col('expense_count').truediv(pl.col('total_count')).alias('percent_expense'),
                         (1-pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_expense'))
           .select(['year', 'original_url', 'percent_expense', 'rank_percent_expense', 'expense_count']))

#%% # merge bow with res
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

#%% # merge with mergent data
sample_issuers1 = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/Border_Matches_URLs_20250903.csv')
sample_issuers2 = pl.read_csv(
        '~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files 20251009/Border_Matches_URLs_20251009.csv')
obs_sample = pl.concat([sample_issuers1, sample_issuers2]).unique()
#obs_sample = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/Border_Matches_URLs_20250903.csv')
#obs = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Border Matches Issuers Website Collected 20250903.csv')
obs = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Expanded Border Matches Issuers Website Collected 20251008.csv')
obs = (obs
       .filter(pl.col('City Website').is_in(obs_sample.select('URL'))))
# get one obs per year
year_list = [2015, 2016, 2017, 2018, 2019, 2020]
obs = (obs
       .with_columns(year = year_list)
       .explode('year'))

# merge with res data
obs = (obs
        .rename({'City Website': 'original_url'})
       .join(res_files_agg
             .with_columns(pl.col('year').cast(pl.Int64)), on = ['year', 'original_url'], how = 'left'))
#%%
# load mergent
mergent = pd.read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)

mergent_constant = (mergent
                    .select(['seed_issuer_id', 'city_go_vote', 'state', 'fips', 'state_go_vote'])
                    .unique())
'''
go_unlim = (mergent
            .filter(pl.col('seed_issuer_id').is_in(obs.select('seed_issuer_id')))
            .filter(pl.col('go_unlim').eq(1))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            #.filter(pl.col('year').is_in(year_list))
           # .sort(['seed_issuer_id', 'issue_id', 'amount'])
            .group_by(['seed_issuer_id', 'year'])
            .agg(pl.col('amount').sum().log().alias('log_issue_size'),
                    pl.col('maturity').max().log().alias('log_max_maturity'),
                    pl.col('maturity').mean().log().alias('log_avg_maturity'),
                    #pl.col('maturity').mul(pl.col('issue_weight')).sum().log().alias('log_weighted_avg_maturity'),
                    pl.col('ln_num_cusip').first().alias('ln_num_cusip'),
                    pl.col('purp_broad').first().alias('purp_broad')))
                    '''

go_unlim = (mergent
            .filter(pl.col('seed_issuer_id').is_in(obs.select('seed_issuer_id')))
            .filter(pl.col('go_unlim').eq(1))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            #.filter(pl.col('year').is_in(year_list))
           # .sort(['seed_issuer_id', 'issue_id', 'amount'])
            .group_by(['seed_issuer_id', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues')))

# get cumulative issuances
go_unlim_obs_annual = (obs
              .select(['seed_issuer_id', 'year'])
              .unique()
              .join(go_unlim
                    .with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64)), on = ['seed_issuer_id', 'year'], how = 'left')
              .with_columns(pl.col('num_issues').fill_null(0))
              .sort(['seed_issuer_id', 'year'])
               .with_columns(pl.col('num_issues').cum_sum().over('seed_issuer_id').alias('cum_num_issues'),
                             pl.col('num_issues').rolling_sum(5).over('seed_issuer_id').alias('rolling_sum_num_issues_5')))


all_bonds = (mergent
            .filter(pl.col('seed_issuer_id').is_in(obs.select('seed_issuer_id')))
            #.filter(pl.col('go_unlim').eq(1))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            #.filter(pl.col('year').is_in(year_list))
           # .sort(['seed_issuer_id', 'issue_id', 'amount'])
            .group_by(['seed_issuer_id', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues_all')))

# get cumulative issuances
all_bonds_obs_annual = (obs
              .select(['seed_issuer_id', 'year'])
              .unique()
              .join(all_bonds
                    .with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64)), on = ['seed_issuer_id', 'year'], how = 'left')
              .with_columns(pl.col('num_issues_all').fill_null(0))
              .sort(['seed_issuer_id', 'year'])
               .with_columns(pl.col('num_issues_all').cum_sum().over('seed_issuer_id').alias('cum_num_issues_all'),
                             pl.col('num_issues_all').rolling_sum(5).over('seed_issuer_id').alias('rolling_sum_num_issues_5_all')))


employment = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/employment_2001_2022.dta'))
percap_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/percap_inc_2001_2022.dta'))
pers_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pers_inc_2001_2022.dta'))
pop = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pop_2001_2022.dta'))
gdp = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/gdp_2001_2022.dta'))


# merge

obs = (obs
       .join(mergent_constant
             .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = ['seed_issuer_id'], how = 'left')
       .join(go_unlim_obs_annual, on = ['seed_issuer_id', 'year'], how = 'left')
        .join(all_bonds_obs_annual, on = ['seed_issuer_id', 'year'], how = 'left')
       .join(employment
             .select(['fips', 'year', 'employment']).group_by(['fips', 'year']).first()
             .with_columns(pl.col('year').cast(pl.Int64)), on = ['fips', 'year'], how = 'left')
       .join(percap_inc
             .select(['fips', 'year', 'percap_inc']).group_by(['fips', 'year']).first()
             .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
       .join(pers_inc
             .select(['fips', 'year', 'pers_inc']).group_by(['fips', 'year']).first()
             .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
        .join(pop
             .select(['fips', 'year', 'pop']).group_by(['fips', 'year']).first()
              .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
        .join(gdp
             .select(['fips', 'year', 'gdp']).group_by(['fips', 'year']).first()
              .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
       )

# log adjust
obs = (obs
       .with_columns(pl.col('bond_count').add(pl.col('debt_count')).alias('bond_debt_count'),
                     pl.col('bond_count').add(pl.col('debt_count')).add(pl.col('credit_count')).add(pl.col('fiscal_count'))
                     .add(pl.col('capital_count')).add(pl.col('tax_count')).alias('all_finance_count'))
       .with_columns(pl.col('employment').log().alias('ln_emp'),
                     pl.col('percap_inc').log().alias('ln_percap_inc'),
                     pl.col('pers_inc').log().alias('ln_pers_inc'),
                     pl.col('pop').log().alias('ln_pop'),
                     pl.col('gdp').log().alias('ln_gdp'),
                     pl.col('cum_num_issues').add(1).log().alias('ln_cum_num_issues'),
                     pl.col('rolling_sum_num_issues_5').add(1).log().alias('ln_rolling_sum_num_issues_5'),
                     pl.col('bond_count').add(1).log().alias('ln_bond_count'),
                    pl.col('tax_count').add(1).log().alias('ln_tax_count'),
                     pl.col('debt_count').add(1).log().alias('ln_debt_count'),
                     pl.col('bond_debt_count').add(1).log().alias('ln_bond_and_debt_count'),
                      pl.col('all_finance_count').add(1).log().alias('ln_all_finance_count')))
#%%
# save
obs.write_csv(f'{data_dir}/Websites/border_state_website_data_{output_date}.csv')