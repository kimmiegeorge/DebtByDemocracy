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
- Next: migrate the remaining Mergent inputs in
  `Python/Clean/Census_COG_Finance/2. Build Census Mergent Debt Cross Sections.py`
  to the expanded DTA, beginning with the yield-spread and rating constructions.
