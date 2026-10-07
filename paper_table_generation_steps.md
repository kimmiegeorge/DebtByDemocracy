# Paper Table Generation Steps

Audit date: 2026-09-17

Live sources reviewed: `/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/main.tex`, `251214_draft.tex`, `tables_figures.tex`, `appendix.tex`, `online_appendix.tex`, `response_1.tex`, and `response_2.tex`.

Clean output locations created:

- R clean scripts: `Code/R/Clean`
- R clean table outputs: `Code/R/Clean/output/revision_tables`
- Python clean scripts: `Code/Python/Clean`
- Clean intermediate data target: `Data/Clean_Intermediate`

Clean reruns write generated intermediate data under `Data/Clean_Intermediate` with stable, undated filenames. Source data inputs, including Mergent `.dta`, BEA, WRDS/RavenPack raw files, state-policy inputs, and Stata-built source files, remain in the original `Data` tree.

## Tables Included in the Live Documents

The paper includes these main-table wrappers in order:

1. `tables/clean/processed/summary_stats.tex`
2. `tables/clean/processed/websites.tex`
3. `tables/clean/processed/media_coverage.tex`
4. `tables/clean/processed/tx_election_time_series.tex`
5. `tables/clean/processed/tx_election_outcomes.tex`
6. `tables/clean/processed/trade_before_maturity.tex`
7. `tables/clean/processed/outstanding_debt.tex`
8. `tables/clean/processed/debt_choice_full_sample.tex`
9. `tables/clean/processed/substitution.tex`
10. `tables/clean/processed/issuer_yields_full_sample.tex`
11. `tables/clean/processed/point_in_time_robustness.tex`

The paper appendix includes `alternative_sample_robustness.tex`; the online appendix includes `media_coverage_dpc.tex`, `county_debt.tex`, `wild_cluster_bootstrap_border_tests.tex`, and `media_coverage_exclude_month_zero.tex`. Response 1 includes `supermajority_media_response.tex`, `point_in_time_debt_choice_alternative_controls.tex`, and `media_coverage_panel_b_ols.tex`. Response 2 includes `leave_one_out_summary.tex` and `tx_election_time_series_poisson.tex`.

## Run Order

### 1. Stata data build layer

Not audited per instruction. The R/Python analysis layer reads Stata-generated `.dta` files, especially:

- `Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta`
- `Data/Mergent/clean/260716_city_issuerlevel_yieldspread.dta`
- `Data/BEA/countydemos_1999_2026.dta`

### 2. Python intermediate data layer

Run these only when rebuilding intermediate datasets. The clean copies are in `Code/Python/Clean`.

The canonical border-pair universe is defined in `Code/Config/border_state_pairs.csv`.
Both border-sample construction and every active paper regression read that file.
The full border universe contains 14 pairs and excludes only Rhode
Island/Massachusetts and Maine/New Hampshire because the RI and ME treatments
are undefined. All border-state debt-choice and yield-spread tests use the
separate `include_debt_yield` flag. This restricts the 2012 point-in-time, 2017
point-in-time, and full-period issuer-aggregate designs to the same six pairs
where the treated state has `city_rev_vote == 0`.

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
| `Code/R/Clean/01_websites.R` | Clean website panel, state-monitoring policy, Mergent issuances | Tables 2 and 4 plus the Table 1 website panel |
| `Code/R/Clean/02_media_coverage.R` | Mergent issuances, RavenPack media panel, border sample | Table 3 plus the Table 1 media panel |
| `Code/R/Clean/03_election_outcomes.R` | Clean Texas election, website, media, and Mergent files | Tables 4 and 5, the Table 1 election panel, and the Response 2 PPML table |
| `Code/R/Clean/03_texas_media_event_time.R` | Texas election and issuance media panels | Event-time figure associated with Table 4 |
| `Code/R/Clean/04_trade_before_maturity.R` | Clean MSRB trading file and border sample | Table 6 plus the Table 1 trading panel |
| `Code/R/Clean/05_census_mergent_point_in_time_debt_choice.R` | Clean 2017 Census-Mergent cross sections | Tables 7, 8, 10, and 11 plus the Table 1 issuer panel |
| `Code/R/Clean/06_point_in_time_purpose_substitution.R` | Clean 2017 DPC purpose panel | Table 9 and its associated figure |
| `Code/R/Clean/07_alternative_sample_robustness.R` | 2012 and full-period alternative samples | Paper appendix robustness table |
| `Code/R/Clean/08_media_coverage_dpc.R` | Clean DPC media file and Mergent issuances | Online-appendix DPC media table |
| `Code/R/Clean/09_census_county_debt_issuance_share_2017.R` | Clean Census county debt files | Online-appendix county debt table |
| `Code/R/Clean/10_wild_cluster_bootstrap_border_tests.R` | Clean website, media, point-in-time, and MSRB files | Online-appendix wild-bootstrap table and wrapper |
| `Code/R/Clean/11_media_coverage_exclude_month_zero.R` | Clean RavenPack/Mergent media files | Online-appendix month-zero robustness table and wrapper |

## Wrapper-to-Component Mapping

The included `tables/clean/processed/*.tex` files are wrappers that `\input{}` generated fragments from `tables/clean/raw`.

| Paper wrapper | Component tables |
|---|---|
| `processed/summary_stats.tex` | `website_descriptives`, `media_descriptives`, `election_descriptives`, `secondary_market_descriptives`, `issuer_level_desc` |
| `processed/websites.tex` | `website_diff_means_table`, `websites_regression` |
| `processed/media_coverage.tex` | `media_diff_means_table`, `media_coverage`, `media_coverage_super_majority` |
| `processed/tx_election_time_series.tex` | `tx_website_time_series_reg`, `tx_city_month_reg` |
| `processed/tx_election_outcomes.tex` | `tx_failed_and_margin_websites`, `tx_failed_and_margin` |
| `processed/trade_before_maturity.tex` | `trade_before_maturity_full_sample_tax`, `trade_before_maturity_border_sample_tax` |
| `processed/outstanding_debt.tex` | `point_in_time_census_debt_poisson_2017_full_sample` |
| `processed/debt_choice_full_sample.tex` | `point_in_time_debt_choice_2017_allgo`, `point_in_time_debt_choice_2017_utgo_only` |
| `processed/substitution.tex` | `point_in_time_purpose_category_amount_ppml_2017_full_sample`, `point_in_time_purpose_revenue_share_2017_full_sample` |
| `processed/issuer_yields_full_sample.tex` | `point_in_time_yield_spread_2017_full_sample` and both bond-type panels |
| `processed/media_coverage_dpc.tex` | `media_coverage_dpc` |
| `output/processed/point_in_time_robustness.tex` | `point_in_time_robustness_border_state`, `point_in_time_robustness_super_majority` |

## Audit Notes

- Several wrappers are generated by the clean R scripts; the remaining wrappers are maintained in `tables/clean/processed` in Overleaf.
- `99_promote_tables_to_overleaf.R` copies reviewed raw fragments from `Code/R/Clean/output/revision_tables` to `tables/clean/raw`; it does not replace the live processed wrappers.
- Several scripts use hard-coded dated input files. The date suffixes should be treated as part of the reproducibility contract.
- All active border-state debt-choice and yield-spread regressions use the same six identifying pairs: Georgia/Tennessee, Louisiana/Mississippi, Michigan/Wisconsin, North Carolina/Tennessee, Ohio/Kentucky, and West Virginia/Kentucky.
- All other border analyses use the shared 14-pair universe. Outcome-specific missing data can change observations, but those regressions do not apply ad hoc pair exclusions.
- The clean R copies redirect table outputs away from Overleaf. The clean Python copies are isolated, but many original Python scripts use one `data_dir` variable for both inputs and outputs; output redirection should be finished before running them end-to-end.
