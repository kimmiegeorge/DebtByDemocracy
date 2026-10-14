# Mergent vintage update

Update date: 2026-10-13

## Decision

The paper pipeline now treats the following as its canonical Mergent contract:

- bond level: `260716_city_cusiplevel_statereq_purpose_yieldspread.dta`
- issuer level: `260716_city_issuerlevel_yieldspread.dta`
- annual outstanding debt:
  `Data/Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv`,
  which is built from the canonical `260716` bond file

`261013_mergent_raw.dta` is a separate coauthor expanded-sample project and is
explicitly excluded. The role of every approved Mergent input is recorded in
`Config/mergent_inputs.csv`, and `Python/Clean/validate_mergent_inputs.py`
checks the active paper consumers.

## Changes made

| Pipeline location | Before | After | Reason |
|---|---|---|---|
| Purpose step 01 | `260610_city_cusiplevel_statereq_purpose_yieldspread.dta` | `260716_city_cusiplevel_statereq_purpose_yieldspread.dta` | Start the DPC merge from the final paper sample and policy classifications |
| Purpose step 02 | `260709_city_cusiplevel_statereq_purpose_yieldspread.dta` | `260716_city_cusiplevel_statereq_purpose_yieldspread.dta` | Use the same classifications and maturity source as step 01 and the no-refundings cross section |
| Texas rejection-risk annual debt | `Data/Mergent/Outstanding Debt/260709_issuer_year_outstanding_debt.csv` | `Data/Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv` | Use the shared annual panel already used by the website pipeline and built from `260716` |
| Texas event-time issuance events | `Data/TX/241120_tx_issue_level.dta` | `260716_city_cusiplevel_statereq_purpose_yieldspread.dta` | Align the figure's GO issuance events with the related Texas tables |
| Mergent governance | Dates were distributed across scripts with no executable contract check | `Config/mergent_inputs.csv` plus `Python/Clean/validate_mergent_inputs.py` | Prevent a pre-`260716` or coauthor-expanded input from re-entering an active paper consumer |

Supporting changes make `PURPOSE_REGRESSION_DIR`, `RESULTS_DIR`, `FIGURES_DIR`,
`TX_REJECTION_RISK_OUTPUT_DIR`, `TX_REJECTION_RISK_DATA_DIR`,
`TEXAS_EVENT_ISSUANCE_DATA`, and `PROCESSED_RESULTS_DIR` usable for isolated
migration runs. Purpose step 02 also deduplicates its final column lists; the
prior code failed after the policy merge because fields such as
`glm_proactive` appeared twice.

## Intentional vintages retained

These are not stale substitutes for the paper's canonical GO/revenue sample:

- `260917_city_cusiplevel_finsample_allbonds.dta` adds other debt for the
  established paper issuers and remains limited to all-bond extensions.
- `260923_cusiplevel_allbonds_inclrefund.dta` remains limited to the
  refunding-inclusive sensitivity and associated audit utilities.
- `260709` references remain only in explicitly named legacy/reconciliation
  audit scripts; they no longer feed an active paper or response table.
- `261013_mergent_raw.dta` remains outside the paper pipeline.

## Staged result comparison

No production data, paper table, or paper figure was overwritten during this
comparison. All updated pipelines were run in temporary staging directories.

### Purpose substitution

The input merge changed from 326,735 rows under `260610` to 324,958 rows under
`260716`. Step 02 changed from the 327,506-row `260709` classification source to
the 324,958-row `260716` source.

Despite those upstream differences:

- all 2012 and 2017 issuer-purpose keys were retained;
- zero category amounts, revenue amounts, revenue shares, vote variables, or
  DPC-observation flags changed in the final purpose panels;
- the existing validation against the preserved baseline passed;
- the two main purpose table fragments and both dark-green purpose fragments
  were byte-identical;
- the 2017 purpose pie figure was byte-identical.

Therefore the purpose tables and figure do not change.

### Texas rejection-risk mechanism

The shared `260716` annual debt panel changes 659 Texas issuer-year debt values
over 2001--2020 relative to the old input. Of these, 620 are previously missing
values that become observed. The annual regression sample consequently changes
from 4,580 to the intended balanced 5,200 city-years.

Panel A is byte-identical: its website and media regressions do not use the
annual outstanding-debt field.

The active ten-year Panel B changes as follows:

| Outcome | Before | After | Inference |
|---|---:|---:|---|
| Any city bond election | -0.028** | -0.027** | Unchanged inference |
| Any bond issuance | -0.022 | -0.028 | Remains insignificant |
| GO bond issuance | -0.031* | -0.026 | Loses 10% significance |
| Revenue bond issuance | 0.015 | 0.013 | Remains insignificant |
| Observations | 4,580 | 5,200 | Adds 620 complete city-years |

The all-history election estimate changes from -0.038*** to -0.040***; its
inference is unchanged. Threshold-robustness issuance coefficients move
modestly. The information-response columns are exactly unchanged because they
do not use the annual debt panel.

The annual descriptive means also change because the sample is complete:

| Variable | Before | After |
|---|---:|---:|
| Prior ISD failure | 0.268 | 0.261 |
| Any city bond election | 0.072 | 0.065 |
| Any bond issuance | 0.200 | 0.187 |
| GO bond issuance | 0.131 | 0.116 |
| Revenue bond issuance | 0.090 | 0.080 |

### Texas media event-time figure

The canonical file contains the same 726 Texas GO issues and 689 raw
city-month issue events as the retired issue-level source. Ten event labels are
reassigned because the canonical file contains corrected seed-issuer names.
After matching to the figure's eligible city-month media panel and imposing the
balanced window:

- issuance events change from 346 to 339;
- the number of represented cities remains 101;
- election-event estimates are unchanged;
- all 13 GO-issuance bins move slightly, with a maximum absolute mean-coverage
  change of 0.002805, or 0.28 percentage points.

The updated figure is therefore visually very similar but not numerically
identical. Its new binned-summary CSV makes future comparisons auditable.

## Promotion status

The source-code migration is implemented and validated, but the changed Texas
Panel B fragments and event-time PDF have not been copied into the production
output folder or paper repository. They should be promoted only after the
sample expansion and the loss of 10% significance for GO issuance are accepted.
