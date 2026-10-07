'''
Aggregate Mergent Bond-Level Data to Issuance-Level Data
Merge with state bond voting requirements

'''

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import os
import pandas as pd

data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Load data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

bond_level = (pl
             .DataFrame(pd
                        .read_stata(f'{data_dir}/Mergent/Clean/251027_city_cusiplevel_statereq_purpose_yieldspread.dta')))

#state_req = (pl
 #            .read_csv(f'{data_dir}/Bond Elections/election_requirements_by_state.csv'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
aggregate to issuance level 
- log of total  issue size 
- log of maximum maturity (also pull amount-weighted average maturity)
- log of number of cusips packaged in the issue 
- callable 
- insured 
- sinkable 
- pre-funded 
- competitive issue 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
#### bank qualified info (Farrell)
#### also add rated
issue_level = (bond_level
                # first compute weights
                .with_columns(pl.col('amount').sum().over('issue_id').alias('issue_size'))
                .with_columns(pl.col('amount').truediv(pl.col('issue_size')).alias('issue_weight'))
                # also compute total amount issued in calendar year
                .with_columns(pl.col('offering_date').dt.year().alias('year'))
                # sort to later get purpose of largest issuance
                .sort(['issue_id', 'amount'], descending=True)
                .group_by('issue_id')
                .agg(pl.col('amount').sum().log().alias('log_issue_size'),
                    pl.col('maturity_days').max().log().alias('log_max_maturity'),
                    pl.col('maturity_days').mean().log().alias('log_avg_maturity'),
                    pl.col('maturity_days').mul(pl.col('issue_weight')).sum().log().alias('log_weighted_avg_maturity'),
                    pl.col('ln_num_cusip').first().alias('ln_num_cusip'),
                    pl.col('callable').mul(pl.col('issue_weight')).sum().alias('weighted_avg_callable'),
                    pl.col('insured').mul(pl.col('issue_weight')).sum().alias('weighted_avg_insured'),
                    pl.col('sinkable').mul(pl.col('issue_weight')).sum().alias('weighted_avg_sinkable'),
                    pl.col('rated').mul(pl.col('issue_weight')).sum().alias('weighted_avg_rated'),
                    pl.col('rated').max().alias('at_least_one_bond_rated'),
                    pl.col('callable').max().alias('at_least_one_bond_callable'),
                    pl.col('insured').max().alias('at_least_one_bond_insured'),
                     pl.col('sinkable').max().alias('at_least_one_bond_sinkable'),
                   # pl.col('offering_type').first().alias('offering_type'),
                    pl.col('offering_yield').mul(pl.col('issue_weight')).sum().alias('weighted_avg_offering_yield'),
                    pl.col('purp_broad').first().alias('purp_broad'),
                    # country demo
                    pl.col('ln_pop').first().alias('ln_pop'),
                    pl.col('ln_gdp').first().alias('ln_gdp'),
                    pl.col('ln_pers_inc').first().alias('ln_pers_inc'),
                    pl.col('ln_percap_inc').first().alias('ln_percap_inc'),
                    pl.col('ln_emp').first().alias('ln_emp'),
                    # identifying information
                    pl.col('state').first().alias('state'),
                    pl.col('seed_issuer').first().alias('seed_issuer'),
                    pl.col('seed_issuer_id').first().alias('seed_issuer_id'),
                    pl.col('city').first().alias('city'),
                    pl.col('county').first().alias('county'),
                    pl.col('school').first().alias('school'),
                    pl.col('year').first().alias('year'),
                    pl.col('cusip').first().alias('cusip'),
                    pl.col('offering_date').first().alias('offering_date'),
                    pl.col('go_unlim').first().alias('go_unlim'),
                    pl.col('go_lim').first().alias('go_lim'),
                    pl.col('rev').first().alias('rev'),
                    pl.col('fips').first().alias('fips'),
                    pl.col('county_name').first().alias('county_name'),
                    #pl.col('bank_qualified').first().alias('bank_qualified'),
                    # state level vars
                    pl.col('city_go_vote').first().alias('city_go_vote'),
                    pl.col('city_rev_vote').first().alias('city_rev_vote'),
                    #pl.col('state'),
                    pl.col('state_go_vote').first(),
                    pl.col('state_ltgo_allowed').first(),
                    pl.col('glm_proactive').first(),
                    pl.col('state_fullfaith').first(),
                    pl.col('state_sep_debtservice_levy').first(),
                    pl.col('state_sep_pledgerev').first(),
                    pl.col('state_statutorylien').first())
               )

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
add MSRB variables
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

msrb = (pl
        .read_parquet(f'{data_dir}/MSRB/Processed/Issuance_Level_Secondary_Market_Vars_2005_2023.gzip'))

issue_level = (issue_level
               .join(msrb, on = 'issue_id', how = 'left'))


issue_level = (issue_level
               .with_columns(pl.col('offering_date').dt.year().alias('year'),
                             pl.col('offering_date').dt.month().alias('month')))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
issue_level.write_parquet(f'{data_dir}/Mergent/Clean/251111_issue_level_aggregation.gzip')
issue_level.write_csv(f'{data_dir}/Mergent/Clean/251111_issue_level_aggregation.csv')