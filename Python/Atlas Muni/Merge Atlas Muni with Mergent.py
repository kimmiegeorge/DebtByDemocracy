'''
Merge Atlas Muni and Mergent Data
Get Time Series of Fraction of Debt in different types
'''

#%% -----------------------------------------------------------------------
# Notes
# -----------------------------------------------------------------------
'''
* ID Mapping: Cusip6toIssuerId_XX.txt and Cusip9toIssuerId_XX.txt located in Atlas Muni Data/IDMapping
* Total Debt Data TotalDebtHistory_ATXXXXXX.txt includes full history of total debt data, updated monthly
* Total Debt Data: DebtType 1 = debt issued by oligor directly 
* Total Debt Data: DebtType 2 = local overlapping debt 
* Total Debt Data includes GOOutstanding and RevOutstanding
'''


#%% -----------------------------------------------------------------------
# set up
# -----------------------------------------------------------------------
import pandas as pd
import polars as pl
import os

mergent_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data')
atlas_dir = '~/Dropbox/SZ/Atlas Muni Data'

#%% -----------------------------------------------------------------------
# load data
# -----------------------------------------------------------------------

atlas = (pl.scan_csv(f'{atlas_dir}/TotalDebt/TotalDebtHistory/TotalDebtHistory_*.txt',
                   skip_rows =1,
                   separator = '|',
                   has_header = False,
                   low_memory = False
                   )
            .rename({'column_1': 'ObligorId', 'column_2': 'DataDate', 'column_3': 'DebtType', 'column_4': 'GOOutstanding',
                     'column_5': 'RevOutstanding', 'column_6': 'TotalOutstanding'})
            .with_columns(pl.col('DataDate').cast(pl.Date))
            .with_columns(pl.col('DataDate').dt.month().alias('month'),
                          pl.col('DataDate').dt.year().alias('year'))
            # keep last month of the year
            .filter(pl.col('month').eq(12))
            # keep debt type = 1
            .filter(pl.col('DebtType').eq(1))
        .collect())

mergent = (pl
             .DataFrame(pd
                        .read_stata(f'{mergent_dir}/Mergent/Clean/250313_citycountyschool_cusiplevel_statereq_purpose.dta'))
           .select(['seed_issuer_id', 'issuer_long_name', 'seed_issuer', 'cusip6', 'issuer_type', 'state', 'city_go_vote',
                    'city_rev_vote', 'city', 'county', 'school', 'fips', 'county_name',
                    'state_utgo_allowed', 'state_ltgo_allowed', 'state_fullfaith', 'state_go_vote',
                    'state_sep_debtservice_levy', 'state_sep_pledgerev', 'state_statutorylien'])
           .unique()
            .filter(pl.col('city').eq(1))
            # keep one observation per seed issuer id (will have multiple cusip)
           .group_by('seed_issuer_id').first())

cusip_to_issuer = (pl
          .scan_csv(f'{atlas_dir}/IDMapping/Cusip6toIssuerId/*.txt',
                   separator = '|',
                    skip_rows = 1,
                   has_header = False,
                   low_memory = False)
.rename({'column_1': 'cusip6', 'column_2': 'IssuerId'})
        .collect())

issuer_to_obligor =  (pl
          .scan_csv(f'{atlas_dir}/Reference/RefIssuer/*.txt',
                   separator = '|',
                    skip_rows = 1,
                   has_header = False,
                   low_memory = False)
        .select(['column_1', 'column_2', 'column_3'])
        .rename({'column_1': 'IssuerId',
                 'column_2': 'AtlasIssuerName',
                 'column_3': 'ObligorId'})
        .collect())

cusip_to_issuer = (cusip_to_issuer
                   .join(issuer_to_obligor, on = 'IssuerId', how = 'left'))

#%% -----------------------------------------------------------------------
# Merge
# -----------------------------------------------------------------------

# merge id_map with mergent
mergent = (mergent
           .join(cusip_to_issuer, on = 'cusip6', how = 'left'))

print(mergent.filter(pl.col('IssuerId').is_null()).shape[0]/mergent.shape[0]) # only 1% of issuers are missing

mergent = (mergent
           .filter(pl.col('ObligorId').is_not_null()))

# keep first observation for each ObligorId (some are duplicated)
mergent = (mergent
           .group_by('ObligorId').first())

atlas = (atlas
         .join(mergent, on = 'ObligorId', how = 'left'))

print(atlas.filter(pl.col('cusip6').is_null()).shape[0]/atlas.shape[0]) # 87% of Atlas Issuers not in Mergent City sample

atlas = (atlas
         .filter(pl.col('seed_issuer_id').is_not_null()))


#%% -----------------------------------------------------------------------
# Additional Variables
# -----------------------------------------------------------------------
atlas = (atlas
         .with_columns(pl.col('GOOutstanding').truediv(pl.col('TotalOutstanding')).alias('Percent_GOOutstanding'))
         .with_columns(pl.when(pl.col('state').is_in(['WA', 'MI', 'OH'])).then(1).otherwise(0).alias('go_unlim_vote_only')))

#%% -----------------------------------------------------------------------
# Demo Variables
# -----------------------------------------------------------------------
emp = (pl.DataFrame(pd.read_stata(f'{mergent_dir}/BEA/employment_2001_2022.dta'))
                   .drop('geoname'))
percap_inc = (pl.DataFrame(pd.read_stata(f'{mergent_dir}/BEA/percap_inc_2001_2022.dta'))
                            .drop('geoname'))
pers_inc = (pl.DataFrame(pd.read_stata(f'{mergent_dir}/BEA/pers_inc_2001_2022.dta'))
                        .drop('geoname'))
pop = (pl.DataFrame(pd.read_stata(f'{mergent_dir}/BEA/pop_2001_2022.dta'))
                    .drop('geoname'))
gdp = (pl.DataFrame(pd.read_stata(f'{mergent_dir}/BEA/gdp_2001_2022.dta'))
                .drop('geoname'))

atlas = (atlas
        .with_columns(pl.col('year').cast(pl.Int16))
         .join(emp, on = ['fips', 'year'], how = 'left')
         .join(percap_inc, on = ['fips', 'year'], how = 'left')
         .join(pers_inc, on = ['fips', 'year'], how = 'left')
         .join(pop, on = ['fips', 'year'], how = 'left')
         .join(gdp, on = ['fips', 'year'], how = 'left'))


#%% -----------------------------------------------------------------------
# logadjust
# -----------------------------------------------------------------------

atlas = (atlas
         .with_columns(pl.col('GOOutstanding').add(1).log().alias('ln_GOOutstanding'),
                       pl.col('RevOutstanding').add(1).log().alias('ln_RevOutstanding'),
                       pl.col('TotalOutstanding').log().alias('ln_TotalOutstanding'),
                       pl.col('employment').add(1).log().alias('ln_employment'),
                          pl.col('percap_inc').add(1).log().alias('ln_percap_inc'),
                            pl.col('pers_inc').add(1).log().alias('ln_pers_inc'),
                          pl.col('pop').add(1).log().alias('ln_pop'),
                            pl.col('gdp').add(1).log().alias('ln_gdp')
         ))

atlas = (atlas
         .with_columns(pl.when(pl.col('city_go_vote').eq(1) & pl.col('go_unlim_vote_only').eq(0))
                       .then(1).otherwise(0).alias('all_go_vote')))

# per capita
atlas = (atlas
         .with_columns(pl.col('GOOutstanding').truediv(pl.col('pop')).alias('GOOutstanding_percap'),
                       pl.col('RevOutstanding').truediv(pl.col('pop')).alias('RevOustanding_percap'),
                       pl.col('TotalOutstanding').truediv(pl.col('pop')).alias('TotalOutstanding_percap')))

# log adjust
atlas = (atlas
         .with_columns(pl.col('GOOutstanding_percap').add(1).log().alias('ln_GOOutstanding_percap'),
                       pl.col('RevOustanding_percap').add(1).log().alias('ln_RevOutstanding_percap'),
                       pl.col('TotalOutstanding_percap').add(1).log().alias('ln_TotalOutstanding_percap')))
#%% -----------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------
atlas.write_csv(f'{mergent_dir}/Atlas Muni/250519_atlas_mergent_merged.csv')

#%% -----------------------------------------------------------------------
# Also Output Border-State Sample
# -----------------------------------------------------------------------
border_state = (pl.read_csv(f'{mergent_dir}/Border States/Border Matches All Mergent Data With MSRB 20250514.csv',
                            infer_schema_length = 10000)
                .select(['seed_issuer_id',
                         'group', 'category'])
                .unique())

atlas_border = (atlas
                .with_columns(pl.col('seed_issuer_id').cast(pl.Int64))
                .join(border_state, on = 'seed_issuer_id', how = 'inner'))

atlas_border.write_csv(f'{mergent_dir}/Atlas Muni/250519_atlas_mergent_border_states.csv')