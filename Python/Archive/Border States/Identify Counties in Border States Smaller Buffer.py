'''
Identify counties within 25 miles of bordering states of interest
Follows Holmes (1998, JPE) and Gao et al. (2019 JFE)
State-pairs:
Ohio/Indiana
Ohio/Kentucky
Tennesee/North Carolina
Tennesee/Georgia
Alabama/Mississippi
Alabama/Tennessee
Tennesee/Arkansas
Wisconsin/Iowa
West Virginia/Virginia
Louisiana/Mississippi
Michigan/Wisconsin
Michigan/Indiana
New Hampshire/Vermont
New Hampshire/Maine
'''
#%%


import geopandas as gp
import pandas as pd
import polars as pl
import matplotlib.pyplot as plt
import seaborn as sns
import requests
from pygris import tracts

data_dir = '~/Dropbox/Voting on Bonds/Data'
states_list = ['NC', 'OH', 'KY', 'TN', 'VA', 'WV', 'GA', 'LA', 'MS', 'AR', 'MI', 'WI', 'IN', 'NH', 'VT', 'ME', 'AL', 'IA', 'MO']

# pairs
state_pairs = {'Ohio/Indiana': ['OH', 'IN', 'dark blue'],
                'Ohio/Kentucky': ['OH', 'KY', 'dark blue'],
                'Tennesee/North Carolina': ['TN', 'NC', 'light blue'],
                'Tennesee/Georgia': ['TN', 'GA', 'light blue'],
                'Alabama/Mississippi': ['AL', 'MS', 'green'],
                'Alabama/Tennessee': ['AL', 'TN', 'green'],
                #'Tennesee/Arkansas': ['TN', 'AR', 'light blue'],
                'Wisconsin/Iowa': ['WI', 'IA', 'light blue'],
                'West Virginia/Kentucky': ['WV', 'KY', 'light blue'],
                'Louisiana/Mississippi': ['LA', 'MS', 'light blue'],
                #'Arkansas/Mississippi': ['AR', 'MS', 'light blue'],
                'Michigan/Wisconsin': ['MI', 'WI', 'dark blue'],
                'Michigan/Indiana': ['MI', 'IN', 'dark blue'],
                'New Hampshire/Vermont': ['NH', 'VT', 'green'],
                'New Hampshire/Maine': ['NH', 'ME', 'green'],
                'Kentucky/Missouri': ['KY', 'MO', 'light blue'],
               'Tennessee/Missouri': ['TN', 'MO', 'light blue']}

#%%
# Get lat/long coordinates of FIPS codes
# load mergent data and pull FIPS
mergent_full = pd.read_stata(f'{data_dir}/Mergent/Clean/250707_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent_full = pl.DataFrame(mergent_full)
mergent = (mergent_full
           .filter(pl.col('state').is_in(states_list))
           .select('fips', 'state')
           .unique())

lat_long_fips = (pl.read_csv(f'{data_dir}/Border States/us_county_latlng.csv')
                 .rename({'fips_code':'fips'}))

mergent = (mergent
            .with_columns(pl.col('fips').cast(pl.Int64))
           .join(lat_long_fips, on = 'fips', how = 'inner'))
#

#%%

def build_coordinate_system(state):
    state_tracts = tracts(state, cb = True, year = 2010, cache = True).to_crs(6571)
    state_buffer = gp.GeoDataFrame(geometry = state_tracts.dissolve().buffer(80000))
    return state_buffer

state_map_dict = {}
for state in states_list:
    state_buffer = build_coordinate_system(state)
    state_map_dict[state] = state_buffer

#%%
state_fips_codes = pl.DataFrame({'state':states_list,
                                 'state_fips': [37,39,21,47,51,54,13,22,28,5,26,55,18,33,50,23, 1, 19, 29]})
state_fips_codes = state_fips_codes.rows_by_key('state')

#%%
# transform lat long FIPS into geo data frame
lat_long_fips = gp.GeoDataFrame(mergent, geometry = gp.points_from_xy(mergent['lng'], mergent['lat']),
                                crs = 4326)
lat_long_fips = lat_long_fips.to_crs(6571)

#%%
# merge

def merge_buffer(state):
    state_buffer = state_map_dict[state]
    state_merge = lat_long_fips.sjoin(state_buffer, how = 'inner')
    state_merge_fips = pl.DataFrame({'fips':state_merge[0]})
    state_merge_fips = state_merge_fips.with_columns(pl.col('fips').cast(pl.String).str.slice(0, 2).alias('state_code'))
    return state_merge_fips

state_merged_fips = {}
for state in states_list:
    state_merged_fips[state] = merge_buffer(state)

#%%

sample_dict = {}
for pairing in state_pairs.keys():
    print(pairing)
    state1 = state_pairs[pairing][0]
    state2 = state_pairs[pairing][1]
    category = state_pairs[pairing][2]
    state_code1 = state_fips_codes[state1][0]
    state_code2 = state_fips_codes[state2][0]

    first_overlap = (state_merged_fips[state1]
        .filter(pl.col('state_code').cast(pl.Int64).eq(state_code2)))

    second_overlap = (state_merged_fips[state2]
                     .filter(pl.col('state_code').cast(pl.Int64).eq(state_code1)))

    overlap = pl.concat([first_overlap, second_overlap])
    overlap = overlap.with_columns(group = pl.lit(pairing),
                                   category = pl.lit(category))
    sample_dict[pairing] = overlap


#%%
# concat
all_overlaps = pl.concat([sample_dict[pairing] for pairing in sample_dict.keys()])


#%%
# pull mergent data for border matches
mergent_border_matches = (mergent_full
                          .with_columns(pl.col('fips').cast(pl.Int64))
                          .join(all_overlaps, on = 'fips', how = 'inner')
                          .filter(pl.col('issuer_type').eq('city')))


# save
mergent_border_matches.write_csv(f'{data_dir}/Border States/Smaller Buffer/Border Matches All Mergent Data 20250715.csv')
#%%
# also merge with ravenpack data
rp_issuance = pl.read_csv(f'{data_dir}/News/Issuance_Lvl_News_With_Lagged_News_20250312.csv')
rp_city_month = pl.read_parquet(f'{data_dir}/News/Full_City_Month_Data_Headline_Filter.gzip')

# join
rp_issuance = (rp_issuance
               .filter(pl.col('seed_issuer_id').is_in(mergent_border_matches['seed_issuer_id']))
               .join(mergent_border_matches.select(['seed_issuer_id', 'fips', 'group', 'category']).unique()
                     .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = 'seed_issuer_id', how = 'inner'))

rp_city_month = (rp_city_month
                 .filter(pl.col('seed_issuer_id').is_in(mergent_border_matches['seed_issuer_id']))
                 .join(mergent_border_matches.select(['seed_issuer_id', 'group', 'category'])
                       .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = 'seed_issuer_id', how = 'inner')
                 )

rp_issuance.write_csv(f'{data_dir}/Border States/Smaller Buffer/Border Matches RP Issuance Lvl 20250715.csv')
rp_city_month.write_csv(f'{data_dir}/Border States/Smaller Buffer/Border Matches RP City Month Lvl 20250715.csv')


#%%
# also merge with secondarymarket issuance data
issuance = pl.read_csv(f'{data_dir}/Mergent/Clean/250507_issue_level_aggregation.csv')


# join
issuance = (issuance
               .filter(pl.col('seed_issuer_id').is_in(mergent_border_matches['seed_issuer_id']))
               .join(mergent_border_matches.select(['seed_issuer_id', 'group', 'category']).unique()
                     .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = 'seed_issuer_id', how = 'inner'))


issuance.write_csv(f'{data_dir}/Border States/Smaller Buffer/Border Matches Secondary Issuance Lvl 20250715.csv')


#%%
# just save list of issuers
#issuers = mergent_border_matches.select(['seed_issuer_id', 'seed_issuer', 'group', 'category']).unique()
#issuers.write_csv(f'{data_dir}/Border States/Border Matches Issuers 20250307.csv')


#%%
# output just list of issuers in sample
issuers = pl.read_csv(f'{data_dir}/Border States/Border Matches All Mergent Data 20250307.csv', infer_schema_length=10000)
issuers = (issuers
           .filter(pl.col('category').ne(pl.lit('green')))
           .filter(pl.col('go_unlim').eq(1))
            .filter(pl.col('pop').is_not_null())
           .select(['seed_issuer_id', 'seed_issuer', 'state', 'group', 'category'])
           .unique()
           )
issuers.write_csv(f'{data_dir}/Border States/Border States GO Unlim Blue Only Issuers 20250312.csv')