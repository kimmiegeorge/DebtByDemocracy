# Texas website-disclosure response around bond elections by county partisanship
#
# This script reproduces the city-year website-disclosure design in
# R/Clean/election_outcomes.R and adds election-year interactions with:
#   1. the most recent presidential Republican two-party share strictly before
#      each city-year; and
#   2. a fixed county partisan measure (the county mean over 2000-2016).
#
# Standard errors are clustered by county, and all models include city and year
# fixed effects. The dependent variable equals one when the number of website
# URLs containing "bond" rises relative to the prior year.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(haven)
})

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) == 0L) {
  stop("Run this file with Rscript so the project directory can be resolved.")
}
script_path <- normalizePath(sub("^--file=", "", script_arg[1]))
project_dir <- normalizePath(file.path(dirname(script_path), "..", ".."))

data_dir <- file.path(project_dir, "Data")
results_dir <- file.path(project_dir, "Results", "TX Republican Vote Share")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

output_date <- "260917"
analysis_data_path <- file.path(
  data_dir,
  "TX",
  "Republican Vote Share",
  paste0("tx_website_disclosure_with_republican_share_", output_date, ".csv")
)
coefficient_path <- file.path(
  results_dir,
  paste0("tx_website_disclosure_republican_heterogeneity_models_", output_date, ".csv")
)
marginal_effect_path <- file.path(
  results_dir,
  paste0("tx_website_disclosure_republican_heterogeneity_effects_", output_date, ".csv")
)
summary_path <- file.path(
  results_dir,
  paste0("tx_website_disclosure_republican_heterogeneity_summary_", output_date, ".md")
)

first_nonmissing <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(NA)
  x[1]
}

format_fips <- function(x) {
  fifelse(is.na(x), NA_character_, sprintf("%05d", as.integer(x)))
}

normalize_county <- function(x) {
  x <- toupper(x)
  x <- sub(", TX$", "", x)
  x <- sub(" COUNTY$", "", x)
  gsub("[^A-Z0-9]", "", x)
}

tidy_fixest <- function(model, model_name, outcome_name) {
  ct <- as.data.table(coeftable(model), keep.rownames = "term")
  setnames(ct, c("Estimate", "Std. Error", "t value", "Pr(>|t|)"),
           c("estimate", "std_error", "t_stat", "p_value"))
  ct[, `:=`(
    model = model_name,
    outcome = outcome_name,
    n = nobs(model),
    adjusted_r2 = fitstat(model, "ar2")[[1]]
  )]
  setcolorder(ct, c(
    "model", "outcome", "term", "estimate", "std_error", "t_stat",
    "p_value", "n", "adjusted_r2"
  ))
  ct[]
}

linear_combination <- function(model, base_term, interaction_term, moderator,
                               label, model_name, outcome_name) {
  beta <- coef(model)
  variance <- vcov(model)
  estimate <- beta[[base_term]] + moderator * beta[[interaction_term]]
  std_error <- sqrt(
    variance[base_term, base_term] +
      moderator^2 * variance[interaction_term, interaction_term] +
      2 * moderator * variance[base_term, interaction_term]
  )
  t_stat <- estimate / std_error
  degrees_freedom <- degrees_freedom(model, "t")
  p_value <- 2 * pt(abs(t_stat), df = degrees_freedom, lower.tail = FALSE)
  data.table(
    model = model_name,
    outcome = outcome_name,
    moderator_value = moderator,
    moderator_label = label,
    election_effect = estimate,
    std_error = std_error,
    t_stat = t_stat,
    p_value = p_value
  )
}

# -----------------------------------------------------------------------------
# Rebuild the original Texas city-year website panel.
# -----------------------------------------------------------------------------

website_panel <- fread(file.path(
  data_dir, "Clean_Intermediate", "Websites", "Texas",
  "time_series_website_data.csv"
))
website_panel <- website_panel[!is.na(seed_issuer) & seed_issuer != ""]
website_panel[, year := as.integer(year)]
website_panel[, seed_issuer_key := tolower(seed_issuer)]
setorder(website_panel, seed_issuer_key, year)
website_panel <- unique(website_panel, by = c("seed_issuer_key", "year"))

website_elections <- fread(file.path(
  data_dir, "Clean_Intermediate", "Websites", "Texas",
  "election_level_website_data.csv"
))
county_controls_raw <- fread(file.path(
  data_dir, "BEA", "countydemos_1999_2026.csv"
))
tx_county_fips_map <- unique(county_controls_raw[
  grepl(", TX$", geoname),
  .(County = sub(", TX$", "", geoname), fips_from_county = format_fips(fips))
])
tx_county_fips_map <- tx_county_fips_map[, .(
  fips_from_county = first_nonmissing(fips_from_county)
), by = County]
website_elections[, fips := format_fips(fips)]
website_elections <- tx_county_fips_map[website_elections, on = "County"]
website_elections[is.na(fips), fips := fips_from_county]
website_elections[, fips_from_county := NULL]
website_fips <- website_elections[!is.na(fips), .(
  fips = first_nonmissing(fips)
), by = .(seed_issuer_key = tolower(seed_issuer))]

media_panel <- fread(file.path(
  data_dir, "Clean_Intermediate", "TX",
  "City_Month_Elections_News_WithFailed.csv"
))
media_fips <- media_panel[!is.na(fips), .(
  fips = first_nonmissing(fips)
), by = .(seed_issuer_key = tolower(seed_issuer))]

fips_map <- rbindlist(list(website_fips, media_fips), use.names = TRUE)
fips_map <- fips_map[
  !is.na(seed_issuer_key) & seed_issuer_key != "",
  .(fips = first_nonmissing(fips)),
  by = seed_issuer_key
]
fips_map[, fips := format_fips(fips)]
website_panel <- fips_map[website_panel, on = "seed_issuer_key"]

county_controls <- copy(county_controls_raw)
county_controls[, fips := format_fips(fips)]
county_controls[, `:=`(
  ln_county_gdp_prior = log(gdp),
  ln_county_pop_prior = log(pop),
  ln_county_pers_inc_prior = log(pers_inc)
)]
county_controls <- county_controls[, .(
  fips,
  year = as.integer(year),
  county_name = sub(", TX$", "", geoname),
  ln_county_gdp_prior,
  ln_county_pop_prior,
  ln_county_pers_inc_prior
)]
website_panel <- county_controls[website_panel, on = .(fips, year)]

issue_level <- as.data.table(read_dta(file.path(
  data_dir, "Mergent", "Clean",
  "260716_city_cusiplevel_statereq_purpose_yieldspread.dta"
)))
issue_level <- unique(issue_level[
  state == "TX" & !is.na(seed_issuer) & !is.na(year),
  .(
    seed_issuer_key = tolower(seed_issuer),
    year = as.integer(year),
    issue_id,
    go_unlim,
    go_lim
  )
])
issue_city_year <- issue_level[, .(
  num_issues_bond_data = uniqueN(issue_id),
  num_issues_go = uniqueN(issue_id[go_unlim == 1 | go_lim == 1])
), by = .(seed_issuer_key, year)]
website_panel <- issue_city_year[
  website_panel, on = .(seed_issuer_key, year)
]
website_panel[is.na(num_issues_bond_data), num_issues_bond_data := 0L]
website_panel[is.na(num_issues_go), num_issues_go := 0L]
website_panel[, issuance_window := as.integer(num_issues_bond_data > 0)]

website_panel[, total_words := bond_count]
lag_one <- website_panel[, .(
  seed_issuer_key,
  year = year + 1L,
  total_words_lag1 = total_words
)]
website_panel <- lag_one[website_panel, on = .(seed_issuer_key, year)]
website_panel[, delta_bond_debt_count1 := total_words - total_words_lag1]
website_panel[, positive_delta_bond_debt1 := as.integer(delta_bond_debt_count1 > 0)]

lag_two <- website_panel[, .(
  seed_issuer_key,
  year = year + 2L,
  total_words_lag2 = total_words
)]
website_panel <- lag_two[website_panel, on = .(seed_issuer_key, year)]
website_panel[, delta_bond_debt_count2 := total_words - total_words_lag2]
website_panel[, positive_delta_bond_debt2 := as.integer(delta_bond_debt_count2 > 0)]

# -----------------------------------------------------------------------------
# Construct prior and fixed county Republican two-party shares.
# -----------------------------------------------------------------------------

mit_returns <- fread(file.path(
  data_dir, "TX", "Republican Vote Share", "raw",
  "countypres_2000-2024.csv"
))
mit_returns <- mit_returns[
  state_po == "TX" & party %chin% c("REPUBLICAN", "DEMOCRAT")
]
mit_returns[, county_fips := format_fips(county_fips)]
mit_returns <- mit_returns[, .(
  republican_votes = sum(candidatevotes[party == "REPUBLICAN"], na.rm = TRUE),
  democratic_votes = sum(candidatevotes[party == "DEMOCRAT"], na.rm = TRUE)
), by = .(fips = county_fips, presidential_year = as.integer(year))]
mit_returns[, republican_two_party_share :=
              republican_votes / (republican_votes + democratic_votes)]

tx_sos_returns <- fread(file.path(
  data_dir, "TX", "Republican Vote Share", "raw",
  "tx_sos_presidential_county_1992_1996.csv"
))
tx_county_crosswalk <- unique(county_controls[
  substr(fips, 1L, 2L) == "48" & !is.na(county_name),
  .(fips, county_key = normalize_county(county_name))
])
tx_sos_returns <- tx_county_crosswalk[
  tx_sos_returns, on = "county_key", nomatch = 0L
]
tx_sos_returns <- tx_sos_returns[, .(
  fips,
  presidential_year = as.integer(year),
  republican_votes,
  democratic_votes,
  republican_two_party_share =
    republican_votes / (republican_votes + democratic_votes)
)]

county_returns <- rbindlist(
  list(tx_sos_returns, mit_returns),
  use.names = TRUE,
  fill = TRUE
)
county_returns <- unique(county_returns, by = c("fips", "presidential_year"))

presidential_years <- sort(unique(county_returns$presidential_year))
panel_year_map <- data.table(year = sort(unique(website_panel$year)))
panel_year_map[, prior_presidential_year := vapply(
  year,
  function(current_year) {
    eligible <- presidential_years[presidential_years < current_year]
    if (length(eligible) == 0L) return(NA_integer_)
    max(eligible)
  },
  integer(1)
)]
website_panel <- panel_year_map[website_panel, on = "year"]
website_panel <- county_returns[, .(
  fips,
  prior_presidential_year = presidential_year,
  republican_two_party_share
)][website_panel, on = .(fips, prior_presidential_year)]

fixed_county_share <- county_returns[
  presidential_year >= 2000 & presidential_year <= 2016,
  .(county_mean_republican_share = mean(republican_two_party_share, na.rm = TRUE)),
  by = fips
]
website_panel <- fixed_county_share[website_panel, on = "fips"]

# -----------------------------------------------------------------------------
# Estimate the original and partisan-heterogeneity specifications.
# -----------------------------------------------------------------------------

control_vars <- c(
  "issuance_window",
  "ln_county_gdp_prior",
  "ln_county_pop_prior",
  "ln_county_pers_inc_prior"
)
base_common_vars <- c(
  "election",
  "republican_two_party_share", "county_mean_republican_share", "fips",
  "seed_issuer_key", "year", control_vars
)
one_year_vars <- c("positive_delta_bond_debt1", base_common_vars)
two_year_vars <- c("positive_delta_bond_debt2", base_common_vars)
analysis_sample_one <- website_panel[
  complete.cases(website_panel[, ..one_year_vars])
]
analysis_sample_two <- website_panel[
  complete.cases(website_panel[, ..two_year_vars])
]

for (sample_name in c("analysis_sample_one", "analysis_sample_two")) {
  sample_data <- get(sample_name)
  sample_data[, republican_share_sd :=
                as.numeric(scale(republican_two_party_share))]
  sample_data[, county_mean_republican_share_sd :=
                as.numeric(scale(county_mean_republican_share))]
  assign(sample_name, sample_data)
}

models_one_year <- list(
  original_full_baseline = feols(
    positive_delta_bond_debt1 ~ election | seed_issuer_key + year,
    data = website_panel[!is.na(fips)],
    cluster = ~fips
  ),
  original_full_controls = feols(
    positive_delta_bond_debt1 ~
      election + issuance_window + ln_county_gdp_prior +
      ln_county_pop_prior + ln_county_pers_inc_prior |
      seed_issuer_key + year,
    data = website_panel[!is.na(fips)],
    cluster = ~fips
  ),
  matched_baseline = feols(
    positive_delta_bond_debt1 ~ election | seed_issuer_key + year,
    data = analysis_sample_one,
    cluster = ~fips
  ),
  prior_share = feols(
    positive_delta_bond_debt1 ~ election * republican_share_sd |
      seed_issuer_key + year,
    data = analysis_sample_one,
    cluster = ~fips
  ),
  prior_share_controls = feols(
    positive_delta_bond_debt1 ~
      election * republican_share_sd + issuance_window +
      ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
      seed_issuer_key + year,
    data = analysis_sample_one,
    cluster = ~fips
  ),
  fixed_county_share_controls = feols(
    positive_delta_bond_debt1 ~
      election + election:county_mean_republican_share_sd + issuance_window +
      ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
      seed_issuer_key + year,
    data = analysis_sample_one,
    cluster = ~fips
  )
)

models_two_year <- list(
  original_full_baseline = feols(
    positive_delta_bond_debt2 ~ election | seed_issuer_key + year,
    data = website_panel[!is.na(fips)],
    cluster = ~fips
  ),
  matched_baseline = feols(
    positive_delta_bond_debt2 ~ election | seed_issuer_key + year,
    data = analysis_sample_two,
    cluster = ~fips
  ),
  prior_share_controls = feols(
    positive_delta_bond_debt2 ~
      election * republican_share_sd + issuance_window +
      ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
      seed_issuer_key + year,
    data = analysis_sample_two,
    cluster = ~fips
  ),
  fixed_county_share_controls = feols(
    positive_delta_bond_debt2 ~
      election + election:county_mean_republican_share_sd + issuance_window +
      ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
      seed_issuer_key + year,
    data = analysis_sample_two,
    cluster = ~fips
  )
)

coefficient_results <- rbindlist(c(
  Map(
    function(model, name) tidy_fixest(model, name, "One-year increase"),
    models_one_year,
    names(models_one_year)
  ),
  Map(
    function(model, name) tidy_fixest(model, name, "Two-year increase"),
    models_two_year,
    names(models_two_year)
  )
), use.names = TRUE, fill = TRUE)
fwrite(coefficient_results, coefficient_path)

fixed_model <- models_one_year$fixed_county_share_controls
fixed_term <- "election:county_mean_republican_share_sd"
fixed_quantiles <- quantile(
  analysis_sample_one$county_mean_republican_share_sd,
  probs = c(0.25, 0.50, 0.75),
  na.rm = TRUE
)
marginal_effects <- rbindlist(lapply(seq_along(fixed_quantiles), function(i) {
  linear_combination(
    fixed_model,
    "election",
    fixed_term,
    unname(fixed_quantiles[i]),
    names(fixed_quantiles)[i],
    "fixed_county_share_controls",
    "One-year increase"
  )
}))
fwrite(marginal_effects, marginal_effect_path)

output_columns <- c(
  "seed_issuer", "seed_issuer_key", "year", "fips", "county_name",
  "election", "issuance_window", "bond_count", "total_words_lag1",
  "positive_delta_bond_debt1", "total_words_lag2",
  "positive_delta_bond_debt2", "prior_presidential_year",
  "republican_two_party_share", "republican_share_sd",
  "county_mean_republican_share", "county_mean_republican_share_sd",
  "ln_county_gdp_prior", "ln_county_pop_prior", "ln_county_pers_inc_prior"
)
fwrite(analysis_sample_one[, ..output_columns], analysis_data_path)

prior_interaction <- coefficient_results[
  outcome == "One-year increase" & model == "prior_share_controls" &
    term == "election:republican_share_sd"
]
fixed_interaction <- coefficient_results[
  outcome == "One-year increase" & model == "fixed_county_share_controls" &
    term == "election:county_mean_republican_share_sd"
]
baseline_row <- coefficient_results[
  outcome == "One-year increase" & model == "original_full_baseline" &
    term == "election"
]
matched_baseline_row <- coefficient_results[
  outcome == "One-year increase" & model == "matched_baseline" &
    term == "election"
]

summary_lines <- c(
  "# Texas website disclosure response by county Republican share",
  "",
  paste0("- One-year analysis sample: ",
         format(nrow(analysis_sample_one), big.mark = ","),
         " city-years, ", uniqueN(analysis_sample_one$seed_issuer_key),
         " cities, and ", uniqueN(analysis_sample_one$fips), " counties."),
  paste0("- Two-year robustness sample: ",
         format(nrow(analysis_sample_two), big.mark = ","), " city-years."),
  paste0("- Reproduced original election-year response: ",
         sprintf("%.3f", baseline_row$estimate), " (p = ",
         sprintf("%.3f", baseline_row$p_value), "; N = ",
         format(baseline_row$n, big.mark = ","), ")."),
  paste0("- Election-year response on the partisan-share matched sample: ",
         sprintf("%.3f", matched_baseline_row$estimate), " (p = ",
         sprintf("%.3f", matched_baseline_row$p_value), "; N = ",
         format(matched_baseline_row$n, big.mark = ","), ")."),
  paste0("- Election x prior Republican share (per one SD), with controls: ",
         sprintf("%.3f", prior_interaction$estimate), " (p = ",
         sprintf("%.3f", prior_interaction$p_value), ")."),
  paste0("- Election x fixed county Republican share (per one SD), with controls: ",
         sprintf("%.3f", fixed_interaction$estimate), " (p = ",
         sprintf("%.3f", fixed_interaction$p_value), ")."),
  "",
  "## Election-year marginal effects using fixed county partisanship",
  "",
  paste0(
    "- ", marginal_effects$moderator_label, ": ",
    sprintf("%.3f", marginal_effects$election_effect), " (p = ",
    sprintf("%.3f", marginal_effects$p_value), ")"
  ),
  "",
  "All specifications include city and year fixed effects and cluster standard errors by county. The controlled specifications also include a bond-issuance-year indicator and county GDP, population, and personal income controls."
)
writeLines(summary_lines, summary_path)

cat(paste(summary_lines, collapse = "\n"), "\n")
cat("\nSaved:\n")
cat("-", analysis_data_path, "\n")
cat("-", coefficient_path, "\n")
cat("-", marginal_effect_path, "\n")
cat("-", summary_path, "\n")
