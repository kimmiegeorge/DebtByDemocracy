# Border-State Website Analysis Data

The shared scraper is now in
`Python/Clean/City_Websites/updated-wayback-json-parsing-expanded-border-state/`.
For the restored Alabama/Arkansas cities, use the separate
[AL/AR collection pipeline](AL_AR/README.md). This builder automatically includes
its approved roster and processed files when present. Set `AL_AR_WEBSITE_DIR`
to use a different supplement location. `WEBSITE_OUTPUT_DIR` overrides step
01's output directory for validation.

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
county demographics from the preceding calendar year, the shared full-Mergent
debt panel lagged one year, and state fiscal-monitoring
adoption dates, and caps the five disclosure counts at the sample's 1st and
99th percentiles using observed order statistics (R `quantile(type = 1)`). It
also creates the state-year cluster identifier and the subgroup indicators
used by the revenue-vote robustness and dark-green interaction regressions.
The county controls use the same BEA 2001–2022 source files as step 01;
`county_control_year` records the preceding year. No same-year fallback is
applied. It reads election rules from the same clean Mergent Stata file as step 01.
It also merges all fields from
`Data/State Policies/20260929_state_policy_comparison.csv` by state, including
debt-limit measures, municipal TEL severity, property-tax limits, municipal
GAAP reporting requirements, audit indicators, and state GFOA award averages.
Source fields and missing values are retained. These state-level measures are
repeated across website years; dated measures are not historical policy panels.
The current regressions still use their existing controls.
Build this input with the scripts in
[`State_Policy_Comparison`](../../State_Policy_Comparison/README.md).
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
`WEBSITE_ANALYSIS_DATA` overrides step 02's input intermediate for validation.
