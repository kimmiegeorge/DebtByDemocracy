# Create seed_issuer_id - year panel with outstanding debt and continuing disclosure
# This script:
# 1. Creates a time series of issuer's outstanding debt from bond-level data
# 2. Expands each bond to create observations for each year it's outstanding
# 3. Aggregates to issuer-year level to get total outstanding debt
# 4. Merges continuing disclosure data and creates disclosure variables by year

#%%=================== Set up ===================
import polars as pl
import pandas as pd
from pathlib import Path

data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data/'
clean_data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data/Clean_Intermediate/'
processed_dir = Path(f'{clean_data_dir}Continuing Disclosure/Processed')
processed_dir.mkdir(parents=True, exist_ok=True)
project_root = next(
    parent for parent in Path(__file__).resolve().parents
    if (parent / 'Code/Config/border_state_pairs.csv').exists()
)
paper_border_pairs = (
    pl.read_csv(project_root / 'Code/Config/border_state_pairs.csv')
    .filter(pl.col('include_in_paper') == 1)
    .get_column('group')
    .to_list()
)


def add_issuer_key(frame: pl.DataFrame) -> pl.DataFrame:
    """Preserve decimal IDs and disambiguate numeric IDs reused by issuers."""
    return (
        frame
        .with_columns([
            pl.col('seed_issuer_id').cast(pl.Float64).round(1),
            pl.col('seed_issuer').cast(pl.Utf8).str.strip_chars(),
            pl.col('state').cast(pl.Utf8).str.strip_chars().str.to_uppercase(),
        ])
        .with_columns(
            pl.concat_str([
                (pl.col('seed_issuer_id') * 10).round(0).cast(pl.Int64).cast(pl.Utf8),
                pl.col('state'),
                pl.col('seed_issuer').str.to_uppercase().str.replace_all(r'\s+', ' '),
            ], separator='|').alias('issuer_key')
        )
    )

#%%=================== Load Mergent bond-level data ===================
print("Loading Mergent data...")
mergent = pl.DataFrame(pd.read_stata(f'{data_dir}Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'))

# Keep relevant columns
mergent = mergent.select([
    'cusip', 'issue_id', 'seed_issuer_id', 'offering_date', 'maturity_date', 
    'amount', 'seed_issuer', 'state', 'go_unlim'
])
mergent = add_issuer_key(mergent)

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
                'issuer_key': row['issuer_key'],
                'seed_issuer': row['seed_issuer'],
                'state': row['state'],
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
    .group_by(['issuer_key', 'year'])
    .agg([
        pl.col('seed_issuer_id').first(),
        pl.col('seed_issuer').first(),  # Keep issuer name
        pl.col('state').first(),
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
    .sort(['issuer_key', 'year'])
)

print(f"Created issuer-year panel with {len(issuer_year_panel):,} observations")
print(f"Unique issuers: {issuer_year_panel['issuer_key'].n_unique():,}")
print(f"Year range: {issuer_year_panel['year'].min()} - {issuer_year_panel['year'].max()}")

#%%=================== Load continuing disclosure data ===================
print("\nLoading continuing disclosure data...")
disclosure_columns = [
    'cusip_c',
    'disclosure_event_date',
    'disclosuretype',
    'financialoperatingdisclosurecategory',
    'eventdisclosurecategory',
    'submissionidentifier',
    'timeliness_days_mean',
    'num_disclosures',
]
cd = pl.read_csv(
    f'{data_dir}Continuing Disclosure/cleaned_daily_disclosure_data.csv',
    columns=disclosure_columns,
    infer_schema_length=10000,
    null_values='NA',
)

print(f"Loaded {len(cd):,} disclosure records")

#%%=================== Link CD data to Mergent via CUSIP ===================
print("Linking continuing disclosure to bonds...")

# Get a one-to-one CUSIP-to-issuer mapping.
cusip_issue = mergent.select(['cusip', 'issuer_key']).unique()
cusip_conflicts = (
    cusip_issue
    .group_by('cusip')
    .agg(pl.col('issuer_key').n_unique().alias('issuer_count'))
    .filter(pl.col('issuer_count') > 1)
)
if cusip_conflicts.height > 0:
    raise ValueError(
        f'{cusip_conflicts.height:,} CUSIPs map to more than one issuer_key.'
    )
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

# The source has one row per submission-CUSIP link. Submission attributes are
# repeated unchanged for every linked CUSIP, so reduce to one row per
# issuer-year-submission before calculating any issuer totals.
matched_disclosure_rows = cd_with_issuer.height
repeated_disclosure_sum = int(cd_with_issuer['num_disclosures'].sum() or 0)
issuer_submissions = (
    cd_with_issuer
    .unique(subset=['issuer_key', 'year', 'submissionidentifier'], keep='first')
)
if issuer_submissions.is_duplicated().any():
    raise ValueError('Duplicate issuer-year-submission rows remain after deduplication.')

corrected_disclosure_sum = int(issuer_submissions['num_disclosures'].sum() or 0)
print(
    f"Reduced {matched_disclosure_rows:,} matched CUSIP rows to "
    f"{issuer_submissions.height:,} issuer-submission rows"
)

#%%=================== Create disclosure type indicators ===================
issuer_submissions = (issuer_submissions
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

cd_issuer_year = (issuer_submissions
    .group_by(['issuer_key', 'year'])
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
    .join(
        cd_issuer_year.with_columns(pl.col('year').cast(pl.Int64)),
        on=['issuer_key', 'year'],
        how='left',
        validate='1:1',
    )
)

# Fill missing disclosure counts with 0
disclosure_cols = [
    'num_submission', 'num_disclosures', 'num_event_based_disclosures', 
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
    .with_columns(pl.col('seed_issuer_id').cast(pl.Float64).round(1))
    .group_by(['seed_issuer_id', 'year'])
    .agg([
        pl.col('rolling_sum_monthly_article_count_12').mean().alias('avg_rolling_articles_12mo')
    ])
)

# News files do not yet carry issuer_key. Attach news only where the numeric ID
# identifies exactly one issuer; reused IDs remain unmatched rather than being
# assigned to the wrong municipality.
unambiguous_id_map = (
    final_panel
    .select(['seed_issuer_id', 'issuer_key'])
    .unique()
    .group_by('seed_issuer_id')
    .agg([
        pl.col('issuer_key').n_unique().alias('issuer_count'),
        pl.col('issuer_key').first(),
    ])
    .filter(pl.col('issuer_count') == 1)
    .drop('issuer_count')
)
news_year = news_year.join(unambiguous_id_map, on='seed_issuer_id', how='inner')

print(f"Created issuer-year news panel with {len(news_year):,} observations (years with issuances)")

# Create a complete issuer-year grid for issuers that appear in news data
# Get all issuer-year combinations from the main panel for issuers that have news
issuers_with_news = news_year.select('issuer_key').unique()

# Get all issuer-year combinations from main panel for these issuers
issuer_year_grid = (final_panel
    .join(issuers_with_news, on='issuer_key', how='semi')
    .select(['issuer_key', 'year'])
    .unique()
)

# Merge with news data to fill in missing years
news_year_complete = (issuer_year_grid
    .join(news_year.drop('seed_issuer_id'), on=['issuer_key', 'year'], how='left')
    .sort(['issuer_key', 'year'])
)

print(f"Expanded to {len(news_year_complete):,} issuer-year observations for cumulative calculation")

# Calculate cumulative average media coverage up to and including current year
# For years without issuances, carry forward the cumulative average from prior years
news_year_complete = (news_year_complete
    .with_columns([
        # First calculate cumulative sum and count (ignoring nulls)
        pl.col('avg_rolling_articles_12mo').fill_null(0).cum_sum().over('issuer_key').alias('_cum_sum'),
        pl.col('avg_rolling_articles_12mo').is_not_null().cum_sum().over('issuer_key').alias('_cum_count')
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
        pl.col('cumavg_media_coverage').forward_fill().over('issuer_key')
    ])
    .drop(['_cum_sum', '_cum_count'])
)

# Merge news data with main panel
print("Merging news data with issuer-year panel...")
final_panel = (final_panel
    .join(news_year_complete, on=['issuer_key', 'year'], how='left')
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
print(f"  Unique issuers: {final_panel['issuer_key'].n_unique():,}")
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
mergent = pl.DataFrame(pd.read_stata(f'{data_dir}Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'))
mergent = add_issuer_key(mergent)
mergent = (mergent
           .group_by('issuer_key')
           .agg([
               pl.col('fips').drop_nulls().first(),
               pl.col('city_go_vote').drop_nulls().first(),
               pl.col('state_go_vote').drop_nulls().first(),
               pl.col('glm_proactive').drop_nulls().first(),
               pl.col('state_ltgo_allowed').drop_nulls().first(),
           ]))

final_panel = (final_panel
               .join(mergent, on='issuer_key', how='left', validate='m:1'))


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
output_path = f'{clean_data_dir}Continuing Disclosure/Processed/issuer_year_panel.csv'

print(f"\nSaving to: {output_path}")
final_panel.write_csv(output_path)

# Also save as parquet for faster loading
parquet_path = f'{clean_data_dir}Continuing Disclosure/Processed/issuer_year_panel.gzip'
final_panel.write_parquet(parquet_path, compression='gzip')

print(f"Also saved as: {parquet_path}")
print("\nDone!")

pl.DataFrame({
    'metric': [
        'source_disclosure_cusip_rows',
        'matched_disclosure_cusip_rows',
        'issuer_submission_rows_after_deduplication',
        'repeated_cusip_rows_removed',
        'num_disclosures_before_deduplication',
        'num_disclosures_after_deduplication',
        'num_disclosures_overcount_removed',
    ],
    'value': [
        cd.height,
        matched_disclosure_rows,
        issuer_submissions.height,
        matched_disclosure_rows - issuer_submissions.height,
        repeated_disclosure_sum,
        corrected_disclosure_sum,
        repeated_disclosure_sum - corrected_disclosure_sum,
    ],
}).write_csv(processed_dir / 'disclosure_aggregation_diagnostics.csv')


#%%=================== Border state ===================
border_state = pl.read_csv(
    f'{clean_data_dir}Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv',
    infer_schema_length=10000
)
border_state = (border_state
                .select(['seed_issuer_id', 'seed_issuer', 'state', 'group'])
                .filter(pl.col('group').is_in(paper_border_pairs))
                .unique())
border_panel = (add_issuer_key(border_state)
                .join(final_panel,
                      on = 'issuer_key', how = 'left'))

#%%=================== Merge with website data ===================
websites = (pl.read_csv(f'{clean_data_dir}Websites/border_state_website_data_with_recovered.csv')
            .select(['seed_issuer_id', 'seed_issuer', 'year', 'bond_url', 'debt_url', 'bond_count', 'debt_count',
                     'total_subs', 'bond_or_debt_url', 'all_finance_url', 'financ_count', 'budget_count', 'budget_url',
                     'fiscal_url', 'fiscal_count', 'financial_pdf_urls'])
            .unique(subset=['seed_issuer_id', 'seed_issuer', 'year'], keep='first'))

border_panel = (border_panel
                .join(websites.with_columns(pl.col('seed_issuer_id').cast(pl.Float64).round(1),
                                            pl.col('year').cast(pl.Int64)),
                      on = ['seed_issuer_id', 'seed_issuer', 'year'], how = 'left'))

output_path = f'{clean_data_dir}Continuing Disclosure/Processed/border_issuer_year_panel.csv'

print(f"\nSaving to: {output_path}")
border_panel.write_csv(output_path)
