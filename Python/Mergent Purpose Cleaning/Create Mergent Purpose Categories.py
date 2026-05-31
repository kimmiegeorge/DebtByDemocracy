#%%
#--------------------
# set up
#--------------------

import polars as pl
import pandas as pd

data_dir = '~/Dropbox/Voting on Bonds/Data'

#%%
#--------------------
# set up
#--------------------
mergent_full = pd.read_stata(f'{data_dir}/Mergent/Clean/250313_citycountyschool_cusiplevel_statereq_purpose.dta')
mergent_full = pl.DataFrame(mergent_full)

# filter to go unlim and cities
mergent_full = (mergent_full
                .filter(pl.col('go_unlim').eq(1) & pl.col('city').eq(1)))

# pull id, desc and purpose
desc = (mergent_full
                .select(['issue_id', 'cusip', 'issue_description', 'purp_broad'])
                .unique())

# gen pub improv
gen_improv = (desc
              .filter(pl.col('purp_broad').eq('genpubimprov')))

# adjust string
gen_improv_words = (gen_improv
              .with_columns(pl.col('issue_description').str.to_lowercase())
              .with_columns(pl.col('issue_description').str.replace('general obligation', ''))
              .with_columns(
                            pl.col('issue_description').str.replace('limited obligation', ''))
.with_columns(pl.col('issue_description').str.split(' ').alias('words'))
              .explode('words')
              .group_by('words').len().sort('len'))

# drop un-necessary
drop_words = [' ', ',', 'improvement', 'tax', 'public', 'general', 'and', 'purpose', 'purpose,',
              'unlimited', 'municipal', 'city']
gen_improv_words = (gen_improv_words
                    .filter(~pl.col('words').is_in(drop_words)))

'''
gen_improv_words.write_csv('~/Dropbox/Voting on Bonds/Code/Python/Mergent Purpose Cleaning/gen_improv_words.csv')

# also save purposes
mergent_full.select('purp_broad').unique().write_csv('~/Dropbox/Voting on Bonds/Code/Python/Mergent Purpose Cleaning/purpose_cats.csv')
'''

#%%
# re-load classifications
classifications = (pl
                   .read_csv('~/Dropbox/Voting on Bonds/Code/Python/Mergent Purpose Cleaning/words_classified.csv')
                   .filter(pl.col('purp_adj').is_not_null())
                   )

issue_lvl_words =  (gen_improv
              .with_columns(pl.col('issue_description').str.to_lowercase())
              .with_columns(pl.col('issue_description').str.replace('general obligation', ''))
              .with_columns(
                            pl.col('issue_description').str.replace('limited obligation', ''))
.with_columns(pl.col('issue_description').str.split(' ').alias('words'))
              .explode('words'))

issue_lvl_words = (issue_lvl_words
                   .join(classifications, on = 'words', how = 'left'))

adj_classified_issues = (issue_lvl_words
                         .filter(pl.col('purp_adj').is_not_null()))