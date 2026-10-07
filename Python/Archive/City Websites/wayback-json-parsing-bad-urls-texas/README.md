# Bad URLs Recovery Pipeline - Texas

A specialized pipeline for investigating and re-scraping URL-year pairs that only yielded 1 snapshot in the original scraping process for Texas cities.

## Problem

During the original scraping, some URL-year combinations only collected 1 URL (the root page) instead of the expected ~50 sub-URLs. This typically happens when:

1. **Redirects**: The selected snapshot returns HTTP 301/302 instead of 200
2. **Empty pages**: The snapshot has minimal or no sub-URLs
3. **Filtering**: Valid sub-URLs were filtered out by the URLFilter rules
4. **Site changes**: The site structure changed during the year

## Solution

This pipeline:
1. **Investigates** each bad URL-year pair to find alternative snapshots
2. **Tests** multiple snapshots from the same year to find ones with valid sub-URLs
3. **Re-scrapes** using better snapshots
4. **Reports** which URLs are truly unrecoverable vs. successfully recovered

## Texas-Specific Configuration

This version is configured for Texas cities with:
- Bad URLs file: `~/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/bad_urls_251113.csv`
- Base path: `~/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Updated Scraping 202509/`
- Recovery output: `~/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Recovery 202511/`

## Directory Structure

```
wayback-json-parsing-bad-urls-texas/
├── README.md                  # This file
├── config.py                  # Configuration (Texas-specific paths)
├── investigate_bad_urls.py    # Analysis tool to find better snapshots
├── requirements.txt           # Dependencies
├── run_investigation.sh       # Quick start script
└── reports/                   # Investigation reports and results
```

## Installation

```bash
cd wayback-json-parsing-bad-urls-texas
pip install -r requirements.txt
```

## Usage

### Quick Start

Run the investigation on a small sample:

```bash
chmod +x run_investigation.sh
./run_investigation.sh
```

### Step 1: Investigate Bad URLs

Analyze each bad URL to find alternative snapshots:

```bash
# Test on first 5 URLs
python investigate_bad_urls.py --limit 5 --sample-size 5

# Run on all bad URLs
python investigate_bad_urls.py --sample-size 10
```

This will:
- Check the CDX files for available snapshots
- Test multiple snapshots per year to find ones with sub-URLs
- Generate a report showing which URLs can be recovered

### Configuration

All configuration is in `config.py`. Key settings:

```python
# Paths (already set for Texas)
bad_urls_file = "~/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/bad_urls_251113.csv"
base_path = "~/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Updated Scraping 202509/"

# Investigation settings
SAMPLE_SIZE = 10          # Number of snapshots to test per URL-year
TIMEOUT = 30              # Request timeout in seconds
MIN_SUBURLS_THRESHOLD = 5 # Minimum sub-URLs to consider success
```

## Output

### Investigation Report

JSON file with structure:
```json
{
  "www.texascity.gov_2017": {
    "original_scraped": 1,
    "total_snapshots": 156,
    "valid_snapshots": 89,
    "tested_snapshots": 10,
    "best_snapshot": {
      "timestamp": "20170615123456",
      "url": "https://web.archive.org/...",
      "sub_url_count": 47,
      "status": 200
    },
    "recommendation": "RECOVERABLE",
    "alternative_snapshots": [...]
  }
}
```

### Recoverable URLs

CSV file (`reports/recoverable_urls.csv`) showing URLs that can be recovered:
```csv
host,year,timestamp,url,sub_url_count
www.texascity.gov,2017,20170615123456,https://web.archive.org/...,47
```

## Tips

1. **Start with a small sample** to validate the approach (`--limit 5`)
2. **Check the investigation report** before running full re-scrape
3. **Some URLs may be truly unrecoverable** if all snapshots have issues
4. **Use the threshold parameter** to decide what counts as "recovered"
5. **Be patient** - investigating and re-scraping takes time

## Workflow Example

```bash
# 1. Investigate first 10 bad URLs
python investigate_bad_urls.py --limit 10

# 2. Review the report
cat reports/investigation_results.json

# 3. Check recoverable URLs
cat reports/recoverable_urls.csv

# 4. Run on all URLs
python investigate_bad_urls.py
```

## Notes

- This pipeline reuses the core scraping logic from the original pipeline
- It focuses specifically on finding better snapshots from the same year
- Results are saved separately to avoid overwriting original data
- Check `reports/` directory for all output files

