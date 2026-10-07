'''
split collection files into lists of URLs
'''
import polars as pl
data_dir = '~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data'

#%%
all_issuers = pl.read_csv(f'{data_dir}/Border Matches Issuers 20250227.csv')
unique_url = all_issuers.select('City Website').unique().rename({'City Website': 'URL'})

#%%
num_rows = unique_url.shape[0]
quarter_size = num_rows // 4

df1 = unique_url.slice(0, quarter_size)
df2 = unique_url.slice(quarter_size, 2*quarter_size)
df3 = unique_url.slice(2*quarter_size, 3*quarter_size)
df4 = unique_url.slice(3*quarter_size, num_rows)

df1.write_csv(f'{data_dir}/Collection Files/URL Set 1.csv')
df2.write_csv(f'{data_dir}/Collection Files/URL Set 2.csv')
df3.write_csv(f'{data_dir}/Collection Files/URL Set 3.csv')
df4.write_csv(f'{data_dir}/Collection Files/URL Set 4.csv')
