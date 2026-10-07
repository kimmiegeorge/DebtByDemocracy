'''
find URLs that don't seem to be processed correctly
'''

import polars as pl
import os
input_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Updated Scraping 202509/Processed')
from pathlib import Path

res = (pl.concat(
   (pl.scan_csv(f) for f in Path(f'{input_dir}/res/').glob("*.csv")),
   how="diagonal_relaxed"
).collect()
       .select(['parent url', 'URL', 'original_url', 'priority']))

# get year
res = (res
       .with_columns(pl.col('parent url').str.slice(28, 4).alias('year')))


# get counts
res = (res
       .with_columns(pl.col('URL').count().over(['original_url', 'year']).alias('count')))

# url level
parent_url_count = (res
                    .group_by(pl.col(['original_url', 'year']))
                    .agg(pl.col('count').first()))

# bad url
bad_url = (parent_url_count
           .filter(pl.col('count').eq(1)))

# output
bad_url.write_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/bad_urls_251105.csv')