'''
Load FULL election data (including failed elections) and merge with news article counts
Create two outputs:
1. City-month level time series with bond election indicators
2. Election-level data with article counts in different time windows

FIXED VERSION: Uses correct column names from CSV file
'''

# SET DATE FOR OUTPUT FILES
output_date = '251014'  # YYMMDD format - UPDATE THIS FOR EACH RUN

#%%

#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#setup
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import os

# Data directories - using same structure as News analysis
wrds_dir = '/Volumes/External/WRDS_202408'
#wrds_dir = '/Volumes/Elements/WRDS_202408'
rp_dir = '/Volumes/External/City_RP_Articles_Through_2024'
#rp_dir = '~/Dropbox/City_RP_Articles'
data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data'

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#load full election data including failed elections
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Load FULL Texas election data (includes failed elections)
print("Loading full TX election data including failed elections...")
full_election_data = pl.read_csv(f'{data_dir}/TX/20240510_TX_local_election.csv')

print(f"Full election data shape: {full_election_data.shape}")
print(f"Columns: {full_election_data.columns}")
print(f"Result distribution:")
print(full_election_data.select(pl.col('Result').value_counts()))

# Load the crosswalk to get seed_issuer mappings
crosswalk = pl.read_csv(f'{data_dir}/TX/241120_tx_uniquegovt_fuzzymatch_crosswalk.csv')
print(f"Crosswalk shape: {crosswalk.shape}")
print(f"Crosswalk columns: {crosswalk.columns}")

# Process full election data similar to Stata script
# CRITICAL FIX: Use lowercase governmentname matching like Stata does
election_data = (full_election_data
                # Create lowercase governmentname to exactly match Stata logic
                .with_columns(pl.col('GovernmentName').str.to_lowercase().alias('governmentname'))
                # Create step2-like crosswalk with lowercase governmentname (like Stata line 66)
                .join(crosswalk.with_columns(pl.col('muni_upper').str.to_lowercase().alias('governmentname'))
                        .select(['seed_issuer', 'governmentname']), 
                      on='governmentname', how='inner')
                # Clean election date (using ElectionDate from CSV) 
                .with_columns(pl.col('ElectionDate').str.strptime(pl.Date, format='%m/%d/%Y').alias('date_election'))
                .filter(pl.col('date_election').is_not_null())
                # Extract year/month and ensure Int64 type
                .with_columns(pl.col('date_election').dt.year().cast(pl.Int64).alias('year'),
                              pl.col('date_election').dt.month().cast(pl.Int64).alias('month'))
                # Keep elections from 1995-2024 (as in Stata script)
                .filter(pl.col('year').is_between(1995, 2024))
                # Drop elections that were cancelled
                .filter(pl.col('Result').is_in(['Carried', 'Defeated']))
                # Create passed/failed indicators
                .with_columns((pl.col('Result') == 'Carried').alias('passed'))
                .with_columns((pl.col('Result') == 'Defeated').alias('failed')))

print(f"Election data after processing: {election_data.shape}")
print(f"Elections by result:")
print(election_data.select(pl.col('Result').value_counts()))

# Clean voting data and create vote margin (using proper CSV column names)
election_data = (election_data
                .with_columns((pl.col('VotesFor') + pl.col('VotesAgainst')).alias('votestotal'))
                # Create vote margin (positive for wins, negative for losses)  
                .with_columns(
                    pl.when(pl.col('Result') == 'Carried')
                    .then((pl.col('VotesFor') - pl.col('VotesAgainst')) / pl.col('votestotal'))
                    .when(pl.col('Result') == 'Defeated') 
                    .then(-1 * (pl.col('VotesAgainst') - pl.col('VotesFor')) / pl.col('votestotal'))
                    .otherwise(None)
                    .alias('vote_margin'))
                # Create log amount (using Amount from CSV)
                .with_columns((pl.col('Amount') + 1).log().alias('ln_amount')))

print(f"Vote margin stats:")
vote_margin_stats = election_data.filter(pl.col('vote_margin').is_not_null()).select(pl.col('vote_margin').mean())
print(vote_margin_stats)

# Get unique issuers for mapping (now includes issuers with failed elections)
# CRITICAL: Convert seed_issuer to lowercase to match RavenPack format
election_issuers = (election_data
                   .select(['seed_issuer', 'County'])
                   .unique()
                   .with_columns(pl.col('seed_issuer').str.to_lowercase().alias('seed_issuer'))
                   .rename({'County': 'county'}))

print(f"Number of unique election issuers: {election_issuers.shape[0]}")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#load rp map and filter for election issuers
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# load rp map and add fips
rp_map = pl.read_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv')
fips = (pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')
        .select(['rp_entity_id', 'fips']))
rp_map = (rp_map
          .join(fips, on = 'rp_entity_id', how = 'left'))

print(f"Total RavenPack entities: {rp_map.shape[0]}")

# Filter rp_map to only include entities that appear in our election data
# Note: now matching on seed_issuer name instead of seed_issuer_id since full data doesn't have IDs
rp_map_elections = (rp_map
                   .join(election_issuers.select(['seed_issuer']),
                         on='seed_issuer', how='inner'))

print(f"RavenPack entities in election sample: {rp_map_elections.shape[0]}")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#define keywords and load rp articles with bond-related filtering
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Define bond-related keywords (using same as original script)
keywords = [
     "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable", "property tax",
     "issuance", "offering",  "yield",
    "debt", "underwriter", "underwriting", "rating", "credit", "refunding",
    "callable", "coupon", "referendum"
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

# Get list of entity IDs to filter on
election_entity_ids = rp_map_elections.select('rp_entity_id')['rp_entity_id'].to_list()

newswires = ['B5569E', 'D19959', '53A5CA', '751371', 'A51917', '4A513E']
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(election_entity_ids))
               .filter(pl.col('relevance').ge(90))
.filter(~pl.col('rp_source_id').is_in(newswires))
               .filter(pl.col("headline").str.to_lowercase().str.contains(pattern))
                #.with_columns(pl.col('rpa_date_utc').cast(pl.Date))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))

print(f"Loaded {rp_articles.shape[0]} bond-related articles for election sample")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#load all articles (non-bond-filtered) for total article count and unique sources
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Load ALL articles (no bond keyword filter) for total article count and source diversity
print("Loading all RavenPack articles (no bond filter) for total counts...")

rp_all_articles = (pl
                   .scan_parquet(f'{rp_dir}/*')
                   .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
                   .filter(pl.col('rp_entity_id').is_in(election_entity_ids))
                   .filter(pl.col('relevance').ge(90))
                   # No bond keyword filter - we want ALL articles
                   .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                   .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
                   .collect(streaming = True))

print(f"Loaded {rp_all_articles.shape[0]} total articles (no bond filter) for election sample")

# Aggregate ALL articles to monthly level with source tracking
rp_all_monthly = (rp_all_articles
                  .with_columns(pl.col('rpa_date_utc').dt.month().cast(pl.Int64).alias('month'),
                                pl.col('rpa_date_utc').dt.year().cast(pl.Int64).alias('year'))
                  .group_by(['rp_entity_id', 'year', 'month'])
                  .agg(pl.col('headline').count().alias('all_article_count'),
                       pl.col('rp_source_id').alias('sources')))  # Keep list of sources

print(f"All articles monthly aggregates: {rp_all_monthly.shape[0]} entity-month observations")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#aggregate articles to monthly level
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

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
              .with_columns(pl.col('rpa_date_utc').dt.month().cast(pl.Int64).alias('month'),
                            pl.col('rpa_date_utc').dt.year().cast(pl.Int64).alias('year'))
              .group_by(['rp_entity_id', 'year', 'month'])
              .agg(pl.col('headline').count().alias('rp_article_count')))

print(f"Monthly article aggregates: {rp_monthly.shape[0]} entity-month observations")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#create comprehensive city-month time series
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Create a list of all possible combinations of seed_issuer, year, and month
min_year = election_data.select(pl.col('year').min()).item()
max_year = election_data.select(pl.col('year').max()).item()

data = []
for issuer in rp_map_elections['seed_issuer'].unique():
    for year in range(min_year, max_year + 1):
        for month in range(1, 13):
            data.append({'seed_issuer': issuer, 'year': year, 'month': month})

city_month = (pl.DataFrame(data)
              # Ensure consistent Int64 types
              .with_columns(pl.col('year').cast(pl.Int64),
                           pl.col('month').cast(pl.Int64)))

# merge with rp-entity-id
city_month = (city_month
              .join(rp_map_elections, on = 'seed_issuer', how = 'left'))

# merge with rp_monthly
city_month = (city_month
              .join(rp_monthly, on = ['rp_entity_id', 'year', 'month'], how = 'left'))

# fill null with zero
city_month = (city_month
              .with_columns(pl.col('rp_article_count').fill_null(0)))

print(f"City-month framework: {city_month.shape[0]} observations")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#aggregate election data and create election indicators
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Aggregate elections to monthly level for city-month indicators  
# CRITICAL: Convert seed_issuer to lowercase to match city_month format
election_monthly = (election_data
                   .with_columns(pl.col('seed_issuer').str.to_lowercase().alias('seed_issuer'))
                   .group_by(['seed_issuer', 'year', 'month'])
                   .agg(pl.len().alias('num_bond_elections'),
                        pl.col('Amount').sum().alias('total_election_amount'),
                        pl.col('vote_margin').mean().alias('avg_vote_margin'),
                        pl.col('passed').sum().alias('num_passed_elections'),
                        pl.col('failed').sum().alias('num_failed_elections'),
                        pl.col('passed').mean().alias('passage_rate')))

# Create binary indicators
election_monthly = (election_monthly
                   .with_columns(pl.lit(1).alias('has_bond_election')))

# Merge election indicators with city_month
city_month = (city_month
              .join(election_monthly,  # Types should already be consistent
                    on = ['seed_issuer', 'year', 'month'], how = 'left')
              .with_columns(pl.col('has_bond_election').fill_null(0),
                           pl.col('num_bond_elections').fill_null(0),
                           pl.col('total_election_amount').fill_null(0),
                           pl.col('num_passed_elections').fill_null(0),
                           pl.col('num_failed_elections').fill_null(0),
                           pl.col('passage_rate').fill_null(0)))

print(f"City-month with elections: {city_month.filter(pl.col('has_bond_election') == 1).shape[0]} months with elections")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#create forward-looking election indicators (upcoming month)
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Sort for time series operations
city_month = city_month.sort(['seed_issuer', 'year', 'month'])

# Create forward-looking indicators
city_month = (city_month
             .with_columns(pl.col('has_bond_election').shift(-1).over('seed_issuer').alias('has_election_next_month'),
                          pl.col('num_bond_elections').shift(-1).over('seed_issuer').alias('num_elections_next_month')))

# Fill nulls 
city_month = (city_month
             .with_columns(pl.col('has_election_next_month').fill_null(0),
                          pl.col('num_elections_next_month').fill_null(0)))


#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#prepare election-level data with article count windows
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Create year-month index for window calculations
year_month_df = (city_month.select(['year', 'month'])
                 .unique()
                 .sort(['year', 'month'])
                 .with_row_index('year_month_id')
                 # Ensure consistent data types
                 .with_columns(pl.col('year').cast(pl.Int64),
                              pl.col('month').cast(pl.Int64),
                              pl.col('year_month_id').cast(pl.Int64)))

# Add year_month_id to datasets
city_month = (city_month
              .join(year_month_df, on=['year', 'month'], how='left'))

# Filter election_data to only include issuers with RavenPack coverage
# This ensures election-level dataset only includes elections where news coverage is possible
election_data = (election_data
                 .join(year_month_df, on=['year', 'month'], how='left')
                 # CRITICAL: Filter to only include issuers that appear in RavenPack mapping
                 .with_columns(pl.col('seed_issuer').str.to_lowercase().alias('seed_issuer_lower'))
                 .join(rp_map_elections.select('seed_issuer').unique(), 
                       left_on='seed_issuer_lower', right_on='seed_issuer', how='inner')
                 .drop('seed_issuer_lower'))

print(f"Filtered election data to only include RavenPack-matched issuers: {election_data.shape[0]} elections")
print(f"Unique seed_issuers in filtered election data: {election_data.with_columns(pl.col('seed_issuer').str.to_lowercase().alias('seed_issuer_lower')).select('seed_issuer_lower').n_unique()}")
print("Added year_month_id for window calculations")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#calculate article counts in election month and preceding periods
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Get elections with their year_month_id - now using a unique identifier since no issue_id
# CRITICAL: Convert seed_issuer to lowercase to match city_month format for joins
elections = (election_data
            .with_row_index('election_id')
            .with_columns(pl.col('seed_issuer').str.to_lowercase().alias('seed_issuer'))
            .select(['election_id', 'seed_issuer', 'year_month_id', 'date_election', 'passed', 'failed', 'vote_margin', 'Amount', 'Result'])
            .rename({'year_month_id': 'election_year_month_id'}))

print(f"Processing article windows for {elections.shape[0]} elections")

# Election month only (window: 0 to 0)
elections_election_month = (elections
                           .with_columns(year_month_id = pl.col('election_year_month_id').cast(pl.Int64)))

elections_election_month = (elections_election_month
                           .join(city_month.select(['seed_issuer', 'year_month_id', 'rp_article_count']),
                                 on = ['seed_issuer', 'year_month_id'], how = 'left')
                           .group_by(['election_id', 'election_year_month_id'])
                           .agg(pl.col('rp_article_count').sum().alias('articles_election_month')))

# Election month + 2 months before (window: -2 to 0)
elections_2m_before = (elections
                      .with_columns(pl.col('election_year_month_id').cast(pl.Int64).alias('election_year_month_id'))
                      .pipe(lambda df_: pl.concat([df_
                                                  .with_columns(year_month_id = (pl.col('election_year_month_id') + i).cast(pl.Int64)) for i in range(-1, 1)])))

elections_2m_before = (elections_2m_before
                      .join(city_month.select(['seed_issuer', 'year_month_id', 'rp_article_count']),
                            on = ['seed_issuer', 'year_month_id'], how = 'left')
                      .group_by(['election_id', 'election_year_month_id'])
                      .agg(pl.col('rp_article_count').sum().alias('articles_2m_before_to_election')))

# Election month + 3 months before (window: -3 to 0)
elections_3m_before = (elections
                      .with_columns(pl.col('election_year_month_id').cast(pl.Int64).alias('election_year_month_id'))
                      .pipe(lambda df_: pl.concat([df_
                                                  .with_columns(year_month_id = (pl.col('election_year_month_id') + i).cast(pl.Int64)) for i in range(-3, 1)])))

elections_3m_before = (elections_3m_before
                      .join(city_month.select(['seed_issuer', 'year_month_id', 'rp_article_count']),
                            on = ['seed_issuer', 'year_month_id'], how = 'left')
                      .group_by(['election_id', 'election_year_month_id'])
                      .agg(pl.col('rp_article_count').sum().alias('articles_3m_before_to_election')))

# Election month + 6 months before (window: -6 to 0)  
elections_6m_before = (elections
                      .with_columns(pl.col('election_year_month_id').cast(pl.Int64).alias('election_year_month_id'))
                      .pipe(lambda df_: pl.concat([df_
                                                  .with_columns(year_month_id = (pl.col('election_year_month_id') + i).cast(pl.Int64)) for i in range(-6, 1)])))

elections_6m_before = (elections_6m_before
                      .join(city_month.select(['seed_issuer', 'year_month_id', 'rp_article_count']),
                            on = ['seed_issuer', 'year_month_id'], how = 'left')
                      .group_by(['election_id', 'election_year_month_id'])
                      .agg(pl.col('rp_article_count').sum().alias('articles_6m_before_to_election')))

print("Completed article count window calculations")

# Calculate total articles and unique sources in 12 months prior to election
# Create comprehensive city-month framework for ALL articles (similar to existing city_month but for all articles)
city_month_all = (city_month.select(['seed_issuer', 'rp_entity_id', 'year', 'month', 'year_month_id'])
                  .join(rp_all_monthly, on=['rp_entity_id', 'year', 'month'], how='left')
                  .with_columns(pl.col('all_article_count').fill_null(0)))

# Calculate total articles in 12 months prior to election (window: -12 to -1)
elections_12m_total_articles = (elections
                               .with_columns(pl.col('election_year_month_id').cast(pl.Int64).alias('election_year_month_id'))
                               .pipe(lambda df_: pl.concat([df_
                                                           .with_columns(year_month_id = (pl.col('election_year_month_id') + i).cast(pl.Int64)) for i in range(-12, 0)])))

elections_12m_total_articles = (elections_12m_total_articles
                               .join(city_month_all.select(['seed_issuer', 'year_month_id', 'all_article_count']),
                                     on=['seed_issuer', 'year_month_id'], how='left')
                               .group_by(['election_id', 'election_year_month_id'])
                               .agg(pl.col('all_article_count').sum().alias('total_articles_12m_prior')))

# Calculate unique sources in 12 months prior to election (window: -12 to -1)
elections_12m_unique_sources = (elections
                               .with_columns(pl.col('election_year_month_id').cast(pl.Int64).alias('election_year_month_id'))
                               .pipe(lambda df_: pl.concat([df_
                                                           .with_columns(year_month_id = (pl.col('election_year_month_id') + i).cast(pl.Int64)) for i in range(-12, 0)])))

elections_12m_unique_sources = (elections_12m_unique_sources
                               .join(city_month_all.select(['seed_issuer', 'year_month_id', 'sources']),
                                     on=['seed_issuer', 'year_month_id'], how='left')
                               .group_by(['election_id', 'election_year_month_id'])
                               .agg(pl.col('sources').flatten().alias('all_sources'))
                               .with_columns(pl.col('all_sources').list.drop_nulls())
                               .with_columns(pl.col('all_sources').list.n_unique().alias('unique_sources_12m_prior'))
                               .select(['election_id', 'election_year_month_id', 'unique_sources_12m_prior']))

print("Completed 12-month total articles and unique sources calculations")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#load county-level demographic data for year prior to election
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Load county-level demographic data
print("Loading county-level demographic data...")

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
                                on=['fips_str', 'year'], how='left')
                          .join(demo_data['pers_inc'].select(['fips_str', 'year', 'pers_inc']),
                                on=['fips_str', 'year'], how='left')
                          .join(demo_data['pop'].select(['fips_str', 'year', 'pop']),
                                on=['fips_str', 'year'], how='left')
                          .join(demo_data['gdp'].select(['fips_str', 'year', 'gdp']),
                                on=['fips_str', 'year'], how='left'))
    
    # Filter to Texas counties only (FIPS starting with 48)
    county_demographics = county_demographics.filter(pl.col('fips_str').str.starts_with('48'))
    
    print(f"Merged county demographics: {county_demographics.shape[0]} TX county-year observations")
    print(f"Years available: {sorted(county_demographics.select('year').unique().to_series().to_list())}")
    print(f"TX counties: {county_demographics.select('fips_str').n_unique()} unique counties")
else:
    print("Error: Could not load all demographic files")
    county_demographics = None

# Create FIPS mapping for elections using RavenPack Cities with FIPS
print("Creating FIPS mapping for elections...")
rp_fips_mapping = pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')

# Clean up the state column (remove leading space) and filter for Texas
rp_fips_mapping = (rp_fips_mapping
                   .with_columns(pl.col('state').str.strip_chars().alias('state_clean'))
                   .filter(pl.col('state_clean') == 'TX')
                   .filter(pl.col('fips').is_not_null())
                   .with_columns(pl.col('fips').cast(pl.Int64).cast(pl.Utf8).str.zfill(5).alias('fips_str')))

print(f"Texas cities with FIPS codes: {rp_fips_mapping.shape[0]}")

# Create election-year-prior demographic lookup if demographic data loaded successfully
if county_demographics is not None:
    # Get unique election years from our election data
    election_years = sorted(election_data.select('year').unique().to_series().to_list())
    print(f"Election years: {election_years}")
    
    # Create demographic data for year prior to each election
    # For each election year, get demographics from year-1 
    election_demographics = []
    for election_year in election_years:
        demo_year = election_year - 1
        if demo_year >= 2001:  # Only if demographic data available
            year_demo = (county_demographics
                        .filter(pl.col('year') == demo_year)
                        .with_columns(pl.lit(election_year).alias('election_year'))
                        .select(['fips_str', 'election_year', 'geoname', 'employment', 
                                'percap_inc', 'pers_inc', 'pop', 'gdp']))
            election_demographics.append(year_demo)
    
    if election_demographics:
        election_year_demographics = pl.concat(election_demographics)
        print(f"Election-year demographics created: {election_year_demographics.shape[0]} county-election-year observations")
        print(f"Coverage: elections {sorted(election_year_demographics.select('election_year').unique().to_series().to_list())}")
    else:
        election_year_demographics = None
        print("No demographic data available for election years")
else:
    election_year_demographics = None
    print("Skipping demographic preparation due to data loading issues")

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#merge article counts back to election-level data
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Start with original election data
# CRITICAL: Convert seed_issuer to lowercase to match the joins we'll do with city_month
election_level = (election_data
                 .with_row_index('election_id')
                 .with_columns(pl.col('seed_issuer').str.to_lowercase().alias('seed_issuer')))

# Merge all article count windows
election_level = (election_level
                 .join(elections_election_month,
                       left_on=['election_id', 'year_month_id'], 
                       right_on=['election_id', 'election_year_month_id'], 
                       how='left')
                 .join(elections_2m_before,
                       left_on=['election_id', 'year_month_id'],
                       right_on=['election_id', 'election_year_month_id'], 
                       how='left')
                    .join(elections_3m_before,
                          left_on=['election_id', 'year_month_id'],
                            right_on=['election_id', 'election_year_month_id'],
                            how='left')
                 .join(elections_6m_before,
                       left_on=['election_id', 'year_month_id'],
                       right_on=['election_id', 'election_year_month_id'],
                       how='left')
                 .join(elections_12m_total_articles,
                       left_on=['election_id', 'year_month_id'],
                       right_on=['election_id', 'election_year_month_id'],
                       how='left')
                 .join(elections_12m_unique_sources,
                       left_on=['election_id', 'year_month_id'], 
                       right_on=['election_id', 'election_year_month_id'],
                       how='left'))

# Fill nulls with zeros
election_level = (election_level
                 .with_columns(pl.col('articles_election_month').fill_null(0),
                              pl.col('articles_2m_before_to_election').fill_null(0),
pl.col('articles_3m_before_to_election').fill_null(0),
                              pl.col('articles_6m_before_to_election').fill_null(0),
                              pl.col('total_articles_12m_prior').fill_null(0),
                              pl.col('unique_sources_12m_prior').fill_null(0)))

# Merge county-level demographics if available
if election_year_demographics is not None:
    print("Merging county-level demographics into election-level dataset...")
    
    # First, we need to connect seed_issuer to FIPS codes
    # We'll use the existing rp_map that already has FIPS codes
    election_level = (election_level
                     .join(rp_map.select(['seed_issuer', 'fips']), on='seed_issuer', how='left')
                     # Convert fips to string format for matching
                     .with_columns(pl.when(pl.col('fips').is_not_null())
                                   .then(pl.col('fips').cast(pl.Int64).cast(pl.Utf8).str.zfill(5))
                                   .otherwise(None)
                                   .alias('fips_str')))
    
    # Merge with year-prior demographics
    election_level = (election_level
                     .join(election_year_demographics.select(['fips_str', 'election_year', 'employment', 
                                                              'percap_inc', 'pers_inc', 'pop', 'gdp']).with_columns(pl.col('election_year').cast(pl.Int64)),
                           left_on=['fips_str', 'year'],
                           right_on=['fips_str', 'election_year'],
                           how='left')
                     # Add prefix to demographic variables for clarity
                     .rename({'employment': 'county_employment_prior',
                             'percap_inc': 'county_percap_inc_prior',
                             'pers_inc': 'county_pers_inc_prior', 
                             'pop': 'county_pop_prior',
                             'gdp': 'county_gdp_prior'}))
    
    # Clean up temporary columns
    election_level = election_level.drop(['year_month_id', 'fips', 'fips_str'])

    # Create log-adjusted versions of demographic variables (log(1 + x))
    election_level = (election_level
                     .with_columns(
                        (pl.col('county_pop_prior')).log().alias('ln_county_pop_prior'),
                        (pl.col('county_gdp_prior')).log().alias('ln_county_gdp_prior'),
                        (pl.col('county_pers_inc_prior')).log().alias('ln_county_pers_inc_prior'),
                        (pl.col('county_percap_inc_prior')).log().alias('ln_county_percap_inc_prior'),
                        (pl.col('county_employment_prior')).log().alias('ln_county_employment_prior')
                     ))
    
    print(f"Elections with demographic data: {election_level.filter(pl.col('county_pop_prior').is_not_null()).shape[0]}")
else:
    print("Skipping demographic merge due to data availability issues")
    election_level = election_level.drop(['year_month_id'])

print(f"Election-level dataset final shape: {election_level.shape}")


#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# merge with mergent purposes
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
mergent_purpose = (pl.read_csv(f'{data_dir}/TX/2025-03-24_texasbondpurpose_classify.csv')
                   .rename({'purposedescription':'PurposeDescription'})
                   .select(['purp_broad_new', 'PurposeDescription']))

election_level = (election_level
                  .join(mergent_purpose, on = 'PurposeDescription', how = 'left'))

#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# merge city month with demo variables
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
city_month = (city_month
              .with_columns(pl.col('fips').cast(pl.String).alias('fips_str'))
              .join(county_demographics, on = ['fips_str', 'year'], how = 'left')
              .with_columns(
    (pl.col('pop')).log().alias('ln_county_pop_prior'),
    (pl.col('gdp')).log().alias('ln_county_gdp_prior'),
    (pl.col('pers_inc')).log().alias('ln_county_pers_inc_prior'),
    (pl.col('percap_inc')).log().alias('ln_county_percap_inc_prior'),
    (pl.col('employment')).log().alias('ln_county_employment_prior')
))


#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#save city-month level dataset
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print(f"Final city-month dataset shape: {city_month.shape}")
print("Key columns in city-month dataset:")
key_cols = ['seed_issuer', 'year', 'month', 'rp_article_count', 'has_bond_election', 'has_election_next_month', 'num_bond_elections', 'num_passed_elections', 'num_failed_elections']
for col in key_cols:
    if col in city_month.columns:
        print(f"  {col}")

# Save city -month level dataset
city_month.write_parquet(f'{data_dir}/TX/City_Month_Elections_News_WithFailed_{output_date}.gzip')
city_month.write_csv(f'{data_dir}/TX/City_Month_Elections_News_WithFailed_{output_date}.csv')

print(f"Saved city-month dataset: {data_dir}/TX/City_Month_Elections_News_WithFailed_{output_date}.*")


#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#save election-level dataset
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# Save as CSV and parquet (easier to work with than Stata for exploratory analysis)
election_level.write_parquet(f'{data_dir}/TX/News/Election_Level_With_News_WithFailed_{output_date}.gzip')
election_level.write_csv(f'{data_dir}/TX/News/Election_Level_With_News_WithFailed_{output_date}.csv')

print(f"Saved election-level dataset: {data_dir}/TX/News/Election_Level_With_News_WithFailed_{output_date}.*")



#%%
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#summary statistics
#''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

print("\n" + "="*80)
print("SUMMARY STATISTICS - WITH FAILED ELECTIONS")
print("="*80)

print(f"\nRavenPack Article Processing:")
print(f"  - Total bond-related articles loaded: {rp_articles.shape[0]}")
print(f"  - Total articles loaded (no bond filter): {rp_all_articles.shape[0]}")
print(f"  - Cities with article coverage: {rp_cities_with_coverage.shape[0]}")
print(f"  - Entity-month observations with bond articles: {rp_monthly.shape[0]}")
print(f"  - Entity-month observations with all articles: {rp_all_monthly.shape[0]}")

print(f"\nCity-Month Dataset:")
print(f"  - Total observations: {city_month.shape[0]}")
print(f"  - Unique cities: {city_month.select('seed_issuer').n_unique()}")
print(f"  - Months with elections: {city_month.filter(pl.col('has_bond_election') == 1).shape[0]}")
print(f"  - Months with upcoming elections: {city_month.filter(pl.col('has_election_next_month') == 1).shape[0]}")
print(f"  - Months with articles > 0: {city_month.filter(pl.col('rp_article_count') > 0).shape[0]}")

election_summary = (city_month
                   .filter(pl.col('has_bond_election') == 1)
                   .select([pl.col('num_bond_elections').sum(),
                           pl.col('num_passed_elections').sum(), 
                           pl.col('num_failed_elections').sum()]))

if election_summary.shape[0] > 0:
    print(f"  - Total bond elections: {election_summary.item(0, 0)}")
    print(f"  - Passed elections: {election_summary.item(0, 1)}")
    print(f"  - Failed elections: {election_summary.item(0, 2)}")
    print(f"  - Overall passage rate: {election_summary.item(0, 1) / election_summary.item(0, 0):.2%}")

print(f"\nElection-Level Dataset (Including Failed Elections):")
print(f"  - Total elections: {election_level.shape[0]}")
print(f"  - Passed elections: {election_level.filter(pl.col('passed') == True).shape[0]}")
print(f"  - Failed elections: {election_level.filter(pl.col('failed') == True).shape[0]}")
print(f"  - Elections with articles in election month: {election_level.filter(pl.col('articles_election_month') > 0).shape[0]}")
print(f"  - Elections with articles in 2m window: {election_level.filter(pl.col('articles_2m_before_to_election') > 0).shape[0]}")
print(f"  - Elections with articles in 6m window: {election_level.filter(pl.col('articles_6m_before_to_election') > 0).shape[0]}")
print(f"  - Elections with total articles in 12m prior: {election_level.filter(pl.col('total_articles_12m_prior') > 0).shape[0]}")
print(f"  - Elections with unique sources in 12m prior: {election_level.filter(pl.col('unique_sources_12m_prior') > 0).shape[0]}")

# Add demographic data summary if available
if 'county_pop_prior' in election_level.columns:
    elections_with_demo = election_level.filter(pl.col('county_pop_prior').is_not_null())
    print(f"  - Elections with county demographic data: {elections_with_demo.shape[0]}")
    
    if elections_with_demo.shape[0] > 0:
        demo_stats = elections_with_demo.select([
            pl.col('county_pop_prior').mean().alias('mean_pop'),
            pl.col('county_percap_inc_prior').mean().alias('mean_percap_inc'),
            pl.col('county_employment_prior').mean().alias('mean_employment'),
            pl.col('county_gdp_prior').mean().alias('mean_gdp')
        ])
        print(f"  - Mean county population (year prior): {demo_stats.item(0, 0):,.0f}")
        print(f"  - Mean county per capita income (year prior): ${demo_stats.item(0, 1):,.0f}")
        print(f"  - Mean county employment (year prior): {demo_stats.item(0, 2):,.0f}")
        print(f"  - Mean county GDP (year prior): ${demo_stats.item(0, 3):,.0f}")

article_stats = (election_level
                .select([pl.col('articles_election_month').mean().alias('mean_election_month'),
                        pl.col('articles_2m_before_to_election').mean().alias('mean_2m_before'),
                        pl.col('articles_6m_before_to_election').mean().alias('mean_6m_before'),
                        pl.col('total_articles_12m_prior').mean().alias('mean_total_12m_prior'),
                        pl.col('unique_sources_12m_prior').mean().alias('mean_sources_12m_prior')]))

print(f"  - Mean articles election month: {article_stats.item(0, 0):.2f}")
print(f"  - Mean articles 2m window: {article_stats.item(0, 1):.2f}")  
print(f"  - Mean articles 6m window: {article_stats.item(0, 2):.2f}")
print(f"  - Mean total articles 12m prior: {article_stats.item(0, 3):.2f}")
print(f"  - Mean unique sources 12m prior: {article_stats.item(0, 4):.2f}")

# Compare article counts for passed vs failed elections
passed_article_stats = (election_level.filter(pl.col('passed') == True)
                        .select([pl.col('articles_election_month').mean(),
                                pl.col('articles_2m_before_to_election').mean(),
                                pl.col('articles_6m_before_to_election').mean(),
                                pl.col('total_articles_12m_prior').mean(),
                                pl.col('unique_sources_12m_prior').mean()]))

failed_article_stats = (election_level.filter(pl.col('failed') == True)
                        .select([pl.col('articles_election_month').mean(),
                                pl.col('articles_2m_before_to_election').mean(),
                                pl.col('articles_6m_before_to_election').mean(),
                                pl.col('total_articles_12m_prior').mean(),
                                pl.col('unique_sources_12m_prior').mean()]))

if passed_article_stats.shape[0] > 0 and failed_article_stats.shape[0] > 0:
    print(f"\nArticle Coverage by Election Outcome:")
    print(f"  - Passed elections - mean articles election month: {passed_article_stats.item(0, 0):.2f}")
    print(f"  - Failed elections - mean articles election month: {failed_article_stats.item(0, 0):.2f}")
    print(f"  - Passed elections - mean articles 6m window: {passed_article_stats.item(0, 2):.2f}")
    print(f"  - Failed elections - mean articles 6m window: {failed_article_stats.item(0, 2):.2f}")
    print(f"  - Passed elections - mean total articles 12m prior: {passed_article_stats.item(0, 3):.2f}")
    print(f"  - Failed elections - mean total articles 12m prior: {failed_article_stats.item(0, 3):.2f}")
    print(f"  - Passed elections - mean unique sources 12m prior: {passed_article_stats.item(0, 4):.2f}")
    print(f"  - Failed elections - mean unique sources 12m prior: {failed_article_stats.item(0, 4):.2f}")
    
    # Add demographic comparison if available
    if 'county_pop_prior' in election_level.columns:
        passed_demo_stats = (election_level.filter((pl.col('passed') == True) & (pl.col('county_pop_prior').is_not_null()))
                            .select([pl.col('county_pop_prior').mean(),
                                    pl.col('county_percap_inc_prior').mean(),
                                    pl.col('county_employment_prior').mean(),
                                    pl.col('county_gdp_prior').mean()]))
        
        failed_demo_stats = (election_level.filter((pl.col('failed') == True) & (pl.col('county_pop_prior').is_not_null()))
                            .select([pl.col('county_pop_prior').mean(),
                                    pl.col('county_percap_inc_prior').mean(),
                                    pl.col('county_employment_prior').mean(),
                                    pl.col('county_gdp_prior').mean()]))
        
        if passed_demo_stats.shape[0] > 0 and failed_demo_stats.shape[0] > 0:
            print(f"\nCounty Demographics by Election Outcome:")
            print(f"  - Passed elections - mean county population: {passed_demo_stats.item(0, 0):,.0f}")
            print(f"  - Failed elections - mean county population: {failed_demo_stats.item(0, 0):,.0f}")
            print(f"  - Passed elections - mean per capita income: ${passed_demo_stats.item(0, 1):,.0f}")
            print(f"  - Failed elections - mean per capita income: ${failed_demo_stats.item(0, 1):,.0f}")

print(f"\nOutput files created:")
print(f"  - {data_dir}/TX/election_cities_with_bond_coverage_{output_date}.csv")
print(f"  - {data_dir}/TX/City_Month_Elections_News_WithFailed_{output_date}.gzip")
print(f"  - {data_dir}/TX/City_Month_Elections_News_WithFailed_{output_date}.csv") 
print(f"  - {data_dir}/TX/Election_Level_With_News_WithFailed_{output_date}.dta")
print(f"  - {data_dir}/TX/Election_Level_With_News_WithFailed_{output_date}.gzip")
print(f"  - {data_dir}/TX/Election_Level_With_News_WithFailed_{output_date}.csv")

print("\n" + "="*80)
print("SCRIPT COMPLETED SUCCESSFULLY")
print("="*80)
