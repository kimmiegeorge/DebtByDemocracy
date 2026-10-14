# Texas rejection-risk regression data

`01_prepare_tx_rejection_risk.py` builds the analysis panels used by
`R/Clean/13_tx_rejection_risk.R`. Run it from the repository root after its
upstream inputs have been refreshed:

```sh
python3 Python/Clean/TX_Election_Exposure/03_build_tx_isd_failure_exposure.py
python3 Python/Clean/Election_Outcomes/05_prepare_tx_regression_inputs.py
python3 "Python/Clean/Census_COG_Finance/9. Build Texas 2017 Rejection Risk Cross Section.py"
python3 Python/Clean/TX_Rejection_Risk/01_prepare_tx_rejection_risk.py
```

The preparation step combines those existing regression and exposure panels
with the local election, issuance, outstanding-debt, county-demographic, and
issuer-spread inputs. Issuance and issuer metadata use the canonical `260716`
paper-sample files. Beginning-of-year debt comes from the shared
`Data/Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv`,
which is also built from `260716`; the former
`260709_issuer_year_outstanding_debt.csv` input is no longer used. It exports
the website city-year, city-month, annual
election, RavenPack-linked annual, proposition-level validation, 2017
debt-choice, full-period issuance, and media-election panels to
`Data/Clean_Intermediate/TX/Rejection_Risk/`.

The Python and R stages support `TX_REJECTION_RISK_OUTPUT_DIR` and
`TX_REJECTION_RISK_DATA_DIR`, respectively, so a migration or audit run can be
kept outside production outputs. The analysis window is 2001--2020.
