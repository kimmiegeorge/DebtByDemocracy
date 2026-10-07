'''
Merge RP identified cities with demographic data
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import requests
import urllib
wrds_dir = '~/WRDS_202408'
data_dir = '~/Dropbox/Voting on Bonds/Data'
import os


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
pull ravenpack cities 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
entity_map2 = pl.read_parquet(f'{wrds_dir}/ravenpack_common_rpa_entity_mappings_20240819.gzip')
entity_map2 = entity_map2.filter(pl.col('entity_type').eq('PLCE'))
cities = entity_map2.filter(pl.col('data_type').eq('PLACE_TYPE') & pl.col('data_value').eq('CITY')).select('rp_entity_id')
us_all = entity_map2.filter(pl.col('data_type').eq('COUNTRY_ID') & pl.col('data_value').eq('3D4567')).select('rp_entity_id')
cities_all = entity_map2.filter(pl.col('rp_entity_id').is_in(cities) & pl.col('rp_entity_id').is_in(us_all))

cities_all = (cities_all
              .filter(pl.col('data_type').eq('ENTITY_NAME'))
              .with_columns(pl.col('data_value').str.split(',').alias('city_state_country'))
               .with_columns(pl.col('city_state_country').list.len().alias('list_len'))
              .filter(pl.col('list_len').eq(3))
              .with_columns(pl.col('city_state_country').list.get(1).alias('state'))
              .with_columns(pl.col('city_state_country').list.get(0).alias('city'))
              .select(['rp_entity_id', 'city', 'state']))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
add latititude and longitude 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

lat = entity_map2.filter(pl.col('data_type').eq(pl.lit('LATITUDE'))).select(['rp_entity_id', 'data_value']).rename({'data_value': 'latitude'})
long = entity_map2.filter(pl.col('data_type').eq(pl.lit('LONGITUDE'))).select(['rp_entity_id', 'data_value']).rename({'data_value': 'longitude'})

cities_all = (cities_all
              .join(lat, on =['rp_entity_id'], how = 'left')
              .join(long, on = ['rp_entity_id'], how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
get fips 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

unique_lat_long = cities_all.select(['latitude', 'longitude']).unique().to_pandas()

def pull_fips(lat, long):
    url = f'https://geo.fcc.gov/api/census/block/find?latitude={lat}&longitude={long}&format=json'
    try:
        response = requests.get(url)
        return response.json()['County']['FIPS']
    except:
        return None
count = 0
for index, row in unique_lat_long.iterrows():
    unique_lat_long.loc[index, 'fips'] = pull_fips(row['latitude'], row['longitude'])
    count += 1
    if count % 1000 == 0:
        print(count)


# add back
unique_lat_long = pl.DataFrame(unique_lat_long)
cities_all = (cities_all
              .join(unique_lat_long, on = ['latitude', 'longitude'], how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
cities_all.write_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')