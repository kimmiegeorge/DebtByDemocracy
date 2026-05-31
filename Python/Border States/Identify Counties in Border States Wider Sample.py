'''
Identify counties within configurable distance of bordering states of interest
EXPANDED SET OF BORDER STATES - INCLUDES BORDER STATES WHERE REVENUE VOTE MAY BE REQUIRED
(Default: 26 miles / 42km buffer)
Follows Holmes (1998, JPE) and Gao et al. (2019 JFE)
State-pairs:
Ohio/Kentucky
West Virginia/Kentucky
Missouri/Kentucky
Michigan/Wisconsin
North Carolina/Tennessee
Arkansas/Tennesee
Georgia/Tennessee
Alabama/Tennessee
Missouri/Tennessee
Alabama/Mississippi
Louisiana/Mississippi
Arkansas/Mississippi
Rhode Island/Massachusetts
Vermont/Massachusetts
Vermont/New Hampshire
Maine/New Hampshire
'''
#%%

# ========== PARAMETERS - UPDATE THESE AS NEEDED ==========

# DATE PARAMETER - Change this to update all output file dates
# Option 1: Manual date
DATE_SUFFIX = '20251215'  # Format: YYYYMMDD

# Option 2: Automatic today's date (uncomment to use)
# from datetime import datetime
# DATE_SUFFIX = datetime.now().strftime('%Y%m%d')

# INPUT FILE PARAMETERS - Update these file names as needed
MERGENT_DATA_FILE = '251119_city_cusiplevel_statereq_purpose_yieldspread.dta'
COUNTY_LATLNG_FILE = 'us_county_latlng.csv'
#RP_ISSUANCE_FILE = 'Issuance_Lvl_News_With_Lagged_News_250916.csv'
#RP_ISSUANCE_FILE = 'Issuance_Lvl_News_With_Lagged_News_2501013.csv'
RP_ISSUANCE_FILE = 'Issuance_Lvl_News_With_Lagged_News_251215.csv'
RP_CITY_MONTH_FILE = 'Full_City_Month_Data_Headline_Filter_250916.gzip'
SECONDARY_MARKET_FILE = '250507_issue_level_aggregation.csv'

# BUFFER PARAMETER - Change buffer distance for state borders
BUFFER_DISTANCE = 100000  # Default: 42000 meters (~26 miles)
# Common alternatives:
# 16000   = ~10 miles
# 32000   = ~20 miles
# 40000   = ~25 miles (Holmes 1998)
# 42000   = ~26 miles (current default)
# 48000   = ~30 miles
# 10000   = ~50 miles

# ========================================================


import geopandas as gp
import pandas as pd
import polars as pl
import matplotlib.pyplot as plt
import seaborn as sns
import requests
from pygris import tracts

data_dir = '~/Dropbox/Voting on Bonds/Data'
states_list = ['AL', 'AR', 'GA', 'KY', 'LA', 'MA', 'ME', 'MI', 'MO', 'MS', 'NC', 'NH', 'OH', 'RI', 'TN', 'VT', 'WI', 'WV']

# pairs
state_pairs = {'Ohio/Kentucky': ['OH', 'KY', 'green striped'],
                'West Virginia/Kentucky': ['WV', 'KY', 'green'],
                'Missouri/Kentucky': ['MO', 'KY', 'green'],
               'Michigan/Wisconsin': ['MI', 'WI', 'green striped'],
                'North Carolina/Tennessee': ['NC', "TN", 'green'],
                'Arkansas/Tennesee': ['AR', 'TN', 'grey'],
                'Georgia/Tennessee': ['GA', 'TN', 'green'],
               'Alabama/Tennessee': ['AL', 'TN', 'grey'],
                'Missouri/Tennessee': ['MO', 'TN', 'green'],
                'Alabama/Mississippi': ['AL', 'MS', 'grey'],
               'Arkansas/Mississippi': ['AR', 'MS', 'grey'],
                'Louisiana/Mississippi': ['LA', 'MS', 'green'],
               'Rhode Island/Massachusetts': ['RI', 'MA', 'grey'],
               'Vermont/Massachusetts': ['VT', 'MA', 'grey'],
               'Vermont/New Hampshire': ['VT', 'NH', 'grey'],
                'Maine/New Hampshire': ['ME', 'NH', 'grey']}




#%%
# Get lat/long coordinates of FIPS codes
# load mergent data and pull FIPS
mergent_full = pd.read_stata(f'{data_dir}/Mergent/Clean/{MERGENT_DATA_FILE}')
mergent_full = pl.DataFrame(mergent_full)
mergent = (mergent_full
           .filter(pl.col('state').is_in(states_list))
           .select('fips', 'state')
           .unique())

lat_long_fips = (pl.read_csv(f'{data_dir}/Border States/{COUNTY_LATLNG_FILE}')
                 .rename({'fips_code':'fips'}))

mergent = (mergent
            .with_columns(pl.col('fips').cast(pl.Int64))
           .join(lat_long_fips, on = 'fips', how = 'inner'))
#

#%%

def build_coordinate_system(state):
    state_tracts = tracts(state, cb = True, year = 2010, cache = True).to_crs(6571)
    state_buffer = gp.GeoDataFrame(geometry = state_tracts.dissolve().buffer(BUFFER_DISTANCE))
    return state_buffer

state_map_dict = {}
for state in states_list:
    state_buffer = build_coordinate_system(state)
    state_map_dict[state] = state_buffer

#%%
state_fips_codes = pl.DataFrame({'state':states_list,
                                 'state_fips': [1, 5, 13, 21, 22, 25, 23, 26, 29, 28, 37, 33, 39, 44, 47, 50, 55, 54]})
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
mergent_border_matches.write_csv(f'{data_dir}/Border States/Border Matches All Mergent Data Expanded Set Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv')
#mergent_border_matches.select(['state', 'seed_issuer', 'county_name']).write_csv(f'{data_dir}/Border States/Border Matches All Mergent Data Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv')
#%%
# also merge with ravenpack data
rp_issuance = pl.read_csv(f'{data_dir}/News/{RP_ISSUANCE_FILE}')
rp_city_month = pl.read_parquet(f'{data_dir}/News/{RP_CITY_MONTH_FILE}')

# join
rp_issuance = (rp_issuance
               .filter(pl.col('seed_issuer_id').is_in(mergent_border_matches['seed_issuer_id']))
               .join(mergent_border_matches.select(['seed_issuer_id', 'group', 'category']).unique()
                     .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = 'seed_issuer_id', how = 'inner'))

rp_city_month = (rp_city_month
                 .filter(pl.col('seed_issuer_id').is_in(mergent_border_matches['seed_issuer_id']))
                 .join(mergent_border_matches.select(['seed_issuer_id', 'group', 'category'])
                       .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = 'seed_issuer_id', how = 'inner')
                 )

rp_issuance.write_csv(f'{data_dir}/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv')
rp_city_month.write_csv(f'{data_dir}/Border States/Border Matches RP City Month Lvl Expanded Set Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv')


#%%
# also merge with secondarymarket issuance data
issuance = pl.read_csv(f'{data_dir}/Mergent/Clean/{SECONDARY_MARKET_FILE}')


# join
issuance = (issuance
               .filter(pl.col('seed_issuer_id').is_in(mergent_border_matches['seed_issuer_id']))
               .join(mergent_border_matches.select(['seed_issuer_id', 'group', 'category']).unique()
                     .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = 'seed_issuer_id', how = 'inner'))


issuance.write_csv(f'{data_dir}/Border States/Border Matches Secondary Issuance Lvl Expanded Set Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv')


#%%
# just save list of issuers
#issuers = mergent_border_matches.select(['seed_issuer_id', 'seed_issuer', 'group', 'category']).unique()
#issuers.write_csv(f'{data_dir}/Border States/Border Matches Issuers 20250307.csv')


#%%
# output just list of issuers in sample
# Note: Using the output file from above instead of hardcoded date
issuers = pl.read_csv(f'{data_dir}/Border States/Border Matches All Mergent Data Expanded Set Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv', infer_schema_length=10000)
issuers = (issuers
           .filter(pl.col('category').ne(pl.lit('green')))
           .filter(pl.col('go_unlim').eq(1))
            .filter(pl.col('pop').is_not_null())
           .select(['seed_issuer_id', 'seed_issuer', 'state', 'group', 'category'])
           .unique()
           )
issuers.write_csv(f'{data_dir}/Border States/Border States GO Unlim Blue Only Issuers Expanded Set Buffer {BUFFER_DISTANCE} {DATE_SUFFIX}.csv')
