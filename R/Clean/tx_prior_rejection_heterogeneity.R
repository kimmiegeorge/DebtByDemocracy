# Texas election-history heterogeneity in website text and media coverage

rm(list = ls())

library(data.table)
library(fixest)
library(haven)

project_dir <- path.expand("~/Dropbox/Voting on Bonds")
data_dir <- file.path(project_dir, "Data")
clean_data_dir <- file.path(data_dir, "Clean_Intermediate")
results_dir <- file.path(project_dir, "Results", "TX Prior Rejection Heterogeneity")
table_dir <- file.path(project_dir, "Code", "R", "Clean", "output", "revision_tables")

source(file.path(project_dir, "Code", "R", "Clean", "modify_etable_rounding.R"))

dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)


# -----------------------------------------------------------------------------
# Shared source data
# -----------------------------------------------------------------------------

website_election_history <- fread(file.path(
  clean_data_dir,
  "Websites",
  "Texas",
  "election_level_website_data.csv"
))

media_election_history <- fread(file.path(
  clean_data_dir,
  "TX",
  "News",
  "Election_Level_With_News_WithFailed.csv"
))

website_election_history[, election_date := as.IDate(ElectionDate, "%m/%d/%Y")]
media_election_history[, election_date := as.IDate(ElectionDate, "%m/%d/%Y")]

# Build the history measures from the unrestricted election files. This step
# must precede all media-availability and regression-sample restrictions.
website_failure_dates <- unique(
  website_election_history[failed == 1 & !is.na(seed_issuer) & !is.na(election_date),
                           .(seed_issuer,
                             history_date = election_date,
                             last_failure_date = election_date)]
)
setkey(website_failure_dates, seed_issuer, history_date)

website_election_dates <- unique(
  website_election_history[!is.na(seed_issuer) & !is.na(election_date),
                           .(seed_issuer,
                             history_date = election_date,
                             last_election_date = election_date)]
)
setkey(website_election_dates, seed_issuer, history_date)

media_failure_dates <- unique(
  media_election_history[failed == 1 & !is.na(seed_issuer) & !is.na(election_date),
                         .(seed_issuer,
                           history_date = election_date,
                           last_failure_date = election_date)]
)
setkey(media_failure_dates, seed_issuer, history_date)

media_election_dates <- unique(
  media_election_history[!is.na(seed_issuer) & !is.na(election_date),
                         .(seed_issuer,
                           history_date = election_date,
                           last_election_date = election_date)]
)
setkey(media_election_dates, seed_issuer, history_date)


# -----------------------------------------------------------------------------
# Website city-year panel
# -----------------------------------------------------------------------------

website_city_year <- fread(file.path(
  clean_data_dir,
  "Websites",
  "Texas",
  "time_series_website_data.csv"
))
website_city_year <- website_city_year[!is.na(seed_issuer) & seed_issuer != ""]
setorder(website_city_year, seed_issuer, year)
website_city_year <- unique(website_city_year, by = c("seed_issuer", "year"))
website_city_year[, seed_issuer_key := tolower(seed_issuer)]

# Rebuild the FIPS and county-control merges used in the current Texas table.
county_controls_source <- as.data.table(read_dta(file.path(
  data_dir,
  "BEA",
  "countydemos_1999_2026.dta"
)))
county_controls_source[, fips := fifelse(
  is.na(fips),
  NA_character_,
  sprintf("%05d", as.integer(fips))
)]

tx_county_fips_map <- unique(
  county_controls_source[grepl(", TX$", geoname),
                         .(County = sub(", TX$", "", geoname),
                           county_fips = fips)]
)
tx_county_fips_map <- tx_county_fips_map[
  !is.na(county_fips),
  .(county_fips = first(county_fips)),
  by = County
]

website_election_history[, fips := fifelse(
  is.na(fips),
  NA_character_,
  sprintf("%05d", as.integer(fips))
)]
website_election_history <- tx_county_fips_map[
  website_election_history,
  on = .(County)
]
website_election_history[is.na(fips), fips := county_fips]
website_election_history[, county_fips := NULL]

website_fips_map <- website_election_history[
  !is.na(fips),
  .(fips = first(fips)),
  by = .(seed_issuer_key = tolower(seed_issuer))
]

media_city_month_raw <- fread(file.path(
  clean_data_dir,
  "TX",
  "City_Month_Elections_News_WithFailed.csv"
))
media_fips_map <- media_city_month_raw[
  !is.na(fips),
  .(fips = sprintf("%05d", as.integer(first(fips)))),
  by = .(seed_issuer_key = tolower(seed_issuer))
]

fips_map <- rbindlist(
  list(website_fips_map, media_fips_map),
  use.names = TRUE,
  fill = TRUE
)
fips_map <- fips_map[!is.na(seed_issuer_key) & seed_issuer_key != ""]
fips_map <- fips_map[, .(fips = first(fips)), by = seed_issuer_key]

county_controls <- county_controls_source[, .(
  fips,
  year,
  ln_county_gdp_prior = log(gdp),
  ln_county_pop_prior = log(pop),
  ln_county_pers_inc_prior = log(pers_inc)
)]

website_city_year <- fips_map[website_city_year, on = .(seed_issuer_key)]
website_city_year <- county_controls[website_city_year, on = .(fips, year)]

issue_level <- as.data.table(read_dta(
  file.path(
    data_dir,
    "Mergent",
    "Clean",
    "260716_city_cusiplevel_statereq_purpose_yieldspread.dta"
  ),
  col_select = c("state", "seed_issuer", "seed_issuer_id", "year", "month",
                 "issue_id", "go_unlim", "go_lim")
))

actual_issue_city_year <- unique(
  issue_level[state == "TX" & !is.na(seed_issuer) & !is.na(year),
              .(seed_issuer_key = tolower(seed_issuer),
                year = as.integer(year),
                issue_id,
                go_unlim,
                go_lim)]
)
actual_issue_city_year <- actual_issue_city_year[, .(
  num_issues_bond_data = uniqueN(issue_id),
  num_issues_go = uniqueN(issue_id[go_unlim == 1 | go_lim == 1])
), by = .(seed_issuer_key, year)]

website_city_year <- actual_issue_city_year[
  website_city_year,
  on = .(seed_issuer_key, year)
]
website_city_year[is.na(num_issues_bond_data), num_issues_bond_data := 0L]
website_city_year[is.na(num_issues_go), num_issues_go := 0L]
website_city_year[, issuance_window := as.integer(num_issues_bond_data > 0)]

setorder(website_city_year, seed_issuer, year)
website_city_year[, total_words := bond_count]
website_city_year[, total_words_lag1 := shift(total_words), by = seed_issuer]
website_city_year[, delta_bond_debt_count1 := total_words - total_words_lag1]
website_city_year[, positive_delta_bond_debt1 := as.integer(delta_bond_debt_count1 > 0)]
website_city_year[, delta_asinh_bond_count1 :=
                    asinh(total_words) - asinh(total_words_lag1)]

# Status is measured at the start of each year. A failure during the current
# election year therefore cannot determine the current year's moderator.
website_city_year[, period_start := as.IDate(sprintf("%d-01-01", year))]
website_city_year[, failure_lookup_date := period_start - 1L]
website_city_year[, election_lookup_date := period_start - 1L]
website_city_year[, five_year_start := as.IDate(sprintf("%d-01-01", year - 5L))]

website_city_year <- website_failure_dates[
  website_city_year,
  on = .(seed_issuer, history_date = failure_lookup_date),
  roll = Inf
]
website_city_year <- website_election_dates[
  website_city_year,
  on = .(seed_issuer, history_date = election_lookup_date),
  roll = Inf
]
website_city_year[, prior_rejection := as.integer(!is.na(last_failure_date))]
website_city_year[, prior_rejection_5yr := as.integer(
  !is.na(last_failure_date) & last_failure_date >= five_year_start
)]
website_city_year[, prior_election := as.integer(!is.na(last_election_date))]
website_city_year[, city_fe := seed_issuer]

stopifnot(!anyNA(website_city_year$prior_rejection))
stopifnot(all(
  website_city_year[prior_rejection == 1, last_failure_date < period_start]
))

website_delta_cutoffs <- quantile(
  website_city_year$delta_bond_debt_count1,
  probs = c(0.01, 0.99),
  na.rm = TRUE
)
website_city_year[, delta_bond_debt_count1_win := pmax(
  website_delta_cutoffs[1],
  pmin(delta_bond_debt_count1, website_delta_cutoffs[2])
)]


# -----------------------------------------------------------------------------
# Media city-month panel
# -----------------------------------------------------------------------------

media_city_month <- copy(media_city_month_raw)
setorder(media_city_month, seed_issuer_id, year, month)
media_city_month[, ym_id := .GRP, by = .(year, month)]

issue_months <- unique(
  issue_level[!is.na(seed_issuer_id) & !is.na(year) & !is.na(month),
              .(seed_issuer_id,
                year = as.integer(year),
                month = as.integer(month))]
)
issue_months[, bond_issuance := 1L]
media_city_month <- issue_months[
  media_city_month,
  on = .(seed_issuer_id, year, month)
]
setorder(media_city_month, seed_issuer_id, year, month)

media_city_month[, next_month_bond_issuance := shift(
  bond_issuance,
  type = "lead",
  n = 1L
), by = seed_issuer_id]
media_city_month[, next_next_month_bond_issuance := shift(
  bond_issuance,
  type = "lead",
  n = 2L
), by = seed_issuer_id]
media_city_month[, next_next_next_month_bond_issuance := shift(
  bond_issuance,
  type = "lead",
  n = 3L
), by = seed_issuer_id]
media_city_month[, issuance_window := as.integer(
  bond_issuance == 1 |
    next_month_bond_issuance == 1 |
    next_next_month_bond_issuance == 1 |
    next_next_next_month_bond_issuance == 1
)]
media_city_month[is.na(issuance_window), issuance_window := 0L]

media_city_month[, next_next_month_election := shift(
  has_bond_election,
  type = "lead",
  n = 2L
), by = seed_issuer_id]
media_city_month[, next_next_next_month_election := shift(
  has_bond_election,
  type = "lead",
  n = 3L
), by = seed_issuer_id]
media_city_month[, election_window := as.integer(
  has_bond_election == 1 |
    has_election_next_month == 1 |
    next_next_month_election == 1 |
    next_next_next_month_election == 1
)]
media_city_month[is.na(election_window), election_window := 0L]

media_city_month[, covered := as.integer(rp_article_count > 0)]
media_city_month[, log_article_count := log1p(rp_article_count)]

# Status is measured at the start of each month. This prevents the result of an
# election held later in the month from entering that month's history measure.
media_city_month[, period_start := as.IDate(sprintf(
  "%d-%02d-01",
  year,
  month
))]
media_city_month[, failure_lookup_date := period_start - 1L]
media_city_month[, election_lookup_date := period_start - 1L]
media_city_month[, five_year_start := as.IDate(sprintf(
  "%d-%02d-01",
  year - 5L,
  month
))]

media_city_month <- media_failure_dates[
  media_city_month,
  on = .(seed_issuer, history_date = failure_lookup_date),
  roll = Inf
]
media_city_month <- media_election_dates[
  media_city_month,
  on = .(seed_issuer, history_date = election_lookup_date),
  roll = Inf
]
media_city_month[, prior_rejection := as.integer(!is.na(last_failure_date))]
media_city_month[, prior_rejection_5yr := as.integer(
  !is.na(last_failure_date) & last_failure_date >= five_year_start
)]
media_city_month[, prior_election := as.integer(!is.na(last_election_date))]
media_city_month[, city_fe := seed_issuer_id]

stopifnot(!anyNA(media_city_month$prior_rejection))
stopifnot(all(
  media_city_month[prior_rejection == 1, last_failure_date < period_start]
))

covered_media_cities <- unique(
  media_election_history[unique_sources_12m_prior > 0, seed_issuer]
)
media_city_month <- media_city_month[
  seed_issuer %in% covered_media_cities &
    !is.na(ln_county_gdp_prior) &
    !is.na(ln_county_employment_prior)
]


# -----------------------------------------------------------------------------
# Regressions: all specifications are written explicitly
# -----------------------------------------------------------------------------

website_binary_unadjusted <- feols(
  positive_delta_bond_debt1 ~ election * prior_rejection |
    city_fe + year,
  data = website_city_year[!is.na(fips)],
  cluster = ~fips
)

website_binary_adjusted <- feols(
  positive_delta_bond_debt1 ~ election * prior_rejection +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips)],
  cluster = ~fips
)

website_binary_prior_election_sample <- feols(
  positive_delta_bond_debt1 ~ election * prior_rejection +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips) & prior_election == 1],
  cluster = ~fips
)

website_binary_recent_rejection <- feols(
  positive_delta_bond_debt1 ~ election * prior_rejection_5yr +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips)],
  cluster = ~fips
)

website_continuous_adjusted <- feols(
  delta_bond_debt_count1_win ~ election * prior_rejection +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips)],
  cluster = ~fips
)

website_continuous_prior_election_sample <- feols(
  delta_bond_debt_count1_win ~ election * prior_rejection +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips) & prior_election == 1],
  cluster = ~fips
)

website_continuous_recent_rejection <- feols(
  delta_bond_debt_count1_win ~ election * prior_rejection_5yr +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips)],
  cluster = ~fips
)

website_asinh_adjusted <- feols(
  delta_asinh_bond_count1 ~ election * prior_rejection +
    issuance_window + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | city_fe + year,
  data = website_city_year[!is.na(fips)],
  cluster = ~fips
)

media_binary_unadjusted <- feols(
  covered ~ election_window * prior_rejection |
    city_fe + ym_id,
  data = media_city_month,
  cluster = ~fips
)

media_binary_adjusted <- feols(
  covered ~ election_window * prior_rejection + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    city_fe + ym_id,
  data = media_city_month,
  cluster = ~fips
)

media_binary_prior_election_sample <- feols(
  covered ~ election_window * prior_rejection + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    city_fe + ym_id,
  data = media_city_month[prior_election == 1],
  cluster = ~fips
)

media_binary_recent_rejection <- feols(
  covered ~ election_window * prior_rejection_5yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    city_fe + ym_id,
  data = media_city_month,
  cluster = ~fips
)

media_continuous_adjusted <- feols(
  log_article_count ~ election_window * prior_rejection + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    city_fe + ym_id,
  data = media_city_month,
  cluster = ~fips
)


# -----------------------------------------------------------------------------
# Machine-readable estimates and sample diagnostics
# -----------------------------------------------------------------------------

extract_coefficients <- function(model, model_name, outcome_name) {
  estimates <- as.data.table(coeftable(model), keep.rownames = "term")
  setnames(
    estimates,
    c("Estimate", "Std. Error", "t value", "Pr(>|t|)"),
    c("estimate", "std_error", "t_value", "p_value")
  )
  estimates[, `:=`(
    model = model_name,
    outcome = outcome_name,
    n = nobs(model)
  )]
  setcolorder(
    estimates,
    c("model", "outcome", "term", "estimate", "std_error", "t_value",
      "p_value", "n")
  )
  estimates
}

coefficient_results <- rbindlist(list(
  extract_coefficients(
    website_binary_unadjusted,
    "website_binary_unadjusted",
    "Increase in bond text"
  ),
  extract_coefficients(
    website_binary_adjusted,
    "website_binary_adjusted",
    "Increase in bond text"
  ),
  extract_coefficients(
    website_binary_prior_election_sample,
    "website_binary_prior_election_sample",
    "Increase in bond text"
  ),
  extract_coefficients(
    website_binary_recent_rejection,
    "website_binary_recent_rejection",
    "Increase in bond text"
  ),
  extract_coefficients(
    website_continuous_adjusted,
    "website_continuous_adjusted",
    "Winsorized change in bond text"
  ),
  extract_coefficients(
    website_continuous_prior_election_sample,
    "website_continuous_prior_election_sample",
    "Winsorized change in bond text"
  ),
  extract_coefficients(
    website_continuous_recent_rejection,
    "website_continuous_recent_rejection",
    "Winsorized change in bond text"
  ),
  extract_coefficients(
    website_asinh_adjusted,
    "website_asinh_adjusted",
    "Change in asinh(bond text)"
  ),
  extract_coefficients(
    media_binary_unadjusted,
    "media_binary_unadjusted",
    "Any bond coverage"
  ),
  extract_coefficients(
    media_binary_adjusted,
    "media_binary_adjusted",
    "Any bond coverage"
  ),
  extract_coefficients(
    media_binary_prior_election_sample,
    "media_binary_prior_election_sample",
    "Any bond coverage"
  ),
  extract_coefficients(
    media_binary_recent_rejection,
    "media_binary_recent_rejection",
    "Any bond coverage"
  ),
  extract_coefficients(
    media_continuous_adjusted,
    "media_continuous_adjusted",
    "Log(1 + article count)"
  )
))

extract_election_effects <- function(model,
                                     model_name,
                                     outcome_name,
                                     election_term,
                                     interaction_term) {
  model_coef <- coef(model)
  model_vcov <- vcov(model)
  model_df <- degrees_freedom(model, type = "t")

  no_prior_estimate <- model_coef[election_term]
  no_prior_se <- sqrt(model_vcov[election_term, election_term])
  no_prior_t <- no_prior_estimate / no_prior_se
  no_prior_p <- 2 * pt(abs(no_prior_t), df = model_df, lower.tail = FALSE)

  interaction_estimate <- model_coef[interaction_term]
  interaction_se <- sqrt(model_vcov[interaction_term, interaction_term])
  interaction_t <- interaction_estimate / interaction_se
  interaction_p <- 2 * pt(abs(interaction_t), df = model_df, lower.tail = FALSE)

  prior_estimate <- no_prior_estimate + interaction_estimate
  prior_variance <- model_vcov[election_term, election_term] +
    model_vcov[interaction_term, interaction_term] +
    2 * model_vcov[election_term, interaction_term]
  prior_se <- sqrt(prior_variance)
  prior_t <- prior_estimate / prior_se
  prior_p <- 2 * pt(abs(prior_t), df = model_df, lower.tail = FALSE)

  data.table(
    model = model_name,
    outcome = outcome_name,
    contrast = c(
      "Election effect: no prior rejection",
      "Election effect: prior rejection",
      "Difference: prior minus no prior"
    ),
    estimate = c(no_prior_estimate, prior_estimate, interaction_estimate),
    std_error = c(no_prior_se, prior_se, interaction_se),
    t_value = c(no_prior_t, prior_t, interaction_t),
    p_value = c(no_prior_p, prior_p, interaction_p),
    n = nobs(model)
  )
}

marginal_effect_results <- rbindlist(list(
  extract_election_effects(
    website_binary_unadjusted,
    "website_binary_unadjusted",
    "Increase in bond text",
    "election",
    "election:prior_rejection"
  ),
  extract_election_effects(
    website_binary_adjusted,
    "website_binary_adjusted",
    "Increase in bond text",
    "election",
    "election:prior_rejection"
  ),
  extract_election_effects(
    website_binary_prior_election_sample,
    "website_binary_prior_election_sample",
    "Increase in bond text",
    "election",
    "election:prior_rejection"
  ),
  extract_election_effects(
    website_binary_recent_rejection,
    "website_binary_recent_rejection",
    "Increase in bond text",
    "election",
    "election:prior_rejection_5yr"
  ),
  extract_election_effects(
    website_continuous_adjusted,
    "website_continuous_adjusted",
    "Winsorized change in bond text",
    "election",
    "election:prior_rejection"
  ),
  extract_election_effects(
    website_continuous_prior_election_sample,
    "website_continuous_prior_election_sample",
    "Winsorized change in bond text",
    "election",
    "election:prior_rejection"
  ),
  extract_election_effects(
    website_continuous_recent_rejection,
    "website_continuous_recent_rejection",
    "Winsorized change in bond text",
    "election",
    "election:prior_rejection_5yr"
  ),
  extract_election_effects(
    website_asinh_adjusted,
    "website_asinh_adjusted",
    "Change in asinh(bond text)",
    "election",
    "election:prior_rejection"
  ),
  extract_election_effects(
    media_binary_unadjusted,
    "media_binary_unadjusted",
    "Any bond coverage",
    "election_window",
    "election_window:prior_rejection"
  ),
  extract_election_effects(
    media_binary_adjusted,
    "media_binary_adjusted",
    "Any bond coverage",
    "election_window",
    "election_window:prior_rejection"
  ),
  extract_election_effects(
    media_binary_prior_election_sample,
    "media_binary_prior_election_sample",
    "Any bond coverage",
    "election_window",
    "election_window:prior_rejection"
  ),
  extract_election_effects(
    media_binary_recent_rejection,
    "media_binary_recent_rejection",
    "Any bond coverage",
    "election_window",
    "election_window:prior_rejection_5yr"
  ),
  extract_election_effects(
    media_continuous_adjusted,
    "media_continuous_adjusted",
    "Log(1 + article count)",
    "election_window",
    "election_window:prior_rejection"
  )
))

website_estimation_sample <- website_city_year[obs(website_binary_adjusted)]
media_estimation_sample <- media_city_month[obs(media_binary_adjusted)]

website_sample_counts <- website_estimation_sample[, .(
  panel = "Website city-year",
  observations = .N,
  cities = uniqueN(seed_issuer),
  periods_with_prior_rejection = sum(prior_rejection),
  election_periods = sum(election == 1, na.rm = TRUE),
  election_periods_with_prior_rejection = sum(
    election == 1 & prior_rejection == 1,
    na.rm = TRUE
  ),
  cities_with_interacted_election = uniqueN(
    seed_issuer[election == 1 & prior_rejection == 1]
  )
)]

media_sample_counts <- media_estimation_sample[, .(
  panel = "Media city-month",
  observations = .N,
  cities = uniqueN(seed_issuer),
  periods_with_prior_rejection = sum(prior_rejection),
  election_periods = sum(election_window == 1, na.rm = TRUE),
  election_periods_with_prior_rejection = sum(
    election_window == 1 & prior_rejection == 1,
    na.rm = TRUE
  ),
  cities_with_interacted_election = uniqueN(
    seed_issuer[election_window == 1 & prior_rejection == 1]
  )
)]

sample_counts <- rbindlist(list(website_sample_counts, media_sample_counts))

fwrite(
  coefficient_results,
  file.path(results_dir, "tx_prior_rejection_coefficients.csv")
)
fwrite(
  marginal_effect_results,
  file.path(results_dir, "tx_prior_rejection_marginal_effects.csv")
)
fwrite(
  sample_counts,
  file.path(results_dir, "tx_prior_rejection_sample_counts.csv")
)


# -----------------------------------------------------------------------------
# Main exploratory LaTeX table
# -----------------------------------------------------------------------------

table_call <- etable(
  website_binary_unadjusted,
  website_binary_adjusted,
  media_binary_unadjusted,
  media_binary_adjusted,
  coefstat = "tstat",
  style.tex = style.tex(
    main = "aer",
    fixef.suffix = " FE",
    yesNo = c("Yes", "No")
  ),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "Increase in Bond Text",
    covered = "Bond Coverage",
    election = "Election Year",
    election_window = "Election [-3, 0]",
    prior_rejection = "Prior Rejection",
    "election:prior_rejection" = "Election Year $\\times$ Prior Rejection",
    "election_window:prior_rejection" = "Election [-3, 0] $\\times$ Prior Rejection",
    issuance_window = "Bond Issuance Window",
    ln_county_gdp_prior = "County ln(GDP)",
    ln_county_pop_prior = "County ln(Pop)",
    ln_county_pers_inc_prior = "County ln(Pers. Inc)",
    city_fe = "City",
    year = "Year",
    ym_id = "Year-Month"
  ),
  placement = "H",
  replace = TRUE
)

table_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
table_output <- format_table(
  table_output,
  cluster_level = "County",
  drop_covariance = TRUE
)
table_output <- sub("[[:space:]]+$", "", table_output)

writeLines(
  table_output,
  file.path(table_dir, "tx_prior_rejection_heterogeneity.tex")
)

message("Wrote Texas prior-rejection heterogeneity results to ", results_dir)
