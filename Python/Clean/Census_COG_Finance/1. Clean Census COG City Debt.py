'''
Clean Census of Governments municipal debt files

This script uses the individual-unit public-use files for Census of Governments
years. It filters to municipal governments, extracts debt items, merges in
population and identifiers from the PID/GID directory file, and creates a panel
that can be used for reviewer-response balance checks.

The Mergent "city" issuer-level file includes cities, towns, villages, and
townships. Census classifies many towns/townships as type 3 rather than type 2,
so the mergeable municipal sample keeps both:
    2 = City
    3 = Township

It also creates a first-pass merge diagnostic against the Mergent issuer-level
debt choice file. The merge diagnostic is intentionally conservative: exact
matches are attempted on normalized city name within state-county, then within
state. A fuzzy candidate file is written for unmatched issuers.
'''

#%% -----------------------------------------------------------------------
# set up
# -----------------------------------------------------------------------
import difflib
import os
import re
import zipfile
from pathlib import Path

import polars as pl

try:
    import pandas as pd
except ImportError:
    pd = None


root = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
data_dir = root / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
census_dir = data_dir / 'Census COG Finance'
raw_dir = census_dir / 'raw'
clean_census_dir = clean_data_dir / 'Census COG Finance'
processed_dir = clean_census_dir / 'processed'
diagnostics_dir = clean_census_dir / 'diagnostics'

processed_dir.mkdir(parents=True, exist_ok=True)
diagnostics_dir.mkdir(parents=True, exist_ok=True)

mergent_bond_file = data_dir / 'Mergent' / 'Clean' / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'

cog_years = {
    2012: {
        'zip': raw_dir / '2012_Individual_Unit_file.zip',
        'pid_pattern': r'Fin_GID_2012\.txt$',
        'finance_pattern': r'2012FinEstDAT_.*_pu\.txt$',
        'id_len': 14,
        'pid_slices': {
            'name': (14, 78),
            'county_name': (78, 113),
            'county_fips': (113, 118),
            'place_fips': (118, 123),
            'population': (123, 132),
            'population_year': (132, 134),
            'enrollment': (134, 141),
            'enrollment_year': (141, 143),
            'special_district_function': (143, 145),
            'school_level': (145, 147),
            'fiscal_year_ending': (147, 151),
            'survey_year': (151, 153),
        },
        'finance_slices': {
            'item_code': (14, 17),
            'amount': (17, 29),
            'data_year': (29, 33),
            'data_flag': (33, 34),
        },
    },
    2017: {
        'zip': raw_dir / '2017_Individual_Unit_File.zip',
        'pid_pattern': r'Fin_PID_2017\.txt$',
        'finance_pattern': r'2017FinEstDAT_.*_pu\.txt$',
        'id_len': 12,
    },
    2022: {
        'zip': raw_dir / '2022_Individual_Unit_File.zip',
        'pid_pattern': r'Fin_PID_2022\.txt$',
        'finance_pattern': r'2022FinEstDAT_.*_pu\.txt$',
        'id_len': 12,
    },
}

default_pid_slices = {
    'name': (12, 76),
    'county_name': (76, 111),
    'place_fips': (111, 116),
    'population': (116, 125),
    'population_year': (125, 127),
    'enrollment': (127, 134),
    'enrollment_year': (134, 136),
    'special_district_function': (136, 138),
    'school_level': (138, 140),
    'fiscal_year_ending': (140, 144),
    'survey_year': (144, 146),
}

default_finance_slices = {
    'item_code': (12, 15),
    'amount': (15, 27),
    'data_year': (27, 31),
    'data_flag': (31, 32),
}

pid_schema = {
    'year': pl.Int64,
    'gov_id': pl.Utf8,
    'state_fips': pl.Utf8,
    'government_type': pl.Utf8,
    'county_fips3': pl.Utf8,
    'unit_id': pl.Utf8,
    'census_name': pl.Utf8,
    'county_name': pl.Utf8,
    'place_fips': pl.Utf8,
    'population': pl.Int64,
    'population_year': pl.Utf8,
    'enrollment': pl.Int64,
    'enrollment_year': pl.Utf8,
    'special_district_function': pl.Utf8,
    'school_level': pl.Utf8,
    'fiscal_year_ending': pl.Utf8,
    'survey_year': pl.Utf8,
}

finance_schema = {
    'year': pl.Int64,
    'gov_id': pl.Utf8,
    'item_code': pl.Utf8,
    'amount_thousands': pl.Int64,
    'data_year': pl.Int64,
    'data_flag': pl.Utf8,
}

debt_items = {
    '19U': 'begin_lt_debt_outstanding',
    '29U': 'lt_debt_issued',
    '39U': 'lt_debt_retired',
    '49U': 'end_lt_debt_outstanding',
    '61V': 'begin_short_term_debt_outstanding',
    '64V': 'end_short_term_debt_outstanding',
}

municipal_government_types = ['2', '3']
local_nonmunicipal_government_types = ['1', '4', '5']

government_type_labels = {
    '0': 'state',
    '1': 'county',
    '2': 'city',
    '3': 'township',
    '4': 'special_district',
    '5': 'school_district',
}

state_fips_to_abbr = {
    '01': 'AL', '02': 'AK', '04': 'AZ', '05': 'AR', '06': 'CA',
    '08': 'CO', '09': 'CT', '10': 'DE', '11': 'DC', '12': 'FL',
    '13': 'GA', '15': 'HI', '16': 'ID', '17': 'IL', '18': 'IN',
    '19': 'IA', '20': 'KS', '21': 'KY', '22': 'LA', '23': 'ME',
    '24': 'MD', '25': 'MA', '26': 'MI', '27': 'MN', '28': 'MS',
    '29': 'MO', '30': 'MT', '31': 'NE', '32': 'NV', '33': 'NH',
    '34': 'NJ', '35': 'NM', '36': 'NY', '37': 'NC', '38': 'ND',
    '39': 'OH', '40': 'OK', '41': 'OR', '42': 'PA', '44': 'RI',
    '45': 'SC', '46': 'SD', '47': 'TN', '48': 'TX', '49': 'UT',
    '50': 'VT', '51': 'VA', '53': 'WA', '54': 'WV', '55': 'WI',
    '56': 'WY',
}

state_abbr_to_fips = {abbr: fips for fips, abbr in state_fips_to_abbr.items()}

state_suffixes = {
    'AL': ['AL', 'ALA', 'ALABAMA'],
    'AK': ['AK', 'ALASKA'],
    'AZ': ['AZ', 'ARIZ', 'ARIZONA'],
    'AR': ['AR', 'ARK', 'ARKANSAS'],
    'CA': ['CA', 'CAL', 'CALIF', 'CALIFORNIA'],
    'CO': ['CO', 'COLO', 'COLORADO'],
    'CT': ['CT', 'CONN', 'CONNECTICUT'],
    'DE': ['DE', 'DEL', 'DELAWARE'],
    'DC': ['DC', 'D C', 'DISTRICT OF COLUMBIA'],
    'FL': ['FL', 'FLA', 'FLORIDA'],
    'GA': ['GA', 'GEORGIA'],
    'HI': ['HI', 'HAWAII'],
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
    'NE': ['NE', 'NEB', 'NEBR', 'NEBRASKA'],
    'NV': ['NV', 'NEV', 'NEVADA'],
    'NH': ['NH', 'N H', 'NEW HAMPSHIRE'],
    'NJ': ['NJ', 'N J', 'NEW JERSEY'],
    'NM': ['NM', 'N M', 'N MEX', 'NEW MEXICO'],
    'NY': ['NY', 'N Y', 'NEW YORK'],
    'NC': ['NC', 'N C', 'N CAR', 'NORTH CAROLINA'],
    'ND': ['ND', 'N D', 'N DAK', 'NORTH DAKOTA'],
    'OH': ['OH', 'OHIO'],
    'OK': ['OK', 'OKLA', 'OKLAHOMA'],
    'OR': ['OR', 'ORE', 'OREGON'],
    'PA': ['PA', 'PENN', 'PENNA', 'PENNSYLVANIA'],
    'RI': ['RI', 'R I', 'RHODE ISLAND'],
    'SC': ['SC', 'S C', 'S CAR', 'SOUTH CAROLINA'],
    'SD': ['SD', 'S D', 'S DAK', 'SOUTH DAKOTA'],
    'TN': ['TN', 'TENN', 'TENNESSEE'],
    'TX': ['TX', 'TEX', 'TEXAS'],
    'UT': ['UT', 'UTAH'],
    'VT': ['VT', 'VERMONT'],
    'VA': ['VA', 'VIRGINIA'],
    'WA': ['WA', 'WASH', 'WASHINGTON'],
    'WV': ['WV', 'W VA', 'WEST VIRGINIA'],
    'WI': ['WI', 'WIS', 'WISC', 'WISCONSIN'],
    'WY': ['WY', 'WYO', 'WYOMING'],
}


#%% -----------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------
def find_zip_member(zip_path, pattern):
    regex = re.compile(pattern)
    with zipfile.ZipFile(zip_path) as zf:
        matches = [name for name in zf.namelist() if regex.search(name)]

    if not matches:
        raise FileNotFoundError(f'No member matching {pattern} in {zip_path}')

    return sorted(matches)[-1]


def clean_number(value):
    value = str(value).strip()
    if value == '':
        return None
    try:
        return int(value)
    except ValueError:
        return None


def normalize_city_name(value):
    if value is None:
        return None

    text = str(value).upper()
    text = text.replace('&', ' AND ')
    text = re.sub(r'[^A-Z0-9 ]+', ' ', text)
    text = re.sub(r'\b(CITY OF|TOWN OF|VILLAGE OF|BOROUGH OF)\b', ' ', text)
    text = re.sub(
        r'\b(CITY|TOWN|TWP|TOWNSHIP|VILLAGE|VLG|BOROUGH|BORO|MUNICIPALITY|MUNICIPAL|CORP|CORPORATION|'
        r'GOVT|GOVERNMENT|AUTHORITY|PUBLIC|FINANCE|BUILDING|CORP)\b',
        ' ',
        text,
    )
    text = re.sub(r'\s+', ' ', text).strip()

    return text if text else None


def normalize_issuer_name(value, state):
    text = normalize_city_name(value)
    if text is None:
        return None

    state = str(state).upper().strip()
    for suffix in state_suffixes.get(state, [state]):
        new_text = re.sub(rf'\b{re.escape(suffix)}\b$', '', text).strip()
        if new_text != text:
            text = new_text
            break

    # Common name abbreviations in Mergent issuer strings.
    text = re.sub(r'\bMT\b', 'MOUNT', text)
    text = re.sub(r'\bFT\b', 'FORT', text)
    if state != 'LA':
        text = re.sub(r'\bLA\b$', 'LAKE', text)

    return re.sub(r'\s+', ' ', text).strip() or None


def read_pid_file(zip_path, member, year, config):
    id_len = config['id_len']
    slices = default_pid_slices | config.get('pid_slices', {})
    records = []
    with zipfile.ZipFile(zip_path) as zf:
        with zf.open(member) as fh:
            for raw in fh:
                line = raw.decode('latin1').rstrip('\n')
                line = line.rstrip('\r')
                max_stop = max(stop for _, stop in slices.values())
                if len(line) < max_stop:
                    line = line.ljust(max_stop)

                gov_id = line[0:id_len]
                if len(gov_id) != id_len:
                    continue

                county_fips_full = (
                    line[slices['county_fips'][0]:slices['county_fips'][1]].strip()
                    if 'county_fips' in slices
                    else None
                )
                state_fips = (
                    county_fips_full[0:2]
                    if county_fips_full
                    else gov_id[0:2]
                )

                records.append(
                    {
                        'year': year,
                        'gov_id': gov_id,
                        'state_fips': state_fips,
                        'government_type': gov_id[2:3],
                        'county_fips3': (
                            county_fips_full[2:5]
                            if county_fips_full
                            else gov_id[3:6]
                        ),
                        'unit_id': gov_id[6:id_len],
                        'census_name': line[slices['name'][0]:slices['name'][1]].strip(),
                        'county_name': line[slices['county_name'][0]:slices['county_name'][1]].strip(),
                        'place_fips': line[slices['place_fips'][0]:slices['place_fips'][1]].strip(),
                        'population': clean_number(line[slices['population'][0]:slices['population'][1]]),
                        'population_year': line[slices['population_year'][0]:slices['population_year'][1]].strip(),
                        'enrollment': clean_number(line[slices['enrollment'][0]:slices['enrollment'][1]]),
                        'enrollment_year': line[slices['enrollment_year'][0]:slices['enrollment_year'][1]].strip(),
                        'special_district_function': line[slices['special_district_function'][0]:slices['special_district_function'][1]].strip(),
                        'school_level': line[slices['school_level'][0]:slices['school_level'][1]].strip(),
                        'fiscal_year_ending': line[slices['fiscal_year_ending'][0]:slices['fiscal_year_ending'][1]].strip(),
                        'survey_year': line[slices['survey_year'][0]:slices['survey_year'][1]].strip(),
                    }
                )

    return pl.DataFrame(records, schema=pid_schema, orient='row')


def read_finance_file(zip_path, member, year, config):
    id_len = config['id_len']
    slices = default_finance_slices | config.get('finance_slices', {})
    records = []
    with zipfile.ZipFile(zip_path) as zf:
        with zf.open(member) as fh:
            for raw in fh:
                line = raw.decode('latin1').rstrip('\n')
                line = line.rstrip('\r')
                max_stop = max(stop for _, stop in slices.values())
                if len(line) < max_stop:
                    continue

                item_code = line[slices['item_code'][0]:slices['item_code'][1]]
                if item_code not in debt_items:
                    continue

                records.append(
                    {
                        'year': year,
                        'gov_id': line[0:id_len],
                        'item_code': item_code,
                        'amount_thousands': clean_number(line[slices['amount'][0]:slices['amount'][1]]),
                        'data_year': clean_number(line[slices['data_year'][0]:slices['data_year'][1]]),
                        'data_flag': line[slices['data_flag'][0]:slices['data_flag'][1]],
                    }
                )

    return pl.DataFrame(records, schema=finance_schema, orient='row')


def load_cog_year(year, config):
    zip_path = config['zip']
    pid_member = find_zip_member(zip_path, config['pid_pattern'])
    finance_member = find_zip_member(zip_path, config['finance_pattern'])

    print(f'Loading {year}:')
    print(f'  PID/GID: {pid_member}')
    print(f'  finance: {finance_member}')

    pid = read_pid_file(zip_path, pid_member, year, config)
    finance = read_finance_file(zip_path, finance_member, year, config)

    gov_pid = (
        pid
        .with_columns([
            pl.col('government_type').replace(government_type_labels).alias('government_type_label'),
            pl.col('state_fips').replace(state_fips_to_abbr).alias('state'),
            pl.concat_str(['state_fips', 'county_fips3']).alias('county_fips'),
        ])
    )

    city_pid = (
        gov_pid
        .filter(pl.col('government_type').is_in(municipal_government_types))
        .with_columns([
            pl.concat_str(['state_fips', 'place_fips']).alias('place_fips_full'),
            pl.col('census_name').map_elements(normalize_city_name, return_dtype=pl.Utf8).alias('census_city_clean'),
        ])
    )

    debt_long = (
        finance
        .with_columns([
            pl.col('gov_id').str.slice(2, 1).alias('government_type'),
            pl.col('item_code').replace(debt_items).alias('debt_item'),
        ])
    )

    all_debt_wide = (
        debt_long
        .pivot(
            values='amount_thousands',
            index=['year', 'gov_id'],
            columns='debt_item',
            aggregate_function='first',
        )
    )

    all_debt_panel = (
        gov_pid
        .join(all_debt_wide, on=['year', 'gov_id'], how='left')
        .with_columns([
            pl.col(col).fill_null(0).alias(col)
            for col in debt_items.values()
            if col in all_debt_wide.columns
        ])
    )

    for col in debt_items.values():
        if col not in all_debt_panel.columns:
            all_debt_panel = all_debt_panel.with_columns(pl.lit(0).alias(col))

    all_debt_panel = (
        all_debt_panel
        .with_columns([
            (
                pl.col('end_lt_debt_outstanding') +
                pl.col('end_short_term_debt_outstanding')
            ).alias('total_end_debt_outstanding'),
            (
                pl.col('begin_lt_debt_outstanding') +
                pl.col('begin_short_term_debt_outstanding')
            ).alias('total_begin_debt_outstanding'),
        ])
    )

    county_nonmunicipal_summary = (
        all_debt_panel
        .filter(pl.col('government_type').is_in(local_nonmunicipal_government_types))
        .group_by(['year', 'state', 'county_fips'])
        .agg([
            pl.len().alias('county_nonmunicipal_governments'),
            (pl.col('total_end_debt_outstanding') > 0)
            .sum()
            .alias('county_nonmunicipal_governments_with_end_debt'),
            pl.col('end_lt_debt_outstanding')
            .sum()
            .alias('county_nonmunicipal_end_lt_debt_outstanding'),
            pl.col('end_short_term_debt_outstanding')
            .sum()
            .alias('county_nonmunicipal_end_short_term_debt_outstanding'),
            pl.col('total_end_debt_outstanding')
            .sum()
            .alias('county_nonmunicipal_total_end_debt_outstanding'),
            pl.col('lt_debt_issued')
            .sum()
            .alias('county_nonmunicipal_lt_debt_issued'),
        ])
        .with_columns([
            (pl.col('county_nonmunicipal_end_lt_debt_outstanding') * 1000)
            .alias('county_nonmunicipal_end_lt_debt_outstanding_dollars'),
            (pl.col('county_nonmunicipal_end_short_term_debt_outstanding') * 1000)
            .alias('county_nonmunicipal_end_short_term_debt_outstanding_dollars'),
            (pl.col('county_nonmunicipal_total_end_debt_outstanding') * 1000)
            .alias('county_nonmunicipal_total_end_debt_outstanding_dollars'),
            (pl.col('county_nonmunicipal_lt_debt_issued') * 1000)
            .alias('county_nonmunicipal_lt_debt_issued_dollars'),
        ])
        .sort(['year', 'state', 'county_fips'])
    )

    city_debt_long = (
        debt_long
        .filter(pl.col('government_type').is_in(municipal_government_types))
    )

    city_debt_wide = (
        city_debt_long
        .pivot(
            values='amount_thousands',
            index=['year', 'gov_id'],
            columns='debt_item',
            aggregate_function='first',
        )
    )

    flag_summary = (
        city_debt_long
        .group_by(['year', 'item_code', 'data_flag'])
        .agg([
            pl.len().alias('records'),
            pl.col('amount_thousands').sum().alias('amount_thousands'),
        ])
    )

    panel = (
        city_pid
        .join(city_debt_wide, on=['year', 'gov_id'], how='left')
        .with_columns([
            pl.col(col).fill_null(0).alias(col)
            for col in debt_items.values()
            if col in city_debt_wide.columns
        ])
    )

    for col in debt_items.values():
        if col not in panel.columns:
            panel = panel.with_columns(pl.lit(0).alias(col))

    panel = (
        panel
        .with_columns([
            (
                pl.col('end_lt_debt_outstanding') +
                pl.col('end_short_term_debt_outstanding')
            ).alias('total_end_debt_outstanding'),
            (
                pl.col('begin_lt_debt_outstanding') +
                pl.col('begin_short_term_debt_outstanding')
            ).alias('total_begin_debt_outstanding'),
        ])
        .with_columns([
            (pl.col('end_lt_debt_outstanding') * 1000).alias('end_lt_debt_outstanding_dollars'),
            (pl.col('end_short_term_debt_outstanding') * 1000).alias('end_short_term_debt_outstanding_dollars'),
            (pl.col('total_end_debt_outstanding') * 1000).alias('total_end_debt_outstanding_dollars'),
            pl.when(pl.col('population') > 0)
            .then((pl.col('total_end_debt_outstanding') * 1000) / pl.col('population'))
            .otherwise(None)
            .alias('total_end_debt_per_capita'),
        ])
        .sort(['state', 'county_fips', 'census_city_clean', 'year'])
    )

    return panel, flag_summary, county_nonmunicipal_summary


def read_mergent_issuer_file():
    if pd is None:
        print('pandas is not installed; skipping Mergent merge diagnostic.')
        return None

    if not mergent_bond_file.exists():
        print(f'Mergent bond file not found: {mergent_bond_file}')
        return None

    print('Loading latest Mergent bond-level file for issuer match diagnostic...')
    cols = [
        'seed_issuer_id',
        'seed_issuer',
        'fips',
        'state',
        'state_name',
        'city_go_vote',
        'city_rev_vote',
    ]

    try:
        bond_pd = pd.read_stata(mergent_bond_file, columns=cols, convert_categoricals=False)
    except Exception as exc:
        print(f'Could not read Mergent Stata file; skipping merge diagnostic. Error: {exc}')
        return None

    issuer = (
        pl.from_pandas(bond_pd)
        .filter(pl.col('seed_issuer_id').is_not_null())
        .with_columns([
            pl.col('seed_issuer_id').cast(pl.Float64).cast(pl.Int64),
            pl.col('state').cast(pl.Utf8).str.to_uppercase(),
            pl.col('fips').cast(pl.Utf8).str.replace(r'\.0$', '').str.zfill(5).alias('county_fips'),
        ])
        .group_by('seed_issuer_id')
        .agg([
            pl.col('seed_issuer').drop_nulls().first().alias('seed_issuer'),
            pl.col('county_fips').drop_nulls().first().alias('county_fips'),
            pl.col('state').drop_nulls().first().alias('state'),
            pl.col('state_name').drop_nulls().first().alias('state_name'),
            pl.col('city_go_vote').drop_nulls().first().alias('city_go_vote'),
            pl.col('city_rev_vote').drop_nulls().first().alias('city_rev_vote'),
        ])
        .with_columns([
            (
                pl.col('city_go_vote').eq(0)
                & pl.col('city_rev_vote').eq(0)
            ).fill_null(False).cast(pl.Int8).alias('control'),
            pl.col('state').is_in(['WA', 'MI', 'OH']).cast(pl.Int8).alias('utgo_only'),
        ])
        .with_columns([
            (
                pl.col('city_go_vote').eq(1)
                & pl.col('city_rev_vote').eq(0)
                & pl.col('utgo_only').eq(0)
            ).fill_null(False).cast(pl.Int8).alias('allgo_only'),
        ])
        .with_columns([
            (
                pl.col('control').eq(1)
                | pl.col('utgo_only').eq(1)
                | pl.col('allgo_only').eq(1)
            ).cast(pl.Int8).alias('insample'),
            (
                pl.col('control').eq(1)
                | pl.col('allgo_only').eq(1)
            ).cast(pl.Int8).alias('insample_allgo'),
            (
                pl.col('control').eq(1)
                | pl.col('utgo_only').eq(1)
            ).cast(pl.Int8).alias('insample_utgo_only'),
        ])
        .with_columns([
            pl.struct(['seed_issuer', 'state'])
            .map_elements(
                lambda x: normalize_issuer_name(x['seed_issuer'], x['state']),
                return_dtype=pl.Utf8,
            )
            .alias('issuer_city_clean')
        ])
    )

    return issuer


def build_merge_diagnostic(census_panel, issuers):
    if issuers is None:
        return

    census_names = (
        census_panel
        .filter(pl.col('year').eq(2022))
        .select([
            'gov_id',
            'state',
            'county_fips',
            'census_name',
            'government_type',
            'government_type_label',
            'census_city_clean',
            'place_fips_full',
            'population',
            'total_end_debt_outstanding',
            'total_end_debt_per_capita',
        ])
        .filter(pl.col('census_city_clean').is_not_null())
        .with_columns([
            pl.when(pl.col('government_type').eq('2'))
            .then(0)
            .when(pl.col('government_type').eq('3'))
            .then(1)
            .otherwise(2)
            .alias('census_government_priority'),
        ])
        .sort(['state', 'county_fips', 'census_city_clean', 'census_government_priority', 'population'])
        .unique(subset=['state', 'county_fips', 'census_city_clean'], keep='first')
    )

    exact_county = (
        issuers
        .join(
            census_names,
            left_on=['state', 'county_fips', 'issuer_city_clean'],
            right_on=['state', 'county_fips', 'census_city_clean'],
            how='left',
        )
        .with_columns(
            pl.when(pl.col('gov_id').is_not_null())
            .then(pl.lit('state_county_name'))
            .otherwise(None)
            .alias('match_type')
        )
    )

    unmatched = exact_county.filter(pl.col('gov_id').is_null()).select(issuers.columns)

    census_state_names = (
        census_names
        .unique(subset=['state', 'census_city_clean'], keep='first')
        .select([
            'state',
            'gov_id',
            'county_fips',
            'census_name',
            'government_type',
            'government_type_label',
            'census_government_priority',
            'census_city_clean',
            'place_fips_full',
            'population',
            'total_end_debt_outstanding',
            'total_end_debt_per_capita',
        ])
    )

    exact_state = (
        unmatched
        .join(
            census_state_names,
            left_on=['state', 'issuer_city_clean'],
            right_on=['state', 'census_city_clean'],
            how='left',
            suffix='_census',
        )
        .with_columns(
            pl.when(pl.col('gov_id').is_not_null())
            .then(pl.lit('state_name'))
            .otherwise(None)
            .alias('match_type')
        )
    )

    matched_exact = pl.concat(
        [
            exact_county.filter(pl.col('gov_id').is_not_null()),
            exact_state.filter(pl.col('gov_id').is_not_null()),
        ],
        how='diagonal',
    )

    matched_exact = (
        matched_exact
        .with_columns([
            pl.when(pl.col('match_type').eq('state_county_name'))
            .then(0)
            .otherwise(1)
            .alias('match_type_priority'),
            pl.col('city_go_vote').is_null().cast(pl.Int8).alias('law_missing_priority'),
            pl.when(
                pl.col('seed_issuer')
                .str.to_uppercase()
                .str.contains(r'\b(TWP|TOWNSHIP)\b')
            )
            .then(2)
            .when(
                pl.col('seed_issuer')
                .str.to_uppercase()
                .str.contains(r'\b(VLG|VILLAGE|BORO|BOROUGH)\b')
            )
            .then(1)
            .otherwise(0)
            .alias('issuer_name_priority'),
        ])
        .sort([
            'gov_id',
            'match_type_priority',
            'law_missing_priority',
            'census_government_priority',
            'issuer_name_priority',
            'seed_issuer_id',
        ])
        .unique(subset=['gov_id'], keep='first')
        .unique(subset=['seed_issuer_id'], keep='first')
        .drop(['match_type_priority', 'law_missing_priority', 'census_government_priority', 'issuer_name_priority'])
    )

    still_unmatched = exact_state.filter(pl.col('gov_id').is_null()).select(issuers.columns)

    matched_exact.write_csv(diagnostics_dir / 'census_cog_2022_mergent_exact_matches.csv')
    still_unmatched.write_csv(diagnostics_dir / 'census_cog_2022_mergent_unmatched.csv')

    print('Exact merge diagnostic:')
    print(f'  Mergent issuers: {issuers.height:,}')
    print(f'  exact matches: {matched_exact.select("seed_issuer_id").n_unique():,}')
    print(f'  matched Census governments: {matched_exact.select("gov_id").n_unique():,}')
    print(f'  unmatched: {still_unmatched.height:,}')

    fuzzy_rows = []
    census_by_state = {}
    for row in census_state_names.select(['state', 'census_city_clean', 'census_name', 'gov_id']).iter_rows(named=True):
        if row['census_city_clean'] is None:
            continue
        census_by_state.setdefault(row['state'], []).append(row)

    for issuer in still_unmatched.iter_rows(named=True):
        issuer_name = issuer.get('issuer_city_clean')
        state = issuer.get('state')
        if issuer_name is None or state not in census_by_state:
            continue

        choices = [row['census_city_clean'] for row in census_by_state[state]]
        for candidate in difflib.get_close_matches(issuer_name, choices, n=3, cutoff=0.82):
            match = next(row for row in census_by_state[state] if row['census_city_clean'] == candidate)
            fuzzy_rows.append(
                {
                    'seed_issuer_id': issuer['seed_issuer_id'],
                    'seed_issuer': issuer['seed_issuer'],
                    'state': state,
                    'county_fips': issuer['county_fips'],
                    'issuer_city_clean': issuer_name,
                    'candidate_gov_id': match['gov_id'],
                    'candidate_census_name': match['census_name'],
                    'candidate_city_clean': candidate,
                }
            )

    if fuzzy_rows:
        pl.DataFrame(fuzzy_rows).write_csv(diagnostics_dir / 'census_cog_2022_mergent_fuzzy_candidates.csv')
    else:
        pl.DataFrame(
            schema={
                'seed_issuer_id': pl.Int64,
                'seed_issuer': pl.Utf8,
                'state': pl.Utf8,
                'county_fips': pl.Utf8,
                'issuer_city_clean': pl.Utf8,
                'candidate_gov_id': pl.Utf8,
                'candidate_census_name': pl.Utf8,
                'candidate_city_clean': pl.Utf8,
            }
        ).write_csv(diagnostics_dir / 'census_cog_2022_mergent_fuzzy_candidates.csv')


#%% -----------------------------------------------------------------------
# load and clean census COG files
# -----------------------------------------------------------------------
panels = []
flag_summaries = []
county_nonmunicipal_summaries = []

for year, config in cog_years.items():
    panel_year, flags_year, county_nonmunicipal_year = load_cog_year(year, config)
    panels.append(panel_year)
    flag_summaries.append(flags_year)
    county_nonmunicipal_summaries.append(county_nonmunicipal_year)

census_panel = (
    pl.concat(panels, how='diagonal')
    .sort(['state', 'county_fips', 'census_city_clean', 'year'])
)

flag_summary = (
    pl.concat(flag_summaries, how='diagonal')
    .sort(['year', 'item_code', 'data_flag'])
)

county_nonmunicipal_summary = (
    pl.concat(county_nonmunicipal_summaries, how='diagonal')
    .sort(['year', 'state', 'county_fips'])
)


#%% -----------------------------------------------------------------------
# diagnostics
# -----------------------------------------------------------------------
year_summary = (
    census_panel
    .group_by('year')
    .agg([
        pl.len().alias('municipal_governments'),
        pl.col('population').is_not_null().sum().alias('nonmissing_population'),
        (pl.col('total_end_debt_outstanding') > 0).sum().alias('municipal_governments_with_end_debt'),
        pl.col('total_end_debt_outstanding').sum().alias('total_end_debt_thousands'),
    ])
    .sort('year')
)

state_summary = (
    census_panel
    .group_by(['year', 'state'])
    .agg([
        pl.len().alias('municipal_governments'),
        (pl.col('total_end_debt_outstanding') > 0).sum().alias('municipal_governments_with_end_debt'),
        pl.col('population').sum().alias('population'),
        pl.col('total_end_debt_outstanding').sum().alias('total_end_debt_thousands'),
    ])
    .sort(['year', 'state'])
)

print('COG year summary:')
print(year_summary)


#%% -----------------------------------------------------------------------
# save census outputs
# -----------------------------------------------------------------------
census_panel.write_csv(processed_dir / 'census_cog_city_debt_panel.csv')
county_nonmunicipal_summary.write_csv(processed_dir / 'census_cog_county_nonmunicipal_debt_summary.csv')
year_summary.write_csv(diagnostics_dir / 'census_cog_city_debt_year_summary.csv')
state_summary.write_csv(diagnostics_dir / 'census_cog_city_debt_state_summary.csv')
flag_summary.write_csv(diagnostics_dir / 'census_cog_city_debt_item_flag_summary.csv')


#%% -----------------------------------------------------------------------
# investigate merge feasibility with Mergent issuer-level file
# -----------------------------------------------------------------------
issuers = read_mergent_issuer_file()
build_merge_diagnostic(census_panel, issuers)

# %%
