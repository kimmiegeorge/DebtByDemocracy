# State policy comparison for Reviewer R3

`aggregate_state_policies.py` builds a merge-ready state-level policy file and a
LaTex comparison table for the R3 response.  It is deliberately a small,
auditable build: each source is retained separately before aggregation and all
derived indicators are labelled in the output.

## Inputs

* `Data/Statutes/2026-07-23_City laws by state.xlsx` -- city GO and revenue
  referendum rules.  The comparison treats a state as a referendum state only
  when its GO rule is uniform and requires a vote; states coded `Depends` are
  retained in the state file but excluded from the eligible comparison.
* `Data/Statutes/2026-09-26_City debt limits by state.xlsx` -- city debt-limit
  coding.  The script retains the underlying limit, valuation basis, override,
  and strictness fields rather than reducing the source to one indicator.
* `Data/State Monitoring Policy/state_enforcement_adoption_years.csv` --
  adoption years from Nakhmurina (2024).  `before_sample` is treated as in
  force in every study year.
* `Data/Addnl State Policy Data/wen_municipal_tel_index_2020.csv` -- transcription of Appendix 2 of Wen, Xu,
  Kim, and Warner (2020), PDF page 20.  This is the municipal (not county or
  school-district) TEL severity index, whose underlying tax-limit research
  draws on the Lincoln Institute's Significant Features of the Property Tax.
  The current Lincoln database is linked in the output as the update source:
  <https://apps.lincolninst.edu/data/significant-features-property-tax/access-database/tax-limits-truth-taxation/report>.
* `Data/Addnl State Policy Data/lincoln_property_tax_limit_features_2024.csv` -- transcription of state-level
  outcomes from Langley, Paquin, and Um, *Understanding State Property Tax
  Limits* (Lincoln Institute, 2025), Figure 2, Tables 1--3, Figures 9--10, and the
  underlying 2024 database records. The levy-limit override method preserves the
  source's four categories: referendum, referendum or governing body, governing
  body, and no override. Among the 50 states, these categories reproduce Figure
  9's totals after excluding the District of Columbia: 16 referendum, 3 either,
  2 governing body, and 6 no-override states. States without a levy limit are
  coded separately. The
  accompanying binary indicator equals one only when a referendum is required
  to override the levy limit; it is not a measure of voter approval for every tax
  increase. The source distinguishes voter approval from a governing-body vote;
  the separate Truth-in-Taxation governing-body-vote measure is also retained.
* `Data/Addnl State Policy Data/gasb_municipal_gaap_requirements_2025.csv` --
  state-level municipal (city) GAAP reporting-framework categories transcribed
  from Waymire (2025), GASB Staff Working Paper, Table I.c. It retains the
  distinction between an unconditional requirement and a requirement with
  exceptions; it does not use the paper's separate state-government table.
* `Data/Addnl State Policy Data/nasact_state_audit_requirements_2023.csv` --
  state auditor and local-government audit fields converted from NASACT (2023),
  Table 4.29. The source's original cell text is retained alongside the binary
  audit indicators derived in the output.
* `Data/GFOA Awards/analysis/city_year_pafr/city_year_gfoa_awards_panel.csv`
  -- balanced FY2014--2020 GO-city panel with conservative exact GFOA matches.
  The build calculates annual state rates for COA, PAFR, and either award, then
  merges the state average COA and PAFR rates into the financial-reporting and
  oversight variables. COA FY2019 is excluded from COA/either averages because
  the public archive/AMS transition has incomplete coverage that year.

## Outputs

The script writes:

* `Data/State Policies/20260929_state_policy_comparison.csv` -- one row per
  state, keyed by `state_abbr`.  This is the file to merge into state-level or
  city-level analysis files.
* `Data/State Policies/20260929_state_fiscal_monitor_2000_2020.csv` -- a
  state-year expansion of the fiscal-monitor indicator for specifications with
  year variation.
* `Data/State Policies/20260929_state_policy_comparison_table.tex` -- the
  descriptive comparison table used in the reviewer response.
* `Data/GFOA Awards/analysis/city_year_pafr/state_year_gfoa_award_rates.csv`
  -- state-by-fiscal-year award rates and numerator/denominator counts.
* `Data/GFOA Awards/analysis/city_year_pafr/state_gfoa_award_rate_averages.csv`
  -- state averages merged into the policy comparison file. These are
  unweighted averages of annual rates; because each state has a balanced city
  panel, they equal pooled city-year rates over the same observed years.

Run from the repository root:

```bash
python3 Python/Clean/State_Policy_Comparison/prepare_addnl_state_policy_sources.py
python3 Python/Clean/State_Policy_Comparison/aggregate_state_policies.py
```

The preparation script writes the shareable source extracts and a
`state_policy_source_manifest.csv` to `Data/Addnl State Policy Data/`. The
aggregation script then reads those CSVs; it does not read the GASB PDF or the
NASACT workbook directly.

The table is descriptive.  It does not interpret the seven non-referendum
states as a random sample, and it does not include the 16 states whose city GO
rules vary by city, project, or financing category.

## Website regression data

After rebuilding the state-policy output, run
`Python/Clean/City_Websites/Border_States/02_prepare_border_state_website_regression_data.py`.
It merges every state-level field into the website sample by postal abbreviation,
retaining source text and missing values. The dated policy and award-average
fields are state-level comparisons repeated across website years; they are not
year-specific policy histories. The existing `state_monitor` variable remains
the adoption-based control for each website year.
