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
analysis_data_dir <- file.path(
  root,
  "Data/Clean_Intermediate/TX/Rejection_Risk"
)
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = file.path(root, "Code/R/Clean/output/revision_tables")
)
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

# Data construction is handled by the Python preparation step; this script
# loads those panels and runs the regression and table code below.
website_city_year <- fread(
  file.path(analysis_data_dir, "website_city_year_analysis.csv")
)
annual_election <- fread(
  file.path(analysis_data_dir, "annual_election_analysis.csv")
)
annual_news_election <- fread(
  file.path(analysis_data_dir, "annual_news_election_analysis.csv")
)
city_propositions <- fread(
  file.path(analysis_data_dir, "city_propositions_analysis.csv")
)
debt_choice <- fread(
  file.path(analysis_data_dir, "debt_choice_analysis.csv")
)
full_issuance_debt_choice <- fread(
  file.path(analysis_data_dir, "full_issuance_debt_choice_analysis.csv")
)
media_panel_indicator <- fread(
  file.path(analysis_data_dir, "media_panel_indicator_analysis.csv")
)

# Keep every time-series rejection-risk specification on the same window as
# the Texas election, media, and website analyses.
analysis_start_year <- 2001L
analysis_end_year <- 2020L
website_city_year <- website_city_year[
  year >= analysis_start_year & year <= analysis_end_year
]
annual_election <- annual_election[
  year >= analysis_start_year & year <= analysis_end_year
]
annual_news_election <- annual_news_election[
  year >= analysis_start_year & year <= analysis_end_year
]
city_propositions <- city_propositions[
  year >= analysis_start_year & year <= analysis_end_year
]
media_panel_indicator <- media_panel_indicator[
  year >= analysis_start_year & year <= analysis_end_year
]

indicator_10yr_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_50pct_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_city_year[
    !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
      !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_media <- feols(
  covered ~ election_window * failure_50pct_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
indicator_10yr_annual <- feols(
  city_bond_election_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(city_bond_election_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_go_issuance <- feols(
  go_bond_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(go_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_any_issuance <- feols(
  any_debt_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(any_debt_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_revenue_issuance <- feols(
  revenue_bond_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(revenue_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_any_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_any_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_city_year[
    !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
      !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_any_media <- feols(
  covered ~ election_window * failure_any_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_any_election <- feols(
  city_bond_election_year ~ failure_any_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_any_issuance <- feols(
  any_debt_issuance_year ~ failure_any_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_any_go <- feols(
  go_bond_issuance_year ~ failure_any_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_any_revenue <- feols(
  revenue_bond_issuance_year ~ failure_any_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)

robust_20pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_20pct_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_city_year[
    !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
      !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_20pct_media <- feols(
  covered ~ election_window * failure_20pct_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_20pct_election <- feols(
  city_bond_election_year ~ failure_20pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_20pct_issuance <- feols(
  any_debt_issuance_year ~ failure_20pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_20pct_go <- feols(
  go_bond_issuance_year ~ failure_20pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_20pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_20pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)

robust_25pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_25pct_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_city_year[
    !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
      !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_25pct_media <- feols(
  covered ~ election_window * failure_25pct_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_25pct_election <- feols(
  city_bond_election_year ~ failure_25pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_25pct_issuance <- feols(
  any_debt_issuance_year ~ failure_25pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_25pct_go <- feols(
  go_bond_issuance_year ~ failure_25pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_25pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_25pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)

robust_80pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_80pct_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_city_year[
    !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
      !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_80pct_media <- feols(
  covered ~ election_window * failure_80pct_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_80pct_election <- feols(
  city_bond_election_year ~ failure_80pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_80pct_issuance <- feols(
  any_debt_issuance_year ~ failure_80pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_80pct_go <- feols(
  go_bond_issuance_year ~ failure_80pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
robust_80pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_80pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
      !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
      !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)

# All-history counterparts for the private threshold-sensitivity table.
website_robustness_sample <- website_city_year[
  !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
    !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
    !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
]
annual_robustness_sample <- annual_election[
  year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
robust_all_history_any_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_any_all_history + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
  cluster = ~fips
)
robust_all_history_any_media <- feols(
  covered ~ election_window * failure_any_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_all_history_any_election <- feols(
  city_bond_election_year ~ failure_any_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_any_issuance <- feols(
  any_debt_issuance_year ~ failure_any_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_any_go <- feols(
  go_bond_issuance_year ~ failure_any_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_any_revenue <- feols(
  revenue_bond_issuance_year ~ failure_any_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)

robust_all_history_20pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_20pct_all_history + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
  cluster = ~fips
)
robust_all_history_20pct_media <- feols(
  covered ~ election_window * failure_20pct_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_all_history_20pct_election <- feols(
  city_bond_election_year ~ failure_20pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_20pct_issuance <- feols(
  any_debt_issuance_year ~ failure_20pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_20pct_go <- feols(
  go_bond_issuance_year ~ failure_20pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_20pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_20pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)

robust_all_history_25pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_25pct_all_history + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
  cluster = ~fips
)
robust_all_history_25pct_media <- feols(
  covered ~ election_window * failure_25pct_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_all_history_25pct_election <- feols(
  city_bond_election_year ~ failure_25pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_25pct_issuance <- feols(
  any_debt_issuance_year ~ failure_25pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_25pct_go <- feols(
  go_bond_issuance_year ~ failure_25pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_25pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_25pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)

robust_all_history_80pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_80pct_all_history + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
  cluster = ~fips
)
robust_all_history_80pct_media <- feols(
  covered ~ election_window * failure_80pct_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_all_history_80pct_election <- feols(
  city_bond_election_year ~ failure_80pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_80pct_issuance <- feols(
  any_debt_issuance_year ~ failure_80pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_80pct_go <- feols(
  go_bond_issuance_year ~ failure_80pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_80pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_80pct_all_history + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
indicator_10yr_annual_news <- feols(
  city_bond_election_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(city_bond_election_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_go_issuance_news <- feols(
  go_bond_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(go_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_any_issuance_news <- feols(
  any_debt_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(any_debt_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_10yr_revenue_issuance_news <- feols(
  revenue_bond_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(revenue_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)

indicator_all_history_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_50pct_all_history +
    issuance_year + ln_county_gdp_prior + ln_county_pop_prior +
    ln_county_pers_inc_prior | seed_issuer + year,
  data = website_city_year[
    !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
      !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_media <- feols(
  covered ~ election_window * failure_50pct_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
indicator_all_history_annual <- feols(
  city_bond_election_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(city_bond_election_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_go_issuance <- feols(
  go_bond_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(go_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_any_issuance <- feols(
  any_debt_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(any_debt_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_revenue_issuance <- feols(
  revenue_bond_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_election[
    year > 2000 & !is.na(revenue_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_annual_news <- feols(
  city_bond_election_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(city_bond_election_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_go_issuance_news <- feols(
  go_bond_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(go_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_any_issuance_news <- feols(
  any_debt_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(any_debt_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)
indicator_all_history_revenue_issuance_news <- feols(
  revenue_bond_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_news_election[
    year > 2000 & !is.na(revenue_bond_issuance_year) & !is.na(fips) &
      !is.na(ln_1p_outstanding_debt_lag1) & !is.na(ln_county_gdp_prior) &
      !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
  ],
  cluster = ~fips
)

indicator_10yr_table <- etable(
  indicator_10yr_website, indicator_10yr_media, indicator_10yr_annual_news,
  indicator_10yr_go_issuance_news, indicator_10yr_any_issuance_news,
  indicator_10yr_revenue_issuance_news,
  coefstat = "tstat",
  keep_raw = "failure_50pct_10yr|election:failure_50pct_10yr|election_window:failure_50pct_10yr|^election$|^election_window$",
  order_raw = c(
    "^election$", "^election:failure_50pct_10yr$",
    "^election_window$", "^election_window:failure_50pct_10yr$",
    "^failure_50pct_10yr$"
  ),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "\\shortstack{Increase in\\\\ Bond Text}",
    covered = "\\shortstack{Bond\\\\ Coverage}",
    city_bond_election_year = "\\shortstack{Any City Bond\\\\ Election}",
    go_bond_issuance_year = "\\shortstack{Any City GO\\\\ Bond Issuance}",
    any_debt_issuance_year = "\\shortstack{Any City Debt\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Any City Revenue\\\\ Bond Issuance}",
    failure_50pct_10yr = "Prior ISD Failure",
    `election:failure_50pct_10yr` = "Election Year $\\times$ Prior ISD Failure",
    election = "Election Year",
    election_window = "Election [0, +3]",
    `election_window:failure_50pct_10yr` = "Election [0, +3] $\\times$ Prior ISD Failure",
    seed_issuer = "City", year = "Year", year_month_id = "Year-Month"
  ),
  extralines = list("Controls" = c("Yes", "Yes", "Yes", "Yes", "Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_10yr_output <- modify_etable_rounding(
  indicator_10yr_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_10yr_output <- format_table(
  indicator_10yr_output,
  cluster_level = "County"
)
indicator_10yr_output <- add_panel(
  indicator_10yr_output,
  "Texas local rejection risk: failed ISD with at least 50% city-area overlap in the prior ten years",
  ncols = 7,
  zero_width = TRUE
)
# The six outcome columns are wider than a landscape text block at the native
# etable size. Scale the full tabular to the available page width.
indicator_10yr_table_start <- grep("^\\\\begin\\{tabular\\*\\}", indicator_10yr_output)
indicator_10yr_output <- append(
  indicator_10yr_output, "\\resizebox{\\textwidth}{!}{%}",
  after = indicator_10yr_table_start - 1L
)
indicator_10yr_table_end <- grep("^\\\\end\\{tabular\\*\\}", indicator_10yr_output)
indicator_10yr_output <- append(indicator_10yr_output, "}", after = indicator_10yr_table_end)

indicator_all_history_table <- etable(
  indicator_all_history_website, indicator_all_history_media,
  indicator_all_history_annual_news, indicator_all_history_go_issuance_news,
  indicator_all_history_any_issuance_news,
  indicator_all_history_revenue_issuance_news,
  coefstat = "tstat",
  keep_raw = "failure_50pct_all_history|election:failure_50pct_all_history|election_window:failure_50pct_all_history|^election$|^election_window$",
  order_raw = c(
    "^election$", "^election:failure_50pct_all_history$",
    "^election_window$", "^election_window:failure_50pct_all_history$",
    "^failure_50pct_all_history$"
  ),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "\\shortstack{Increase in\\\\ Bond Text}",
    covered = "\\shortstack{Bond\\\\ Coverage}",
    city_bond_election_year = "\\shortstack{Any City Bond\\\\ Election}",
    go_bond_issuance_year = "\\shortstack{Any City GO\\\\ Bond Issuance}",
    any_debt_issuance_year = "\\shortstack{Any City Debt\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Any City Revenue\\\\ Bond Issuance}",
    failure_50pct_all_history = "Prior ISD Failure",
    `election:failure_50pct_all_history` = "Election Year $\\times$ Prior ISD Failure",
    election = "Election Year",
    election_window = "Election [0, +3]",
    `election_window:failure_50pct_all_history` = "Election [0, +3] $\\times$ Prior ISD Failure",
    seed_issuer = "City", year = "Year", year_month_id = "Year-Month"
  ),
  extralines = list("Controls" = c("Yes", "Yes", "Yes", "Yes", "Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_all_history_output <- modify_etable_rounding(
  indicator_all_history_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_all_history_output <- format_table(
  indicator_all_history_output,
  cluster_level = "County"
)
indicator_all_history_output <- add_panel(
  indicator_all_history_output,
  "Texas local rejection risk: failed ISD with at least 50% city-area overlap in all prior recorded years",
  ncols = 7,
  zero_width = TRUE
)
indicator_all_history_table_start <- grep(
  "^\\\\begin\\{tabular\\*\\}", indicator_all_history_output
)
indicator_all_history_output <- append(
  indicator_all_history_output, "\\resizebox{\\textwidth}{!}{%}",
  after = indicator_all_history_table_start - 1L
)
indicator_all_history_table_end <- grep(
  "^\\\\end\\{tabular\\*\\}", indicator_all_history_output
)
indicator_all_history_output <- append(
  indicator_all_history_output, "}",
  after = indicator_all_history_table_end
)

# Separate robustness tables: annual outcomes on the expanded Census/COG city
# universe, constructed without RavenPack/news coverage. The disclosure and
# media outcomes remain in the main tables because their samples require their
# respective source data.
indicator_10yr_no_news_annual_table <- etable(
  indicator_10yr_annual, indicator_10yr_go_issuance,
  indicator_10yr_any_issuance, indicator_10yr_revenue_issuance,
  coefstat = "tstat",
  keep_raw = "^failure_50pct_10yr$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    city_bond_election_year = "\\shortstack{Any City Bond\\\\ Election}",
    go_bond_issuance_year = "\\shortstack{Any City GO\\\\ Bond Issuance}",
    any_debt_issuance_year = "\\shortstack{Any City Debt\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Any City Revenue\\\\ Bond Issuance}",
    failure_50pct_10yr = "Prior ISD Failure",
    seed_issuer = "City", year = "Year"
  ),
  extralines = list("Controls" = c("Yes", "Yes", "Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_10yr_no_news_annual_output <- modify_etable_rounding(
  indicator_10yr_no_news_annual_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_10yr_no_news_annual_output <- format_table(
  indicator_10yr_no_news_annual_output,
  cluster_level = "County"
)
indicator_10yr_no_news_annual_output <- add_panel(
  indicator_10yr_no_news_annual_output,
  "Texas annual outcomes, no-news city panel: 10-year local rejection-risk indicator",
  ncols = 5,
  zero_width = TRUE
)

indicator_all_history_no_news_annual_table <- etable(
  indicator_all_history_annual, indicator_all_history_go_issuance,
  indicator_all_history_any_issuance, indicator_all_history_revenue_issuance,
  coefstat = "tstat",
  keep_raw = "^failure_50pct_all_history$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    city_bond_election_year = "\\shortstack{Any City Bond\\\\ Election}",
    go_bond_issuance_year = "\\shortstack{Any City GO\\\\ Bond Issuance}",
    any_debt_issuance_year = "\\shortstack{Any City Debt\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Any City Revenue\\\\ Bond Issuance}",
    failure_50pct_all_history = "Prior ISD Failure",
    seed_issuer = "City", year = "Year"
  ),
  extralines = list("Controls" = c("Yes", "Yes", "Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_all_history_no_news_annual_output <- modify_etable_rounding(
  indicator_all_history_no_news_annual_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_all_history_no_news_annual_output <- format_table(
  indicator_all_history_no_news_annual_output,
  cluster_level = "County"
)
indicator_all_history_no_news_annual_output <- add_panel(
  indicator_all_history_no_news_annual_output,
  "Texas annual outcomes, no-news city panel: all-history local rejection-risk indicator",
  ncols = 5,
  zero_width = TRUE
)

# Final presentation tables: Panel A contains the information-environment
# outcomes; Panel B contains the referendum and issuance decisions on the
# expanded no-news annual city panel. The annual controls are shown explicitly
# in Panel B, while Panel A reports their inclusion below fit statistics.
indicator_10yr_panel_a_table <- etable(
  indicator_10yr_website, indicator_10yr_media,
  coefstat = "tstat",
  keep_raw = "failure_50pct_10yr|election:failure_50pct_10yr|election_window:failure_50pct_10yr|^election$|^election_window$",
  order_raw = c(
    "^election$", "^election:failure_50pct_10yr$",
    "^election_window$", "^election_window:failure_50pct_10yr$",
    "^failure_50pct_10yr$"
  ),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "\\shortstack{Increase in\\\\ Bond Text}",
    covered = "\\shortstack{Bond\\\\ Coverage}",
    failure_50pct_10yr = "Prior ISD Failure",
    `election:failure_50pct_10yr` = "Election Year $\\times$ Prior ISD Failure",
    election = "Election Year",
    election_window = "Election [0, +3]",
    `election_window:failure_50pct_10yr` = "Election [0, +3] $\\times$ Prior ISD Failure",
    seed_issuer = "City", year = "Year", year_month_id = "Year-Month"
  ),
  extralines = list("Controls" = c("Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_10yr_panel_a_output <- modify_etable_rounding(
  indicator_10yr_panel_a_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_10yr_panel_a_output <- format_table(
  indicator_10yr_panel_a_output,
  cluster_level = "County"
)
indicator_10yr_panel_a_controls <- grep(
  "^[[:space:]]*Controls[[:space:]]*&", indicator_10yr_panel_a_output
)
indicator_10yr_panel_a_control_line <- indicator_10yr_panel_a_output[
  indicator_10yr_panel_a_controls
]
indicator_10yr_panel_a_output <- indicator_10yr_panel_a_output[
  -indicator_10yr_panel_a_controls
]
indicator_10yr_panel_a_ar2 <- grep(
  "^[[:space:]]*Adj\\. R", indicator_10yr_panel_a_output
)
indicator_10yr_panel_a_output <- append(
  indicator_10yr_panel_a_output,
  indicator_10yr_panel_a_control_line,
  after = indicator_10yr_panel_a_ar2
)
indicator_10yr_panel_a_output <- add_panel(
  indicator_10yr_panel_a_output,
  "Panel A: Rejection risk and the information environment",
  ncols = 3,
  zero_width = TRUE
)

indicator_10yr_panel_b_table <- etable(
  indicator_10yr_annual, indicator_10yr_any_issuance,
  indicator_10yr_go_issuance, indicator_10yr_revenue_issuance,
  coefstat = "tstat",
  order_raw = c(
    "^failure_50pct_10yr$", "^ln_1p_outstanding_debt_lag1$",
    "^ln_county_gdp_prior$", "^ln_county_pop_prior$",
    "^ln_county_pers_inc_prior$"
  ),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    city_bond_election_year = "\\shortstack{Bond\\\\ Election}",
    any_debt_issuance_year = "\\shortstack{Any Bond\\\\ Issuance}",
    go_bond_issuance_year = "\\shortstack{GO Bond\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Rev Bond\\\\ Issuance}",
    failure_50pct_10yr = "Prior ISD Failure",
    ln_1p_outstanding_debt_lag1 = "Outstanding Debt",
    ln_county_gdp_prior = "County ln(GDP)",
    ln_county_pop_prior = "County ln(Pop)",
    ln_county_pers_inc_prior = "County ln(Pers. Inc)",
    seed_issuer = "City", year = "Year"
  ),
  placement = "H",
  replace = TRUE
)
indicator_10yr_panel_b_output <- modify_etable_rounding(
  indicator_10yr_panel_b_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_10yr_panel_b_output <- format_table(
  indicator_10yr_panel_b_output,
  cluster_level = "County"
)
indicator_10yr_panel_b_output <- add_panel(
  indicator_10yr_panel_b_output,
  "Panel B: Rejection risk and the referendum decision",
  ncols = 5,
  zero_width = TRUE
)
indicator_10yr_panel_a_start <- grep(
  "^\\\\begin\\{tabular\\*\\}", indicator_10yr_panel_a_output
)
indicator_10yr_panel_a_end <- grep(
  "^\\\\end\\{tabular\\*\\}", indicator_10yr_panel_a_output
)
indicator_10yr_panel_b_start <- grep(
  "^\\\\begin\\{tabular\\*\\}", indicator_10yr_panel_b_output
)
indicator_10yr_panel_b_end <- grep(
  "^\\\\end\\{tabular\\*\\}", indicator_10yr_panel_b_output
)
indicator_10yr_final_output <- c(
  "\\begingroup",
  "\\centering",
  indicator_10yr_panel_a_output[
    indicator_10yr_panel_a_start:indicator_10yr_panel_a_end
  ],
  "\\medskip",
  indicator_10yr_panel_b_output[
    indicator_10yr_panel_b_start:indicator_10yr_panel_b_end
  ],
  "\\par\\endgroup"
)
writeLines(
  indicator_10yr_panel_a_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_50pct_10yr_final_panel_a.tex")
)
writeLines(
  indicator_10yr_panel_b_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_50pct_10yr_final_panel_b.tex")
)

# Response 2 reports the same annual models in a compact table that suppresses
# the displayed control coefficients. Generate it from the current-window
# models so the response cannot retain a stale annual sample.
indicator_10yr_no_news_annual_table <- etable(
  indicator_10yr_annual, indicator_10yr_go_issuance,
  indicator_10yr_any_issuance, indicator_10yr_revenue_issuance,
  coefstat = "tstat",
  keep_raw = "^failure_50pct_10yr$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    city_bond_election_year = "\\shortstack{Any City Bond\\\\ Election}",
    go_bond_issuance_year = "\\shortstack{Any City GO\\\\ Bond Issuance}",
    any_debt_issuance_year = "\\shortstack{Any City Debt\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Any City Revenue\\\\ Bond Issuance}",
    failure_50pct_10yr = "Prior ISD Failure",
    seed_issuer = "City", year = "Year"
  ),
  extralines = list("Controls" = c("Yes", "Yes", "Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_10yr_no_news_annual_output <- modify_etable_rounding(
  indicator_10yr_no_news_annual_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_10yr_no_news_annual_output <- format_table(
  indicator_10yr_no_news_annual_output,
  cluster_level = "County"
)
indicator_10yr_no_news_annual_output <- add_panel(
  indicator_10yr_no_news_annual_output,
  "Texas annual outcomes, no-news city panel: 10-year local rejection-risk indicator",
  ncols = 5,
  zero_width = TRUE
)
writeLines(
  indicator_10yr_no_news_annual_output,
  file.path(
    tbl_dir,
    "tx_rejection_risk_indicator_50pct_10yr_no_news_annual.tex"
  )
)

indicator_all_history_panel_a_table <- etable(
  indicator_all_history_website, indicator_all_history_media,
  coefstat = "tstat",
  keep_raw = "failure_50pct_all_history|election:failure_50pct_all_history|election_window:failure_50pct_all_history|^election$|^election_window$",
  order_raw = c(
    "^election$", "^election:failure_50pct_all_history$",
    "^election_window$", "^election_window:failure_50pct_all_history$",
    "^failure_50pct_all_history$"
  ),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    positive_delta_bond_debt1 = "\\shortstack{Increase in\\\\ Bond Text}",
    covered = "\\shortstack{Bond\\\\ Coverage}",
    failure_50pct_all_history = "Prior ISD Failure",
    `election:failure_50pct_all_history` = "Election Year $\\times$ Prior ISD Failure",
    election = "Election Year",
    election_window = "Election [0, +3]",
    `election_window:failure_50pct_all_history` = "Election [0, +3] $\\times$ Prior ISD Failure",
    seed_issuer = "City", year = "Year", year_month_id = "Year-Month"
  ),
  extralines = list("Controls" = c("Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_all_history_panel_a_output <- modify_etable_rounding(
  indicator_all_history_panel_a_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_all_history_panel_a_output <- format_table(
  indicator_all_history_panel_a_output,
  cluster_level = "County"
)
indicator_all_history_panel_a_controls <- grep(
  "^[[:space:]]*Controls[[:space:]]*&", indicator_all_history_panel_a_output
)
indicator_all_history_panel_a_control_line <- indicator_all_history_panel_a_output[
  indicator_all_history_panel_a_controls
]
indicator_all_history_panel_a_output <- indicator_all_history_panel_a_output[
  -indicator_all_history_panel_a_controls
]
indicator_all_history_panel_a_ar2 <- grep(
  "^[[:space:]]*Adj\\. R", indicator_all_history_panel_a_output
)
indicator_all_history_panel_a_output <- append(
  indicator_all_history_panel_a_output,
  indicator_all_history_panel_a_control_line,
  after = indicator_all_history_panel_a_ar2
)
indicator_all_history_panel_a_output <- add_panel(
  indicator_all_history_panel_a_output,
  "Panel A: Rejection risk and the information environment",
  ncols = 3,
  zero_width = TRUE
)

indicator_all_history_panel_b_table <- etable(
  indicator_all_history_annual, indicator_all_history_any_issuance,
  indicator_all_history_go_issuance, indicator_all_history_revenue_issuance,
  coefstat = "tstat",
  order_raw = c(
    "^failure_50pct_all_history$", "^ln_1p_outstanding_debt_lag1$",
    "^ln_county_gdp_prior$", "^ln_county_pop_prior$",
    "^ln_county_pers_inc_prior$"
  ),
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    city_bond_election_year = "\\shortstack{Bond\\\\ Election}",
    any_debt_issuance_year = "\\shortstack{Any Bond\\\\ Issuance}",
    go_bond_issuance_year = "\\shortstack{GO Bond\\\\ Issuance}",
    revenue_bond_issuance_year = "\\shortstack{Rev Bond\\\\ Issuance}",
    failure_50pct_all_history = "Prior ISD Failure",
    ln_1p_outstanding_debt_lag1 = "Outstanding Debt",
    ln_county_gdp_prior = "County ln(GDP)",
    ln_county_pop_prior = "County ln(Pop)",
    ln_county_pers_inc_prior = "County ln(Pers. Inc)",
    seed_issuer = "City", year = "Year"
  ),
  placement = "H",
  replace = TRUE
)
indicator_all_history_panel_b_output <- modify_etable_rounding(
  indicator_all_history_panel_b_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_all_history_panel_b_output <- format_table(
  indicator_all_history_panel_b_output,
  cluster_level = "County"
)
indicator_all_history_panel_b_output <- add_panel(
  indicator_all_history_panel_b_output,
  "Panel B: Rejection risk and the referendum decision",
  ncols = 5,
  zero_width = TRUE
)
indicator_all_history_panel_a_start <- grep(
  "^\\\\begin\\{tabular\\*\\}", indicator_all_history_panel_a_output
)
indicator_all_history_panel_a_end <- grep(
  "^\\\\end\\{tabular\\*\\}", indicator_all_history_panel_a_output
)
indicator_all_history_panel_b_start <- grep(
  "^\\\\begin\\{tabular\\*\\}", indicator_all_history_panel_b_output
)
indicator_all_history_panel_b_end <- grep(
  "^\\\\end\\{tabular\\*\\}", indicator_all_history_panel_b_output
)
indicator_all_history_final_output <- c(
  "\\begingroup",
  "\\centering",
  indicator_all_history_panel_a_output[
    indicator_all_history_panel_a_start:indicator_all_history_panel_a_end
  ],
  "\\medskip",
  indicator_all_history_panel_b_output[
    indicator_all_history_panel_b_start:indicator_all_history_panel_b_end
  ],
  "\\par\\endgroup"
)
writeLines(
  indicator_all_history_panel_a_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_50pct_all_history_final_panel_a.tex")
)
writeLines(
  indicator_all_history_panel_b_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_50pct_all_history_final_panel_b.tex")
)

# Private threshold-sensitivity summary. Each entry is the relevant primary
# coefficient followed by its county-clustered p-value in brackets.
robustness_cell <- function(model, coefficient_pattern) {
  coefficient_table <- coeftable(model)
  coefficient_row <- grep(coefficient_pattern, rownames(coefficient_table))
  if (length(coefficient_row) != 1L) {
    stop("Could not uniquely identify robustness coefficient: ", coefficient_pattern)
  }
  estimate <- coefficient_table[coefficient_row, "Estimate"]
  p_value <- coefficient_table[coefficient_row, "Pr(>|t|)"]
  stars <- if (p_value < 0.01) {
    "***"
  } else if (p_value < 0.05) {
    "**"
  } else if (p_value < 0.10) {
    "*"
  } else {
    ""
  }
  paste0(sprintf("%.3f", estimate), stars, " [", sprintf("%.3f", p_value), "]")
}

threshold_robustness <- data.table(
  `Minimum ISD Coverage` = c("Any overlap", "$\\geq$20\\%", "$\\geq$25\\%", "$\\geq$50\\%", "$\\geq$80\\%"),
  `Bond Text $\\times$ Risk` = c(
    robustness_cell(robust_any_website, "election.*failure_any_10yr|failure_any_10yr.*election"),
    robustness_cell(robust_20pct_website, "election.*failure_20pct_10yr|failure_20pct_10yr.*election"),
    robustness_cell(robust_25pct_website, "election.*failure_25pct_10yr|failure_25pct_10yr.*election"),
    robustness_cell(indicator_10yr_website, "election.*failure_50pct_10yr|failure_50pct_10yr.*election"),
    robustness_cell(robust_80pct_website, "election.*failure_80pct_10yr|failure_80pct_10yr.*election")
  ),
  `Bond Coverage $\\times$ Risk` = c(
    robustness_cell(robust_any_media, "election_window.*failure_any_10yr|failure_any_10yr.*election_window"),
    robustness_cell(robust_20pct_media, "election_window.*failure_20pct_10yr|failure_20pct_10yr.*election_window"),
    robustness_cell(robust_25pct_media, "election_window.*failure_25pct_10yr|failure_25pct_10yr.*election_window"),
    robustness_cell(indicator_10yr_media, "election_window.*failure_50pct_10yr|failure_50pct_10yr.*election_window"),
    robustness_cell(robust_80pct_media, "election_window.*failure_80pct_10yr|failure_80pct_10yr.*election_window")
  ),
  `Bond Election` = c(
    robustness_cell(robust_any_election, "^failure_any_10yr$"),
    robustness_cell(robust_20pct_election, "^failure_20pct_10yr$"),
    robustness_cell(robust_25pct_election, "^failure_25pct_10yr$"),
    robustness_cell(indicator_10yr_annual, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_election, "^failure_80pct_10yr$")
  ),
  `Any Bond Issuance` = c(
    robustness_cell(robust_any_issuance, "^failure_any_10yr$"),
    robustness_cell(robust_20pct_issuance, "^failure_20pct_10yr$"),
    robustness_cell(robust_25pct_issuance, "^failure_25pct_10yr$"),
    robustness_cell(indicator_10yr_any_issuance, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_issuance, "^failure_80pct_10yr$")
  ),
  `GO Bond Issuance` = c(
    robustness_cell(robust_any_go, "^failure_any_10yr$"),
    robustness_cell(robust_20pct_go, "^failure_20pct_10yr$"),
    robustness_cell(robust_25pct_go, "^failure_25pct_10yr$"),
    robustness_cell(indicator_10yr_go_issuance, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_go, "^failure_80pct_10yr$")
  ),
  `Revenue Bond Issuance` = c(
    robustness_cell(robust_any_revenue, "^failure_any_10yr$"),
    robustness_cell(robust_20pct_revenue, "^failure_20pct_10yr$"),
    robustness_cell(robust_25pct_revenue, "^failure_25pct_10yr$"),
    robustness_cell(indicator_10yr_revenue_issuance, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_revenue, "^failure_80pct_10yr$")
  )
)
threshold_robustness_lines <- c(
  "\\begingroup",
  "\\centering",
  "\\small",
  "\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lcccccc}",
  "\\multicolumn{7}{l}{\\makebox[0pt][l]{\\textbf{Robustness to the ISD city-area-overlap threshold}}}\\\\",
  "\\addlinespace",
  "\\toprule",
  "Minimum ISD Coverage & \\shortstack{Bond Text\\\\ $\\times$ Risk} & \\shortstack{Bond Coverage\\\\ $\\times$ Risk} & \\shortstack{Bond\\\\ Election} & \\shortstack{Any Bond\\\\ Issuance} & \\shortstack{GO Bond\\\\ Issuance} & \\shortstack{Revenue Bond\\\\ Issuance}\\\\",
  "\\midrule"
)
threshold_robustness_lines <- c(
  threshold_robustness_lines,
  apply(threshold_robustness, 1, function(row) paste0(paste(row, collapse = " & "), "\\\\")),
  "\\bottomrule",
  "\\end{tabular*}",
  "\\par\\smallskip\\footnotesize{Entries are coefficients; county-clustered p-values are in brackets. All measures use a prior-ten-year failure indicator.}",
  "\\par\\endgroup"
)
writeLines(
  threshold_robustness_lines,
  file.path(tbl_dir, "tx_rejection_risk_threshold_robustness.tex")
)

threshold_robustness_all_history <- data.table(
  `Minimum ISD Coverage` = c("Any overlap", "$\\geq$20\\%", "$\\geq$25\\%", "$\\geq$50\\%", "$\\geq$80\\%"),
  `Bond Text $\\times$ Risk` = c(
    robustness_cell(robust_all_history_any_website, "election.*failure_any_all_history|failure_any_all_history.*election"),
    robustness_cell(robust_all_history_20pct_website, "election.*failure_20pct_all_history|failure_20pct_all_history.*election"),
    robustness_cell(robust_all_history_25pct_website, "election.*failure_25pct_all_history|failure_25pct_all_history.*election"),
    robustness_cell(indicator_all_history_website, "election.*failure_50pct_all_history|failure_50pct_all_history.*election"),
    robustness_cell(robust_all_history_80pct_website, "election.*failure_80pct_all_history|failure_80pct_all_history.*election")
  ),
  `Bond Coverage $\\times$ Risk` = c(
    robustness_cell(robust_all_history_any_media, "election_window.*failure_any_all_history|failure_any_all_history.*election_window"),
    robustness_cell(robust_all_history_20pct_media, "election_window.*failure_20pct_all_history|failure_20pct_all_history.*election_window"),
    robustness_cell(robust_all_history_25pct_media, "election_window.*failure_25pct_all_history|failure_25pct_all_history.*election_window"),
    robustness_cell(indicator_all_history_media, "election_window.*failure_50pct_all_history|failure_50pct_all_history.*election_window"),
    robustness_cell(robust_all_history_80pct_media, "election_window.*failure_80pct_all_history|failure_80pct_all_history.*election_window")
  ),
  `Bond Election` = c(
    robustness_cell(robust_all_history_any_election, "^failure_any_all_history$"),
    robustness_cell(robust_all_history_20pct_election, "^failure_20pct_all_history$"),
    robustness_cell(robust_all_history_25pct_election, "^failure_25pct_all_history$"),
    robustness_cell(indicator_all_history_annual, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_election, "^failure_80pct_all_history$")
  ),
  `Any Bond Issuance` = c(
    robustness_cell(robust_all_history_any_issuance, "^failure_any_all_history$"),
    robustness_cell(robust_all_history_20pct_issuance, "^failure_20pct_all_history$"),
    robustness_cell(robust_all_history_25pct_issuance, "^failure_25pct_all_history$"),
    robustness_cell(indicator_all_history_any_issuance, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_issuance, "^failure_80pct_all_history$")
  ),
  `GO Bond Issuance` = c(
    robustness_cell(robust_all_history_any_go, "^failure_any_all_history$"),
    robustness_cell(robust_all_history_20pct_go, "^failure_20pct_all_history$"),
    robustness_cell(robust_all_history_25pct_go, "^failure_25pct_all_history$"),
    robustness_cell(indicator_all_history_go_issuance, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_go, "^failure_80pct_all_history$")
  ),
  `Revenue Bond Issuance` = c(
    robustness_cell(robust_all_history_any_revenue, "^failure_any_all_history$"),
    robustness_cell(robust_all_history_20pct_revenue, "^failure_20pct_all_history$"),
    robustness_cell(robust_all_history_25pct_revenue, "^failure_25pct_all_history$"),
    robustness_cell(indicator_all_history_revenue_issuance, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_revenue, "^failure_80pct_all_history$")
  )
)
threshold_robustness_all_history_lines <- c(
  "\\begingroup",
  "\\centering",
  "\\small",
  "\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lcccccc}",
  "\\multicolumn{7}{l}{\\makebox[0pt][l]{\\textbf{Robustness to the ISD city-area-overlap threshold: all prior elections}}}\\\\",
  "\\addlinespace",
  "\\toprule",
  "Minimum ISD Coverage & \\shortstack{Bond Text\\\\ $\\times$ Risk} & \\shortstack{Bond Coverage\\\\ $\\times$ Risk} & \\shortstack{Bond\\\\ Election} & \\shortstack{Any Bond\\\\ Issuance} & \\shortstack{GO Bond\\\\ Issuance} & \\shortstack{Revenue Bond\\\\ Issuance}\\\\",
  "\\midrule",
  apply(threshold_robustness_all_history, 1, function(row) paste0(paste(row, collapse = " & "), "\\\\")),
  "\\bottomrule",
  "\\end{tabular*}",
  "\\par\\smallskip\\footnotesize{Entries are coefficients; county-clustered p-values are in brackets. All measures use failures in any prior observed election.}",
  "\\par\\endgroup"
)
writeLines(
  threshold_robustness_all_history_lines,
  file.path(tbl_dir, "tx_rejection_risk_threshold_robustness_all_history.tex")
)

# Descriptives use the exact expanded annual-regression sample in Panel B.
annual_descriptive_sample <- annual_election[
  year > 2000 & !is.na(fips) & !is.na(ln_1p_outstanding_debt_lag1) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_descriptives <- data.table(
  Variable = c(
    "Prior ISD Failure", "Any City Bond Election", "Any Bond Issuance",
    "GO Bond Issuance", "Revenue Bond Issuance"
  ),
  Mean = c(
    mean(annual_descriptive_sample$failure_50pct_10yr),
    mean(annual_descriptive_sample$city_bond_election_year),
    mean(annual_descriptive_sample$any_debt_issuance_year),
    mean(annual_descriptive_sample$go_bond_issuance_year),
    mean(annual_descriptive_sample$revenue_bond_issuance_year)
  ),
  `Std. Dev.` = c(
    sd(annual_descriptive_sample$failure_50pct_10yr),
    sd(annual_descriptive_sample$city_bond_election_year),
    sd(annual_descriptive_sample$any_debt_issuance_year),
    sd(annual_descriptive_sample$go_bond_issuance_year),
    sd(annual_descriptive_sample$revenue_bond_issuance_year)
  ),
  N = nrow(annual_descriptive_sample)
)
annual_descriptive_lines <- c(
  "\\begingroup",
  "\\centering",
  "\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lrrr}",
  "\\multicolumn{4}{l}{\\makebox[0pt][l]{\\textbf{Descriptive statistics: no-news annual city-year panel}}}\\\\",
  "\\addlinespace",
  "\\toprule",
  "Variable & Mean & Std. Dev. & N\\\\",
  "\\midrule",
  paste0(
    annual_descriptives$Variable, " & ",
    sprintf("%.3f", annual_descriptives$Mean), " & ",
    sprintf("%.3f", annual_descriptives$`Std. Dev.`), " & ",
    format(annual_descriptives$N, big.mark = ","), "\\\\"
  ),
  "\\bottomrule",
  "\\end{tabular*}",
  "\\par\\endgroup"
)
writeLines(
  annual_descriptive_lines,
  file.path(tbl_dir, "tx_rejection_risk_annual_descriptives.tex")
)

# The debt-choice tables use the paper's full-period issuance aggregates:
# the dollar-weighted UTGO share and the issuer-level weighted-average spread.
full_issuance_indicator <- full_issuance_debt_choice[
  !is.na(frac_utgo) & !is.na(fips) & !is.na(ln_gdp) & !is.na(ln_pop) &
    !is.na(ln_pers_inc) & !is.na(ln_county_debt_other)
]
point_in_time_indicator <- debt_choice[
  mergent_go_revenue_bonds_outstanding >= 2L &
    !is.na(frac_utgo_outstanding) & !is.na(fips) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt)
]
indicator_10yr_utgo <- feols(
  frac_utgo ~ failure_50pct_10yr + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other,
  data = full_issuance_indicator,
  cluster = ~fips
)
indicator_10yr_yield_spread <- feols(
  issuer_spread ~ failure_50pct_10yr + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating + issuer_mat,
  data = full_issuance_indicator,
  cluster = ~fips
)
indicator_all_history_utgo <- feols(
  frac_utgo_outstanding ~ failure_50pct_all_history + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt,
  data = point_in_time_indicator,
  cluster = ~fips
)
indicator_all_history_yield_spread <- feols(
  mergent_wavg_yield_spread_go_revenue ~ failure_50pct_all_history +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue,
  data = point_in_time_indicator,
  cluster = ~fips
)

indicator_10yr_debt_table <- etable(
  indicator_10yr_utgo, indicator_10yr_yield_spread,
  coefstat = "tstat",
  keep_raw = "^failure_50pct_10yr$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    frac_utgo = "Pct UTGO",
    issuer_spread = "Wtd. Avg. Yield Spread",
    failure_50pct_10yr = "Prior ISD Failure"
  ),
  extralines = list("Controls" = c("Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_10yr_debt_output <- modify_etable_rounding(
  indicator_10yr_debt_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_10yr_debt_output <- format_table(
  indicator_10yr_debt_output,
  cluster_level = "County"
)
indicator_10yr_debt_output <- add_panel(
  indicator_10yr_debt_output,
  "Texas full-period issuance: failed ISD with at least 50% city-area overlap in the prior ten years",
  ncols = 3,
  zero_width = TRUE
)

indicator_all_history_debt_table <- etable(
  indicator_all_history_utgo, indicator_all_history_yield_spread,
  coefstat = "tstat",
  keep_raw = "^failure_50pct_all_history$",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    frac_utgo_outstanding = "Pct UTGO",
    mergent_wavg_yield_spread_go_revenue = "Wtd. Avg. Yield Spread",
    failure_50pct_all_history = "Prior ISD Failure"
  ),
  extralines = list("Controls" = c("Yes", "Yes")),
  placement = "H",
  replace = TRUE
)
indicator_all_history_debt_output <- modify_etable_rounding(
  indicator_all_history_debt_table,
  coef_digits = 3,
  tstat_digits = 2
)
indicator_all_history_debt_output <- format_table(
  indicator_all_history_debt_output,
  cluster_level = "County"
)
indicator_all_history_debt_output <- add_panel(
  indicator_all_history_debt_output,
  "Texas debt choice in 2017: failed ISD with at least 50% city-area overlap in all prior recorded years",
  ncols = 3,
  zero_width = TRUE
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
    sd(prior_weighted_failure_rate_60m)]

annual_weighted <- annual_news_election[
  !is.na(city_bond_election_year) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_60m) &
    !is.na(ln_1p_outstanding_debt_lag1) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m - mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)]

debt_choice_weighted <- debt_choice[
  mergent_go_revenue_bonds_outstanding >= 2L &
    !is.na(frac_rev_outstanding) & !is.na(fips) &
    !is.na(prior_weighted_failure_rate_60m) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt)
]
debt_choice_weighted[, weighted_risk_z :=
  (prior_weighted_failure_rate_60m -
    mean(prior_weighted_failure_rate_60m)) /
    sd(prior_weighted_failure_rate_60m)]

weighted_disclosure <- feols(
  positive_delta_bond_debt1 ~ election * weighted_risk_z + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_weighted[year < 2021],
  cluster = ~fips
)
annual_weighted[, had_election := max(city_bond_election_year), .(seed_issuer)]
weighted_annual_election <- feols(
  city_bond_election_year ~ weighted_risk_z + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_weighted[year > 2000],
  cluster = ~fips
)
weighted_substitution_utgo <- feols(
  frac_utgo_outstanding ~ weighted_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_weighted,
  cluster = ~fips
)

weighted_substitution_ltgo <- feols(
  frac_ltgo_outstanding ~ weighted_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_weighted,
  cluster = ~fips
)

weighted_substitution_rev <- feols(
  frac_rev_outstanding ~ weighted_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_weighted,
  cluster = ~fips
)

weighted_yield_spread <- feols(
  mergent_wavg_yield_spread_go_revenue ~ weighted_risk_z + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue,
  data = debt_choice_weighted,
  cluster = ~fips
)

weighted_table <- etable(
  weighted_disclosure, weighted_annual_election, weighted_substitution_utgo,
  weighted_substitution_ltgo, weighted_substitution_rev, weighted_yield_spread,
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
    positive_delta_bond_debt1 = "\\shortstack{Increase in\\\\ Bond Text}",
    city_bond_election_year = "\\shortstack{City Bond\\\\ Election}",
    frac_rev_outstanding = "Pct Revenue",
    frac_ltgo_outstanding = "Pct LTGO",
    frac_utgo_outstanding = "Pct UTGO",
    mergent_wavg_yield_spread_go_revenue = "\\shortstack{Wtd. Avg.\\\\ Yield Spread}",
    weighted_risk_z = "Local Rejection Risk",
    `election:weighted_risk_z` = "Election Year $\\times$ Local Rejection Risk",
    election = "Election Year",
    seed_issuer = "City",
    year = "Year",
    purpose_category = "Purpose"
  ),
  extralines = list(
    "__Controls" = c("Yes", "Yes", "Yes", "Yes", "Yes", "Yes")
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
  "Texas local rejection risk: overlap-weighted rejection risk",
  ncols = 7,
  zero_width = TRUE
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
    sd(prior_simple_failure_rate_20pct_60m)]

annual_simple <- annual_news_election[
  !is.na(city_bond_election_year) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_60m) &
    !is.na(ln_1p_outstanding_debt_lag1) &
    !is.na(ln_county_gdp_prior) & !is.na(ln_county_pop_prior) &
    !is.na(ln_county_pers_inc_prior)
]
annual_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)]

debt_choice_simple <- debt_choice[
  # insample == 1L & insample_allgo == 1L &
  # mergent_go_revenue_bonds_outstanding >= 2L &
  !is.na(frac_rev_outstanding) & !is.na(fips) &
    !is.na(prior_simple_failure_rate_20pct_60m) & !is.na(ln_gdp) &
    !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt)
]
debt_choice_simple[, simple_risk_z :=
  (prior_simple_failure_rate_20pct_60m - mean(prior_simple_failure_rate_20pct_60m)) /
    sd(prior_simple_failure_rate_20pct_60m)]

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
  data = annual_simple[year > 2000],
  cluster = ~fips
)
simple_substitution_utgo <- feols(
  frac_utgo_outstanding ~ simple_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_simple,
  cluster = ~fips
)

simple_substitution_ltgo <- feols(
  frac_ltgo_outstanding ~ simple_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_simple,
  cluster = ~fips
)

simple_substitution_rev <- feols(
  frac_rev_outstanding ~ simple_risk_z + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt,
  data = debt_choice_simple,
  cluster = ~fips
)

simple_yield_spread <- feols(
  mergent_wavg_yield_spread_go_revenue ~ simple_risk_z + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue,
  data = debt_choice_simple,
  cluster = ~fips
)


simple_table <- etable(
  simple_disclosure, simple_annual_election, simple_substitution_utgo,
  simple_substitution_ltgo, simple_substitution_rev, simple_yield_spread,
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
    positive_delta_bond_debt1 = "\\shortstack{Increase in\\\\ Bond Text}",
    city_bond_election_year = "\\shortstack{City Bond\\\\ Election}",
    frac_rev_outstanding = "Pct Revenue",
    frac_utgo_outstanding = "Pct UTGO",
    frac_ltgo_outstanding = "Pct LTGO",
    mergent_wavg_yield_spread_go_revenue = "\\shortstack{Wtd. Avg.\\\\ Yield Spread}",
    simple_risk_z = "Local Rejection Risk",
    `election:simple_risk_z` = "Election Year $\\times$ Local Rejection Risk",
    election = "Election Year",
    election = "Election Year",
    seed_issuer = "City",
    year = "Year",
    purpose_category = "Purpose"
  ),
  extralines = list(
    "__Controls" = c("Yes", "Yes", "Yes", "Yes", "Yes", "Yes")
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
  "Texas local rejection risk: simple failure rate among at least 20% overlapping ISDs",
  ncols = 7,
  zero_width = TRUE
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
    failed = "Failed",
    vote_margin_signed = "Signed Margin",
    weighted_risk_z = "Local Rejection Risk"
  ),
  extralines = list(
    "__Controls" = c("Yes", "Yes")
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
    failed = "Failed",
    vote_margin_signed = "Signed Margin",
    simple_risk_z = "Local Rejection Risk"
  ),
  extralines = list(
    "__Controls" = c("Yes", "Yes")
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
