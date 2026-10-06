# 03b: Texas city elections and website disclosure after a local bond failure
#
# Main exposure: a defeated ISD or county proposition in the city's recorded
# county during the selected number of complete calendar months.
#
# The county is a co-location proxy. It does not establish that the same voters
# participated in the earlier non-city election and the later city election.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(haven)
})
source('Code/R/Clean/00_modify_etable_rounding.R')

# Use `Rscript 03b_tx_county_noncity_failure_exposure.R 12 isd_only` to run
# a 12-month ISD-only sensitivity analysis. With no arguments, the main
# 36-month ISD-or-county design is reproduced.
exposure_horizon_months <- 36L
exposure_source <- 'isd_county'
script_arguments <- commandArgs(trailingOnly = TRUE)
if (length(script_arguments) > 0L) {
  exposure_horizon_months <- as.integer(script_arguments[1])
}
if (length(script_arguments) > 1L) {
  exposure_source <- script_arguments[2]
}
if (is.na(exposure_horizon_months) || exposure_horizon_months < 1L) {
  stop('The exposure horizon must be a positive number of months.')
}
source_labels <- c(
  isd_county = 'ISD or county',
  isd_only = 'ISD only',
  county_only = 'county only',
  any_noncity = 'any non-city government',
  isd_overlap_any = 'ISD with any positive city-area overlap',
  isd_overlap_20 = 'ISD with at least 20% city-area overlap',
  isd_overlap_25 = 'ISD with at least 25% city-area overlap',
  isd_overlap_50 = 'ISD with at least 50% city-area overlap',
  isd_overlap_80 = 'ISD with at least 80% city-area overlap'
)
if (!(exposure_source %in% names(source_labels))) {
  stop('Exposure source must be one of: isd_county, isd_only, county_only, any_noncity, isd_overlap_any, isd_overlap_20, isd_overlap_25, isd_overlap_50, isd_overlap_80.')
}
source_label <- unname(source_labels[exposure_source])
is_spatial_overlap_exposure <- exposure_source %in% c(
  'isd_overlap_any', 'isd_overlap_20', 'isd_overlap_25', 'isd_overlap_50', 'isd_overlap_80'
)
if (is_spatial_overlap_exposure && exposure_horizon_months == 360L) {
  exposure_description <- sprintf(
    'a defeated %s at any earlier point in the observed election history (back to 1995)',
    source_label
  )
  exposure_note <- 'It is a spatial city-area overlap proxy, not an observed shared-electorate measure.'
} else if (is_spatial_overlap_exposure) {
  exposure_description <- sprintf(
    'a defeated %s during the preceding %d complete months',
    source_label,
    exposure_horizon_months
  )
  exposure_note <- 'It is a spatial city-area overlap proxy, not an observed shared-electorate measure.'
} else {
  exposure_description <- sprintf(
    'a defeated %s proposition in the city\'s recorded county during the preceding %d complete months',
    source_label,
    exposure_horizon_months
  )
  exposure_note <- 'It is a county co-location proxy, not an observed shared-electorate measure.'
}

# %% Set paths
root <- normalizePath(getwd(), mustWork = TRUE)
raw_election_path <- file.path(root, 'Data/TX/20240510_TX_local_election.csv')
city_month_path <- file.path(
  root,
  'Data/Clean_Intermediate/TX/Regression/city_month_media_regression_ready.csv'
)
election_media_path <- file.path(
  root,
  'Data/Clean_Intermediate/TX/Regression/election_media_regression_ready.csv'
)
website_regression_path <- file.path(
  root,
  'Data/Clean_Intermediate/TX/Regression/website_city_year_regression_ready.csv'
)
issue_path <- file.path(
  root,
  'Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
)
overlap_exposure_dir <- file.path(root, 'Data/Clean_Intermediate/TX/Election_Exposure')
paper_table_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')
if (exposure_horizon_months == 36L && exposure_source == 'isd_county') {
  results_dir <- file.path(root, 'Results/TX ISD County Failure Exposure Nearest Controls')
} else {
  results_dir <- file.path(
    root,
    'Results',
    paste0(
      'TX ', gsub(' ', '_', source_label),
      ' Failure Exposure Nearest Controls ', exposure_horizon_months, 'm'
    )
  )
}
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(paper_table_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(raw_election_path)) stop('The raw Texas election file is missing.')
if (!file.exists(city_month_path)) stop('The Texas city-month panel is missing.')
if (!file.exists(election_media_path)) stop('The Texas election-media file is missing.')
if (!file.exists(website_regression_path)) stop('The regression-ready Texas website panel is missing.')
if (!file.exists(issue_path)) stop('The city bond-issuance file is missing.')

# %% Step 1: Load city-month data and assign each city to its recorded county
city_month <- fread(city_month_path)
city_month[, seed_issuer := tolower(trimws(seed_issuer))]
city_month[, month_date := as.IDate(sprintf('%04d-%02d-01', year, month))]

# geoname is recorded as "County, TX." Use one stable county assignment for
# every city so early observations without control variables are retained.
city_county <- city_month[
  !is.na(geoname) & grepl(', TX$', geoname),
  .(county = tolower(trimws(sub(', TX$', '', geoname)))),
  by = seed_issuer
][, .(county = first(county)), by = seed_issuer]
city_month <- city_county[city_month, on = .(seed_issuer)]
if (city_month[, any(is.na(county) | county == '')]) {
  stop('Some city-month observations could not be assigned to a county.')
}

# %% Step 2: Identify defeated propositions that define the selected exposure
raw_elections <- fread(raw_election_path)
raw_elections[, election_date := as.IDate(ElectionDate, format = '%m/%d/%Y')]
raw_elections[, county := tolower(trimws(County))]

# Retain proposition-level failures. A city is exposed if at least one selected
# failure occurred in its county; multiple failures do not change the binary
# exposure indicator used in the main tests.
if (exposure_source == 'isd_county') {
  source_failures <- raw_elections[GovernmentType %in% c('ISD', 'COUNTY')]
} else if (exposure_source == 'isd_only') {
  source_failures <- raw_elections[GovernmentType == 'ISD']
} else if (exposure_source == 'county_only') {
  source_failures <- raw_elections[GovernmentType == 'COUNTY']
} else {
  source_failures <- raw_elections[GovernmentType != 'CITY']
}
source_failures <- unique(source_failures[
  Result == 'Defeated' & !is.na(election_date) & !is.na(county) & county != '',
  .(county, failure_month = as.IDate(format(election_date, '%Y-%m-01')))
])

# For the continuous measure, retain every non-city proposition with reported
# votes. Prior Opposition is the negative of the average proposition margin,
# so larger values mean closer/larger prior rejections rather than support.
noncity_vote_margins <- raw_elections[
  GovernmentType != 'CITY' & !is.na(election_date) &
    !is.na(county) & county != '' &
    !is.na(VotesFor) & !is.na(VotesAgainst) & (VotesFor + VotesAgainst) > 0,
  .(
    county,
    election_month = as.IDate(format(election_date, '%Y-%m-01')),
    proposition_margin = (VotesFor - VotesAgainst) / (VotesFor + VotesAgainst)
  )
]
noncity_margin_month <- noncity_vote_margins[
  , .(
    noncity_propositions_this_month = .N,
    noncity_margin_sum_this_month = sum(proposition_margin)
  ),
  by = .(county, election_month)
]

# %% Step 3: Measure prior-horizon exposure before every city-month outcome
county_month <- unique(city_month[, .(county, year, month)])
county_month[, month_date := as.IDate(sprintf('%04d-%02d-01', year, month))]
county_month[, isd_or_county_failure_this_month := as.integer(
  paste(county, month_date) %in% paste(source_failures$county, source_failures$failure_month)
)]
county_month <- merge(
  county_month,
  noncity_margin_month,
  by.x = c('county', 'month_date'),
  by.y = c('county', 'election_month'),
  all.x = TRUE
)
county_month[is.na(noncity_propositions_this_month), noncity_propositions_this_month := 0L]
county_month[is.na(noncity_margin_sum_this_month), noncity_margin_sum_this_month := 0]
setorder(county_month, county, month_date)

# Exposure excludes the current month and sums t-horizon through t-1.
county_month[, failed_propositions_prior_horizon := 0L]
county_month[, noncity_propositions_prior_horizon := 0L]
county_month[, noncity_margin_sum_prior_horizon := 0]
for (months_back in 1:exposure_horizon_months) {
  county_month[, failed_propositions_prior_horizon :=
    failed_propositions_prior_horizon + shift(isd_or_county_failure_this_month, months_back, fill = 0L),
    by = county
  ]
  county_month[, noncity_propositions_prior_horizon :=
    noncity_propositions_prior_horizon + shift(noncity_propositions_this_month, months_back, fill = 0L),
    by = county
  ]
  county_month[, noncity_margin_sum_prior_horizon :=
    noncity_margin_sum_prior_horizon + shift(noncity_margin_sum_this_month, months_back, fill = 0),
    by = county
  ]
}
county_month[, prior_isd_or_county_failure := as.integer(
  failed_propositions_prior_horizon > 0L
)]
county_month[, prior_opposition := fifelse(
  noncity_propositions_prior_horizon > 0L,
  -noncity_margin_sum_prior_horizon / noncity_propositions_prior_horizon,
  NA_real_
)]

city_month <- merge(
  city_month,
  county_month[, .(county, year, month, prior_isd_or_county_failure, prior_opposition)],
  by = c('county', 'year', 'month'),
  all.x = TRUE
)
if (is_spatial_overlap_exposure) {
  if (!(exposure_horizon_months %in% c(12L, 24L, 36L, 60L, 360L))) {
    stop('The spatial-overlap panel currently provides 12-, 24-, 36-, 60-, and 360-month windows.')
  }
  overlap_file <- if (exposure_source == 'isd_overlap_any') {
    file.path(overlap_exposure_dir, 'city_month_isd_failure_exposure_any_overlap.csv')
  } else if (exposure_source == 'isd_overlap_20') {
    file.path(overlap_exposure_dir, 'city_month_isd_failure_exposure_20pct.csv')
  } else if (exposure_source == 'isd_overlap_25') {
    file.path(overlap_exposure_dir, 'city_month_isd_failure_exposure_25pct.csv')
  } else if (exposure_source == 'isd_overlap_50') {
    file.path(overlap_exposure_dir, 'city_month_isd_failure_exposure_50pct.csv')
  } else {
    file.path(overlap_exposure_dir, 'city_month_high_overlap_isd_failure_exposure.csv')
  }
  website_overlap_file <- if (exposure_source == 'isd_overlap_any') {
    file.path(overlap_exposure_dir, 'website_city_year_isd_failure_exposure_any_overlap.csv')
  } else if (exposure_source == 'isd_overlap_20') {
    file.path(overlap_exposure_dir, 'website_city_year_isd_failure_exposure_20pct.csv')
  } else if (exposure_source == 'isd_overlap_25') {
    file.path(overlap_exposure_dir, 'website_city_year_isd_failure_exposure_25pct.csv')
  } else if (exposure_source == 'isd_overlap_50') {
    file.path(overlap_exposure_dir, 'website_city_year_isd_failure_exposure_50pct.csv')
  } else {
    file.path(overlap_exposure_dir, 'website_city_year_high_overlap_isd_failure_exposure.csv')
  }
  if (!file.exists(overlap_file)) {
    stop('The requested ISD-overlap exposure panel is missing.')
  }
  if (!file.exists(website_overlap_file)) {
    stop('The requested website-city ISD-overlap exposure panel is missing.')
  }
  overlap_column <- paste0('prior_failure_any_', exposure_horizon_months, 'm')
  overlap_observed_column <- paste0('spatial_exposure_observed_', exposure_horizon_months, 'm')
  overlap_exposure <- fread(overlap_file)
  overlap_exposure[, seed_issuer := tolower(trimws(seed_issuer))]
  overlap_exposure <- overlap_exposure[, .(
    seed_issuer,
    year,
    month,
    prior_isd_or_county_failure = get(overlap_column)
  )]
  city_month[, prior_isd_or_county_failure := NULL]
  city_month <- merge(
    city_month,
    overlap_exposure,
    by = c('seed_issuer', 'year', 'month'),
    all.x = TRUE
  )
  website_overlap_exposure <- fread(website_overlap_file)
  if (!(overlap_observed_column %in% names(website_overlap_exposure))) {
    stop('The website-city ISD-overlap panel does not report coverage for this horizon.')
  }
  website_overlap_exposure[, seed_issuer := tolower(trimws(seed_key))]
  website_overlap_exposure <- website_overlap_exposure[, .(
    seed_issuer,
    year,
    prior_isd_or_county_failure = get(overlap_column),
    spatial_exposure_observed = get(overlap_observed_column)
  )]
}
if (city_month[, any(is.na(prior_isd_or_county_failure))]) {
  stop('The ISD/county failure exposure did not merge to every city-month.')
}
city_month[, year_month_id := year * 12L + month]

# %% Step 4: Test whether exposure changes the probability of a city election
election_likelihood_sample <- city_month[
  !is.na(has_bond_election) & !is.na(fips)
]
election_likelihood_raw <- election_likelihood_sample[
  , .(
    city_months = .N,
    city_election_months = sum(has_bond_election),
    city_election_rate = mean(has_bond_election)
  ),
  by = prior_isd_or_county_failure
]
election_likelihood_model <- feols(
  has_bond_election ~ prior_isd_or_county_failure | seed_issuer + year_month_id,
  data = election_likelihood_sample,
  cluster = ~fips,
  notes = FALSE
)

# Annual alternative: whether a city holds any bond election in calendar year
# t. Exposure is measured on January 1 of year t, so it is strictly prior to
# every possible election in that year.
city_year_elections <- city_month[
  !is.na(fips),
  .(city_bond_election_year = as.integer(any(has_bond_election == 1L))),
  by = .(seed_issuer, year)
]
city_year_start_exposure <- city_month[
  month == 1L & !is.na(fips),
  .(seed_issuer, year, fips, prior_isd_or_county_failure)
]
city_year_incidence_sample <- merge(
  city_year_elections,
  city_year_start_exposure,
  by = c('seed_issuer', 'year'),
  all.x = TRUE
)
if (city_year_incidence_sample[, any(is.na(prior_isd_or_county_failure))]) {
  stop('The January city-year exposure did not merge to every city-year.')
}
city_year_incidence_raw <- city_year_incidence_sample[
  , .(
    city_years = .N,
    city_election_years = sum(city_bond_election_year),
    city_election_year_rate = mean(city_bond_election_year)
  ),
  by = prior_isd_or_county_failure
]
city_year_incidence_model <- feols(
  city_bond_election_year ~ prior_isd_or_county_failure | seed_issuer + year,
  data = city_year_incidence_sample,
  cluster = ~fips,
  notes = FALSE
)

# %% Step 5: Build the full city-year panel used by the paper regression
# Election Year is one if the city held any bond election during the year.
# Exposed is one if a prior ISD or county failure occurred before at least one
# month in that city-year. The interaction asks whether the election-year
# disclosure response differs after a local failure.
city_year <- city_month[
  !is.na(fips),
  .(
    election_year = as.integer(any(has_bond_election == 1L)),
    prior_isd_or_county_failure = if (any(has_bond_election == 1L)) {
      max(prior_isd_or_county_failure[has_bond_election == 1L])
    } else {
      max(prior_isd_or_county_failure)
    },
    prior_opposition = if (any(has_bond_election == 1L)) {
      mean(prior_opposition[has_bond_election == 1L], na.rm = TRUE)
    } else {
      mean(prior_opposition, na.rm = TRUE)
    },
    fips = first(fips),
    ln_county_gdp_prior = mean(ln_county_gdp_prior, na.rm = TRUE),
    ln_county_pop_prior = mean(ln_county_pop_prior, na.rm = TRUE),
    ln_county_pers_inc_prior = mean(ln_county_pers_inc_prior, na.rm = TRUE)
  ),
  by = .(seed_issuer, year)
]
city_year[is.nan(ln_county_gdp_prior), ln_county_gdp_prior := NA_real_]
city_year[is.nan(ln_county_pop_prior), ln_county_pop_prior := NA_real_]
city_year[is.nan(ln_county_pers_inc_prior), ln_county_pers_inc_prior := NA_real_]
city_year[is.nan(prior_opposition), prior_opposition := NA_real_]

# The issuance-year indicator matches the paper: one if the city appears in
# the Texas Mergent issue file in that calendar year.
issue_data <- as.data.table(read_dta(issue_path))
issue_city_year <- unique(issue_data[
  state == 'TX' & !is.na(seed_issuer) & !is.na(year),
  .(seed_issuer = tolower(trimws(seed_issuer)), year, issue_id)
])
issuance_year <- issue_city_year[
  , .(issuance_year = as.integer(uniqueN(issue_id) > 0L)),
  by = .(seed_issuer, year)
]

# %% Step 6: Build the two annual website disclosure outcomes
# Start from the same regression-ready website panel used in Table 4 Panel A.
# This keeps its FIPS assignments, issuance indicator, and nearest-year county
# controls when estimating the overlapping-ISD specification.
website <- fread(website_regression_path)
website[, seed_issuer := tolower(trimws(seed_issuer))]
website <- website[!is.na(seed_issuer) & seed_issuer != '']
website <- unique(website, by = c('seed_issuer', 'year'))
website[, bond_count := as.numeric(bond_count)]
setorder(website, seed_issuer, year)
website[, lag_bond_count := shift(bond_count), by = seed_issuer]
website[, website_bond_text_increase := as.integer(bond_count > lag_bond_count)]

# For the spatial design, merge the exposure constructed from every website
# city, including cities without RavenPack coverage.  Do not code a missing
# Census place boundary as zero: retain it as missing and exclude it from the
# regression sample below.  The coverage flag makes that restriction auditable.
if (is_spatial_overlap_exposure) {
  website_city_year <- merge(
    website,
    website_overlap_exposure,
    by = c('seed_issuer', 'year'),
    all.x = TRUE
  )
  # Prior Opposition remains the county-based continuous sensitivity measure.
  # It is not used in the spatial-failure specification, but retaining it
  # keeps the existing optional sensitivity outputs available.
  website_city_year <- merge(
    website_city_year,
    city_year[, .(seed_issuer, year, prior_opposition)],
    by = c('seed_issuer', 'year'),
    all.x = TRUE
  )
  if (website_city_year[, any(is.na(spatial_exposure_observed))]) {
    stop('Some website city-years did not merge to the full-city spatial exposure panel.')
  }
  website_city_year[
    spatial_exposure_observed == 0L,
    prior_isd_or_county_failure := NA_integer_
  ]
} else {
  city_year_spatial_exposure <- city_year[, .(
    seed_issuer,
    year,
    prior_isd_or_county_failure,
    prior_opposition
  )]
  website_city_year <- merge(
    website,
    city_year_spatial_exposure,
    by = c('seed_issuer', 'year'),
    all.x = TRUE
  )
}
website_city_year[, election_year := as.integer(election == 1L)]
website_city_year[is.na(issuance_year), issuance_year := 0L]

increase_sample <- website_city_year[
  !is.na(fips) & !is.na(website_bond_text_increase) &
    !is.na(prior_isd_or_county_failure) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
count_sample <- website_city_year[
  !is.na(fips) & !is.na(bond_count) &
    !is.na(prior_isd_or_county_failure) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior) &
    total_subs == 50
]
count_unrestricted_sample <- website_city_year[
  !is.na(fips) & !is.na(bond_count) &
    !is.na(prior_isd_or_county_failure) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]

# %% Step 7: Estimate disclosure in two columns
# Column 1 is the binary increase indicator. Column 2 is the count of bond-text
# mentions, estimated with Poisson pseudo-maximum likelihood. Both columns use
# the paper's issuance-year and county controls; only Election Year is varied
# through its interaction with the local-failure exposure.
bond_text_increase_model <- feols(
  website_bond_text_increase ~ election_year * prior_isd_or_county_failure +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = increase_sample,
  cluster = ~fips,
  notes = FALSE
)
bond_text_count_model <- fepois(
  bond_count ~ election_year * prior_isd_or_county_failure +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = count_sample,
  cluster = ~fips,
  notes = FALSE
)

# Robustness: remove the equal-50-sub-URL restriction. This retains more
# website city-years, but bond-count measurement is less comparable when the
# number of processed sub-URLs varies across observations.
bond_text_count_unrestricted_model <- fepois(
  bond_count ~ election_year * prior_isd_or_county_failure +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = count_unrestricted_sample,
  cluster = ~fips,
  notes = FALSE
)

# Continuous alternative: higher Prior Opposition means a lower average vote
# margin on non-city propositions in the preceding 36 months. City-years with
# no prior non-city vote are excluded because the average margin is undefined.
opposition_increase_sample <- increase_sample[!is.na(prior_opposition)]
opposition_count_sample <- count_sample[!is.na(prior_opposition)]
prior_opposition_increase_model <- feols(
  website_bond_text_increase ~ election_year * prior_opposition +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = opposition_increase_sample,
  cluster = ~fips,
  notes = FALSE
)
prior_opposition_count_model <- fepois(
  bond_count ~ election_year * prior_opposition +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = opposition_count_sample,
  cluster = ~fips,
  notes = FALSE
)

# Threshold versions of Prior Opposition use cutoffs from the full increase
# sample. The same cutoffs are then applied to both outcome columns.
prior_opposition_median <- median(opposition_increase_sample$prior_opposition)
prior_opposition_upper_quartile <- quantile(
  opposition_increase_sample$prior_opposition, 0.75, names = FALSE
)
opposition_increase_sample[, prior_opposition_above_median := as.integer(
  prior_opposition >= prior_opposition_median
)]
opposition_increase_sample[, prior_opposition_upper_quartile := as.integer(
  prior_opposition >= prior_opposition_upper_quartile
)]
opposition_count_sample[, prior_opposition_above_median := as.integer(
  prior_opposition >= prior_opposition_median
)]
opposition_count_sample[, prior_opposition_upper_quartile := as.integer(
  prior_opposition >= prior_opposition_upper_quartile
)]

opposition_median_increase_model <- feols(
  website_bond_text_increase ~ election_year * prior_opposition_above_median +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = opposition_increase_sample,
  cluster = ~fips,
  notes = FALSE
)
opposition_median_count_model <- fepois(
  bond_count ~ election_year * prior_opposition_above_median +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = opposition_count_sample,
  cluster = ~fips,
  notes = FALSE
)
opposition_upper_quartile_increase_model <- feols(
  website_bond_text_increase ~ election_year * prior_opposition_upper_quartile +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = opposition_increase_sample,
  cluster = ~fips,
  notes = FALSE
)
opposition_upper_quartile_count_model <- fepois(
  bond_count ~ election_year * prior_opposition_upper_quartile +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = opposition_count_sample,
  cluster = ~fips,
  notes = FALSE
)

increase_raw <- increase_sample[
  , .(
    city_election_years = .N,
    bond_text_increase_rate = mean(website_bond_text_increase)
  ),
  by = .(election_year, prior_isd_or_county_failure)
]
count_raw <- count_sample[
  , .(
    city_election_years = .N,
    mean_bond_text_count = mean(bond_count)
  ),
  by = .(election_year, prior_isd_or_county_failure)
]

# %% Step 8: Validate that exposure predicts subsequent city bond failure
# This is descriptive only. It uses city election months, and the exposure is
# still measured before the city election month. The proposition failure rate
# weights each city bond proposition equally; the first rate weights city
# election months equally.
failure_validation <- city_month[
  has_bond_election == 1L & !is.na(num_failed_elections) & !is.na(num_bond_elections),
  .(
    city_election_months = .N,
    share_with_any_city_bond_failure = mean(num_failed_elections > 0L),
    city_bond_propositions = sum(num_bond_elections),
    failed_city_bond_propositions = sum(num_failed_elections),
    city_bond_proposition_failure_rate = sum(num_failed_elections) / sum(num_bond_elections)
  ),
  by = prior_isd_or_county_failure
]

# %% Step 9: Test election-window media coverage after an ISD/county failure
# This follows Panel B of 03_election_outcomes.R. The outcome is an indicator
# for any bond-related article. Election and issuance windows cover the current
# month through the following three months; fixed effects are city and month.
# The interaction asks whether election-window coverage is higher after a
# prior local ISD or county failure.
election_media <- fread(election_media_path)
media_eligible_cities <- unique(tolower(trimws(election_media[
  unique_sources_12m_prior > 0L, seed_issuer
])))

issue_month <- unique(issue_data[
  state == 'TX' & !is.na(seed_issuer) & !is.na(year) & !is.na(month),
  .(seed_issuer = tolower(trimws(seed_issuer)), year, month)
])
issue_month[, issuance_this_month := 1L]

media_city_month <- copy(city_month)
if ('issuance_this_month' %in% names(media_city_month)) {
  media_city_month[, issuance_this_month := NULL]
}
media_city_month <- merge(
  media_city_month,
  issue_month,
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)
media_city_month[is.na(issuance_this_month), issuance_this_month := 0L]
setorder(media_city_month, seed_issuer, year, month)
media_city_month[, election_window := as.integer(
  has_bond_election == 1L |
    shift(has_bond_election, 1L, type = 'lead', fill = 0L) == 1L |
    shift(has_bond_election, 2L, type = 'lead', fill = 0L) == 1L |
    shift(has_bond_election, 3L, type = 'lead', fill = 0L) == 1L
), by = seed_issuer]
media_city_month[, issuance_window := as.integer(
  issuance_this_month == 1L |
    shift(issuance_this_month, 1L, type = 'lead', fill = 0L) == 1L |
    shift(issuance_this_month, 2L, type = 'lead', fill = 0L) == 1L |
    shift(issuance_this_month, 3L, type = 'lead', fill = 0L) == 1L
), by = seed_issuer]
media_city_month[, covered := as.integer(rp_article_count > 0L)]

# Match Table 4 Panel B's original 2003--2024 common sample.  The original
# table began in 2003 because prior-year county employment was unavailable in
# 2001--02; use the date window directly rather than filter on that unused
# control.
media_coverage_sample <- media_city_month[
  seed_issuer %in% media_eligible_cities & !is.na(fips) &
    !is.na(covered) & !is.na(ln_county_gdp_prior) &
    !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior) &
    year >= 2003L
]
media_coverage_model <- feols(
  covered ~ election_window * prior_isd_or_county_failure +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_coverage_sample,
  cluster = ~fips,
  notes = FALSE
)
media_coverage_coefficients <- as.data.table(
  coeftable(media_coverage_model), keep.rownames = 'term'
)
media_coverage_interaction <- media_coverage_coefficients[
  grepl('election_window:prior_isd_or_county_failure|prior_isd_or_county_failure:election_window', term)
]

# Poisson robustness: retain the same 32,208 city-months, controls, fixed
# effects, and clustering, but use the count of bond-related articles rather
# than the extensive-margin coverage indicator.  Coefficients are log IRRs.
media_article_count_model <- fepois(
  rp_article_count ~ election_window * prior_isd_or_county_failure +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_coverage_sample,
  cluster = ~fips,
  notes = FALSE
)
media_article_count_coefficients <- as.data.table(
  coeftable(media_article_count_model), keep.rownames = 'term'
)
media_article_count_interaction <- media_article_count_coefficients[
  grepl('election_window:prior_isd_or_county_failure|prior_isd_or_county_failure:election_window', term)
]
media_coverage_table_tex <- fixest::etable(
  media_coverage_model,
  coefstat = 'tstat',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = 'n',
  se.below = TRUE,
  digits = 'r3',
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = c(
    covered = 'Bond Coverage',
    election_window = 'Election [0, +3]',
    prior_isd_or_county_failure = 'Exposed',
    `election_window:prior_isd_or_county_failure` = 'Election [0, +3] $\\times$ Exposed',
    issuance_window = 'Bond Issuance [0, +3]',
    ln_county_gdp_prior = 'County ln(GDP)',
    ln_county_pop_prior = 'County ln(Pop)',
    ln_county_pers_inc_prior = 'County ln(Pers. Inc.)',
    seed_issuer = 'City',
    year_month_id = 'Year-Month'
  ),
  placement = 'H',
  replace = TRUE
)
media_article_count_table_tex <- fixest::etable(
  media_article_count_model,
  coefstat = 'tstat',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'pr2'),
  se.below = TRUE,
  digits = 'r3',
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = c(
    rp_article_count = 'Bond Article Count',
    election_window = 'Election [0, +3]',
    prior_isd_or_county_failure = 'Prior ISD Failure',
    `election_window:prior_isd_or_county_failure` = 'Election [0, +3] $\\times$ Prior ISD Failure',
    issuance_window = 'Bond Issuance [0, +3]',
    ln_county_gdp_prior = 'County ln(GDP)',
    ln_county_pop_prior = 'County ln(Pop)',
    ln_county_pers_inc_prior = 'County ln(Pers. Inc.)',
    seed_issuer = 'City',
    year_month_id = 'Year-Month'
  ),
  placement = 'H',
  replace = TRUE
)

# %% Step 10: Save the paper-style tables and supporting outputs
election_coefficient <- as.data.table(coeftable(election_likelihood_model), keep.rownames = 'term')[
  term == 'prior_isd_or_county_failure'
]
city_year_incidence_coefficient <- as.data.table(
  coeftable(city_year_incidence_model), keep.rownames = 'term'
)[
  term == 'prior_isd_or_county_failure'
]
increase_coefficients <- as.data.table(
  coeftable(bond_text_increase_model), keep.rownames = 'term'
)
count_coefficients <- as.data.table(
  coeftable(bond_text_count_model), keep.rownames = 'term'
)
count_unrestricted_coefficients <- as.data.table(
  coeftable(bond_text_count_unrestricted_model), keep.rownames = 'term'
)
increase_interaction <- increase_coefficients[
  grepl('election_year:prior_isd_or_county_failure|prior_isd_or_county_failure:election_year', term)
]
count_interaction <- count_coefficients[
  grepl('election_year:prior_isd_or_county_failure|prior_isd_or_county_failure:election_year', term)
]
count_unrestricted_interaction <- count_unrestricted_coefficients[
  grepl('election_year:prior_isd_or_county_failure|prior_isd_or_county_failure:election_year', term)
]

# Table 4 Panel C. Write this paper-facing panel only for the 80-percent
# overlap, all-prior-failure specification, so a later sensitivity run cannot
# overwrite the table selected for the paper.
if (exposure_source == 'isd_overlap_80' && exposure_horizon_months == 360L) {
  panel_c_rows <- data.table(
    outcome = c('Increase in Bond Text', 'Bond Coverage'),
    estimate = c(increase_interaction$Estimate, media_coverage_interaction$Estimate),
    std_error = c(increase_interaction$`Std. Error`, media_coverage_interaction$`Std. Error`),
    p_value = c(increase_interaction$`Pr(>|t|)`, media_coverage_interaction$`Pr(>|t|)`),
    observations = c(nobs(bond_text_increase_model), nobs(media_coverage_model))
  )
  panel_c_etable <- etable(
    bond_text_increase_model,
    media_coverage_model,
    coefstat = 'tstat',
    keep_raw = 'election_year|election_window|prior_isd_or_county_failure',
    order_raw = c(
      '^election_year$',
      '^election_year:prior_isd_or_county_failure$',
      '^election_window$',
      '^election_window:prior_isd_or_county_failure$',
      '^prior_isd_or_county_failure$'
    ),
    style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
    fitstat = c('n', 'ar2'),
    se.below = TRUE,
    digits = 3,
    digits.stats = 3,
    signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
    tex = TRUE,
    dict = c(
      website_bond_text_increase = 'Increase in Bond Text',
      covered = 'Bond Coverage',
      election_year = 'Election Year',
      prior_isd_or_county_failure = 'Prior ISD Failure',
      `election_year:prior_isd_or_county_failure` = 'Election Year $\\times$ Prior ISD Failure',
      election_window = 'Election [0, +3]',
      `election_window:prior_isd_or_county_failure` = 'Election [0, +3] $\\times$ Prior ISD Failure',
      seed_issuer = 'City',
      year = 'Year',
      year_month_id = 'Year-Month'
    ),
    extralines = list(
      'County controls' = c('Yes', 'Yes')
    ),
    placement = 'H',
    replace = TRUE
  )
  panel_c_table_tex <- modify_etable_rounding(
    panel_c_etable,
    coef_digits = 3,
    tstat_digits = 2
  )
  panel_c_table_tex <- format_table(panel_c_table_tex, cluster_level = 'County')
  panel_c_table_tex <- add_panel(
    panel_c_table_tex,
    'Panel C: City behavior after an overlapping ISD bond failure',
    ncols = 3
  )
  writeLines(
    panel_c_table_tex,
    file.path(paper_table_dir, 'tx_prior_overlap_failure_panel_c.tex')
  )
  fwrite(
    panel_c_rows,
    file.path(results_dir, 'table4_panel_c_prior_overlap_failure.csv')
  )
}

# This is intentionally the same presentation style as the paper's website
# regression: outcome in each column, city and year fixed effects, clustered
# standard errors, issuance year, and county controls.
disclosure_table_tex <- fixest::etable(
  bond_text_increase_model,
  bond_text_count_model,
  coefstat = 'tstat',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = 'n',
  se.below = TRUE,
  digits = 'r3',
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = c(
    website_bond_text_increase = 'Increase in Bond Text',
    bond_count = 'Bond Count',
    election_year = 'Election Year',
    prior_isd_or_county_failure = 'Exposed',
    `election_year:prior_isd_or_county_failure` = 'Election Year $\\times$ Exposed',
    issuance_year = 'Bond Issuance Year',
    ln_county_gdp_prior = 'County ln(GDP)',
    ln_county_pop_prior = 'County ln(Pop)',
    ln_county_pers_inc_prior = 'County ln(Pers. Inc.)',
    seed_issuer = 'City',
    year = 'Year'
  ),
  placement = 'H',
  replace = TRUE
)

opposition_increase_coefficients <- as.data.table(
  coeftable(prior_opposition_increase_model), keep.rownames = 'term'
)
opposition_count_coefficients <- as.data.table(
  coeftable(prior_opposition_count_model), keep.rownames = 'term'
)
opposition_increase_interaction <- opposition_increase_coefficients[
  grepl('election_year:prior_opposition|prior_opposition:election_year', term)
]
opposition_count_interaction <- opposition_count_coefficients[
  grepl('election_year:prior_opposition|prior_opposition:election_year', term)
]
opposition_median_increase_interaction <- as.data.table(
  coeftable(opposition_median_increase_model), keep.rownames = 'term'
)[
  grepl('election_year:prior_opposition_above_median|prior_opposition_above_median:election_year', term)
]
opposition_median_count_interaction <- as.data.table(
  coeftable(opposition_median_count_model), keep.rownames = 'term'
)[
  grepl('election_year:prior_opposition_above_median|prior_opposition_above_median:election_year', term)
]
opposition_upper_quartile_increase_interaction <- as.data.table(
  coeftable(opposition_upper_quartile_increase_model), keep.rownames = 'term'
)[
  grepl('election_year:prior_opposition_upper_quartile|prior_opposition_upper_quartile:election_year', term)
]
opposition_upper_quartile_count_interaction <- as.data.table(
  coeftable(opposition_upper_quartile_count_model), keep.rownames = 'term'
)[
  grepl('election_year:prior_opposition_upper_quartile|prior_opposition_upper_quartile:election_year', term)
]

prior_opposition_indicator_models <- rbindlist(list(
  data.table(
    cutoff = 'Above median', outcome = 'Increase in Bond Text',
    estimate = opposition_median_increase_interaction$Estimate,
    std_error = opposition_median_increase_interaction$`Std. Error`,
    p_value = opposition_median_increase_interaction$`Pr(>|t|)`,
    observations = nobs(opposition_median_increase_model)
  ),
  data.table(
    cutoff = 'Above median', outcome = 'Bond Count (Poisson log IRR)',
    estimate = opposition_median_count_interaction$Estimate,
    std_error = opposition_median_count_interaction$`Std. Error`,
    p_value = opposition_median_count_interaction$`Pr(>|z|)`,
    observations = nobs(opposition_median_count_model)
  ),
  data.table(
    cutoff = 'Upper quartile', outcome = 'Increase in Bond Text',
    estimate = opposition_upper_quartile_increase_interaction$Estimate,
    std_error = opposition_upper_quartile_increase_interaction$`Std. Error`,
    p_value = opposition_upper_quartile_increase_interaction$`Pr(>|t|)`,
    observations = nobs(opposition_upper_quartile_increase_model)
  ),
  data.table(
    cutoff = 'Upper quartile', outcome = 'Bond Count (Poisson log IRR)',
    estimate = opposition_upper_quartile_count_interaction$Estimate,
    std_error = opposition_upper_quartile_count_interaction$`Std. Error`,
    p_value = opposition_upper_quartile_count_interaction$`Pr(>|z|)`,
    observations = nobs(opposition_upper_quartile_count_model)
  )
))
prior_opposition_indicator_models[, cutoff_value := c(
  prior_opposition_median, prior_opposition_median,
  prior_opposition_upper_quartile, prior_opposition_upper_quartile
)]

prior_opposition_table_tex <- fixest::etable(
  prior_opposition_increase_model,
  prior_opposition_count_model,
  coefstat = 'tstat',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = 'n',
  se.below = TRUE,
  digits = 'r3',
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = c(
    website_bond_text_increase = 'Increase in Bond Text',
    bond_count = 'Bond Count',
    election_year = 'Election Year',
    prior_opposition = 'Prior Opposition',
    `election_year:prior_opposition` = 'Election Year $\\times$ Prior Opposition',
    issuance_year = 'Bond Issuance Year',
    ln_county_gdp_prior = 'County ln(GDP)',
    ln_county_pop_prior = 'County ln(Pop)',
    ln_county_pers_inc_prior = 'County ln(Pers. Inc.)',
    seed_issuer = 'City',
    year = 'Year'
  ),
  placement = 'H',
  replace = TRUE
)

model_summary <- data.table(
  outcome = c(
    'City bond election in month',
    'City bond election in year (January exposure)',
    'Election Year x Exposed: bond-text increase',
    'Election Year x Exposed: bond-text count (Poisson log IRR)',
    'Election Year x Exposed: bond-text count, unrestricted (Poisson log IRR)',
    'Election [0, +3] x Exposed: bond coverage',
    'Election [0, +3] x Exposed: bond article count (Poisson log IRR)'
  ),
  estimate = c(election_coefficient$Estimate, city_year_incidence_coefficient$Estimate, increase_interaction$Estimate,
               count_interaction$Estimate, count_unrestricted_interaction$Estimate,
               media_coverage_interaction$Estimate, media_article_count_interaction$Estimate),
  std_error = c(election_coefficient$`Std. Error`, city_year_incidence_coefficient$`Std. Error`, increase_interaction$`Std. Error`,
                count_interaction$`Std. Error`, count_unrestricted_interaction$`Std. Error`,
                media_coverage_interaction$`Std. Error`, media_article_count_interaction$`Std. Error`),
  p_value = c(election_coefficient$`Pr(>|t|)`, city_year_incidence_coefficient$`Pr(>|t|)`, increase_interaction$`Pr(>|t|)`,
              count_interaction$`Pr(>|z|)`, count_unrestricted_interaction$`Pr(>|z|)`,
              media_coverage_interaction$`Pr(>|t|)`, media_article_count_interaction$`Pr(>|z|)`),
  observations = c(nobs(election_likelihood_model), nobs(city_year_incidence_model), nobs(bond_text_increase_model),
                   nobs(bond_text_count_model), nobs(bond_text_count_unrestricted_model),
                   nobs(media_coverage_model), nobs(media_article_count_model))
)

fwrite(model_summary, file.path(results_dir, 'isd_county_failure_models.csv'))
fwrite(increase_coefficients, file.path(results_dir, 'isd_county_failure_increase_coefficients.csv'))
fwrite(count_coefficients, file.path(results_dir, 'isd_county_failure_count_coefficients.csv'))
fwrite(count_unrestricted_coefficients, file.path(results_dir, 'isd_county_failure_count_unrestricted_coefficients.csv'))
writeLines(disclosure_table_tex, file.path(results_dir, 'isd_county_failure_disclosure_table.tex'))
fwrite(opposition_increase_coefficients, file.path(results_dir, 'prior_opposition_increase_coefficients.csv'))
fwrite(opposition_count_coefficients, file.path(results_dir, 'prior_opposition_count_coefficients.csv'))
writeLines(prior_opposition_table_tex, file.path(results_dir, 'prior_opposition_disclosure_table.tex'))
fwrite(prior_opposition_indicator_models, file.path(results_dir, 'prior_opposition_indicator_models.csv'))
fwrite(election_likelihood_raw, file.path(results_dir, 'isd_county_failure_election_rates.csv'))
fwrite(city_year_incidence_raw, file.path(results_dir, 'isd_county_failure_city_year_election_rates.csv'))
fwrite(increase_raw, file.path(results_dir, 'isd_county_failure_increase_rates.csv'))
fwrite(count_raw, file.path(results_dir, 'isd_county_failure_count_rates.csv'))
fwrite(failure_validation, file.path(results_dir, 'isd_county_failure_validation_rates.csv'))
fwrite(media_coverage_coefficients, file.path(results_dir, 'isd_county_failure_media_coverage_coefficients.csv'))
writeLines(media_coverage_table_tex, file.path(results_dir, 'isd_county_failure_media_coverage_table.tex'))
fwrite(media_article_count_coefficients, file.path(results_dir, 'isd_county_failure_media_article_count_coefficients.csv'))
writeLines(media_article_count_table_tex, file.path(results_dir, 'isd_county_failure_media_article_count_table.tex'))

summary_note <- c(
  paste0('# Texas ', source_label, ' bond-failure exposure'),
  '',
  paste0('Exposure is ', exposure_description, '. ', exposure_note),
  '',
  '## City election incidence',
  sprintf('- Unexposed/exposed city-month election rates: %.3f / %.3f.',
          election_likelihood_raw[prior_isd_or_county_failure == 0L, city_election_rate],
          election_likelihood_raw[prior_isd_or_county_failure == 1L, city_election_rate]),
  sprintf('- City and year-month FE estimate: %.4f (SE %.4f; p = %.4f; N = %s).',
          election_coefficient$Estimate, election_coefficient$`Std. Error`, election_coefficient$`Pr(>|t|)`,
          format(nobs(election_likelihood_model), big.mark = ',')),
  sprintf('- Annual alternative (January exposure; city and year FE): %.4f (SE %.4f; p = %.4f; N = %s).',
          city_year_incidence_coefficient$Estimate, city_year_incidence_coefficient$`Std. Error`,
          city_year_incidence_coefficient$`Pr(>|t|)`,
          format(nobs(city_year_incidence_model), big.mark = ',')),
  '',
  '## Website disclosure: paper specification with local-failure interaction',
  'Both columns use Election Year, Election Year x Exposed, Bond Issuance Year, county controls, and city/year fixed effects. The second column also restricts to 50 processed sub-URLs, as in the paper Poisson specification.',
  sprintf('- Increase-in-bond-text interaction: %.4f (SE %.4f; p = %.4f; N = %s).',
          increase_interaction$Estimate, increase_interaction$`Std. Error`, increase_interaction$`Pr(>|t|)`,
          format(nobs(bond_text_increase_model), big.mark = ',')),
  sprintf('- Bond-count Poisson interaction: %.4f (IRR %.3f; SE %.4f; p = %.2e; N = %s).',
          count_interaction$Estimate, exp(count_interaction$Estimate), count_interaction$`Std. Error`, count_interaction$`Pr(>|z|)`,
          format(nobs(bond_text_count_model), big.mark = ',')),
  '',
  '## Media coverage: Panel B specification with local-failure interaction',
  'The media model uses Bond Coverage, Election [0, +3], Election [0, +3] x Exposed, Bond Issuance [0, +3], county controls, and city/year-month fixed effects. It uses the same media-eligible cities as Panel B in 03_election_outcomes.R.',
  sprintf('- Election-window coverage interaction: %.4f (SE %.4f; p = %.4f; N = %s).',
          media_coverage_interaction$Estimate, media_coverage_interaction$`Std. Error`, media_coverage_interaction$`Pr(>|t|)`,
          format(nobs(media_coverage_model), big.mark = ',')),
  sprintf('- Election-window article-count Poisson interaction: %.4f (IRR %.3f; SE %.4f; p = %.4f; N = %s).',
          media_article_count_interaction$Estimate, exp(media_article_count_interaction$Estimate),
          media_article_count_interaction$`Std. Error`, media_article_count_interaction$`Pr(>|z|)`,
          format(nobs(media_article_count_model), big.mark = ',')),
  '',
  '## Continuous prior-opposition specification',
  'Prior Opposition is the negative unweighted average non-city proposition margin in the preceding window. Larger values mean more prior opposition. City-years without a prior non-city vote are excluded.',
  sprintf('- Increase-in-bond-text interaction: %.4f (SE %.4f; p = %.4f; N = %s).',
          opposition_increase_interaction$Estimate, opposition_increase_interaction$`Std. Error`, opposition_increase_interaction$`Pr(>|t|)`,
          format(nobs(prior_opposition_increase_model), big.mark = ',')),
  sprintf('- Bond-count Poisson interaction: %.4f (IRR %.3f; SE %.4f; p = %.2e; N = %s).',
          opposition_count_interaction$Estimate, exp(opposition_count_interaction$Estimate), opposition_count_interaction$`Std. Error`, opposition_count_interaction$`Pr(>|z|)`,
          format(nobs(prior_opposition_count_model), big.mark = ',')),
  '',
  '## Threshold versions of prior opposition',
  sprintf('- Above-median cutoff: %.3f; increase interaction %.4f (p = %.4f); count interaction %.4f (p = %.4f).',
          prior_opposition_median,
          opposition_median_increase_interaction$Estimate, opposition_median_increase_interaction$`Pr(>|t|)`,
          opposition_median_count_interaction$Estimate, opposition_median_count_interaction$`Pr(>|z|)`),
  sprintf('- Upper-quartile cutoff: %.3f; increase interaction %.4f (p = %.4f); count interaction %.4f (p = %.4f).',
          prior_opposition_upper_quartile,
          opposition_upper_quartile_increase_interaction$Estimate, opposition_upper_quartile_increase_interaction$`Pr(>|t|)`,
          opposition_upper_quartile_count_interaction$Estimate, opposition_upper_quartile_count_interaction$`Pr(>|z|)`),
  '',
  '## Descriptive validation: subsequent city bond failure',
  sprintf('- Share of city election months with any failed city bond: %.3f unexposed / %.3f exposed.',
          failure_validation[prior_isd_or_county_failure == 0L, share_with_any_city_bond_failure],
          failure_validation[prior_isd_or_county_failure == 1L, share_with_any_city_bond_failure]),
  sprintf('- City bond-proposition failure rate: %.3f unexposed / %.3f exposed.',
          failure_validation[prior_isd_or_county_failure == 0L, city_bond_proposition_failure_rate],
          failure_validation[prior_isd_or_county_failure == 1L, city_bond_proposition_failure_rate]),
  '',
  'The LaTex disclosure table has the requested two columns: increase in bond text and bond count. The separate media table mirrors Panel B of 03_election_outcomes.R.'
)
writeLines(summary_note, file.path(results_dir, 'README.md'))

print(model_summary)
print(failure_validation)
