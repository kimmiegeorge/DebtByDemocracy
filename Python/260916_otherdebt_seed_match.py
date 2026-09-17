'''
Match "other debt" issuer names (city bonds that are not GO/revenue, and so were
not run through the original seed-issuer matching process) back to the
seed_issuer identifiers already established for cities in the final
bond-level sample.

Matching approach (mirrors the logic in
"Mergent Issuer Name Cleaning/1. Match City and County Issuers.py"):
 1) Check whether an existing seed_issuer (from the final sample) is a
    leading, word-bounded match of the new issuer_long_name
    (e.g. 'ANDALUSIA ALA' matches 'ANDALUSIA ALA INDL DEV BRD RECOVERY ZONE FAC REV').
 2) For anything not matched in step 1, extract a candidate seed name by
    pulling text up to and including a state abbreviation (same state
    abbreviation list/regex approach used in the original seed-matching
    script), and check whether that candidate coincides with a known
    seed_issuer.
 3) For anything still unmatched, report the closest fuzzy match among known
    seed_issuer values, for manual review (this is NOT auto-accepted).
 4) Generate in_finalsample / drop_notfinalsample indicators marking whether
    the issuer belongs to a city already included in the final bond-level
    sample.

Output is meant for manual review before being merged back in Stata.
'''
#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Set up
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
import re
import difflib
from pathlib import Path
from typing import Optional

import pandas as pd
import polars as pl

MAIN = Path(r'C:\Users\juneh\Dropbox (Personal)\Voting on Bonds')
# MAIN = Path(r'C:\Users\jxh230025\Dropbox\Voting on Bonds')
DATA = MAIN / 'Data'
MERGENT = DATA / 'Mergent'
CLEAN = MERGENT / 'Clean'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# final bond-level sample's issuer-level file: one row per city issuer_long_name,
# with the seed_issuer already assigned during the prior seed-matching process
city_issuers = pl.from_pandas(pd.read_stata(CLEAN / '260716_city_issuerlevel.dta'))

# unique seed issuers already confirmed to be cities in the final sample
seed_lookup = (city_issuers
               .select(['seed_issuer', 'seed_issuer_id', 'state'])
               .unique(subset = ['seed_issuer']))

seed_list = seed_lookup['seed_issuer'].to_list()
seed_set = set(seed_list)
seed_lookup.height, len(seed_set) #5,910

# new issuer names needing a seed match (unmatched, non-GO/rev "other debt" issuers)
otherdebt = pl.read_csv(CLEAN / '260916_otherdebt_issuerforseed.csv')
otherdebt.height #654

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
step 1: token-prefix match against known seed_issuer values
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
def longest_prefix_seed_match(issuer_long_name: str, seeds: set) -> Optional[str]:
    '''
    Find the longest leading run of words in `issuer_long_name` that exactly
    matches a known seed_issuer. This mirrors the nested-containment logic
    used in the original seed-matching scripts, but matches against the
    fixed set of seed issuers already confirmed to be cities in the final
    sample (rather than doing pairwise matching within the new list itself).
    '''
    tokens = issuer_long_name.split(' ')
    for k in range(len(tokens), 0, -1):
        candidate = ' '.join(tokens[:k])
        if candidate in seeds:
            return candidate
    return None

otherdebt = otherdebt.with_columns(
    pl.col('issuer_long_name')
      .map_elements(lambda x: longest_prefix_seed_match(x, seed_set), return_dtype = pl.Utf8)
      .alias('seed_issuer_prefix_match')
)

otherdebt['seed_issuer_prefix_match'].is_not_null().sum()

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
step 2: for anything unmatched in step 1, extract a candidate seed via
state-abbreviation regex (same state abbreviation list used in
"1. Match City and County Issuers.py"), then check if it is a known seed
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
state_abb = ['ALASKA', 'ALA', 'ARK', 'ARIZ', 'CALIF', 'COLO', 'CONN', 'DEL', 'FLA', 'GA', 'HAWAII', 'IDAHO', 'ILL', 'IND',
             'IOWA', 'KANS', 'KY', 'LA', 'ME', 'MD', 'MASS', 'MICH', 'MINN', 'MISS', 'MO', 'MONT', 'NEB', 'NEV', 'N H', 'N J', 'N MEX', 'N Y', 'N C', 'N D',
             'OHIO', 'OKLA', 'ORE', 'PA', 'R I', 'S C', 'S D', 'TENN', 'TEX', 'UTAH', 'VT', 'VA', 'WASH', 'W VA', 'WIS', 'WYO']

# map each abbreviation to its 2-letter postal code, to allow restricting
# fuzzy-match candidates to the correct state
state_abb_to_code = {
    'ALASKA': 'AK', 'ALA': 'AL', 'ARK': 'AR', 'ARIZ': 'AZ', 'CALIF': 'CA', 'COLO': 'CO', 'CONN': 'CT',
    'DEL': 'DE', 'FLA': 'FL', 'GA': 'GA', 'HAWAII': 'HI', 'IDAHO': 'ID', 'ILL': 'IL', 'IND': 'IN',
    'IOWA': 'IA', 'KANS': 'KS', 'KY': 'KY', 'LA': 'LA', 'ME': 'ME', 'MD': 'MD', 'MASS': 'MA', 'MICH': 'MI',
    'MINN': 'MN', 'MISS': 'MS', 'MO': 'MO', 'MONT': 'MT', 'NEB': 'NE', 'NEV': 'NV', 'N H': 'NH', 'N J': 'NJ',
    'N MEX': 'NM', 'N Y': 'NY', 'N C': 'NC', 'N D': 'ND', 'OHIO': 'OH', 'OKLA': 'OK', 'ORE': 'OR', 'PA': 'PA',
    'R I': 'RI', 'S C': 'SC', 'S D': 'SD', 'TENN': 'TN', 'TEX': 'TX', 'UTAH': 'UT', 'VT': 'VT', 'VA': 'VA',
    'WASH': 'WA', 'W VA': 'WV', 'WIS': 'WI', 'WYO': 'WY',
}

# require the abbreviation to be a whole word (followed by a space or end of
# string) to avoid spurious matches like "GA" inside "GAMING"
state_pattern = re.compile(r'(.*? (' + '|'.join(state_abb) + r'))(?=\s|$)')

def extract_regex_seed(issuer_long_name: str) -> Optional[str]:
    m = state_pattern.match(issuer_long_name)
    return m.group(1) if m else None

def extract_regex_state(issuer_long_name: str) -> Optional[str]:
    m = state_pattern.match(issuer_long_name)
    return state_abb_to_code.get(m.group(2)) if m else None

otherdebt = otherdebt.with_columns(
    pl.col('issuer_long_name')
      .map_elements(extract_regex_seed, return_dtype = pl.Utf8)
      .alias('seed_issuer_regex_extract'),
    pl.col('issuer_long_name')
      .map_elements(extract_regex_state, return_dtype = pl.Utf8)
      .alias('state_extracted'),
)

otherdebt = otherdebt.with_columns(
    pl.when(pl.col('seed_issuer_regex_extract').is_in(seed_list))
      .then(pl.col('seed_issuer_regex_extract'))
      .otherwise(None)
      .alias('seed_issuer_regex_match')
)

otherdebt['seed_issuer_regex_match'].is_not_null().sum()

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
step 3: combine into a single matched seed_issuer; for rows that remain
unmatched, surface the closest fuzzy match among known seeds for manual
review (this is a SUGGESTION only, not auto-accepted into seed_issuer)
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
otherdebt = otherdebt.with_columns(
    pl.coalesce(['seed_issuer_prefix_match', 'seed_issuer_regex_match']).alias('seed_issuer')
)

# group known seeds by state so fuzzy suggestions don't cross state lines
# (e.g. avoid suggesting 'BRUNSWICK MO' for 'BRUNSWICK ME')
seeds_by_state: dict = {}
for row in seed_lookup.iter_rows(named = True):
    seeds_by_state.setdefault(row['state'], []).append(row['seed_issuer'])

def closest_seed(candidate: Optional[str], state_code: Optional[str], cutoff: float = 0.85):
    if candidate is None:
        return (None, None)
    pool = seeds_by_state.get(state_code, seed_list) if state_code else seed_list
    matches = difflib.get_close_matches(candidate, pool, n = 1, cutoff = cutoff)
    if not matches:
        return (None, None)
    score = difflib.SequenceMatcher(None, candidate, matches[0]).ratio()
    return (matches[0], round(score, 3))

fuzzy_results = [
    (None, None) if row['seed_issuer'] is not None
    else closest_seed(row['seed_issuer_regex_extract'] or row['issuer_long_name'], row['state_extracted'])
    for row in otherdebt.iter_rows(named = True)
]

otherdebt = otherdebt.with_columns(
    pl.Series('fuzzy_candidate_seed', [f[0] for f in fuzzy_results]),
    pl.Series('fuzzy_score', [f[1] for f in fuzzy_results]),
)

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
step 4: bring in seed_issuer_id/state for matched rows, and build the
in-final-sample indicator
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
otherdebt = otherdebt.join(seed_lookup, on = 'seed_issuer', how = 'left')

otherdebt = otherdebt.with_columns(
    pl.col('seed_issuer').is_not_null().cast(pl.Int8).alias('in_finalsample')
)
otherdebt = otherdebt.with_columns(
    (1 - pl.col('in_finalsample')).alias('drop_notfinalsample')
)

otherdebt['in_finalsample'].value_counts()
#matched to an existing city seed_issuer vs. not; see csv output to review unmatched/fuzzy cases

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output for review
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
otherdebt = otherdebt.rename({'state': 'state_matched'})
otherdebt = otherdebt.select([
    'issuer_long_name', 'seed_issuer', 'seed_issuer_id', 'state_matched',
    'in_finalsample', 'drop_notfinalsample',
    'seed_issuer_prefix_match', 'seed_issuer_regex_extract', 'state_extracted', 'seed_issuer_regex_match',
    'fuzzy_candidate_seed', 'fuzzy_score',
])

otherdebt.write_csv(CLEAN / '260916_otherdebt_issuerforseed_matched.csv')
