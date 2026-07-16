'''
Compute trade-level yield spread on seconday market trades
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import os

import polars as pl
import wrds

data_dir = '~/Dropbox/Voting on Bonds/Data/MSRB'
clean_data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data/Clean_Intermediate/MSRB'
os.makedirs(os.path.expanduser(f'{clean_data_dir}/Processed'), exist_ok=True)
wrds_dir = '~/WRDS_202408'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load MMA data used to compute yield spread 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# load MMA data

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
For now, without MMA data, simply save trade-level yields 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
yields = (pl
          .scan_parquet(f'{data_dir}/Raw Files/*')
          .select(['cusip', 'dated_date', 'trade_date', 'yield'])
          .collect(streaming = True))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
yields.write_parquet(f'{clean_data_dir}/Processed/All_Trade_Yields_2005_2023.gzip')
