# Submitted media border prior-issuance indicator

`media_submission_border_prior_12.csv` preserves `bond_prior_12` for the 430
border observations in the submitted main media-coverage table. The key is
`seed_issuer_id`, `issuance_year_month_id`, and `group`.

The values were recovered from:

`Data/Clean_Intermediate/Border States/pre_fips_fix_fc04014/Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv`

The recovery follows the historical R sequence: remove missing `ln_employment`,
order by issuer and issuance month, calculate the issuer lag before filtering
paper border pairs, then restrict to UTGO issuances with positive background
coverage. The lookup retains the 430 rows used by the main border PPML models
following fixed-effect removal of zero-outcome and singleton groups.

This is a historical replication input, not a corrected prior-issuance measure.
The submitted calculation treats copies of an issuance in different border
pairs as successive rows. `02_media_coverage.R` uses these frozen values only
for `r2` and `r2b`; it checks unique matches and the exact estimation-row keys.
Other media models continue to use the current prepared indicator.

Using this lookup with the current input reproduces the submitted border Vote
coefficients 0.566933 and 0.565760 and t-statistics 2.13 and 2.04.
