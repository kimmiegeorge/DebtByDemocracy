'''
pull MSRB data from WRDS
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import wrds

db = wrds.Connection()

data_dir  = '~/Dropbox/Voting on Bonds/Data/MSRB'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
preview MSRB files
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# list all msrb tables
db.list_tables('msrb')

# describe main table
db.describe_table('msrb', 'msrb')
# preview
preview = db.get_table('msrb', 'msrb', rows = 10)

# describe lookup
db.describe_table('msrb', 'msrb_lookup')
# preview
db.get_table('msrb', 'msrb_lookup', rows = 10)

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load full file 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

for year in [2012, 2013, 2014, 2019, 2020, 2021, 2022, 2023]:
    query  = f"SELECT * FROM msrb.msrb WHERE EXTRACT(YEAR FROM trade_date) = {year}"
    file = db.raw_sql(query)
    (pl.DataFrame(file)
     .write_parquet(f'{data_dir}/msrb_{year}.gzip'))
    print(f"Saved {year}")


