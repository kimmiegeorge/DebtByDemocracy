# Pre-conference pipeline audit

Audit date: 2026-10-13

## Scope and method

This audit traces every active table and figure included by `main.tex` in the
pulled paper repository at `/Users/kmunevar/Repos/overleaf-voting-on-bonds`.
That document includes `2610_draft.tex`, `appendix.tex`, `online_appendix.tex`,
and `response_2.tex`. The paper repository was updated with `git pull --ff-only`
before the audit.

The audit is a static provenance and specification review of the active TeX
inputs, the scripts in `Python/Clean` and `R/Clean`, their declared inputs, and
the table fragments currently present in the Code and paper repositories. I did
not rerun the complete pipeline: several acquisition stages scrape websites,
download external data, call APIs, or rebuild multi-gigabyte Mergent files, and
the Code worktree contains in-progress changes. Remediations made after the
initial review are marked as completed below.

## Executive summary

The production path is not yet a single reproducible pipeline. The highest
priority issues are:

1. **Mergent paper-sample alignment was completed after this audit.** Routine
   paper consumers now use the canonical `260716` bond/issuer files. The
   `260917` all-bond extension and `260923` refunding sensitivity retain narrow
   documented roles; the coauthor's `261013` expanded sample is excluded. See
   `mergent_vintage_update.md` for the before/after results.
2. **The refunding-output collision was resolved after this audit.** Step 05d
   now writes only to sensitivity-specific directories, uses
   `_with_refundings` filenames, and refuses the main production output roots.
   Its exploratory excess-debt result also has a separate, correctly labeled
   table.
3. **The active border table, wild-bootstrap table, and leave-one-out exercise
   do not currently use the same border specification/sample.** Their controls
   and identifying-pair screens differ.
4. **The response's expanded-sample outstanding-debt table is confounded.** It
   is generated only by the refunding-inclusive script, so it changes both the
   dark-green-state sample and the refunding treatment relative to the main
   table. Its note also incorrectly says dark-green states are excluded.
5. **The local and paper outputs are not synchronized.** The active website
   estimates and leave-one-out summary differ substantively between Code and
   the pulled paper. Paper prose reports the paper-repository website numbers,
   not the current Code output.
6. **Several paper descriptions no longer match the active tables.** The main
   text discusses descriptive rows that were removed; the Texas prose mixes the
   raw 2000--2021/872-proposition universe with the 2001--2020 regression
   window; and the Texas time-series wrapper and prose describe a Panel C whose
   TeX input is commented out.
7. **Promotion is incomplete.** `99_promote_tables_to_overleaf.R` omits several
   active fragments and defaults to a different Overleaf folder than the pulled
   Git repository.

These issues should be resolved before treating a fresh run as the conference
version. A safe routine-run sequence is documented in `R/Clean/README.md`.

## Active artifact inventory

### Main draft

| Paper artifact | Active processed/raw input | Generator and principal upstream input |
|---|---|---|
| State-policy comparison | `raw/20260929_state_policy_comparison_table` | `Python/Clean/State_Policy_Comparison/aggregate_state_policies.py`; `260716_city_issuerlevel_yieldspread.dta` plus policy sources |
| Summary statistics | `processed/summary_stats` | R steps 01--05 |
| Website disclosure | `processed/websites` | website Python steps 01--02; `R/Clean/01_websites.R`; `260716` Mergent inputs through the Python preparation |
| Media coverage | `processed/media_coverage` | `News/6. Prepare Media Coverage Regression Data.py`; `R/Clean/02_media_coverage.R`; `260716` Mergent bond file |
| Texas election time series | `processed/tx_election_time_series_with_failure_risk` | `Election_Outcomes/05_prepare_tx_regression_inputs.py`; `R/Clean/03_election_outcomes.R` |
| Texas election outcomes | `processed/tx_election_outcomes` | same Texas preparation and R step 03 |
| Trade before maturity | `processed/trade_before_maturity` | `MSRB/01_build_trade_before_maturity.py`, `02_prepare_trade_regression_data.py`; `R/Clean/04_trade_before_maturity.R`; `260716` Mergent bond file |
| Outstanding debt | `processed/outstanding_debt` | intended source: Census steps 1 and 2b plus `R/Clean/05_census_mergent_point_in_time_debt_choice.R` |
| Debt choice | `processed/debt_choice_full_sample` | Census step 2b no-refundings cross section; R step 05 |
| Purpose substitution | `processed/substitution` | `Purposes_Substitution/01`--`03`; `R/Clean/06_point_in_time_purpose_substitution.R` |
| Issuer yield spreads | `processed/issuer_yields_full_sample` | Yield Spreads Python step, Census step 2b, and R step 05 |
| Rejection-risk and supermajority mechanisms | `processed/mechanisms` | `TX_Rejection_Risk/01_prepare_tx_rejection_risk.py`; R steps 13 and 14 |

### Paper appendix and online appendix

| Artifact | Active processed input | Generator |
|---|---|---|
| Border-city point-in-time robustness | `border_state_robustness` | `R/Clean/15_point_in_time_border_state_robustness.R` |
| Dark-green robustness | `dark_green_robustness` | R steps 05b and 06b |
| Alternative measurement samples | `alternative_sample_robustness` | `R/Clean/07_alternative_sample_robustness.R` |
| DPC media coverage | `media_coverage_dpc` | DPC preparation Python step; R step 08 |
| County share of debt issuance | `county_debt` | Census Python step 3; R step 09 |
| Wild-cluster border inference | `wild_cluster_bootstrap_border_tests` | R step 10 |
| Media excluding issuance month | `media_coverage_exclude_month_zero` | R step 11 |
| Supermajority media response | `supermajority_media_response` | R step 02 writes `media_coverage_super_majority.tex`; the older `r1_01` path is not the active wrapper input |

### `response_2.tex`

| Artifact | Active input | Generator |
|---|---|---|
| Leave-one-out summary | `processed/leave_one_out_summary` | R step 12; Code output is under `output/leave_one_out`, not the normal revision-table root |
| Texas PPML time series | `processed/tx_election_time_series_poisson` | R step 03 |
| Expanded outstanding-debt sample | `processed/outstanding_debt_expanded_sample` | **Only R step 05d, the refunding-inclusive sensitivity script** |
| Restricted website sample | `processed/websites_restricted_sample` | R step 01 |
| Restricted media sample | `processed/media_coverage_restricted_sample` | R step 02 |
| Other-debt descriptives and debt choice | three direct `raw/with_other/...` inputs | R step 05c, which depends on objects created by R step 05 in the same R session |

### Figures and non-regression source material

| Artifact | Status |
|---|---|
| Texas media event-time PDF | Generated by `R/Clean/03_texas_media_event_time.R`; updated after this audit to use the same canonical `260716` Mergent issuance source as the related Texas tables |
| 2017 purpose/revenue pies | Generated by R step 06 |
| State map and law/statute pages | No active generator is present in `Python/Clean` or `R/Clean`; related map/statute code is archived or the asset is manually maintained |
| Regime pies and city-bond pies | No generator was found in the active clean-code folders |
| Anecdote table | No generator was found in the active clean-code folders |
| Woodlands, Sun Valley, Dunwoody, and website examples | Source screenshots/manual appendix exhibits rather than generated statistical figures |

The non-generated assets need a short provenance record: source, retrieval
date, script/location if one exists, and whether regeneration is expected.

## Findings and recommended actions

### 1. Mergent paper-sample vintages — resolved in code; promotion pending

The paper now uses `260716_city_cusiplevel_statereq_purpose_yieldspread.dta`
and its issuer-level companions as the canonical paper-sample contract. Purpose
steps 01 and 02 were migrated from `260610` and `260709`; the Texas
rejection-risk mechanism now uses the shared `260716`-based annual debt panel;
and the event-time figure now uses `260716` issuance events.

`260917_city_cusiplevel_finsample_allbonds.dta` remains an intentional all-bond
extension for the established paper issuers. `260923_cusiplevel_allbonds_inclrefund.dta`
remains an intentional refunding-inclusive sensitivity input. The coauthor's
`261013_mergent_raw.dta` expanded sample is explicitly excluded.

The contract is recorded in `Config/mergent_inputs.csv` and checked by
`Python/Clean/validate_mergent_inputs.py`. Staged comparisons show no changes to
the purpose tables or figure, but they do change the Texas annual rejection-risk
sample/results and slightly change the Texas event-time figure. Full details are
in `mergent_vintage_update.md`; those changed artifacts have not yet been
promoted to production or the paper repository.

The Texas rejection-risk definition has since been standardized at an exact
two-thirds minimum city-area overlap for the main ten-year specification. Its
reported overlap-threshold robustness table now shows only the 50-percent and
80-percent alternatives, estimated on the same outcome-specific samples and
with the same controls and fixed effects as the main models. The corresponding
all-prior-election sensitivity uses the same main and alternative thresholds.

### 2. The refunding sensitivity output collision — resolved

At the time of the initial audit,
`R/Clean/05d_census_mergent_point_in_time_debt_choice_refundings.R` read the
refunding-inclusive cross section but wrote these active production filenames:

- `point_in_time_yield_spread_2017_full_sample.tex`
- `point_in_time_yield_spread_2017_full_sample_panel_b_utgo_ltgo_revenue.tex`
- `point_in_time_census_debt_poisson_2017_full_sample.tex`
- `point_in_time_robustness_border_state.tex`

The outstanding-debt filename was written twice inside 05d. The second write
used an exploratory excess-debt outcome while retaining column labels intended
for total debt, long-term debt, and Mergent debt. The script also predates the
current strict-municipal-debt-limit control used in the main point-in-time
analysis. That specification-alignment question was not changed as part of the
output quarantine and remains in the broader reconciliation work in finding 3.

Because the main no-refundings script and 05d shared output names, the
pre-remediation TeX fragments had ambiguous provenance: file contents and
timestamps alone did not prove which script wrote them last.

**Resolution:** step 05d now defaults to `revision_tables/refundings` and
`processed/refundings`, assigns `_with_refundings` to every artifact, and stops
if configured to use either main production root. The exploratory excess-debt
model now writes a separate
`point_in_time_excess_census_debt_poisson_2017_with_refundings.tex` file with
outcome-specific labels rather than overwriting the total-debt table. The safe
sensitivity command and promotion warning are documented in `R/Clean/README.md`.
The orphaned, undefined `excluded_state` filter was also removed so the script
can complete from a clean R session.

### 3. Border specifications have drifted — high priority

The active Appendix table (R step 15), Online Appendix wild-bootstrap table (R
step 10), and response leave-one-out table (R step 12) should be variants of the
same border model. They are not currently aligned.

- Step 15 filters to configured debt/yield border pairs but no longer performs
  the explicit within-pair treatment-variation screen described by its nearby
  comment.
- Steps 10 and 12 retain only identifying border groups with both vote regimes.
- Step 15's debt-choice model includes `state_ltgo_allowed` and `glm_proactive`
  but omits `strict_municipal_debt_limit`.
- Its yield model omits `state_ltgo_allowed`, `glm_proactive`, and
  `strict_municipal_debt_limit`.
- Steps 10 and 12 include `strict_municipal_debt_limit` in their point-in-time
  border specifications and use a different control set.
- The active Appendix table note says proactive-state, LTGO-allowed, and strict
  debt-limit controls are omitted, but step 15's debt-choice model currently
  includes the first two.

**Action:** choose one production border sample and one control list per outcome,
store them in shared helpers, and have steps 10, 12, and 15 call those helpers.
The wild-bootstrap and leave-one-out code should alter inference or omit a state,
not silently alter the baseline model.

### 4. The response expanded-sample debt table changes two dimensions — high priority

`point_in_time_census_debt_poisson_2017_expanded_sample.tex` is generated only
by step 05d. It therefore uses the refunding-inclusive cross section as well as
the expanded state sample. The main table is intended to use the no-refundings
cross section. This response table cannot isolate the effect of adding
dark-green states.

In addition, `processed/outstanding_debt_expanded_sample.tex` says in its title
that the expanded sample keeps dark-green states but says in its note that those
states are excluded.

**Action:** generate the expanded-state result from the same no-refundings data
and control construction as the main table, changing only the state/sample
screen. Correct the note after the output is regenerated.

### 5. Point-in-time control construction is not fully consistent — high priority

The main R step 05 applies a common nonmissing-control screen and fills missing
`strict_municipal_debt_limit` with zero. That control is used in the current
main point-in-time models and in much of the leave-one-out code. However:

- step 05c (the response's other-debt tables) uses the older control list and
  omits `strict_municipal_debt_limit`;
- step 05d omits it;
- step 15 differs as described above;
- border yield models use weighted-average insured/sinkable controls, whereas
  the full-sample yield models use any-insured, any-callable, and any-sinkable
  indicators.

The last difference may be intentional, but it should be documented as a model
choice rather than presented as the same controlled specification.

**Action:** create named control vectors and sample-building functions for
full-sample debt, full-sample yield, border debt, and border yield. Reuse them in
main, dark-green, other-debt, refunding, wild-bootstrap, and leave-one-out code.

### 6. State-policy corrections are repeated rather than centralized — medium priority

The purpose merge and DPC media code make inline policy adjustments, including
setting Missouri revenue-vote treatment to one and Rhode Island GO-vote status
to missing. Other pipelines depend on whichever values are embedded in their
dated Mergent or state-policy inputs. The main news preparation also fills
missing revenue-vote values under its own convention.

**Action:** encode every approved state-policy correction once in the state
policy build, with source and effective dates, and merge that version everywhere.
Downstream scripts should assert the expected values rather than rewrite them.

### 7. The Code and paper repositories contain different results — high priority

Most compared active raw fragments are byte-identical, apart from generated
timestamps. The material exceptions are:

- `websites_regression.tex`: current Code coefficients for the five Vote rows
  are 1.060, 1.021, 1.986, 1.896, and 0.629; the paper repository contains
  1.204, 1.098, 2.139, 2.423, and 0.864. Observation counts also differ.
- `websites_regression_drop_dark_green.tex` differs substantively.
- the current Code leave-one-out summary differs substantively from
  `raw/leave_one_out_summary.tex` in the paper repository.

The main text reports the paper-repository website estimates (for example,
1.204), not the current Code output. This means the current scripts/data,
response tables, and prose do not describe a single frozen result set.

**Action:** choose the conference data vintage, run into a clean staging
directory, compare every active fragment, then promote the complete set and
update prose from the promoted outputs. Preserve a manifest of file hashes.

### 8. Paper descriptions need revision — high priority

1. Main-draft website prose says vote-state cities hold less outstanding debt
   and discusses county size, but the active Table 2 Panel A contains only the
   five website outcomes.
2. Main-draft media prose discusses prior issuance, source count, amount, GDP,
   income, and population differences, but the active Table 3 Panel A reports
   only the media outcome.
3. The paper describes the Texas Bond Review Board raw file as 2000--2021 with
   872 propositions. Current regression preparation deliberately enforces
   2001--2020. The paper should distinguish the raw universe from the analysis
   window and report analysis-specific observations where appropriate.
4. `tx_election_time_series_with_failure_risk.tex` describes Panel C, and the
   main text and response cite Panel C, but the Panel C `\input` is commented
   out. Only Panels A and B are currently rendered.
5. The time-series and election-outcome notes repeatedly call the analysis a
   “sample of 872” even though the regression units are filtered city-years,
   city-months, or election observations. Clarify that 872 is the raw
   proposition universe.
6. The response expanded-sample note contradicts its title, as noted above.
7. `variable_definitions.tex` contains minor typos (“across across” and
   “bodns”).

### 9. Texas event-time issuance construction — resolved in code; promotion pending

`R/Clean/03_texas_media_event_time.R` now obtains issuance events from the
canonical `260716` city-bond file used by the related Texas preparation. The
updated binned results differ by at most 0.28 percentage points and are recorded
in a diagnostic CSV. The staged PDF has not yet replaced the production/paper
figure.

### 10. Step 05c is not standalone and is not promoted reliably — medium priority

`05c_census_mergent_point_in_time_debt_choice_with_other.R` begins with objects
such as `full_sample_2017_unrestricted`, `control_dict`, and `tbl_dir_other`
that are created by step 05. Running 05c by itself fails. Its outputs belong in
`revision_tables/with_other`, but the currently observed copies also exist at
the output root, and the promotion script neither recurses nor allowlists these
response fragments by default.

**Action:** make 05c load/build its inputs explicitly or source a shared setup
module. Keep one canonical `with_other` output location and promote it
recursively with explicit paths.

### 11. Table promotion does not cover the active document — high priority

The default allowlist in `99_promote_tables_to_overleaf.R`:

- omits the active main `point_in_time_census_debt_poisson_2017_full_sample.tex`;
- names `r3b_media_supermajority.tex`, while the active online-appendix wrapper
  reads `media_coverage_super_majority.tex`;
- omits the four dark-green appendix panels;
- omits `14_supermajority_panel_c.tex`;
- omits the leave-one-out summary and nested `with_other` response files;
- omits the two restricted-sample response fragments.

The script promotes raw fragments only; processed wrappers and figures remain
manual. Its default destination is the Dropbox Apps Overleaf directory, not the
pulled Git clone audited here.

**Action:** derive a promotion manifest from the active TeX dependency graph or
maintain a checked manifest covering raw fragments, wrappers, and figures. Use
dry-run and an explicit destination. Do not use `--apply --overwrite` until the
staged manifest has been reviewed.

### 12. Several figures/tables lack an active clean-code generator — medium priority

The state map, law/statute exhibits, regime/city-bond pie charts, and anecdote
table cannot currently be reconstructed from the active clean-code folders.
Some related code is in `Python/Archive`; other assets appear manual.

**Action:** either restore the production generator to `Python/Clean` with
documented fixed inputs, or label the item as a manual source exhibit and record
its provenance. Archive status should not be the only copy of code needed to
rebuild an active paper figure.

## Consistency matrix for common constructions

| Construction | Current status |
|---|---|
| Prior-year BEA controls | Website and RavenPack preparation document year-minus-one matching; the RavenPack pipeline uses a 2001 GDP fallback for 2001 issuances. Purpose point-in-time panels use prior-year controls inherited from the Census cross section. These timing choices should be stated by analysis. |
| Prior 12-month issuance | RavenPack main preparation and DPC preparation now both use an inclusive `<= 12` convention. The border RavenPack lag is constructed on its border intermediate, while DPC constructs the lag before restricting its DPC estimation base; preserve and test the intended city issuance universe. |
| Article winsorization | RavenPack main full and border samples share caps from the full-sample UTGO/positive-background-coverage sample. The month-zero robustness calculates caps for its own samples. This can be defensible but should be described as a robustness-specific recapping choice. |
| Low-tax-privilege state | Centralized in `Config/low_state_tax_privilege_states.csv` / `00_tax_privilege_definitions.R`; this is a good shared pattern. |
| Border-pair definitions | Centralized in `Config/border_state_pairs.csv` / `00_border_pair_definitions.R`, but identifying-pair screens and regression controls still differ by script. |
| Supermajority states | Centralized in `00_state_policy_definitions.R` for R analyses. |
| Point-in-time eligibility | Main debt choice/yield generally requires at least two outstanding GO/revenue CUSIPs; other-debt analysis switches to at least two total bonds. The distinction is appropriate only if notes state it explicitly. |
| Missing strict debt-limit flag | Main step 05 converts missing to zero. That convention must be validated against the policy source and applied consistently if retained. |

## Recommended pre-conference resolution order

1. **Completed:** freeze the paper Mergent contract at `260716`, document the
   permitted extensions, and exclude the coauthor's `261013` expanded sample.
2. **Completed:** quarantine step 05d so it cannot write production names.
3. Reconcile the common point-in-time and border control/sample definitions.
4. Regenerate the dark-green expanded result from the main no-refundings data.
5. Decide whether Texas Panel C is active; either restore its input or remove
   all Panel C descriptions and references.
6. Run the approved Python preparation steps and R generation steps into an
   empty staging directory, not the existing output folder.
7. Compare staged results with the paper dependency manifest, investigate every
   numerical difference, and record hashes.
8. Promote all active raw fragments, processed wrappers, and generated figures
   to the pulled paper clone using an explicit destination.
9. Update the paper prose and table notes only after the conference outputs are
   frozen.
10. Compile the full paper and both response documents, then visually inspect
    every table/figure and verify that all references resolve.

## Audit limitations

- This review did not execute regressions, external downloads, website scraping,
  OpenAI classification jobs, or the 7+ GB Mergent rebuild.
- Existing Code worktree changes and generated outputs were preserved.
- Static tracing can establish declared provenance and specification drift, but
  it cannot prove that a current output was generated by a particular script
  when multiple scripts write the same filename. That ambiguity is itself a
  finding and should be removed before the final rerun.
