'''
Adjust yields for matched treasury yield

From Gao et al. (2020):

We calculate the yield on the coupon-equivalent risk-free bond as follows.
For each municipal bond, we calculate the present value of its coupon payments and face value using the US Treasury yield curve,
which is based on the zero-coupon yield curve estimated in Gürkaynak et al. (2007).
This gives us the price of the coupon-equivalent risk-free bond.
The risk-free yield-to-maturity is then calculated using this price, the coupon payments,
and the face value payment.
The yield spread is calculated as the difference between the municipal bond yield and the risk- free yield-to-maturity.
This is similar to the yield spread calculation in Longstaff et al. (2005).
'''

#%%------------------------------------
# set up
#------------------------------------

import polars as pl
import yfinance as yf
import pandas as pd
import numpy as np
import numpy_financial as npf

pl.Config(tbl_cols=100,
		  tbl_width_chars=1000)


data_dir = '~/Dropbox/Voting on Bonds/Data'

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

mergent = (mergent
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
mergent = (mergent
           .with_columns(pl.col('maturity_date').sub(pl.col('offering_date')).dt.total_days()
                         .truediv(365).round().cast(pl.Int64).alias('maturity_yrs'))
           .filter(pl.col('maturity_yrs').is_between(1, 30)))

# filter to semiannual interest or interest at maturity only
mergent = (mergent
           .filter(pl.col('interest_frequency').eq(pl.lit('Z')) |
                                                   pl.col('interest_frequency').eq(pl.lit('S'))))

# merge
mergent = (mergent
            .with_columns(pl.col('offering_date').cast(pl.Date))
           .join(yield_melt.rename({'Date': 'offering_date'}),
                 left_on = ['offering_date', 'maturity_yrs'],
                 right_on = ['offering_date', 'zero_coupon_maturity'], how = 'left'))

del yield_melt
del yield_curve

#%%------------------------------------
# adjust to semi annual
#------------------------------------

# present value of face value and coupon payments
mergent = (mergent
            .with_columns(pl.col('zero_coupon_yield').truediv(2).alias('semi_annual_zero_yield'))
            .with_columns(pl.col('maturity_yrs').mul(2).alias('semi_annual_payments'))
            .with_columns(pl.col('coupon').truediv(2).alias('semi_annual_coupon')))


#%%------------------------------------
# functions for pv and irr
#------------------------------------

def get_pv_semi(struct):
    cpn = struct['semi_annual_coupon']
    cpn_periods = struct['semi_annual_payments']
    r = struct['semi_annual_zero_yield']
    fv = struct['maturity_amount']
    # Initialize cash_sequence
    cash_sequence = [0] # initialize with zero initial investment, then start the coupon payments
    cash_sequence.extend([cpn] * (cpn_periods - 1))
    # Add the sum of the last coupon payment and the face value
    cash_sequence.append(cpn + fv)
    pv = npf.npv(r, cash_sequence)

    return pv

def get_pv_maturity(struct):
    cpn = struct['coupon']
    cpn_periods = struct['maturity_yrs']
    r = struct['zero_coupon_yield']
    fv = struct['maturity_amount']
    # calculate interest payment at maturity
    int_payment = (cpn/100) * cpn_periods * fv
    cash_sequence = [0] # initialize with zero initial investment, then start the coupon payments
    cash_sequence.extend([0] * (cpn_periods - 1))
    # Add the sum of the last coupon payment and the face value
    cash_sequence.append(int_payment + fv)
    pv = npf.npv(r, cash_sequence)
    return pv


def get_ytm_semi(struct):
    pv = struct['total_pv']
    cpn = struct['semi_annual_coupon']
    cpn_periods = struct['semi_annual_payments']
    fv = struct['maturity_amount']
    # Initialize cash_sequence with -pv
    cash_sequence = [-pv]
    # Add semi-annual coupon payment for cpn_periods times
    cash_sequence.extend([cpn] * (cpn_periods-1))
    # Add the sum of the last coupon payment and the face value
    cash_sequence.append(cpn + fv)
    ytm = npf.irr(cash_sequence)

    return ytm


def get_ytm_maturity(struct):
    pv = struct['total_pv']
    cpn = struct['coupon']
    cpn_periods = struct['maturity_yrs']
    fv = struct['maturity_amount']
    # Initialize cash_sequence with -pv
    cash_sequence = [-pv]
    # Add semi-annual coupon payment for cpn_periods times
    cash_sequence.extend([0] * (cpn_periods-1))
    # Add the sum of the last coupon payment and the face value
    int_payment = (cpn/100) * cpn_periods * fv
    cash_sequence.append(int_payment + fv)
    ytm = npf.irr(cash_sequence)

    return ytm

#%%------------------------------------
# calculate pv
#------------------------------------
# inputs
mergent = (mergent.with_columns(pl.struct(pl.col('semi_annual_coupon'),
                       pl.col('semi_annual_zero_yield'),
                       pl.col('semi_annual_payments'),
                       pl.col('maturity_amount')).alias('pv_inputs_semi'),
                                pl.struct(pl.col('coupon'),
                                          pl.col('zero_coupon_yield'),
                                          pl.col('maturity_yrs'),
                                          pl.col('maturity_amount')).alias('pv_inputs_maturity')))

# calculate yield to maturity
mergent_semi = (mergent
            # filter to semiannual interest only
            .filter(pl.col('interest_frequency').eq(pl.lit('Z')))
            .with_columns(pl.col('pv_inputs_semi').map_elements(get_pv_semi, return_dtype=pl.Float64).alias('total_pv')))

mergent_maturity = (mergent
            # filter to semiannual interest only
            .filter(pl.col('interest_frequency').eq(pl.lit('S')))
            .with_columns(pl.col('pv_inputs_maturity').map_elements(get_pv_maturity, return_dtype=pl.Float64).alias('total_pv')))



#%%------------------------------------
# calculate ytm
#------------------------------------
# inputs for ytm
mergent_semi = (mergent_semi.with_columns(pl.struct(pl.col('total_pv'),
                       pl.col('semi_annual_coupon'),
                       pl.col('semi_annual_payments'),
                       pl.col('maturity_amount')).alias('ytm_inputs_semi')))

mergent_maturity = (mergent_maturity.with_columns(pl.struct(pl.col('total_pv'),
                       pl.col('coupon'),
                       pl.col('maturity_yrs'),
                       pl.col('maturity_amount')).alias('ytm_inputs_maturity')))
# calculate yield to maturity
mergent_semi = (mergent_semi
           .with_columns(pl.col('ytm_inputs_semi').map_elements(get_ytm_semi, return_dtype=pl.Float64).alias('ytm')))

mergent_maturity = (mergent_maturity
           .with_columns(pl.col('ytm_inputs_maturity').map_elements(get_ytm_maturity, return_dtype=pl.Float64).alias('ytm')))


#%%------------------------------------
# combine semiannual and maturity
#------------------------------------

mergent_full = (pl.concat([
    mergent_semi.select(['issue_id', 'interest_frequency', 'cusip', 'offering_yield', 'ytm']),
    mergent_maturity.select(['issue_id', 'interest_frequency', 'cusip', 'offering_yield', 'ytm'])
]))

#%%------------------------------------
# calculate yield spread
#------------------------------------
mergent_full = (mergent_full
           .with_columns(pl.col('offering_yield')
                         .sub(pl.col('ytm').mul(100)).alias('offering_yield_spread')))

#%%------------------------------------
# save
#------------------------------------
mergent_full.select(['issue_id', 'cusip', 'offering_yield_spread']).write_csv(f'{data_dir}/Mergent/Clean/250701_bond_level_off_yield_spread.csv')
