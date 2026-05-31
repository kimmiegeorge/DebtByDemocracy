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
           .filter(pl.col('school').eq(1)))
issuers.shape[0] #8,328

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

matched_issuers.shape[0] #486
matched_issuers['seed_issuer'].n_unique() #224

del seed_list, full_list

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output matches for manual inspection
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
matched_issuers.write_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/nested_sch_dist_matches.csv')

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
After manual inspection only keep true matches 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
manual_matched_issuers = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/nested_sch_dist_matches_MANUAL.csv')


seeds = (manual_matched_issuers
         .filter(pl.col('seed_issuer').eq(pl.col('issuer_long_name'))))

manual_matched_issuers = (manual_matched_issuers
                          .filter(pl.col('seed_issuer').ne(pl.col('issuer_long_name'))))

manual_matched_issuers = (manual_matched_issuers
                          .filter(pl.col('Match').eq(1)))
seeds = (seeds
         .filter(pl.col('seed_issuer').is_in(manual_matched_issuers.select('seed_issuer'))))

matched_issuers = pl.concat([seeds, manual_matched_issuers])

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
filter to remaining users not matched in pairwise search
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
match_inner = matched_issuers.select(['seed_issuer'])
match_outer = matched_issuers.select(['issuer_long_name'])

nonmatch_issuers = (issuers
                    .filter((~pl.col('issuer_long_name').is_in(match_inner)))
                    .filter((~pl.col('issuer_long_name').is_in(match_outer))))

nonmatch_issuers.shape[0] #8047


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
for remaining non-matched, check if high % of words are in other issuer names
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

issuer_list = nonmatch_issuers['issuer_long_name'].to_list()
def jaccard_similarity(set1, set2):
    intersection = len(set1.intersection(set2))
    union = len(set1.union(set2))
    return intersection / union if union != 0 else 0

substrings_to_remove = ['SCH DIST', 'SALES TAX REV', 'INFRASTRUCTURE SALES', 'CMNTY UNIT']

# create list of close matches with high % overlap of words
close_matches = []
for s_i in range(0, len(issuer_list)):
    if s_i % 100 == 0:
        print(f'{s_i} out of {len(issuer_list)}')
    issuer_name_i = issuer_list[s_i]
    for sub in substrings_to_remove:
        issuer_name_i = issuer_name_i.replace(sub, '').strip()
    words_i = set(issuer_name_i.split())
    for s_j in range(s_i+1, len(issuer_list)):
        issuer_name_j = issuer_list[s_j]
        for sub in substrings_to_remove:
            issuer_name_j = issuer_name_j.replace(sub, '').strip()
        words_j = set(issuer_name_j.split())
        similarity = jaccard_similarity(words_i, words_j)
        if similarity > 0.75:
            close_matches.append([issuer_list[s_i], issuer_list[s_j], similarity])

close_matches_df = pl.DataFrame({'issuer_long_name': [t[0] for t in close_matches],
                                 'issuer_long_name_match' : [t[1] for t in close_matches],
                                 'similarity': [t[2] for t in close_matches]})

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output matches for manual inspection
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
close_matches_df.write_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/similarity_sch_dist_matches.csv')

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
reload matches after manual inspection
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

manual_close_matches = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Mergent/For Issuer Name Matching/similarity_sch_dist_matches_MANUAL.csv')

manual_close_matches = (manual_close_matches
                        .filter(pl.col('Match').eq(1)))

close_matches = []

for row in manual_close_matches.rows(named = True):
    match_1 = row['issuer_long_name']
    match_2 = row['issuer_long_name_match']

    # check which one is "seed" issuer, and add observations for the match and the seed issuer
    if len(match_1) < len(match_2):
        result1 = [match_1, match_2]
        result2 = [match_1, match_1]

    else:
        result1 = [match_2, match_1]
        result2 = [match_2, match_2]
    close_matches.append(result1)
    close_matches.append(result2)

close_matches_df = pl.DataFrame({'seed_issuer': [t[0] for t in close_matches],
                                 'issuer_long_name': [t[1] for t in close_matches]})

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
get remaining non-matched issuers and prep them for addition to final df 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

nonmatch_issuers = (nonmatch_issuers
                    .filter((~pl.col('issuer_long_name').is_in(close_matches_df.select(['issuer_long_name'])))))

nonmatch_issuers.shape[0] #8021

nonmatch_issuers = (nonmatch_issuers
                    .with_columns(seed_issuer = pl.col('issuer_long_name'))
                    .select(['seed_issuer', 'issuer_long_name']))


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
final df 
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
all_matches = pl.concat([matched_issuers
                         .select(['seed_issuer', 'issuer_long_name']),
                         close_matches_df
                         .select(['seed_issuer', 'issuer_long_name']),
                         nonmatch_issuers])

# join with needed issuer data
all_matches = (all_matches
               .join(issuers
                     .select(['issuer_long_name', 'state', 'issuer_name_id', 'school', 'n_bonds']),
                     on = 'issuer_long_name', how = 'left'))

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
all_matches.write_csv(f'{dta_dir}/241108_sch_dist_issuernames_with_seed_issuer.csv')