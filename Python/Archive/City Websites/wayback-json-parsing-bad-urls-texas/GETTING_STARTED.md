# Getting Started - Texas Bad URLs Recovery

Quick guide to get up and running with the Texas bad URLs investigation.

## Prerequisites

- Python 3.7+
- Access to:
  - `~/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/bad_urls_251113.csv`
  - `~/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Updated Scraping 202509/`

## Quick Start (Recommended)

```bash
cd wayback-json-parsing-bad-urls-texas
./run_investigation.sh
```

This will:
1. Install dependencies (if needed)
2. Test the first 5 bad URLs
3. Generate reports in `reports/` directory

## Manual Setup

If you prefer to set up manually:

```bash
cd wayback-json-parsing-bad-urls-texas

# Install dependencies
pip install -r requirements.txt

# Run investigation on first 5 URLs (test)
python investigate_bad_urls.py --limit 5 --sample-size 5

# View results
cat reports/investigation_summary.json
cat reports/recoverable_urls.csv
```

## Running Full Investigation

Once you've verified the test works:

```bash
# Investigate all bad URLs
python investigate_bad_urls.py

# Or with custom sample size
python investigate_bad_urls.py --sample-size 15
```

## Understanding the Output

### reports/investigation_summary.json
High-level statistics about the investigation

### reports/investigation_results.json
Detailed results for each URL-year pair

### reports/recoverable_urls.csv
List of URLs that can be successfully recovered (ready for re-scraping)

## What's Next?

1. Review the results in `reports/`
2. Check which URLs are marked as "RECOVERABLE"
3. Use the recoverable URLs list for re-scraping (if needed)

## Troubleshooting

### "FileNotFoundError" for bad_urls_251113.csv
Check that the file exists at:
`~/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/bad_urls_251113.csv`

### "No CDX file found"
Check that CDX files exist at:
`~/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Updated Scraping 202509/Annual Files/JSON_YYYY/`

### Dependencies installation fails
Try creating a virtual environment first:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Configuration

All paths are pre-configured in `config.py`. You can adjust:
- `sample_size`: Number of snapshots to test (default: 10)
- `min_suburls_threshold`: Minimum sub-URLs to consider recoverable (default: 5)
- `rate_limit_delay`: Delay between requests (default: 2.0 seconds)

## Questions?

See `README.md` for more detailed documentation.

