'''
Get time series of outlets covered per year
'''

# SET DATE FOR OUTPUT FILES
output_date = '250908'

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
load data and aggregate rp articles 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# load rp map and add fips
rp_map = pl.read_csv(f'{data_dir}/News/RP_Mergent_Mapping.csv')
fips = (pl.read_csv(f'{data_dir}/News/Ravenpack_Cities_With_FIPS.csv')
        .select(['rp_entity_id', 'fips']))
rp_map = (rp_map
          .join(fips, on = 'rp_entity_id', how = 'left'))

newswires = ['B5569E', 'D19959', '53A5CA', '751371', 'A51917', '4A513E']
# load rp articles
rp_articles = (pl
               .scan_parquet(f'{rp_dir}/*')
               .select(['rp_entity_id', 'relevance', 'rpa_date_utc', 'topic', 'group', 'type', 'headline', 'rp_source_id'])
               .filter(pl.col('rp_entity_id').is_in(rp_map.select('rp_entity_id')))
               .filter(pl.col('relevance').ge(90))
                #.filter(pl.col('relevance').eq(100))
#.filter(~pl.col('rp_source_id').is_in(newswires))
                # drop bond-related articles
               #.filter(~(pl.col('headline').str.to_lowercase().str.contains('bond') |
                #       pl.col('headline').str.to_lowercase().str.contains('debt') |
                 #      pl.col('headline').str.to_lowercase().str.contains('credit') |
                  #     pl.col('headline').str.to_lowercase().str.contains('tax')))
               #.filter(pl.col('group').is_in(['housing', 'elections', 'government', 'credit', 'taxes', 'public-finance']))
               .filter(pl.col('rpa_date_utc').lt(pl.date(2021,1,1)))
                .filter(pl.col('rpa_date_utc').gt(pl.date(2000,12,31)))
               .collect(streaming = True))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
compute average number of outlets covering cities per year
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# aggregate by year to get unique outlets covering each city per year
yearly_outlets = (rp_articles
                  .with_columns(pl.col('rpa_date_utc').dt.year().alias('year'))
                  .group_by(['rp_entity_id', 'year'])
                  .agg(pl.col('rp_source_id').n_unique().alias('unique_outlets'))
                  .with_columns(pl.col('year').cast(pl.Int64)))

# compute average number of outlets per city per year
avg_outlets_per_year = (yearly_outlets
                        .group_by('year')
                        .agg(pl.col('unique_outlets').mean().alias('avg_outlets_per_city'))
                        .sort('year'))

print("Average number of outlets covering cities per year:")
print(avg_outlets_per_year)

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
plot time series
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

# convert to pandas for plotting
avg_outlets_pd = avg_outlets_per_year.to_pandas()

# create the plot
plt.figure(figsize=(12, 8))
plt.plot(avg_outlets_pd['year'], avg_outlets_pd['avg_outlets_per_city'],
         marker='o', linewidth=2, markersize=6)
plt.title('Average Number of Outlets Covering Cities Per Year', fontsize=16, fontweight='bold')
plt.xlabel('Year', fontsize=14)
plt.ylabel('Average Number of Unique Outlets per City', fontsize=14)
plt.grid(True, alpha=0.3)
plt.xticks(range(2001, 2021, 2), rotation=45)
plt.tight_layout()

# show statistics
print(f"\nSummary Statistics:")
print(f"Mean outlets per city across all years: {avg_outlets_pd['avg_outlets_per_city'].mean():.2f}")
print(f"Min outlets per city: {avg_outlets_pd['avg_outlets_per_city'].min():.2f} (Year: {avg_outlets_pd.loc[avg_outlets_pd['avg_outlets_per_city'].idxmin(), 'year']})")
print(f"Max outlets per city: {avg_outlets_pd['avg_outlets_per_city'].max():.2f} (Year: {avg_outlets_pd.loc[avg_outlets_pd['avg_outlets_per_city'].idxmax(), 'year']})")

plt.show()

# optionally save the plot
plt.savefig(f'/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/avg_outlets_per_city_per_year_{output_date}.png')
