# Point-in-time purpose panels

The existing `260719_dpc_point_in_time_purpose_substitution_*` panels are built by
`Python/Archive/Purposes Substitution/2. Build Point in Time Purpose Cross Sections.py`.
That builder aggregates DPC-matched GO/revenue bonds outstanding at December 31
in 2012 and 2017 and attaches the Census/Mergent cross-section controls.

After building the panels, run:

```sh
python3 Python/Clean/Purposes_Substitution/01_add_state_policies_to_purpose_panels.py
```

This step adds all fields from
`Data/State Policies/20260929_state_policy_comparison.csv`, keyed by state, to
the 2012 and 2017 category panels and their wide counterparts. Outputs stay in
`Data/DPC Data/Use Of Proceeds/Purposes Substitution`, where
`R/Clean/06_point_in_time_purpose_substitution.R` already loads the 2017 panel.

Fields include `municipal_debt_limit`, `strict_municipal_debt_limit`, GAAP
requirements, state audits, tax/expenditure limits, and fiscal-monitoring
snapshots. Policy snapshots repeat across issuers and categories; they are not
historical policy panels. Source text and missing values are retained, with
embedded line breaks replaced by spaces for reliable R `fread` type detection.
Bond outcomes, existing controls, row order, and sample membership are preserved.
The step is safe to rerun to refresh the added policy fields.

`PURPOSE_POLICY_OUTPUT_DIR` can write enriched copies to a separate directory
for review. By default, it updates the four existing input files in place.
