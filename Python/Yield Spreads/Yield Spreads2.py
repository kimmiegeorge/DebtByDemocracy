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

sveny_cols = sorted([col for col in yield_curve.columns if 'SVENY' in col])

yield_curve = (yield_curve
               .select(['Date', *sveny_cols])
               .with_columns(pl.col('Date').str.to_date(format = '%m/%d/%y'))
               .filter(pl.col('Date').dt.year().is_between(2000, 2026)))

# convert SVENY columns from string to float (decimal), NA -> null
yield_curve = (yield_curve
               .with_columns([pl.col(c).replace('NA', None).alias(c) for c in sveny_cols])
               .with_columns([pl.col(c).cast(pl.Float64).truediv(100).alias(c) for c in sveny_cols])
               # create list column with full zero curve for each date (index 0 = 1yr, ..., 29 = 30yr)
               .with_columns(pl.concat_list(sveny_cols).alias('zero_curve'))
               .select(['Date', 'zero_curve']))



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

# merge full zero curve by offering date
mergent = (mergent
            .with_columns(pl.col('offering_date').cast(pl.Date))
           .join(yield_curve.rename({'Date': 'offering_date'}),
                 on = 'offering_date', how = 'left'))

del yield_curve

#%%------------------------------------
# adjust to semi annual
#------------------------------------

# semi-annual coupon and period count
mergent = (mergent
            .with_columns(pl.col('maturity_yrs').mul(2).alias('semi_annual_payments'))
            .with_columns(pl.col('coupon').truediv(2).alias('semi_annual_coupon')))


#%%------------------------------------
# functions for pv and irr
#------------------------------------

def interp_zero_rate(zero_curve, tau):
    """Linearly interpolate the zero-coupon rate for maturity tau (in years).
    zero_curve is a list of 30 rates at integer maturities 1..30."""
    if tau <= 1:
        r = zero_curve[0]
        return r
    if tau >= 30:
        r = zero_curve[29]
        return r
    lower = int(np.floor(tau))   # e.g., 1 for tau=1.5
    upper = lower + 1            # e.g., 2
    frac = tau - lower           # e.g., 0.5
    r_lower = zero_curve[lower - 1]  # 0-indexed
    r_upper = zero_curve[upper - 1]
    if r_lower is None or r_upper is None:
        return None
    return r_lower + frac * (r_upper - r_lower)


def get_pv_semi(struct):
    cpn = struct['semi_annual_coupon']
    cpn_periods = int(struct['semi_annual_payments'])
    zero_curve = struct['zero_curve']  # list of 30 annual zero-coupon rates
    fv = struct['maturity_amount']

    pv = 0.0
    for t in range(1, cpn_periods + 1):
        tau = t / 2  # exact maturity in years
        r = interp_zero_rate(zero_curve, tau)
        if r is None:
            return None

        # cash flow at period t
        cf = cpn if t < cpn_periods else cpn + fv
        pv += cf / (1 + r) ** tau

    return pv

def get_pv_maturity(struct):
    cpn = struct['coupon']
    cpn_periods = int(struct['maturity_yrs'])
    zero_curve = struct['zero_curve']  # list of 30 annual zero-coupon rates
    fv = struct['maturity_amount']
    # calculate interest payment at maturity
    int_payment = (cpn / 100) * cpn_periods * fv

    pv = 0.0
    for t in range(1, cpn_periods + 1):
        tau = float(t)  # maturity in years
        r = interp_zero_rate(zero_curve, tau)
        if r is None:
            return None

        cf = 0 if t < cpn_periods else int_payment + fv
        pv += cf / (1 + r) ** tau

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

    return ytm * 2  # annualize: semi-annual rate -> bond-equivalent yield


def get_ytm_maturity(struct):
    pv = struct['total_pv']
    cpn = struct['coupon']
    cpn_periods = int(struct['maturity_yrs'])
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
                       pl.col('semi_annual_payments'),
                       pl.col('maturity_amount'),
                       pl.col('zero_curve')).alias('pv_inputs_semi'),
                                pl.struct(pl.col('coupon'),
                                          pl.col('maturity_yrs'),
                                          pl.col('maturity_amount'),
                                          pl.col('zero_curve')).alias('pv_inputs_maturity')))

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
    mergent_semi.select(['issue_id', 'interest_frequency', 'cusip', 'offering_yield', 'ytm', 'offering_date']),
    mergent_maturity.select(['issue_id', 'interest_frequency', 'cusip', 'offering_yield', 'ytm', 'offering_date'])
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
mergent_full.select(['issue_id', 'cusip', 'offering_yield_spread']).write_csv(f'{data_dir}/Mergent/Clean/260324_bond_level_off_yield_spread.csv')
