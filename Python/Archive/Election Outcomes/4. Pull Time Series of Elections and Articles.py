'''
Load election data and merge with news article counts
Create two outputs:
1. City-month level time series with bond election indicators
2. Election-level data with article counts in different time windows
'''

# SET DATE FOR OUTPUT FILES
output_date = '251012'  # YYMMDD format - UPDATE THIS FOR EACH RUN

#%%

#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#setup
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import matplotlib.pyplot as plt
import os

# Data directories - using same structure as News analysis
wrds_dir = '/Volumes/External/WRDS_202408'
#wrds_dir = '/Volumes/Elements/WRDS_202408'
rp_dir = '/Volumes/External/City_RP_Articles'
#rp_dir = '~/Dropbox/City_RP_Articles'
data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data'

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#load election data and prepare basic structure
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Load Texas election data
election_data = pd.read_stata('/Users/kmunevar/Dropbox/Voting on Bonds/Data/TX/250310_txmerge_election_issuelevel.dta')
election_data = pl.DataFrame(election_data)

print(f"Original election data shape: {election_data.shape}")

# Convert date_election to proper date format and extract year/month
election_data = (election_data
                .with_columns(pl.col('date_election').cast(pl.Date))
                .with_columns(pl.col('date_election').dt.year().alias('year'),
                              pl.col('date_election').dt.month().alias('month'))
                .filter(pl.col('date_election').is_not_null()))

print(f"Election data after date processing: {election_data.shape}")
#print(f"Election date range: {election_data.select(pl.col('date_election').min(), pl.col('date_election').max())}")

# Get unique issuers for mapping
election_issuers = (election_data
                   .select(['seed_issuer_id', 'seed_issuer', 'fips', 'county_name'])
                   .unique())

print(f"Number of unique election issuers: {election_issuers.shape[0]}")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load rp map and filter for election issuers
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# load rp map and add fips
rp_map = pl.read_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv')
fips = (pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')
        .select(['rp_entity_id', 'fips']))
rp_map = (rp_map
          .join(fips, on = 'rp_entity_id', how = 'left'))

print(f"Total RavenPack entities: {rp_map.shape[0]}")

# Filter rp_map to only include entities that appear in our election data
rp_map_elections = (rp_map
                   .join(election_issuers.select(['seed_issuer_id']).with_columns(pl.col('seed_issuer_id').cast(pl.Int64)),
                         on='seed_issuer_id', how='inner'))

print(f"RavenPack entities in election sample: {rp_map_elections.shape[0]}")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
define keywords and load rp articles with bond-related filtering
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Define bond-related keywords (using same as original script)
keywords = [
     "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable", "property tax",
     "issuance", "offering",  "yield",
    "debt", "underwriter", "underwriting", "rating", "credit", "refunding",
    "callable", "coupon",
]

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

print(f"Keyword pattern: {pattern[:100]}...")

# Load and filter rp articles
print("Loading RavenPack articles...")
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(rp_map_elections.select('rp_entity_id')))
               .filter(pl.col('relevance').ge(90))
               .filter(pl.col("headline").str.to_lowercase().str.contains(pattern))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))

print(f"Loaded {rp_articles.shape[0]} bond-related articles for election sample")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
aggregate articles to monthly level
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Save cities with bond coverage for reference
rp_cities_with_coverage = (rp_articles
                          .group_by('rp_entity_id')
                          .agg(pl.col('rpa_date_utc').min().alias('first_article_date'),
                               pl.col('headline').count().alias('total_articles'))
                           .join(rp_map_elections, on = 'rp_entity_id', how = 'left'))

rp_cities_with_coverage.write_csv(f'{data_dir}/TX/News/election_cities_with_bond_coverage_{output_date}.csv')
print(f"Saved coverage info for {rp_cities_with_coverage.shape[0]} cities with bond articles")

# Aggregate articles to monthly level
rp_monthly = (rp_articles
              .with_columns(pl.col('rpa_date_utc').dt.month().alias('month'),
                            pl.col('rpa_date_utc').dt.year().alias('year'))
              .group_by(['rp_entity_id', 'year', 'month'])
              .agg(pl.col('headline').count().alias('rp_article_count'))
              .with_columns(pl.col('year').cast(pl.Int64),
                            pl.col('month').cast(pl.Int64)))

print(f"Monthly article aggregates: {rp_monthly.shape[0]} entity-month observations")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create comprehensive city-month time series 
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Create a list of all possible combinations of seed_issuer, year, and month
min_year = election_data.select(pl.col('year').min()).item()
max_year = election_data.select(pl.col('year').max()).item()

data = []
for issuer_id in rp_map_elections['seed_issuer_id'].unique():
    for year in range(min_year, max_year + 1):
        for month in range(1, 13):
            data.append({'seed_issuer_id': issuer_id, 'year': year, 'month': month})

city_month = pl.DataFrame(data)

# merge with rp-entity-id
city_month = (city_month
              .join(rp_map_elections, on = 'seed_issuer_id', how = 'left'))

# merge with rp_monthly
city_month = (city_month
              .join(rp_monthly, on = ['rp_entity_id', 'year', 'month'], how = 'left'))

# fill null with zero
city_month = (city_month
              .with_columns(pl.col('rp_article_count').fill_null(0)))

print(f"City-month framework: {city_month.shape[0]} observations")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
aggregate election data and create election indicators
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Aggregate elections to monthly level for city-month indicators
election_monthly = (election_data
                   .group_by(['seed_issuer_id', 'year', 'month'])
                   .agg(pl.col('issue_id').count().alias('num_bond_elections'),
                        pl.col('amount_total').sum().alias('total_election_amount'),
                        pl.col('wavg_winmargin').mean().alias('avg_win_margin'),
                        pl.col('go_unlim').sum().alias('num_go_unlim_elections'),
                        pl.col('go_lim').sum().alias('num_go_lim_elections'), 
                        pl.col('rev').sum().alias('num_rev_elections')))

# Create binary indicators
election_monthly = (election_monthly
                   .with_columns(pl.lit(1).alias('has_bond_election')))

# Merge election indicators with city_month
city_month = (city_month
              .join(election_monthly.with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                                  pl.col('year').cast(pl.Int64),
                                                  pl.col('month').cast(pl.Int64)),
                    on = ['seed_issuer_id', 'year', 'month'], how = 'left')
              .with_columns(pl.col('has_bond_election').fill_null(0),
                           pl.col('num_bond_elections').fill_null(0),
                           pl.col('total_election_amount').fill_null(0),
                           pl.col('num_go_unlim_elections').fill_null(0),
                           pl.col('num_go_lim_elections').fill_null(0),
                           pl.col('num_rev_elections').fill_null(0)))

print(f"City-month with elections: {city_month.filter(pl.col('has_bond_election') == 1).shape[0]} months with elections")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create forward-looking election indicators (upcoming month)
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Sort for time series operations
city_month = city_month.sort(['seed_issuer_id', 'year', 'month'])

# Create forward-looking indicators
city_month = (city_month
             .with_columns(pl.col('has_bond_election').shift(-1).over('seed_issuer_id').alias('has_election_next_month'),
                          pl.col('num_bond_elections').shift(-1).over('seed_issuer_id').alias('num_elections_next_month')))

# Fill nulls 
city_month = (city_month
             .with_columns(pl.col('has_election_next_month').fill_null(0),
                          pl.col('num_elections_next_month').fill_null(0)))

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save city-month level dataset
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print(f"Final city-month dataset shape: {city_month.shape}")
print("Key columns in city-month dataset:")
key_cols = ['seed_issuer_id', 'year', 'month', 'rp_article_count', 'has_bond_election', 'has_election_next_month', 'num_bond_elections']
for col in key_cols:
    if col in city_month.columns:
        print(f"  {col}")

# Save city-month level dataset
city_month.write_parquet(f'{data_dir}/TX/News/City_Month_Elections_News_{output_date}.gzip')
city_month.write_csv(f'{data_dir}/TX/News/City_Month_Elections_News_{output_date}.csv')

print(f"Saved city-month dataset: {data_dir}/TX/City_Month_Elections_News_{output_date}.*")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
prepare election-level data with article count windows
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Create year-month index for window calculations
year_month_df = (city_month.select(['year', 'month'])
                 .unique()
                 .sort(['year', 'month'])
                 .with_row_index('year_month_id'))

# Add year_month_id to datasets
city_month = (city_month
              .join(year_month_df, on=['year', 'month'], how='left'))

election_data = (election_data.with_columns(pl.col('year').cast(pl.Int64),
                                            pl.col('month').cast(pl.Int64))
                 .join(year_month_df, on=['year', 'month'], how='left'))

print("Added year_month_id for window calculations")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
calculate article counts in election month and preceding periods
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Get elections with their year_month_id
elections = (election_data
            .select(['issue_id', 'seed_issuer_id', 'year_month_id', 'date_election'])
            .rename({'year_month_id': 'election_year_month_id'}))

print(f"Processing article windows for {elections.shape[0]} elections")

# Election month only (window: 0 to 0)
elections_election_month = (elections
                           .with_columns(year_month_id = pl.col('election_year_month_id')))

elections_election_month = (elections_election_month.with_columns(pl.col('seed_issuer_id').cast(pl.Int64))
                           .join(city_month.select(['seed_issuer_id', 'year_month_id', 'rp_article_count']),
                                 on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                           .group_by(['issue_id', 'election_year_month_id'])
                           .agg(pl.col('rp_article_count').sum().alias('articles_election_month')))

# Election month + 2 months before (window: -2 to 0)
elections_2m_before = (elections
                      .pipe(lambda df_: pl.concat([df_
                                                  .with_columns(year_month_id = pl.col('election_year_month_id').cast(pl.Int64) + i) for i in range(-2, 1)])))

elections_2m_before = (elections_2m_before.with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                                        pl.col('year_month_id').cast(pl.Int64))
                      .join(city_month.select(['seed_issuer_id', 'year_month_id', 'rp_article_count']).with_columns(pl.col('year_month_id').cast(pl.Int64)),
                            on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                      .group_by(['issue_id', 'election_year_month_id'])
                      .agg(pl.col('rp_article_count').sum().alias('articles_2m_before_to_election')))

# Election month + 6 months before (window: -6 to 0)  
elections_6m_before = (elections
                      .pipe(lambda df_: pl.concat([df_
                                                  .with_columns(year_month_id = pl.col('election_year_month_id').cast(pl.Int64) + i) for i in range(-6, 1)])))

elections_6m_before = (elections_6m_before.with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                                        pl.col('year_month_id').cast(pl.Int64))
                      .join(city_month.select(['seed_issuer_id', 'year_month_id', 'rp_article_count']).with_columns(pl.col('year_month_id').cast(pl.Int64)),
                            on = ['seed_issuer_id', 'year_month_id'], how = 'left')
                      .group_by(['issue_id', 'election_year_month_id'])
                      .agg(pl.col('rp_article_count').sum().alias('articles_6m_before_to_election')))

print("Completed article count window calculations")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge article counts back to election-level data
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Start with original election data
election_level = election_data.clone()

# Merge all article count windows
election_level = (election_level
                 .join(elections_election_month,
                       left_on=['issue_id', 'year_month_id'], 
                       right_on=['issue_id', 'election_year_month_id'], 
                       how='left')
                 .join(elections_2m_before,
                       left_on=['issue_id', 'year_month_id'],
                       right_on=['issue_id', 'election_year_month_id'], 
                       how='left')
                 .join(elections_6m_before,
                       left_on=['issue_id', 'year_month_id'],
                       right_on=['issue_id', 'election_year_month_id'],
                       how='left'))

# Fill nulls with zeros
election_level = (election_level
                 .with_columns(pl.col('articles_election_month').fill_null(0),
                              pl.col('articles_2m_before_to_election').fill_null(0),
                              pl.col('articles_6m_before_to_election').fill_null(0)))

# Clean up temporary columns
election_level = election_level.drop(['year_month_id'])

print(f"Election-level dataset final shape: {election_level.shape}")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save election-level dataset
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Save as Stata format (preserving all original variables plus new article counts)
election_level_pandas = election_level.to_pandas()
election_level_pandas.to_stata(f'{data_dir}/TX/News/Election_Level_With_News_{output_date}.dta',
                               write_index=False, version=118)

# Also save as parquet and CSV
election_level.write_parquet(f'{data_dir}/TX/News/Election_Level_With_News_{output_date}.gzip')
election_level.write_csv(f'{data_dir}/TX/News/Election_Level_With_News_{output_date}.csv')

print(f"Saved election-level dataset: {data_dir}/TX/Election_Level_With_News_{output_date}.*")

#%%
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
summary statistics
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("\n" + "="*80)
print("SUMMARY STATISTICS")
print("="*80)

print(f"\nRavenPack Article Processing:")
print(f"  - Total bond-related articles loaded: {rp_articles.shape[0]}")
print(f"  - Cities with article coverage: {rp_cities_with_coverage.shape[0]}")
print(f"  - Entity-month observations with articles: {rp_monthly.shape[0]}")

print(f"\nCity-Month Dataset:")
print(f"  - Total observations: {city_month.shape[0]}")
print(f"  - Unique cities: {city_month.select('seed_issuer_id').n_unique()}")
print(f"  - Months with elections: {city_month.filter(pl.col('has_bond_election') == 1).shape[0]}")
print(f"  - Months with upcoming elections: {city_month.filter(pl.col('has_election_next_month') == 1).shape[0]}")
print(f"  - Months with articles > 0: {city_month.filter(pl.col('rp_article_count') > 0).shape[0]}")

election_summary = (city_month
                   .filter(pl.col('has_bond_election') == 1)
                   .select([pl.col('num_bond_elections').sum(),
                           pl.col('num_go_unlim_elections').sum(), 
                           pl.col('num_go_lim_elections').sum(),
                           pl.col('num_rev_elections').sum()]))

if election_summary.shape[0] > 0:
    print(f"  - Total bond elections: {election_summary.item(0, 0)}")
    print(f"  - GO Unlimited elections: {election_summary.item(0, 1)}")
    print(f"  - GO Limited elections: {election_summary.item(0, 2)}")
    print(f"  - Revenue elections: {election_summary.item(0, 3)}")

print(f"\nElection-Level Dataset:")
print(f"  - Total elections: {election_level.shape[0]}")
print(f"  - Elections with articles in election month: {election_level.filter(pl.col('articles_election_month') > 0).shape[0]}")
print(f"  - Elections with articles in 2m window: {election_level.filter(pl.col('articles_2m_before_to_election') > 0).shape[0]}")
print(f"  - Elections with articles in 6m window: {election_level.filter(pl.col('articles_6m_before_to_election') > 0).shape[0]}")

article_stats = (election_level
                .select([pl.col('articles_election_month').mean().alias('mean_election_month'),
                        pl.col('articles_2m_before_to_election').mean().alias('mean_2m_before'),
                        pl.col('articles_6m_before_to_election').mean().alias('mean_6m_before')]))

print(f"  - Mean articles election month: {article_stats.item(0, 0):.2f}")
print(f"  - Mean articles 2m window: {article_stats.item(0, 1):.2f}")  
print(f"  - Mean articles 6m window: {article_stats.item(0, 2):.2f}")

print(f"\nOutput files created:")
print(f"  - {data_dir}/TX/election_cities_with_bond_coverage_{output_date}.csv")
print(f"  - {data_dir}/TX/City_Month_Elections_News_{output_date}.gzip")
print(f"  - {data_dir}/TX/City_Month_Elections_News_{output_date}.csv") 
print(f"  - {data_dir}/TX/Election_Level_With_News_{output_date}.dta")
print(f"  - {data_dir}/TX/Election_Level_With_News_{output_date}.gzip")
print(f"  - {data_dir}/TX/Election_Level_With_News_{output_date}.csv")

print("\n" + "="*80)
print("SCRIPT COMPLETED SUCCESSFULLY")
print("="*80)
