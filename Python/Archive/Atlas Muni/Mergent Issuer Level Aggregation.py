'''
Aggregate to the issuer level
Total debt, debt of different types, size weighted yields
'''

#%% -----------------------------------------------------------------------
# set up
# -----------------------------------------------------------------------
import pandas as pd
import polars as pl
import os

mergent_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data')
#%% -----------------------------------------------------------------------
# load data
# -----------------------------------------------------------------------
mergent = (pl.DataFrame(pd
                        .read_stata(f'{mergent_dir}/Mergent/Clean/250313_citycountyschool_cusiplevel_statereq_purpose.dta')))

yield_spreads = (pl.read_csv(f'{mergent_dir}/Mergent/Clean/250603_bond_level_off_yield_spread.csv'))

mergent = (mergent
            .with_columns(pl.col('issue_id').cast(pl.Int64))
           .join(yield_spreads,on = ['issue_id', 'cusip'], how = 'left'))

#%% -----------------------------------------------------------------------
# aggregate to issuer level
# -----------------------------------------------------------------------
issuer_level = (mergent
                .sort(['seed_issuer_id', 'year'])
                .with_columns(pl.col('amount').sum().over('seed_issuer_id').alias('total_amount_issued'))
                .with_columns(pl.col('amount').truediv(pl.col('total_amount_issued')).alias('weight'))
                .drop('total_amount_issued')
                .group_by('seed_issuer_id')
                .agg(pl.col('issue_id').n_unique().alias('num_issuances'),
                     pl.col('cusip').n_unique().alias('num_bonds'),
              pl.col('state').first(),
                     pl.col('issuer_type').first(),
                     pl.col('county_name').first(),
                     pl.col('city_go_vote').first(),
                     pl.col('city_rev_vote').first(),
                        pl.col('city').first(),
                        pl.col('county').first(),
                        pl.col('school').first(),
                        pl.col('fips').first(),
                     pl.col('amount').sum(),
                     pl.col('amount').sum().log().alias('ln_amount'),
                     pl.col('offering_yield').mean().alias('yield'),
                     pl.col('offering_yield').mul(pl.col('weight')).sum().alias('weighted_yield'),
                    pl.col('offering_yield_spread').mean().alias('yield_spread'),
                     pl.col('offering_yield_spread').mul(pl.col('weight')).sum().alias('weighted_yield_spread'),
                     pl.col('amount').filter(pl.col('go_unlim').eq(1)).sum().alias('go_unlimited_amount'),
                        pl.col('amount').filter(pl.col('go_lim').eq(1)).sum().alias('go_limited_amount'),
                        pl.col('amount').filter(pl.col('rev').eq(1)).sum().alias('rev_amount'),
                     pl.col('insured').mean().alias('insured'),
                     pl.col('rated').mean().alias('rated'),
                     pl.col('pop').filter(pl.col('pop').is_not_null()).log().first(),
                     pl.col('gdp').filter(pl.col('gdp').is_not_null()).log().first(),
                        pl.col('pers_inc').filter(pl.col('pers_inc').is_not_null()).log().first(),
                        pl.col('percap_inc').filter(pl.col('percap_inc').is_not_null()).log().first(),
                        pl.col('emp').filter(pl.col('emp').is_not_null()).log().first(),
                     pl.col('state_go_vote').first(),
                     pl.col('state_ltgo_allowed').first(),
                        pl.col('state_fullfaith').first(),
                        pl.col('state_sep_debtservice_levy').first(),
                        pl.col('state_sep_pledgerev').first(),
                        pl.col('state_statutorylien').first())
                .with_columns(pl.col('go_unlimited_amount').fill_null(0).truediv(pl.col('amount')).alias('perc_go_unlim'),
                              pl.col('go_limited_amount').fill_null(0).truediv(pl.col('amount')).alias('perc_go_lim'),
                              pl.col('rev_amount').fill_null(0).truediv(pl.col('amount')).alias('perc_rev'))
                .with_columns(pl.col('perc_go_unlim').add(pl.col('perc_go_lim')).alias('perc_go'))
                .with_columns(
    pl.when(pl.col('state').is_in(['WA', 'MI', 'OH'])).then(1).otherwise(0).alias('go_unlim_vote_only'))
.with_columns(pl.when(pl.col('city_go_vote').eq(1) & pl.col('go_unlim_vote_only').eq(0))
                       .then(1).otherwise(0).alias('all_go_vote')))



#%% -----------------------------------------------------------------------
# filter
# -----------------------------------------------------------------------
issuer_level_sample = (issuer_level
                       .filter(pl.col('city').eq(1))
                       .filter(pl.col('city_go_vote').is_not_null()))

#%% -----------------------------------------------------------------------
# save
# -----------------------------------------------------------------------
issuer_level_sample.write_csv(f'{mergent_dir}/Atlas Muni/Issuer Level Aggregation by Mergent.csv')

#%% -----------------------------------------------------------------------
# Also Output Border-State Sample
# -----------------------------------------------------------------------
border_state = (pl.read_csv(f'{mergent_dir}/Border States/Border Matches All Mergent Data With MSRB 20250514.csv',
                            infer_schema_length = 10000)
                .select(['seed_issuer_id',
                         'group', 'category'])
                .unique())

issuer_border = (issuer_level_sample
                .with_columns(pl.col('seed_issuer_id').cast(pl.Int64))
                .join(border_state, on = 'seed_issuer_id', how = 'inner'))

issuer_border.write_csv(f'{mergent_dir}/Atlas Muni/Issuer Level Aggregation by Mergent Border States.csv')