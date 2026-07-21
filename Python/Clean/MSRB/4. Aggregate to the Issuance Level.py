'''
Aggregate liquidity measurse and yields at the issuance level using Mergent data
'''


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import pandas as pd
from pathlib import Path

project_dir = Path(__file__).resolve().parents[4]
data_dir = project_dir / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
msrb_processed_dir = clean_data_dir / 'MSRB' / 'Processed'
msrb_processed_dir.mkdir(parents=True, exist_ok=True)

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load needed data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuances = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'))
             .select(['issue_id', 'cusip',
                      'offering_date']))

liquidity = (pl
             .read_parquet(msrb_processed_dir / 'All_Trade_Markup_2005_2023.gzip')
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
          .read_parquet(msrb_processed_dir / 'All_Trade_Yields_2005_2023.gzip'))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Aggregate liquidity to issuance level 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
liquidity_3yr = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days=3 * 365)))
             # group by issue_id and aggregate
             .group_by('issue_id')
             .agg(pl.col('offering_date').count().alias('number_of_trades_3yr'),
                  pl.col('markup').mean().alias('markup_3yr'),
                  pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_3yr'),
                  pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_3yr'),
                  pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_3yr'),
                  pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_3yr'),
                  pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias('markup_small_institutional_3yr'),
                  pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias('markup_large_institutional_3yr'),
                  # Buy markup calculations (trade_sign = 1)
                  pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_3yr'),
                  pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_retail_buy_3yr'),
                  pl.col('markup').filter((pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_small_retail_buy_3yr'),
                  pl.col('markup').filter((pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_large_retail_buy_3yr'),
                  pl.col('markup').filter((pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_institutional_buy_3yr'),
                  pl.col('markup').filter((pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_small_institutional_buy_3yr'),
                  pl.col('markup').filter((pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_large_institutional_buy_3yr'),
                  # Sell markup calculations (trade_sign = -1)
                  pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_3yr'),
                  pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_retail_sell_3yr'),
                  pl.col('markup').filter((pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_small_retail_sell_3yr'),
                  pl.col('markup').filter((pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_large_retail_sell_3yr'),
                  pl.col('markup').filter((pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_institutional_sell_3yr'),
                  pl.col('markup').filter((pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_small_institutional_sell_3yr'),
                  pl.col('markup').filter((pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_large_institutional_sell_3yr')
    ))

liquidity_1yr = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days=365)))
             # group by issue_id and aggregate
             .group_by('issue_id')
             .agg(pl.col('dated_date').count().alias('number_of_trades_1yr'),
                  pl.col('markup').mean().alias('markup_1yr'),
                  pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_1yr'),
                  pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_1yr'),
                  pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_1yr'),
                  pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_1yr'),
                  pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias('markup_small_institutional_1yr'),
                  pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias('markup_large_institutional_1yr'),
                  # Buy markup calculations (trade_sign = 1)
                  pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_1yr'),
                  pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_retail_buy_1yr'),
                  pl.col('markup').filter((pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_small_retail_buy_1yr'),
                  pl.col('markup').filter((pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_large_retail_buy_1yr'),
                  pl.col('markup').filter((pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_institutional_buy_1yr'),
                  pl.col('markup').filter((pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_small_institutional_buy_1yr'),
                  pl.col('markup').filter((pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_large_institutional_buy_1yr'),
                  # Sell markup calculations (trade_sign = -1)
                  pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_1yr'),
                  pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_retail_sell_1yr'),
                  pl.col('markup').filter((pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_small_retail_sell_1yr'),
                  pl.col('markup').filter((pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_large_retail_sell_1yr'),
                  pl.col('markup').filter((pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_institutional_sell_1yr'),
                  pl.col('markup').filter((pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_small_institutional_sell_1yr'),
                  pl.col('markup').filter((pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_large_institutional_sell_1yr')
    ))

liquidity_6mo = (liquidity
             .join(issuances, on = 'cusip', how = 'inner')
             # keep first 3 years after dated_date
             .filter(pl.col('trade_date').le(pl.col('offering_date') + pl.duration(days=183)))
             # group by issue_id and aggregate
             .group_by('issue_id')
             .agg(pl.col('dated_date').count().alias('number_of_trades_6mo'),
                  pl.col('markup').mean().alias('markup_6mo'),
                  pl.col('markup').filter(pl.col('retail').eq(1)).mean().alias('markup_retail_6mo'),
                  pl.col('markup').filter(pl.col('small_retail').eq(1)).mean().alias('markup_small_retail_6mo'),
                  pl.col('markup').filter(pl.col('large_retail').eq(1)).mean().alias('markup_large_retail_6mo'),
                  pl.col('markup').filter(pl.col('institutional').eq(1)).mean().alias('markup_institutional_6mo'),
                  pl.col('markup').filter(pl.col('small_institutional').eq(1)).mean().alias('markup_small_institutional_6mo'),
                  pl.col('markup').filter(pl.col('large_institutional').eq(1)).mean().alias('markup_large_institutional_6mo'),
                  # Buy markup calculations (trade_sign = 1)
                  pl.col('markup').filter(pl.col('trade_sign').eq(1)).mean().alias('markup_buy_6mo'),
                  pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_retail_buy_6mo'),
                  pl.col('markup').filter((pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_small_retail_buy_6mo'),
                  pl.col('markup').filter((pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_large_retail_buy_6mo'),
                  pl.col('markup').filter((pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_institutional_buy_6mo'),
                  pl.col('markup').filter((pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_small_institutional_buy_6mo'),
                  pl.col('markup').filter((pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(1))).mean().alias('markup_large_institutional_buy_6mo'),
                  # Sell markup calculations (trade_sign = -1)
                  pl.col('markup').filter(pl.col('trade_sign').eq(-1)).mean().alias('markup_sell_6mo'),
                  pl.col('markup').filter((pl.col('retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_retail_sell_6mo'),
                  pl.col('markup').filter((pl.col('small_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_small_retail_sell_6mo'),
                  pl.col('markup').filter((pl.col('large_retail').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_large_retail_sell_6mo'),
                  pl.col('markup').filter((pl.col('institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_institutional_sell_6mo'),
                  pl.col('markup').filter((pl.col('small_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_small_institutional_sell_6mo'),
                  pl.col('markup').filter((pl.col('large_institutional').eq(1)) & (pl.col('trade_sign').eq(-1))).mean().alias('markup_large_institutional_sell_6mo')
    ))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Aggregate yield spreads to issuance level 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
yields_3yr = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days=3 * 365)))
          # group by issue_id and compute standard deviation of yield
          .group_by('issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_3yr'))
          )

yields_1yr = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days=365)))
          # group by issue_id and compute standard deviation of yield
          .group_by('issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_1yr'))
          )

yields_6mo = (yields
          .join(issuances, on = 'cusip', how = 'inner')
          # keep first 3 years after dated date
          .filter(pl.col('trade_date').lt(pl.col('offering_date') + pl.duration(days=365)))
          # group by issue_id and compute standard deviation of yield
          .group_by('issue_id')
          .agg(pl.col('yield').std().alias('yield_volatility_6mo'))
          )


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
combine yields and liquidity
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
liquidity = (liquidity_1yr
             .join(liquidity_6mo, on = 'issue_id', how = 'inner')
             .join(liquidity_3yr, on = 'issue_id', how = 'inner'))

yields = (yields_1yr
          .join(yields_3yr, on = 'issue_id', how = 'inner')
          .join(yields_6mo, on = 'issue_id', how = 'inner'))

issuance_level = (liquidity
                  .join(yields, on = 'issue_id', how = 'full'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
(issuance_level
 .drop([ 'issue_id_right'])
 .write_parquet(msrb_processed_dir / 'Issuance_Level_Secondary_Market_Vars_2005_2023.gzip'))
