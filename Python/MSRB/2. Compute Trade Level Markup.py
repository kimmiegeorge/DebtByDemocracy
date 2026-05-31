'''
Compute trade-level Markup following Cuny(2018) JAE
Markup = TradeSign (1 or -1) * 10,000 * ln(Customer Price/ Avg Interdealer Price)
Can only be computed for bonds tha thave at least one inter-dealer trade occurring on the same day

Following Schultz (2011) and Cuny (2018), trades with par values less than 100,000 are likely to be executed by retail customers
Follow Schultz(2011) and Cuny (2018) and further partition retail trade category into those under 25,000 (small retail) and greater than
25,000 (large retail)
Follow Cuny (2018) and futher paritition institutional trade category into those less than 250,000 (small institutional) and those
greater than or equal to 250,000 (large institutional)
'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl

data_dir = '~/Dropbox/Voting on Bonds/Data/MSRB'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Compute daily average interdealer price for each bond 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
inter_dealer_price = (pl
                      .scan_parquet(f'{data_dir}/Raw Files/*')
                      # filter to interdealer trades (trade type = D)
                      .filter(pl.col('trade_type_indicator').eq('D'))
                      # filter to positive dollar_price
                      .filter(pl.col('dollar_price').gt(0))
                      # group by bond and trade date
                      .group_by(['cusip', 'trade_date'])
                      # compute average price
                      .agg(pl.col('dollar_price').mean().alias('AvgInterdealerPrice'))
                      # collect to memory
                      .collect(streaming = True)
                      )
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Compute markup for trades and create indicators for retail and institutional trades
*Note* trade_type_indicator = P for a purchase from a customer by a dealer, S for a sale to a customer by a dealer 
From customer perspective, P is a sale and S is a purchase 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
markup = (pl
          .scan_parquet(f'{data_dir}/Raw Files/*')
          .select(['cusip', 'dated_date', 'trade_date', 'trade_type_indicator', 'dollar_price', 'par_traded'])
          # only keep customer transactions (purchases and sales)
          .filter(pl.col('trade_type_indicator').is_in(['P', 'S']))
          # drop observations with missing price
          .filter(pl.col('dollar_price').is_not_null())
          # create trade sign variable
          .with_columns(trade_sign = pl.when(pl.col('trade_type_indicator').eq('S')).then(1).otherwise(-1))
          # merge with inter dealer price, only keeping observations that do have an inter-dealer trade
          .join(inter_dealer_price.lazy(), on = ['cusip', 'trade_date'], how = 'inner')
          # compute markup
          .with_columns(markup = pl.col('trade_sign') * 10000 * ((pl.col('dollar_price') / pl.col('AvgInterdealerPrice')).log()))
          # follow  Cuny (2018) and Chordia et al. (2001) and drop markups that are negative (uncommon)
          .filter(pl.col('markup').ge(0))
          # create indicators for retail and institutional trades
          # first adjust dtype for par traded
          .with_columns(par_traded = pl.when(pl.col('par_traded').eq("1MM+")).then(pl.lit('1000000')).otherwise(pl.col('par_traded')))
          .with_columns(pl.col('par_traded').cast(pl.Float64))
          .with_columns(retail = pl.when(pl.col('par_traded').lt(100000)).then(1).otherwise(0),
                        institutional = pl.when(pl.col('par_traded').ge(100000)).then(1).otherwise(0))
          # create indicators for small and large retail trades
          .with_columns(small_retail = pl.when(pl.col('par_traded').lt(25000)).then(1).otherwise(0),
                        large_retail = pl.when(pl.col('retail').eq(1) & pl.col('par_traded').ge(25000)).then(1).otherwise(0))
          # create indicators for small and large institutional trades
          .with_columns(small_institutional = pl.when(pl.col('institutional').eq(1) & pl.col('par_traded').lt(250000)).then(1).otherwise(0),
                        large_institutional = pl.when(pl.col('par_traded').ge(250000)).then(1).otherwise(0))
          # collect to memory
          .collect(streaming = True)
          )

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
markup.write_parquet(f'{data_dir}/Processed/All_Trade_Markup_2005_2023.gzip')