#!/usr/bin/env bash
set -euo pipefail

SCRAPER_DIR="/Users/kmunevar/Dropbox/Voting on Bonds/Code/Python/City Websites/updated-wayback-json-parsing-texas"
TARGET_DIR="empty_url_year_reruns_260601"
STATUS_FILE="/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/missing_url_scrape_status_260601.txt"
LOG_FILE="/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/missing_url_scrape_260601.log"

write_status() {
  {
    echo "Updated: $(date)"
    echo "$1"
    echo
    echo "Log: $LOG_FILE"
  } > "$STATUS_FILE"
}

cd "$SCRAPER_DIR"

echo "Started missing URL-year scrape at $(date)" > "$LOG_FILE"
write_status "Starting missing URL-year scrape."

for year in 2013 2014 2015 2016 2017 2018 2019 2020; do
  url_file="${TARGET_DIR}/TX_empty_${year}.csv"
  n_urls=$(python3 -c "import pandas as pd; print(len(pd.read_csv('/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/${url_file}')))")
  write_status "Current year: ${year}
URL file: ${url_file}
URLs in file: ${n_urls}
Status: running"

  {
    echo
    echo "===== YEAR ${year} START $(date) ====="
  } >> "$LOG_FILE"

  python3 run_wbm.py "$url_file" "$year" "$year" 2>&1 | while IFS= read -r line; do
    echo "$line" >> "$LOG_FILE"
    if [[ "$line" == *"ETA:"* ]] || [[ "$line" == *"Total work:"* ]] || [[ "$line" == *"Processing years"* ]]; then
      write_status "Current year: ${year}
URL file: ${url_file}
URLs in file: ${n_urls}
Latest scraper update:
${line}"
    fi
  done

  {
    echo "===== YEAR ${year} END $(date) ====="
  } >> "$LOG_FILE"
done

write_status "Completed missing URL-year scrape."
echo "Completed missing URL-year scrape at $(date)" >> "$LOG_FILE"

