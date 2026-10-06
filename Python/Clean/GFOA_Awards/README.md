# City-year GFOA awards

Run from the Code repository:

```sh
python3 Python/Clean/GFOA_Awards/01_create_city_year_awards_panel.py
Rscript R/Clean/01b_gfoa_awards.R
```

The Python step uses Polars for transformations, pyreadstat for Stata inputs,
and rapidfuzz for edit-distance review candidates. It builds the balanced
FY2014–2020 GO-city panel using unique exact normalized city/state award
matches. Unmatched COA observations in FY2019 remain missing because archive
coverage is incomplete. Approximate matches are exported for review only.
The historical R name-normalization, modal tie-breaking, and initial-year
issuance definitions are preserved.

Inputs include the financial-sample Mergent city bonds, issuer state policies,
GFOA award observations, BEA county data, the state-policy comparison, monitoring
adoption years, and the shared full-Mergent outstanding-debt panel. The canonical
state lists in `R/Clean/00_state_policy_definitions.R` and
`R/Clean/00_tax_privilege_definitions.R` supply policy membership.

Outputs go to `Data/GFOA Awards/analysis/city_year_pafr`:

- `city_year_gfoa_awards_panel.csv`: original panel with source missing values,
  adoption-based `state_monitor`, and preceding year-end debt and log(1 + debt).
- `city_year_gfoa_awards_regression_data.csv`: the existing regression sample,
  with revenue-vote, debt-limit, and audit-source missing indicators and their
  corresponding zero-filled fields prepared in Python.
- Exact-match files, unmatched-candidate review files, city FIPS conflicts,
  build diagnostics, and a generated `README.txt`.

`GFOA_ANALYSIS_DIR` overrides the Python output directory. In R,
`GFOA_REGRESSION_DATA` overrides the prepared input and `RESULTS_DIR` overrides
the table directory (default: `R/Clean/output/revision_tables`). R reads with
`fread`, estimates the four explicit existing linear probability models, and
uses the website script's `etable`, rounding, formatting, and panel helpers.
The first three outcomes are COA; the fourth is PAFR among GO-vote states.
All models retain year fixed effects and state-clustered standard errors.
Lagged debt remains available as a panel field; the migration preserves the
existing regression specifications.

R writes `gfoa_awards_regression.tex`, `gfoa_awards_models.txt`, and
`gfoa_awards_model_coefficients.csv`. The LaTeX table reports coefficients to
three decimals, t-statistics to two, observations, adjusted R-squared, year
fixed effects, and state clustering. Adjusted R-squared matches the existing
OLS estimator; the website count models instead report pseudo R-squared.
