'''
Combine samples of city/county and school issuers
'''
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import pandas as pd

dta_dir = '~/Dropbox/Voting on Bonds/Data/Mergent/Clean'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
city_county = pl.read_csv(f'{dta_dir}/241107_city_county_issuernames_with_seed_issuer.csv')
sch_dist = pl.read_csv(f'{dta_dir}/241108_sch_dist_issuernames_with_seed_issuer.csv')

# combine
city_county = (city_county
               .drop(['match_type', 'seed_issuer_id'])
               .with_columns(pl.col('issuer_long_name').str.contains('CNTY').cast(pl.Int64).alias('county')))

sch_dist = (sch_dist
            .with_columns(county = 0)
            .with_columns(pl.col('county').cast(pl.Int64))
            .select(['seed_issuer', 'issuer_long_name', 'issuer_name_id', 'school', 'state', 'n_bonds', 'county']))

all_issuers = (pl.concat([city_county, sch_dist]))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create seed issuer id
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

seed_issuers = (all_issuers
                .select('seed_issuer')
                .unique()
                .with_row_index('seed_issuer_id'))

all_issuers = (all_issuers
               .join(seed_issuers, on = 'seed_issuer', how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
all_issuers.write_csv(f'{dta_dir}/241108_all_issuernames_with_seed_issuer.csv')