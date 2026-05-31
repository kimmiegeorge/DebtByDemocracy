'''
download ravenpack macro files locally
'''
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import calendar
import datetime
import glob
import os
import pandas as pd
import wrds
import re
from tqdm import tqdm
db = wrds.Connection()

temp_date = datetime.datetime.now()
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
pull data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


rp_path = '/Users/kmunevar/WRDS_202408/Ravenpack_Macro'

def download_monthly_ravenpack(yr, mnth):
    end_date = calendar.monthrange(yr,mnth)[1]

    if not os.path.isfile(f'{rp_path}/ravenpack_full_rpa_full_macro_{yr}_{mnth}.gzip'):
        (db
         .raw_sql(f"""select *
         from ravenpack_full.rpa_full_global_macro_{yr}
         where rpa_date_utc >= '{yr}-{mnth}-01' and
         rpa_date_utc <= '{yr}-{mnth}-{end_date}'""")
         .to_parquet(f'{rp_path}/ravenpack_full_rpa_full_macro_{yr}_{mnth}.gzip', compression = 'gzip', index=False)
         )

        print(f'Year {yr} Month {mnth} downloaded')
    else:
        print(f'Year {yr} Month {mnth} already downloaded')

[download_monthly_ravenpack(yr, mth) for yr in range(2000, temp_date.year) for mth in range(1, 13)]

