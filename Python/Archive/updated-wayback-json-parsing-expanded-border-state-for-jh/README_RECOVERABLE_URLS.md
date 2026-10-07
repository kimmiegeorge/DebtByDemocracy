# Recoverable URLs Processing

This directory contains scripts to process URL-year pairs identified as recoverable from the bad URLs investigation.

## Overview

The `wayback-json-parsing-bad-urls` investigation identified **416 URL-year pairs** that failed in previous scraping attempts but are actually recoverable from the Wayback Machine. These scripts allow you to re-scrape these URLs and save them to a separate output directory.

## Files

### Scripts (in this repo directory)
- **`split_recoverable_urls.py`**: Splits the recoverable URLs into multiple sets for parallel processing
- **`process_recoverable_urls.py`**: Processes specific sets or all recoverable URLs

### Data Files (in Dropbox for team access)
Location: `/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/`

- **`recoverable_urls_set1.csv`**: Set 1 (139 pairs, 84 unique URLs)
- **`recoverable_urls_set2.csv`**: Set 2 (139 pairs, 101 unique URLs)
- **`recoverable_urls_set3.csv`**: Set 3 (138 pairs, 93 unique URLs)

## Output Directory

All recovered URLs are saved to a separate directory to avoid mixing with regular scraping:
```
/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Recovered URLs From Bad URLs Investigation/
```

## Usage

### Step 1: Split URLs into Sets (Already Done)

The recoverable URLs have already been split into 3 sets:

```bash
python3 split_recoverable_urls.py
```

Optional arguments:
- `--sets N`: Number of sets to create (default: 3)
- `--input FILE`: Input recoverable_urls.csv file
- `--output-dir DIR`: Output directory for set files

### Step 2: Process Each Set

You can process each set on a different computer for parallel processing:

**Computer 1 - Process Set 1:**
```bash
python3 process_recoverable_urls.py --set 1
```

**Computer 2 - Process Set 2:**
```bash
python3 process_recoverable_urls.py --set 2
```

**Computer 3 - Process Set 3:**
```bash
python3 process_recoverable_urls.py --set 3
```

**Or process all at once on one computer:**
```bash
python3 process_recoverable_urls.py
```

## Configuration

The script uses the same configuration as the main expanded-border-state pipeline but with modified paths:

- **Max URLs per site**: 50 pages
- **Max sub-levels**: 3 levels deep
- **Rate limit**: 8 seconds between requests
- **Output**: Separate "Recovered URLs" directory

## What Gets Saved

For each URL-year pair, the following files are created in the output directory organized by year:

```
Recovered URLs From Bad URLs Investigation/
├── JSON_2015/
│   ├── cdx[hostname].csv       # Wayback Machine metadata
│   ├── res[hostname].json      # Complete scraping results
│   └── bow[hostname].json      # Bag-of-words text data
├── JSON_2016/
│   └── ...
```

## Progress Tracking

The script provides:
- Real-time progress updates
- Already-processed URL detection (resumes if interrupted)
- Success/failure counts
- ETA calculations
- Progress summaries every 10 pairs

## Expected Runtime

- **Per URL-year pair**: ~30-60 seconds
- **Set 1 (139 pairs)**: ~2-3 hours
- **Set 2 (139 pairs)**: ~2-3 hours
- **Set 3 (138 pairs)**: ~2-3 hours
- **All sets combined**: ~6-9 hours

## Example Session

```bash
# On Computer 1
cd /Users/kmunevar/Repos/VotingOnBonds/City\ Websites/updated-wayback-json-parsing-expanded-border-state
python3 process_recoverable_urls.py --set 1

# Output:
# ======================================================================
# Recoverable URLs Scraping Pipeline
# ======================================================================
# 
# 📦 Processing Set 1
# 📁 Input file: recoverable_urls_set1.csv
# 
# 📁 Loaded 139 recoverable URL-year pairs
# 📊 Unique URLs: 84
# 📅 Years: [2015, 2016, 2017, 2018, 2019, 2020]
# 📂 Output directory: /Users/kmunevar/Dropbox/Voting on Bonds/...
# 
# 🔄 [1/139] Processing www.ishpemingcity.org (2017)...
# ✅ [1/139] www.ishpemingcity.org (2017) - Completed in 45.2s
# ...
```

## Troubleshooting

**Set file not found:**
```
❌ Error: Could not find file at recoverable_urls_set1.csv
Hint: Did you run 'python3 split_recoverable_urls.py' first?
```
→ Run the split script first

**Already processed:**
Files with existing `cdx[hostname].csv` files are automatically skipped

**Network errors:**
The script includes retry logic and will continue processing other URLs if one fails

## Integration with Main Pipeline

These recovered URLs are kept separate from:
- Regular Texas scraping pipeline (`updated-wayback-json-parsing-texas`)
- Main border state scraping (`Updated Scraping 202509`)

This allows you to:
- Track which URLs were recovered from the bad URLs list
- Re-run recovery without affecting existing data
- Merge results later if desired
