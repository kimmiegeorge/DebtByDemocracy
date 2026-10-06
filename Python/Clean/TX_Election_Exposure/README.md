# Texas overlapping-ISD failure exposure

This pipeline turns failed Texas ISD bond propositions into city-level exposure
measures using Census place and unified-school-district boundaries.  The city
universe is the union of the city-month media panel and the full website
disclosure panel; it is not restricted to cities with a RavenPack match.

Run from the repository root:

```sh
python3 Code/Python/Clean/TX_Election_Exposure/01_download_tx_historical_boundaries.py
python3 Code/Python/Clean/TX_Election_Exposure/02_build_tx_city_isd_crosswalk.py
python3 Code/Python/Clean/TX_Election_Exposure/03_build_tx_isd_failure_exposure.py
```

Raw Census downloads are stored in `Data/Geography/Texas/raw/census_tiger/`.
Derived crosswalks and exposure panels are stored in
`Data/Clean_Intermediate/TX/Election_Exposure/`.

The primary exposure is an ISD failure in the preceding 36 months where the
ISD contains at least 80 percent of the city's area in the nearest historical
boundary vintage. The current implementation uses area shares, not voters or
population shares; all files name this explicitly. The `city_isd_overlap_*`
outputs also retain every intersecting ISD, so the area weights can later be
replaced with Census-block population or voting-age-population weights.

Historical vintages are assigned as 2000 for 1995--2004, 2010 for 2005--2014,
and 2020 for 2015--2024. Match diagnostics are written for manual audit before
using the exposure in a paper table.

For the website-disclosure outcome, Script 03 writes a separate full-city
city-year exposure panel.  It reports `spatial_exposure_observed_*` flags for
each lookback horizon.  A zero exposure is used only when the corresponding
historical place boundary is observed.  For example, Ivanhoe is not an
incorporated place in the 2000 Census vintage, so its all-history exposure is
flagged as unavailable rather than coded as zero.

For Table 4 Panel C, the election input builder merges `prior_failure_any_360m`
from the two 80%-overlap exposure files as `prior_isd_failure`. Website
city-years with `spatial_exposure_observed_360m == 0` remain missing. The
regressions and table now also run directly in `R/Clean/03_election_outcomes.R`.

Scripts 02 and 03 read the upstream `Websites/Texas/time_series_website_data.csv`
for the website city universe. They therefore run before the regression-input
builder and do not depend on the regression-ready files they help produce.
