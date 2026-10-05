"""Convert AL/AR Wayback JSON results to the shared res/bow CSV schema."""
import json
import os
from pathlib import Path
import sys
import polars as pl

code_dir = Path(__file__).resolve().parents[5]
collection_dir = Path(os.getenv(
    'AL_AR_WEBSITE_DIR',
    str(code_dir.parent / 'Data/Websites/Border States Website Data/AL_AR')
)).expanduser()
output_dir = collection_dir / 'WBM/Processed'
for kind in ['res', 'bow']:
    (output_dir / kind).mkdir(parents=True, exist_ok=True)
hosts = pl.read_csv(collection_dir / 'urls.csv', schema_overrides={'URL': pl.String})['URL'].drop_nulls().to_list()
# This utility module has no configuration instance or network side effects.
sys.path.insert(0, str(code_dir / 'Python/Clean/City_Websites/updated-wayback-json-parsing-expanded-border-state'))
from utils import sanitize_filename

processed = []
for year in range(2015, 2021):
    year_dir = collection_dir / 'WBM/Annual Files' / f'JSON_{year}'
    for host in hosts:
        name = sanitize_filename(host)
        res_file = year_dir / f'res[{name}].json'
        bow_file = year_dir / f'bow[{name}].json'
        if not res_file.exists() or not bow_file.exists():
            processed.append({'URL': host, 'year': year, 'status': 'missing_raw_files', 'rows': 0})
            continue
        results = json.loads(res_file.read_text())
        words = json.loads(bow_file.read_text())
        if set(results) != set(words):
            raise ValueError(f'Result and word-count snapshots disagree: {host} {year}')
        rows = [dict(entry, **{'parent url': parent, 'original_url': host})
                for parent, entries in results.items() for entry in entries]
        if not rows:
            processed.append({'URL': host, 'year': year, 'status': 'empty_results', 'rows': 0})
            continue
        res = pl.DataFrame(rows, infer_schema_length=None)
        res = res.drop([column for column in ['subURLs', 'info'] if column in res.columns])
        res.write_csv(output_dir / 'res' / f'{name}_{year}.csv')
        bow_rows = [{'url': parent, 'word': word, 'count': count, 'original_url': host}
                    for parent, counts in words.items() for word, count in counts.items()]
        bow = pl.DataFrame(bow_rows, schema={'url': pl.String, 'word': pl.String,
                                          'count': pl.Int64, 'original_url': pl.String})
        bow.write_csv(output_dir / 'bow' / f'{name}_{year}.csv')
        processed.append({'URL': host, 'year': year, 'status': 'processed', 'rows': res.height})
if processed:
    pl.DataFrame(processed).write_csv(collection_dir / 'processing_status.csv')
print(f'Processed {sum(row["status"] == "processed" for row in processed)} host-years into {output_dir}')
