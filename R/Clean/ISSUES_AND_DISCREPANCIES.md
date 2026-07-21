# R Clean Folder Issues and Discrepancies

## Table wrappers

- The paper includes `tables/revision_tables/processed/*.tex`, but the R scripts generate component files in `tables/revision_tables`.
- I did not find an R script that creates the `processed` wrappers. Those wrappers appear to be manually maintained.
- `processed/summary_stats.tex` inputs `tables/submission_tables/website_descriptives` and `tables/submission_tables/media_descriptives`, while the active R scripts write those files to `tables/revision_tables`.

## Path consistency

- The original R scripts use absolute local paths and `~/Dropbox/...` paths.
- The clean copies now write table outputs to `Code/R/Clean/output/revision_tables`.
- Input paths still point to the original `Data` folder so the cleaned scripts do not require copying large datasets.

## Output naming

- In the original workflow, `debt_choice.r` wrote `yield_spread_utgo_only.tex` twice from two separate model blocks. The clean copy now writes the bond-type version to `yield_spread_utgo_only_bond_type_spreads.tex` and leaves the two-column paper table at `yield_spread_utgo_only.tex`.
- Robustness tables were written to an Overleaf robustness folder in the original scripts. The official clean R scripts now omit those alternative clustering/sample outputs.

## Sample and filtering discrepancies

- `media_coverage.r` defines `bond_prior_12` using `diff <= 12`, while `media_coverage_dpc.R` defines the analogous DPC variable using `diff < 12`. This changes the treatment of issuers with a prior issuance exactly 12 months earlier.
- `media_coverage.r` descriptive statistics restrict to `rolling_sum_monthly_article_count_12 > 0`, but the main regressions use the broader filtered issuance sample. This can make the descriptive panel describe a different sample than the regression panel.
- `media_coverage_dpc.R` restricts to issuers with `dpc_issuer_has_any_articles == 1` and `dpc_lifetime_article_count > 0`, then further uses a complete-case regression sample. This differs from the RavenPack media table, which does not impose the same lifetime-coverage restriction.
- `websites.R` restricts the website sample to `total_subs == 50`, but some Texas election outcome code only applies that restriction in the website-election branch and not in the media-election branch. The restriction may be intended, but it is not common across all information-related analyses.
- `election_outcomes.R` filters the election media sample to `unique_sources_12m_prior > 0`, excluding elections in places without prior media-source coverage. This should be disclosed clearly because it changes the estimand from all Texas elections to covered-source elections.
- `trade_before_maturity.R` merges media disclosure by `seed_issuer_id`, `year`, and `month` after calling `unique()` on the disclosure file. If there are multiple issuances for the same issuer-month with different media context, this collapses to a shared issuer-month disclosure measure.
- `debt_choice.r` now joins the issuer-level outcomes to border groups by state and issuer name, avoiding reused `seed_issuer_id` values. After this correction, 55 of 430 non-RI border issuers enter more than one border-pair group, creating 60 extra issuer-group rows. This may be intended for a border-pair design, but it means the issuer-level border regression weights multi-border issuers more heavily.
- The current issuer-level file has one reused whole-number ID and two reused decimal IDs: three `seed_issuer_id` values each identify two different issuer names. Joins for the new border and purpose tables therefore use state and issuer name rather than ID alone.
- The aggregate issuer file records `year = 2001` for every observation. Consequently, state-year clustering in the issuer-level border cross section is numerically identical to state clustering; the printable wrapper discloses this.
- The Texas election-outcome paper wrapper text says the table uses 872 city bond elections, but diagnostics find 1,134 raw media-election rows, 700 media-election rows after current restrictions, 1,492 raw website-election rows, and 499 website-election rows after `total_subs > 10`.

## Coding issues that can change reported results

- Several scripts recode `city_rev_vote` and `city_go_vote` state-by-state in-line (`MO`, `RI`) rather than relying only on upstream law variables. These recodes should be documented and checked against the state-law source file.
- The clean R scripts previously classified `ND` as a municipal GO-bond supermajority state while omitting `OK` and `WV`; older archived scripts also contained competing lists. The corrected shared definition is `CA`, `ID`, `MO`, `OK`, `SD`, `WA`, and `WV` in `state_policy_definitions.R`.
- Earlier clean R scripts used an upper-two-quintile high tax privilege indicator. An intermediate clean revision intended to use the bottom two quintiles but included several third-quintile states and omitted several fourth/bottom-quintile states. The current clean scripts source the exact fourth-plus-bottom Babina et al. (2021, Table 2) state list from `tax_privilege_definitions.R`.
- See `DEEPER_AUDIT_FINDINGS.md` for quantified diagnostics and recommended fixes.

## Stata dependency

- Several R scripts read `.dta` files generated upstream by Stata. Those Stata scripts were not audited or copied.
