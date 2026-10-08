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

## Definitions for the reviewer comparison table

`20260929_state_policy_comparison_table.tex` compares the 33 states with a
uniform city GO-bond rule: 26 states where voter approval is required and 7
where it is not.  It excludes states whose rule varies by city, project, or
financing type, as well as states without a classifiable rule.  "GO" means a
municipal general-obligation bond; it does not refer to revenue bonds.  The
two comparison columns report the number of states meeting each policy followed
by the percentage of all 26 or 7 states in that group, formatted as `N [%]`.
Unknown policy values are not counted as meeting a policy. The States row
reports only group sizes, and the final column identifies policy sources.
The table uses a wider policy-label column to keep labels on one line.

### State debt policies

* **Proactive state.** `glm_proactive` from Gao, Lee, and Murphy (2019),
  read from `Data/Gao et al/250624_GLM_table1.csv`.
* **LTGO allowed.** Fidelity policy coding (`state_ltgo_allowed`).
* **State GO vote required.** Pew Trusts policy coding (`state_go_vote`).
  This is distinct from the municipal GO-vote rule used to form comparison
  groups. Both bond-policy indicators are read from the existing
  `Data/Mergent/Clean/260716_city_issuerlevel_yieldspread.dta` file, with a
  check that coding is constant within each state.

Truth-in-Taxation and GFOA recipient rates remain in the data outputs but are
omitted from the displayed comparison table.

### Debt-limit policies

* **Any municipal debt limit.** Indicator equal to one when the statutory
  debt-limit workbook codes the state as having a municipal debt limit.  States
  coded `Depends` or `N/A` are missing rather than treated as having no limit.
* **Strict municipal debt limit.** Indicator
  equal to one only when the workbook's threshold is at most 5 percent at a
  close-to-market valuation (or at most 10 percent at a below-market
  valuation) **and** the cap cannot be exceeded.  A low cap with an available
  override is therefore not strict.  Nebraska is coded zero because its rule
  varies across cities, consistent with the main debt-choice analyses.
* **Debt limit can be exceeded.** Indicator equal to one when the statutory
  workbook explicitly codes the municipal limit as exceedable.  The row does
  not require that the override be by referendum; the separate raw field
  `debt_limit_voter_override` retains that distinction.

### Tax-related policies

* **Property-tax levy cap.** Indicator for a state-imposed cap on annual
  increases in the property-tax levy, using the Lincoln Institute's 2024
  classification.  It is a state policy feature and is not restricted to a
  city's particular tax base or fiscal year.
* **Referendum required to exceed property-tax levy cap.** Indicator equal to
  one only where the Lincoln source classifies the override mechanism as a
  referendum.  It is zero for no levy limit, no override, a governing-body
  override, and a choice between referendum and governing-body override.  It
  is consequently a measure of a *referendum-only* override, not of whether a
  voter ever approves a tax increase.
* **Broad municipal revenue/expenditure cap.** Indicator for a state limit on
  municipal revenues, expenditures, or both that extends beyond the property
  tax.  The Lincoln source identifies six states where the limit applies to
  municipalities (whether alone or with counties and/or school districts), as
  of 2022.
* **Truth-in-Taxation requirement.** Indicator for a state included in the
  Lincoln source's 2024 Truth-in-Taxation summary.  These laws require public
  disclosure and hearings around proposed property-tax increases; states differ
  in whether they also require a rollback-rate calculation, mailed notice, or
  a governing-body vote.
* **Governing-body vote for tax increase.** Indicator for a state where the
  Lincoln source reports that the local governing body must vote to exceed the
  Truth-in-Taxation rollback rate (or, for Arizona, to approve a covered
  increase).  This is distinct from a voter referendum.

### Financial reporting and oversight policies

* **State fiscal monitor in place by 2020.** Indicator equal to one when the
  fiscal-monitoring adoption file, based on Nakhmurina (2024), identifies the
  policy as adopted before the study period or no later than 2020.  Fiscal
  monitoring is a state process that regularly reviews local-government
  financial information for signs of distress.
* **Municipal GAAP required.** Indicator equal to one when GASB's municipal
  table categorizes the state as either `GAAP required` or `GAAP required with
  exception`.  It is not limited to unconditional requirements; the output
  retains the more restrictive no-exception version separately.
* **State auditor audits cities/towns/villages.** Indicator equal to one when
  the NASACT 2023 table places a checkmark in the cities/towns/villages column.
  It means that the state auditor audits at least some such governments, not
  necessarily all of them; several source cells report partial coverage.
* **COA recipient rate among GO-bond cities (annual mean).** For each fiscal
  year, the share of cities in the project's GO-bond city universe that receive
  GFOA's Certificate of Achievement for Excellence in Financial Reporting
  (COA), averaged across available FY2014--2020 state-year rates.  FY2019 is
  omitted because the public COA archive/awards-management-system transition
  has incomplete coverage, so the usual denominator is six years.
* **PAFR recipient rate among GO-bond cities (annual mean).** The analogous
  annual-average recipient rate for GFOA's Popular Annual Financial Reporting
  (PAFR) Award, over FY2014--2020.  PAFR is observed in all seven years.  Both
  award rates are unweighted averages of state annual rates; because the city
  universe is balanced within state, they equal the corresponding pooled
  city-year rates.

The tax and reporting-policy measures are source-year snapshots (principally
2023--25, with the budget-limit measure referring to 2022), whereas the award
rates cover FY2014--20.  The table should therefore be described as a
descriptive comparison of policy environments, not as a time-aligned policy
panel or causal estimate.

## Website regression data

After rebuilding the state-policy output, run
`Python/Clean/City_Websites/Border_States/02_prepare_border_state_website_regression_data.py`.
It merges every state-level field into the website sample by postal abbreviation,
retaining source text and missing values. The dated policy and award-average
fields are state-level comparisons repeated across website years; they are not
year-specific policy histories. The existing `state_monitor` variable remains
the adoption-based control for each website year.
