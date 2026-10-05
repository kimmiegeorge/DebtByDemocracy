# Border-State Website Analysis Data

Run these scripts in order from the repository root:

```sh
python3 Python/Clean/City_Websites/Border_States/01_create_border_state_website_analysis_data.py
python3 Python/Clean/City_Websites/Border_States/02_prepare_border_state_website_regression_data.py
Rscript R/Clean/01_websites.R
```

Step 01 rebuilds the website intermediate from existing original and recovered
collection inputs, including Mergent issuance measures, county BEA controls,
and financial-document counts. It does not perform website scraping. If its
intermediate is already current, run step 02 directly.

Step 02 applies the paper border-pair and city-year sample restrictions, merges
the shared full-Mergent debt panel lagged one year and state fiscal-monitoring
adoption dates, and caps the five disclosure counts at the sample's 1st and
99th percentiles using observed order statistics (R `quantile(type = 1)`). It
also creates the state-year cluster identifier and the subgroup indicators
used by the revenue-vote robustness and dark-green interaction regressions.
It reads election rules from the same clean Mergent Stata file as step 01.
The shared outstanding-debt panel must already exist; step 02 stops on duplicate
debt-panel keys or missing debt controls.

R reads the prepared file and handles descriptive statistics, regressions, and
table formatting. No state exclusions are applied.

Outputs:

- `Data/Clean_Intermediate/Websites/border_state_website_data_with_recovered.csv`
- `Data/Clean_Intermediate/Websites/missing_url_year_pairs.csv`
- `Data/Clean_Intermediate/Websites/border_state_website_seed_id_update_diagnostics.csv`
- `Data/Clean_Intermediate/Websites/border_state_website_regression_data.csv`

Paths above are relative to the project directory containing `Code/` and `Data/`.
Step 01 preserves its existing output names for other consumers. Step 02 and
the R script both support `WEBSITE_REGRESSION_DATA` to override the prepared
file path, for example when validating in a temporary directory.
