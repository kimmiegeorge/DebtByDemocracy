'''
Aggregate MSRB to the issuance - month level
Filter to city and county GO bonds
Merge with issuance-level data
Look at trades at least 60 days after offering date and 60 days before maturity date
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
markups = pl.read_parquet(f'{data_dir}/MSRB/Processed/All_Trade_Markup_2005_2023.gzip')
issuance_lvl = (pl.read_csv(f'{data_dir}/Mergent/Clean/241120_issue_level.csv')
                .select(['issue_id', 'state', 'seed_issuer', 'year',
                         'offering_date', 'vote_req', 'rev', 'qtr',
                         'city', 'city_go_vote'])
                .filter(pl.col('city').eq(1))
                .filter(pl.col('rev').eq(0))
                .filter(pl.col('vote_req').is_not_null()))
bond_lvl = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/241112_citycountyschool_cusiplevel.dta'))
            .select(['cusip', 'issue_id', 'maturity_date']))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Merge
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
markups = (markups
           .join(bond_lvl, on = 'cusip', how = 'inner'))

markups = (markups
           .with_columns(pl.col('issue_id').cast(pl.Int64))
           .join(issuance_lvl, on = 'issue_id', how = 'inner'))

# focus on city and county GO bonds with  non-missing vote requirement
markups = (markups
           .filter(pl.col('city').eq(1))
           .filter(pl.col('rev').eq(0))
           .filter(pl.col('city_go_vote').is_not_null()))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
filter to trades 60 days after offering and 60 days before maturity 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# first, adjust date type of maturity date
markups = (markups
           .with_columns(pl.col('maturity_date').cast(pl.Date))
           )

# compute date diffs
markups = (markups
           .with_columns(pl.col('trade_date').sub(pl.col('dated_date')).dt.total_days().alias('diff1'),
                         pl.col('maturity_date').sub(pl.col('trade_date')).dt.total_days().alias('diff2'))
           .filter(pl.col('diff1').gt(90))
           .filter(pl.col('diff2').gt(90))
           .drop(['diff1', 'diff2']))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
compute averages at the year qtr level for each issuance 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


year_qtr_ids = (pl.DataFrame({'date': pl.date_range(pl.date(2000,1,1), pl.date(2024,1,1), eager = True)})
                .with_columns(qtr = pl.col('date').dt.year() * 10 + pl.col('date').dt.quarter())
                .select(['qtr'])
                .unique()
                .sort(['qtr'])
                .with_row_index('qtr_id'))


year_qtr = (markups
            # need to make qtr variable based off of trade_date
            .with_columns(qtr = pl.col('trade_date').dt.year() * 10 + pl.col('trade_date').dt.quarter())
            .join(year_qtr_ids, on = ['qtr'], how = 'inner')
            .group_by(['qtr_id', 'issue_id', 'seed_issuer'])
            .agg(pl.col('dated_date').count().alias('number_of_trades'),
                 pl.col('dated_date').filter(pl.col('retail').eq(1)).count().alias('number_of_retail_trades'),
                 pl.col('dated_date').filter(pl.col('small_retail').eq(1)).count().alias('number_of_small_retail_trades'),
                 pl.col('dated_date').filter(pl.col('large_retail').eq(1)).count().alias('number_of_large_retail_trades'),
                 pl.col('dated_date').filter(pl.col('institutional').eq(1)).count().alias('number_of_institutional_trades'),
                 pl.col('dated_date').filter(pl.col('small_institutional').eq(1)).count().alias('number_of_small_institutional_trades'),
                 pl.col('dated_date').filter(pl.col('large_institutional').eq(1)).count().alias('number_of_large_institutional_trades'),
                 pl.col('markup').mean().alias('markup'),
                 pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail'),
                 pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail'),
                 pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail'),
                 pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional'),
                 pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias(
                     'markup_small_institutional'),
                 pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias(
                     'markup_large_institutional')
                 ))



#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
each issue_id, year qtr search for issuances from the same issuer int the same year qtr or previous year qtr 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


_temp1 = (year_qtr
         .select(['issue_id', 'seed_issuer', 'qtr_id']))

_temp2 = (issuance_lvl
          .select(['issue_id', 'seed_issuer', 'offering_date', 'vote_req'])
          .with_columns(pl.col('offering_date').str.to_date(format = '%d%b%Y'))
          .with_columns(offering_qtr = pl.col('offering_date').dt.year() * 10 + pl.col('offering_date').dt.quarter())
          .join(year_qtr_ids
                .rename({'qtr': 'offering_qtr',
                         'qtr_id': 'offering_qtr_id'}), on = 'offering_qtr', how = 'inner'))

# now join all _temp1 with _temp2
# and only keep obs where issue_id is not the same, and offering_qtr_id == qtr_id or is one less
_temp3 = (_temp1
          .join(_temp2, on = 'seed_issuer', how = 'left')
          .filter(pl.col('issue_id').ne(pl.col('issue_id_right')))
          .with_columns(pl.col('qtr_id').sub(pl.col('offering_qtr_id')).alias('diff'))
          .filter(pl.col('diff').is_in([0,1]))
          #.filter(pl.col('diff').eq(0))
          # if multiple issuance in the same quarter, just keep one
          .drop(['issue_id_right', 'offering_date', 'offering_qtr', 'offering_qtr_id', 'diff', 'offering_qtr_id'])
          .unique())



# create indicator for same quarter and next quarter issuance
year_qtr = (year_qtr
            .join(_temp3
                  .select(['issue_id', 'qtr_id', 'vote_req'])
                   .with_columns(recent_issuance = 1)
                  .rename({'vote_req': 'vote_req_past_issuance'}),
                  on = ['issue_id', 'qtr_id'], how = 'left')
            .with_columns(pl.col('recent_issuance').fill_null(0)))

# merge with general state vote requirements
year_qtr = (year_qtr
            .join(issuance_lvl
                  .select(['issue_id', 'city_go_vote']), on = 'issue_id', how = 'left'))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
descriptives
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
def desc(var):
    mean_all = year_qtr[var].mean()
    mean_recent_issuance = year_qtr.filter(pl.col('recent_issuance').eq(1))[var].mean()
    mean_norecent_issuance = year_qtr.filter(pl.col('recent_issuance').eq(0))[var].mean()
    mean_norecent_issuance_vote = year_qtr.filter(pl.col('recent_issuance').eq(0)).filter(pl.col('city_go_vote').eq(1))[var].mean()
    mean_norecent_issuance_novote = year_qtr.filter(pl.col('recent_issuance').eq(0)).filter(pl.col('city_go_vote').eq(0))[
        var].mean()
    mean_recent_issuance_vote = year_qtr.filter(pl.col('recent_issuance').eq(1)).filter(pl.col('vote_req_past_issuance').eq(1))[var].mean()
    mean_recent_issuance_novote = year_qtr.filter(pl.col('recent_issuance').eq(1)).filter(pl.col('vote_req_past_issuance').eq(0))[var].mean()

    tbl = pl.DataFrame({'var' : [var],
                        'all': [mean_all],
                        'no_recent_issuance': [mean_norecent_issuance],
                        'no_recent_issuance_vote': [mean_norecent_issuance_vote],
                        'no_recent_issuance_novote': [mean_norecent_issuance_novote],
                        'recent_issuance': [mean_recent_issuance],
                        'recent_issuance_vote': [mean_recent_issuance_vote],
                        'recent_issuance_novote': [mean_recent_issuance_novote]})

    return tbl

descriptives = pl.concat([desc(var) for var in ['number_of_trades', 'number_of_retail_trades', 'number_of_small_retail_trades',
                                                'number_of_large_retail_trades', 'number_of_institutional_trades',
                                                'number_of_small_institutional_trades', 'number_of_large_institutional_trades',
                                                'markup', 'markup_retail', 'markup_small_retail', 'markup_large_retail',
                                                'markup_institutional', 'markup_small_institutional', 'markup_large_institutional']])

descriptives.write_csv(f'{data_dir}/MSRB/Processed/Descriptives - Quarterly Liquidity by Recent Issuance.csv')

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge year qtr with issuance data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuance_lvl = (pl.read_csv(f'{data_dir}/Mergent/Clean/241120_issue_level.csv')
                .select(['issue_id', 'state', 'year',
                         'offering_date', 'log_issue_size', "log_wavg_maturity", "ln_num_cusip",
                   "wavg_callable", "wavg_sinkable", "wavg_insured", "rated_dummy", "pop", "gdp",
                   "pers_inc"])
                .rename({'year': 'issuance_year'})
                .with_columns(pl.when(pl.col('wavg_callable').gt(0)).then(1).otherwise(0).alias('callable_ind'),
                              pl.when(pl.col('wavg_sinkable').gt(0)).then(1).otherwise(0).alias('sinkable_ind'),
                              pl.when(pl.col('wavg_insured').gt(0)).then(1).otherwise(0).alias('insured_ind')))

year_qtr = (year_qtr
            .join(issuance_lvl, on = 'issue_id', how = 'inner'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
get actual quarter and year of year qtr data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

year_qtr = (year_qtr
            .join(year_qtr_ids, on = 'qtr_id', how = 'inner'))

# create year variable
year_qtr = (year_qtr
            .with_columns(pl.col('qtr').truediv(10).alias('year'))
            .with_columns(pl.col('year').cast(pl.String).str.slice(0,4))
            .with_columns(pl.col('year').cast(pl.Int64))
            .with_columns(pl.col('year').sub(pl.col('issuance_year')).alias('year_since_issuance')))

# save
year_qtr.write_parquet(f'{data_dir}/MSRB/Processed/Quarterly Liquidity by Recent Issuance_2005_2023.gzip')