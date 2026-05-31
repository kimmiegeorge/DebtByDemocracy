'''
Create outcome variables based on parsing
UPDATED VERSION: Combines original scraping data with recovered URLs data
'''
#%%
import polars as pl
import os
import json
import re
from pathlib import Path
import pandas as pd
from collections import Counter

# Original data directory
input_dir_original = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Updated Scraping 202509/Processed')

# Recovered URLs data directory
input_dir_recovered = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Recovered URLs From Bad URLs Investigation/Processed')

data_dir = '~/Dropbox/Voting on Bonds/Data'
output_date = '251111'  # Updated date

print("="*70)
print("Creating Variables from Combined WBM Data")
print("="*70)
print(f"\nOriginal data:  {input_dir_original}")
print(f"Recovered data: {input_dir_recovered}\n")

#%% Load and combine RES files from both sources
print("📊 Loading RES files...")
res_file_dfs = []

# Load original res files
print("  - Loading original res files...")
original_count = 0
for f in Path(f'{input_dir_original}/res/').glob("*.csv"):
    try:
        df = pl.scan_csv(f).with_columns([
            pl.col('parent url').cast(pl.Utf8, strict = False),
            pl.col('URL').cast(pl.Utf8, strict = False),
            pl.col('original_url').cast(pl.Utf8, strict = False),
            pl.col('priority').cast(pl.Int64, strict = False),
            pl.col('content_length').cast(pl.Int64, strict = False),
            pl.col('text').cast(pl.Utf8, strict = False)
        ]).select(['parent url', 'URL', 'original_url', 'priority', 'content_length', 'text'])
        res_file_dfs.append(df)
        original_count += 1
    except Exception as e:
        print(f"    Warning: Could not load {f}: {e}")

print(f"    ✅ Loaded {original_count} original res files")

# Load recovered res files
print("  - Loading recovered res files...")
recovered_count = 0
if os.path.exists(f'{input_dir_recovered}/res/'):
    for f in Path(f'{input_dir_recovered}/res/').glob("*.csv"):
        try:
            df = pl.scan_csv(f).with_columns([
                pl.col('parent url').cast(pl.Utf8, strict = False),
                pl.col('URL').cast(pl.Utf8, strict = False),
                pl.col('original_url').cast(pl.Utf8, strict = False),
                pl.col('priority').cast(pl.Int64, strict = False),
                pl.col('content_length').cast(pl.Int64, strict = False),
                pl.col('text').cast(pl.Utf8, strict = False)
            ]).select(['parent url', 'URL', 'original_url', 'priority', 'content_length', 'text'])
            res_file_dfs.append(df)
            recovered_count += 1
        except Exception as e:
            print(f"    Warning: Could not load {f}: {e}")
    print(f"    ✅ Loaded {recovered_count} recovered res files")
else:
    print(f"    ⚠️  Recovered res directory not found")

print(f"\n  Total res files: {original_count + recovered_count}")

# Combine all res files
res_files = (pl.concat(res_file_dfs, how = "diagonal")
             .collect(streaming = True)
             )

# get year
res_files = (res_files
       .with_columns(pl.col('parent url').str.slice(28, 4).alias('year')))

# Deduplicate: If there are multiple pulls for the same URL-year (from original + recovered),
# keep only the one with the most sub-URLs
print("\n  🔍 Checking for duplicate URL-year pairs...")
original_rows = res_files.height

# Count URLs per parent URL and year to identify which pull has more data
res_files = (res_files
    .with_columns(
        pl.col('URL').count().over(['original_url', 'year', 'parent url']).alias('pull_sub_count')
    )
)

# For each original_url-year pair, keep only the parent url with the most sub-URLs
res_files_deduplicated = (res_files
    .with_columns(
        pl.col('pull_sub_count').max().over(['original_url', 'year']).alias('max_sub_count_for_pair')
    )
    # Keep only rows from the pull with the maximum sub-URL count
    .filter(pl.col('pull_sub_count') == pl.col('max_sub_count_for_pair'))
    # If there are still ties (same count from multiple pulls), keep the first one
    .unique(subset=['original_url', 'year', 'URL'], keep='first')
    .drop(['pull_sub_count', 'max_sub_count_for_pair'])
)

deduped_rows = res_files_deduplicated.height
if original_rows != deduped_rows:
    print(f"    ⚠️  Found duplicates: Removed {original_rows - deduped_rows} rows from lower-quality pulls")
    
    # Report which URL-year pairs had duplicates
    duplicate_pairs = (res_files
        .select(['original_url', 'year', 'parent url'])
        .unique()
        .group_by(['original_url', 'year'])
        .count()
        .filter(pl.col('count') > 1)
    )
    if duplicate_pairs.height > 0:
        print(f"    📋 {duplicate_pairs.height} URL-year pairs had multiple pulls")
else:
    print(f"    ✅ No duplicates found")

res_files = res_files_deduplicated

# count per url year
res_files = (res_files
             .with_columns(pl.col('URL').count().over(['parent url', 'year']).alias('total_subs')))

# Define URL keywords to search for
URL_KEYWORDS = ['bond', 'debt', 'tax', 'fiscal', 'budget', 'audit', 'credit', 'capital']

# Create columns for each keyword
url_keyword_cols = []
for keyword in URL_KEYWORDS:
    url_keyword_cols.append(
        pl.col('URL').str.to_lowercase().str.contains(keyword).alias(f'{keyword}_url')
    )

res_files = res_files.with_columns(url_keyword_cols)

res_files = (res_files
             .with_columns(pl.col('priority').fill_null(0)))

# Count numeric tokens (sequences of digits) in page text
res_files = res_files.with_columns(
    pl.col('text').fill_null('').str.count_matches(r'\d+').alias('numeric_tokens')
)

# Create combined finance URL column
all_finance_pattern = '|'.join(['bond', 'debt', 'finance', 'financial', 'credit', 'fiscal', 'capital', 'tax', 'budget', 'fy'])
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase()
                           .str.contains(all_finance_pattern).alias('all_finance_url')))

# Create bond_or_debt_url for backward compatibility
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase().str.contains('bond|debt').alias('bond_or_debt_url')))

# Aggregate URL counts
agg_cols = [pl.col('total_subs').first()]

# Add counts for each keyword
for keyword in URL_KEYWORDS:
    agg_cols.append(pl.col(f'{keyword}_url').sum())

# Add special combined columns
agg_cols.extend([
    pl.col('bond_or_debt_url').sum(),
    pl.col('all_finance_url').sum()
])

# Add numeric token metrics
agg_cols.extend([
    pl.col('numeric_tokens').sum().alias('total_numeric_tokens')
])

# Add website size metrics (from content_length)
agg_cols.extend([
    pl.col('content_length').sum().alias('total_content_length'),
    pl.col('content_length').mean().alias('avg_content_length'),
    pl.col('content_length').max().alias('max_content_length'),
    pl.col('content_length').min().alias('min_content_length')
])

res_files_agg = res_files.group_by(['original_url', 'year']).agg(agg_cols)

print("✅ RES files processed\n")

# Diagnostic: Check what URLs we have in res_files
res_urls_by_year = (res_files
    .group_by(['original_url', 'year'])
    .agg(pl.col('URL').count().alias('url_count'))
)
print(f"📊 RES data coverage:")
print(f"  - Unique URLs: {res_files.select('original_url').unique().height}")
print(f"  - URL-year pairs: {res_urls_by_year.height}")
for year in sorted(res_files.select('year').unique().to_series().to_list()):
    count = res_urls_by_year.filter(pl.col('year') == year).height
    print(f"  - {year}: {count} URLs")

#%% Load and combine BOW files from both sources
print("📊 Loading BOW files...")
bow_file_dfs = []

# Load original bow files
print("  - Loading original bow files...")
original_bow_count = 0
original_bow_skipped = 0
for f in Path(f'{input_dir_original}/bow/').glob("*.csv"):
    try:
        # First check what columns are available in this file
        temp_df = pl.scan_csv(f, n_rows=1)
        available_cols = temp_df.collect_schema().names()
        
        # Skip files that don't have the required columns for bow analysis
        if not all(col in available_cols for col in ['url', 'word', 'count', 'original_url']):
            original_bow_skipped += 1
            continue
            
        df = pl.scan_csv(f).with_columns([
            pl.col('url').cast(pl.Utf8, strict=False),
            pl.col('original_url').cast(pl.Utf8, strict=False),
            pl.col('word').cast(pl.Utf8, strict=False),
            pl.col('count').cast(pl.Int64, strict=False)
        ])
        bow_file_dfs.append(df)
        original_bow_count += 1
    except Exception as e:
        print(f"    Warning: Could not load bow file {f}: {e}")
        original_bow_skipped += 1

print(f"    ✅ Loaded {original_bow_count} original bow files")
if original_bow_skipped > 0:
    print(f"    ⚠️  Skipped {original_bow_skipped} empty/corrupt original bow files")

# Load recovered bow files
print("  - Loading recovered bow files...")
recovered_bow_count = 0
recovered_bow_skipped = 0
if os.path.exists(f'{input_dir_recovered}/bow/'):
    for f in Path(f'{input_dir_recovered}/bow/').glob("*.csv"):
        try:
            # First check what columns are available in this file
            temp_df = pl.scan_csv(f, n_rows=1)
            available_cols = temp_df.collect_schema().names()
            
            # Skip files that don't have the required columns for bow analysis
            if not all(col in available_cols for col in ['url', 'word', 'count', 'original_url']):
                recovered_bow_skipped += 1
                continue
                
            df = pl.scan_csv(f).with_columns([
                pl.col('url').cast(pl.Utf8, strict=False),
                pl.col('original_url').cast(pl.Utf8, strict=False),
                pl.col('word').cast(pl.Utf8, strict=False),
                pl.col('count').cast(pl.Int64, strict=False)
            ])
            bow_file_dfs.append(df)
            recovered_bow_count += 1
        except Exception as e:
            print(f"    Warning: Could not load bow file {f}: {e}")
            recovered_bow_skipped += 1
    print(f"    ✅ Loaded {recovered_bow_count} recovered bow files")
    if recovered_bow_skipped > 0:
        print(f"    ⚠️  Skipped {recovered_bow_skipped} empty/corrupt recovered bow files")
else:
    print(f"    ⚠️  Recovered bow directory not found")

print(f"\n  Total bow files: {original_bow_count + recovered_bow_count}")

if bow_file_dfs:
    bow_files = (pl.concat(bow_file_dfs, how="diagonal")
                .collect(streaming=True))
else:
    print("  Warning: No valid bow files found!")
    # Create an empty dataframe with the expected schema
    bow_files = pl.DataFrame({
        'url': [],
        'word': [],
        'count': [],
        'original_url': []
    }, schema={'url': pl.Utf8, 'word': pl.Utf8, 'count': pl.Int64, 'original_url': pl.Utf8})

bow_files = (bow_files
            .with_columns(pl.col('url').str.slice(28, 4).alias('year')))

# Deduplicate BOW files: Keep the pull with the most total word counts for each URL-year
if bow_files.height > 0:
    print("\n  🔍 Checking for duplicate BOW URL-year pairs...")
    original_bow_rows = bow_files.height
    
    # Calculate total word count per url (parent url in BOW)
    bow_files = (bow_files
        .with_columns(
            pl.col('count').sum().over(['original_url', 'year', 'url']).alias('pull_total_words')
        )
    )
    
    # For each original_url-year pair, keep only the url with the most total words
    bow_files_deduplicated = (bow_files
        .with_columns(
            pl.col('pull_total_words').max().over(['original_url', 'year']).alias('max_words_for_pair')
        )
        # Keep only rows from the pull with the maximum word count
        .filter(pl.col('pull_total_words') == pl.col('max_words_for_pair'))
        # If there are still ties, keep the first one
        .unique(subset=['original_url', 'year', 'url', 'word'], keep='first')
        .drop(['pull_total_words', 'max_words_for_pair'])
    )
    
    deduped_bow_rows = bow_files_deduplicated.height
    if original_bow_rows != deduped_bow_rows:
        print(f"    ⚠️  Found duplicates: Removed {original_bow_rows - deduped_bow_rows} rows from lower-quality pulls")
        
        # Report which URL-year pairs had duplicates
        duplicate_bow_pairs = (bow_files
            .select(['original_url', 'year', 'url'])
            .unique()
            .group_by(['original_url', 'year'])
            .count()
            .filter(pl.col('count') > 1)
        )
        if duplicate_bow_pairs.height > 0:
            print(f"    📋 {duplicate_bow_pairs.height} URL-year pairs had multiple BOW pulls")
    else:
        print(f"    ✅ No BOW duplicates found")
    
    bow_files = bow_files_deduplicated

bow_files = (bow_files
             .filter(pl.col('count').is_not_null())
             .filter(pl.col('original_url').ne('NA')))

bow_files = (bow_files
                 .with_columns(pl.col('word').n_unique().over(['year', 'original_url']).alias('total_words'),
                               pl.col('count').sum().over(['year', 'original_url']).alias('total_count')))

# compute ranking of words within URL
bow_files = (bow_files
             .sort(['original_url', 'year', 'count'])
             .with_columns(pl.col('count').rank('dense').over(['year', 'original_url']).alias('word_rank'))
             .with_columns(pl.col('word_rank').max().over(['year', 'original_url']).alias('max_word_rank')))

print("✅ BOW files processed\n")

print("📊 Computing financial word frequencies...")

# Define words to search for in BOW data
BOW_WORDS = ['financ', 'bond', 'debt', 'fiscal', 'tax', 'credit', 'capital', 'budget', 'revenue', 'expense', 'fy', 'audit']

# Create dataframes for each word
word_dfs = {}
for word in BOW_WORDS:
    word_dfs[word] = (
        bow_files
        .filter(pl.col('word').eq(pl.lit(word)))
        .rename({'count': f'{word}_count'})
        .select(['year', 'original_url', f'{word}_count'])
    )

print("✅ Financial word frequencies computed\n")

#%% merge bow with res
print("📊 Merging RES and BOW data...")

# Join all word dataframes
for word in BOW_WORDS:
    res_files_agg = res_files_agg.join(
        word_dfs[word], 
        on=['year', 'original_url'], 
        how='left'
    )

res_files_agg = res_files_agg.fill_null(0)

# Convert content_length nulls separately (use 0 for missing values)
res_files_agg = res_files_agg.with_columns([
    pl.col('total_content_length').fill_null(0),
    pl.col('avg_content_length').fill_null(0),
    pl.col('max_content_length').fill_null(0),
    pl.col('min_content_length').fill_null(0)
])

print("✅ Data merged\n")

#%% merge with mergent data
print("📊 Loading and merging external data...")
sample_issuers1 = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/Border_Matches_URLs_20250903.csv')
sample_issuers2 = pl.read_csv(
        '~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files 20251009/Border_Matches_URLs_20251009.csv')
obs_sample = pl.concat([sample_issuers1, sample_issuers2]).unique()
obs = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Expanded Border Matches Issuers Website Collected 20251008.csv')
obs = (obs
       .filter(pl.col('City Website').is_in(obs_sample.select('URL'))))
# get one obs per year
year_list = [2015, 2016, 2017, 2018, 2019, 2020]
obs = (obs
       .with_columns(year = year_list)
       .explode('year'))

# merge with res data
obs = (obs
        .rename({'City Website': 'original_url'})
       .join(res_files_agg
             .with_columns(pl.col('year').cast(pl.Int64)), on = ['year', 'original_url'], how = 'left'))

# Diagnostic: Check match rate
print(f"\n🔍 Merge diagnostics:")
print(f"  - Total obs rows: {obs.height}")
print(f"  - Obs rows with RES data (total_subs not null): {obs.filter(pl.col('total_subs').is_not_null()).height}")
print(f"  - Obs rows missing RES data: {obs.filter(pl.col('total_subs').is_null()).height}")
print(f"  - Match rate: {obs.filter(pl.col('total_subs').is_not_null()).height / obs.height * 100:.1f}%")

# Show which URLs are missing data
missing_urls = (obs
    .filter(pl.col('total_subs').is_null())
    .select(['original_url', 'year'])
    .unique()
    .group_by('original_url')
    .agg(pl.col('year').count().alias('missing_years'))
    .sort('missing_years', descending=True)
)

# Check if these URLs exist in res_files_agg at all
if missing_urls.height > 0:
    print(f"\n  ⚠️  Top URLs with missing data:")
    
    # Get list of URLs that were actually scraped
    scraped_urls = res_files_agg.select('original_url').unique().to_series().to_list()
    
    for i, row in enumerate(missing_urls.head(10).iter_rows(named=True)):
        url = row['original_url']
        years = row['missing_years']
        
        # Check if this URL was scraped for ANY year
        was_scraped = url in scraped_urls
        status = "never scraped" if not was_scraped else "scraped but missing these years"
        
        print(f"    {i+1}. {url}: missing {years} year(s) - {status}")
    
    # Summary
    never_scraped = sum(1 for url in missing_urls.select('original_url').to_series().to_list() 
                       if url not in scraped_urls)
    print(f"\n  📊 Summary of missing URLs:")
    print(f"    - URLs never scraped at all: {never_scraped}")
    print(f"    - URLs scraped but missing some years: {missing_urls.height - never_scraped}")
    print(f"    - Total unique URLs with missing data: {missing_urls.height}")
    
    # Export missing URL-year pairs for potential re-scraping
    missing_pairs = (obs
        .filter(pl.col('total_subs').is_null())
        .select(['original_url', 'year'])
        .unique()
        .rename({'original_url': 'host'})
        .sort(['host', 'year'])
    )
    
    missing_file = f'{data_dir}/Websites/missing_url_year_pairs_{output_date}.csv'
    missing_pairs.write_csv(missing_file)
    print(f"\n  💾 Exported missing URL-year pairs to:")
    print(f"     {missing_file}")
    print(f"     ({missing_pairs.height} host-year pairs)")
print()

# load mergent
mergent = pd.read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)

mergent_constant = (mergent
                    .select(['seed_issuer_id', 'city_go_vote', 'state', 'fips', 'state_go_vote'])
                    .unique())

go_unlim = (mergent
            .filter(pl.col('seed_issuer_id').is_in(obs.select('seed_issuer_id')))
            .filter(pl.col('go_unlim').eq(1))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            .group_by(['seed_issuer_id', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues')))

# Calculate cumulative issuances over ALL years in mergent data
go_unlim_cumulative = (go_unlim
              .with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                            pl.col('year').cast(pl.Int64))
              .sort(['seed_issuer_id', 'year'])
              .with_columns(
                  pl.col('num_issues').cum_sum().over('seed_issuer_id').alias('cum_num_issues'),
                  pl.col('num_issues').rolling_sum(5).over('seed_issuer_id').alias('rolling_sum_num_issues_5')
              ))

# For each obs year, get the cumulative count as of that year (using join_asof)
go_unlim_obs_annual = (obs
              .select(['seed_issuer_id', 'year'])
              .unique()
              .sort(['seed_issuer_id', 'year'])
              .join_asof(
                  go_unlim_cumulative.sort(['seed_issuer_id', 'year']),
                  on='year',
                  by='seed_issuer_id',
                  strategy='backward'
              )
              .with_columns(
                  pl.col('num_issues').fill_null(0),
                  pl.col('cum_num_issues').fill_null(0),
                  pl.col('rolling_sum_num_issues_5').fill_null(0)
              ))

all_bonds = (mergent
            .filter(pl.col('seed_issuer_id').is_in(obs.select('seed_issuer_id')))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            .group_by(['seed_issuer_id', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues_all')))

# Calculate cumulative issuances over ALL years in mergent data
all_bonds_cumulative = (all_bonds
              .with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                            pl.col('year').cast(pl.Int64))
              .sort(['seed_issuer_id', 'year'])
              .with_columns(
                  pl.col('num_issues_all').cum_sum().over('seed_issuer_id').alias('cum_num_issues_all'),
                  pl.col('num_issues_all').rolling_sum(5).over('seed_issuer_id').alias('rolling_sum_num_issues_5_all')
              ))

# For each obs year, get the cumulative count as of that year (using join_asof)
all_bonds_obs_annual = (obs
              .select(['seed_issuer_id', 'year'])
              .unique()
              .sort(['seed_issuer_id', 'year'])
              .join_asof(
                  all_bonds_cumulative.sort(['seed_issuer_id', 'year']),
                  on='year',
                  by='seed_issuer_id',
                  strategy='backward'
              )
              .with_columns(
                  pl.col('num_issues_all').fill_null(0),
                  pl.col('cum_num_issues_all').fill_null(0),
                  pl.col('rolling_sum_num_issues_5_all').fill_null(0)
              ))

employment = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/employment_2001_2022.dta'))
percap_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/percap_inc_2001_2022.dta'))
pers_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pers_inc_2001_2022.dta'))
pop = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pop_2001_2022.dta'))
gdp = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/gdp_2001_2022.dta'))

# merge
obs = (obs
       .join(mergent_constant
             .with_columns(pl.col('seed_issuer_id').cast(pl.Int64)), on = ['seed_issuer_id'], how = 'left')
       .join(go_unlim_obs_annual, on = ['seed_issuer_id', 'year'], how = 'left')
        .join(all_bonds_obs_annual, on = ['seed_issuer_id', 'year'], how = 'left')
       .join(employment
             .select(['fips', 'year', 'employment']).group_by(['fips', 'year']).first()
             .with_columns(pl.col('year').cast(pl.Int64)), on = ['fips', 'year'], how = 'left')
       .join(percap_inc
             .select(['fips', 'year', 'percap_inc']).group_by(['fips', 'year']).first()
             .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
       .join(pers_inc
             .select(['fips', 'year', 'pers_inc']).group_by(['fips', 'year']).first()
             .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
        .join(pop
             .select(['fips', 'year', 'pop']).group_by(['fips', 'year']).first()
              .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
        .join(gdp
             .select(['fips', 'year', 'gdp']).group_by(['fips', 'year']).first()
              .with_columns(pl.col('year').cast(pl.Int64)), on=['fips', 'year'], how='left')
       )

print("✅ External data merged\n")

# log adjust
print("📊 Computing log-adjusted variables...")
obs = (obs
       .with_columns(pl.col('bond_count').add(pl.col('debt_count')).alias('bond_debt_count'),
                     pl.col('bond_count').add(pl.col('debt_count')).add(pl.col('credit_count')).add(pl.col('fiscal_count'))
                     .add(pl.col('capital_count')).add(pl.col('tax_count').add(pl.col('tax_count'))
                                                       .add(pl.col('budget_count'))).alias('all_finance_count'))
       .with_columns(pl.col('employment').log().alias('ln_emp'),
                     pl.col('percap_inc').log().alias('ln_percap_inc'),
                     pl.col('pers_inc').log().alias('ln_pers_inc'),
                     pl.col('pop').log().alias('ln_pop'),
                     pl.col('gdp').log().alias('ln_gdp'),
                     pl.col('cum_num_issues').add(1).log().alias('ln_cum_num_issues'),
                     pl.col('rolling_sum_num_issues_5').add(1).log().alias('ln_rolling_sum_num_issues_5'),
                     pl.col('bond_count').add(1).log().alias('ln_bond_count'),
                    pl.col('tax_count').add(1).log().alias('ln_tax_count'),
                     pl.col('debt_count').add(1).log().alias('ln_debt_count'),
                     pl.col('bond_debt_count').add(1).log().alias('ln_bond_and_debt_count'),
                      pl.col('all_finance_count').add(1).log().alias('ln_all_finance_count')))

print("✅ Log-adjusted variables computed\n")

#%% Analyze financial documents from res files
print("📊 Analyzing financial documents...")

# Financial keywords for URL analysis
FINANCIAL_KEYWORDS = [
    'budget', 'bond', 'debt', 'audit', 'tax', 'cafr', 'acfr', 'credit'
]


def is_financial_url(url: str) -> bool:
    """Check if URL contains financial-related keywords"""
    url_lower = url.lower()
    return any(keyword in url_lower for keyword in FINANCIAL_KEYWORDS)

def get_file_extension(url: str) -> str:
    """Extract file extension from URL"""
    url_clean = url.split('?')[0]
    if '.' in url_clean:
        ext = url_clean.split('.')[-1].lower()
        if len(ext) <= 5:
            return ext
    return ''

def classify_mime_type(error_msg: str) -> str:
    """Extract MIME type from error message if present"""
    if not error_msg or pd.isna(error_msg):
        return None
    mime_pattern = r'Invalid MIME type: ([\w\-/\.+]+)'
    match = re.search(mime_pattern, str(error_msg))
    if match:
        return match.group(1)
    return None

# Analyze original + recovered res files together
print("  - Analyzing res files for document types...")

# Add document type flags to res_files
res_files_docs = (res_files
    .with_columns([
        # Check if URL is financial-related
        pl.col('URL').map_elements(
            lambda x: is_financial_url(x) if x else False, 
            return_dtype=pl.Boolean
        ).alias('is_financial_url'),
        
        # Extract file extension
        pl.col('URL').map_elements(
            lambda x: get_file_extension(x) if x else '', 
            return_dtype=pl.Utf8
        ).alias('file_ext'),
        
        # Check for PDF
        pl.col('URL').str.to_lowercase().str.contains('.pdf').fill_null(False).alias('is_pdf_ext'),
        
        # Check for spreadsheet
        pl.col('URL').str.to_lowercase().str.contains('.xls|.xlsx|.csv').fill_null(False).alias('is_spreadsheet_ext'),
        
        # Check for document
        pl.col('URL').str.to_lowercase().str.contains('.doc|.docx').fill_null(False).alias('is_document_ext')
    ])
)

# Aggregate document counts by original_url and year
financial_docs_agg = (res_files_docs
    .group_by(['original_url', 'year'])
    .agg([
        # PDF counts
        pl.col('is_pdf_ext').sum().alias('pdf_urls'),
        (pl.col('is_pdf_ext') & pl.col('is_financial_url')).sum().alias('financial_pdf_urls'),
        
        # Spreadsheet counts
        pl.col('is_spreadsheet_ext').sum().alias('spreadsheet_urls'),
        (pl.col('is_spreadsheet_ext') & pl.col('is_financial_url')).sum().alias('financial_spreadsheet_urls'),
        
        # Document counts
        pl.col('is_document_ext').sum().alias('document_urls'),
        (pl.col('is_document_ext') & pl.col('is_financial_url')).sum().alias('financial_document_urls'),
        
        # Financial URL count
        pl.col('is_financial_url').sum().alias('financial_keyword_urls'),
        
        # Total documents (any type)
        (pl.col('is_pdf_ext') | pl.col('is_spreadsheet_ext') | pl.col('is_document_ext')).sum().alias('total_document_urls'),
        
        # Financial documents (any type)
        ((pl.col('is_pdf_ext') | pl.col('is_spreadsheet_ext') | pl.col('is_document_ext')) & 
         pl.col('is_financial_url')).sum().alias('total_financial_document_urls'),
        
        # Get total_subs from first row (it's the same for all rows in a group)
        pl.col('total_subs').first().alias('total_subs')
    ])
)

# Calculate ratios after aggregation
financial_docs_agg = (financial_docs_agg
    .with_columns([
        # Calculate ratios
        (pl.col('financial_pdf_urls') / pl.col('pdf_urls')).fill_nan(0).alias('pct_financial_pdfs'),
        (pl.col('financial_spreadsheet_urls') / pl.col('spreadsheet_urls')).fill_nan(0).alias('pct_financial_spreadsheets'),
        (pl.col('total_financial_document_urls') / pl.col('total_document_urls')).fill_nan(0).alias('pct_financial_documents'),
        (pl.col('total_document_urls') / pl.col('total_subs')).fill_nan(0).alias('pct_urls_are_documents')
    ])
)

print(f"    ✅ Analyzed {financial_docs_agg.height} url-year pairs for document types")

# Merge financial document variables with main dataset
print("  - Merging financial document variables...")
obs = (obs
    .join(financial_docs_agg
        .with_columns(pl.col('year').cast(pl.Int64)), 
        on=['original_url', 'year'], 
        how='left')
    .with_columns([
        # Fill nulls with 0 for document counts
        pl.col('pdf_urls').fill_null(0),
        pl.col('financial_pdf_urls').fill_null(0),
        pl.col('spreadsheet_urls').fill_null(0),
        pl.col('financial_spreadsheet_urls').fill_null(0),
        pl.col('document_urls').fill_null(0),
        pl.col('financial_document_urls').fill_null(0),
        pl.col('financial_keyword_urls').fill_null(0),
        pl.col('total_document_urls').fill_null(0),
        pl.col('total_financial_document_urls').fill_null(0),
        pl.col('pct_financial_pdfs').fill_null(0),
        pl.col('pct_financial_spreadsheets').fill_null(0),
        pl.col('pct_financial_documents').fill_null(0),
        pl.col('pct_urls_are_documents').fill_null(0)
    ])
)

print("✅ Financial document variables added\n")

#%% save
output_file = f'{data_dir}/Websites/border_state_website_data_{output_date}_with_recovered.csv'
obs.write_csv(output_file)

print("="*70)
print("✅ Processing Complete!")
print("="*70)
print(f"\nFinal dataset saved to:")
print(f"  {output_file}")
print(f"\nDataset dimensions:")
print(f"  Rows: {obs.shape[0]}")
print(f"  Columns: {obs.shape[1]}")
print("\nData sources combined:")
print(f"  - Original res files: {original_count}")
print(f"  - Recovered res files: {recovered_count}")
print(f"  - Original bow files: {original_bow_count}")
print(f"  - Recovered bow files: {recovered_bow_count}")

print("\nFinancial document variables included:")
print(f"  - pdf_urls: Total PDF files encountered")
print(f"  - financial_pdf_urls: PDFs with financial keywords in URL")
print(f"  - spreadsheet_urls: Total spreadsheet files (XLS, XLSX, CSV)")
print(f"  - financial_spreadsheet_urls: Spreadsheets with financial keywords")
print(f"  - document_urls: Total Word documents (DOC, DOCX)")
print(f"  - total_document_urls: All documents (PDFs + spreadsheets + docs)")
print(f"  - total_financial_document_urls: All financial documents")
print(f"  - pct_financial_pdfs: % of PDFs that are financial-related")
print(f"  - pct_financial_spreadsheets: % of spreadsheets that are financial")
print(f"  - pct_financial_documents: % of all docs that are financial")
print(f"  - pct_urls_are_documents: % of scraped URLs that are documents")

print("\nText/number features included:")
print(f"  - total_numeric_tokens: Total count of numeric sequences (e.g., years, dollar amounts) in scraped text")

print("\nWebsite size variables included:")
print(f"  - total_content_length: Sum of all page sizes in bytes")
print(f"  - avg_content_length: Average page size in bytes")
print(f"  - max_content_length: Largest single page size in bytes")
print(f"  - min_content_length: Smallest single page size in bytes")
print("="*70)
