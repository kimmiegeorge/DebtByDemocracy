# Alabama and Arkansas website supplement

This separate collection uses the corrected 100-km border sample and the shared
scraper in `Python/Clean/City_Websites/updated-wayback-json-parsing-expanded-border-state/`.
It follows the existing annual 2015–2020 collection, with at most 50 URLs per
tree, depth 3, and the same snapshot selection, priority keywords, text
processing, and network delays. It does not change the historical collections.

Run from the Code repository root:

```sh
python3 Python/Clean/City_Websites/Border_States/AL_AR/01_prepare_collection.py
```

The first run writes `issuer_website_mapping.csv` under
`Data/Websites/Border States Website Data/AL_AR/`. For each issuer, enter its
official host in `URL`, a verification link in `source_url`, and
`include_in_collection = 1`. Use additional rows for historical host aliases.
Leave ambiguous entities unapproved and explain them in `notes`; some Mergent
issuer names are abbreviated or may refer to entities other than city halls.
Rerunning step 01 preserves this mapping and builds the approved issuer/host
roster, deduplicated `urls.csv`, and `issuers_needing_websites.csv`.

```sh
python3 Python/Clean/City_Websites/Border_States/AL_AR/01_prepare_collection.py
python3 Python/Clean/City_Websites/Border_States/AL_AR/02_collect_wayback.py --dry-run
python3 Python/Clean/City_Websites/Border_States/AL_AR/02_collect_wayback.py
python3 Python/Clean/City_Websites/Border_States/AL_AR/03_process_jsons.py
python3 Python/Clean/City_Websites/Border_States/01_create_border_state_website_analysis_data.py
python3 Python/Clean/City_Websites/Border_States/02_prepare_border_state_website_regression_data.py
```

Install the shared scraper's `requirements.txt` and NLTK stopwords before
collecting. For a small initial run, use `--limit-hosts 1 --start-year 2015
--end-year 2015`. Set `AL_AR_WEBSITE_DIR` on all commands to use an alternate
collection directory.

Raw outputs go to `AL_AR/WBM/Annual Files/JSON_YEAR/`, and processed outputs
to `AL_AR/WBM/Processed/res/` and `bow/`. The runner skips only host-years with
matching nonempty result and word-count JSON files, not just a downloaded CDX
index. Incomplete host-years are rebuilt; completed host-years are retained.
`collection_status.csv` records completed, failed, and unavailable host-years;
`processing_status.csv` records conversion outcomes and scraped row counts.

The shared website builder reads this supplement when present, appends its
issuer roster to the historical roster, and computes the same outcomes and
controls. When historical host aliases are supplied, it selects the host with
the most collected URLs for each issuer/year/border pair, avoiding duplicate
city-year observations. Step 02 retains the existing 50-URL regression sample restriction:
collection alone does not guarantee that every city-year enters regressions.
Adding AL/AR also changes the sample-wide winsorization cutoffs.
