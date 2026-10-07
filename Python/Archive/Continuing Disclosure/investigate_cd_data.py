# construct continuing disclosure variables and merge with Mergent data

#%%=================== Set up===================
import polars as pl
import pandas as pd

data_dir = '/Users/kmunevar/Dropbox/Voting on Bonds/Data/'
#%%=================== Load cleaned CD data ===================
cd = pl.read_csv(f'{data_dir}Continuing Disclosure/cleaned_daily_disclosure_data.csv', infer_schema_length=10000, null_values = 'NA')


#%%=================== Load Mergent data ===================
mergent = pl.DataFrame(pd.read_stata(f'{data_dir}Mergent/Clean/251027_city_cusiplevel_statereq_purpose_yieldspread.dta'))

# filter to non-missing city go vote
mergent = (mergent
           .filter(pl.col('city_go_vote').is_not_null()))

# filter to go unlim bonds
mergent = (mergent
           .filter(pl.col('go_unlim').eq(1)))

#%%=================== Merge ===================
cusip_issue = mergent.select(['cusip', 'issue_id', 'offering_date']).unique()
cusip_issue = cusip_issue.rename({'cusip':'cusip_c'})
cd = cd.join(cusip_issue, on='cusip_c', how='inner')


# keep one observation per issue-id - submissionid
cd = (cd
      .group_by('issue_id', 'submissionidentifier').first())

#%%=================== Calculate vars ===================

# first. determine number of days since offering date
cd = (cd
      .with_columns(pl.col('disclosure_event_date').cast(pl.Date),
                    pl.col('offering_date').cast(pl.Date))
      .with_columns(pl.col('disclosure_event_date').sub(pl.col('offering_date')).dt.total_days().alias('days_since_offering')))

# create indicators for different disclosure types
cd = (cd
      .with_columns(
    pl.when(pl.col('disclosuretype').eq(pl.lit('EventBasedDisclosure')))
    .then(1).otherwise(0).alias('event_based_disclosure'),
    pl.when(pl.col('disclosuretype').eq(pl.lit('FinancialOperatingDataDisclosure')))
    .then(1).otherwise(0).alias('financial_operating_data_disclosure'),
    pl.when(pl.col('financialoperatingdisclosurecategory').str.to_lowercase().str.contains('audited'))
    .then(1).otherwise(0).alias('audited_financial_disclosure'),
    pl.when(pl.col('financialoperatingdisclosurecategory').str.to_lowercase().str.contains('failure'))
    .then(1).otherwise(0).alias('failure_financial_disclosure'),
    pl.when(pl.col('financialoperatingdisclosurecategory').str.to_lowercase().str.contains('budget'))
    .then(1).otherwise(0).alias('budget_financial_disclosure'),
    pl.when(pl.col('financialoperatingdisclosurecategory').str.to_lowercase().str.contains('voluntary'))
    .then(1).otherwise(0).alias('voluntary_financial_disclosure')
))


# create indicators for different time horizons
cd = (cd
      .with_columns(
    pl.when(pl.col('days_since_offering').le(365)).then(1).otherwise(0).alias('within_1_year'),
    pl.when(pl.col('days_since_offering').le(365*2)).then(1).otherwise(0).alias('within_2_years'),
    pl.when(pl.col('days_since_offering').le(365*3)).then(1).otherwise(0).alias('within_3_years'),
    pl.when(pl.col('days_since_offering').le(365*5)).then(1).otherwise(0).alias('within_5_years'),
    pl.when(pl.col('disclosure_event_date').lt(pl.date(2024,1,1))).then(1).otherwise(0).alias('full_msrb_sample')
))

cd_agg = (
    cd
    .group_by(['issue_id'])
    .agg(
        # -----------------------------
        # Timeliness (unchanged)
        # -----------------------------
        pl.col('timeliness_days_mean')
            .filter(pl.col('within_1_year').eq(1) & pl.col('timeliness_days_mean').is_not_null())
            .mean()
            .alias('timeliness_avg_1yr'),

        pl.col('timeliness_days_mean')
            .filter(pl.col('within_3_years').eq(1) & pl.col('timeliness_days_mean').is_not_null())
            .mean()
            .alias('timeliness_avg_3yr'),

        pl.col('timeliness_days_mean')
            .filter(pl.col('within_5_years').eq(1) & pl.col('timeliness_days_mean').is_not_null())
            .mean()
            .alias('timeliness_avg_5yr'),

        # FULL MSRB
        pl.col('timeliness_days_mean')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('full_msrb_sample').eq(1)
                & pl.col('timeliness_days_mean').is_not_null()
            )
            .mean()
            .alias('timeliness_avg_full_msrb'),

        # -----------------------------
        # Total disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1))
            .n_unique()
            .alias('num_disclosures_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_2_years').eq(1))
            .n_unique()
            .alias('num_disclosures_within_2_years'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1))
            .n_unique()
            .alias('num_disclosures_within_3_years'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1))
            .n_unique()
            .alias('num_disclosures_within_5_years'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('full_msrb_sample').eq(1))
            .n_unique()
            .alias('num_disclosures_full_msrb'),

        # -----------------------------
        # Event-based disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1) & pl.col('event_based_disclosure').eq(1))
            .n_unique()
            .alias('num_event_based_disclosures_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_2_years').eq(1) & pl.col('event_based_disclosure').eq(1))
            .n_unique()
            .alias('num_event_based_disclosures_within_2_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1) & pl.col('event_based_disclosure').eq(1))
            .n_unique()
            .alias('num_event_based_disclosures_within_3_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('event_based_disclosure').eq(1))
            .n_unique()
            .alias('num_event_based_disclosures_within_5_year'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('event_based_disclosure').eq(1)
                & pl.col('full_msrb_sample').eq(1)
            )
            .n_unique()
            .alias('num_event_based_disclosures_full_msrb'),

        # -----------------------------
        # Financial operating disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1) & pl.col('financial_operating_data_disclosure').eq(1))
            .n_unique()
            .alias('num_financial_operating_data_disclosure_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_2_years').eq(1) & pl.col('financial_operating_data_disclosure').eq(1))
            .n_unique()
            .alias('num_financial_operating_data_disclosure_within_2_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1) & pl.col('financial_operating_data_disclosure').eq(1))
            .n_unique()
            .alias('num_financial_operating_data_disclosure_within_3_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('financial_operating_data_disclosure').eq(1))
            .n_unique()
            .alias('num_financial_operating_data_disclosure_within_5_year'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('financial_operating_data_disclosure').eq(1)
                & pl.col('full_msrb_sample').eq(1)
            )
            .n_unique()
            .alias('num_financial_operating_data_disclosure_full_msrb'),

        # -----------------------------
        # Audited financial disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1) & pl.col('audited_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_audited_cafr_disclosure_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_2_years').eq(1) & pl.col('audited_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_audited_cafr_disclosure_within_2_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1) & pl.col('audited_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_audited_cafr_disclosure_within_3_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('audited_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_audited_cafr_disclosure_within_5_year'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('audited_financial_disclosure').eq(1)
                & pl.col('full_msrb_sample').eq(1)
            )
            .n_unique()
            .alias('num_audited_cafr_disclosure_full_msrb'),

        # -----------------------------
        # Failure-to-file disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1) & pl.col('failure_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_failure_disclosure_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_2_years').eq(1) & pl.col('failure_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_failure_disclosure_within_2_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1) & pl.col('failure_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_failure_disclosure_within_3_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('failure_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_failure_disclosure_within_5_year'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('failure_financial_disclosure').eq(1)
                & pl.col('full_msrb_sample').eq(1)
            )
            .n_unique()
            .alias('num_failure_disclosure_full_msrb'),

        # -----------------------------
        # Budget disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1) & pl.col('budget_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_budget_financial_disclosure_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_2_years').eq(1) & pl.col('budget_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_budget_financial_disclosure_within_2_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1) & pl.col('budget_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_budget_financial_disclosure_within_3_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('budget_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_budget_financial_disclosure_within_5_year'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('budget_financial_disclosure').eq(1)
                & pl.col('full_msrb_sample').eq(1)
            )
            .n_unique()
            .alias('num_budget_financial_disclosure_full_msrb'),

        # -----------------------------
        # Voluntary disclosures
        # -----------------------------
        pl.col('submissionidentifier')
            .filter(pl.col('within_1_year').eq(1) & pl.col('voluntary_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_voluntary_financial_disclosure_within_1_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_3_years').eq(1) & pl.col('voluntary_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_voluntary_financial_disclosure_within_3_year'),

        pl.col('submissionidentifier')
            .filter(pl.col('within_5_years').eq(1) & pl.col('voluntary_financial_disclosure').eq(1))
            .n_unique()
            .alias('num_voluntary_financial_disclosure_within_5_year'),

        # FULL MSRB
        pl.col('submissionidentifier')
            .filter(
                pl.col('within_5_years').eq(1)
                & pl.col('voluntary_financial_disclosure').eq(1)
                & pl.col('full_msrb_sample').eq(1)
            )
            .n_unique()
            .alias('num_voluntary_financial_disclosure_full_msrb'),
    )
)



#%%=================== Merge back with Mergent - issue level ===================
# Load full Mergent data (don't filter yet — need full history for cumulative calculations)
mergent_issue_level_all = pl.read_parquet(f'{data_dir}Mergent/Clean/251111_issue_level_aggregation.gzip')
mergent_issue_level = (mergent_issue_level_all
                       .filter(pl.col('issue_id').is_in(mergent.select('issue_id').unique().to_series().to_list())))

# merge
mergent_issue_level = (
    mergent_issue_level
    .join(cd_agg, on='issue_id', how='left')
)

# fill null of all disclosure variables with 0
mergent_issue_level = (mergent_issue_level
                       .with_columns([
    pl.col('num_disclosures_within_1_year').fill_null(0),
    pl.col('num_disclosures_within_2_years').fill_null(0),
    pl.col('num_disclosures_within_3_years').fill_null(0),
    pl.col('num_disclosures_within_5_years').fill_null(0),
    pl.col('num_disclosures_full_msrb').fill_null(0),
    pl.col('num_event_based_disclosures_within_1_year').fill_null(0),
    pl.col('num_event_based_disclosures_within_2_year').fill_null(0),
    pl.col('num_event_based_disclosures_within_3_year').fill_null(0),
    pl.col('num_event_based_disclosures_within_5_year').fill_null(0),
    pl.col('num_event_based_disclosures_full_msrb').fill_null(0),
    pl.col('num_financial_operating_data_disclosure_within_1_year').fill_null(0),
    pl.col('num_financial_operating_data_disclosure_within_2_year').fill_null(0),
    pl.col('num_financial_operating_data_disclosure_within_3_year').fill_null(0),
    pl.col('num_financial_operating_data_disclosure_within_5_year').fill_null(0),
    pl.col('num_financial_operating_data_disclosure_full_msrb').fill_null(0),
    pl.col('num_audited_cafr_disclosure_within_1_year').fill_null(0),
    pl.col('num_audited_cafr_disclosure_within_2_year').fill_null(0),
    pl.col('num_audited_cafr_disclosure_within_3_year').fill_null(0),
    pl.col('num_audited_cafr_disclosure_within_5_year').fill_null(0),
    pl.col('num_audited_cafr_disclosure_full_msrb').fill_null(0),
    pl.col('num_failure_disclosure_within_1_year').fill_null(0),
    pl.col('num_failure_disclosure_within_2_year').fill_null(0),
    pl.col('num_failure_disclosure_within_3_year').fill_null(0),
    pl.col('num_failure_disclosure_within_5_year').fill_null(0),
    pl.col('num_failure_disclosure_full_msrb').fill_null(0),
    pl.col('num_budget_financial_disclosure_within_1_year').fill_null(0),
    pl.col('num_budget_financial_disclosure_within_2_year').fill_null(0),
    pl.col('num_budget_financial_disclosure_within_3_year').fill_null(0),
    pl.col('num_budget_financial_disclosure_within_5_year').fill_null(0),
    pl.col('num_budget_financial_disclosure_full_msrb').fill_null(0),
    pl.col('num_voluntary_financial_disclosure_within_1_year').fill_null(0),
    #pl.col('num_voluntary_financial_disclosure_within_2_year').fill_null(0),
    pl.col('num_voluntary_financial_disclosure_within_3_year').fill_null(0),
    pl.col('num_voluntary_financial_disclosure_within_5_year').fill_null(0),
    pl.col('num_voluntary_financial_disclosure_full_msrb').fill_null(0)
]))

#%%=================== Cumulative issuance over full sample ===================
# Recover issue size from log
mergent_issue_level = (
    mergent_issue_level
    .with_columns(pl.col('log_issue_size').exp().alias('issue_size'))
)

# Cumulative total debt before each issuance (all bonds)
all_bonds_cumulative = (
    mergent_issue_level
    .select(['seed_issuer_id', 'issue_id', 'offering_date', 'issue_size'])
    .sort(['seed_issuer_id', 'offering_date'])
    .with_columns(
        pl.col('issue_size').cum_sum().over('seed_issuer_id').alias('cum_debt_after'),
        pl.col('issue_id').cum_count().over('seed_issuer_id').alias('cum_count_after')
    )
    .with_columns(
        (pl.col('cum_debt_after') - pl.col('issue_size')).alias('cum_total_debt_before'),
        (pl.col('cum_count_after') - 1).alias('cum_total_count_before')
    )
    .select(['issue_id', 'cum_total_debt_before', 'cum_total_count_before'])
)

# Cumulative GO unlimited debt before each issuance (as-of each issuance date)
# Build a running cumulative GO series across ALL issuances, treating non-GO as 0
go_debt_for_all_issues = (
    mergent_issue_level
    .select(['seed_issuer_id', 'issue_id', 'offering_date', 'go_unlim', 'issue_size'])
    .sort(['seed_issuer_id', 'offering_date'])
    .with_columns(
        pl.when(pl.col('go_unlim').eq(1)).then(pl.col('issue_size')).otherwise(0).alias('go_issue_size'),
        pl.when(pl.col('go_unlim').eq(1)).then(1).otherwise(0).alias('go_issue_indicator')
    )
    .with_columns(
        pl.col('go_issue_size').cum_sum().over('seed_issuer_id').alias('cum_go_after'),
        pl.col('go_issue_indicator').cum_sum().over('seed_issuer_id').alias('cum_go_count_after')
    )
    .with_columns(
        (pl.col('cum_go_after') - pl.col('go_issue_size')).alias('cum_go_debt_before'),
        (pl.col('cum_go_count_after') - pl.col('go_issue_indicator')).alias('cum_go_count_before')
    )
    .select(['issue_id', 'cum_go_debt_before', 'cum_go_count_before'])
)

# Attach cumulative variables
mergent_issue_level = (
    mergent_issue_level
    .join(all_bonds_cumulative, on='issue_id', how='left')
    .join(go_debt_for_all_issues, on='issue_id', how='left')
    .with_columns([
        pl.col('cum_total_debt_before').fill_null(0),
        pl.col('cum_total_count_before').fill_null(0),
        pl.col('cum_go_debt_before').fill_null(0),
        pl.col('cum_go_count_before').fill_null(0)
    ])
)

# Final sample restriction (post-2009) happens AFTER cumulative calculations
mergent_issue_level = (
    mergent_issue_level
    .filter(pl.col('offering_date').dt.year() >= 2009)
)

#%%=================== Create restriction indicators ===================
# Indicator for small issuances (< $1 million)
mergent_issue_level = (
    mergent_issue_level
    .with_columns(
        pl.when(pl.col('issue_size').lt(1_000_000))
        .then(1)
        .otherwise(0)
        .alias('small_issue_under_1m')
    )
)

# Indicator for short maturity (< 18 months)
# log_avg_maturity is in log years, so 18 months = 1.5 years
mergent_issue_level = (
    mergent_issue_level
    .with_columns(
        pl.col('log_avg_maturity').exp().alias('avg_maturity_years')
    )
    .with_columns(
        pl.when(pl.col('avg_maturity_years').lt(1.5))
        .then(1)
        .otherwise(0)
        .alias('short_maturity_under_18mo')
    )
)

#%%=================== Save ===================
output_date = 20251201
mergent_issue_level.write_csv(f'{data_dir}Continuing Disclosure/Processed/issue_level_with_cd_vars_{output_date}.csv')

#%%=================== Border State ===================
border_state = pl.read_csv(f'{data_dir}/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20251013.csv', infer_schema_length = 10000)
border_state = (border_state
                .select(['issue_id', 'group'])
                .unique())

mergent_issue_level_border = (mergent_issue_level.with_columns(pl.col('issue_id').cast(pl.Int64))
                              .join(border_state, on='issue_id', how='inner'))

#%%=================== Merge with website data ===================
websites = (pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_251111_with_recovered.csv')
            .select(['seed_issuer_id', 'year', 'bond_url', 'debt_url', 'bond_count', 'debt_count',
                     'fiscal_url', 'fiscal_count', 'financial_pdf_urls'])
            .with_columns(pl.col('bond_url').add(pl.col('debt_url')).alias('bond_debt_url'),
                          pl.col('bond_count').add(pl.col('debt_count')).alias('bond_debt_count')))

mergent_issue_level_border = (mergent_issue_level_border.with_columns(pl.col('seed_issuer_id').cast(pl.Int64),
                                                                      pl.col('year').cast(pl.Int64))
                              .join(websites, on = ['seed_issuer_id', 'year'], how='left'))

mergent_issue_level_border.write_csv(f'{data_dir}Continuing Disclosure/Processed/border_issue_level_with_cd_vars_{output_date}.csv')