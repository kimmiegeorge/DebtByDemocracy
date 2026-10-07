#!/usr/bin/env bash
set -euo pipefail

SCRAPER_DIR="/Users/kmunevar/Dropbox/Voting on Bonds/Code/Python/City Websites/updated-wayback-json-parsing-texas"
TARGET_DIR="empty_url_year_reruns_260601"

cd "$SCRAPER_DIR"

for year in 2013 2014 2015 2016 2017 2018 2019 2020; do
  python3 run_wbm.py "${TARGET_DIR}/TX_empty_${year}.csv" "$year" "$year"
done

