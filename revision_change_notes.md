# Revision Change Notes

## Expanded Mergent issuer debt coverage

- Use `Data/Mergent/Clean/260917_city_cusiplevel_finsample_allbonds.dta` as the
  comprehensive issuer-level Mergent bond source for the Census--Mergent debt
  cross sections.
- The revised cross sections include `mergent_total_outstanding_debt` and
  `mergent_total_outstanding_debt_mil`: the issuer's total outstanding Mergent
  debt as of December 31 of each cross-section year, without restricting debt
  to the paper's GO and strict-revenue categories.
- Retain the `newmatch == 1` bonds in the construction. These are valid bonds
  from raw issuers matched to an existing city seed issuer; 58 are classified
  as GO and 603 as strict revenue bonds. They should contribute to both total
  debt and the revised GO/revenue debt measures.
- In the expanded file, use `bond_type == "go"` and `bond_type == "rev"` for
  the final GO and strict (non-sales/excise-tax) revenue categories. Do not use
  `rev == 1` for strict revenue, because it is a broader classification in this
  file.

## Expanded Mergent yield-spread construction

- Rebuilt the NC/tax-adjusted, maturity-matched Treasury yield-spread lookup
  from the expanded all-bonds DTA. The new output is
  `Data/Clean_Intermediate/Mergent/Clean/bond_level_off_yield_spread_allbonds.csv`.
- The calculation uses the same Taxsim and Treasury-curve method as the prior
  lookup and covers all maturity-eligible expanded-file bonds, including
  `newmatch == 1` bonds. Among shared CUSIPs with a nonmissing prior NC spread,
  the rebuilt values are identical.
- Updated the Census--Mergent cross-section builder to use this expanded-file
  lookup. The legacy Gao spread is not available in the expanded DTA and is
  retained only from the current paper-sample bond file during the transition.

## Expanded Mergent cross-section construction

- The cross-section builder now uses the expanded DTA for all bond-level debt,
  maturity, rating, yield-spread, and bond-characteristic aggregations. It
  retains `newmatch == 1` observations.
- `mergent_total_outstanding_debt` includes every valid expanded-file bond
  outstanding at the cross-section date, regardless of `bond_type` or security
  code.
- `mergent_go_revenue_outstanding_debt` uses `bond_type` equal to `go` or
  `rev`. The final `rev` bond type excludes sales- and excise-tax bonds.
- Added `mergent_lease_rent_loan_agreement_outstanding_debt` and its millions
  and CUSIP-count counterparts. It combines Mergent security codes `C`
  (lease/rent) and `N` (loan agreement), irrespective of final bond type.
- Recreated `rating_num`, `rating_issue_max`, and `issue_unrated` directly from
  raw ratings in the expanded DTA using the prior Stata rules. All recreated
  values match the legacy file for its shared CUSIPs.
- Static issuer controls and the legacy Gao yield spread remain temporary
  lookups from the prior bond file because those fields are not retained in the
  expanded DTA.

## Outstanding-debt composition shares

- Moved `frac_utgo_outstanding`, `frac_ltgo_outstanding`, and
  `frac_rev_outstanding` from the R point-in-time analysis script into the
  Python cross-section build. Their denominator remains outstanding GO plus
  strict-revenue debt, and they are missing when that denominator is zero.
- Added lease/rent-inclusive shares with denominator outstanding GO/revenue
  debt plus outstanding lease/rent--loan-agreement debt:
  `frac_utgo_outstanding_wrl`, `frac_ltgo_outstanding_wrl`,
  `frac_rev_outstanding_wrl`, and
  `frac_lease_rent_loan_agreement_outstanding_wrl`.
