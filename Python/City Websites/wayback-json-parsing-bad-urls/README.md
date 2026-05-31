# Bad URLs Recovery Pipeline

A specialized pipeline for investigating and re-scraping URL-year pairs that only yielded 1 snapshot in the original scraping process.

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

## Directory Structure

```
wayback-json-parsing-bad-urls/
├── README.md                  # This file
├── config.py                  # Configuration (paths, thresholds, etc.)
├── investigate_bad_urls.py    # Analysis tool to find better snapshots
├── rescrape_bad_urls.py       # Re-scrape using alternative snapshots
├── utils.py                   # Shared utilities
├── requirements.txt           # Dependencies
└── reports/                   # Investigation reports and results
```

## Installation

```bash
cd wayback-json-parsing-bad-urls
pip install -r requirements.txt
```

## Usage

### Step 1: Investigate Bad URLs

Analyze each bad URL to find alternative snapshots:

```bash
python investigate_bad_urls.py --bad-urls-file /path/to/bad_urls_251105.csv \
                               --output-dir ./reports \
                               --sample-size 10
```

This will:
- Check the CDX files for available snapshots
- Test multiple snapshots per year to find ones with sub-URLs
- Generate a report showing which URLs can be recovered

### Step 2: Re-scrape with Better Snapshots

Re-scrape using the best snapshots found:

```bash
python rescrape_bad_urls.py --investigation-report ./reports/investigation_results.json \
                            --output-dir /path/to/output \
                            --threshold 5
```

Options:
- `--threshold`: Minimum number of sub-URLs to consider successful (default: 5)
- `--max-urls`: Maximum URLs to scrape per tree (default: 50)
- `--retry-failed`: Retry URLs that failed in investigation

### Step 3: Merge Results

Merge the re-scraped data back into your main dataset:

```bash
python merge_results.py --original-dir /path/to/original \
                       --recovery-dir /path/to/recovery \
                       --output-dir /path/to/merged
```

## Configuration

Edit `config.py` to customize:

```python
# Paths
BAD_URLS_FILE = "~/Dropbox/.../bad_urls_251105.csv"
BASE_PATH = "~/Dropbox/.../WBM/Updated Scraping 202509/"
COLLECTION_FILES_PATH = "~/Dropbox/.../Collection Files/"

# Investigation settings
SAMPLE_SIZE = 10          # Number of snapshots to test per URL-year
TIMEOUT = 30              # Request timeout in seconds
MIN_SUBURLS_THRESHOLD = 5 # Minimum sub-URLs to consider success

# Scraping settings
MAX_URLS = 50
MAX_SUB_LEVELS = 3
RATE_LIMIT_DELAY = 8.0
```

## Output

### Investigation Report

JSON file with structure:
```json
{
  "www.example.com_2017": {
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

### Recovery Report

CSV file showing recovery success:
```csv
original_url,year,original_count,new_count,status,timestamp_used
www.example.com,2017,1,47,SUCCESS,20170615123456
www.example2.com,2018,1,1,UNRECOVERABLE,none
```

## Tips

1. **Start with a small sample** to validate the approach
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

# 3. Re-scrape recoverable ones
python rescrape_bad_urls.py --threshold 5

# 4. Check recovery stats
cat reports/recovery_summary.csv

# 5. Merge successful recoveries
python merge_results.py
```

## Notes

- This pipeline reuses the core scraping logic from the original pipeline
- It focuses specifically on finding better snapshots from the same year
- Results are saved separately to avoid overwriting original data
- You can merge results manually or use the merge script
