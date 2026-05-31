#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import requests
import re
from rapidfuzz.distance import Levenshtein,JaroWinkler


wrds_dir = '/Volumes/External/WRDS_202408'
data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

rp_matches = pl.read_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv')
border_issuers = (pl.read_csv('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 100000 20250827.csv', infer_schema_length=10000)
                  .select(['seed_issuer', 'seed_issuer_id', 'group']).unique())

# load ravenpack entities
entity_map2 = (pl.read_parquet(f'{wrds_dir}/ravenpack_common_rpa_entity_mappings_20240819.gzip')
               .filter(pl.col('data_type').eq(pl.lit('ENTITY_NAME')))
               .select(['rp_entity_id', 'data_value'])
               .rename({'data_value': 'rp_entity_name'}))

rp_matches = (rp_matches.join(border_issuers, on = 'seed_issuer_id', how = 'inner')
              .join(entity_map2, on = 'rp_entity_id', how = 'left'))

good_groups = ['Tennesee/Georgia', 'Kentucky/Missouri', 'Louisiana/Mississippi', 'West Virginia/Kentucky', 'Ohio/Kentucky', 'Michigan/Wisconsin',
               'Tennesee/North Carolina', 'Tennessee/Missouri']

rp_matches = rp_matches.filter(pl.col('group').is_in(good_groups))
rp_matches.write_csv(f'{data_dir}/News/RP_Mergent_Border_Matches_To_Examine.csv')