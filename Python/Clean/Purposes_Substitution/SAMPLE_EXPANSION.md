# Expanded DPC purpose-substitution sample

The purpose regression inputs now retain the full Census/Mergent issuer cross
section used by the dark-green-inclusive debt-choice analysis. Creation is
maintained in `Python/Clean/Purposes_Substitution`, rather than relying on the
restricted DPC bond merge produced by the archived R script.

## What changed

The previous upstream merge, `R/Archive/dpc_use_proceeds_debt_choice_sample.R`,
restricted issuers to `insample == 1` using
`260611_city_issuerlevel_yieldspread.dta`. Consequently, the purpose-panel input
already excluded some issuers before the panel builder or R regressions ran.

The new Python pipeline merges DPC purpose indicators onto the full bond input
and uses the full `processed/no_refundings` Census/Mergent cross sections for
issuer coverage. It retains revenue-vote states and states with missing
revenue-vote rules, without filling missing rules. The expanded state-policy
fields are merged directly into both the category panels and wide files.

The 2017 file now includes 3,023 issuers, including 57 in Alabama, 33 in South
Dakota, and 14 in Idaho. Of these, 43 Alabama, 16 South Dakota, and 10 Idaho
issuers have observed DPC purposes. Issuers without positive DPC-matched
outstanding GO/revenue par remain in the file with `dpc_purpose_observed = 0`
and missing purpose outcomes. Missing coverage is not coded as zero debt.

## Why 44 Arkansas issuers now enter the regressions

The expanded input adds 44 Arkansas issuers to the existing step-06 PPML
regression sample. In the old June issuer file, all 44 had `city_rev_vote = NA`
and `insample = 0`. In the July cross-section controls, they have
`city_rev_vote = 0` and `insample = 1`.

Their old population and county-debt controls were nonmissing. Their exclusion
was caused by the older revenue-vote coding and sample flags, rather than
missing demographic controls. Including them increases the PPML observation
count from 1,726 to 1,770 under the specifications checked during migration.

The 44 issuer names, as recorded in the data, are:

- BAUXITE ARK
- BENTON ARK
- BENTONVILLE ARK
- BRYANT ARK
- CAMDEN ARK
- CENTERTON ARK
- CENTRAL ARK
- CLARKSVILLE ARK
- CONCORD ARK
- CONWAY ARK
- DECATUR ARK
- DUMAS ARK
- EL DORADO ARK
- ELKINS ARK
- EUREKA SPRINGS ARK
- FAYETTEVILLE ARK
- FORT SMITH ARK
- GREEN FOREST ARK
- GREENWOOD ARK
- HEBER SPRINGS ARK
- HOPE ARK
- HOT SPRINGS ARK
- HUNTSVILLE ARK
- JACKSONVILLE ARK
- LAVACA ARK
- LITTLE ROCK ARK
- LOWELL ARK
- MAGNOLIA ARK
- MAUMELLE ARK
- MENA ARK
- MONTICELLO ARK
- MOUNTAIN VIEW ARK
- OZARK ARK
- PEA RIDGE ARK
- PINE BLUFF ARK
- PRAIRIE GROVE ARK
- ROGERS ARK
- SEARCY ARK
- SHANNON HILLS ARK
- SHERWOOD ARK
- TEXARKANA ARK
- VAN BUREN ARK
- VILONIA ARK
- WARD ARK

## Validation and regression restrictions

Every original value matches exactly on overlapping observation keys after
reading the written CSVs. No original observation was lost. This was checked
for all four existing files: the 2012 and 2017 category panels and their wide
counterparts. The original category panels contain 10,860 observations in 2012
and 11,784 in 2017. Original July county controls are retained, avoiding an
unrelated change to the newer prior-year BEA controls.

The pre-expansion inputs are preserved in `legacy_before_expansion` under
`Data/DPC Data/Use Of Proceeds/Purposes Substitution`. Step 03 writes overlap
and state-coverage reports to the panel directory's `diagnostics` folder.

`R/Clean/06_point_in_time_purpose_substitution.R` still applies its own
`insample == 1` restriction, nonmissing-control screens, and requirement of
at least two outstanding GO/revenue bonds. Thus, retaining AL, SD, and ID in
the input file does not automatically include them in the current regressions.

See [README.md](README.md) for the three Python steps and output paths.
