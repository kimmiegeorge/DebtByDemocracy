# Python Clean Folder Changes Made

- Created `Code/Python/Clean` and copied traced upstream scripts into topic subfolders.
- Preserved the original scripts' filenames to maintain traceability to the source code.
- Created `Data/Clean_Intermediate` as the designated destination for future clean intermediate outputs.
- Redirected Clean Python intermediate outputs to `Data/Clean_Intermediate` using stable, undated filenames.
- Updated Clean R table scripts to read regenerated intermediate datasets from `Data/Clean_Intermediate` where those files are produced by the Clean Python chain.
- Split the Clean website scripts into `City_Websites/Texas` and `City_Websites/Border_States`, and renamed them for their analysis branch.
- Updated active Clean Mergent `.dta` input paths to `260716` for city bond/issuer yield-spread files, including replacing prior `citycountyschool` inputs with the city-level bond file.
- Did not run Python scripts and did not overwrite existing data.
- Did not edit Stata files.

## Copied script groups

- `News`
- `DPC_News`
- `City_Websites/Texas`
- `City_Websites/Border_States`
- `Election_Outcomes`
- `Border_States`
- `MSRB`
- `Census_COG_Finance`
- `Debt_Outstanding`
- `Continuing_Disclosure`
- `Yield_Spreads`
