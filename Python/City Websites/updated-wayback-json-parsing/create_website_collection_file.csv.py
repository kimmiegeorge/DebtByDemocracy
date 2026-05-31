'''
create website collection file for manual website collection
'''

import polars as pl

# load border issuers
border_issuers = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 100000 20250827.csv',infer_schema_length=10000)
border_issuers = (border_issuers.select(['seed_issuer_id', 'seed_issuer', 'group'])).unique()
good_groups = ["Tennesee/Georgia","Kentucky/Missouri","Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                               "Tennesee/North Carolina", "Tennessee/Missouri"]
border_issuers = (border_issuers.filter(pl.col('group').is_in(good_groups)))

# merge with previous collection
prev_collection = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Border Matches Issuers 20250227.csv')
border_issuers = (border_issuers
                  .join(prev_collection
                        .select(['seed_issuer_id', 'seed_issuer', 'group', 'City Website'])
                        .with_columns(prev_collected = 1), on = ['seed_issuer_id', 'seed_issuer', 'group'], how = 'left'))

# write csv for collection
border_issuers = (border_issuers
                  .with_columns(pl.col('prev_collected').fill_null(0)))
border_issuers.write_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Border Matches Issuers Website Collection 20250901.csv')