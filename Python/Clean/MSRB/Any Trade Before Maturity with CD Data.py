'''
Create file with bond-level trade-before-maturity indicators and continuing
disclosure data. Preserve the original markup-sample indicators and add
separate raw customer-trade indicators without the same-day interdealer rule.
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

raw_trade_files = [data_dir / 'MSRB' / 'Raw Files' / f'msrb_{year}.gzip'
                   for year in range(2005, 2024)]
missing_raw_files = [path for path in raw_trade_files if not path.exists()]
if missing_raw_files:
    raise FileNotFoundError(f'Missing MSRB raw files: {missing_raw_files}')
raw_trade_files = [str(path) for path in raw_trade_files]

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load needed data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuances = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'))
             .select(['issue_id', 'cusip',
                      'offering_date', 'maturity_date'])
             .with_columns([
    pl.col("offering_date").cast(pl.Date),
    pl.col("maturity_date").cast(pl.Date)
]))

liquidity = (pl
             .read_parquet(msrb_processed_dir / 'All_Trade_Markup_2005_2023.gzip')
             )
daily_liquidity = (liquidity
                   .group_by(['cusip', 'trade_date'])
                   .agg(pl.col('trade_type_indicator').count().alias('num_trades'),
                        pl.col('par_traded').sum().alias('total_par_traded'),
                        pl.col('retail').sum().alias('retail_trades'),
                        pl.col('institutional').sum().alias('institutional_trades')))
del liquidity

# Create separate trade-presence indicators directly from all raw customer
# transactions (P and S). These intentionally do not require a same-day
# interdealer trade or a nonnegative computed markup. The original indicators
# above remain based on the markup sample and are preserved unchanged.
raw_customer_trade_indicators = (pl
    .scan_parquet(raw_trade_files)
    .select(['cusip', 'trade_date', 'trade_type_indicator', 'par_traded'])
    .filter(pl.col('trade_type_indicator').is_in(['P', 'S']))
    .with_columns(
        pl.col('par_traded')
        .replace('1MM+', '1000000')
        .cast(pl.Float64, strict=False)
    )
    .join(issuances.lazy(), on='cusip', how='inner')
    .filter(pl.col('trade_date') >= pl.col('offering_date') + pl.duration(days=30))
    .filter(pl.col('trade_date') <= pl.col('maturity_date'))
    .group_by('cusip')
    .agg(
        pl.len().gt(0).cast(pl.Int8).alias('traded_before_maturity_raw'),
        pl.col('par_traded').lt(100000).fill_null(False).any().cast(pl.Int8)
        .alias('retail_traded_before_maturity_raw'),
        pl.col('par_traded').ge(100000).fill_null(False).any().cast(pl.Int8)
        .alias('institutional_traded_before_maturity_raw'),
    )
    .collect()
)


cd = pl.read_csv(f'{data_dir}/Continuing Disclosure/cleaned_daily_disclosure_data.csv',
                 infer_schema_length=100000, null_values='NA')

daily_cd = (cd
            .group_by(['cusip_c', 'disclosure_event_date'])
            .agg(pl.col('submissionidentifier').n_unique().alias('num_disclosures')))
del cd


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create panel from offering to maturity date
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Create daily panel by exploding each issuance for all dates between offering and maturity
daily_panel = (issuances
               .with_columns([
                   # Create a list of all dates from offering_date to maturity_date
                   pl.date_ranges(
                       pl.col('offering_date'),
                       pl.col('maturity_date'),
                       interval='1d'
                   ).alias('date_range')
               ])
               .explode('date_range')  # Explode the date range to create one row per date
               .rename({'date_range': 'date'})
               )

# filter to dates more than 30 days after offering date
daily_panel = daily_panel.filter(
    pl.col('date') >= (pl.col('offering_date') + pl.duration(days=30))
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge with trade data and continuing disclosure data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
daily_panel = (daily_panel
                # join with daily liquidity data
               .join(daily_liquidity
                     .rename({'trade_date': 'date'}),
                      on = ['cusip', 'date'], how='left')
               .with_columns(pl.col('num_trades').fill_null(0),
                             pl.col('total_par_traded').fill_null(0),
                             pl.col('retail_trades').fill_null(0),
                             pl.col('institutional_trades').fill_null(0))
                # join with daily continuing disclosure data
                .join(daily_cd
                      .rename({'cusip_c': 'cusip',
                              'disclosure_event_date': 'date'})
                      .with_columns(pl.col('date').cast(pl.Date)),
                          on = ['cusip', 'date'], how='left')
                .with_columns(pl.col('num_disclosures').fill_null(0))
               )


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create bond-level variables on trade activity and continuing disclosure 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
bond_agg = (daily_panel
            .with_columns(pl.col('date').dt.year().alias('year'))
            .group_by('cusip')
            .agg(pl.col('year').n_unique().alias('pre_maturity_years'),
                 pl.col('num_trades').sum().alias('total_trades_before_maturity'),
                 pl.col('year').filter(pl.col('num_trades') > 0).n_unique().alias('num_years_with_trades_before_maturity'),
                 pl.col('total_par_traded').sum().alias('total_par_traded_before_maturity'),
                 pl.col('retail_trades').sum().alias('total_retail_trades_before_maturity'),
                 pl.col('institutional_trades').sum().alias('total_institutional_trades_before_maturity'),
                 pl.col('num_disclosures').sum().alias('total_disclosures_before_maturity'),
                 pl.col('year').filter(pl.col('num_disclosures') > 0).n_unique().alias('num_years_with_disclosures_before_maturity'))
                )

bond_agg = (bond_agg
            .with_columns(pl.when(pl.col('total_trades_before_maturity') > 0)
                          .then(1).otherwise(0).alias('traded_before_maturity'),
                          pl.col('num_years_with_trades_before_maturity').truediv(pl.col('pre_maturity_years')).alias('fraction_years_traded_before_maturity'),
                          pl.when(pl.col('total_disclosures_before_maturity') > 0)
                          .then(1).otherwise(0).alias('disclosed_before_maturity'),
                          pl.col('num_years_with_disclosures_before_maturity').truediv(pl.col('pre_maturity_years')).alias('fraction_years_with_disclosures_before_maturity'),
                          pl.when(pl.col('total_retail_trades_before_maturity').gt(0))
                          .then(1).otherwise(0).alias('retail_traded_before_maturity'),
                          pl.when(pl.col('total_institutional_trades_before_maturity').gt(0))
                            .then(1).otherwise(0).alias('institutional_traded_before_maturity'),
                          pl.col('total_disclosures_before_maturity').truediv(pl.col('pre_maturity_years')).alias('avg_disclosures_per_year_before_maturity'))
            .join(raw_customer_trade_indicators, on='cusip', how='left')
            .with_columns(
                pl.col('traded_before_maturity_raw').fill_null(0),
                pl.col('retail_traded_before_maturity_raw').fill_null(0),
                pl.col('institutional_traded_before_maturity_raw').fill_null(0),
            )
            )

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge with mergent data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
mergent = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'))
           )

bond_agg = (bond_agg
            .join(mergent, on = 'cusip', how='left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
bond_agg.write_csv(msrb_processed_dir / 'Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv')
