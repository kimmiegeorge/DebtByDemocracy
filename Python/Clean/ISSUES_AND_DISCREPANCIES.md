# Python Clean Folder Issues and Discrepancies

## Output safety

- Clean reruns now direct generated intermediate outputs to `Data/Clean_Intermediate` with stable, undated filenames.
- True source inputs, including Mergent `.dta` files, BEA controls, state-policy files, WRDS/RavenPack raw files, and Stata-created source files, remain read from the original `Data` tree.

## Dated file dependencies

- Clean-generated output filenames no longer carry run-date suffixes.
- The active Clean Mergent `.dta` inputs have been updated to `260716` for city bond/issuer yield-spread files. The prior `citycountyschool` inputs in the Clean pipeline were replaced with the city-level bond file.

## External/API dependencies

- RavenPack, DPC/OpenAI batch classification, Wayback Machine collection, and WRDS-derived files require external credentials or prior downloads.
- The copied clean scripts should not be rerun blindly until those dependencies are confirmed.

## Stata dependency

- Python scripts read Mergent and BEA `.dta` files produced by upstream Stata or other cleaning steps. Those were not audited.

## Wrapper gap

- Python scripts generate data inputs, not the final paper wrapper `.tex` files.
- The final assembly from component tables into `processed/*.tex` remains outside the traced Python/R generation layer.
