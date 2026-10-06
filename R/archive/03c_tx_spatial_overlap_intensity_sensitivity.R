# 03c: Alternative intensity measures for overlapping-ISD failure exposure
#
# This script starts from the corresponding 03b spatial-overlap analysis and
# then replaces the binary exposure with three interpretable alternatives:
#   1. Number of prior failed ISD propositions.
#   2. An indicator for two or more prior failed ISD propositions.
#   3. The maximum ISD share of city area exposed to a prior failed proposition.
#
# Run, for example:
# Rscript 03c_tx_spatial_overlap_intensity_sensitivity.R 36 isd_overlap_any

source('Code/R/Archive/03b_tx_county_noncity_failure_exposure.R')

if (!is_spatial_overlap_exposure) {
  stop('This sensitivity script requires a spatial-overlap source, such as isd_overlap_any.')
}

# %% Step 1: Restore the spatial exposure intensity fields
overlap_panel <- fread(overlap_file)
overlap_panel[, seed_issuer := tolower(trimws(seed_issuer))]

count_column <- paste0('prior_failure_count_', exposure_horizon_months, 'm')
share_column <- paste0('prior_failure_max_area_share_', exposure_horizon_months, 'm')
required_columns <- c('seed_issuer', 'year', 'month', count_column, share_column)
if (!all(required_columns %in% names(overlap_panel))) {
  stop('The requested overlap panel does not contain the required intensity fields.')
}

overlap_intensity <- overlap_panel[, .(
  seed_issuer,
  year,
  month,
  prior_failure_count = get(count_column),
  prior_failure_max_area_share = get(share_column)
)]
overlap_intensity[, repeated_prior_failure := as.integer(prior_failure_count >= 2L)]

# %% Step 2: Map monthly intensity measures to every regression sample
city_month_intensity <- merge(
  city_month[, .(seed_issuer, year, month, has_bond_election, fips)],
  overlap_intensity,
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)
if (city_month_intensity[, any(is.na(prior_failure_count) | is.na(prior_failure_max_area_share))]) {
  stop('The spatial intensity measures did not merge to every city-month.')
}

# The website regressions are annual. Match 03b: when there is an election,
# use the largest exposure measured in an election month; otherwise use the
# largest exposure during that calendar year.
city_year_intensity <- city_month_intensity[
  !is.na(fips),
  .(
    prior_failure_count = if (any(has_bond_election == 1L)) {
      max(prior_failure_count[has_bond_election == 1L])
    } else {
      max(prior_failure_count)
    },
    repeated_prior_failure = if (any(has_bond_election == 1L)) {
      max(repeated_prior_failure[has_bond_election == 1L])
    } else {
      max(repeated_prior_failure)
    },
    prior_failure_max_area_share = if (any(has_bond_election == 1L)) {
      max(prior_failure_max_area_share[has_bond_election == 1L])
    } else {
      max(prior_failure_max_area_share)
    }
  ),
  by = .(seed_issuer, year)
]

website_intensity <- merge(
  website_city_year,
  city_year_intensity,
  by = c('seed_issuer', 'year'),
  all.x = TRUE
)
increase_intensity <- website_intensity[
  !is.na(website_bond_text_increase) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]

media_intensity <- merge(
  media_coverage_sample,
  overlap_intensity,
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)

# Scale overlap area so its coefficient is the effect of a ten-percentage-point
# increase in affected city area, rather than a one-unit (100-point) increase.
election_intensity <- merge(
  election_likelihood_sample,
  overlap_intensity,
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)
for (dataset in list(election_intensity, increase_intensity, media_intensity)) {
  if (any(is.na(dataset$prior_failure_count) | is.na(dataset$prior_failure_max_area_share))) {
    stop('An analysis sample is missing spatial intensity values.')
  }
}
election_intensity[, prior_failure_max_area_share_10pp := prior_failure_max_area_share / 0.10]
increase_intensity[, prior_failure_max_area_share_10pp := prior_failure_max_area_share / 0.10]
media_intensity[, prior_failure_max_area_share_10pp := prior_failure_max_area_share / 0.10]

# %% Step 3: Estimate the three outcomes under each alternative definition
exposure_measures <- data.table(
  exposure_measure = c(
    'Prior failed ISD propositions (count)',
    'Two or more prior failed ISD propositions',
    'Maximum prior failed-ISD city-area share (10 pp)'
  ),
  variable = c(
    'prior_failure_count',
    'repeated_prior_failure',
    'prior_failure_max_area_share_10pp'
  )
)

extract_term <- function(model, pattern) {
  coefficients <- as.data.table(coeftable(model), keep.rownames = 'term')
  coefficients[grepl(pattern, term)][1, .(estimate = Estimate, std_error = `Std. Error`, p_value = `Pr(>|t|)`)]
}

intensity_results <- rbindlist(lapply(seq_len(nrow(exposure_measures)), function(index) {
  exposure_variable <- exposure_measures$variable[index]
  exposure_label <- exposure_measures$exposure_measure[index]

  election_model <- feols(
    as.formula(paste0('has_bond_election ~ ', exposure_variable, ' | seed_issuer + year_month_id')),
    data = election_intensity,
    cluster = ~fips,
    notes = FALSE
  )
  increase_model <- feols(
    as.formula(paste0(
      'website_bond_text_increase ~ election_year * ', exposure_variable,
      ' + issuance_year + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year'
    )),
    data = increase_intensity,
    cluster = ~fips,
    notes = FALSE
  )
  media_model <- feols(
    as.formula(paste0(
      'covered ~ election_window * ', exposure_variable,
      ' + issuance_window + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year_month_id'
    )),
    data = media_intensity,
    cluster = ~fips,
    notes = FALSE
  )

  rbindlist(list(
    cbind(
      data.table(exposure_measure = exposure_label, outcome = 'City bond election in month'),
      extract_term(election_model, paste0('^', exposure_variable, '$'))
    ),
    cbind(
      data.table(exposure_measure = exposure_label, outcome = 'Election Year x Exposure: bond-text increase'),
      extract_term(increase_model, paste0('election_year:', exposure_variable, '|', exposure_variable, ':election_year'))
    ),
    cbind(
      data.table(exposure_measure = exposure_label, outcome = 'Election [0, +3] x Exposure: bond coverage'),
      extract_term(media_model, paste0('election_window:', exposure_variable, '|', exposure_variable, ':election_window'))
    )
  ))
}))

# %% Step 4: Save the complete exploratory sensitivity table
fwrite(
  intensity_results,
  file.path(results_dir, 'spatial_overlap_intensity_sensitivity.csv')
)
print(intensity_results)
