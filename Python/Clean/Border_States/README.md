# Border-state sample builder

Run `Identify Counties in Border States Wider Sample.py` to build the Mergent
and RavenPack issuance border files using the pairs included in
`Config/border_state_pairs.csv`. The current county-centroid buffer is 100,000
meters. Inputs are read from the existing project Data directories.

County FIPS codes are integers for the joins. The state component is computed
with integer division by 1,000, preserving Alabama (01) and Arkansas (05)
even after leading zeros are removed. State codes are keyed explicitly by
postal abbreviation so removing a configured pair cannot shift the mapping.

Outputs default to `Data/Clean_Intermediate/Border States/`. Set
`BORDER_OUTPUT_DIR` to write both outputs to another directory for validation.

The pre-fix builder is preserved at commit `fc04014`. Before replacing the
existing outputs, copies were saved under
`Data/Clean_Intermediate/Border States/pre_fips_fix_fc04014/`.

The website collection input is a separate, previously collected issuer/URL
list. Rebuilding the border files does not collect websites for newly restored
Alabama and Arkansas issuers; those cities must be added to the collection
pipeline before they can appear in website regressions.
