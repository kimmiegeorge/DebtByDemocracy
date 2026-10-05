"""Build an AL/AR-only issuer roster and a separate Wayback URL list."""
import os
from pathlib import Path
from urllib.parse import urlsplit
import polars as pl

code_dir = Path(__file__).resolve().parents[5]
data_dir = code_dir.parent / 'Data'
collection_dir = Path(os.getenv(
    'AL_AR_WEBSITE_DIR',
    str(data_dir / 'Websites/Border States Website Data/AL_AR')
)).expanduser()
collection_dir.mkdir(parents=True, exist_ok=True)

# Keep one issuer per border pair; scrape a shared host only once per year.
issuers = pl.read_csv(
    data_dir / 'Clean_Intermediate/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv',
    infer_schema_length=10000
).filter(pl.col('state').is_in(['AL', 'AR'])).select(
    ['state', 'seed_issuer_id', 'seed_issuer', 'group', 'county_name']
).unique().sort(['state', 'seed_issuer', 'group'])
if set(issuers.get_column('state')) != {'AL', 'AR'}:
    raise ValueError('Rebuild the corrected border sample before preparing AL/AR collection.')

# Preserve reviewed hosts across reruns. Fill this file with verified official
# hosts (including historical aliases when needed), source URLs, and notes.
# One issuer may have several hosts; explicit inclusion avoids guessing URLs
# for abbreviated or ambiguous Mergent names.
mapping_file = collection_dir / 'issuer_website_mapping.csv'
if not mapping_file.exists():
    issuers.select(['state', 'seed_issuer_id', 'seed_issuer']).unique().with_columns(
        pl.lit('').alias('URL'),
        pl.lit('').alias('source_url'),
        pl.lit('').alias('notes'),
        pl.lit(0).alias('include_in_collection')
    ).sort(['state', 'seed_issuer']).write_csv(mapping_file)
mapping = pl.read_csv(mapping_file, infer_schema_length=10000,
                      schema_overrides={'URL': pl.String, 'source_url': pl.String, 'notes': pl.String})
mapping = mapping.with_columns(pl.col('seed_issuer_id').cast(pl.Float64))
keys = ['state', 'seed_issuer_id', 'seed_issuer']
if mapping.select(keys).unique().join(issuers.select(keys).unique(), on=keys, how='anti').height:
    raise ValueError('The website mapping contains issuers outside the AL/AR border sample.')
approved = mapping.filter(pl.col('include_in_collection') == 1)
hosts = []
for row in approved.iter_rows(named=True):
    raw = (row['URL'] or '').strip()
    parsed = urlsplit(raw if '://' in raw else f'https://{raw}')
    if (not parsed.hostname or '.' not in parsed.hostname or parsed.path not in ['', '/']
            or parsed.query or parsed.fragment or parsed.username or parsed.port):
        raise ValueError(f'Enter a bare official website host for {row["seed_issuer"]}: {raw}')
    if not row['source_url']:
        raise ValueError(f'Missing verification source for {row["seed_issuer"]}.')
    hosts.append(parsed.hostname.lower())
approved = approved.with_columns(pl.Series('URL', hosts, dtype=pl.String))
roster = issuers.join(approved.select(keys + ['URL', 'source_url', 'notes']), on=keys, how='inner')
roster.rename({'URL': 'City Website'}).write_csv(collection_dir / 'collected_issuers.csv')
approved.select('URL').unique().sort('URL').write_csv(collection_dir / 'urls.csv')
missing = issuers.join(approved.select(keys).unique(), on=keys, how='anti')
missing.write_csv(collection_dir / 'issuers_needing_websites.csv')
print(f'{issuers.select(keys).unique().height} AL/AR issuers; {approved["URL"].n_unique()} approved hosts.')
print(f'{missing.select(keys).unique().height} issuers still need reviewed websites: {mapping_file}')
