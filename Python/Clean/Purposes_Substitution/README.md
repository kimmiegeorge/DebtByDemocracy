# Expanded point-in-time DPC purpose panels

Run these scripts in order from the Code repository (or use absolute paths):

```sh
python3 Python/Clean/Purposes_Substitution/01_merge_dpc_purposes_all_issuers.py
python3 Python/Clean/Purposes_Substitution/02_build_point_in_time_purpose_panels.py
python3 Python/Clean/Purposes_Substitution/03_validate_expanded_purpose_panels.py
```

Step 01 replaces the restricted input produced by the archived R DPC merge.
It merges the same `260223_dpcdata_cusip_purpose.csv` indicators onto the full
`260610_city_cusiplevel_statereq_purpose_yieldspread.dta` bond file. CUSIPs are
normalized and repeated DPC documents are combined with the maximum of each
binary purpose indicator. No insample or revenue-vote restriction is applied.
It writes `dpc_use_proceeds_all_issuers_bonds.csv`.

Step 02 is the former archived point-in-time purpose builder, now maintained
here. It uses the same `260709` Mergent bond classifications and contractual
maturities to construct DPC-matched GO/revenue amounts at December 31 in 2012
and 2017. Issuer coverage comes from the full `processed/no_refundings`
Census/Mergent cross sections, the source used by the dark-green-inclusive
analysis. It preserves the original July `ln_gdp` and `ln_pers_inc` controls
from the `260716` Mergent file rather than replacing them with the newer
prior-year BEA controls. This keeps all original overlapping inputs identical.
The state-policy comparison is merged directly into both long and wide outputs.
Source-text line breaks are flattened so R reads numeric fields correctly.

All cross-section issuers are retained, including those with `city_rev_vote`
equal to one or missing. The `insample`, `insample_allgo`, and
`insample_utgo_only` indicators remain available for analysis-specific screens.
Missing revenue-vote rules are retained as missing. Issuers without positive
DPC-matched outstanding GO/revenue par have `dpc_purpose_observed = 0` and
missing purpose outcomes, rather than invented zeros. For observed issuers,
categories with no matching bonds remain zero, as in the original panel.

Step 02 writes the existing `260719_dpc_point_in_time_purpose_substitution_*`
2012/2017 category-panel and wide filenames, plus the category dictionary.
The default directory is
`Data/DPC Data/Use Of Proceeds/Purposes Substitution`, so R steps 06 and 07
load the expanded panels without path changes. `PURPOSE_REGRESSION_DIR`
overrides the output directory for both steps (and step-02 bond input).
R step 06 still selects `insample == 1`; broadening its regression sample is
a separate specification choice.

Step 03 compares every original field on overlapping observation keys and
checks that no original observation was lost, every expanded cross-section
issuer is retained, and AL, SD, and ID are present. All original values must
match exactly after reading the written CSVs; nullable type widening is allowed.
The pre-expansion four files
are preserved in `legacy_before_expansion`; `PURPOSE_BASELINE_DIR` can select
another baseline. Validation reports go to `diagnostics` under the panel
directory (`PURPOSE_VALIDATION_DIR` overrides it).

The earlier restricted R merge remains archived at
`R/Archive/dpc_use_proceeds_debt_choice_sample.R`; it is no longer a prerequisite.
The separate additive policy-refresh script is archived as
`Python/Archive/Purposes Substitution/03_add_state_policies_to_existing_panels.py`;
policy merging is now part of step 02.
