'''
Add bond-level secondary market measures to bond-level border-state sample
'''

#%% -----------------------------------------------------------------------
# set up
# -----------------------------------------------------------------------
import polars as pl

data_dir = '~/Dropbox/Voting on Bonds/Data'

#%% -----------------------------------------------------------------------
# load data
# -----------------------------------------------------------------------
border_state = pl.read_csv(f'{data_dir}/Border States/Border Matches All Mergent Data 20250707.csv', infer_schema_length=10000)
msrb = (pl.read_csv(f'{data_dir}/MSRB/Processed/Bond_Level_Secondary_Market_Vars_With_Bond_Vars_2005_2023.csv')
        .select(['cusip', 'issue_id', 'number_of_trades_1yr',
                 'markup_1yr', 'markup_retail_1yr', 'markup_small_retail_1yr', 'markup_large_retail_1yr',
                 'markup_institutional_1yr', 'markup_small_institutional_1yr', 'markup_large_institutional_1yr',
                 'number_of_trades_3yr', 'markup_3yr', 'markup_retail_3yr', 'markup_small_retail_3yr', 'markup_large_retail_3yr',
                 'markup_institutional_3yr', 'markup_small_institutional_3yr', 'markup_large_institutional_3yr',
                 'number_of_trades_6mo', 'markup_6mo', 'markup_retail_6mo', 'markup_small_retail_6mo', 'markup_large_retail_6mo',
                 'markup_institutional_6mo', 'markup_small_institutional_6mo', 'markup_large_institutional_6mo',
                 'yield_volatility_1yr', 'yield_volatility_3yr', 'yield_volatility_6mo']))

#%% -----------------------------------------------------------------------
# merge
# -----------------------------------------------------------------------
full = (border_state
        .join(msrb, on = ['cusip', 'issue_id'], how = 'left'))

#%% -----------------------------------------------------------------------
# save
# -----------------------------------------------------------------------
full.write_csv(f'{data_dir}/Border States/Border Matches All Mergent Data With MSRB 20250707.csv')