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
- Next: recreate the bond-level ordinal and issue-level rating variables from
  the expanded DTA's raw Fitch, Moody's, and S&P fields, then migrate the
  remaining Mergent inputs in the cross-section builder.
