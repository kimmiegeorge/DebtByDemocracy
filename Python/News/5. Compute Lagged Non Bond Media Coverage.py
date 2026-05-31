'''
Compute Lagged Non Bond Media Coverage
Average monthly count of articles over the prior 12 months
'''

# SET DATE FOR OUTPUT FILES
output_date = '251215'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import matplotlib.pyplot as plt
import os
import pyreadr

wrds_dir = '/Volumes/External/WRDS_202408'
#wrds_dir = '/Volumes/Elements/WRDS_202408'
rp_dir = '/Volumes/External/City_RP_Articles'
#rp_dir = '~/Dropbox/City_RP_Articles'
data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load data and aggregate rp articles 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# load rp map and add fips
rp_map = pl.read_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv')
fips = (pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')
        .select(['rp_entity_id', 'fips']))
rp_map = (rp_map
          .join(fips, on = 'rp_entity_id', how = 'left'))

newswires = ['B5569E', 'D19959', '53A5CA', '751371', 'A51917', '4A513E']
# load rp articles
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(rp_map.select('rp_entity_id')))
               #.filter(pl.col('relevance').ge(90))
#.filter(~pl.col('rp_source_id').is_in(newswires))
                # drop bond-related articles
               #.filter(~(pl.col('headline').str.to_lowercase().str.contains('bond') |
                #       pl.col('headline').str.to_lowercase().str.contains('debt') |
                 #      pl.col('headline').str.to_lowercase().str.contains('credit') |
                  #     pl.col('headline').str.to_lowercase().str.contains('tax')))
               #.filter(pl.col('group').is_in(['housing', 'elections', 'government', 'credit', 'taxes', 'public-finance']))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))



# aggregate
rp_monthly = (rp_articles
              .with_columns(pl.col('rpa_date_utc').dt.month().alias('month'),
                            pl.col('rpa_date_utc').dt.year().alias('year'))
              .group_by(['rp_entity_id', 'year', 'month'])
              .agg(pl.col('headline').count().alias('rp_article_count'),
                   pl.col('rp_source_id').alias('sources'))
              .with_columns(pl.col('year').cast(pl.Int64),
                            pl.col('month').cast(pl.Int64)))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Each month, get rolling sum of prior 12 month media coverage 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# Create a list of all possible combinations of seed_issuer, year, and month
data = []
ym_id = 0
for entity_id in rp_map['seed_issuer_id'].unique():
    for year in range(2000, 2021):
        for month in range(1, 13):
            data.append({'seed_issuer_id': entity_id, 'year': year, 'month': month})

data_ym_id = []
for year in range(2000, 2021):
    for month in range(1,13):
        ym_id += 1
        data_ym_id.append({'year': year, 'month': month, 'ym_id': ym_id})

seed_month = pl.DataFrame(data)
ym_id = pl.DataFrame(data_ym_id)
seed_month = (seed_month
              .join(ym_id, on = ['year', 'month'], how = 'left'))

# merge with rp-entity-id\
seed_month = (seed_month
              .join(rp_map, on = 'seed_issuer_id', how = 'left'))

# merge with rp_monthly
seed_month = (seed_month
              .join(rp_monthly, on = ['rp_entity_id', 'year', 'month'], how = 'left'))

# fill null with zero
seed_month = (seed_month
              .with_columns(pl.col('rp_article_count').fill_null(0)))

seed_month = (seed_month
              .sort(['rp_entity_id', 'year', 'month'])
              .with_columns([
                  pl.col('rp_article_count')
                    .rolling_sum(24)
                    .over(pl.col('rp_entity_id'))
                    .alias('rolling_sum_monthly_article_count_24'),
                  pl.col('rp_article_count')
                    .rolling_sum(12)
                    .over(pl.col('rp_entity_id'))
                    .alias('rolling_sum_monthly_article_count_12'),
                  pl.col('rp_article_count')
                    .rolling_sum(6)
                    .over(pl.col('rp_entity_id'))
                    .alias('rolling_sum_monthly_article_count_6')
              ])
              )




#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
add to article count files 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
issuance_dta = pl.read_parquet(f'{data_dir}/News/Issuance_Lvl_AbnormalNews_HeadlineFilter_{output_date}.gzip')
issuance_dta = (issuance_dta
                .join(ym_id, on = ['year', 'month'], how = 'left'))

issuance_dta = (issuance_dta
                .join(seed_month
                      .select(['seed_issuer_id', 'ym_id', 'rolling_sum_monthly_article_count_6', 'rolling_sum_monthly_article_count_12',
                               'rolling_sum_monthly_article_count_24'])
                      , on = ['seed_issuer_id', 'ym_id'], how = 'left'))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
get unique number of sources 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
_temp = pl.read_parquet(f'{data_dir}/News/Issuance_Lvl_AbnormalNews_HeadlineFilter_251215.gzip')
_temp = (_temp
                .join(ym_id, on = ['year', 'month'], how = 'left'))

prior_6_mo = (_temp
              .pipe(lambda df_: pl.concat([df_
                .with_columns(ym_id_adj=pl.col('ym_id').add(i)) for i in range(-7,1)]))
              .join(seed_month
                    .select(['seed_issuer_id', 'ym_id', 'sources'])
                    .rename({'ym_id': 'ym_id_adj'}), on = ['seed_issuer_id', 'ym_id_adj'], how = 'left'))


prior_6_mo_agg = (prior_6_mo
                  .group_by(['seed_issuer_id', 'year', 'month'])
                  .agg(pl.col('sources').flatten().alias('all_sources'))
                  .with_columns(pl.col('all_sources').list.drop_nulls())
                  .with_columns(pl.col('all_sources').list.n_unique().alias('unique_sources_6'))
                  .select(['seed_issuer_id', 'year', 'month', 'unique_sources_6']))


prior_12_mo = (_temp
              .pipe(lambda df_: pl.concat([df_
                .with_columns(ym_id_adj=pl.col('ym_id').add(i)) for i in range(-13, 1)]))
              .join(seed_month
                    .select(['seed_issuer_id', 'ym_id', 'sources'])
                    .rename({'ym_id': 'ym_id_adj'}), on = ['seed_issuer_id', 'ym_id_adj'], how = 'left'))


prior_12_mo_agg = (prior_12_mo
                  .group_by(['seed_issuer_id', 'year', 'month'])
                  .agg(pl.col('sources').flatten().alias('all_sources'))
                  .with_columns(pl.col('all_sources').list.drop_nulls())
                  .with_columns(pl.col('all_sources').list.n_unique().alias('unique_sources_12'))
                  .select(['seed_issuer_id', 'year', 'month', 'unique_sources_12']))

issuance_dta = (issuance_dta
                .join(prior_6_mo_agg, on = ['seed_issuer_id', 'year', 'month'], how = 'left')
                .join(prior_12_mo_agg, on = ['seed_issuer_id', 'year', 'month'], how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
scaled vars
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuance_dta = (issuance_dta
               # .rename({'total_rp_articles_12_10': 'total_rp_articles_12_0'})
                .with_columns(pl.when(pl.col('rolling_sum_monthly_article_count_6').ne(0))
                              .then(pl.col('total_rp_articles_6_0').truediv(pl.col('rolling_sum_monthly_article_count_6')))
                                .otherwise(0)
                              .alias('total_rp_articles_6_0_scaled_by_articles'),
                              pl.when(pl.col('rolling_sum_monthly_article_count_12').ne(0))
                              .then(pl.col('total_rp_articles_12_0').truediv(
                                  pl.col('rolling_sum_monthly_article_count_12')))
                              .otherwise(0)
                              .alias('total_rp_articles_12_0_scaled_by_articles'),
                            pl.when(pl.col('unique_sources_6').ne(0))
                              .then(pl.col('total_rp_articles_6_0').truediv(pl.col('unique_sources_6')))
                                .otherwise(0)
                              .alias('total_rp_articles_6_0_scaled_by_sources'),
                            pl.when(pl.col('unique_sources_12').ne(0))
                              .then(pl.col('total_rp_articles_12_0').truediv(pl.col('unique_sources_12')))
                                .otherwise(0)
                              .alias('total_rp_articles_12_0_scaled_by_sources'),
                              ))

#%%

issuance_dta.write_csv(f'{data_dir}/News/Issuance_Lvl_News_With_Lagged_News_{output_date}.csv')