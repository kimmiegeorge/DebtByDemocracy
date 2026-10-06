# 03d: PPML sensitivity grid for Texas media articles after overlapping ISD failure
#
# This is an exploratory grid.  Every model uses the same 2003--2024 input
# sample as Table 4 Panel B, the same controls, city and year-month fixed
# effects, and county-clustered standard errors.  Only the spatial exposure
# lookback window and city-area-overlap threshold vary.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

root <- normalizePath(getwd(), mustWork = TRUE)
regression_dir <- file.path(root, 'Data/Clean_Intermediate/TX/Regression')
exposure_dir <- file.path(root, 'Data/Clean_Intermediate/TX/Election_Exposure')
results_dir <- file.path(root, 'Results/TX PPML Media Spatial Exposure Sensitivity')
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

# %% Step 1: Reconstruct the fixed 32,208-row Panel B input sample
city_month <- fread(file.path(regression_dir, 'city_month_media_regression_ready.csv'))
election_media <- fread(file.path(regression_dir, 'election_media_regression_ready.csv'))
city_month[, seed_issuer := tolower(trimws(seed_issuer))]
election_media[, seed_issuer := tolower(trimws(seed_issuer))]

media_eligible_cities <- unique(election_media[
  unique_sources_12m_prior > 0L, seed_issuer
])
media_sample <- city_month[
  seed_issuer %in% media_eligible_cities & year >= 2003L &
    !is.na(fips) & !is.na(rp_article_count) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
if (nrow(media_sample) != 32208L) {
  stop('The fixed Panel B input sample should contain 32,208 city-months.')
}

# %% Step 2: Merge each pre-constructed spatial exposure definition
exposure_any <- fread(file.path(
  exposure_dir, 'city_month_isd_failure_exposure_any_overlap.csv'
))
exposure_50 <- fread(file.path(
  exposure_dir, 'city_month_isd_failure_exposure_50pct.csv'
))
exposure_80 <- fread(file.path(
  exposure_dir, 'city_month_high_overlap_isd_failure_exposure.csv'
))

exposure_any[, seed_issuer := tolower(trimws(seed_issuer))]
exposure_50[, seed_issuer := tolower(trimws(seed_issuer))]
exposure_80[, seed_issuer := tolower(trimws(seed_issuer))]

media_any <- merge(
  media_sample,
  exposure_any[, c('seed_issuer', 'year', 'month', grep('^prior_failure_any_', names(exposure_any), value = TRUE)), with = FALSE],
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)
media_50 <- merge(
  media_sample,
  exposure_50[, c('seed_issuer', 'year', 'month', grep('^prior_failure_any_', names(exposure_50), value = TRUE)), with = FALSE],
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)
media_80 <- merge(
  media_sample,
  exposure_80[, c('seed_issuer', 'year', 'month', grep('^prior_failure_any_', names(exposure_80), value = TRUE)), with = FALSE],
  by = c('seed_issuer', 'year', 'month'),
  all.x = TRUE
)

if (any(is.na(media_any$prior_failure_any_360m)) ||
    any(is.na(media_50$prior_failure_any_360m)) ||
    any(is.na(media_80$prior_failure_any_360m))) {
  stop('A spatial exposure definition did not merge to the fixed media sample.')
}

# %% Step 3: Estimate every exposure definition with the fixed PPML model
model_any_12 <- fepois(rp_article_count ~ election_window * prior_failure_any_12m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_any, cluster = ~fips, notes = FALSE)
model_any_24 <- fepois(rp_article_count ~ election_window * prior_failure_any_24m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_any, cluster = ~fips, notes = FALSE)
model_any_36 <- fepois(rp_article_count ~ election_window * prior_failure_any_36m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_any, cluster = ~fips, notes = FALSE)
model_any_60 <- fepois(rp_article_count ~ election_window * prior_failure_any_60m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_any, cluster = ~fips, notes = FALSE)
model_any_360 <- fepois(rp_article_count ~ election_window * prior_failure_any_360m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_any, cluster = ~fips, notes = FALSE)

model_50_12 <- fepois(rp_article_count ~ election_window * prior_failure_any_12m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_50, cluster = ~fips, notes = FALSE)
model_50_24 <- fepois(rp_article_count ~ election_window * prior_failure_any_24m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_50, cluster = ~fips, notes = FALSE)
model_50_36 <- fepois(rp_article_count ~ election_window * prior_failure_any_36m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_50, cluster = ~fips, notes = FALSE)
model_50_60 <- fepois(rp_article_count ~ election_window * prior_failure_any_60m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_50, cluster = ~fips, notes = FALSE)
model_50_360 <- fepois(rp_article_count ~ election_window * prior_failure_any_360m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_50, cluster = ~fips, notes = FALSE)

model_80_12 <- fepois(rp_article_count ~ election_window * prior_failure_any_12m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_80, cluster = ~fips, notes = FALSE)
model_80_24 <- fepois(rp_article_count ~ election_window * prior_failure_any_24m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_80, cluster = ~fips, notes = FALSE)
model_80_36 <- fepois(rp_article_count ~ election_window * prior_failure_any_36m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_80, cluster = ~fips, notes = FALSE)
model_80_60 <- fepois(rp_article_count ~ election_window * prior_failure_any_60m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_80, cluster = ~fips, notes = FALSE)
model_80_360 <- fepois(rp_article_count ~ election_window * prior_failure_any_360m +
  issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
  ln_county_pers_inc_prior | seed_issuer + year_month_id,
  data = media_80, cluster = ~fips, notes = FALSE)

# %% Step 4: Extract the election-window interaction from each model
result_any_12 <- as.data.table(coeftable(model_any_12), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_12m|prior_failure_any_12m:election_window', term)
]
result_any_24 <- as.data.table(coeftable(model_any_24), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_24m|prior_failure_any_24m:election_window', term)
]
result_any_36 <- as.data.table(coeftable(model_any_36), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_36m|prior_failure_any_36m:election_window', term)
]
result_any_60 <- as.data.table(coeftable(model_any_60), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_60m|prior_failure_any_60m:election_window', term)
]
result_any_360 <- as.data.table(coeftable(model_any_360), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_360m|prior_failure_any_360m:election_window', term)
]

result_50_12 <- as.data.table(coeftable(model_50_12), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_12m|prior_failure_any_12m:election_window', term)
]
result_50_24 <- as.data.table(coeftable(model_50_24), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_24m|prior_failure_any_24m:election_window', term)
]
result_50_36 <- as.data.table(coeftable(model_50_36), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_36m|prior_failure_any_36m:election_window', term)
]
result_50_60 <- as.data.table(coeftable(model_50_60), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_60m|prior_failure_any_60m:election_window', term)
]
result_50_360 <- as.data.table(coeftable(model_50_360), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_360m|prior_failure_any_360m:election_window', term)
]

result_80_12 <- as.data.table(coeftable(model_80_12), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_12m|prior_failure_any_12m:election_window', term)
]
result_80_24 <- as.data.table(coeftable(model_80_24), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_24m|prior_failure_any_24m:election_window', term)
]
result_80_36 <- as.data.table(coeftable(model_80_36), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_36m|prior_failure_any_36m:election_window', term)
]
result_80_60 <- as.data.table(coeftable(model_80_60), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_60m|prior_failure_any_60m:election_window', term)
]
result_80_360 <- as.data.table(coeftable(model_80_360), keep.rownames = 'term')[
  grepl('election_window:prior_failure_any_360m|prior_failure_any_360m:election_window', term)
]

results <- rbindlist(list(
  cbind(data.table(overlap = 'Any positive overlap', months = 12L), result_any_12),
  cbind(data.table(overlap = 'Any positive overlap', months = 24L), result_any_24),
  cbind(data.table(overlap = 'Any positive overlap', months = 36L), result_any_36),
  cbind(data.table(overlap = 'Any positive overlap', months = 60L), result_any_60),
  cbind(data.table(overlap = 'Any positive overlap', months = 360L), result_any_360),
  cbind(data.table(overlap = 'At least 50% overlap', months = 12L), result_50_12),
  cbind(data.table(overlap = 'At least 50% overlap', months = 24L), result_50_24),
  cbind(data.table(overlap = 'At least 50% overlap', months = 36L), result_50_36),
  cbind(data.table(overlap = 'At least 50% overlap', months = 60L), result_50_60),
  cbind(data.table(overlap = 'At least 50% overlap', months = 360L), result_50_360),
  cbind(data.table(overlap = 'At least 80% overlap', months = 12L), result_80_12),
  cbind(data.table(overlap = 'At least 80% overlap', months = 24L), result_80_24),
  cbind(data.table(overlap = 'At least 80% overlap', months = 36L), result_80_36),
  cbind(data.table(overlap = 'At least 80% overlap', months = 60L), result_80_60),
  cbind(data.table(overlap = 'At least 80% overlap', months = 360L), result_80_360)
), fill = TRUE)
setnames(results, c('Estimate', 'Std. Error', 'Pr(>|z|)'), c('estimate', 'std_error', 'p_value'))
results[, `:=`(
  irr = exp(estimate),
  input_observations = nrow(media_sample),
  ppml_observations = c(
    nobs(model_any_12), nobs(model_any_24), nobs(model_any_36), nobs(model_any_60), nobs(model_any_360),
    nobs(model_50_12), nobs(model_50_24), nobs(model_50_36), nobs(model_50_60), nobs(model_50_360),
    nobs(model_80_12), nobs(model_80_24), nobs(model_80_36), nobs(model_80_60), nobs(model_80_360)
  )
)]
setorder(results, overlap, months)
fwrite(results, file.path(results_dir, 'ppml_media_article_count_spatial_sensitivity.csv'))
print(results)
