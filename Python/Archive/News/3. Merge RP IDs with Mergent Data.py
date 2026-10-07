'''
Merge RP Entitys with Mergent Issuers
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import requests
import re
from rapidfuzz.distance import Levenshtein,JaroWinkler


wrds_dir = '~/WRDS_202408'
data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
rp_entities = pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')
mergent = pd.read_stata(f'{data_dir}/Mergent/Clean/250307_citycountyschool_cusiplevel_statereq_purpose.dta')
mergent = pl.DataFrame(mergent)

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
get mergent to issuer level 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
mergent = (mergent
           .filter(pl.col('issuer_type').eq(pl.lit('city')))
           .select(['state','seed_issuer', 'seed_issuer_id', 'city_go_vote', 'city_rev_vote', 'fips'])
           .unique())

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge on fips and then look for seed issuer matches
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
mergent_rp_join  = (rp_entities
                    .join(mergent
                          .with_columns(pl.col('fips').cast(pl.Int64)), on = ['fips'], how = 'inner'))

# change to lower
mergent_rp_join = (mergent_rp_join
                   .with_columns(pl.col('seed_issuer').str.to_lowercase(),
                                 pl.col('city').str.to_lowercase()))

# create indicator if city is included in seed_issuer
# get max value over rp_entity_ids to know if the entity id was matched
mergent_rp_join = (mergent_rp_join
                   .with_columns(pl.col('seed_issuer').str.contains(pl.col('city')).cast(pl.Int64).alias('city_in_issuer'))
                   .with_columns(pl.col('city_in_issuer').max().over('rp_entity_id').alias('max_city_in_issuer')))

# separate out matches made on name
# note that there are a few duplicate rp_entity_ids, but they seem to refer to the same issuer
matched_on_name = (mergent_rp_join.filter(pl.col('max_city_in_issuer').eq(1))
                   .filter(pl.col('city_in_issuer').eq(1)))

# note below, tried to match on string similarity after dropping state names, but this did not yield good results
# only 5 or so had match scores over 90%
'''
# now continue trying to match those not matched on name
not_matched = (mergent_rp_join
               .filter(pl.col('max_city_in_issuer').eq(0))
               )

# create list of state names to remove from seed issuers
state_nms = ['alaska', 'ala', 'ariz', 'ark', 'calif', 'colo', 'conn', 'del', 'fla', 'ga', 'hawaii', 'idaho',
             'ill', 'ind', 'ia', 'kans', 'ky', 'la', 'me', 'md', 'mass', 'mich', 'minn', 'mo', 'miss', 'mont', 'neb', 'nev',
             'north carolina', 'n d', 'n j', 'n y', 'n mex', 'ohio', 'okla', 'ore', 'pa', 'r i', 's c', 's d', 'tenn', 'tex', 'utah',
             'va', 'vt', 'wash', 'wis', 'w va', 'wyo']

# Create a regex pattern to match any of the specified state names preceded by a space
pattern = r' (?:\b|(?<=\s))(' + '|'.join(state_nms) + r')(?=\s|$)'

# Remove the specified state names from the seed_issuer column if preceded by a space
for state_nm in state_nms:
    not_matched = not_matched.with_columns(pl.col('seed_issuer').str.replace(f' {state_nm}', '')
    )

# now test for string similarity
not_matched = (not_matched
               .with_columns(pl.struct(pl.col('seed_issuer'), pl.col('city')).alias('name_struct'))
               .with_columns(
    pl.col('name_struct').map_elements(lambda t: Levenshtein.normalized_similarity(t['seed_issuer'], t['city']),
                                       return_dtype = pl.Float32).alias('name_similarity')))

# sort by name similarity and keep first
not_matched = (not_matched
               .sort(['rp_entity_id', 'name_similarity'], descending = True)
               .group_by('rp_entity_id').first())
               '''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save mapping file 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

rp_mapping_file = (matched_on_name
                   .select(['rp_entity_id', 'seed_issuer', 'seed_issuer_id'])
                   .write_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv'))