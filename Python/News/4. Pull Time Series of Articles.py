'''
Load articles for cities in sample
Aggregate to monthly level, include filter on headline for bond-related information
'''

# SET DATE FOR OUTPUT FILES
output_date = '251215'  # YYMMDD format - UPDATE THIS FOR EACH RUN

#%%

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import matplotlib.pyplot as plt
import os

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

# load rp articles
'''
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(rp_map.select('rp_entity_id')))
               .filter(pl.col('relevance').ge(90))
               .filter(pl.col('headline').str.to_lowercase().str.contains('bond') |
                       pl.col('headline').str.to_lowercase().str.contains('debt') |
                       pl.col('headline').str.to_lowercase().str.contains('credit') |
                       pl.col('headline').str.to_lowercase().str.contains('tax'))
               #.filter(pl.col('group').is_in(['housing', 'elections', 'government', 'credit', 'taxes', 'public-finance']))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))


keywords = [
    "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable",
     "issuance", "offering", "issue", "yield",
    "debt", "underwriter", "underwriting", "pricing",
]

'''
'''
keywords = [
    "bond", "bonds", "general obligation",
     "tax-exempt", "taxable", "tax", "taxes", "revenue",
     "issuance", "offering",  "yield",
    "debt", "debts",  "underwriter", "underwriting", "pricing",
]


'''

# 9/16 - worked pretty well
# KEYWORD SET 1 (9/16)
'''
keywords = [
    "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable",
     "issuance", "offering",  "yield", "pricing",
    "debt", "underwriter", "underwriting", "credit"
]
'''

keywords = [
     "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable", "property tax",
     "issuance", "offering",  "yield",
    "debt", "underwriter", "underwriting", "rating", "credit", "refunding",
    "callable", "coupon"
]

'''
# KEYWORD SET 2 - STRICT (9/16)
keywords = [
      "bond", "general obligation",
    "tax-exempt", "taxable",
     "issuance", "offering",  "yield",
    "debt", "underwriter", "underwriting", "credit rating", "refunding", "capital"
]
'''



'''
# 9/16 - what I started with
keywords = [
    "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable",
     "issuance", "offering",  "yield", "pricing", "issue",
    "debt", "underwriter", "underwriting", "rating", "credit", "refunding",
    "callable", "coupon", "capital"
]
'''

'''


keywords = [
     "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable", "property tax",
     "issuance", "offering",  "yield",
    "debt", "underwriter", "underwriting", "rating", "credit", "refunding",
    "callable", "coupon",
]
'''

keywords_dpc = ["bond", "general obligation", "abatement", "tax", "callable", "issuance",
"debt", "underwriter", "underwriting", "credit rating", "refunding"]


# Create flexible pattern that handles plurals
def create_flexible_pattern(keywords):
    patterns = []
    for keyword in keywords:
        if keyword.endswith(('s', 'ing', 'ed')):
            # Already plural/gerund/past tense, keep as-is
            patterns.append(f"\\b{keyword}\\b")
        else:
            # Add optional 's' for plurals
            patterns.append(f"\\b{keyword}s?\\b")
    return "|".join(patterns)

pattern = create_flexible_pattern(keywords)  # handles plurals automatically


#pattern = "|".join([f"\\b{k}\\b" for k in keywords])  # word boundaries
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(rp_map.select('rp_entity_id')))
#.filter(~pl.col('rp_source_id').is_in(newswires))
               .filter(pl.col('relevance').ge(90))
               .filter(pl.col("headline").str.to_lowercase().str.contains(pattern))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))

####
# for media tests, save list of cities that get some bond-related coverage over the sample period
rp_cities_with_coverage = (rp_articles
                            .group_by('rp_entity_id')
                            .agg(pl.col('rpa_date_utc').min().alias('first_article_date'))
                           .join(rp_map, on = 'rp_entity_id', how = 'left'))
rp_cities_with_coverage.write_csv(f'{data_dir}/News/cities_with_bond_related_coverage_{output_date}.csv')
####

# aggregate
rp_monthly = (rp_articles
              .with_columns(pl.col('rpa_date_utc').dt.month().alias('month'),
                            pl.col('rpa_date_utc').dt.year().alias('year'))
              .group_by(['rp_entity_id', 'year', 'month'])
              .agg(pl.col('headline').count().alias('rp_article_count'))
              .with_columns(pl.col('year').cast(pl.Int64),
                            pl.col('month').cast(pl.Int64)))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create entity-month data frame 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# Create a list of all possible combinations of seed_issuer, year, and month
data = []
for entity_id in rp_map['seed_issuer_id'].unique():
    for year in range(2000, 2021):
        for month in range(1, 13):
            data.append({'seed_issuer_id': entity_id, 'year': year, 'month': month})

seed_month = pl.DataFrame(data)

# merge with rp-entity-id\
seed_month = (seed_month
              .join(rp_map, on = 'seed_issuer_id', how = 'left'))

# merge with rp_monthly
seed_month = (seed_month
              .join(rp_monthly, on = ['rp_entity_id', 'year', 'month'], how = 'left'))

# fill null with zero
seed_month = (seed_month
              .with_columns(pl.col('rp_article_count').fill_null(0)))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
now merge with mergent data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
mergent = pd.read_stata(f'{data_dir}/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)

mergent_state = (mergent
                 .select(['seed_issuer_id', 'state', 'fips'])
                 .unique()
                 .filter(pl.col('seed_issuer_id').is_duplicated()))

# aggregate to issuance level
mergent = (mergent
            .filter(~pl.col('seed_issuer_id').is_in(mergent_state.select('seed_issuer_id')))
            .filter(pl.col('seed_issuer').str.to_lowercase().is_in(rp_map.select('seed_issuer')))
            .sort(['issue_id', 'amount'], descending = True)
           .group_by('issue_id', 'state', 'seed_issuer', 'seed_issuer_id')
           .agg(pl.col('offering_date').first(),
           pl.col('go_unlim').first(),
           pl.col('go_lim').first(),
           pl.col('rev').first(),
           pl.col('maturity_date').max().alias('max_maturity'),
            pl.col('amount').sum().alias('total_amount'),
            pl.col('purp_broad').first(),
                pl.col('rating_fe_id').mode().first().alias('rating_fe_id'),
                pl.col('rating_fe').mode().first().alias('rating_fe'),
                pl.col('rating_num').mode().first().alias('rating_num'),
                pl.col('rating_low').mode().first().alias('low_rating')
                ))


# for merge with monthly data
mergent_month = (mergent
                 .with_columns(pl.col('offering_date').cast(pl.Date))
                 .with_columns(pl.col('offering_date').dt.year().alias('year'),
                               pl.col('offering_date').dt.month().alias('month'))
                 .with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                               pl.col('year').cast(pl.Int64),
                               pl.col('month').cast(pl.Int64)))

# some issuers have multiple issuances within a month, so need to aggregate to the month level (just take largest issuance in that month)
mergent_month = (mergent_month
                 .sort(['seed_issuer_id', 'year', 'month', 'total_amount'], descending = True)
                  .group_by(['seed_issuer_id', 'year', 'month'])
                 .agg(pl.col('go_unlim').first(),
                      pl.col('issue_id').first(),
                      pl.col('go_lim').first(),
                        pl.col('rev').first(),
                        pl.col('total_amount').first(),
                        pl.col('purp_broad').first(),
                      pl.col('max_maturity').first(),
                      pl.col('offering_date').first(),
                      pl.col('rating_fe_id').first(),
                      pl.col('rating_fe').first(),
                      pl.col('rating_num').first(),
                      pl.col('low_rating').first()
                      ))


mergent_month = (mergent_month
                 .rename({'go_lim': 'go_lim_bond_issuance',
                          'go_unlim': 'go_unlim_bond_issuance',
                          'rev': 'rev_bond_issuance'}))

# merge bond issuance month indicator with seed_month
seed_month = (seed_month
              .join(mergent_month
                    .with_columns(bond_issuance_month = 1), on = ['seed_issuer_id', 'year', 'month'], how = 'left'))
seed_month = (seed_month
              .with_columns(pl.col('bond_issuance_month').fill_null(0),
                            pl.col('go_lim_bond_issuance').fill_null(0),
                            pl.col('go_unlim_bond_issuance').fill_null(0),
                            pl.col('rev_bond_issuance').fill_null(0)))

# also fill null of issue_id
seed_month = (seed_month
              .with_columns(pl.col('issue_id').fill_null(0))
              .with_columns(pl.col('issue_id').cast(pl.Int64)))

# data types
seed_month = (seed_month
              .with_columns(pl.col('go_lim_bond_issuance').cast(pl.Int64),
                            pl.col('go_unlim_bond_issuance').cast(pl.Int64),
                            pl.col('rev_bond_issuance').cast(pl.Int64)))

# create indicator for bond issuance in the next 12 months
seed_month = (seed_month
              .sort(['seed_issuer_id', 'year', 'month'], descending = True)
              .with_columns(pl.col('bond_issuance_month').rolling_max(12).over('seed_issuer_id').alias('bond_issuance_next_12mth'),
                            pl.col('bond_issuance_month').rolling_max(6).over('seed_issuer_id').alias('bond_issuance_next_6mth'),
                            pl.col('go_lim_bond_issuance').rolling_max(12).over('seed_issuer_id').alias(
                                'go_lim_bond_issuance_next_12mth'),
                            pl.col('go_lim_bond_issuance').rolling_max(6).over('seed_issuer_id').alias(
                                'go_lim_bond_issuance_next_6mth'),
                            pl.col('go_unlim_bond_issuance').rolling_max(12).over('seed_issuer_id').alias(
                                'go_unlim_bond_issuance_next_12mth'),
                            pl.col('go_unlim_bond_issuance').rolling_max(6).over('seed_issuer_id').alias(
                                'go_unlim_bond_issuance_next_6mth'),
                            pl.col('rev_bond_issuance').rolling_max(12).over('seed_issuer_id').alias(
                                'rev_bond_issuance_next_12mth'),
                            pl.col('rev_bond_issuance').rolling_max(6).over('seed_issuer_id').alias(
                                'rev_bond_issuance_next_6mth'),
                            pl.col('issue_id').rolling_max(6).over('seed_issuer_id').alias('issue_id_next_6mth'),
                            pl.col('issue_id').rolling_max(12).over('seed_issuer_id').alias('issue_id_next_12mth')
                            )
              .with_columns(pl.col('bond_issuance_next_12mth').fill_null(0),
                            pl.col('bond_issuance_next_6mth').fill_null(0),
                            pl.col('go_lim_bond_issuance_next_6mth').fill_null(0),
                            pl.col('go_lim_bond_issuance_next_12mth').fill_null(0),
                            pl.col('go_unlim_bond_issuance_next_6mth').fill_null(0),
                            pl.col('go_unlim_bond_issuance_next_12mth').fill_null(0),
                            pl.col('rev_bond_issuance_next_6mth').fill_null(0),
                            pl.col('rev_bond_issuance_next_12mth').fill_null(0)))

# get purpose and amount
seed_month = (seed_month
              .join(mergent_month
                    .select(['issue_id', 'purp_broad', 'total_amount'])
                    .with_columns(pl.col('issue_id').cast(pl.Int64))
                    .rename({'purp_broad': 'bond_purpose_current_month',
                             'total_amount': 'bond_amount_current_month'}), on = 'issue_id', how = 'left')
              .join(mergent_month
                    .select(['issue_id', 'purp_broad', 'total_amount'])
                    .with_columns(pl.col('issue_id').cast(pl.Int64))
                    .rename({'purp_broad': 'bond_purpose_next_6mth',
                             'total_amount': 'bond_amount_next_6mth',
                             'issue_id': 'issue_id_next_6mth'}), on = 'issue_id_next_6mth', how = 'left')
              .join(mergent_month
                    .select(['issue_id', 'purp_broad', 'total_amount'])
                    .with_columns(pl.col('issue_id').cast(pl.Int64))
                    .rename({'purp_broad': 'bond_purpose_next_12mth',
                             'total_amount': 'bond_amount_next_12mth',
                             'issue_id': 'issue_id_next_12mth'}), on = 'issue_id_next_12mth', how = 'left'))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge with demo data  
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
employment = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/employment_2001_2022.dta'))
percap_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/percap_inc_2001_2022.dta'))
pers_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pers_inc_2001_2022.dta'))
pop = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pop_2001_2022.dta'))
gdp = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/gdp_2001_2022.dta'))

seed_month = (seed_month
              .join(employment
                    .with_columns(pl.col('fips').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64))
                    .select(['fips', 'year', 'employment']), on = ['fips', 'year'], how = 'left')
              )

seed_month = (seed_month
              .join(percap_inc
                    .with_columns(pl.col('fips').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64))
                    .select(['fips', 'year', 'percap_inc']), on = ['fips', 'year'], how = 'left'))

seed_month = (seed_month
              .join(pers_inc
                    .with_columns(pl.col('fips').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64))
                    .select(['fips', 'year', 'pers_inc']), on = ['fips', 'year'], how = 'left'))

seed_month = (seed_month
              .join(pop
                    .with_columns(pl.col('fips').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64))
                    .select(['fips', 'year', 'pop']), on = ['fips', 'year'], how = 'left'))

seed_month = (seed_month
              .join(gdp
                    .with_columns(pl.col('fips').cast(pl.Int64),
                                  pl.col('year').cast(pl.Int64))
                    .select(['fips', 'year', 'gdp']), on = ['fips', 'year'], how = 'left'))

# log adjust
seed_month = (seed_month
              .with_columns(pl.col('employment').log().alias('ln_employment'),
                            pl.col('percap_inc').log().alias('ln_percap_inc'),
                            pl.col('pers_inc').log().alias('ln_pers_inc'),
                            pl.col('pop').log().alias('ln_pop'),
                            pl.col('gdp').log().alias('ln_gdp')))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
add vote requirement 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

mergent = pd.read_stata(f'{data_dir}/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)

mergent = (mergent
           .select(['seed_issuer_id', 'city_go_vote', 'city_rev_vote', 'state', 'fips'])
           .unique())

seed_month = (seed_month
              .join(mergent
                    .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = ['seed_issuer_id'], how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# fill nas

seed_month = (seed_month
              .with_columns(pl.col('bond_purpose_current_month').fill_null(''),
                            pl.col('bond_purpose_next_6mth').fill_null(''),
                            pl.col('bond_purpose_next_12mth').fill_null(''),
                            pl.col('bond_amount_current_month').fill_null(0),
                            pl.col('bond_amount_next_6mth').fill_null(0),
                            pl.col('bond_amount_next_12mth').fill_null(0))
              .with_columns(pl.col('bond_amount_current_month').add(1).log().alias('ln_bond_amount_current_month'),
                            pl.col('bond_amount_next_6mth').add(1).log().alias('ln_bond_amount_next_6mth'),
                            pl.col('bond_amount_next_12mth').add(1).log().alias('ln_bond_amount_next_12mth')))
seed_month.write_parquet(f'{data_dir}/News/Full_City_Month_Data_Headline_Filter_{output_date}.gzip')



#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
construct abnormal coverage variable 
focus on the 6 months prior to and including issuance 
then pull the same six month period over the prior 3 years and average that 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
year_month_df = (seed_month.select(['year', 'month'])
                 .unique()
                 .sort(['year', 'month'])
                 .with_row_index('year_month_id'))

seed_month = (seed_month
              .join(year_month_df, on = ['year', 'month'], how = 'left'))

issuance_months = (seed_month
                   .filter(pl.col('bond_issuance_month').eq(1))
                   .select(['seed_issuer_id', 'fips', 'year', 'month', 'year_month_id', 'go_unlim_bond_issuance',
                            'go_lim_bond_issuance', 'rev_bond_issuance', 'rp_article_count'])
                   .rename({'year_month_id':'issuance_year_month_id',
                            'rp_article_count': 'issuance_month_total_articles'})
                   .with_columns(pl.col('issuance_year_month_id').cast(pl.Int64)))

issuance_months_event_period_6_0 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-6, 1)])))
issuance_months_event_period_6_0 = (issuance_months_event_period_6_0
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_6_0')))


issuance_months_event_period_6_neg1 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-6, 0)])))
issuance_months_event_period_6_neg1 = (issuance_months_event_period_6_neg1
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_6_neg1')))

issuance_months_event_period_6_1 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-6, 2)])))
issuance_months_event_period_6_1 = (issuance_months_event_period_6_1
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_6_2')))

issuance_months_event_period_1_1 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-1, 2)])))
issuance_months_event_period_1_1 = (issuance_months_event_period_1_1
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_1_1')))

issuance_months_event_period_1_0 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-1, 1)])))
issuance_months_event_period_1_0 = (issuance_months_event_period_1_0
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_1_0')))

issuance_months_event_period_12_0 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-12, 1)])))
issuance_months_event_period_12_0 = (issuance_months_event_period_12_0
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_12_0')))


issuance_months_event_period_12_neg1 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-12, 0)])))
issuance_months_event_period_12_neg1 = (issuance_months_event_period_12_neg1
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_12_neg1')))

issuance_months_event_period_18_12 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-18, -12)])))
issuance_months_event_period_18_12 = (issuance_months_event_period_18_12
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_18_12')))

issuance_months_event_period_18_12 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-18, -12)])))
issuance_months_event_period_18_12 = (issuance_months_event_period_18_12
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_18_12')))

issuance_months_event_period_30_24 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-30, -24)])))
issuance_months_event_period_30_24 = (issuance_months_event_period_30_24
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_30_24')))

issuance_months_event_period_12_6 = (issuance_months
                                .pipe(lambda df_: pl.concat([df_
                                                        .with_columns(year_month_id = pl.col('issuance_year_month_id') + i) for i in range(-12, -6)])))
issuance_months_event_period_12_6 = (issuance_months_event_period_12_6
                                .join(seed_month
                                      .select(['seed_issuer_id', 'year_month_id', 'rp_article_count'])
                                      .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                                      on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                                .group_by(['seed_issuer_id', 'issuance_year_month_id'])
                                .agg(pl.col('rp_article_count').sum().alias('total_rp_articles_12_6')))


issuance_months = (issuance_months
                   .join(seed_month
                         .select(['seed_issuer_id', 'fips', 'year_month_id', 'ln_employment', 'ln_percap_inc', 'ln_pers_inc', 'ln_pop', 'ln_gdp',
                                  'rating_fe_id', 'rating_fe', 'rating_num', 'low_rating'])
                         .rename({'year_month_id':'issuance_year_month_id'})
                         .with_columns(pl.col('issuance_year_month_id').cast(pl.Int64)), on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                   .join(issuance_months_event_period_1_1, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                    .join(issuance_months_event_period_1_0, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                   .join(issuance_months_event_period_6_0, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                   .join(issuance_months_event_period_6_neg1, on = ['seed_issuer_id', 'issuance_year_month_id'],
                         how = 'left')
                   .join(issuance_months_event_period_6_1, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                   .join(issuance_months_event_period_12_0, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
.join(issuance_months_event_period_12_neg1, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                   .join(issuance_months_event_period_18_12, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                    .join(issuance_months_event_period_30_24, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left')
                   .join(issuance_months_event_period_12_6, on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left'))

mergent = pd.read_stata(f'{data_dir}/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)


mergent_month = (mergent
                 .with_columns(pl.col('offering_date').cast(pl.Date))
                 .with_columns(pl.col('offering_date').dt.year().alias('year'),
                               pl.col('offering_date').dt.month().alias('month'))
                .sort(['seed_issuer_id', 'year', 'month', 'amount'], descending = True)
                 # if multiple bonds issued in month, aggregate
                .group_by(['seed_issuer_id', 'year', 'month'])
                .agg(pl.col('maturity_mths').mean().log().alias('ln_maturity'),
                     pl.col('amount').sum().log().alias('ln_amount'),
                     pl.col('num_cusip').sum().log().alias('ln_num_cusip'),
                     pl.col('rated').mean().alias('rated'),
                     pl.col('callable').mean().alias('callable'),
                     pl.col('insured').mean().alias('insured'),
                     pl.col('sinkable').mean().alias('sinkable'),
                     pl.col('city_go_vote').first(),
                    pl.col('city_rev_vote').first(),
                     pl.col('purp_broad').first(),
                     #pl.col('state_godebt_limit').first(),
                     pl.col('state_ltgo_allowed').first(),
                     #pl.col('state_fullfaith').first(),
                     #pl.col('state_sep_debtservice_levy').first(),
                     pl.col('glm_proactive').first(),
                     pl.col('state_go_vote').first(),
                     pl.col('state').first())
                 .with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                               pl.col('year').cast(pl.Int64),
                               pl.col('month').cast(pl.Int64)))

mergent_month = (mergent_month
                 .join(year_month_df, on = ['year', 'month'], how = 'left')
                 .rename({'year_month_id':'issuance_year_month_id'}))

issuance_months = (issuance_months
                   .join(mergent_month
                         .drop(['year', 'month'])
                         .with_columns(pl.col('issuance_year_month_id').cast(pl.Int64))
                         , on = ['seed_issuer_id', 'issuance_year_month_id'], how = 'left'))

issuance_months.write_parquet(f'{data_dir}/News/Issuance_Lvl_AbnormalNews_HeadlineFilter_{output_date}.gzip')


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
also create event study data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''




bond_issuance_months = (seed_month
                        .filter(pl.col('bond_issuance_month').eq(1))
                        .select(['seed_issuer_id','year_month_id', 'go_lim_bond_issuance', 'go_unlim_bond_issuance', 'rev_bond_issuance'])
                        .rename({'year_month_id':'bond_issuance_year_month_id'})
                        .with_columns(pl.col('bond_issuance_year_month_id').cast(pl.Int64))
                        .pipe(lambda df_: pl.concat([df_
                                                    .with_columns(year_month_id=pl.col('bond_issuance_year_month_id').add(i)) for i in range(-48, 49)])))

bond_issuance_months = (bond_issuance_months
                        .with_columns(pl.col('year_month_id').sub(pl.col('bond_issuance_year_month_id')).alias('event_month')))

# now join with data
bond_issuance_months = (bond_issuance_months
                        .join(seed_month
                              .select(['seed_issuer_id', 'year_month_id', 'rp_article_count', 'city_go_vote', 'city_rev_vote',
                                       'ln_employment', 'ln_percap_inc', 'ln_pers_inc', 'ln_pop', 'ln_gdp'])
                              .with_columns(pl.col('year_month_id').cast(pl.Int64)),
                              on = ['seed_issuer_id', 'year_month_id'], how = 'left'))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
plot
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

event_plot_df = (bond_issuance_months
                 .filter(pl.col('city_go_vote').is_not_null())
                 .group_by(['event_month', 'city_go_vote'])
                 .agg(pl.col('rp_article_count').mean().alias('rp_article_count')))

event_plot_df.write_csv(f'{data_dir}/News/City_Month_DF_For_Event_Plot_{output_date}.csv')


event_plot_df = (bond_issuance_months
                 .filter(pl.col('go_unlim_bond_issuance').eq(1) | pl.col('go_lim_bond_issuance').eq(1))
                 .filter(pl.col('city_go_vote').is_not_null())
                 .group_by(['event_month', 'city_go_vote'])
                 .agg(pl.col('rp_article_count').mean().alias('rp_article_count')))

event_plot_df.write_csv(f'{data_dir}/News/City_Month_DF_For_Event_Plot_GO_Only_{output_date}.csv')

event_plot_df = (bond_issuance_months
                 .filter(pl.col('go_unlim_bond_issuance').eq(1))
                 .filter(pl.col('city_go_vote').is_not_null())
                 .group_by(['event_month', 'city_go_vote'])
                 .agg(pl.col('rp_article_count').mean().alias('rp_article_count')))

event_plot_df.write_csv(f'{data_dir}/News/City_Month_DF_For_Event_Plot_Unlim_GO_Only_{output_date}.csv')
