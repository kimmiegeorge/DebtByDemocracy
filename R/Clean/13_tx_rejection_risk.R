# 13: Texas local rejection-risk mechanism tests
#
# Main specification: a prior ISD failure with at least two-thirds city-area
# overlap during the preceding ten years. Robustness checks vary the overlap
# threshold and replace the ten-year window with all prior observed elections.

rm(list = ls())

library(pacman)
p_load(data.table, fixest)

source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R")
source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_helper_functions.R")

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
analysis_data_dir <- Sys.getenv(
  "TX_REJECTION_RISK_DATA_DIR",
  unset = file.path(root, "Data/Clean_Intermediate/TX/Rejection_Risk")
)
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = file.path(root, "Code/R/Clean/output/revision_tables")
)
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

# ==============================================================================
# 1. LOAD THE THREE ANALYSIS PANELS
# ==============================================================================

# Python/Clean/TX_Rejection_Risk/01_prepare_tx_rejection_risk.py constructs
# these files and applies the common 2001--2020 analysis window.
website_city_year <- fread(
  file.path(analysis_data_dir, "website_city_year_analysis.csv")
)
annual_election <- fread(
  file.path(analysis_data_dir, "annual_election_analysis.csv")
)
media_panel_indicator <- fread(
  file.path(analysis_data_dir, "media_panel_indicator_analysis.csv")
)

# Enforce the common window again so stale prepared files cannot change a sample.
analysis_start_year <- 2001L
analysis_end_year <- 2020L
website_city_year <- website_city_year[
  year >= analysis_start_year & year <= analysis_end_year
]
annual_election <- annual_election[
  year >= analysis_start_year & year <= analysis_end_year
]
media_panel_indicator <- media_panel_indicator[
  year >= analysis_start_year & year <= analysis_end_year
]
annual_main_sample <- tx_annual_main_sample(
  annual_election,
  analysis_start_year,
  analysis_end_year
)

# ==============================================================================
# 2. OUTPUT DESCRIPTIVE STATISTICS
# ==============================================================================

# Descriptives use the exact expanded annual-regression sample in Panel B.
annual_descriptive_sample <- annual_main_sample
annual_descriptives <- data.table(
  Variable = c(
    "Election Year", "Bond Issuance Year", "GO Bond Issuance Year",
    "Revenue Bond Issuance Year", "Prior ISD Failure"
  ),
  Mean = c(
    mean(annual_descriptive_sample$city_bond_election_year),
    mean(annual_descriptive_sample$any_debt_issuance_year),
    mean(annual_descriptive_sample$go_bond_issuance_year),
    mean(annual_descriptive_sample$revenue_bond_issuance_year),
    mean(annual_descriptive_sample$failure_twothirds_10yr)
  ),
  `Std. Dev.` = c(
    sd(annual_descriptive_sample$city_bond_election_year),
    sd(annual_descriptive_sample$any_debt_issuance_year),
    sd(annual_descriptive_sample$go_bond_issuance_year),
    sd(annual_descriptive_sample$revenue_bond_issuance_year),
    sd(annual_descriptive_sample$failure_twothirds_10yr)
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

# ==============================================================================
# 3. RUN AND OUTPUT THE MAIN TWO-THIRDS, TEN-YEAR SPECIFICATION
# ==============================================================================

indicator_10yr_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_twothirds_10yr + issuance_year +
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
  covered ~ election_window * failure_twothirds_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
indicator_10yr_annual <- feols(
  city_bond_election_year ~ failure_twothirds_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)
indicator_10yr_go_issuance <- feols(
  go_bond_issuance_year ~ failure_twothirds_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)
indicator_10yr_any_issuance <- feols(
  any_debt_issuance_year ~ failure_twothirds_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)
indicator_10yr_revenue_issuance <- feols(
  revenue_bond_issuance_year ~ failure_twothirds_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)

# Final presentation tables: Panel A contains the information-environment
# outcomes; Panel B contains the referendum and issuance decisions on the
# expanded no-news annual city panel. The annual controls are shown explicitly
# in Panel B, while Panel A reports their inclusion below fit statistics.
indicator_10yr_panel_a_table <- etable(
  indicator_10yr_website, indicator_10yr_media,
  coefstat = "tstat",
  keep_raw = "failure_twothirds_10yr|election:failure_twothirds_10yr|election_window:failure_twothirds_10yr|^election$|^election_window$",
  order_raw = c(
    "^election$", "^election:failure_twothirds_10yr$",
    "^election_window$", "^election_window:failure_twothirds_10yr$",
    "^failure_twothirds_10yr$"
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
    failure_twothirds_10yr = "Prior ISD Failure",
    `election:failure_twothirds_10yr` = "Election Year $\\times$ Prior ISD Failure",
    election = "Election Year",
    election_window = "Election [0, +3]",
    `election_window:failure_twothirds_10yr` = "Election [0, +3] $\\times$ Prior ISD Failure",
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
    "^failure_twothirds_10yr$", "^ln_1p_outstanding_debt_lag1$",
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
    city_bond_election_year = "\\shortstack{Election\\\\ Year}",
    any_debt_issuance_year = "\\shortstack{Bond Issuance\\\\ Year}",
    go_bond_issuance_year = "\\shortstack{GO Bond\\\\ Issuance Year}",
    revenue_bond_issuance_year = "\\shortstack{Revenue Bond\\\\ Issuance Year}",
    failure_twothirds_10yr = "Prior ISD Failure",
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
writeLines(
  indicator_10yr_panel_a_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_twothirds_10yr_final_panel_a.tex")
)
writeLines(
  indicator_10yr_panel_b_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_twothirds_10yr_final_panel_b.tex")
)

# Response 2 reports the same annual models in a compact table that suppresses
# the displayed control coefficients. Generate it from the current-window
# models so the response cannot retain a stale annual sample.
indicator_10yr_no_news_annual_table <- etable(
  indicator_10yr_annual, indicator_10yr_go_issuance,
  indicator_10yr_any_issuance, indicator_10yr_revenue_issuance,
  coefstat = "tstat",
  keep_raw = "^failure_twothirds_10yr$",
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
    failure_twothirds_10yr = "Prior ISD Failure",
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
    "tx_rejection_risk_indicator_twothirds_10yr_no_news_annual.tex"
  )
)

# ==============================================================================
# 4. ROBUSTNESS TO ALTERNATIVE OVERLAP THRESHOLDS
# ==============================================================================

# Report 50- and 80-percent alternatives to the main two-thirds threshold.
# Reuse fixed estimation samples so threshold changes alone drive comparisons.
website_robustness_sample <- website_city_year[
  !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
    !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
    !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
]
annual_robustness_sample <- annual_main_sample

robust_50pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_50pct_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
  cluster = ~fips
)
robust_50pct_media <- feols(
  covered ~ election_window * failure_50pct_10yr + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_50pct_election <- feols(
  city_bond_election_year ~ failure_50pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_50pct_issuance <- feols(
  any_debt_issuance_year ~ failure_50pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_50pct_go <- feols(
  go_bond_issuance_year ~ failure_50pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_50pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_50pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)

robust_80pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_80pct_10yr + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
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
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_80pct_issuance <- feols(
  any_debt_issuance_year ~ failure_80pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_80pct_go <- feols(
  go_bond_issuance_year ~ failure_80pct_10yr + ln_1p_outstanding_debt_lag1 +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_80pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_80pct_10yr +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
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
  `Minimum ISD Coverage` = c("$\\geq$50\\%", "$\\geq$80\\%"),
  `Bond Text $\\times$ Risk` = c(
    robustness_cell(robust_50pct_website, "election.*failure_50pct_10yr|failure_50pct_10yr.*election"),
    robustness_cell(robust_80pct_website, "election.*failure_80pct_10yr|failure_80pct_10yr.*election")
  ),
  `Bond Coverage $\\times$ Risk` = c(
    robustness_cell(robust_50pct_media, "election_window.*failure_50pct_10yr|failure_50pct_10yr.*election_window"),
    robustness_cell(robust_80pct_media, "election_window.*failure_80pct_10yr|failure_80pct_10yr.*election_window")
  ),
  `Bond Election` = c(
    robustness_cell(robust_50pct_election, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_election, "^failure_80pct_10yr$")
  ),
  `Any Bond Issuance` = c(
    robustness_cell(robust_50pct_issuance, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_issuance, "^failure_80pct_10yr$")
  ),
  `GO Bond Issuance` = c(
    robustness_cell(robust_50pct_go, "^failure_50pct_10yr$"),
    robustness_cell(robust_80pct_go, "^failure_80pct_10yr$")
  ),
  `Revenue Bond Issuance` = c(
    robustness_cell(robust_50pct_revenue, "^failure_50pct_10yr$"),
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
  "\\par\\smallskip\\footnotesize{Entries are coefficients; county-clustered p-values are in brackets. Rows report 50- and 80-percent alternatives to the main two-thirds city-area-overlap threshold. All measures use a prior-ten-year failure indicator.}",
  "\\par\\endgroup"
)
writeLines(
  threshold_robustness_lines,
  file.path(tbl_dir, "tx_rejection_risk_threshold_robustness.tex")
)

# ==============================================================================
# 5. ROBUSTNESS TO USING ALL PRIOR OBSERVED ELECTIONS
# ==============================================================================

# First rerun the main two-thirds specifications using all prior history.
indicator_all_history_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_twothirds_all_history +
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
  covered ~ election_window * failure_twothirds_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
indicator_all_history_annual <- feols(
  city_bond_election_year ~ failure_twothirds_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)
indicator_all_history_go_issuance <- feols(
  go_bond_issuance_year ~ failure_twothirds_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)
indicator_all_history_any_issuance <- feols(
  any_debt_issuance_year ~ failure_twothirds_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)
indicator_all_history_revenue_issuance <- feols(
  revenue_bond_issuance_year ~ failure_twothirds_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = annual_main_sample,
  cluster = ~fips
)

# Output the all-history versions of Panels A and B.
indicator_all_history_panel_a_table <- etable(
  indicator_all_history_website, indicator_all_history_media,
  coefstat = "tstat",
  keep_raw = "failure_twothirds_all_history|election:failure_twothirds_all_history|election_window:failure_twothirds_all_history|^election$|^election_window$",
  order_raw = c(
    "^election$", "^election:failure_twothirds_all_history$",
    "^election_window$", "^election_window:failure_twothirds_all_history$",
    "^failure_twothirds_all_history$"
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
    failure_twothirds_all_history = "Prior ISD Failure",
    `election:failure_twothirds_all_history` = "Election Year $\\times$ Prior ISD Failure",
    election = "Election Year",
    election_window = "Election [0, +3]",
    `election_window:failure_twothirds_all_history` = "Election [0, +3] $\\times$ Prior ISD Failure",
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
    "^failure_twothirds_all_history$", "^ln_1p_outstanding_debt_lag1$",
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
    failure_twothirds_all_history = "Prior ISD Failure",
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
writeLines(
  indicator_all_history_panel_a_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_twothirds_all_history_final_panel_a.tex")
)
writeLines(
  indicator_all_history_panel_b_output,
  file.path(tbl_dir, "tx_rejection_risk_indicator_twothirds_all_history_final_panel_b.tex")
)

# Retain the parallel all-history robustness output on the same annual sample.
indicator_all_history_no_news_annual_table <- etable(
  indicator_all_history_annual, indicator_all_history_go_issuance,
  indicator_all_history_any_issuance, indicator_all_history_revenue_issuance,
  coefstat = "tstat",
  keep_raw = "^failure_twothirds_all_history$",
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
    failure_twothirds_all_history = "Prior ISD Failure",
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
writeLines(
  indicator_all_history_no_news_annual_output,
  file.path(
    tbl_dir,
    "tx_rejection_risk_indicator_twothirds_all_history_no_news_annual.tex"
  )
)

# Then vary the overlap threshold within the all-history definition.
# All-history counterparts for the private threshold-sensitivity table.
website_robustness_sample <- website_city_year[
  !is.na(positive_delta_bond_debt1) & !is.na(election) & !is.na(fips) &
    !is.na(issuance_year) & !is.na(ln_county_gdp_prior) &
    !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
]
annual_robustness_sample <- annual_main_sample
robust_all_history_50pct_website <- feols(
  positive_delta_bond_debt1 ~ election * failure_50pct_all_history + issuance_year +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year,
  data = website_robustness_sample,
  cluster = ~fips
)
robust_all_history_50pct_media <- feols(
  covered ~ election_window * failure_50pct_all_history + issuance_window +
    ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior |
    seed_issuer + year_month_id,
  data = media_panel_indicator,
  cluster = ~fips
)
robust_all_history_50pct_election <- feols(
  city_bond_election_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_50pct_issuance <- feols(
  any_debt_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_50pct_go <- feols(
  go_bond_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
  data = annual_robustness_sample,
  cluster = ~fips
)
robust_all_history_50pct_revenue <- feols(
  revenue_bond_issuance_year ~ failure_50pct_all_history +
    ln_1p_outstanding_debt_lag1 + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
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

threshold_robustness_all_history <- data.table(
  `Minimum ISD Coverage` = c("$\\geq$50\\%", "$\\geq$80\\%"),
  `Bond Text $\\times$ Risk` = c(
    robustness_cell(robust_all_history_50pct_website, "election.*failure_50pct_all_history|failure_50pct_all_history.*election"),
    robustness_cell(robust_all_history_80pct_website, "election.*failure_80pct_all_history|failure_80pct_all_history.*election")
  ),
  `Bond Coverage $\\times$ Risk` = c(
    robustness_cell(robust_all_history_50pct_media, "election_window.*failure_50pct_all_history|failure_50pct_all_history.*election_window"),
    robustness_cell(robust_all_history_80pct_media, "election_window.*failure_80pct_all_history|failure_80pct_all_history.*election_window")
  ),
  `Bond Election` = c(
    robustness_cell(robust_all_history_50pct_election, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_election, "^failure_80pct_all_history$")
  ),
  `Any Bond Issuance` = c(
    robustness_cell(robust_all_history_50pct_issuance, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_issuance, "^failure_80pct_all_history$")
  ),
  `GO Bond Issuance` = c(
    robustness_cell(robust_all_history_50pct_go, "^failure_50pct_all_history$"),
    robustness_cell(robust_all_history_80pct_go, "^failure_80pct_all_history$")
  ),
  `Revenue Bond Issuance` = c(
    robustness_cell(robust_all_history_50pct_revenue, "^failure_50pct_all_history$"),
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
  "\\par\\smallskip\\footnotesize{Entries are coefficients; county-clustered p-values are in brackets. Rows report 50- and 80-percent alternatives to the main two-thirds city-area-overlap threshold. All measures use failures in any prior observed election.}",
  "\\par\\endgroup"
)
writeLines(
  threshold_robustness_all_history_lines,
  file.path(tbl_dir, "tx_rejection_risk_threshold_robustness_all_history.tex")
)
