# 13: Texas local rejection-risk mechanism tests
#
# Produces parallel tables for two five-year measures built from prior ISD bond
# propositions: an area-overlap-weighted failure rate and a simple failure rate
# limited to ISDs covering at least 20 percent of city area.

rm(list = ls())

library(pacman)
p_load(data.table, fixest)

source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R")

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
regression_data_dir <- file.path(root, "Data/Clean_Intermediate/TX/Regression")
substitution_file <- file.path(
  root,
  "Data/Clean_Intermediate/Census COG Finance/processed",
  "texas_2017_purpose_substitution_rejection_risk.csv"
)
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = file.path(root, "Code/R/Clean/output/revision_tables")
)
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

website_city_year <- fread(
  file.path(regression_data_dir, "website_city_year_regression_ready.csv")
)
city_month <- fread(
  file.path(regression_data_dir, "city_month_media_regression_ready.csv")
)
substitution <- fread(substitution_file)

website_city_year[, seed_issuer := tolower(trimws(seed_issuer))]
city_month[, seed_issuer := tolower(trimws(seed_issuer))]
substitution[, seed_issuer := tolower(trimws(seed_issuer))]

# Annual election-incidence outcome: risk is measured on January 1, and the
# outcome is whether the city holds any bond election during that calendar year.
annual_election_outcome <- city_month[
  year >= 1996L & year <= 2023L,
  .(city_bond_election_year = as.integer(any(has_bond_election == 1L))),
  by = .(seed_issuer, year)
]
annual_election <- city_month[month == 1L & year >= 1996L & year <= 2023L]
annual_election <- annual_election_outcome[
  annual_election,
  on = .(seed_issuer, year)
]

# ==============================================================================
# AREA-OVERLAP-WEIGHTED FAILURE RATE
# ==============================================================================

website_weighted <- website_city_year[
  !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_60m) & !is.na(issuance_year) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
website_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m - mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)
]

annual_weighted <- annual_election[
  !is.na(city_bond_election_year) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_60m) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m - mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)
]

substitution_weighted <- substitution[
  !is.na(share_revenue_vs_go_amount) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_60m) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_census_total_debt) & !is.na(ln_1p_county_nonmunicipal_total_debt)
]
substitution_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m - mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)
]

weighted_disclosure <- feols(
  positive_delta_bond_debt1 ~ election * weighted_risk_z + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_weighted,
  cluster = ~fips
)
weighted_annual_election <- feols(
  city_bond_election_year ~ weighted_risk_z + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_weighted,
  cluster = ~fips
)
weighted_substitution <- feols(
  share_revenue_vs_go_amount ~ weighted_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt + ln_1p_county_nonmunicipal_total_debt |
    purpose_category,
  data = substitution_weighted,
  cluster = ~fips
)

weighted_table <- etable(
  weighted_disclosure, weighted_annual_election, weighted_substitution,
  headers = c("Disclosure", "Annual Election", "2017 Revenue Share"),
  coefstat = "tstat",
  keep_raw = "weighted_risk_z|election:weighted_risk_z|^election$",
  order_raw = c("^weighted_risk_z$", "^election:weighted_risk_z$", "^election$"),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "Increase in Bond Text",
    city_bond_election_year = "Any City Bond Election",
    share_revenue_vs_go_amount = "Revenue-Bond Share",
    weighted_risk_z = "Local Rejection Risk (1 SD)",
    `election:weighted_risk_z` = "Election Year $\\times$ Local Rejection Risk",
    election = "Election Year"
  ),
  extralines = list(
    "Economic/debt controls" = c("Yes", "Yes", "Yes"),
    "Risk window" = c("Five years", "Five years", "Five years"),
    "Risk measure" = c("Area weighted", "Area weighted", "Area weighted")
  ),
  placement = "H",
  replace = TRUE
)
weighted_output <- modify_etable_rounding(
  weighted_table,
  coef_digits = 3,
  tstat_digits = 2
)
weighted_output <- format_table(weighted_output, cluster_level = "County")
weighted_output <- sub("[[:space:]]+$", "", weighted_output)
weighted_output <- add_panel(
  weighted_output,
  "Texas local rejection risk: area-overlap-weighted failure rate",
  ncols = 4
)
writeLines(
  weighted_output,
  file.path(tbl_dir, "tx_rejection_risk_weighted.tex")
)

# ==============================================================================
# SIMPLE FAILURE RATE: ISDS COVERING AT LEAST 20 PERCENT OF CITY AREA
# ==============================================================================

website_simple <- website_city_year[
  !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_60m) & !is.na(issuance_year) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
website_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)
]

annual_simple <- annual_election[
  !is.na(city_bond_election_year) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_60m) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)
]

substitution_simple <- substitution[
  !is.na(share_revenue_vs_go_amount) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_60m) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_census_total_debt) & !is.na(ln_1p_county_nonmunicipal_total_debt)
]
substitution_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)
]

simple_disclosure <- feols(
  positive_delta_bond_debt1 ~ election * simple_risk_z + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_simple,
  cluster = ~fips
)
simple_annual_election <- feols(
  city_bond_election_year ~ simple_risk_z + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_simple,
  cluster = ~fips
)
simple_substitution <- feols(
  share_revenue_vs_go_amount ~ simple_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt + ln_1p_county_nonmunicipal_total_debt |
    purpose_category,
  data = substitution_simple,
  cluster = ~fips
)

simple_table <- etable(
  simple_disclosure, simple_annual_election, simple_substitution,
  headers = c("Disclosure", "Annual Election", "2017 Revenue Share"),
  coefstat = "tstat",
  keep_raw = "simple_risk_z|election:simple_risk_z|^election$",
  order_raw = c("^simple_risk_z$", "^election:simple_risk_z$", "^election$"),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "Increase in Bond Text",
    city_bond_election_year = "Any City Bond Election",
    share_revenue_vs_go_amount = "Revenue-Bond Share",
    simple_risk_z = "Local Rejection Risk (1 SD)",
    `election:simple_risk_z` = "Election Year $\\times$ Local Rejection Risk",
    election = "Election Year"
  ),
  extralines = list(
    "Economic/debt controls" = c("Yes", "Yes", "Yes"),
    "Risk window" = c("Five years", "Five years", "Five years"),
    "Risk measure" = c("ISD overlap $\\geq$ 20\\%", "ISD overlap $\\geq$ 20\\%", "ISD overlap $\\geq$ 20\\%")
  ),
  placement = "H",
  replace = TRUE
)
simple_output <- modify_etable_rounding(
  simple_table,
  coef_digits = 3,
  tstat_digits = 2
)
simple_output <- format_table(simple_output, cluster_level = "County")
simple_output <- sub("[[:space:]]+$", "", simple_output)
simple_output <- add_panel(
  simple_output,
  "Texas local rejection risk: simple failure rate among overlapping ISDs",
  ncols = 4
)
writeLines(
  simple_output,
  file.path(tbl_dir, "tx_rejection_risk_simple_20pct.tex")
)
