'''
Create outcome variables pased on parsing
'''
# %%
import polars as pl
import os
from pathlib import Path
import pandas as pd

input_dir_original = os.path.expanduser(
    '/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Processed')
input_dir_recovered = os.path.expanduser(
    '/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Recovered URLs From Bad URLs Investigation/Processed')
data_dir = '~/Dropbox/Voting on Bonds/Data'
output_date = '251217'
# %%
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
print(f"📊 CHECKPOINT: election_data has {election_data.height} rows\n")

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



# %%
# Load CSV files with schema normalization to avoid type conflicts
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
print(f"📊 CHECKPOINT: About to load {original_count + recovered_count} RES files\n")

# Combine all res files
res_files = (pl.concat(res_file_dfs, how = "diagonal")
             .collect(streaming = True)
             )
print(f"📊 CHECKPOINT: res_files has {res_files.height} rows after loading\n")

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
                          .unique(subset = ['original_url', 'year', 'URL'], keep = 'first')
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

# search for bond
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase().str.contains('bond|debt').alias('bond_or_debt_url'),
                           pl.col('URL').str.to_lowercase().str.contains('bond').alias('bond_url'),
                           pl.col('URL').str.to_lowercase().str.contains('debt').alias('debt_url'),
                           pl.col('URL').str.to_lowercase().str.contains('tax').alias('tax_url')))

res_files = (res_files
             .with_columns(pl.col('priority').fill_null(0)))

# Count numeric tokens (sequences of digits) in page text
res_files = res_files.with_columns(
    pl.col('text').fill_null('').str.count_matches(r'\d+').alias('numeric_tokens')
)

# check if contains any finance
res_files = (res_files
             .with_columns(pl.col('URL').str.to_lowercase()
                           .str.contains('bond|debt|finance|financial|credit|fiscal|capital|tax').alias(
    'all_finance_url')))

# %% Analyze financial documents BEFORE aggregation
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
print(f"📊 CHECKPOINT: financial_docs_agg has {financial_docs_agg.height} rows\n")

# aggregate
res_files_agg = (res_files
                 .group_by(['original_url', 'year'])
                 .agg(pl.col('total_subs').first(),
                      pl.col('bond_url').sum(),
                      pl.col('debt_url').sum(),
                      pl.col('tax_url').sum(),
                      pl.col('bond_or_debt_url').sum(),
                      pl.col('all_finance_url').sum(),
                      # Website size metrics
                      pl.col('content_length').sum().alias('total_content_length'),
                      pl.col('content_length').mean().alias('avg_content_length'),
                      pl.col('content_length').max().alias('max_content_length'),
                      pl.col('content_length').min().alias('min_content_length'),
                      # Numeric token metrics
                      pl.col('numeric_tokens').sum().alias('total_numeric_tokens'))
                 .with_columns(pl.col('bond_url').truediv(pl.col('total_subs')).alias('percent_bond_url'),
                               pl.col('debt_url').truediv(pl.col('total_subs')).alias('percent_debt_url'),
                               pl.col('bond_or_debt_url').truediv(pl.col('total_subs')).alias(
                                   'percent_bond_or_debt_url'),
                               pl.col('all_finance_url').truediv(pl.col('total_subs')).alias('percent_all_finance_url'),
                               pl.col('tax_url').truediv(pl.col('total_subs')).alias('percent_tax_url'))
                 # Join with financial documents
                 .join(financial_docs_agg, on=['original_url', 'year'], how='left')
                 .with_columns([
                     # Fill nulls for financial document variables
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
                 ]))
print(f"📊 CHECKPOINT: res_files_agg has {res_files_agg.height} rows after aggregation and joins\n")

# %% # now aggregate bow
print("📊 Loading BOW files...")
bow_file_dfs = []

# Load original bow files
print("  - Loading original bow files...")
original_bow_count = 0
original_bow_skipped = 0
for f in Path(f'{input_dir_original}/bow/').glob("*.csv"):
    try:
        # First check what columns are available in this file
        temp_df = pl.scan_csv(f, n_rows = 1)
        available_cols = temp_df.collect_schema().names()

        # Skip files that don't have the required columns for bow analysis
        if not all(col in available_cols for col in ['url', 'word', 'count', 'original_url']):
            original_bow_skipped += 1
            continue

        df = pl.scan_csv(f).with_columns([
            pl.col('url').cast(pl.Utf8, strict = False),
            pl.col('original_url').cast(pl.Utf8, strict = False),
            pl.col('word').cast(pl.Utf8, strict = False),
            pl.col('count').cast(pl.Int64, strict = False)
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
            temp_df = pl.scan_csv(f, n_rows = 1)
            available_cols = temp_df.collect_schema().names()

            # Skip files that don't have the required columns for bow analysis
            if not all(col in available_cols for col in ['url', 'word', 'count', 'original_url']):
                recovered_bow_skipped += 1
                continue

            df = pl.scan_csv(f).with_columns([
                pl.col('url').cast(pl.Utf8, strict = False),
                pl.col('original_url').cast(pl.Utf8, strict = False),
                pl.col('word').cast(pl.Utf8, strict = False),
                pl.col('count').cast(pl.Int64, strict = False)
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
    bow_files = (pl.concat(bow_file_dfs, how = "diagonal")
                 .collect(streaming = True))
else:
    print("  Warning: No valid bow files found!")
    # Create an empty dataframe with the expected schema
    bow_files = pl.DataFrame({
        'url': [],
        'word': [],
        'count': [],
        'original_url': []
    }, schema = {'url': pl.Utf8, 'word': pl.Utf8, 'count': pl.Int64, 'original_url': pl.Utf8})

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
                              .unique(subset = ['original_url', 'year', 'url', 'word'], keep = 'first')
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
# compute financi, bond, debt, fiscal, capital, credit
# financ
finance = (bow_files
           .filter(pl.col('word').eq(pl.lit('financ')))
           .rename({'count': 'finance_count'})
           .with_columns(pl.col('finance_count').truediv(pl.col('total_count')).alias('percent_finance'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_finance'))
           .select(['year', 'original_url', 'percent_finance', 'rank_percent_finance', 'finance_count']))

bond = (bow_files
        .filter(pl.col('word').eq(pl.lit('bond')))
        .rename({'count': 'bond_count'})
        .with_columns(pl.col('bond_count').truediv(pl.col('total_count')).alias('percent_bond'),
                      (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_bond'))
        .select(['year', 'original_url', 'percent_bond', 'rank_percent_bond', 'bond_count']))

debt = (bow_files
        .filter(pl.col('word').eq(pl.lit('debt')))
        .rename({'count': 'debt_count'})
        .with_columns(pl.col('debt_count').truediv(pl.col('total_count')).alias('percent_debt'),
                      (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_debt'))
        .select(['year', 'original_url', 'percent_debt', 'rank_percent_debt', 'debt_count']))

fiscal = (bow_files
          .filter(pl.col('word').eq(pl.lit('fiscal')))
          .rename({'count': 'fiscal_count'})
          .with_columns(pl.col('fiscal_count').truediv(pl.col('total_count')).alias('percent_fiscal'),
                        (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_fiscal'))
          .select(['year', 'original_url', 'percent_fiscal', 'rank_percent_fiscal', 'fiscal_count']))

tax = (bow_files
       .filter(pl.col('word').eq(pl.lit('tax')))
       .rename({'count': 'tax_count'})
       .with_columns(pl.col('tax_count').truediv(pl.col('total_count')).alias('percent_tax'),
                     (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_tax'))
       .select(['year', 'original_url', 'percent_tax', 'rank_percent_tax', 'tax_count']))

credit = (bow_files
          .filter(pl.col('word').eq(pl.lit('credit')))
          .rename({'count': 'credit_count'})
          .with_columns(pl.col('credit_count').truediv(pl.col('total_count')).alias('percent_credit'),
                        (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_credit'))
          .select(['year', 'original_url', 'percent_credit', 'rank_percent_credit', 'credit_count']))

capital = (bow_files
           .filter(pl.col('word').eq(pl.lit('capital')))
           .rename({'count': 'capital_count'})
           .with_columns(pl.col('capital_count').truediv(pl.col('total_count')).alias('percent_capital'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_capital'))
           .select(['year', 'original_url', 'percent_capital', 'rank_percent_capital', 'capital_count']))

budget = (bow_files
          .filter(pl.col('word').eq(pl.lit('budget')))
          .rename({'count': 'budget_count'})
          .with_columns(pl.col('budget_count').truediv(pl.col('total_count')).alias('percent_budget'),
                        (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_budget'))
          .select(['year', 'original_url', 'percent_budget', 'rank_percent_budget', 'budget_count']))

revenue = (bow_files
           .filter(pl.col('word').eq(pl.lit('revenue')))
           .rename({'count': 'revenue_count'})
           .with_columns(pl.col('revenue_count').truediv(pl.col('total_count')).alias('percent_revenue'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_revenue'))
           .select(['year', 'original_url', 'percent_revenue', 'rank_percent_revenue', 'revenue_count']))

expense = (bow_files
           .filter(pl.col('word').eq(pl.lit('expense')))
           .rename({'count': 'expense_count'})
           .with_columns(pl.col('expense_count').truediv(pl.col('total_count')).alias('percent_expense'),
                         (1 - pl.col('word_rank').truediv(pl.col('max_word_rank'))).alias('rank_percent_expense'))
           .select(['year', 'original_url', 'percent_expense', 'rank_percent_expense', 'expense_count']))

# %% # merge bow with res
res_files_agg = (res_files_agg
                 .join(finance, on = ['original_url', 'year'], how = 'left')
                 .join(bond, on = ['year', 'original_url'], how = 'left')
                 .join(debt, on = ['year', 'original_url'], how = 'left')
                 .join(fiscal, on = ['year', 'original_url'], how = 'left')
                 .join(credit, on = ['year', 'original_url'], how = 'left')
                 .join(capital, on = ['year', 'original_url'], how = 'left')
                 .join(tax, on = ['year', 'original_url'], how = 'left')
                 .join(budget, on = ['year', 'original_url'], how = 'left')
                 .join(revenue, on = ['year', 'original_url'], how = 'left')
                 .join(expense, on = ['year', 'original_url'], how = 'left')
                 .fill_null(0)
                 .with_columns([
                     # Ensure website size variables are filled with 0
                     pl.col('total_content_length').fill_null(0),
                     pl.col('avg_content_length').fill_null(0),
                     pl.col('max_content_length').fill_null(0),
                     pl.col('min_content_length').fill_null(0),
                     pl.col('total_numeric_tokens').fill_null(0)
                 ])
                 .with_columns(pl.col('percent_finance').add(pl.col('percent_bond'))
                               .add(pl.col('percent_fiscal'))
                               .add(pl.col('percent_credit'))
                               .add(pl.col('percent_fiscal'))
                               .add(pl.col('percent_credit')).add(pl.col('percent_tax')).alias('percent_all_finance')))

# %% # merge with mergent data
sample_issuers = pl.read_csv('/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/City Website Collection.csv')
sample_issuers = sample_issuers.rename({'City Website': 'URL'})

# get one obs per year
year_list = [2015, 2016, 2017, 2018, 2019, 2020]
obs = (sample_issuers.rename({'seed_issuer_id': 'GovernmentName'})
       .with_columns(year = year_list)
       .explode('year'))

# merge with res data
print(f"📊 CHECKPOINT: obs has {obs.height} rows before merging with res_files_agg")
obs = (obs
       .rename({'URL': 'original_url'})
       .join(res_files_agg
             .with_columns(pl.col('year').cast(pl.Int64)), on = ['year', 'original_url'], how = 'left'))
print(f"📊 CHECKPOINT: obs has {obs.height} rows after merging with res_files_agg\n")
# %%
# join with election indicators for time series observations
annual_election = (election_data
                   .with_columns(pl.col('ElectionDate').str.strptime(pl.Date, "%m/%d/%Y", strict=False).dt.year().alias('year'))
                   .select(['GovernmentName', 'year'])
                   .unique()
                   .with_columns(election = 1))

obs = (obs
       .join(annual_election.with_columns(pl.col('year').cast(pl.Int64)), on = ['GovernmentName', 'year'], how = 'left')
       .with_columns(pl.col('election').fill_null(0)))


seed_issuer = (election_data
               .select(['GovernmentName', 'seed_issuer'])
               .unique())

obs = (obs
       .join(seed_issuer, on = 'GovernmentName', how = 'left'))

# %%
# get aggregate number of bond issues for the city prior to the given year
mergent = pd.read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
mergent = pl.DataFrame(mergent)
mergent = mergent.filter(pl.col("state").eq("TX"))

# GO unlimited bonds
go_unlim = (mergent
            .filter(pl.col('seed_issuer').is_in(obs.select('seed_issuer')))
            .filter(pl.col('go_unlim').eq(1))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            .group_by(['seed_issuer', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues')))

# Calculate cumulative issuances over ALL years in mergent data
go_unlim_cumulative = (go_unlim
              .with_columns(pl.col('seed_issuer').cast(pl.Utf8),
                            pl.col('year').cast(pl.Int64))
              .sort(['seed_issuer', 'year'])
              .with_columns(
                  pl.col('num_issues').cum_sum().over('seed_issuer').alias('cum_num_issues'),
                  pl.col('num_issues').rolling_sum(5).over('seed_issuer').alias('rolling_sum_num_issues_5')
              ))

# For each obs year, get the cumulative count as of that year (using join_asof)
go_unlim_obs_annual = (obs
              .select(['seed_issuer', 'year'])
              .unique()
              .sort(['seed_issuer', 'year'])
              .join_asof(
                  go_unlim_cumulative.sort(['seed_issuer', 'year']),
                  on='year',
                  by='seed_issuer',
                  strategy='backward'
              )
              .with_columns(
                  pl.col('num_issues').fill_null(0),
                  pl.col('cum_num_issues').fill_null(0),
                  pl.col('rolling_sum_num_issues_5').fill_null(0)
              ))

# All bonds (not just GO unlimited)
all_bonds = (mergent
            .filter(pl.col('seed_issuer').is_in(obs.select('seed_issuer')))
            .with_columns(pl.col('offering_date').dt.year().alias('year'))
            .group_by(['seed_issuer', 'year'])
            .agg(pl.col('issue_id').n_unique().alias('num_issues_all')))

# Calculate cumulative issuances over ALL years in mergent data
all_bonds_cumulative = (all_bonds
              .with_columns(pl.col('seed_issuer').cast(pl.Utf8),
                            pl.col('year').cast(pl.Int64))
              .sort(['seed_issuer', 'year'])
              .with_columns(
                  pl.col('num_issues_all').cum_sum().over('seed_issuer').alias('cum_num_issues_all'),
                  pl.col('num_issues_all').rolling_sum(5).over('seed_issuer').alias('rolling_sum_num_issues_5_all')
              ))

# For each obs year, get the cumulative count as of that year (using join_asof)
all_bonds_obs_annual = (obs
              .select(['seed_issuer', 'year'])
              .unique()
              .sort(['seed_issuer', 'year'])
              .join_asof(
                  all_bonds_cumulative.sort(['seed_issuer', 'year']),
                  on='year',
                  by='seed_issuer',
                  strategy='backward'
              )
              .with_columns(
                  pl.col('num_issues_all').fill_null(0),
                  pl.col('cum_num_issues_all').fill_null(0),
                  pl.col('rolling_sum_num_issues_5_all').fill_null(0)
              ))

obs = (obs
       .join(go_unlim_obs_annual, on = ['seed_issuer', 'year'], how = 'left')
       .join(all_bonds_obs_annual, on = ['seed_issuer', 'year'], how = 'left'))
print(f"📊 CHECKPOINT: obs has {obs.height} rows after joining bond issuance variables\n")

# %%
# save
obs.write_csv(f'{data_dir}/Websites/Texas/time_series_website_data_{output_date}.csv')

# %%
# election level data
print(f"\n📊 CHECKPOINT: election_data has {election_data.height} rows before election_level creation")
print(f"📊 CHECKPOINT: sample_issuers has {sample_issuers.height} unique records")

# Step 1: Join with sample_issuers
election_level_step1 = (election_data
                  .join(sample_issuers.rename({'seed_issuer_id': 'GovernmentName'}),
                        on = 'GovernmentName', how = 'inner'))
print(f"📊 CHECKPOINT: After joining sample_issuers: {election_level_step1.height} rows")

# Step 2: Join with res_files_agg
election_level_step2 = (election_level_step1
                  .join(res_files_agg.rename({'original_url': 'URL'}).with_columns(pl.col('year').cast(pl.Int64)),
                        on = ['URL', 'year'], how = 'left'))
print(f"📊 CHECKPOINT: After joining res_files_agg: {election_level_step2.height} rows")

# Step 3: No year filter for Texas data - keep all years
election_level = election_level_step2
print(f"📊 CHECKPOINT: Keeping all years (no filter): {election_level.height} rows")

#%%
# merge with mergent purposes
mergent_purpose = (pl.read_csv(f'{data_dir}/TX/2025-03-24_texasbondpurpose_classify.csv')
                   .rename({'purposedescription':'PurposeDescription'})
                   .select(['purp_broad_new', 'PurposeDescription']))

election_level = (election_level
                  .join(mergent_purpose, on = 'PurposeDescription', how = 'left'))
#%%
# merge with demographic data
fips = (mergent
        .group_by(['seed_issuer', 'fips']).first())

election_level = (election_level
                  .join(fips, on = 'seed_issuer', how = 'left'))

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

    # Filter to Texas counties only (FIPS starting with 48)
    county_demographics = county_demographics.filter(pl.col('fips_str').str.starts_with('48'))

    print(f"Merged county demographics: {county_demographics.shape[0]} TX county-year observations")
    print(f"Years available: {sorted(county_demographics.select('year').unique().to_series().to_list())}")
    print(f"TX counties: {county_demographics.select('fips_str').n_unique()} unique counties")
else:
    print("Error: Could not load all demographic files")
    county_demographics = None


election_level = (election_level.with_columns(pl.col('fips').cast(pl.Int64))
                  .join(county_demographics.with_columns(pl.col('fips_str').cast(pl.Int64).alias('fips')),
                        on = ['fips', 'year'], how = 'left')
 .with_columns(
    (pl.col('pop')).log().alias('ln_county_pop_prior'),
    (pl.col('gdp')).log().alias('ln_county_gdp_prior'),
    (pl.col('pers_inc')).log().alias('ln_county_pers_inc_prior'),
    (pl.col('percap_inc')).log().alias('ln_county_percap_inc_prior'),
    (pl.col('employment')).log().alias('ln_county_employment_prior')
)
)

# Add bond issuance variables
election_level = (election_level
                  .join(go_unlim_obs_annual, on = ['seed_issuer', 'year'], how = 'left')
                  .join(all_bonds_obs_annual, on = ['seed_issuer', 'year'], how = 'left')
                  .with_columns([
                      pl.col('num_issues').fill_null(0),
                      pl.col('cum_num_issues').fill_null(0),
                      pl.col('rolling_sum_num_issues_5').fill_null(0),
                      pl.col('num_issues_all').fill_null(0),
                      pl.col('cum_num_issues_all').fill_null(0),
                      pl.col('rolling_sum_num_issues_5_all').fill_null(0)
                  ]))

# save
election_level.write_csv(f'{data_dir}/Websites/Texas/election_level_website_data_{output_date}.csv')
