'''
Aggregate liquidity measurse and yields at the bond level using Mergent data
'''


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import os
import pandas as pd
import numpy as np

data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load needed data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuances = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/250828_city_cusiplevel_statereq_purpose_yieldspread.dta'))
             .select(['issue_id', 'cusip',
                      'offering_date']))

liquidity = (pl
             .read_parquet(f'{data_dir}/MSRB/Processed/All_Trade_Markup_2005_2023.gzip')
             )

# Winsorize markup at 1% and 99% percentiles
liquidity = liquidity.with_columns(
    pl.col('markup').clip(
        lower_bound=pl.col('markup').quantile(0.01),
        upper_bound=pl.col('markup').quantile(0.99)
    )
)

# load yield spreads
yields = (pl
          .read_parquet(f'{data_dir}/MSRB/Processed/All_Trade_Yields_2005_2023.gzip'))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
get daily price dispersion
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
daily_price_dispersion = (liquidity

                          .with_columns(pl.col('dollar_price').count().over(['cusip', 'trade_date']).alias('total_trades'),
                               pl.col('retail').sum().over(['cusip', 'trade_date']).alias('retail_trades'),
                               pl.col('institutional').sum().over(['cusip', 'trade_date']).alias('institutional_trades'))
                            .group_by(['cusip', 'trade_date'])
                            .agg(pl.col('dollar_price').filter(pl.col('total_trades').gt(1)).std().alias('all_trade_price_dispersion'),
                                 pl.col('dollar_price').filter((pl.col('retail').eq(1)) & (pl.col('retail_trades').gt(1))).std().alias('retail_trade_price_dispersion'),
                                 pl.col('dollar_price').filter((pl.col('institutional').eq(1)) & (pl.col('institutional_trades').gt(1))).std().alias('institutional_trade_price_dispersion'))
                          )


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Aggregate liquidity to bond level 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
liquidity_3yr = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             .join(daily_price_dispersion, on = ['cusip', 'trade_date'], how = 'left')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days = 3 * 365)))
             # group by issue_id and aggregate
             .group_by('cusip', 'issue_id')
                 .agg(pl.col('offering_date').count().alias('number_of_trades_3yr'),
                        pl.col('offering_date').filter(pl.col('retail').eq(1)).count().alias('number_of_retail_trades_3yr'),
pl.col('offering_date').filter(pl.col('institutional').eq(1)).count().alias('number_of_institutional_trades_3yr'),
                      pl.col('markup').mean().alias('markup_3yr'),
                      pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_3yr'),
                      pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_3yr'),
                      pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_3yr'),
                      pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_3yr'),
                      pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias(
                          'markup_small_institutional_3yr'),
                      pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias(
                          'markup_large_institutional_3yr'),
                      # Buy markup calculations (trade_sign = 1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_3yr'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_retail_buy_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_retail_buy_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_retail_buy_3yr'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_institutional_buy_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_institutional_buy_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_institutional_buy_3yr'),
                      # Sell markup calculations (trade_sign = -1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_3yr'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_retail_sell_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_retail_sell_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_retail_sell_3yr'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_institutional_sell_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_institutional_sell_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_institutional_sell_3yr'),
                      # price dispersion measures
                        pl.col('all_trade_price_dispersion').filter(pl.col('all_trade_price_dispersion').is_not_null()).mean().alias('all_trade_price_dispersion_3yr'),
                        pl.col('retail_trade_price_dispersion').filter(pl.col('retail_trade_price_dispersion').is_not_null()).mean().alias('retail_price_dispersion_3yr'),
                        pl.col('institutional_trade_price_dispersion').filter(pl.col('institutional_trade_price_dispersion').is_not_null()).mean().alias('institutional_price_dispersion_3yr'),
    ))





liquidity_2_3yr = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days = 3 * 365)))
            # drop 1 year after offering date
                .filter(pl.col('trade_date').gt(pl.col('offering_date') + pl.duration(days = 365)))
             # group by issue_id and aggregate
             .group_by('cusip', 'issue_id')
                 .agg(pl.col('offering_date').count().alias('number_of_trades_2_3yr'),
                        pl.col('offering_date').filter(pl.col('retail').eq(1)).count().alias('number_of_retail_trades_2_3yr'),
pl.col('offering_date').filter(pl.col('institutional').eq(1)).count().alias('number_of_institutional_trades_2_3yr'),
                      pl.col('markup').mean().alias('markup_2_3yr'),
                      pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_2_3yr'),
                      pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_2_3yr'),
                      pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_2_3yr'),
                      pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_2_3yr'),
                      pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias(
                          'markup_small_institutional_3yr'),
                      pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias(
                          'markup_large_institutional_3yr'),
                      # Buy markup calculations (trade_sign = 1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_2_3yr'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_retail_buy_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_retail_buy_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_retail_buy_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_institutional_buy_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_institutional_buy_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_institutional_buy_2_3yr'),
                      # Sell markup calculations (trade_sign = -1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_2_3yr'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_retail_sell_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_retail_sell_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_retail_sell_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_institutional_sell_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_institutional_sell_2_3yr'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_institutional_sell_2_3yr')
    ))

liquidity_1yr = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days = 365)))
             # group by issue_id and aggregate
             .group_by('cusip', 'issue_id')
                 .agg(pl.col('dated_date').count().alias('number_of_trades_1yr'),
pl.col('offering_date').filter(pl.col('retail').eq(1)).count().alias('number_of_retail_trades_1yr'),
pl.col('offering_date').filter(pl.col('institutional').eq(1)).count().alias('number_of_institutional_trades_1yr'),
                      pl.col('markup').mean().alias('markup_1yr'),
                      pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_1yr'),
                      pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_1yr'),
                      pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_1yr'),
                      pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_1yr'),
                      pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias(
                          'markup_small_institutional_1yr'),
                      pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias(
                          'markup_large_institutional_1yr'),
                      # Buy markup calculations (trade_sign = 1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_1yr'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_retail_buy_1yr'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_retail_buy_1yr'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_retail_buy_1yr'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_institutional_buy_1yr'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_institutional_buy_1yr'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_institutional_buy_1yr'),
                      # Sell markup calculations (trade_sign = -1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_1yr'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_retail_sell_1yr'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_retail_sell_1yr'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_retail_sell_1yr'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_institutional_sell_1yr'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_institutional_sell_1yr'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_institutional_sell_1yr')
    ))

liquidity_6mo = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days = 183)))
             # group by issue_id and aggregate
             .group_by('cusip', 'issue_id')
                 .agg(pl.col('dated_date').count().alias('number_of_trades_6mo'),
pl.col('offering_date').filter(pl.col('retail').eq(1)).count().alias('number_of_retail_trades_6mo'),
pl.col('offering_date').filter(pl.col('institutional').eq(1)).count().alias('number_of_institutional_trades_6mo'),
                      pl.col('markup').mean().alias('markup_6mo'),
                      pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_6mo'),
                      pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_6mo'),
                      pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_6mo'),
                      pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_6mo'),
                      pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias(
                          'markup_small_institutional_6mo'),
                      pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias(
                          'markup_large_institutional_6mo'),
                      # Buy markup calculations (trade_sign = 1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_6mo'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_retail_buy_6mo'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_retail_buy_6mo'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_retail_buy_6mo'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_institutional_buy_6mo'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_small_institutional_buy_6mo'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias(
                          'markup_large_institutional_buy_6mo'),
                      # Sell markup calculations (trade_sign = -1)
                      pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_6mo'),
                      pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_retail_sell_6mo'),
                      pl.col('markup').filter(
                          (pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_retail_sell_6mo'),
                      pl.col('markup').filter(
                          (pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_retail_sell_6mo'),
                      pl.col('markup').filter(
                          (pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_institutional_sell_6mo'),
                      pl.col('markup').filter(
                          (pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_small_institutional_sell_6mo'),
                      pl.col('markup').filter(
                          (pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias(
                          'markup_large_institutional_sell_6mo')
    ))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Aggregate yield spreads to issuance level 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
yields_3yr = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days = 3*365)))
          # group by issue_id and compute standard deviation of yield
          .group_by('cusip', 'issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_3yr'))
          )


yields_2_3yr = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days = 3*365)))
             # drop 1 year after offering date
          .filter(pl.col('trade_date').gt(pl.col('offering_date') + pl.duration(days = 365)))
          # group by issue_id and compute standard deviation of yield
          .group_by('cusip', 'issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_2_3_yr'))
          )


yields_1yr = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days = 365)))
          # group by issue_id and compute standard deviation of yield
          .group_by('cusip', 'issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_1yr'))
          )

yields_6mo = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days = 183)))
          # group by issue_id and compute standard deviation of yield
          .group_by('cusip', 'issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_6mo'))
          )


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
combine yields and liquidity
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
liquidity = (liquidity_1yr
             .join(liquidity_6mo, on = ['cusip', 'issue_id'], how = 'inner')
             .join(liquidity_3yr, on =  ['cusip', 'issue_id'], how = 'inner')
             .join(liquidity_2_3yr, on =  ['cusip', 'issue_id'], how = 'inner'))

yields = (yields_1yr
          .join(yields_3yr, on =  ['cusip', 'issue_id'], how = 'inner')
          .join(yields_6mo, on =  ['cusip', 'issue_id'], how = 'inner')
          .join(yields_2_3yr, on =  ['cusip', 'issue_id'], how = 'inner'))

issuance_level = (liquidity
                  .join(yields, on =  ['cusip', 'issue_id'], how = 'full'))
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
add all other variables
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
bond_data = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/250828_city_cusiplevel_statereq_purpose_yieldspread.dta'))
             )

issuance_level = (issuance_level
                  .join(bond_data, on = ['cusip', 'issue_id'], how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
(issuance_level
 .write_parquet(f'{data_dir}/MSRB/Processed/Bond_Level_Secondary_Market_Vars_With_Bond_Vars_2005_2023.gzip'))

(issuance_level
 .write_csv(f'{data_dir}/MSRB/Processed/Bond_Level_Secondary_Market_Vars_With_Bond_Vars_2005_2023.csv'))