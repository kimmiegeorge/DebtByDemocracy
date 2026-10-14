# Clean analysis pipeline

This folder contains the R estimation and table-generation layer for the paper,
appendices, online appendix, and response documents. Python scripts prepare the
analysis datasets; these R scripts estimate the models and write raw TeX table
fragments to `R/Clean/output/revision_tables` unless an override is supplied.

> [!IMPORTANT]
> A routine full-table rerun starts from existing raw/acquired data and approved
> clean intermediates. Do **not** include website scraping, external downloads,
> API/OpenAI classification jobs, the raw Mergent rebuild, refunding sensitivity
> step 05d, or table promotion with `--apply` in an unattended full run. Those
> stages are refresh, sensitivity, or publication operations and require
> separate review.

The current cross-script consistency issues and the active paper dependency
inventory are documented in [`../../pre_conference_audit.md`](../../pre_conference_audit.md).

## Pipeline at a glance

```text
fixed raw/acquired sources
        |
        v
Python/Clean preparation and validation
        |
        v
Data/Clean_Intermediate regression-ready files
        |
        v
R/Clean/01--15 estimation and table generation
        |
        v
R/Clean/output/revision_tables (staging)
        |
        v
manual review + 99 promotion dry-run
        |
        v
paper tables/clean/raw + maintained processed wrappers/figures
```

There is not currently one driver script that safely performs every arrow. Run
the preparation families below only when their inputs have changed, then run the
R generation steps into an empty staging directory. Do not use the existing
output folder as evidence of provenance: more than one sensitivity script can
currently write some of the same filenames.

## Shared configuration and helpers

- `00_helper_functions.R`: mean-difference tables and shared media formatting
- `00_border_pair_definitions.R`: approved paper border pairs, backed by
  `Config/border_state_pairs.csv`
- `00_modify_etable_rounding.R`: common `fixest::etable` formatting
- `00_state_policy_definitions.R`: shared state-policy group definitions
- `00_tax_privilege_definitions.R`: low-tax-privilege construction, backed by
  `Config/low_state_tax_privilege_states.csv`

These files are sourced by analysis scripts and are not run directly.

## Routine preparation stages

The commands below describe dependencies; they are not a command to refresh all
raw sources. Use existing approved intermediates unless a source refresh is
intentional.

### 1. State-policy snapshot

The website, media, MSRB, and point-in-time pipelines merge fields from
`Data/State Policies/20260929_state_policy_comparison.csv`.

If the fixed policy source files have changed, run:

```sh
python3 Python/Clean/State_Policy_Comparison/aggregate_state_policies.py
```

`prepare_addnl_state_policy_sources.py` refreshes/manualizes source inputs and is
not part of a routine table rerun.

### 2. Shared Mergent-derived inputs

The routine paper pipeline uses the `260716` city bond and issuer files as its
canonical paper-sample Mergent source. The roles and permitted extensions are
recorded in [`../../Config/mergent_inputs.csv`](../../Config/mergent_inputs.csv).
Run the contract check after changing a Mergent-dependent path:

```sh
python3 Python/Clean/validate_mergent_inputs.py
```

`260917_city_cusiplevel_finsample_allbonds.dta` is retained only for analyses
that require non-GO/non-revenue bonds for the established paper issuer sample.
`260923_cusiplevel_allbonds_inclrefund.dta` is a refunding-inclusive sensitivity
input. Neither is a substitute for the canonical GO/revenue paper file.

The following builders supply widely reused intermediates:

```sh
python3 'Python/Clean/Debt_Outstanding/1. Build Issuer Year Outstanding Debt Panel.py'
python3 'Python/Clean/Debt_Outstanding/2. Build Full Mergent Annual Outstanding Debt Panel.py'
python3 'Python/Clean/Yield_Spreads/Compute Yield Spreads.py'
```

Run them only when deliberately rebuilding those shared inputs. The
`261013_mergent_raw.dta` build belongs to a separate coauthor expanded-sample
project and is explicitly excluded from this paper pipeline. It is not a
routine prerequisite or an approved paper input.

### 3. Website disclosure

Read
[`../../Python/Clean/City_Websites/Border_States/README.md`](../../Python/Clean/City_Websites/Border_States/README.md).
For an ordinary rerun, reuse the approved step-01 website intermediate and run
only the regression-data preparation if necessary:

```sh
python3 Python/Clean/City_Websites/Border_States/02_prepare_border_state_website_regression_data.py
Rscript R/Clean/01_websites.R
```

Step 02 writes
`border_state_website_regression_data_261013_with_recovered_al_ar.csv` with
sample screens, prior-year county controls, lagged Mergent debt, policy fields,
caps, and regression indicators. `WEBSITE_ANALYSIS_DATA`,
`WEBSITE_REGRESSION_DATA`, and `WEBSITE_DATA_DATE` select nondefault inputs.
R step 01 now includes the state GAAP-requirement and state-audit indicators in
the descriptive fragment. Its mean-difference fragment contains only the five
website-disclosure outcomes; debt and county covariates remain regression
controls rather than mean-difference rows.

Do not run the Wayback collection/parsing tree or the AL/AR collection workers
as part of a routine table rerun. Run website step 01 only when the approved
collected website corpus itself has changed.

### 4. RavenPack media coverage

Read [`../../Python/Clean/News/README.md`](../../Python/Clean/News/README.md).
Once the step-5 and border-match intermediates are frozen:

```sh
python3 'Python/Clean/News/6. Prepare Media Coverage Regression Data.py'
Rscript R/Clean/02_media_coverage.R
```

Python step 6 creates the full and border regression-ready files, prior-issuance
indicators, logged source counts, shared article caps, policy fields, and
robustness indicators. `MEDIA_REGRESSION_DIR`, `MEDIA_FULL_REGRESSION_DATA`, and
`MEDIA_BORDER_REGRESSION_DATA` override defaults. `EXCLUDE_STATE` is reserved
for an explicit border sensitivity run.

R step 02's mean-difference fragment now reports only the winsorized 12-month
article count. Prior issuance, source count, amount, and county demographics
remain controls in the regression specifications.

News steps 2--5 rebuild entity mapping and article histories. They are upstream
refresh operations, not required when the current clean intermediates are
approved.

### 5. Texas election and information panels

The main Texas regressions use a common 2001--2020 analysis window. If the
election/media/website inputs change, prepare them with:

```sh
python3 Python/Clean/Election_Outcomes/05_prepare_tx_regression_inputs.py
Rscript R/Clean/03_election_outcomes.R
Rscript R/Clean/03_texas_media_event_time.R
```

The event-time script uses the canonical `260716` city-bond file for issuance
events, matching the related Texas table preparation. It writes a binned-summary
CSV to `PROCESSED_RESULTS_DIR` for numerical comparison. The retired Texas
issue-level source can be supplied with `TEXAS_EVENT_ISSUANCE_DATA` only for a
controlled migration comparison.

R step 03 constructs the election-outcome descriptives on the common 2001--2020
positive-amount sample and reports `ln(Amount)` there once, rather than in the
coverage-control block.

The prior-ISD-failure data used by election step 05 come from
[`../../Python/Clean/TX_Election_Exposure/README.md`](../../Python/Clean/TX_Election_Exposure/README.md).
Reuse the checked exposure outputs in a routine run. Do not redownload Census
geographies unless the boundary source is intentionally being refreshed.

The later rejection-risk mechanism has its own preparation:

```sh
python3 Python/Clean/TX_Rejection_Risk/01_prepare_tx_rejection_risk.py
Rscript R/Clean/13_tx_rejection_risk.R
```

That preparation combines the current Texas regression-ready files, Census
cross section, canonical `260716` issuance/issuer files, the shared
`260716`-based annual outstanding-debt panel, and spatial exposure files.
The main `Prior ISD Failure` measure requires an overlapping school district
to cover at least two-thirds of the city's land area and to have failed a bond
proposition during the preceding ten years. The reported overlap-threshold
robustness checks hold the same samples and specifications fixed and substitute
50-percent and 80-percent minimum coverage thresholds. An all-prior-election
version is generated separately as a lookback-window sensitivity.
`TX_REJECTION_RISK_OUTPUT_DIR` and `TX_REJECTION_RISK_DATA_DIR` keep audit runs
outside production directories.

### 6. MSRB trade-before-maturity outcomes

Read [`../../Python/Clean/MSRB/README.md`](../../Python/Clean/MSRB/README.md).
When the raw MSRB/disclosure inputs or policy snapshot have changed:

```sh
python3 Python/Clean/MSRB/01_build_trade_before_maturity.py
python3 Python/Clean/MSRB/02_prepare_trade_regression_data.py
Rscript R/Clean/04_trade_before_maturity.R
```

Otherwise the R script may reuse the approved regression-ready CSVs.
`MSRB_PROCESSED_DIR`, `MSRB_REGRESSION_DIR`, and `RESULTS_DIR` override defaults.

### 7. Census/Mergent point-in-time cross sections

The intended main-paper path excludes refundings:

```sh
python3 'Python/Clean/Census_COG_Finance/1. Clean Census COG City Debt.py'
python3 'Python/Clean/Census_COG_Finance/2b. Build Census Mergent Debt Cross Sections No Refundings.py'
python3 'Python/Clean/Census_COG_Finance/3. Build 2017 County Debt Issuance Share.py'
python3 'Python/Clean/Census_COG_Finance/9. Build Texas 2017 Rejection Risk Cross Section.py'
Rscript R/Clean/05_census_mergent_point_in_time_debt_choice.R
Rscript R/Clean/05b_census_mergent_point_in_time_debt_choice_with_dark_green.R
Rscript R/Clean/09_census_county_debt_issuance_share_2017.R
```

Steps 3 and 9 are needed only for their corresponding online-appendix and
mechanism outputs. The principal cross sections are in
`Data/Clean_Intermediate/Census COG Finance/processed/no_refundings`.

`05c_census_mergent_point_in_time_debt_choice_with_other.R` is response-only and
currently depends on objects created by step 05. Source or run it immediately
after step 05 in the same R session; it is not a standalone `Rscript` entry
point. Before running 05c, rebuild
`Data/Clean_Intermediate/Mergent/Clean/bond_level_off_yield_spread_allbonds.csv`
with `Python/Clean/Yield_Spreads/Compute Yield Spreads.py`. The spread build and
05c both use `261013_city_cusiplevel_finsample_allpubdebt_v2020.dta`, so the
all-bond and Other yield outcomes include the expanded COO/COP and
residual-other debt universe. Step 05c restricts that source to
`new_money == 1` before constructing any debt, yield, or bond-control measure,
excluding refunding bonds from the analysis. Its canonical outputs should be
under `revision_tables/with_other`.

The response robustness table combines Revenue and Other into one exhaustive
non-GO category. Step 05c writes Panels A--C and E as
`with_other/panel_*_other_*.tex`; step 06c writes Panel D and assembles
`output/processed/with_other_robustness.tex`. The detailed separate Revenue,
Other, and COO/COP fragments remain available as diagnostics, but the assembled
robustness table uses only the combined Revenue/Other outcomes.

Do **not** run Census step 2a or R step 05d in the routine production path. They
are refunding-inclusive sensitivity stages. Step 05d is quarantined by default:

- raw TeX fragments go to `output/revision_tables/refundings`;
- its processed wrapper goes to `output/processed/refundings`;
- every artifact is named with the suffix `_with_refundings`; and
- the script stops if either output is pointed at the corresponding main
  production directory.

To test the sensitivity in an empty staging tree, use the dedicated overrides:

```sh
REFUNDINGS_RESULTS_DIR='/absolute/path/to/staging/revision_tables/refundings' \
REFUNDINGS_PROCESSED_RESULTS_DIR='/absolute/path/to/staging/processed/refundings' \
Rscript R/Clean/05d_census_mergent_point_in_time_debt_choice_refundings.R
```

`RESULTS_DIR` remains a fallback for the raw fragments, but it must not be the
main `output/revision_tables` directory. Prefer `REFUNDINGS_RESULTS_DIR` so the
sensitivity destination is explicit. Review these results separately; do not
promote them into main-paper filenames without an explicit specification
decision.

### 8. Purpose substitution

Read
[`../../Python/Clean/Purposes_Substitution/README.md`](../../Python/Clean/Purposes_Substitution/README.md).
If the purpose inputs or point-in-time issuer universe changed:

```sh
python3 Python/Clean/Purposes_Substitution/01_merge_dpc_purposes_all_issuers.py
python3 Python/Clean/Purposes_Substitution/02_build_point_in_time_purpose_panels.py
python3 Python/Clean/Purposes_Substitution/03_validate_expanded_purpose_panels.py
Rscript R/Clean/06_point_in_time_purpose_substitution.R
Rscript R/Clean/06b_point_in_time_purpose_substitution_with_dark_green.R
```

Step 03 must pass before the R scripts are treated as production results.
`PURPOSE_REGRESSION_DIR`, `PURPOSE_BASELINE_DIR`, and
`PURPOSE_VALIDATION_DIR` override defaults. Purpose steps 01 and 02 both use the
canonical `260716` bond file and the issuer universe comes from the matching
no-refundings point-in-time cross section.

### 9. DPC media robustness

If the approved DPC issuance/classification file is current, run only its final
preparation and R table step:

```sh
python3 'Python/Clean/DPC_News/Prepare DPC Media Regression Data.py'
Rscript R/Clean/08_media_coverage_dpc.R
```

The DPC article pull and OpenAI batch classification scripts are source-refresh
operations and are excluded from a routine full-table run.

### 10. Leave-one-out sensitivities

Step 12 reuses the prepared website, media, MSRB, and 2017 no-refundings
point-in-time files used by the production scripts. It does not rebuild lags,
winsorization, disclosure outcomes, or border matches:

```sh
Rscript R/Clean/12_leave_one_out_control_states.R
```

For full-sample media, retail-trading, debt-choice, and yield specifications,
the script omits each of the seven canonical no-referendum control states in
turn. For border specifications, it separately omits each approved state-border
pair and all pairs linked to each represented control state. Debt choice is run
for separate all-GO and UTGO-only samples, matching step 05; website coverage
includes all five disclosure outcomes from step 01. The media border runs
restore the submitted prior-issuance values from
`input/media_submission_border_prior_12.csv` before estimation.

Outputs default to `output/leave_one_out`: the full estimate and summary CSVs,
the raw and processed summary fragments, and a baseline-regression fragment.
Set `LEAVE_ONE_OUT_RESULTS_DIR` to keep a rerun in an empty staging directory.
The script honors `WEBSITE_REGRESSION_DATA`, `WEBSITE_DATA_DATE`,
`MEDIA_FULL_REGRESSION_DATA`, `MEDIA_BORDER_REGRESSION_DATA`, and
`MSRB_REGRESSION_DIR`.

## R generation order

After all required prepared inputs are frozen, use a new staging output folder:

```sh
export RESULTS_DIR='/absolute/path/to/empty/staging/revision_tables'
export LEAVE_ONE_OUT_RESULTS_DIR='/absolute/path/to/empty/staging/leave_one_out'
```

Then run the applicable scripts in this order:

1. `01_websites.R` — website descriptives, mean differences, main estimates,
   and restricted/dark-green response result
2. `01b_gfoa_awards.R` — GFOA mechanism/supplement if it is included in the
   target document; it is not active in the current main dependency graph
3. `02_media_coverage.R` — media descriptives, main estimates, restricted
   sample, and supermajority media fragment
4. `03_election_outcomes.R` — Texas descriptives, time series, outcome tests,
   and response PPML result
5. `03_texas_media_event_time.R` — Texas event-time figure
6. `04_trade_before_maturity.R` — full and border trading results
7. `05_census_mergent_point_in_time_debt_choice.R` — main point-in-time
   descriptives, outstanding debt, debt choice, and yield tables
8. `05b_census_mergent_point_in_time_debt_choice_with_dark_green.R` —
   dark-green Appendix panels A, B, and D
9. `05c_census_mergent_point_in_time_debt_choice_with_other.R` — response-only;
   run in the same R session as step 05 until it is made standalone
10. `06_point_in_time_purpose_substitution.R` — purpose tables and 2017 pie
    figure
11. `06b_point_in_time_purpose_substitution_with_dark_green.R` — dark-green
    Appendix purpose panel C
12. `07_alternative_sample_robustness.R` — alternative point-in-time/full-period
    appendix table
13. `08_media_coverage_dpc.R` — DPC online-appendix table
14. `09_census_county_debt_issuance_share_2017.R` — county-debt online appendix
15. `10_wild_cluster_bootstrap_border_tests.R` — border wild-cluster inference
16. `11_media_coverage_exclude_month_zero.R` — media timing robustness
17. `12_leave_one_out_control_states.R` — response leave-one-out estimates,
    summary fragments, and baseline table
18. `13_tx_rejection_risk.R` — Texas rejection-risk mechanism panels
19. `14_supermajority.R` — point-in-time supermajority mechanism panel
20. `15_point_in_time_border_state_robustness.R` — raw Appendix border-city
    fragment; the maintained processed wrapper is not rewritten here

The point-in-time debt-choice and yield specifications in steps 10, 12, and 15
now use the same approved debt/yield border pairs, full-sample eligibility and
two-CUSIP screens, outcome-specific controls, border-pair fixed effects, and
state-year clustering. Step 12 also asserts that every requested omission is
present before estimation. Its website, media, and trading baselines mirror the
corresponding controlled production specifications.

Table 1 is assembled from descriptive fragments produced by steps 01--05; it
has no separate estimation script.

## Response-only and legacy response scripts

- `r1_01_supermajority_response_table.R`
- `r1_02a_point_in_time_debt_choice_allgo_alt_controls.R`
- `r1_02b_point_in_time_debt_choice_utgo_alt_controls.R`
- `r1_03_media_coverage_panel_b_ols.R`

These support earlier response specifications. They are not all active in the
current `response_2.tex`. In particular, the active online-appendix
supermajority wrapper reads `media_coverage_super_majority.tex`, written by R
step 02, rather than the older `r3b_media_supermajority.tex` promotion entry.

## Steps excluded from a routine full run

| Stage | Why it is excluded |
|---|---|
| Wayback website collection, updated JSON parsing, and AL/AR workers | Network/scraping and manually reviewed source collection; reuse the approved corpus |
| DPC control-state pull and OpenAI batch classification | External acquisition/API work with cost and nondeterministic service state |
| Texas Census boundary downloader | Network acquisition; use cached, reviewed geography files |
| TX property-tax pull | Network/archive acquisition and not an active paper-table prerequisite |
| CAFR OpenAI/EMMA retry scripts | External API/download work and not in the active paper dependency graph |
| `State_Policy_Comparison/prepare_addnl_state_policy_sources.py` | Source refresh/manual review, not table generation |
| `Mergent/261013_clean_mergent_raw.py` | Separate coauthor expanded-sample build; not an approved paper-pipeline input |
| Census step 2a and R step 05d | Refunding-inclusive sensitivity; step 05d is safely quarantined but is not part of the main-paper run |
| `R/Archive/12_tx_county_failure_screen.R` and `R/Archive/13_tx_isd_overlap_failure_validation.R` | Retired Texas feasibility/validation diagnostics; they are not numbered production steps |
| Archived map/statute code | Archive code is not an approved routine production stage |
| `99_promote_tables_to_overleaf.R --apply` | Mutates the paper repository and must follow numerical/visual review |

## Output review and promotion

`99_promote_tables_to_overleaf.R` is dry-run by default:

```sh
Rscript R/Clean/99_promote_tables_to_overleaf.R \
  --source='/absolute/path/to/staging/revision_tables' \
  --dest='/Users/kmunevar/Repos/overleaf-voting-on-bonds/tables/clean/raw'
```

The script's built-in destination is the Dropbox Apps Overleaf folder, not the
Git clone shown above. Always pass `--dest` explicitly when promoting to the
clone. Review the dry-run list and diffs before adding `--apply`; use
`--overwrite` only for specifically approved replacements.

The current default allowlist is incomplete for the active paper and response:
it omits some main, dark-green, mechanism, leave-one-out, and restricted-sample
fragments, and one supermajority name is stale. The nested `with_other`
diagnostic and five-panel robustness fragments are now allowlisted and trigger
recursive scanning automatically. Until the rest of the manifest is repaired,
pass an explicit `--files=` list for omitted files and verify every active TeX
dependency manually. Processed wrappers and figures are not promoted by this
script.

## Validation checklist

Before updating the paper:

1. Confirm the exact source versions and record a hash/manifest for every
   prepared analysis file.
2. Run R scripts into empty staging directories.
3. Confirm that no filename is written by more than one production script.
4. Diff every active raw table fragment against the paper repository.
5. Verify that wrappers include every panel described in their notes.
6. Check that table notes state the actual sample, dates, controls, fixed
   effects, clustering, and debt/refunding treatment.
7. Promote only approved files with an explicit destination.
8. Compile `main.tex` and the response document and visually inspect every
   table and figure.

## Environment overrides

Common overrides include:

- `RESULTS_DIR`: normal raw-table staging directory
- `LEAVE_ONE_OUT_RESULTS_DIR`: step-12 output directory
- `WEBSITE_ANALYSIS_DATA`, `WEBSITE_REGRESSION_DATA`, `WEBSITE_DATA_DATE`
- `MEDIA_REGRESSION_DIR`, `MEDIA_FULL_REGRESSION_DATA`,
  `MEDIA_BORDER_REGRESSION_DATA`
- `DPC_MEDIA_REGRESSION_DIR`, `DPC_MEDIA_REGRESSION_DATA`
- `MSRB_PROCESSED_DIR`, `MSRB_REGRESSION_DIR`
- `PURPOSE_REGRESSION_DIR`, `PURPOSE_BASELINE_DIR`,
  `PURPOSE_VALIDATION_DIR`
- `TX_REJECTION_RISK_OUTPUT_DIR`, `TX_REJECTION_RISK_DATA_DIR`
- `TEXAS_EVENT_ISSUANCE_DATA`, `FIGURES_DIR`, `PROCESSED_RESULTS_DIR`
- `EXCLUDE_STATE`: explicit border-state sensitivity only

Prefer absolute paths for staging overrides. Never point a test run directly at
the paper's `tables/clean/raw` directory.
