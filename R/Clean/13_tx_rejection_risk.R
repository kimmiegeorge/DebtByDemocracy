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
debt_choice_file <- file.path(
  root,
  "Data/Clean_Intermediate/Census COG Finance/processed",
  "texas_2017_debt_choice_rejection_risk.csv"
)
outstanding_debt_file <- file.path(
  root,
  "Data/Mergent/Outstanding Debt",
  "260709_issuer_year_outstanding_debt.csv"
)
city_propositions_file <- file.path(
  root,
  "Data/Clean_Intermediate/TX/Election_Exposure",
  "city_propositions_high_overlap_isd_failure_exposure.csv"
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
debt_choice <- fread(debt_choice_file)
city_propositions <- fread(city_propositions_file)
outstanding_debt <- fread(outstanding_debt_file)

website_city_year[, seed_issuer := tolower(trimws(seed_issuer))]
city_month[, seed_issuer := tolower(trimws(seed_issuer))]
debt_choice[, seed_issuer := tolower(trimws(seed_issuer))]
debt_choice[, ln_census_population := log(census_population)]
city_propositions[, seed_key := tolower(trimws(seed_key))]

# The year-t annual-election regressions use total debt outstanding at the end
# of year t - 1, which is the stock available at the beginning of year t.
outstanding_debt <- outstanding_debt[
  state == "TX",
  .(
    seed_issuer_id = as.numeric(seed_issuer_id),
    year = as.integer(year) + 1L,
    ln_1p_outstanding_debt_lag1 = ln_1p_total_outstanding_debt
  )
]
stopifnot(!anyDuplicated(outstanding_debt, by = c("seed_issuer_id", "year")))

# Predictive-validity sample: risk is calculated using only ISD propositions
# strictly before each later city bond proposition. The proposition-level sample
# preserves the ballot outcome while accounting for election amount and purpose.
city_propositions[, election_month := as.integer(format(as.IDate(election_date), "%m"))]
city_proposition_controls <- unique(city_month[, .(
  seed_issuer, year, month, ln_county_gdp_prior,
  ln_county_pop_prior, ln_county_pers_inc_prior
)])
city_propositions <- merge(
  city_propositions,
  city_proposition_controls,
  by.x = c("seed_key", "year", "election_month"),
  by.y = c("seed_issuer", "year", "month"),
  all.x = TRUE,
  sort = FALSE
)
city_propositions[, ln_amount := log1p(Amount)]

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
annual_election[, seed_issuer_id := as.numeric(seed_issuer_id)]
annual_election <- merge(
  annual_election,
  outstanding_debt,
  by = c("seed_issuer_id", "year"),
  all.x = TRUE,
  sort = FALSE
)

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
    !is.na(ln_1p_outstanding_debt_lag1) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m - mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)
]

debt_choice_weighted <- debt_choice[
  insample == 1L & insample_allgo == 1L &
    mergent_go_revenue_bonds_outstanding >= 2L &
    !is.na(frac_rev_outstanding) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_all_history_pre2017) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt)
]
debt_choice_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_all_history_pre2017 -
    mean(prior_weighted_failure_rate_all_history_pre2017)) /
    sd(prior_weighted_failure_rate_all_history_pre2017)
]

weighted_disclosure <- feols(
  positive_delta_bond_debt1 ~ election * weighted_risk_z + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_weighted,
  cluster = ~fips
)
weighted_annual_election <- feols(
  city_bond_election_year ~ weighted_risk_z + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_weighted,
  cluster = ~fips
)
weighted_substitution <- feols(
  frac_rev_outstanding ~ weighted_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_weighted,
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
    frac_rev_outstanding = "Pct Revenue",
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
    !is.na(ln_1p_outstanding_debt_lag1) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)
]

debt_choice_simple <- debt_choice[
  insample == 1L & insample_allgo == 1L &
    mergent_go_revenue_bonds_outstanding >= 2L &
    !is.na(frac_rev_outstanding) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_all_history_pre2017) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt)
]
debt_choice_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_all_history_pre2017 -
    mean(prior_simple_failure_rate_20pct_all_history_pre2017)) /
    sd(prior_simple_failure_rate_20pct_all_history_pre2017)
]

simple_disclosure <- feols(
  positive_delta_bond_debt1 ~ election * simple_risk_z + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_simple,
  cluster = ~fips
)
simple_annual_election <- feols(
  city_bond_election_year ~ simple_risk_z + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_simple,
  cluster = ~fips
)
simple_substitution <- feols(
  frac_rev_outstanding ~ simple_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_simple,
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
    frac_rev_outstanding = "Pct Revenue",
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

# ==============================================================================
# PREDICTIVE VALIDITY: SUBSEQUENT CITY BOND-PROPOSITION OUTCOMES
# ==============================================================================

validation_weighted <- city_propositions[
  vote_total > 0 & !is.na(failed) & !is.na(vote_margin_signed) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_60m) & !is.na(ln_amount) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior) & !is.na(Purpose)
]
validation_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m - mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)]

validation_weighted_failure <- feols(
  failed ~ weighted_risk_z + ln_amount + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | year + Purpose,
  data = validation_weighted,
  cluster = ~fips
)
validation_weighted_margin <- feols(
  vote_margin_signed ~ weighted_risk_z + ln_amount + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | year + Purpose,
  data = validation_weighted,
  cluster = ~fips
)

validation_weighted_table <- etable(
  validation_weighted_failure, validation_weighted_margin,
  coefstat = "tstat",
  keep_raw = "^weighted_risk_z$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    failed = "City Proposition Failed",
    vote_margin_signed = "Signed Vote Margin",
    weighted_risk_z = "Local Rejection Risk"
  ),
  extralines = list(
    "Controls" = c("Yes", "Yes"),
    "Risk window" = c("Five years", "Five years")
  ),
  placement = "H",
  replace = TRUE
)
validation_weighted_output <- modify_etable_rounding(
  validation_weighted_table,
  coef_digits = 3,
  tstat_digits = 2
)
validation_weighted_output <- format_table(
  validation_weighted_output,
  cluster_level = "County"
)
validation_weighted_output <- sub("[[:space:]]+$", "", validation_weighted_output)
validation_weighted_output <- add_panel(
  validation_weighted_output,
  "Predictive validity: overlap-weighted rejection risk and later city ballot outcomes",
  ncols = 3
)
writeLines(
  validation_weighted_output,
  file.path(tbl_dir, "tx_rejection_risk_validation_weighted.tex")
)

validation_simple <- city_propositions[
  vote_total > 0 & !is.na(failed) & !is.na(vote_margin_signed) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_60m) & !is.na(ln_amount) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior) & !is.na(Purpose)
]
validation_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)]

validation_simple_failure <- feols(
  failed ~ simple_risk_z + ln_amount + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | year + Purpose,
  data = validation_simple,
  cluster = ~fips
)
validation_simple_margin <- feols(
  vote_margin_signed ~ simple_risk_z + ln_amount + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | year + Purpose,
  data = validation_simple,
  cluster = ~fips
)

validation_simple_table <- etable(
  validation_simple_failure, validation_simple_margin,
  coefstat = "tstat",
  keep_raw = "^simple_risk_z$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    failed = "City Proposition Failed",
    vote_margin_signed = "Signed Vote Margin",
    simple_risk_z = "Local Rejection Risk"
  ),
  extralines = list(
    "Controls" = c("Yes", "Yes"),
    "Risk window" = c("Five years", "Five years")
  ),
  placement = "H",
  replace = TRUE
)
validation_simple_output <- modify_etable_rounding(
  validation_simple_table,
  coef_digits = 3,
  tstat_digits = 2
)
validation_simple_output <- format_table(
  validation_simple_output,
  cluster_level = "County"
)
validation_simple_output <- sub("[[:space:]]+$", "", validation_simple_output)
validation_simple_output <- add_panel(
  validation_simple_output,
  "Predictive validity: simple 20 percent-overlap rejection risk and later city ballot outcomes",
  ncols = 3
)
writeLines(
  validation_simple_output,
  file.path(tbl_dir, "tx_rejection_risk_validation_simple_20pct.tex")
)
