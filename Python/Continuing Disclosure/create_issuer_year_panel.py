# Create seed_issuer_id - year panel with outstanding debt and continuing disclosure
# This script:
# 1. Creates a time series of issuer's outstanding debt from bond-level data
# 2. Expands each bond to create observations for each year it's outstanding
# 3. Aggregates to issuer-year level to get total outstanding debt
# 4. Merges continuing disclosure data and creates disclosure variables by year

#%%=================== Set up ===================
import polars as pl
import pandas as pd

data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data/'

#%%=================== Load Mergent bond-level data ===================
print("Loading Mergent data...")
mergent = pl.DataFrame(pd.read_stata(f'{data_dir}Mergent/Clean/251027_city_cusiplevel_statereq_purpose_yieldspread.dta'))

# Keep relevant columns
mergent = mergent.select([
    'cusip', 'issue_id', 'seed_issuer_id', 'offering_date', 'maturity_date', 
    'amount', 'seed_issuer', 'go_unlim'
])

print(f"Loaded {len(mergent):,} bonds")

#%%=================== Create bond-year panel ===================
print("Creating bond-year observations...")

# Convert dates to proper format and extract years
mergent = (mergent
    .with_columns([
        pl.col('offering_date').cast(pl.Date),
        pl.col('maturity_date').cast(pl.Date)
    ])
    .with_columns([
        pl.col('offering_date').dt.year().alias('issue_year'),
        pl.col('maturity_date').dt.year().alias('maturity_year')
    ])
)

# Create a list of years for each bond (from issue year to maturity year)
# We'll expand each bond to have one row per year it's outstanding
bond_years = []

for row in mergent.iter_rows(named=True):
    if row['issue_year'] is not None and row['maturity_year'] is not None:
        for year in range(row['issue_year'], row['maturity_year'] + 1):
            bond_years.append({
                'cusip': row['cusip'],
                'issue_id': row['issue_id'],
                'seed_issuer_id': row['seed_issuer_id'],
                'seed_issuer': row['seed_issuer'],
                'year': year,
                'amount': row['amount'],
                'issue_year': row['issue_year'],
                'maturity_year': row['maturity_year'],
                'go_unlim': row['go_unlim']
            })
bond_year_panel = pl.DataFrame(bond_years)
print(f"Created {len(bond_year_panel):,} bond-year observations")

#%%=================== Aggregate to issuer-year level ===================
print("Aggregating to issuer-year level...")

issuer_year_panel = (bond_year_panel
    .group_by(['seed_issuer_id', 'year'])
    .agg([
        pl.col('seed_issuer').first(),  # Keep issuer name
        pl.col('amount').sum().alias('total_outstanding_debt'),
        pl.col('cusip').n_unique().alias('num_bonds_outstanding'),
        # Count GO unlimited bonds outstanding
        pl.col('cusip').filter(pl.col('go_unlim') == 1).n_unique().alias('num_go_unlim_bonds_outstanding'),
        # Count new bonds issued in this year
        pl.when(pl.col('year') == pl.col('issue_year'))
            .then(1)
            .otherwise(0)
            .sum()
            .alias('num_bonds_issued'),
        # Sum principal of new bonds issued in this year
        pl.when(pl.col('year') == pl.col('issue_year'))
            .then(pl.col('amount'))
            .otherwise(0)
            .sum()
            .alias('total_debt_issued')
    ])
    .sort(['seed_issuer_id', 'year'])
)

print(f"Created issuer-year panel with {len(issuer_year_panel):,} observations")
print(f"Unique issuers: {issuer_year_panel['seed_issuer_id'].n_unique():,}")
print(f"Year range: {issuer_year_panel['year'].min()} - {issuer_year_panel['year'].max()}")

#%%=================== Load continuing disclosure data ===================
print("\nLoading continuing disclosure data...")
cd = pl.read_csv(f'{data_dir}Continuing Disclosure/cleaned_daily_disclosure_data.csv', 
                 infer_schema_length=10000, null_values='NA')

print(f"Loaded {len(cd):,} disclosure records")

#%%=================== Link CD data to Mergent via CUSIP ===================
print("Linking continuing disclosure to bonds...")

# Get cusip to issue_id mapping
cusip_issue = mergent.select(['cusip', 'issue_id', 'seed_issuer_id']).unique()
cusip_issue = cusip_issue.rename({'cusip': 'cusip_c'})

# Merge CD with issue info
cd_with_issuer = cd.join(cusip_issue, on='cusip_c', how='inner')
print(f"Matched {len(cd_with_issuer):,} disclosure records to bonds")

#%%=================== Create disclosure year variable ===================
# Extract year from disclosure event date
cd_with_issuer = (cd_with_issuer
    .with_columns(pl.col('disclosure_event_date').cast(pl.Date))
    .with_columns(pl.col('disclosure_event_date').dt.year().alias('year'))
)

#%%=================== Create disclosure type indicators ===================
cd_with_issuer = (cd_with_issuer
    .with_columns([
        pl.when(pl.col('disclosuretype').eq(pl.lit('EventBasedDisclosure')))
            .then(1).otherwise(0).alias('event_based_disclosure'),
        pl.when(pl.col('disclosuretype').eq(pl.lit('FinancialOperatingDataDisclosure')))
            .then(1).otherwise(0).alias('financial_operating_data_disclosure'),
        pl.when(pl.col('financialoperatingdisclosurecategory').str.to_lowercase().str.contains('audited'))
            .then(1).otherwise(0).alias('audited_financial_disclosure'),
        pl.when(pl.col('financialoperatingdisclosurecategory').str.to_lowercase().str.contains('failure'))
            .then(1).otherwise(0).alias('failure_financial_disclosure')
    ])
)

#%%=================== Aggregate disclosures to issuer-year level ===================
print("Aggregating disclosures to issuer-year level...")

cd_issuer_year = (cd_with_issuer
    .group_by(['seed_issuer_id', 'year'])
    .agg(
        pl.col('timeliness_days_mean').mean().alias('avg_timeliness_days'),
        # Total disclosures
        pl.col('submissionidentifier').n_unique().alias('num_submission'),
        pl.col('num_disclosures').sum().alias('num_disclosures'),
        # Event-based disclosures
        pl.col('num_disclosures').filter(pl.col('event_based_disclosure') == 1)
            .sum()
            .alias('num_event_based_disclosures'),
        # Financial operating data disclosures
        pl.col('num_disclosures').filter(pl.col('financial_operating_data_disclosure') == 1)
            .sum()
            .alias('num_financial_operating_disclosures'),
        # Audited financial disclosures
    pl.col('num_disclosures').filter(pl.col('audited_financial_disclosure') == 1)
    .sum()
    .alias('num_audited_disclosures'),
              # Failure to file disclosures
pl.col('num_disclosures').filter(pl.col('failure_financial_disclosure') == 1)
    .sum()
    .alias('num_failure_disclosures')
    )
)

print(f"Created issuer-year disclosure panel with {len(cd_issuer_year):,} observations")

#%%=================== Merge disclosure data with issuer-year panel ===================
print("\nMerging disclosure data with issuer-year panel...")

final_panel = (issuer_year_panel
    .join(cd_issuer_year.with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                      pl.col('year').cast(pl.Int64)), on=['seed_issuer_id', 'year'], how='left')
)

# Fill missing disclosure counts with 0
disclosure_cols = [
    'num_disclosures', 'num_event_based_disclosures', 
    'num_financial_operating_disclosures', 'num_audited_disclosures', 
    'num_failure_disclosures'
]

final_panel = (final_panel
    .with_columns([
        pl.col(col).fill_null(0) for col in disclosure_cols
    ])
)

#%%=================== Create disclosure intensity measures ===================
# Create per-bond disclosure metrics
final_panel = (final_panel
    .with_columns([
        (pl.col('num_disclosures') / pl.col('num_bonds_outstanding')).alias('disclosures_per_bond'),
        (pl.col('num_event_based_disclosures') / pl.col('num_bonds_outstanding')).alias('event_disclosures_per_bond'),
        (pl.col('num_financial_operating_disclosures') / pl.col('num_bonds_outstanding')).alias('financial_disclosures_per_bond')
    ])
)

#%%=================== Load news data and calculate average media coverage ===================
print("\nLoading news data...")
news = pl.read_csv(f'{data_dir}News/Issuance_Lvl_News_With_Lagged_News_2501013.csv')

print(f"Loaded {len(news):,} news observations")

# Aggregate news to issuer-year level (average 12-month rolling article count)
news_year = (news
    .group_by(['seed_issuer_id', 'year'])
    .agg([
        pl.col('rolling_sum_monthly_article_count_12').mean().alias('avg_rolling_articles_12mo')
    ])
)

print(f"Created issuer-year news panel with {len(news_year):,} observations (years with issuances)")

# Create a complete issuer-year grid for issuers that appear in news data
# Get all issuer-year combinations from the main panel for issuers that have news
issuers_with_news = news_year.select('seed_issuer_id').unique()

# Get all issuer-year combinations from main panel for these issuers
issuer_year_grid = (final_panel
    .filter(pl.col('seed_issuer_id').is_in(issuers_with_news['seed_issuer_id']))
    .select(['seed_issuer_id', 'year'])
    .unique()
)

# Merge with news data to fill in missing years
news_year_complete = (issuer_year_grid
    .join(news_year, on=['seed_issuer_id', 'year'], how='left')
    .sort(['seed_issuer_id', 'year'])
)

print(f"Expanded to {len(news_year_complete):,} issuer-year observations for cumulative calculation")

# Calculate cumulative average media coverage up to and including current year
# For years without issuances, carry forward the cumulative average from prior years
news_year_complete = (news_year_complete
    .with_columns([
        # First calculate cumulative sum and count (ignoring nulls)
        pl.col('avg_rolling_articles_12mo').fill_null(0).cum_sum().over('seed_issuer_id').alias('_cum_sum'),
        pl.col('avg_rolling_articles_12mo').is_not_null().cum_sum().over('seed_issuer_id').alias('_cum_count')
    ])
    .with_columns([
        # Calculate cumulative average, avoiding division by zero
        pl.when(pl.col('_cum_count') > 0)
            .then(pl.col('_cum_sum') / pl.col('_cum_count'))
            .otherwise(None)
            .alias('cumavg_media_coverage')
    ])
    # Forward fill the cumulative average for years without issuances
    .with_columns([
        pl.col('cumavg_media_coverage').forward_fill().over('seed_issuer_id')
    ])
    .drop(['_cum_sum', '_cum_count'])
)

# Merge news data with main panel
print("Merging news data with issuer-year panel...")
final_panel = (final_panel
    .join(news_year_complete, on=['seed_issuer_id', 'year'], how='left')
)

print(f"Issuer-years with cumulative media coverage: {final_panel.filter(pl.col('cumavg_media_coverage').is_not_null()).height:,} ({100*final_panel.filter(pl.col('cumavg_media_coverage').is_not_null()).height/len(final_panel):.1f}%)")

#%%=================== Create disclosure indicators ===================

final_panel = (final_panel
               .with_columns(
    pl.when(pl.col('num_financial_operating_disclosures').gt(0))
    .then(1).otherwise(0).alias('filed_financial_disclosure'),
    pl.when(pl.col('num_event_based_disclosures').gt(0))
    .then(1).otherwise(0).alias('filed_event_based_disclosure'),
    pl.when(pl.col("num_audited_disclosures").gt(0))
    .then(1).otherwise(0).alias('filed_audited_disclosure')
))

#%%=================== Filter to sample years ===================
final_panel = final_panel.filter(
    (pl.col('year') >= 2010) & (pl.col('year') <= 2024)
)

#%%=================== Summary statistics ===================
print("\n" + "="*60)
print("SUMMARY STATISTICS")
print("="*60)

print(f"\nPanel dimensions:")
print(f"  Total observations: {len(final_panel):,}")
print(f"  Unique issuers: {final_panel['seed_issuer_id'].n_unique():,}")
print(f"  Year range: {final_panel['year'].min()} - {final_panel['year'].max()}")

print(f"\nOutstanding debt statistics:")
debt_stats = final_panel.select('total_outstanding_debt').describe()
print(debt_stats)

print(f"\nDisclosure statistics (issuer-years with disclosures):")
with_disclosures = final_panel.filter(pl.col('num_disclosures') > 0)
print(f"  Issuer-years with any disclosure: {len(with_disclosures):,} ({100*len(with_disclosures)/len(final_panel):.1f}%)")
print(f"  Issuer-years with event-based: {final_panel.filter(pl.col('num_event_based_disclosures') > 0).height:,}")
print(f"  Issuer-years with financial: {final_panel.filter(pl.col('num_financial_operating_disclosures') > 0).height:,}")


#%%=================== Add needed variables ===================
print("Loading Mergent data...")
mergent = pl.DataFrame(pd.read_stata(f'{data_dir}Mergent/Clean/251027_city_cusiplevel_statereq_purpose_yieldspread.dta'))
mergent = (mergent
           .select(['seed_issuer_id','state', 'fips', 'city_go_vote', 'state_go_vote', 'glm_proactive', 'state_ltgo_allowed'])
           .unique())

final_panel = (final_panel
               .join(mergent.with_columns(pl.col('seed_issuer_id').cast(pl.Int64)),
                     on = 'seed_issuer_id', how = 'left'))


#%%=================== Add country demo ===================

employment = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/employment_2001_2022.dta'))
percap_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/percap_inc_2001_2022.dta'))
pers_inc = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pers_inc_2001_2022.dta'))
pop = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/pop_2001_2022.dta'))
gdp = pl.DataFrame(pd.read_stata(f'{data_dir}/BEA/gdp_2001_2022.dta'))

# merge
final_panel = (final_panel
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

final_panel = (final_panel
               .with_columns(pl.col('employment').log().alias('ln_emp'),
                     pl.col('percap_inc').log().alias('ln_percap_inc'),
                     pl.col('pers_inc').log().alias('ln_pers_inc'),
                     pl.col('pop').log().alias('ln_pop'),
                     pl.col('gdp').log().alias('ln_gdp')))


#%%=================== Save final panel ===================
output_date = '20251113'
output_path = f'{data_dir}Continuing Disclosure/Processed/issuer_year_panel_{output_date}.csv'

print(f"\nSaving to: {output_path}")
final_panel.write_csv(output_path)

# Also save as parquet for faster loading
parquet_path = f'{data_dir}Continuing Disclosure/Processed/issuer_year_panel_{output_date}.gzip'
final_panel.write_parquet(parquet_path, compression='gzip')

print(f"Also saved as: {parquet_path}")
print("\nDone!")


#%%=================== Border state ===================
border_state = pl.read_csv(f'{data_dir}/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20251013.csv', infer_schema_length = 10000)
border_state = (border_state
                .select(['seed_issuer_id', 'group'])
                .filter(pl.col('group').ne(pl.lit('Rhode Island/Massachusetts')))
                .unique())
border_panel = (border_state.with_columns(pl.col('seed_issuer_id').cast(pl.Int64))
                .join(final_panel,
                      on = 'seed_issuer_id', how = 'left'))

#%%=================== Merge with website data ===================
websites = (pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_251111_with_recovered.csv')
            .select(['seed_issuer_id', 'year', 'bond_url', 'debt_url', 'bond_count', 'debt_count',
                     'total_subs', 'bond_or_debt_url', 'all_finance_url', 'financ_count', 'budget_count', 'budget_url',
                     'fiscal_url', 'fiscal_count', 'financial_pdf_urls']))

border_panel = (border_panel
                .join(websites.with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                            pl.col('year').cast(pl.Int64)),
                      on = ['seed_issuer_id', 'year'], how = 'left'))

output_date = '20251113'
output_path = f'{data_dir}Continuing Disclosure/Processed/border_issuer_year_panel_{output_date}.csv'

print(f"\nSaving to: {output_path}")
border_panel.write_csv(output_path)
