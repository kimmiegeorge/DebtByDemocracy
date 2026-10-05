"""Collect only reviewed AL/AR hosts with the existing border-state scraper."""
import argparse
import json
import os
from pathlib import Path
import sys
import polars as pl

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dry-run', action='store_true')
parser.add_argument('--start-year', type=int, default=2015)
parser.add_argument('--end-year', type=int, default=2020)
parser.add_argument('--limit-hosts', type=int)
args = parser.parse_args()
if not 2015 <= args.start_year <= args.end_year <= 2020:
    parser.error('Use years within the website study period, 2015–2020.')
if args.limit_hosts is not None and args.limit_hosts < 1:
    parser.error('--limit-hosts must be positive.')

code_dir = Path(__file__).resolve().parents[5]
collection_dir = Path(os.getenv(
    'AL_AR_WEBSITE_DIR',
    str(code_dir.parent / 'Data/Websites/Border States Website Data/AL_AR')
)).expanduser()
urls = pl.read_csv(collection_dir / 'urls.csv', schema_overrides={'URL': pl.String})
hosts = urls.get_column('URL').drop_nulls().unique(maintain_order=True).to_list()
if args.limit_hosts:
    hosts = hosts[:args.limit_hosts]
if not hosts:
    raise SystemExit('No approved hosts. Fill issuer_website_mapping.csv and rerun step 01.')
print(f'{len(hosts)} hosts, {args.end_year - args.start_year + 1} years, up to 50 URLs per tree.')
if args.dry_run:
    print('\n'.join(hosts))
    raise SystemExit(0)

# Set paths before importing the legacy configuration, which creates a default
# instance at import time. All new raw files and logs stay in the AL/AR area.
wbm_dir = collection_dir / 'WBM'
os.environ['WBM_BASE_PATH'] = str(wbm_dir) + '/'
os.environ['WBM_COLLECTION_PATH'] = str(collection_dir) + '/'
sys.path.insert(0, str(code_dir / 'Python/Clean/City_Websites/updated-wayback-json-parsing-expanded-border-state'))
from config import Config
from run_wbm import ImprovedWaybackScraper
from utils import sanitize_filename

config = Config()
config.scraping.max_urls = 50
config.scraping.max_sub_levels = 3
config.logging.log_file_path = str(wbm_dir / 'wayback_scraper.log')
scraper = ImprovedWaybackScraper(config)

# Keep a durable host-year status log. A CDX index alone does not establish
# successful collection; retry incomplete pairs even when the index exists.
status_file = collection_dir / 'collection_status.csv'
statuses = pl.read_csv(status_file).to_dicts() if status_file.exists() else []
failures = 0
for year in range(args.end_year, args.start_year - 1, -1):
    year_dir = wbm_dir / 'Annual Files' / f'JSON_{year}'
    year_dir.mkdir(parents=True, exist_ok=True)
    for host in hosts:
        name = sanitize_filename(host)
        result_file = year_dir / f'res[{name}].json'
        bow_file = year_dir / f'bow[{name}].json'
        complete = False
        if result_file.exists() and bow_file.exists():
            try:
                results = json.loads(result_file.read_text())
                words = json.loads(bow_file.read_text())
                complete = bool(results) and set(results) == set(words)
            except (ValueError, OSError):
                pass
        if complete:
            status = 'already_collected'
        else:
            # Rebuild incomplete trees: legacy session resume only returns new
            # entries and can otherwise overwrite partially collected results.
            success = scraper.scrape_host(
                host=host, frequency='YE', output_path=str(year_dir),
                date_range=(f'{year}-01-01', f'{year}-12-31'),
                max_urls=50, max_sub_levels=3, resume_session=False
            )
            status = 'collected' if success else 'failed_or_no_snapshot'
            failures += int(not success)
        print(f'{host} {year}: {status}', flush=True)
        statuses = [row for row in statuses if (row['URL'], row['year']) != (host, year)]
        statuses.append({'URL': host, 'year': year, 'status': status})
        pl.DataFrame(statuses).sort(['URL', 'year']).write_csv(status_file)
if failures:
    raise SystemExit(f'{failures} host-years failed or had no snapshot; inspect collection_status.csv.')
