'''
Compute trade-level yield spread on seconday market trades
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
from pathlib import Path

import polars as pl

project_dir = Path(__file__).resolve().parents[4]
data_dir = project_dir / 'Data' / 'MSRB'
processed_dir = project_dir / 'Data' / 'Clean_Intermediate' / 'MSRB' / 'Processed'
processed_dir.mkdir(parents=True, exist_ok=True)

# The output filename and downstream sample are explicitly limited to 2005--2023.
# Do not use a wildcard here: raw files for later years may also be present.
raw_trade_files = [data_dir / 'Raw Files' / f'msrb_{year}.gzip'
                   for year in range(2005, 2024)]
missing_raw_files = [path for path in raw_trade_files if not path.exists()]
if missing_raw_files:
    raise FileNotFoundError(f'Missing MSRB raw files: {missing_raw_files}')
raw_trade_files = [str(path) for path in raw_trade_files]

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
          .scan_parquet(raw_trade_files)
          .select(['cusip', 'dated_date', 'trade_date', 'yield'])
          .collect(engine='streaming'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
yields.write_parquet(processed_dir / 'All_Trade_Yields_2005_2023.gzip')
