'''
July 1, 2025 - June discovered 5000 bonds with missing yield spreads
Investigate why these yield spreads are missing
'''


#%%------------------------------------
# set up
#------------------------------------

import polars as pl
import pandas as pd
import yfinance as yf
import pandas as pd
import numpy as np
import numpy_financial as npf

pl.Config(tbl_cols=100,
		  tbl_width_chars=1000)


data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%------------------------------------
# load missing observations
#------------------------------------
missing_obs = pl.DataFrame(
    pd.read_stata(f'{data_dir}/Mergent/Clean/250630_cityyieldspread_unmatched.dta')
)

#%%------------------------------------
# start initial procedure
#------------------------------------

obs = (pl.read_csv(f'{data_dir}/Mergent/Clean/250701_bond_level_off_yield_spread.csv'))

missing = (obs
           .filter(pl.col('cusip').is_in(missing_obs.select('cusip').to_series().to_list())))

#%%------------------------------------
# load mergent data
#------------------------------------
mergent = (pl
           .DataFrame(
    pd
    .read_stata(f'{data_dir}/Mergent/Clean/250313_citycountyschool_cusiplevel_statereq_purpose.dta')
)
            .select(['issue_id', 'cusip', 'maturity_date', 'offering_yield', 'offering_price',
                     'offering_date', 'maturity_mths', 'coupon'])
)
#%%------------------------------------
# identify missing obs
#------------------------------------
mergent_missing = (mergent
                   .filter(pl.col('cusip').is_in(missing_obs.select('cusip').to_series().to_list())))

#%%------------------------------------
# Add additional needed bond information
#------------------------------------
coupon = (pd.read_csv(f'{data_dir}/Mergent/Raw/BONDINFO.DLM', delimiter = '|'))
coupon = coupon[['issue_id_l', 'cusip_c', 'coupon_code_c', 'maturity_amount_f',
                 'interest_frequency_i']]
coupon = pl.DataFrame(coupon)
coupon = (coupon
          .rename({'issue_id_l': 'issue_id',
                   'cusip_c': 'cusip',
                   'coupon_code_c': 'coupon_code',
                   'maturity_amount_f': 'maturity_amount',
                   'interest_frequency_i': 'interest_frequency'}))

mergent_missing = (mergent_missing
            .with_columns(pl.col('issue_id').cast(pl.Int64))
           .join(coupon, on = ['issue_id', 'cusip'], how = 'left'))

del coupon

#%%------------------------------------
# load yield curve data
#------------------------------------
yield_curve = (pl
               .read_csv(f'{data_dir}/Nominal Yield Curve/nominal_yield_curve.csv'))

yield_curve = (yield_curve                # select date and columns containing 'SVENY'
               .select(['Date',
     *[col for col in yield_curve.columns if 'SVENY' in col]]))

yield_curve = (yield_curve
               .with_columns(pl.col('Date').str.to_date(format = '%m/%d/%y'))
               .filter(pl.col('Date').dt.year().is_between(2000, 2026)))

# reshape to have 30 observations per date - one for each maturity
yield_melt = (yield_curve
              .unpivot(index=['Date'], on=[c for c in yield_curve.columns if 'SVENY' in c],
                    variable_name='zero_coupon_maturity', value_name='zero_coupon_yield'))

# adjust maturity to just be int value
# and adjust coupon rate to be in percent
yield_melt = (yield_melt
              .with_columns(pl.col('zero_coupon_maturity').str.slice(-2).cast(pl.Int64))
                .filter(pl.col('zero_coupon_yield').ne('NA'))
              .with_columns(pl.col('zero_coupon_yield').cast(pl.Float64).truediv(100)))

#%%------------------------------------
# Match to closest zero coupon from yield curve
#------------------------------------

# first, get maturity in years
mergent_missing = (mergent_missing
           .with_columns(pl.col('maturity_date').sub(pl.col('offering_date')).dt.total_days()
                         .truediv(365).round().cast(pl.Int64).alias('maturity_yrs'))
           .filter(pl.col('maturity_yrs').is_between(1, 30)))

# filter to semiannual interest only
mergent_missing = (mergent_missing
           .filter(pl.col('interest_frequency').eq(pl.lit('Z'))))

# merge
mergent = (mergent
            .with_columns(pl.col('offering_date').cast(pl.Date))
           .join(yield_melt.rename({'Date': 'offering_date'}),
                 left_on = ['offering_date', 'maturity_yrs'],
                 right_on = ['offering_date', 'zero_coupon_maturity'], how = 'left'))

#del yield_melt
#del yield_curve


