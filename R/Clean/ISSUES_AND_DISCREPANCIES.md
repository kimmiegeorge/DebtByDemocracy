# R Clean Folder Issues and Discrepancies

## Table wrappers

- The live paper and response documents include wrappers under `tables/clean/processed` and raw fragments under `tables/clean/raw`.
- Several clean scripts create the processed wrappers that they own; other wrappers remain manually maintained in Overleaf.
- `99_promote_tables_to_overleaf.R` promotes only the raw fragments used by the live documents by default. It does not overwrite processed wrappers.

## Path consistency

- The original R scripts use absolute local paths and `~/Dropbox/...` paths.
- The clean copies now write table outputs to `Code/R/Clean/output/revision_tables`.
- Input paths still point to the original `Data` folder so the cleaned scripts do not require copying large datasets.

## Output naming

- The former aggregate `debt_choice.r` script was removed from the clean workflow because its outputs are not included in the live paper or response documents.
- Robustness tables were written to an Overleaf robustness folder in the original scripts. The official clean R scripts now omit those alternative clustering/sample outputs.

## Sample and filtering discrepancies

- `02_media_coverage.R` defines `bond_prior_12` using `diff <= 12`, while `08_media_coverage_dpc.R` defines the analogous DPC variable using `diff < 12`. This changes the treatment of issuers with a prior issuance exactly 12 months earlier.
- `02_media_coverage.R` descriptive statistics restrict to `rolling_sum_monthly_article_count_12 > 0`, but the main regressions use the broader filtered issuance sample. This can make the descriptive panel describe a different sample than the regression panel.
- `08_media_coverage_dpc.R` restricts to issuers with `dpc_issuer_has_any_articles == 1` and `dpc_lifetime_article_count > 0`, then further uses a complete-case regression sample. This differs from the RavenPack media table, which does not impose the same lifetime-coverage restriction.
- `01_websites.R` restricts the website sample to `total_subs == 50`, but some Texas election outcome code only applies that restriction in the website-election branch and not in the media-election branch. The restriction may be intended, but it is not common across all information-related analyses.
- `03_election_outcomes.R` filters the election media sample to `unique_sources_12m_prior > 0`, excluding elections in places without prior media-source coverage. This should be disclosed clearly because it changes the estimand from all Texas elections to covered-source elections.
- The Texas election-outcome paper wrapper text says the table uses 872 city bond elections, but diagnostics find 1,134 raw media-election rows, 700 media-election rows after current restrictions, 1,492 raw website-election rows, and 499 website-election rows after `total_subs > 10`.

## Coding issues that can change reported results

- Several scripts recode `city_rev_vote` and `city_go_vote` state-by-state in-line (`MO`, `RI`) rather than relying only on upstream law variables. These recodes should be documented and checked against the state-law source file.
- The clean R scripts previously classified `ND` as a municipal GO-bond supermajority state while omitting `OK` and `WV`; older archived scripts also contained competing lists. The corrected shared definition is `CA`, `ID`, `MO`, `OK`, `SD`, `WA`, and `WV` in `00_state_policy_definitions.R`.
- Earlier clean R scripts used an upper-two-quintile high tax privilege indicator. An intermediate clean revision intended to use the bottom two quintiles but included several third-quintile states and omitted several fourth/bottom-quintile states. The current clean scripts source the exact fourth-plus-bottom Babina et al. (2021, Table 2) state list from `00_tax_privilege_definitions.R`.
- See `DEEPER_AUDIT_FINDINGS.md` for quantified diagnostics and recommended fixes.

## Stata dependency

- Several R scripts read `.dta` files generated upstream by Stata. Those Stata scripts were not audited or copied.
