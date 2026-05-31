'''
Create file with bond-level any trade before maturity indicators
and merge with continuing disclosure data
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import os
import pandas as pd

data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load needed data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuances = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta'))
             .select(['issue_id', 'cusip',
                      'offering_date']))

liquidity = (pl
             .read_parquet(f'{data_dir}/MSRB/Processed/All_Trade_Markup_2005_2023.gzip')
             )
