# Python Clean Folder Changes Made

- Created `Code/Python/Clean` and copied traced upstream scripts into topic subfolders.
- Preserved the original scripts' filenames to maintain traceability to the source code.
- Created `Data/Clean_Intermediate` as the designated destination for future clean intermediate outputs.
- Redirected Clean Python intermediate outputs to `Data/Clean_Intermediate` using stable, undated filenames.
- Updated Clean R table scripts to read regenerated intermediate datasets from `Data/Clean_Intermediate` where those files are produced by the Clean Python chain.
- Split the Clean website scripts into `City_Websites/Texas` and `City_Websites/Border_States`, and renamed them for their analysis branch.
- Updated active Clean Mergent `.dta` input paths to `260716` for city bond/issuer yield-spread files, including replacing prior `citycountyschool` inputs with the city-level bond file.
- Did not run Python scripts and did not overwrite existing data.
- Did not edit Stata files.

## Final audit fixes

- Replaced integer coercion of `seed_issuer_id` in the outstanding-debt build with a stable `issuer_key` consisting of the ID in integer tenths, normalized state, and normalized issuer name. This preserves decimal issuer IDs and disambiguates the three numeric IDs reused by different municipalities.
- Added validated issuer joins and fail-fast key checks to the outstanding-debt build, then regenerated its issuer-year panel, annual summaries, regressions, and diagnostics. The corrected balanced panel contains 2,704 issuers and 67,600 issuer-year rows for 2000-2024, with no duplicate issuer-years.
- Propagated the same composite `issuer_key` through both Census COG scripts. The exact-match file now retains all six municipalities represented by the three reused numeric IDs, and the 2012/2017 cross sections join Mergent debt, controls, and border memberships on `issuer_key` rather than numeric ID alone.
- Corrected continuing-disclosure aggregation to reduce the one-row-per-submission-CUSIP source to one row per issuer-year-submission before summing disclosure counts or calculating type-specific totals. Added `disclosure_aggregation_diagnostics.csv`, propagated `issuer_key`, and regenerated the issuer-year and border issuer-year panels. The correction removes 2,390,272 duplicated disclosure counts; binary filed-disclosure indicators are unchanged by construction and were verified against the corrected counts.
- Made the Clean MSRB pipeline self-contained: the issuance-, bond-, and trade-before-maturity consumers now read trade-level markup and yield files from `Data/Clean_Intermediate/MSRB/Processed`, where the Clean producers write them, rather than from legacy `Data/MSRB/Processed` outputs. The producers now resolve paths relative to the project, enumerate only raw years 2005-2023 (so newer raw files cannot silently enter outputs labeled `2005_2023`), and no longer require an unused WRDS import. Updated Polars expressions that blocked execution while preserving their existing time-window values. Rebuilt and ran all five MSRB stages successfully; the resulting issuance, bond, and trade-before-maturity files contain 17,791, 79,188, and 324,933 rows, respectively.
- Added `traded_before_maturity_raw`, `retail_traded_before_maturity_raw`, and `institutional_traded_before_maturity_raw` to the bond-level MSRB/CD output. These use all raw 2005-2023 customer transactions (`P` and `S`) and the existing $100,000 retail/institutional cutoff, without requiring a same-day interdealer trade or nonnegative markup. The original markup-sample indicators are retained unchanged. After regeneration, the original overall, retail, and institutional indicator totals remain 143,908, 123,659, and 80,408; the corresponding raw totals are 177,283, 149,899, and 113,332.
- Added buy-only raw indicators using MSRB `S` records (dealer sales to customers), with the same timing window and $100,000 cutoff. Their overall, retail, and institutional bond totals are 175,824, 148,617, and 102,600. The R table script accepts `TRADE_BEFORE_MATURITY_OUTCOMES=raw_buys` and writes separate `_raw_buys` outputs.
- Added strict-`> $100,000` institutional sensitivity indicators for all raw customer trades and raw customer buys. The corresponding institutional bond totals are 93,021 and 81,218, versus 113,332 and 102,600 under `>= $100,000`. The cutoff audit is reproducible in `audit_institutional_100k_cutoff.py`, and the R table variants are `raw_gt_100k` and `raw_buys_gt_100k`.
- Added a nonmissing-yield raw sensitivity variant. Requiring a reported, non-NaN MSRB trade yield changes the overall, retail, and institutional raw bond totals from 177,283, 149,899, and 113,332 to 177,140, 149,808, and 113,199. The R table variant is `raw_yield` and writes separate `_raw_yield` outputs.
- Added `TRADE_BEFORE_MATURITY_DISCLOSURE=amount` to replace the binary continuing-disclosure control with `avg_disclosures_per_year_before_maturity`. This writes separate `_cd_amount` table and descriptive outputs for every trade-outcome variant while preserving the indicator specification as the default.
- Added a `same_day_match` outcome sensitivity that reproduces the legacy customer-price and same-day positive interdealer-price match but retains finite negative markups. Its overall, retail, and institutional bond totals are 144,008, 123,810, and 80,731, versus 143,908, 123,659, and 80,408 in the nonnegative-markup legacy outcomes.
- Added `TRADE_BEFORE_MATURITY_RATING=rating_fe` to replace the linear numeric-rating control with the complete 24-level `rating_fe` fixed effect, including an explicit Unrated category. The variant writes separate `_rating_fe` outputs and retains the full estimation samples.

## Copied script groups

- `News`
- `DPC_News`
- `City_Websites/Texas`
- `City_Websites/Border_States`
- `Election_Outcomes`
- `Border_States`
- `MSRB`
- `Census_COG_Finance`
- `Debt_Outstanding`
- `Continuing_Disclosure`
- `Yield_Spreads`
