# R Clean Folder Changes Made

- Copied active table-generation scripts from `Code/R/submission_tables` into `Code/R/Clean`.
- Copied helper files `modify_etable_rounding.R` and `robustness_helpers.R`.
- Redirected helper `source()` calls from `Code/R/submission_tables` to `Code/R/Clean`.
- Redirected table outputs from the Overleaf folder to `Code/R/Clean/output/revision_tables`.
- Redirected robustness table outputs to `Code/R/Clean/output/revision_tables/robustness`.
- Left source-data reads pointed at the original data locations.
- Redirected generated intermediate-data reads to `Data/Clean_Intermediate` where those files are produced by the Clean Python chain.
- Updated active Clean Mergent `.dta` input paths to the latest same-family files available during this pass: `260716` for city bond/issuer yield-spread files.
- Did not run scripts or overwrite existing paper tables.
