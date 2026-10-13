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
issuer-spread inputs. It exports the website city-year, city-month, annual
election, RavenPack-linked annual, proposition-level validation, 2017
debt-choice, full-period issuance, and media-election panels to
`Data/Clean_Intermediate/TX/Rejection_Risk/`.

The annual city-election panel remains 1996--2023, matching the existing R
analysis. The R script now loads these files and retains the regression,
sample-selection, and table-generation code.
