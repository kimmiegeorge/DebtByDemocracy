'''
Create Trade-Level Regression Dataset

Also aggregate to bond level

This script creates a comprehensive trade-level dataset for regressions following the methodology described in the paper.
The dataset includes:
- Bond fixed effects (time-invariant bond characteristics absorbed)
- Daily 10-year treasury yields (interest rate changes)
- Daily AAA General Obligation yields (municipal market conditions) 
- State annual gross state product (local economic conditions)
- Credit risk premia (Baa-Aaa corporate yield differential)
- Log trade size controls
- Daily transaction volume by bond (intermediation costs)
- Inventory turnover indicators (Sirri 2014)
- Bond age and time to maturity controls
'''
output_date = '251202'
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import pandas as pd
import wrds
from datetime import datetime, timedelta

data_dir = '~/Dropbox/Voting on Bonds/Data'
output_dir = f'{data_dir}/MSRB/Processed'


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load base trade data with markup and yield information
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Loading base trade data...")

# Load trade data with markup
trade_data = (pl.read_parquet(f'{data_dir}/MSRB/Processed/All_Trade_Markup_2005_2023.gzip')
              .select(['cusip', 'dated_date', 'trade_date', 'trade_type_indicator',
                      'dollar_price', 'par_traded', 'trade_sign', 'markup',
                      'retail', 'institutional', 'small_retail', 'large_retail',
                      'small_institutional', 'large_institutional'])
              # Create unique trade identifier
              .with_row_index('row_id')
              .with_columns(
                  # Create trade_id using cusip + trade_date + row_id for uniqueness
                  (pl.col('cusip').cast(pl.Utf8) + '_' + 
                   pl.col('trade_date').dt.strftime('%Y%m%d') + '_' + 
                   pl.col('row_id').cast(pl.Utf8)).alias('trade_id')
              )
              .drop('row_id'))

# Load yield data
'''
yield_data = (pl.read_parquet(f'{data_dir}/MSRB/Processed/All_Trade_Yields_2005_2023.gzip')
              .select(['cusip', 'trade_date', 'yield'])
              # Create matching trade identifier for yield data
              .with_row_count('row_id')
              .with_columns(
                  (pl.col('cusip').cast(pl.Utf8) + '_' + 
                   pl.col('trade_date').dt.strftime('%Y%m%d') + '_' + 
                   pl.col('row_id').cast(pl.Utf8)).alias('trade_id')
              )
              .drop('row_id'))
'''
# Merge trade and yield data on trade_id (should be 1:1 match if from same source)
#trade_data = trade_data.join(yield_data.select(['trade_id', 'yield']), on='trade_id', how='left')

print(f"Base trade data loaded: {trade_data.shape}")

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load bond characteristics from Mergent
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Loading bond characteristics...")


# Load bond characteristics (you'll need to adjust path and columns based on your Mergent data)

bond_chars = (pl.DataFrame(pd.read_stata(f'{data_dir}/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta'))
              .select(['cusip', 'offering_date', 'maturity_date', 'state', 'issue_id', 'seed_issuer_id', 'settlement_date',
                      'amount', 'purp_broad', 'go_unlim', 'go_lim', 'rev', 'fips','rated', 'ln_amount', 'ln_maturity_mths',
                       'callable', 'sinkable', 'insured', 'rating_fe_id', 'rating_fe', 'rating_num', 'rating_low',
                       'city', 'city_go_vote', 'city_rev_vote', 'state_go_vote', 'glm_proactive', 'state_ltgo_allowed']))

# Calculate bond age and time to maturity for each trade date
bond_chars = (bond_chars
              .with_columns([
                  pl.col('offering_date').cast(pl.Date),
                  pl.col('maturity_date').cast(pl.Date)
              ]))

print(f"Bond characteristics loaded: {bond_chars.shape}")

# filter trade data to cusips
trade_data = trade_data.filter(pl.col('cusip').is_in(bond_chars.select('cusip').unique()))

# %%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load County Demographic Data (BEA)
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Loading county demographic data...")

# Load all demographic datasets
demo_files = {
    'employment': f'{data_dir}/BEA/employment_2001_2022.dta',
    'percap_inc': f'{data_dir}/BEA/percap_inc_2001_2022.dta',
    'pers_inc': f'{data_dir}/BEA/pers_inc_2001_2022.dta',
    'pop': f'{data_dir}/BEA/pop_2001_2022.dta',
    'gdp': f'{data_dir}/BEA/gdp_2001_2022.dta'
}

demo_data = {}
for name, file_path in demo_files.items():
    try:
        df = pl.DataFrame(pd.read_stata(file_path))
        # Convert FIPS to string for matching and ensure year is Int64
        df = df.with_columns(pl.col('fips').cast(pl.Utf8).str.zfill(5).alias('fips_str'),
                             pl.col('year').cast(pl.Int64))
        demo_data[name] = df
        print(f"Loaded {name}: {df.shape[0]} observations")
    except Exception as e:
        print(f"Error loading {name}: {e}")
        demo_data[name] = None

# Merge all demographic variables into single dataframe by FIPS and year
if all(v is not None for v in demo_data.values()):
    county_demographics = (demo_data['employment']
                           .select(['fips_str', 'year', 'geoname', 'employment'])
                           .join(demo_data['percap_inc'].select(['fips_str', 'year', 'percap_inc']),
                                 on = ['fips_str', 'year'], how = 'left')
                           .join(demo_data['pers_inc'].select(['fips_str', 'year', 'pers_inc']),
                                 on = ['fips_str', 'year'], how = 'left')
                           .join(demo_data['pop'].select(['fips_str', 'year', 'pop']),
                                 on = ['fips_str', 'year'], how = 'left')
                           .join(demo_data['gdp'].select(['fips_str', 'year', 'gdp']),
                                 on = ['fips_str', 'year'], how = 'left'))

    print(f"County demographics merged: {county_demographics.shape}")

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Sorting
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# join with bond characteristics to get offering date
trade_data = (trade_data
                   .join(bond_chars, on='cusip', how='left')
                     )

# compute days since offering
trade_data = (
    trade_data
    .with_columns(
        (pl.col('trade_date') - pl.col('offering_date')).dt.total_days().alias('days_since_offering')
    ))

# sort within each CUSIP by date
trade_data = trade_data.sort(['cusip', 'trade_date'])

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Get  price dispersion 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# compute price change between consecutive trades for each bond
trade_data_diffs = (
    trade_data
   # .filter(pl.col('days_since_offering').is_between(30, (18/12) * 365))
.filter(pl.col('days_since_offering').gt(30))
    .group_by('cusip', maintain_order=True)
    .agg([
        pl.col('trade_date'),
        pl.col('dollar_price'),
        pl.col('dollar_price').diff().alias('price_change')
    ])
    .explode(['trade_date', 'dollar_price', 'price_change'])
)

# compute price dispersion
price_dispersion = (
    trade_data_diffs
    .group_by('cusip')
    .agg(
        pl.col('price_change').std().alias('price_dispersion')
    )
    .drop_nulls('price_dispersion')
)



#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Aggregate 3-yr post issuance variables
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
liquidity_3yr = (trade_data
             # keep first 3 years after dated_date
            #.filter(pl.col('days_since_offering').is_between(30, (18/12) * 365))
.filter(pl.col('days_since_offering').gt(30))
             # group by issue_id and aggregate
             .group_by('cusip')
                 .agg(pl.col('offering_date').count().alias('number_of_trades_3yr'),
                      pl.col('par_traded').sum().alias('total_par_traded_3yr'),
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

    )
                 .join(price_dispersion, on='cusip', how='left'))

full_3yr = (trade_data
            .select('cusip')
            .unique()
            .join(liquidity_3yr, on = 'cusip', how='left')
            .with_columns(pl.col('number_of_trades_3yr').fill_null(0),
                            pl.col('total_par_traded_3yr').fill_null(0),
                          pl.col('number_of_retail_trades_3yr').fill_null(0),
                            pl.col('number_of_institutional_trades_3yr').fill_null(0))
            .join(bond_chars, on = 'cusip', how='left'))

full_3yr = (full_3yr.with_columns(pl.col('offering_date').dt.year().cast(pl.Int64).alias('year'))
            .join(county_demographics.rename({'fips_str': 'fips'}), on=['fips', 'year'], how='left')
            .with_columns( pl.when(pl.col('employment').is_not_null() & (pl.col('employment') > 0))
                         .then(pl.col('employment').log())
                         .otherwise(None)
                         .alias('log_employment'),
                       pl.when(pl.col('percap_inc').is_not_null() & (pl.col('percap_inc') > 0))
                         .then(pl.col('percap_inc').log())
                         .otherwise(None)
                         .alias('log_percap_inc'),
                       pl.when(pl.col('pers_inc').is_not_null() & (pl.col('pers_inc') > 0))
                         .then(pl.col('pers_inc').log())
                         .otherwise(None)
                         .alias('log_pers_inc'),
                       pl.when(pl.col('pop').is_not_null() & (pl.col('pop') > 0))
                         .then(pl.col('pop').log())
                         .otherwise(None)
                         .alias('log_pop'),
                       pl.when(pl.col('gdp').is_not_null() & (pl.col('gdp') > 0))
                         .then(pl.col('gdp').log())
                         .otherwise(None)
                         .alias('log_gdp')))
full_3yr.write_csv(f'{output_dir}/liquidity_allyr.csv')
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Limit trade data to bonds that have at least one trade in each category (small/large retail/institutional)
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
trade_data = (trade_data
              .with_columns(pl.col('small_retail').max().over('cusip').alias('has_small_retail'),
                            pl.col('large_retail').max().over('cusip').alias('has_large_retail'),
                            pl.col('small_institutional').max().over('cusip').alias('has_small_institutional'),
                            pl.col('large_institutional').max().over('cusip').alias('has_large_institutional'))
              #.filter(((pl.col('has_small_retail') == 1) | (pl.col('has_large_retail') == 1)) & ((pl.col('has_small_institutional') == 1) | (pl.col('has_large_institutional') == 1))))
              #.filter((pl.col('has_small_retail') == 1) & (pl.col('has_large_retail') == 1) & (pl.col('has_small_institutional') == 1) & (pl.col('has_large_institutional') == 1)))
              )
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load macroeconomic control variables
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Loading macroeconomic controls...")

# Get date range for data pulls
min_date = trade_data.select(pl.col('trade_date').min()).item()
max_date = trade_data.select(pl.col('trade_date').max()).item()

# Load 10-Year Treasury Rate from downloaded CSV file
print("Loading Treasury rates from local CSV file...")

treasury_rates = (pl.read_csv(f'{data_dir}/MSRB/treasury_10yr_historical.csv')
                  .rename({'observation_date': 'trade_date', 'DGS10': 'treasury_10yr'})
                  .with_columns([
                      pl.col('trade_date').cast(pl.Date)

                  ])
                  # Filter to our date range
                  .filter((pl.col('trade_date') >= min_date) &
                         (pl.col('trade_date') <= max_date))
                  # Forward fill missing values
                  .with_columns(pl.col('treasury_10yr').fill_null(strategy='forward')))

print(f"Treasury rates loaded from CSV: {treasury_rates.shape}")
    



#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Calculate daily transaction volume by bond (intermediation cost proxy)
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Calculating daily transaction volumes...")

# Calculate logged par value of all transactions per bond per day
daily_bond_volume = (trade_data
                     .group_by(['cusip', 'trade_date'])
                     .agg([
                         pl.col('par_traded').sum().alias('daily_par_volume'),
                         pl.col('par_traded').count().alias('daily_trade_count')
                     ])
                     .with_columns([
                         pl.col('daily_par_volume').log().alias('log_daily_par_volume'),
                         pl.col('daily_trade_count').log().alias('log_daily_trade_count')
                     ]))

print(f"Daily volumes calculated: {daily_bond_volume.shape}")

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create inventory turnover indicators (Sirri 2014)
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Creating inventory turnover indicators...")

# Sort trade data for lag operations
trade_data_sorted = (trade_data
                      .sort(['cusip', 'trade_date'])
                      .with_columns([
                          # Create lagged trade type (1 day lag)
                          pl.col('trade_type_indicator').shift(1).over('cusip').alias('prev_trade_type'),
                          # Create lead trade type (1 day forward)
                          pl.col('trade_type_indicator').shift(-1).over('cusip').alias('next_trade_type'),
                          # Create lagged trade date
                          pl.col('trade_date').shift(1).over('cusip').alias('prev_trade_date'),
                          # Create lead trade date  
                          pl.col('trade_date').shift(-1).over('cusip').alias('next_trade_date')
                      ]))

# Calculate inventory indicators following Sirri (2014)
inventory_indicators = (trade_data_sorted
                        .with_columns([
                            # Days since previous trade
                            (pl.col('trade_date') - pl.col('prev_trade_date')).dt.total_days().alias('days_since_prev'),
                            # Days until next trade
                            (pl.col('next_trade_date') - pl.col('trade_date')).dt.total_days().alias('days_until_next'),
                            
                            # Inventory indicator (Sirri 2014): 1 if trade doesn't follow expected inventory pattern
                            # From CUSTOMER perspective: P=customer sale, S=customer purchase
                            # Indicator = 1 if customer purchase (S) doesn't follow customer sale (P) within 1 day
                            # OR if customer sale (P) doesn't precede customer purchase (S) within 1 day
                            pl.when(
                                (pl.col('trade_type_indicator') == 'S') &  # Current is customer purchase (dealer sale)
                                ((pl.col('prev_trade_type') != 'P') |     # Previous wasn't customer sale OR
                                 ((pl.col('trade_date') - pl.col('prev_trade_date')).dt.total_days() > 1))  # >1 day gap
                            ).then(1)
                            .when(
                                (pl.col('trade_type_indicator') == 'P') &  # Current is customer sale (dealer purchase)
                                ((pl.col('next_trade_type') != 'S') |     # Next isn't customer purchase OR
                                 ((pl.col('next_trade_date') - pl.col('trade_date')).dt.total_days() > 1))  # >1 day gap
                            ).then(1)
                            .otherwise(0)
                            .alias('inventory_indicator')
                        ])
                        .select(['trade_id', 'cusip', 'trade_date', 'inventory_indicator']))

print(f"Inventory indicators created: {inventory_indicators.shape}")

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Merge all datasets to create final regression dataset
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Merging all datasets...")


# Add bond characteristics and calculate age/maturity controls
trade_data = (trade_data
                   .join(bond_chars, on='cusip', how='left')
                   .with_columns([
                       # Bond age in years
                       ((pl.col('trade_date') - pl.col('offering_date')).dt.total_days() / 365.25).alias('bond_age_years'),
                       # Time to maturity in years
                       ((pl.col('maturity_date') - pl.col('trade_date')).dt.total_days() / 365.25).alias('time_to_maturity_years'),
                       # Extract year for demographic merge
                       pl.col('trade_date').dt.year().alias('year'),
                       # Convert FIPS to string and format for matching
                       pl.col('fips').cast(pl.Utf8).str.zfill(5).alias('fips_str')
                   ]))

# Add macroeconomic controls
trade_data = (trade_data
                   .join(treasury_rates, on='trade_date', how='left'))

# Add county demographics using PRIOR YEAR data (lagged economic conditions)
trade_data = (trade_data
                   .with_columns(
                       # Create prior year for demographic merge
                       (pl.col('year') - 1).cast(pl.Int64).alias('demo_year')
                   )
                   .join(county_demographics.rename({'year': 'demo_year'}), 
                         on=['fips_str', 'demo_year'], how='left')
                   .drop('demo_year')  # Clean up temporary column
                   )

# Add daily volume controls
trade_data = (trade_data
                   .join(daily_bond_volume, on=['cusip', 'trade_date'], how='left'))

# Add inventory indicators
trade_data = (trade_data
                   .join(inventory_indicators.select(['trade_id', 'inventory_indicator']), on='trade_id', how='left'))

# Add additional regression controls
trade_data = (trade_data
                   .with_columns([
                       # Log trade size
                       pl.col('par_traded').log().alias('log_trade_size'),
                       # Create time variables for fixed effects
                       pl.col('trade_date').dt.year().alias('year_fe'),
                       pl.col('trade_date').dt.month().alias('month_fe'),
                       pl.col('trade_date').dt.quarter().alias('quarter_fe'),
                       # Forward fill missing macroeconomic variables
                       pl.col('treasury_10yr').fill_null(strategy='forward'),
                       #pl.col('credit_spread').fill_null(strategy='forward'),
                       # Fill missing inventory indicator
                       pl.col('inventory_indicator').fill_null(0),
                       # Log transform demographic variables (add small constant to handle zeros)
                       pl.when(pl.col('employment').is_not_null() & (pl.col('employment') > 0))
                         .then(pl.col('employment').log())
                         .otherwise(None)
                         .alias('log_employment'),
                       pl.when(pl.col('percap_inc').is_not_null() & (pl.col('percap_inc') > 0))
                         .then(pl.col('percap_inc').log())
                         .otherwise(None)
                         .alias('log_percap_inc'),
                       pl.when(pl.col('pers_inc').is_not_null() & (pl.col('pers_inc') > 0))
                         .then(pl.col('pers_inc').log())
                         .otherwise(None)
                         .alias('log_pers_inc'),
                       pl.when(pl.col('pop').is_not_null() & (pl.col('pop') > 0))
                         .then(pl.col('pop').log())
                         .otherwise(None)
                         .alias('log_pop'),
                       pl.when(pl.col('gdp').is_not_null() & (pl.col('gdp') > 0))
                         .then(pl.col('gdp').log())
                         .otherwise(None)
                         .alias('log_gdp')
                   ]))

print(f"Final regression dataset: {trade_data.shape}")


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Save final regression dataset
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("Saving final regression dataset...")

# Save full dataset
trade_data.write_parquet(f'{output_dir}/Trade_Level_Regression_Dataset_{output_date}.gzip')
trade_data.write_csv(f'{output_dir}/Trade_Level_Regression_Dataset_{output_date}.csv')


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create data dictionary and regression specification guide
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

data_dictionary = """
# Trade-Level Regression Dataset - Data Dictionary

## Trade Identifier
- `trade_id`: Unique trade identifier (cusip_YYYYMMDD_rownum) for merging with original trade files

## Dependent Variables
- `markup`: Trade-level markup (basis points), following Cuny (2018)
- `yield`: Bond yield at time of trade

## Key Independent Variables  
- `trade_sign`: 1 for customer purchase, -1 for customer sale
- `retail`: 1 if par_traded < 100,000 (retail trade)
- `institutional`: 1 if par_traded >= 100,000 (institutional trade)
- `small_retail`: 1 if par_traded < 25,000
- `large_retail`: 1 if retail=1 and par_traded >= 25,000
- `small_institutional`: 1 if institutional=1 and par_traded < 250,000
- `large_institutional`: 1 if par_traded >= 250,000

## Bond Characteristics (Fixed Effects and Controls)
- `cusip`: Bond identifier (for bond fixed effects)
- `bond_age_years`: Years since bond issuance
- `time_to_maturity_years`: Years until bond maturity
- `par_value`: Total par value of bond issuance
- `interest_rate`: Bond coupon rate
- `state`: State of bond issuer
- `security_level`: Bond security type (GO, Revenue, etc.)
- `fips`: County FIPS code (5-digit string)

## Macroeconomic Controls
- `treasury_10yr`: Daily 10-year Treasury yield (%) - actual FRED data
- `credit_spread`: Daily Baa-Aaa corporate bond yield differential (%)

## County Demographic Controls (Prior Year BEA Data)
- `log_employment`: Log of county employment (lagged one year)
- `log_percap_inc`: Log of county per capita personal income (lagged one year)
- `log_pers_inc`: Log of county total personal income (lagged one year)
- `log_pop`: Log of county population (lagged one year)
- `log_gdp`: Log of county GDP (lagged one year)
- `geoname`: County name for reference

## Transaction-Level Controls
- `log_trade_size`: Log of trade par value
- `log_daily_par_volume`: Log of total par traded for bond on trade date
- `log_daily_trade_count`: Log of number of trades for bond on trade date  
- `inventory_indicator`: 1 if trade doesn't follow expected inventory pattern (Sirri 2014)

## Time Fixed Effects
- `year_fe`: Year fixed effects
- `month_fe`: Month fixed effects
- `quarter_fe`: Quarter fixed effects
- `trade_date`: Exact trade date

## Suggested Regression Specification

```stata
// Basic specification
reghdfe markup retail institutional treasury_10yr credit_spread ///
        bond_age_years time_to_maturity_years log_trade_size ///
        log_daily_par_volume inventory_indicator, ///
        absorb(cusip year_fe) cluster(cusip)
        
// Specification with county demographics
reghdfe markup retail institutional treasury_10yr credit_spread ///
        bond_age_years time_to_maturity_years log_trade_size ///
        log_daily_par_volume inventory_indicator ///
        log_employment log_percap_inc log_pop log_gdp, ///
        absorb(cusip year_fe) cluster(cusip)
```

```python
# Using linearmodels in Python
from linearmodels import PanelOLS

# Set up data with MultiIndex for panel
data = data.set_index(['cusip', 'trade_date'])

# Basic specification
model_basic = PanelOLS(data['markup'], 
                      data[['retail', 'institutional', 'treasury_10yr', 'credit_spread',
                            'bond_age_years', 'time_to_maturity_years', 'log_trade_size', 
                            'log_daily_par_volume', 'inventory_indicator']],
                      entity_effects=True, time_effects=True)
result_basic = model_basic.fit(cov_type='clustered', cluster_entity=True)

# Specification with county demographics
model_demo = PanelOLS(data['markup'], 
                     data[['retail', 'institutional', 'treasury_10yr', 'credit_spread',
                           'bond_age_years', 'time_to_maturity_years', 'log_trade_size', 
                           'log_daily_par_volume', 'inventory_indicator',
                           'log_employment', 'log_percap_inc', 'log_pop', 'log_gdp']],
                     entity_effects=True, time_effects=True)
result_demo = model_demo.fit(cov_type='clustered', cluster_entity=True)
```

## Notes
- Bond fixed effects absorb time-invariant bond characteristics
- Cluster standard errors at the bond (CUSIP) level
- Consider winsorizing markup and yield variables at 1st/99th percentiles
- Treasury rates are actual FRED historical data (DGS10 series)
- Inventory indicator implementation follows Sirri (2014) methodology
- AAA GO yields and state GSP can be added later if needed
"""

with open(f'{output_dir}/Trade_Level_Regression_Dataset_Dictionary.md', 'w') as f:
    f.write(data_dictionary)

print(f"Data dictionary created: {output_dir}/Trade_Level_Regression_Dataset_Dictionary.md")

print("\n=== All tasks completed! ===")