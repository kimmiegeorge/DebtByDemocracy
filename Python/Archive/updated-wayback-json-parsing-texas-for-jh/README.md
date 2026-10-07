# Wayback Machine Scraper for Texas Municipal Websites

This tool scrapes historical snapshots of Texas municipal websites from the Internet Archive's Wayback Machine, extracting and processing text content to build a temporal dataset of city website information.

## What This Does

This scraper:
1. Takes a list of Texas city website URLs
2. Queries the Wayback Machine for historical snapshots of those sites
3. Identifies the largest snapshot for each year (typically the most complete)
4. Crawls each snapshot and its linked pages (up to configurable depth)
5. Extracts and processes text content from all pages
6. Generates bag-of-words representations for text analysis
7. Saves results in structured JSON and CSV formats for further analysis

## How It Works

### Step 1: Prepare Input Data

Use `prepare_urls_file.py` to create a properly formatted URL list from the raw city website data:

```bash
python prepare_urls_file.py
```

This script:
- Reads `City Website Collection.csv` containing Texas city website URLs
- Filters out invalid/missing URLs
- Removes duplicates
- Normalizes URLs (removes protocols, trailing slashes)
- Splits the list into manageable chunks (default: 100 URLs per chunk)
- Outputs files like `Texas_URLs_Set1.csv`, `Texas_URLs_Set2.csv`, etc.

### Step 2: Run the Scraper

Process each URL set across a year range:

```bash
python run_wbm.py Texas_URLs_Set1.csv 2000 2024
```

The scraper then:

**For each year:**
1. **Query Wayback Machine API**: Fetches all available snapshots for each URL
2. **Filter by frequency**: Selects yearly snapshots (or monthly/daily if configured)
3. **Find largest snapshot**: Identifies the snapshot with the most content for each year
4. **Skip already-processed URLs**: Checks for existing output files to avoid re-scraping

**For each selected snapshot:**
1. **Scrape homepage**: Downloads and parses the main page HTML
2. **Extract links**: Finds all internal links from the homepage
3. **Priority ranking**: Scores URLs by relevance (finance/bond keywords get higher priority)
4. **Crawl sub-pages**: Recursively follows links up to configured depth
5. **Process text**: Extracts text, removes stopwords, applies stemming
6. **Build bag-of-words**: Creates word frequency counts for text analysis

**Session management:**
- Saves progress periodically to allow resumption if interrupted
- Respects rate limits (8 second delays between requests)
- Implements retry logic with exponential backoff for failed requests
- Logs all activities for debugging and monitoring

### Step 3: Output Files

For each URL and year, the scraper generates:

- **`cdx[hostname].csv`**: Wayback Machine snapshot metadata (timestamps, status codes, content lengths)
- **`res[hostname].json`**: Complete scraping results with HTML content and metadata for each page
- **`bow[hostname].json`**: Bag-of-words text data (word frequencies) for analysis
- **`session_hostname.json`**: Progress tracking file (deleted after successful completion)
- **`wayback_scraper.log`**: Detailed activity log

Files are organized by year:
```
Annual Files/
├── JSON_2000/
│   ├── cdx[example.gov].csv
│   ├── res[example.gov].json
│   └── bow[example.gov].json
├── JSON_2001/
│   └── ...
```

## Project Structure

```
updated-wayback-json-parsing-texas/
├── config.py              # All configuration settings (paths, timeouts, rate limits)
├── utils.py               # Helper functions (logging, file management, session tracking)
├── scraper.py             # Core scraping logic (API client, tree crawler, text processor)
├── run_wbm.py             # Main orchestration script and CLI
├── prepare_urls_file.py   # Input data preparation
├── requirements.txt       # Python dependencies
└── README.md              # This file
```

## Setup

1. **Install dependencies**:
```bash
pip install -r requirements.txt
```

2. **Download NLTK data** (required for text processing):
```python
import nltk
nltk.download('punkt')
nltk.download('stopwords')
```

3. **Configure paths** in `config.py`:
   - `base_path`: Where to save output files (default: `/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/`)
   - `collection_files_path`: Where input URL files are located

## Configuration

Key settings in `config.py`:

**Network settings:**
- `rate_limit_delay = 8.0`: Seconds between Wayback Machine requests
- `max_retries = 3`: Number of retry attempts for failed requests
- `timeout_seconds = 45`: Request timeout

**Scraping behavior:**
- `max_urls = 50`: Maximum pages to scrape per site snapshot
- `max_sub_levels = 3`: Maximum link depth to follow from homepage
- `priority_keywords`: Words that boost URL priority (e.g., "finance", "bond", "budget")

**Paths:**
- `base_path`: Output directory for scraped data
- `collection_files_path`: Input directory for URL files

## Usage Examples

**Process all URLs for years 2000-2024:**
```bash
python run_wbm.py Texas_URLs_Set1.csv 2000 2024
```

**Process with default year range (2000-2024):**
```bash
python run_wbm.py Texas_URLs_Set1.csv
```

**Process multiple sets in sequence:**
```bash
for i in {1..10}; do
    python run_wbm.py Texas_URLs_Set${i}.csv 2000 2024
done
```

## Key Features

- **Smart resumption**: Automatically skips already-processed URLs and years
- **Rate limiting**: Respects Wayback Machine API limits (8 second delays)
- **Progress tracking**: Shows real-time progress and ETA
- **Error recovery**: Continues processing if individual URLs fail
- **Intermediate saves**: Periodically saves results to prevent data loss
- **Priority ranking**: Processes finance/bond-related pages first
- **Text processing**: Removes stopwords, applies stemming for cleaner data

## Troubleshooting

**Missing dependencies:**
```bash
pip install -r requirements.txt
```

**NLTK data missing:**
```python
import nltk
nltk.download('punkt')
nltk.download('stopwords')
```

**Scraper hangs or times out:**
- Check internet connectivity
- Wayback Machine API may be slow or down
- Increase `timeout_seconds` in config.py

**Out of memory:**
- Reduce `max_urls` (fewer pages per snapshot)
- Process smaller URL sets
- Reduce `max_sub_levels` (shallower crawl depth)

## Performance Notes

- Processing time: ~30-60 seconds per URL-year combination
- With 100 URLs and 25 years: expect 12-24 hours total runtime
- Rate limiting means this is intentionally slow to respect Wayback Machine servers
- Runs are resumable - safe to stop and restart anytime
