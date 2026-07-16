# Paper Table Generation Steps

Audit date: 2026-07-16

Paper source reviewed: `/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/251214_draft.tex`.

Clean output locations created:

- R clean scripts: `Code/R/Clean`
- R clean table outputs: `Code/R/Clean/output/revision_tables`
- Python clean scripts: `Code/Python/Clean`
- Clean intermediate data target: `Data/Clean_Intermediate`

Clean reruns write generated intermediate data under `Data/Clean_Intermediate` with stable, undated filenames. Source data inputs, including Mergent `.dta`, BEA, WRDS/RavenPack raw files, state-policy inputs, and Stata-built source files, remain in the original `Data` tree.

## Tables Included in the Draft

The draft includes the following table wrapper files:

1. `tables/revision_tables/processed/summary_stats.tex`
2. `tables/revision_tables/processed/websites.tex`
3. `tables/revision_tables/processed/media_coverage.tex`
4. `tables/revision_tables/processed/tx_election_time_series.tex`
5. `tables/revision_tables/processed/tx_election_outcomes.tex`
6. `tables/revision_tables/processed/trade_before_maturity.tex`
7. `tables/revision_tables/processed/debt_choice_full_sample.tex`
8. `tables/revision_tables/processed/debt_choice_super_majority.tex`
9. `tables/revision_tables/processed/issuer_yields_full_sample.tex`
10. `tables/revision_tables/processed/debt_choice_border_state.tex`

The `response.tex` file also includes `processed/debt_choice_supermajority_alt_control`, `processed/media_coverage_dpc`, and `processed/media_supermajority`.

## Run Order

### 1. Stata data build layer

Not audited per instruction. The R/Python analysis layer reads Stata-generated `.dta` files, especially:

- `Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta`
- `Data/Mergent/clean/260716_city_issuerlevel_yieldspread.dta`
- `Data/BEA/countydemos_1999_2026.dta`

### 2. Python intermediate data layer

Run these only when rebuilding intermediate datasets. The clean copies are in `Code/Python/Clean`.

| Script | Purpose | Main inputs | Main outputs used downstream |
|---|---|---|---|
| `News/2. Merge RP Entity Lat Long with FIPS.py` | Adds FIPS to RavenPack city entities. | WRDS RavenPack entity mapping | `Data/Clean_Intermediate/News/Ravenpack_Cities_With_FIPS.csv` |
| `News/3. Merge RP IDs with Mergent Data.py` | Maps RavenPack entities to Mergent issuers. | Mergent clean bond data, cleaned RavenPack FIPS file | `Data/Clean_Intermediate/News/RP_Mergent_Mapping.csv` |
| `News/4. Pull Time Series of Articles.py` | Builds city-month and issuance-level RavenPack media measures. | RavenPack article parquet, Mergent clean bond data, BEA controls | `Data/Clean_Intermediate/News/*HeadlineFilter*`, event plot CSVs |
| `News/5. Compute Lagged Non Bond Media Coverage.py` | Builds lagged issuance-level media variables. | Clean headline-filter outputs, clean RP-Mergent mapping | `Data/Clean_Intermediate/News/Issuance_Lvl_News_With_Lagged_News.csv` |
| `Border_States/Identify Counties in Border States Wider Sample.py` | Creates border sample and border media files. | Mergent clean bond data, county lat/long, cleaned issuance-level news | `Data/Clean_Intermediate/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv`; `Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv` |
| `City_Websites/Border_States/create_border_state_website_analysis_data.py` | Creates border-state city-year website variables. | Wayback processed JSON/BOW data, border issuer website collection, Mergent/BEA | `Data/Clean_Intermediate/Websites/border_state_website_data_with_recovered.csv` |
| `City_Websites/Texas/create_texas_website_analysis_data.py` | Creates Texas website city-year and election-level variables. | Texas website collection, Texas elections, Mergent/BEA | `Data/Clean_Intermediate/Websites/Texas/time_series_website_data.csv`; `Data/Clean_Intermediate/Websites/Texas/election_level_website_data.csv` |
| `Election_Outcomes/4. Pull Time Series ... FIXED.py` | Creates Texas election media files with failed elections. | Texas elections, clean RP-Mergent mapping, Mergent purpose data | `Data/Clean_Intermediate/TX/City_Month_Elections_News_WithFailed.csv`; `Data/Clean_Intermediate/TX/News/Election_Level_With_News_WithFailed.csv` |
| `MSRB/2. Compute Trade Level Markup.py` | Computes trade-level markups. | MSRB raw/processed trade data | `Data/Clean_Intermediate/MSRB/Processed/All_Trade_Markup_2005_2023.gzip` |
| `MSRB/3. Compute Trade Level Yield Spread.py` | Computes trade-level yield spreads. | MSRB trades, yield curve | `Data/Clean_Intermediate/MSRB/Processed/All_Trade_Yields_2005_2023.gzip` |
| `MSRB/Any Trade Before Maturity with CD Data.py` | Builds bond-level secondary trading measure. | Mergent clean bond data, MSRB markup/yield files, continuing disclosure | `Data/Clean_Intermediate/MSRB/Processed/Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv` |
| `DPC_News/Create Issuance Level DPC News Variables.py` | Builds issuance-level DPC media measures. | DPC article/classification data, Mergent clean bond data | `Data/Clean_Intermediate/DPC Data/News/Issuance_Lvl_DPC_News.gzip` |
| `Census_COG_Finance/*.py` | Builds census debt panel and point-in-time cross sections. | Census COG files, Mergent bond data, clean border sample | `Data/Clean_Intermediate/Census COG Finance/processed/census_mergent_debt_cross_section_*.csv` |

### 3. R table generation layer

Run these after the Python intermediate data files exist.

| Script | Inputs | Outputs |
|---|---|---|
| `Code/R/Clean/websites.R` | `Data/Clean_Intermediate/Websites/border_state_website_data_with_recovered.csv`; `Data/State Monitoring Policy/state_enforcement_adoption_years.csv`; Mergent clean `.dta` | `website_descriptives.tex`, `website_diff_means_table.tex`, `websites_regression.tex`, `websites_issuance_time_series_reg.tex` |
| `Code/R/Clean/media_coverage.r` | Mergent clean `.dta`; `Data/Clean_Intermediate/News/Issuance_Lvl_News_With_Lagged_News.csv`; clean border RP file | `media_descriptives.tex`, `media_diff_means_table.tex`, `media_coverage.tex`, `media_coverage_super_majority.tex`, `article_counts.png` |
| `Code/R/Clean/election_outcomes.R` | Clean TX election media files; clean TX website files; Mergent clean `.dta`; BEA controls | `election_descriptives.tex`, `tx_failed_and_margin.tex`, `tx_city_month_reg.tex`, `tx_website_time_series_reg.tex`, `tx_failed_and_margin_websites.tex` |
| `Code/R/Clean/trade_before_maturity.R` | `Data/Clean_Intermediate/MSRB/Processed/Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv`; clean border sample; clean website and media disclosure files | `secondary_market_descriptives.tex`, `trade_before_maturity_full_sample_tax.tex`, `trade_before_maturity_border_sample_tax.tex`, disclosure heterogeneity tables |
| `Code/R/Clean/debt_choice.r` | `Data/Mergent/clean/260716_city_issuerlevel_yieldspread.dta`; clean border sample | `issuer_level_desc.tex`, `debt_choice_allgo.tex`, `debt_choice_utgo_only.tex`, `yield_spread_allgo.tex`, `yield_spread_utgo_only.tex`, `debt_choice_border_state_all_go_only.tex`, `debt_choice_super_majority.tex` |
| `Code/R/Clean/media_coverage_dpc.R` | Clean DPC issuance-level parquet; Mergent clean `.dta` | `media_coverage_dpc.tex` |
| `Code/R/Clean/census_mergent_point_in_time_debt_choice.R` | Clean Census-Mergent cross-section CSVs | Point-in-time debt, yield, and census debt tables |

## Wrapper-to-Component Mapping

The included `processed/*.tex` files are wrappers that `\input{}` component tables from `tables/revision_tables` and sometimes `tables/submission_tables`.

| Paper wrapper | Component tables |
|---|---|
| `processed/summary_stats.tex` | `website_descriptives`, `media_descriptives`, `election_descriptives`, `secondary_market_descriptives`, `issuer_level_desc` |
| `processed/websites.tex` | `website_diff_means_table`, `websites_regression` |
| `processed/media_coverage.tex` | `media_diff_means_table`, `media_coverage`, `media_coverage_super_majority` |
| `processed/tx_election_time_series.tex` | `tx_website_time_series_reg`, `tx_city_month_reg` |
| `processed/tx_election_outcomes.tex` | `tx_failed_and_margin_websites`, `tx_failed_and_margin` |
| `processed/trade_before_maturity.tex` | `trade_before_maturity_full_sample_tax`, `trade_before_maturity_border_sample_tax` |
| `processed/debt_choice_full_sample.tex` | `debt_choice_allgo`, `debt_choice_utgo_only`, `debt_choice_super_majority` |
| `processed/issuer_yields_full_sample.tex` | `yield_spread_allgo`, `yield_spread_utgo_only` |
| `processed/debt_choice_border_state.tex` | `debt_choice_border_state_all_go_only` |
| `processed/media_coverage_dpc.tex` | `media_coverage_dpc` |
| `processed/media_supermajority.tex` | `media_coverage_super_majority` |

## Audit Notes

- I did not find a script that generates the `tables/revision_tables/processed/*.tex` wrapper files. They appear to be hand-written or copied wrappers around generated component tables.
- `summary_stats.tex` still inputs two components from `tables/submission_tables` while most other wrappers input from `tables/revision_tables`.
- Several scripts use hard-coded dated input files. The date suffixes should be treated as part of the reproducibility contract.
- The clean R copies redirect table outputs away from Overleaf. The clean Python copies are isolated, but many original Python scripts use one `data_dir` variable for both inputs and outputs; output redirection should be finished before running them end-to-end.
