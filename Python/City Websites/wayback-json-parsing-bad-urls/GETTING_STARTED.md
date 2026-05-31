# Getting Started with Bad URLs Recovery Pipeline

## Quick Summary

You have **583 URL-year pairs** that only collected 1 snapshot instead of ~50. This happens because the pipeline selected snapshots with:
- **Redirects** (HTTP 301/302)
- **Empty pages** with no sub-URLs
- **Filtered content**

**Good news**: Most of these can likely be recovered by finding better snapshots from the same year!

## What This Pipeline Does

1. **Investigates** each bad URL by checking the CDX files
2. **Tests** multiple alternative snapshots from the same year
3. **Finds** snapshots with valid sub-URLs (status 200, actual content)
4. **Reports** which URLs can be recovered vs. truly unrecoverable
5. **(Future)** Re-scrapes using the best snapshots found

## Quick Start

### Option 1: Run the Test Script

```bash
cd /Users/kmunevar/Repos/VotingonBonds/City\ Websites/wayback-json-parsing-bad-urls
./run_investigation.sh
```

This will investigate the first 5 bad URLs as a test (takes ~2-3 minutes).

### Option 2: Manual Run

```bash
cd /Users/kmunevar/Repos/VotingonBonds/City\ Websites/wayback-json-parsing-bad-urls

# Install dependencies (if needed)
pip install -r requirements.txt

# Investigate first 10 URLs
python3 investigate_bad_urls.py --limit 10 --sample-size 5

# Investigate ALL bad URLs (takes ~2-3 hours for 583 URLs)
python3 investigate_bad_urls.py --sample-size 10
```

## Understanding the Output

After running, check the `reports/` directory:

### 1. `investigation_results.json`
Detailed results for each URL-year pair:
```json
{
  "www.ishpemingcity.org_2017": {
    "host": "www.ishpemingcity.org",
    "year": 2017,
    "total_snapshots": 985,
    "valid_snapshots": 89,
    "best_snapshot": {
      "timestamp": "20170126121511",
      "url": "https://web.archive.org/web/20170126121511/...",
      "sub_url_count": 47,
      "status": 200
    },
    "recommendation": "RECOVERABLE"
  }
}
```

### 2. `investigation_summary.json`
Overall statistics:
```json
{
  "total_investigated": 10,
  "recoverable": 7,
  "marginal": 2,
  "unrecoverable": 1,
  "recovery_rate": 70.0
}
```

### 3. `recoverable_urls.csv`
Ready-to-use list of URLs that can be re-scraped:
```csv
host,year,timestamp,url,sub_url_count
www.ishpemingcity.org,2017,20170126121511,https://web.archive.org/...,47
```

## Configuration

Edit `config.py` to customize:

```python
# Number of snapshots to test per URL (higher = more thorough but slower)
sample_size: int = 10

# Minimum sub-URLs to consider successful
min_suburls_threshold: int = 5

# Request timeout
timeout: int = 30
```

## Expected Results

Based on the investigation of `www.ishpemingcity.org` 2017:
- ✅ **Many CDX snapshots available** (100+ for most URLs)
- ✅ **Multiple status 200 snapshots** exist
- ✅ **Alternative snapshots likely have sub-URLs**
- 📈 **Estimated recovery rate**: 60-80% of bad URLs

## Next Steps

1. **Run test investigation** on 5-10 URLs first
2. **Review results** to verify the approach works
3. **Run full investigation** on all 583 URLs (~2-3 hours)
4. **Check recoverable_urls.csv** to see how many can be recovered
5. **(Future)** Re-scrape the recoverable URLs using better snapshots

## Recommendations

### For Testing (Fast)
```bash
python3 investigate_bad_urls.py --limit 5 --sample-size 5
```
- Investigates: 5 URLs
- Tests: 5 snapshots per URL
- Time: ~2-3 minutes

### For Thorough Analysis
```bash
python3 investigate_bad_urls.py --limit 50 --sample-size 10
```
- Investigates: 50 URLs  
- Tests: 10 snapshots per URL
- Time: ~30-40 minutes

### For Full Recovery
```bash
python3 investigate_bad_urls.py --sample-size 15
```
- Investigates: All 583 URLs
- Tests: 15 snapshots per URL
- Time: ~3-4 hours

## Tips

1. **Start small** - Test with 5-10 URLs first
2. **Review CDX patterns** - Some URLs may have consistently bad snapshots
3. **Adjust threshold** - Lower `min_suburls_threshold` if recovery rate is low
4. **Be patient** - Full investigation takes time due to rate limiting
5. **Check logs** - Terminal output shows progress in real-time

## What Makes a URL Recoverable?

✅ **RECOVERABLE**: Found snapshot with ≥5 sub-URLs  
⚠️ **MARGINAL**: Found snapshot with 2-4 sub-URLs  
❌ **UNRECOVERABLE**: No valid snapshots or all have ≤1 sub-URL

## Example Investigation Output

```
================================================================================
🔍 Investigating: www.ishpemingcity.org, 2017
================================================================================
📊 Total snapshots in CDX: 985
📊 Snapshots in 2017: 13
📌 Originally scraped: 1 URLs

📈 Snapshot status codes:
   200: 2 snapshots
   301: 11 snapshots

✅ Valid snapshots (status 200): 2

🔍 Testing 2 snapshots:

  Testing: 20170122224410 (size: 12479)
  ❌ Status: 301

  Testing: 20170126121511 (size: 12933)
  ✅ Status: 200, Sub-URLs: 47

✨ BEST SNAPSHOT FOUND:
   Timestamp: 20170126121511
   Sub-URLs: 47
   💡 RECOMMENDATION: RECOVERABLE - Re-scrape with this snapshot
```

## Questions?

- Check the main README.md for detailed documentation
- Review config.py for all available settings
- Look at investigation_results.json for detailed per-URL analysis
