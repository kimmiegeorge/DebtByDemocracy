#%%

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import polars as pl
import pandas as pd
import matplotlib.pyplot as plt
import os

wrds_dir = '/Volumes/External/WRDS_202408'
#wrds_dir = '/Volumes/Elements/WRDS_202408'
rp_dir = '/Volumes/External/City_RP_Articles'
#rp_dir = '~/Dropbox/City_RP_Articles'
data_dir = '~/Dropbox/Voting on Bonds/Data'
#%%

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# load rp map and add fips
rp_map = pl.read_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv')
fips = (pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')
        .select(['rp_entity_id', 'fips']))
rp_map = (rp_map
          .join(fips, on = 'rp_entity_id', how = 'left'))


keywords = [
    "bond", "municipal", "muni", "obligation",
    "revenue", "tax-exempt", "taxable",
     "issuance", "offering",  "yield", "pricing", "issue",
    "debt", "underwriter", "underwriting", "rating", "credit", "refunding",
    "callable", "coupon", "capital"
]

# Create flexible pattern that handles plurals
def create_flexible_pattern(keywords):
    patterns = []
    for keyword in keywords:
        if keyword.endswith(('s', 'ing', 'ed')):
            # Already plural/gerund/past tense, keep as-is
            patterns.append(f"\\b{keyword}\\b")
        else:
            # Add optional 's' for plurals
            patterns.append(f"\\b{keyword}s?\\b")
    return "|".join(patterns)

pattern = create_flexible_pattern(keywords)  # handles plurals automatically

#pattern = "|".join([f"\\b{k}\\b" for k in keywords])  # word boundaries
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(rp_map.select('rp_entity_id')))
               .filter(pl.col('relevance').ge(90))
               .filter(pl.col("headline").str.to_lowercase().str.contains(pattern))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))

