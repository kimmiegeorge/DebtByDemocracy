'''
Look for duplicate issuer names and create issuer identifier
'''
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

import polars as pl
import pandas as pd

dta_dir = '~/Dropbox/Voting on Bonds/Data/Mergent/Clean'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load data 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuers = (pl
           .read_csv(f'{dta_dir}/241106_issuernames_unique_v2.csv')
           .filter(pl.col('school').eq(0)))
issuers.shape[0] #11,201


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
look for issuer_long_name that are completely included in other issuer_long_name
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
issuer_list = issuers['issuer_long_name'].to_list()

# create list of pairwise matches of issuer names contained in other issuer names
pairwise_matching = []
for s_i in range(0, len(issuer_list)):
    if s_i % 100 == 0:
        print(f'{s_i} out of {len(issuer_list)}')
    for s_j in range(s_i+1, len(issuer_list)):
        if issuer_list[s_i] in issuer_list[s_j]:
            pairwise_matching.append([issuer_list[s_i], issuer_list[s_j]])
        if issuer_list[s_j] in issuer_list[s_i]:
            pairwise_matching.append([issuer_list[s_j], issuer_list[s_i]])

# remove nested matches
# Example: APACHE CNTY ARIZ, APACHE CNTY ARIZ UNI SCH DIST NO 8 WINDOW ROCK,APACHE CNTY ARIZ UNI SCH DIST NO 8 WINDOW ROCK IMPACT A
nested_matches = set([t[0] for t in pairwise_matching]).intersection(set([t[1] for t in pairwise_matching]))
pairwise_matching = [t for t in pairwise_matching if t[0] not in nested_matches]

# remove outers issuers with multiple matches
outer_duplicates = []
outers = []
for t in pairwise_matching:
    if t[1] not in outers:
        outers.append(t[1])
    else:
        outer_duplicates.append(t[1])

pairwise_matching = [t for t in pairwise_matching if t[1] not in outer_duplicates]


del outers, outer_duplicates

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create data frame of issuers with matches, and their core match 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# first, need to add obsrevations for each seed issuer
unique_seeds = []
for t in pairwise_matching:
    if t[0] not in unique_seeds:
        unique_seeds.append(t[0])
seed_list = [[s, s] for s in unique_seeds]
full_list = pairwise_matching + seed_list
matched_issuers = pl.DataFrame({'seed_issuer': [t[0] for t in full_list],
                                'issuer_long_name': [t[1] for t in full_list]})

matched_issuers.shape[0] #4545
matched_issuers['seed_issuer'].n_unique() #1,674

del seed_list, full_list

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
filter to remaining users not matched in pairwise search
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
match_inner = set([t[0] for t in pairwise_matching])
match_outer = [t[1] for t in pairwise_matching]

nonmatch_issuers = (issuers
                    .filter((~pl.col('issuer_long_name').is_in(match_inner)))
                    .filter((~pl.col('issuer_long_name').is_in(match_outer))))

nonmatch_issuers.shape[0] #6,656


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
for the remaining issuers, extract city or county name and set this as seed issuer 
manually inspect observations with missing city or county name
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
state_abb = ['ALASKA', 'ALA', 'ARK', 'ARIZ', 'CALIF', 'COLO', 'CONN', 'DEL', 'FLA', 'GA', 'HAWAII', 'IDAHO', 'ILL', 'IND',
             'IOWA', 'KANS', 'KY', 'LA', 'ME', 'MD', 'MASS', 'MICH', 'MINN', 'MISS', 'MO', 'MONT', 'NEB', 'NEV', 'N H', 'N J', 'N MEX', 'N Y', 'N C', 'N D',
             'OHIO', 'OKLA', 'ORE', 'PA', 'R I', 'S C', 'S D', 'TENN', 'TEX', 'UTAH', 'VT', 'VA', 'WASH', 'W VA', 'WIS', 'WYO']

# do regex search to find any of the state abbreviations and pull all text up to and including state abb
# Regex pattern to match any of the state abbreviations
pattern = fr'(.*?( {"| ".join(state_abb)}))'

# Extract text up to and including the state abbreviation
nonmatch_issuers = nonmatch_issuers.with_columns(
    pl.col("issuer_long_name").str.extract(pattern).alias("seed_issuer")
)


# save those with issuer_short_name null to manually fix
null_short = nonmatch_issuers.filter(pl.col('seed_issuer').is_null())
null_short.write_csv(f'~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/issuer_short_name_null.csv')


# drop nulls and append back with manual fixes
nonmatch_issuers = nonmatch_issuers.filter(pl.col('seed_issuer').is_not_null())
fixes = (pl.read_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/issuer_short_name_null_MANUAL.csv')
         .filter(pl.col('drop').is_null())
         .drop(['drop']))

# append  back
nonmatch_issuers.shape[0] #6,601
nonmatch_issuers = pl.concat([nonmatch_issuers.drop('school'), fixes])
nonmatch_issuers.shape[0] #6,613

# join back to matched issuers
nonmatch_issuers = (nonmatch_issuers
                    .select(['seed_issuer', 'issuer_long_name']))

all_issuers = pl.concat([matched_issuers
                            .with_columns(match_type = pl.lit('nested')),
                         nonmatch_issuers
                         .with_columns(match_type = pl.lit('regex'))])

all_issuers.shape[0] #11,158 # here, drops (43) relative to initial issuers sample are due to dropping duplicates in the nested match (issuers that were matched to multiple seed issuers)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output all seed issuers and identify problematic issuers manually 
What is being dropped:
- some indian tribes
- some issuers that include multiple unique issuers in one issuance 
- state or regional agencies 
- some schools/community colleges that got through filters 
- some airport commissions 
- some fire and rescue, assisted living 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# output all issuers for manual inspection
(all_issuers
      .select('seed_issuer')
      .unique()
      .write_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/all_seed_issuers.csv'))


# reload manual inspection and drop issuers
manual = (pl.read_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/all_seed_issuers_MANUAL.csv')
          .filter(pl.col('drop').is_null()))

# only keep those that were not dropped
all_issuers.shape[0] #11,158
all_issuers['seed_issuer'].n_unique() #7,726
all_issuers = (all_issuers
               .filter(pl.col('seed_issuer').is_in(manual['seed_issuer'])))
all_issuers.shape[0] #11,001
all_issuers['seed_issuer'].n_unique() #7,591

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Create seed issuer id 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
seed_issuers = (all_issuers
                .select(['seed_issuer'])
                .unique()
                .with_row_index('seed_issuer_id'))

all_issuers = (all_issuers
               .join(seed_issuers, on = 'seed_issuer', how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
join with other variables 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

all_issuers = (all_issuers
               .join(issuers, on = 'issuer_long_name', how = 'left'))

# select columns
all_issuers = (all_issuers
               .select(['seed_issuer', 'seed_issuer_id', 'issuer_long_name', 'issuer_name_id', 'school', 'state', 'n_bonds', 'match_type']))


# TOTAL DROPPED
issuers.shape[0] - all_issuers.shape[0] #200

all_issuers.shape[0] #11,001
all_issuers['seed_issuer_id'].n_unique() #7,591


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
all_issuers.write_csv(f'{dta_dir}/241107_city_county_issuernames_with_seed_issuer.csv')