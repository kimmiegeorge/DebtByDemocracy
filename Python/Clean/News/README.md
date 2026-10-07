# RavenPack news pipeline

Steps 2–5 build the city/entity mapping, issuance-level article coverage, and
lagged background coverage. Once the step-5 and border-match intermediates are
current, prepare the R analysis data with:

```sh
python3 'Python/Clean/News/6. Prepare Media Coverage Regression Data.py'
Rscript R/Clean/02_media_coverage.R
```

Step 6 uses Polars for transformations and pyreadstat to read issuer metadata
and election requirements from the Mergent Stata file. It reads:

- `Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta`
- `Data/Clean_Intermediate/News/Issuance_Lvl_News_With_Lagged_News.csv`
- `Data/Clean_Intermediate/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv`
- `Config/border_state_pairs.csv`

It writes to `Data/Clean_Intermediate/News`:

- `media_full_sample_regression_data.csv`: full issuance sample with issuer
  FIPS/name, nonmissing GO-vote and employment restrictions,
  prior-issuance indicators, logged sources, capped article counts, the existing
  revenue-vote missing-value convention, and the dark-green indicator.
- `media_border_state_regression_data.csv`: employment-complete paper border
  pairs with prior-issuance indicators, state-year cluster labels, logged sources,
  the same article caps, revenue-vote fill, and `keep_drop_dark_green`.
- `media_regression_data_diagnostics.csv`: row counts and shared article caps.

The migration preserves first-observation issuer metadata and stable
issuer-month sorting. Border lags are computed before filtering paper pairs,
including duplicate issuer-month records. Both samples use the full-sample
UTGO/positive-background-coverage 1st and 99th empirical percentiles, equivalent
to R `quantile(type = 1)`. The original input files are left intact.

`MEDIA_REGRESSION_DIR` overrides Python's output folder. In R,
`MEDIA_FULL_REGRESSION_DATA` and `MEDIA_BORDER_REGRESSION_DATA` override the two
inputs; `RESULTS_DIR` overrides table output. R retains the runtime
`EXCLUDE_STATE` option for border-sample sensitivity runs, so state exclusions
do not require rebuilding the prepared data. Descriptives, explicit regressions,
and table formatting remain in R. Supermajority membership is assigned in R
from `00_state_policy_definitions.R`; shared table helpers are loaded from
`00_helper_functions.R`.

County GDP, population, and personal income are matched to `year - 1` from
`Data/BEA/countydemos_1999_2026.dta`. `county_control_year` and
`county_control_fips` record the join. Existing issuance indicators, employment
screens, source counts, and article caps are preserved. County GDP starts in
2001, so 2001 issuances use a documented 2001 GDP fallback while population
and personal income remain at 2000. `county_gdp_fallback` identifies those
rows and `county_gdp_control_year` records the GDP source year. Other missing
or nonpositive BEA values remain missing.

For DPC media step 08, run:

```sh
python3 'Python/Clean/DPC_News/Prepare DPC Media Regression Data.py'
Rscript R/Clean/08_media_coverage_dpc.R
```

This creates `Data/Clean_Intermediate/DPC Data/News/dpc_media_regression_data.csv`
from the existing DPC issuance file using the same prior-year BEA source.
`DPC_MEDIA_REGRESSION_DIR` overrides Python's output directory and
`DPC_MEDIA_REGRESSION_DATA` overrides the input read by R.
