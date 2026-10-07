# Texas county-level non-city bond-failure screening test
#
# This is a feasibility screen, not an electorate-overlap design.  A city is
# considered exposed when a non-city issuer in the city's recorded county had
# a defeated proposition in either the prior 12 or prior 36 complete calendar
# months. Same-month failures are excluded so the failure predates the city
# election outcome.

library(data.table)
library(fixest)

project_dir <- normalizePath(file.path(getwd()), mustWork = TRUE)
data_dir <- file.path(project_dir, "Data")
results_dir <- file.path(project_dir, "Results", "TX County Failure Screen")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

raw_path <- file.path(data_dir, "TX", "20240510_TX_local_election.csv")
city_month_path <- file.path(
  data_dir, "Clean_Intermediate", "TX", "City_Month_Elections_News_WithFailed.csv"
)
website_path <- file.path(
  data_dir, "Clean_Intermediate", "Websites", "Texas", "time_series_website_data.csv"
)

raw <- fread(raw_path)
raw[, election_date := as.IDate(ElectionDate, format = "%m/%d/%Y")]
raw <- raw[
  !is.na(election_date) &
    election_date >= as.IDate("1995-01-01") &
    election_date <= as.IDate("2024-12-31")
]
raw[, county := tolower(trimws(County))]

# Proposition-level failures are retained: a multi-proposition ballot counts as
# exposed if any proposition was defeated.
noncity_failures <- raw[
  GovernmentType != "CITY" & Result == "Defeated" & !is.na(county) & county != "",
  .(failed_propositions = .N),
  by = .(county, failure_month = as.IDate(format(election_date, "%Y-%m-01")))
]

city_month <- fread(city_month_path)
city_month[, month_date := as.IDate(sprintf("%04d-%02d-01", year, month))]
city_month[, seed_key := tolower(trimws(seed_issuer))]

# The city-month file contains a stable county FIPS.  Its nonmissing geoname
# values supply a city-to-county lookup for all months, including early months
# in which the control variables (and thus geoname) are absent.
city_county <- city_month[
  !is.na(geoname) & grepl(", TX$", geoname),
  .(county = tolower(trimws(sub(", TX$", "", geoname)))),
  by = seed_key
][, .(county = first(county)), by = seed_key]
city_month <- city_county[city_month, on = .(seed_key)]

if (city_month[, any(is.na(county) | county == "")]) {
  stop("Some city-month observations could not be assigned to a county.")
}

# Construct county-month exposure.  The sum runs from t-12 through t-1, not
# the current month, so exposure always occurs before the outcome month.
county_month <- unique(city_month[, .(county, month_date, year_month_id)])
county_month <- merge(
  county_month,
  noncity_failures,
  by.x = c("county", "month_date"),
  by.y = c("county", "failure_month"),
  all.x = TRUE
)
county_month[is.na(failed_propositions), failed_propositions := 0L]
setorder(county_month, county, month_date)
county_month[, failed_propositions_prior_12m :=
  Reduce(`+`, lapply(1:12, function(k) shift(failed_propositions, k, fill = 0L))),
  by = county
]
county_month[, prior_noncity_failure_12m :=
  as.integer(failed_propositions_prior_12m > 0L)
]
county_month[, failed_propositions_prior_36m :=
  Reduce(`+`, lapply(1:36, function(k) shift(failed_propositions, k, fill = 0L))),
  by = county
]
county_month[, prior_noncity_failure_36m :=
  as.integer(failed_propositions_prior_36m > 0L)
]

city_month <- merge(
  city_month,
  county_month[, .(
    county, month_date, failed_propositions_prior_12m,
    prior_noncity_failure_12m, failed_propositions_prior_36m,
    prior_noncity_failure_36m
  )],
  by = c("county", "month_date"),
  all.x = TRUE
)
if (city_month[, any(is.na(prior_noncity_failure_12m))]) {
  stop("County exposure did not merge to every city-month.")
}

# (1) Does a prior non-city failure predict a city bond election in that month?
monthly_sample <- city_month[
  !is.na(has_bond_election) & !is.na(fips) &
    month_date >= as.IDate("1995-01-01") & month_date <= as.IDate("2024-12-01")
]
election_raw <- monthly_sample[, .(
  n_city_months = .N,
  city_election_rate = mean(has_bond_election),
  city_elections = sum(has_bond_election)
), by = prior_noncity_failure_12m]
election_fe <- feols(
  has_bond_election ~ prior_noncity_failure_12m | seed_key + year_month_id,
  data = monthly_sample,
  cluster = ~fips
)
election_raw_3y <- monthly_sample[, .(
  n_city_months = .N,
  city_election_rate = mean(has_bond_election),
  city_elections = sum(has_bond_election)
), by = prior_noncity_failure_36m]
election_fe_3y <- feols(
  has_bond_election ~ prior_noncity_failure_36m | seed_key + year_month_id,
  data = monthly_sample,
  cluster = ~fips
)

# (2) Among city-election years, is the one-year increase in website bond text
# more common after a county-level non-city failure?  Exposure is evaluated in
# each actual city-election month and then collapsed to the city-year.
city_election_year <- city_month[
  has_bond_election == 1L,
  .(
    prior_noncity_failure_12m = max(prior_noncity_failure_12m),
    failed_propositions_prior_12m = max(failed_propositions_prior_12m),
    prior_noncity_failure_36m = max(prior_noncity_failure_36m),
    failed_propositions_prior_36m = max(failed_propositions_prior_36m),
    fips = first(fips)
  ),
  by = .(seed_key, year)
]

website <- fread(website_path)
website[, seed_key := tolower(trimws(seed_issuer))]
website <- website[!is.na(seed_key) & seed_key != ""]
website <- unique(website, by = c("seed_key", "year"))
website[, bond_count := as.numeric(bond_count)]
setorder(website, seed_key, year)
website[, prior_bond_count := shift(bond_count), by = seed_key]
website[, disclosure_increase := as.integer(bond_count > prior_bond_count)]

website_election_sample <- merge(
  city_election_year,
  website[, .(seed_key, year, disclosure_increase, bond_count, prior_bond_count)],
  by = c("seed_key", "year"),
  all = FALSE
)
website_election_sample <- website_election_sample[
  !is.na(disclosure_increase) & !is.na(fips)
]
disclosure_raw <- website_election_sample[, .(
  city_election_years = .N,
  disclosure_increase_rate = mean(disclosure_increase)
), by = prior_noncity_failure_12m]
disclosure_fe <- feols(
  disclosure_increase ~ prior_noncity_failure_12m | seed_key + year,
  data = website_election_sample,
  cluster = ~fips
)
disclosure_raw_3y <- website_election_sample[, .(
  city_election_years = .N,
  disclosure_increase_rate = mean(disclosure_increase)
), by = prior_noncity_failure_36m]
disclosure_fe_3y <- feols(
  disclosure_increase ~ prior_noncity_failure_36m | seed_key + year,
  data = website_election_sample,
  cluster = ~fips
)

tidy_term <- function(model, outcome, term_name) {
  ct <- as.data.table(coeftable(model), keep.rownames = "term")
  setnames(ct, c("Estimate", "Std. Error", "Pr(>|t|)"), c("estimate", "std_error", "p_value"))
  row <- ct[term == term_name]
  data.table(
    outcome = outcome,
    fixed_effect_association = row$estimate,
    std_error = row$std_error,
    p_value = row$p_value,
    n = nobs(model)
  )
}

summary_results <- rbindlist(list(
  tidy_term(election_fe, "City bond election in month", "prior_noncity_failure_12m"),
  tidy_term(disclosure_fe, "Disclosure increase, conditional on city election", "prior_noncity_failure_12m")
))
summary_results_3y <- rbindlist(list(
  tidy_term(election_fe_3y, "City bond election in month", "prior_noncity_failure_36m"),
  tidy_term(disclosure_fe_3y, "Disclosure increase, conditional on city election", "prior_noncity_failure_36m")
))
setnames(summary_results_3y, "fixed_effect_association", "fixed_effect_association_36m")
setnames(summary_results_3y, "std_error", "std_error_36m")
setnames(summary_results_3y, "p_value", "p_value_36m")
setnames(summary_results_3y, "n", "n_36m")
fwrite(summary_results, file.path(results_dir, "county_failure_screen_models.csv"))
fwrite(election_raw, file.path(results_dir, "county_failure_screen_election_rates.csv"))
fwrite(disclosure_raw, file.path(results_dir, "county_failure_screen_disclosure_rates.csv"))
fwrite(summary_results_3y, file.path(results_dir, "county_failure_screen_36m_models.csv"))
fwrite(election_raw_3y, file.path(results_dir, "county_failure_screen_36m_election_rates.csv"))
fwrite(disclosure_raw_3y, file.path(results_dir, "county_failure_screen_36m_disclosure_rates.csv"))

format_rate <- function(dt, group, exposure_col) {
  row <- dt[get(exposure_col) == group]
  if (nrow(row) == 0L) return("no observations")
  rate_col <- names(row)[grepl("rate$", names(row))][1]
  sprintf("%.3f", row[[rate_col]][1])
}

readme <- c(
  "# Texas county-level non-city failure screen",
  "",
  "A city-month is exposed if a non-city issuer in the city's recorded county had at least one defeated proposition in the preceding 12 complete calendar months. This is a county co-location proxy, not an exact shared-electorate measure.",
  "",
  "## City election incidence",
  "",
  sprintf("- Unexposed city-month election rate: %s.", format_rate(election_raw, 0L, "prior_noncity_failure_12m")),
  sprintf("- Exposed city-month election rate: %s.", format_rate(election_raw, 1L, "prior_noncity_failure_12m")),
  sprintf("- City and year-month fixed-effect association: %.4f (SE %.4f; p = %.4f; N = %s).",
          summary_results[1]$fixed_effect_association,
          summary_results[1]$std_error,
          summary_results[1]$p_value,
          format(summary_results[1]$n, big.mark = ",")),
  "",
  "## Disclosure conditional on a city election",
  "",
  sprintf("- Unexposed election-year disclosure-increase rate: %s.", format_rate(disclosure_raw, 0L, "prior_noncity_failure_12m")),
  sprintf("- Exposed election-year disclosure-increase rate: %s.", format_rate(disclosure_raw, 1L, "prior_noncity_failure_12m")),
  sprintf("- City and year fixed-effect association: %.4f (SE %.4f; p = %.4f; N = %s).",
          summary_results[2]$fixed_effect_association,
          summary_results[2]$std_error,
          summary_results[2]$p_value,
          format(summary_results[2]$n, big.mark = ",")),
  "",
  "## Three-year exposure window",
  "",
  "This definition uses a failure in the preceding 36 complete calendar months (t-36 through t-1).",
  sprintf("- Unexposed city-month election rate: %s; exposed rate: %s.",
          format_rate(election_raw_3y, 0L, "prior_noncity_failure_36m"), format_rate(election_raw_3y, 1L, "prior_noncity_failure_36m")),
  sprintf("- City and year-month fixed-effect association: %.4f (SE %.4f; p = %.4f; N = %s).",
          summary_results_3y[1]$fixed_effect_association_36m,
          summary_results_3y[1]$std_error_36m,
          summary_results_3y[1]$p_value_36m,
          format(summary_results_3y[1]$n_36m, big.mark = ",")),
  sprintf("- Conditional disclosure-increase rate: %s unexposed; %s exposed.",
          format_rate(disclosure_raw_3y, 0L, "prior_noncity_failure_36m"), format_rate(disclosure_raw_3y, 1L, "prior_noncity_failure_36m")),
  sprintf("- City and year fixed-effect association: %.4f (SE %.4f; p = %.4f; N = %s).",
          summary_results_3y[2]$fixed_effect_association_36m,
          summary_results_3y[2]$std_error_36m,
          summary_results_3y[2]$p_value_36m,
          format(summary_results_3y[2]$n_36m, big.mark = ",")),
  "",
  "The exposure is intentionally lagged and the second analysis is restricted to actual city-election years. These associations do not establish that the same voters participated in the non-city and city elections; an ISD/city spatial crosswalk is required for that stronger test."
)
writeLines(readme, file.path(results_dir, "README.md"))

print(summary_results)
print(summary_results_3y)
print(election_raw)
print(disclosure_raw)
print(election_raw_3y)
print(disclosure_raw_3y)
