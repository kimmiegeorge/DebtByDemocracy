# Trade-before-maturity inputs

The active MSRB folder contains only the two steps needed for
`R/Clean/04_trade_before_maturity.R`. Run them from any working directory:

```sh
python3 "Python/Clean/MSRB/01_build_trade_before_maturity.py"
python3 "Python/Clean/MSRB/02_prepare_trade_regression_data.py"
Rscript "R/Clean/04_trade_before_maturity.R"
```

## Step 01: Bond outcomes

Inputs:

- `Data/MSRB/Raw Files/msrb_2005.gzip` through `msrb_2023.gzip` (Parquet).
- `Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta`.
- `Data/Continuing Disclosure/cleaned_daily_disclosure_data.csv`.

Writes `Data/Clean_Intermediate/MSRB/Processed/bond_trade_before_maturity.csv`.
Outcomes indicate any customer trade, any retail trade (par below $100,000),
any institutional trade (par at least $100,000), and any continuing disclosure
from offering + 30 days through maturity, inclusive. Trade observation is
limited to the available 2005–2023 files. Bonds without observed events receive
zero. A bond must have at least one day in that lifetime window.

This step reads raw customer purchases and sales directly. Markup and yield
calculations and a daily bond panel are unnecessary for these outcomes.

## Step 02: Regression samples

Reads the step-01 output, the expanded 100,000-meter Mergent border matches,
`Config/border_state_pairs.csv`, and `Config/low_state_tax_privilege_states.csv`.
The tax-privilege CSV is also read by `R/Clean/00_tax_privilege_definitions.R`.

Writes these files in `Data/Clean_Intermediate/MSRB/Regression`:

- `trade_full_sample_regression_ready.csv`
- `trade_border_sample_regression_ready.csv`

Applies the city, UTGO, observed vote-rule, callable, and post-2004 restrictions;
creates the three outcome aliases, disclosure control, low-tax-privilege
indicator, and state-year cluster; and matches paper border pairs by state and
issuer name. Bonds belonging to multiple border pairs retain one row per pair.
Missing regression controls remain for `fixest` to handle per specification.
Both samples also include every field from
`Data/State Policies/20260929_state_policy_comparison.csv`, matching the expanded
website controls: GAAP requirements, state audits, debt limits, tax and
expenditure limits, fiscal-monitoring snapshots, and source information.
Original policy names and missing values are preserved. Line breaks in policy
source text are replaced with spaces so R's `fread` infers numeric types correctly.
These dated measures
are state snapshots rather than historical policy panels. `state_monitor` is
separately calculated using issuance year and
`Data/State Monitoring Policy/state_enforcement_adoption_years.csv`, with
`before_sample` treated as 2009, consistent with the website preparation.
R loads these files and starts with descriptive statistics.

`MSRB_PROCESSED_DIR` overrides the step-01 output/step-02 input directory.
`MSRB_REGRESSION_DIR` overrides the step-02 output/R input directory.
`EXCLUDE_STATE` in step 02 excludes that state from the border sample only,
matching the former R behavior. R's `RESULTS_DIR` controls table output.

## Archived scripts

The previous markup, yield, issuance/bond aggregation, trade-outcome sensitivity,
and institutional-cutoff audit scripts are preserved in
`Python/Archive/MSRB/trade_before_maturity_legacy`. Existing older files in
`Python/Archive/MSRB` are preserved as well. The old processed
`Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv` is unchanged; other R
sensitivity scripts that still use it retain their existing workflow.
