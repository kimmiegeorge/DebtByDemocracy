'''
Pull city entities from Ravenpack
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
data_dir = '~/WRDS_202408'
import wrds
import calendar
from datetime import datetime, timedelta
import datetime
import os
db = wrds.Connection()

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
pull ravenpack entities for cities 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

entity_map2 = pl.read_parquet(f'{data_dir}/ravenpack_common_rpa_entity_mappings_20240819.gzip')
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

city_ids = cities_all['rp_entity_id'].to_list()

cities_all.write_csv('~/Dropbox/Voting on Bonds/Data/News/Ravenpack_City_IDs.csv')

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
pull articles written about cities  
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
rp_path = '/Users/kmunevar/City_RP_Articles'
'''
for yr in range(2000, 2022):

    if not os.path.isfile(f'{rp_path}/ravenpack_city_articles_{yr}.gzip'):
        (db
         .raw_sql(f"""select *
         from ravenpack_full.rpa_full_global_macro_{yr}
         where rpa_date_utc >= '{yr}-01-01' and
         rpa_date_utc <= '{yr}-12-31'
         and rp_entity_id IN ({','.join(map(lambda x: f"'{x}'", city_ids))})""")
         .to_parquet(f'{rp_path}/ravenpack_city_articles_{yr}.gzip', compression = 'gzip', index=False)
         )

        print(f'Year {yr} downloaded')
    else:
        print(f'Year {yr} already downloaded')
'''


def download_monthly_ravenpack(yr, mnth):
    end_date = calendar.monthrange(yr,mnth)[1]

    if not os.path.isfile(f'{rp_path}/ravenpack_city_articles_{yr}_{mnth}.gzip'):
        (db
         .raw_sql(f"""select *
         from ravenpack_full.rpa_full_global_macro_{yr}
         where rpa_date_utc >= '{yr}-{mnth}-01' and
         rpa_date_utc <= '{yr}-{mnth}-{end_date}'
         and rp_entity_id IN ({','.join(map( lambda x: f"'{x}'", city_ids))})""")
         .to_parquet(f'{rp_path}/ravenpack_city_articles_{yr}_{mnth}.gzip', compression = 'gzip', index=False)
         )

        print(f'Year {yr} Month {mnth} downloaded')
    else:
        print(f'Year {yr} Month {mnth} already downloaded')

[download_monthly_ravenpack(yr, mth) for yr in range(2013, 2024) for mth in range(1, 13)]

def download_daily_ravenpack(dt):
    yr = dt.year
    formatted_dt = dt.strftime('%Y-%m-%d')
    file_dt = dt.strftime('%Y%m%d')

    if not os.path.isfile(f'{rp_path}/ravenpack_city_articles_{file_dt}.gzip'):
        (db
         .raw_sql(f"""select *
         from ravenpack_full.rpa_full_global_macro_{yr}
         where rpa_date_utc = '{formatted_dt}' 
         and rp_entity_id IN ({','.join(map( lambda x: f"'{x}'", city_ids))})""")
         .to_parquet(f'{rp_path}/ravenpack_city_articles_{file_dt}.gzip', compression = 'gzip', index=False)
         )

        print(f'Year {dt} downloaded')
    else:
        print(f'Year {dt} already downloaded')
 def date_range(start_date, end_date):
     current_date = start_date
     while current_date <= end_date:
         yield current_date
         current_date += timedelta(days=1)

[download_daily_ravenpack(dt) for dt in date_range(datetime(2020,6,1), datetime(2024,12,31))]