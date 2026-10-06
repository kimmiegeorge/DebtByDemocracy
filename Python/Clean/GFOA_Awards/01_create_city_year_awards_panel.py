"""Build the balanced FY2014--2020 GO-city GFOA award panel.

Only unique exact normalized name/state matches count as awards. Approximate
matches are exported for review. COA nonmatches, including FY2019, are coded zero.
"""
#%% Paths and shared policy definitions
import os
import re
import unicodedata
from pathlib import Path

import polars as pl
import pyreadstat
from rapidfuzz.distance import Levenshtein

code_dir = Path(__file__).resolve().parents[3]
root = code_dir.parent
data_dir = root / 'Data'
output_dir = Path(os.getenv(
    'GFOA_ANALYSIS_DIR', str(data_dir / 'GFOA Awards/analysis/city_year_pafr')
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)
bond_file = data_dir / 'Mergent/Clean/260917_city_cusiplevel_finsample_allbonds.dta'
bond_policy_file = data_dir / 'Mergent/Clean/260611_city_issuerlevel.dta'
award_file = data_dir / 'GFOA Awards/processed/gfoa_award_observations_long.csv'
bea_file = data_dir / 'BEA/countydemos_1999_2026.dta'
state_policy_file = data_dir / 'State Policies/20260929_state_policy_comparison.csv'
monitor_file = data_dir / 'State Monitoring Policy/state_enforcement_adoption_years.csv'
debt_file = data_dir / 'Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv'

# Read the canonical R state lists so both pipelines use the same definitions.
supermajority_text = (code_dir / 'R/Clean/00_state_policy_definitions.R').read_text()
supermajority_states = re.findall(r"'([A-Z]{2})'", supermajority_text)
privilege_text = (code_dir / 'R/Clean/00_tax_privilege_definitions.R').read_text()
low_privilege_states = re.findall(r"'([A-Z]{2})'", privilege_text)

#%% Name and source-field normalization
# Strip Mergent suffixes only when they belong to the issuer's actual state.
state_suffix_aliases = {'AL': ['AL', 'ALA', 'ALABAMA'],
 'AK': ['AK', 'ALASKA'],
 'AZ': ['AZ', 'ARIZ', 'ARIZONA'],
 'AR': ['AR', 'ARK', 'ARKANSAS'],
 'CA': ['CA', 'CAL', 'CALIF', 'CALIFORNIA'],
 'CO': ['CO', 'COLO', 'COLORADO'],
 'CT': ['CT', 'CONN', 'CONNECTICUT'],
 'DE': ['DE', 'DEL', 'DELAWARE'],
 'FL': ['FL', 'FLA', 'FLORIDA'],
 'GA': ['GA', 'GEORGIA'],
 'HI': ['HI', 'HAW', 'HAWAII'],
 'ID': ['ID', 'IDAHO'],
 'IL': ['IL', 'ILL', 'ILLINOIS'],
 'IN': ['IN', 'IND', 'INDIANA'],
 'IA': ['IA', 'IOWA'],
 'KS': ['KS', 'KANS', 'KANSAS'],
 'KY': ['KY', 'KENTUCKY'],
 'LA': ['LA', 'LOUISIANA'],
 'ME': ['ME', 'MAINE'],
 'MD': ['MD', 'MARYLAND'],
 'MA': ['MA', 'MASS', 'MASSACHUSETTS'],
 'MI': ['MI', 'MICH', 'MICHIGAN'],
 'MN': ['MN', 'MINN', 'MINNESOTA'],
 'MS': ['MS', 'MISS', 'MISSISSIPPI'],
 'MO': ['MO', 'MISSOURI'],
 'MT': ['MT', 'MONT', 'MONTANA'],
 'NE': ['NE', 'NEBR', 'NEBRASKA'],
 'NV': ['NV', 'NEV', 'NEVADA'],
 'NH': ['NH', 'N H', 'NEW HAMPSHIRE'],
 'NJ': ['NJ', 'N J', 'NEW JERSEY'],
 'NM': ['NM', 'N M', 'NEW MEXICO'],
 'NY': ['NY', 'N Y', 'NEW YORK'],
 'NC': ['NC', 'N C', 'NORTH CAROLINA'],
 'ND': ['ND', 'N D', 'NORTH DAKOTA'],
 'OH': ['OH', 'OHIO'],
 'OK': ['OK', 'OKLA', 'OKLAHOMA'],
 'OR': ['OR', 'ORE', 'OREGON'],
 'PA': ['PA', 'PENN', 'PENNSYLVANIA'],
 'RI': ['RI', 'R I', 'RHODE ISLAND'],
 'SC': ['SC', 'S C', 'SOUTH CAROLINA'],
 'SD': ['SD', 'S D', 'SOUTH DAKOTA'],
 'TN': ['TN', 'TENN', 'TENNESSEE'],
 'TX': ['TX', 'TEX', 'TEXAS'],
 'UT': ['UT', 'UTAH'],
 'VT': ['VT', 'VERMONT'],
 'VA': ['VA', 'VIRGINIA'],
 'WA': ['WA', 'WASH', 'WASHINGTON'],
 'WV': ['WV', 'W V', 'WEST VIRGINIA'],
 'WI': ['WI', 'WIS', 'WISCONSIN'],
 'WY': ['WY', 'WYO', 'WYOMING']}


def normalize_city_name(name, state=None, strip_state_suffix=False):
    # Preserve the original macOS R iconv accent separators (Cañon -> CA NON).
    # Its transliteration inserts an accent marker before the base character.
    letters = []
    for character in name:
        decomposed = unicodedata.normalize('NFKD', character)
        ascii_character = decomposed.encode('ascii', 'ignore').decode()
        if any(unicodedata.combining(part) for part in decomposed):
            ascii_character = ' ' + ascii_character
        letters.append(ascii_character)
    name = ''.join(letters)
    name = re.sub(r'[^A-Z0-9]+', ' ', name.upper()).strip()
    if strip_state_suffix:
        for alias in sorted(state_suffix_aliases.get(state, []), key=len, reverse=True):
            if name != alias and name.endswith(' ' + alias):
                name = name[:-len(alias)].strip()
                break
    name = re.sub(r'\b(THE|CITY|TOWN|VILLAGE|BOROUGH|MUNICIPALITY|OF|GOVERNMENT|METROPOLITAN|MUNICIPAL|CORPORATION|AND)\b', ' ', name)
    return re.sub(r' +', ' ', name).strip()


def as_binary(column):
    text = pl.col(column).cast(pl.String).str.strip_chars().str.to_uppercase()
    return pl.when(text.is_null() | text.is_in(['', 'NA', 'N/A'])).then(None).otherwise(
        text.is_in(['1', '1.0', 'YES', 'Y', 'TRUE', '✓']).cast(pl.Int64)
    ).alias(column)


#%% GO-city universe and fixed attributes
# pyreadstat only decodes Stata; all dataframe transformations use Polars.
bond_data_raw, _ = pyreadstat.read_dta(bond_file, usecols=[
    'seed_issuer', 'seed_issuer_id', 'issuer_long_name', 'state', 'year',
    'fips', 'finsample', 'go_unlim', 'go_lim', 'city_go_vote', 'city_rev_vote'
], output_format='dict')
bond_data = pl.DataFrame(bond_data_raw).with_columns(
    pl.col('seed_issuer_id').map_elements(lambda value: f'{value:.1f}', return_dtype=pl.String).alias('city_id'),
    pl.col('fips').cast(pl.Int64, strict=False).cast(pl.String).str.pad_start(5, '0'),
    as_binary('city_go_vote'), as_binary('city_rev_vote')
)
bonds = bond_data.filter(
    pl.col('finsample') == 1,
    (pl.col('go_unlim') == 1) | (pl.col('go_lim') == 1),
    pl.col('seed_issuer_id').is_not_null()
)
# Sorting modal ties reproduces R table()'s alphabetical tie breaking.
city_attributes = ['state', 'seed_issuer', 'issuer_long_name', 'fips', 'city_go_vote', 'city_rev_vote']
city_universe = bonds.group_by('city_id').agg([
    pl.col(column).filter(pl.col(column).is_not_null() & (pl.col(column).cast(pl.String) != ''))
    .mode().sort().first().alias(column) for column in city_attributes
]).sort('city_id').with_columns(
    pl.struct('seed_issuer', 'state').map_elements(
        lambda row: normalize_city_name(row['seed_issuer'], row['state'], True),
        return_dtype=pl.String
    ).alias('city_name_normalized')
)
city_fips_conflicts = bonds.select('city_id', 'fips').unique().group_by('city_id').len(name='n_fips').filter(pl.col('n_fips') > 1)
city_fips_conflicts.write_csv(output_dir / 'city_fips_conflicts.csv')

#%% State bond policies and additional state controls
bond_policy_raw, _ = pyreadstat.read_dta(bond_policy_file, usecols=[
    'state', 'state_go_vote', 'state_utgo_allowed', 'glm_proactive'
], output_format='dict')
bond_policy = pl.DataFrame(bond_policy_raw).unique()
state_bond_policy = bond_policy.group_by('state').agg([
    pl.col(column).drop_nulls().mode().sort().first().cast(pl.Int64).alias(column)
    for column in ['state_go_vote', 'state_utgo_allowed', 'glm_proactive']
])
state_policy_raw = pl.read_csv(state_policy_file, infer_schema_length=10000, null_values=['NA'])
state_policy_vars = [
    'state_abbr', 'municipal_debt_limit', 'strict_municipal_debt_limit',
    'debt_limit_can_be_exceeded', 'debt_limit_exempts_revenue_bonds',
    'debt_limit_vote_to_exceed', 'debt_limit_voter_override',
    'lincoln_property_tax_levy_cap_2024', 'lincoln_property_tax_rate_cap_2024',
    'lincoln_truth_in_taxation_2024', 'lincoln_broad_municipal_budget_limit_2022',
    'municipal_tel_any_2012', 'municipal_tel_index',
    'state_fiscal_monitor_2017', 'state_fiscal_monitor_2020',
    'gasb_municipal_gaap_required_any', 'nasact_audits_cities_towns_villages',
    'go_vote_required'
]
state_policy = state_policy_raw.select(state_policy_vars).rename({'state_abbr': 'state'}).with_columns(
    *[as_binary(column) for column in state_policy_vars if column not in ['state_abbr', 'municipal_tel_index']],
    pl.col('municipal_tel_index').cast(pl.Float64, strict=False),
    pl.col('state').is_in(supermajority_states).cast(pl.Int64).alias('supermajority'),
    pl.col('state').is_in(low_privilege_states).cast(pl.Int64).alias('low_state_tax_privilege')
)
state_lookup = pl.concat([
    state_policy_raw.select(pl.col('state_abbr').alias('state'), pl.col('state_name').str.to_uppercase().alias('state_lookup_key')),
    state_policy_raw.select(pl.col('state_abbr').alias('state'), pl.col('state_abbr').alias('state_lookup_key')),
    pl.DataFrame({'state': ['DC', 'DC'], 'state_lookup_key': ['DISTRICT OF COLUMBIA', 'WASHINGTON, DC']})
]).unique(subset='state_lookup_key', keep='first', maintain_order=True)

#%% Eligible awards and conservative exact matches
award_raw = pl.read_csv(award_file, infer_schema_length=10000, null_values=['NA'], schema_overrides={'gfoa_recipient_id': pl.Float64}).filter(
    pl.col('award_program').is_in(['COA', 'PAFR'])
).with_columns(pl.col('fiscal_year').cast(pl.Int64))
panel_years = sorted(set(range(int(bonds['year'].min()), int(bonds['year'].max()) + 1)).intersection(
    award_raw.filter(pl.col('award_program') == 'PAFR')['fiscal_year'].to_list()
))
if panel_years != list(range(2014, 2021)):
    raise ValueError(f'Unexpected PAFR/bond overlap: {panel_years}')
noncity_pattern = r'(?i)\b(COUNTY|SCHOOL|DISTRICT|RETIREMENT|PENSION|AUTHORITY|COMMISSION|UNIVERSITY|COLLEGE|FUND|SYSTEM|BOARD|AGENCY|TOWNSHIP|UTILITY|UTILITIES|AIRPORT|HOUSING|WATER|SEWER|FIRE|LIBRARY|HOSPITAL|TRANSIT)\b'
award_eligible = award_raw.filter(pl.col('fiscal_year').is_in(panel_years)).with_columns(
    pl.col('state_raw').str.to_uppercase().alias('state_lookup_key'),
    pl.col('recipient_name_raw').map_elements(normalize_city_name, return_dtype=pl.String).alias('recipient_name_normalized'),
    (~pl.col('recipient_name_raw').str.contains(noncity_pattern) &
     (pl.col('government_type').is_in(['MS', 'Municipality', '']) | pl.col('government_type').is_null())).alias('city_eligible')
).join(state_lookup, on='state_lookup_key', how='left', validate='m:1').filter(
    pl.col('city_eligible'), pl.col('state').is_not_null(), pl.col('recipient_name_normalized') != ''
)
city_keys = city_universe.with_columns(pl.len().over('state', 'city_name_normalized').alias('n_city_key'))
unique_city_keys = city_keys.filter(pl.col('n_city_key') == 1).select(
    'state', pl.col('city_name_normalized').alias('recipient_name_normalized'), 'city_id'
)
award_matches = award_eligible.join(unique_city_keys, on=['state', 'recipient_name_normalized'], validate='m:1').select(
    'award_program', 'city_id', 'fiscal_year', 'recipient_name_raw', 'state_raw',
    'government_type', 'gfoa_recipient_id', 'document_url',
    pl.lit('exact_normalized_state_name').alias('match_method')
).unique(maintain_order=True)
pafr_matches = award_matches.filter(pl.col('award_program') == 'PAFR').drop('award_program').rename({
    column: 'pafr_' + column for column in ['recipient_name_raw', 'state_raw', 'government_type', 'gfoa_recipient_id', 'document_url']
})
coa_matches = award_matches.filter(pl.col('award_program') == 'COA').drop('award_program').rename({
    column: 'coa_' + column for column in ['recipient_name_raw', 'state_raw', 'government_type', 'gfoa_recipient_id', 'document_url']
})
pafr_matches.write_csv(output_dir / 'pafr_exact_matches.csv')
coa_matches.write_csv(output_dir / 'coa_exact_matches.csv')

#%% Unmatched recipient review: three nearest same-state GO cities
# Review candidates never enter the award indicators. Stable ties follow the
# city_id ordering used by the original R city universe.
recipient_keys = ['award_program', 'fiscal_year', 'recipient_name_raw', 'state_raw']
award_unmatched = award_eligible.join(award_matches.select(recipient_keys).unique(), on=recipient_keys, how='anti')
cities_by_state = {state[0]: cities.to_dicts() for state, cities in city_universe.partition_by('state', as_dict=True).items()}
candidate_rows = []
for recipient in award_unmatched.iter_rows(named=True):
    candidates = cities_by_state.get(recipient['state'], [])
    nearest = sorted(candidates, key=lambda city: Levenshtein.distance(recipient['recipient_name_normalized'], city['city_name_normalized']))[:3]
    for city in nearest:
        candidate_rows.append({
            **{column: recipient[column] for column in ['award_program', 'fiscal_year', 'state', 'recipient_name_raw', 'recipient_name_normalized', 'government_type']},
            'city_id_candidate': city['city_id'], 'seed_issuer_candidate': city['seed_issuer'],
            'candidate_normalized': city['city_name_normalized'],
            'edit_distance': Levenshtein.distance(recipient['recipient_name_normalized'], city['city_name_normalized'])
        })
approximate_candidates = pl.DataFrame(candidate_rows)
approximate_candidates.write_csv(output_dir / 'gfoa_award_unmatched_candidate_review.csv')
approximate_candidates.filter(pl.col('award_program') == 'PAFR').drop('award_program').write_csv(output_dir / 'pafr_unmatched_candidate_review.csv')
approximate_candidates.filter(pl.col('award_program') == 'COA').drop('award_program').write_csv(output_dir / 'coa_unmatched_candidate_review.csv')

#%% Balanced city-year panel; code all nonmatches zero and retain coverage flags
panel = city_universe.join(pl.DataFrame({'fiscal_year': panel_years}), how='cross').select(
    'city_id', 'fiscal_year', pl.exclude('city_id', 'fiscal_year')
).join(coa_matches.select('city_id', 'fiscal_year').unique().with_columns(pl.lit(1).alias('coa_award')),
       on=['city_id', 'fiscal_year'], how='left', validate='1:1').join(
    pafr_matches.select('city_id', 'fiscal_year').unique().with_columns(pl.lit(1).alias('pafr_award')),
    on=['city_id', 'fiscal_year'], how='left', validate='1:1'
).with_columns(
    pl.col('coa_award').fill_null(0),
    pl.when(pl.col('fiscal_year') == 2019).then(pl.lit('partial_public_GFOA_coverage_archive_AMS_transition')).otherwise(pl.lit('public_GFOA_source_collected')).alias('coa_award_coverage'),
    pl.col('pafr_award').fill_null(0)
).with_columns(
    pl.when((pl.col('pafr_award') == 1) | (pl.col('coa_award') == 1)).then(1)
    .when(pl.col('coa_award').is_null()).then(None).otherwise(0).alias('either_gfoa_award')
).join(state_bond_policy, on='state', how='left', validate='m:1').join(state_policy, on='state', how='left', validate='m:1')

#%% Adoption-year monitoring and preceding year-end outstanding debt
monitor_adoption = pl.read_csv(monitor_file).select(
    pl.col('Abbreviation').alias('state'),
    pl.col('AdoptionYear').replace('before_sample', '2009').cast(pl.Int64).alias('fiscal_monitor_adoption_year')
)
panel = panel.join(monitor_adoption, on='state', how='left', validate='m:1').with_columns(
    (pl.col('fiscal_year') >= pl.col('fiscal_monitor_adoption_year')).fill_null(False).cast(pl.Int64).alias('state_monitor'),
    pl.concat_str([
        (pl.col('city_id').cast(pl.Float64) * 10).round().cast(pl.Int64).cast(pl.String),
        pl.col('state').str.strip_chars().str.to_uppercase(),
        pl.col('seed_issuer').str.strip_chars().str.replace_all(r'\s+', ' ').str.to_uppercase()
    ], separator='|').alias('issuer_key')
)
debt_controls = pl.read_csv(debt_file).select(
    'issuer_key', (pl.col('year') + 1).alias('fiscal_year'),
    pl.col('total_outstanding_debt').alias('total_outstanding_debt_lag1'),
    pl.col('ln_1p_total_outstanding_debt').alias('ln_1p_outstanding_debt_lag1')
)
panel = panel.join(debt_controls, on=['issuer_key', 'fiscal_year'], how='left', validate='m:1')
if panel['ln_1p_outstanding_debt_lag1'].null_count():
    raise ValueError('Shared debt panel is missing award issuer-years.')

#%% Annual financial-sample bond issuance controls
bond_issuance = bond_data.filter(pl.col('finsample') == 1, pl.col('city_id').is_not_null()).select(
    'city_id', pl.col('year').cast(pl.Int64).alias('fiscal_year')
).filter(pl.col('fiscal_year').is_in(panel_years)).unique().with_columns(pl.lit(1).alias('bond_issued_current_year'))
panel = panel.join(bond_issuance, on=['city_id', 'fiscal_year'], how='left', validate='1:1').with_columns(
    pl.col('bond_issued_current_year').fill_null(0)
).sort('city_id', 'fiscal_year').with_columns(
    ((pl.col('bond_issued_current_year') == 1) |
     (pl.col('bond_issued_current_year').shift(1).over('city_id').fill_null(0) == 1))
    .cast(pl.Int64).alias('bond_issued_current_or_prior_year')
)

#%% County BEA controls at t-1 and final panel
bea_raw, _ = pyreadstat.read_dta(bea_file, usecols=[
    'fips', 'year', 'employment', 'gdp', 'percap_inc', 'pers_inc', 'pop'
], output_format='dict')
county_controls = pl.DataFrame(bea_raw).select(
    pl.col('fips').cast(pl.Int64, strict=False).cast(pl.String).str.pad_start(5, '0'),
    (pl.col('year').cast(pl.Int64) + 1).alias('fiscal_year'),
    *[pl.col(column).cast(pl.Float64).alias('county_' + column + '_l1')
      for column in ['employment', 'gdp', 'percap_inc', 'pers_inc', 'pop']]
).unique(subset=['fips', 'fiscal_year'], keep='first', maintain_order=True)
panel = panel.join(county_controls, on=['fips', 'fiscal_year'], how='left', validate='m:1').with_columns(
    *[pl.col('county_' + column + '_l1').log1p().alias('ln_county_' + column + '_l1')
      for column in ['employment', 'gdp', 'pers_inc', 'pop']],
    pl.col('county_percap_inc_l1').log().alias('ln_county_percap_inc_l1')
).sort('fiscal_year', 'state', 'seed_issuer')
if panel.select('city_id', 'fiscal_year').is_duplicated().any():
    raise ValueError('Final panel is not unique by city-year.')
panel.write_csv(output_dir / 'city_year_gfoa_awards_panel.csv')

#%% Regression-ready data: retain the existing R sample and missing indicators
regression_data = panel.filter(
    pl.col('pafr_award').is_not_null(), pl.col('city_go_vote').is_not_null(),
    pl.col('fiscal_year').is_not_null(), pl.col('state').is_not_null()
).with_columns(
    *[pl.col(column).is_null().cast(pl.Int64).alias(column + '_source_missing')
      for column in ['city_rev_vote', 'municipal_debt_limit', 'nasact_audits_cities_towns_villages']]
).with_columns(
    *[pl.col(column).fill_null(0) for column in ['city_rev_vote', 'municipal_debt_limit', 'nasact_audits_cities_towns_villages']]
)
regression_data.write_csv(output_dir / 'city_year_gfoa_awards_regression_data.csv')

#%% Build diagnostics and matching documentation
pl.DataFrame({
    'metric': ['GO-city universe', 'City-years', 'Eligible COA recipient-year records',
               'Accepted exact COA matches', 'COA-positive city-years',
               'Eligible PAFR recipient-year records', 'Accepted exact PAFR matches',
               'PAFR-positive city-years', 'FY range'],
    'value': [str(city_universe.height), str(panel.height),
              str(award_eligible.filter(pl.col('award_program') == 'COA').height), str(coa_matches.height), str(panel['coa_award'].sum()),
              str(award_eligible.filter(pl.col('award_program') == 'PAFR').height), str(pafr_matches.height), str(panel['pafr_award'].sum()),
              f'{panel_years[0]}-{panel_years[-1]}']
}).write_csv(output_dir / 'build_diagnostics.csv')
(output_dir / 'README.txt').write_text("""City-year GFOA award panel build

Built by Code/Python/Clean/GFOA_Awards/01_create_city_year_awards_panel.py.
The primary panel is city_year_gfoa_awards_panel.csv, with COA, PAFR, and either-award outcomes.
A positive is a unique exact normalized name/state match in the GO-city universe.
COA nonmatches, including FY2019, are coded zero. The FY2019 partial archive/AMS coverage flag is retained.
Fiscal years are 2014--2020, the overlapping PAFR archive and financial-sample bond years.
Bond indicators identify issuance in t or t/t-1; the initial panel year follows the original build's zero prior-year default.
County BEA controls and shared Mergent outstanding debt are merged at t-1.
state_monitor turns on in the adoption year; before_sample is coded 2009; unlisted states are zero.
Dated policy snapshots and original source missing values remain in the primary panel.
city_year_gfoa_awards_regression_data.csv applies the existing regression sample and source-missing indicators.
Unmatched same-state candidates are exported for review and never coded as positives.
R/Clean/01b_gfoa_awards.R writes tables under RESULTS_DIR.
""")
print(f'Wrote {panel.height:,} city-years and {regression_data.height:,} regression rows to {output_dir}')
