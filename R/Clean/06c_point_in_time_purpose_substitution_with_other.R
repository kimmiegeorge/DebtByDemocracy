# Set up ----

# 06c: Point-in-time purpose substitution including Other public debt
# The canonical input is built from the v2020 all-public-debt Mergent file by
# Python/Clean/Purposes_Substitution/04_build_point_in_time_purpose_panel_with_other.py.
rm(list = ls())

library(pacman)
p_load(data.table, fixest)

source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R")
source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_tax_privilege_definitions.R")

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
panel_dir <- Sys.getenv(
  "PURPOSE_WITH_OTHER_DIR",
  unset = file.path(
    root,
    "Data/DPC Data/Use Of Proceeds/Purposes Substitution/with_other"
  )
)
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = file.path(root, "Code/R/Clean/output/revision_tables")
)
tbl_dir_other <- file.path(tbl_dir, "with_other")
dir.create(tbl_dir_other, showWarnings = FALSE, recursive = TRUE)
processed_dir <- Sys.getenv(
  "PROCESSED_RESULTS_DIR",
  unset = file.path(root, "Code/R/Clean/output/processed")
)
dir.create(processed_dir, showWarnings = FALSE, recursive = TRUE)

# Purpose categories and table labels ----

reported_categories <- c(
  "utilities",
  "transportation",
  "recreation_amenities",
  "public_safety",
  "other_public_buildings"
)

reported_category_headers <- c(
  "Utilities",
  "Transport.",
  "Recreation",
  "Public Safety",
  "Public Bldg."
)

control_dict <- c(
  city_go_vote = "Vote",
  ln_gdp = "County ln(GDP)",
  ln_census_population = "City ln(Pop)",
  ln_pers_inc = "County ln(Pers. Inc)",
  ln_1p_county_nonmunicipal_total_debt = "County Non-City Debt",
  glm_proactive = "Proactive State",
  state_ltgo_allowed = "LTGO Allowed",
  state_go_vote = "State GO Vote",
  low_state_tax_privilege = "Low Tax Priv.",
  strict_municipal_debt_limit = "Strict Municipal Debt Limit",
  category_amount_mil = "Par of Outstanding Bonds (millions)",
  share_revenue_of_all_public_amount = "Fraction Revenue",
  share_other_of_all_public_amount = "Fraction Other",
  share_revenue_other_of_all_public_amount = "Pct Revenue/Other"
)

# 2017 point-in-time purpose substitution with Other ----

purpose_2017 <- fread(file.path(
  panel_dir,
  "261013_dpc_point_in_time_purpose_substitution_2017_issuer_category_panel_with_other.csv"
))

add_low_state_tax_privilege(purpose_2017, year_value = 2017)
purpose_2017[, fips := as.character(fips)]

purpose_2017 <- purpose_2017[
  !is.na(city_go_vote) &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) &
    mergent_total_bonds_outstanding >= 2
]

purpose_2017_full <- purpose_2017[insample == 1]
purpose_2017_full[, `:=`(
  category_amount_mil = all_public_category_amount / 1000000,
  share_revenue_other_of_all_public_amount = fifelse(
    all_public_category_amount > 0,
    (revenue_category_amount + other_category_amount) /
      all_public_category_amount,
    NA_real_
  )
)]

# Panel A: 2017 all-public-debt par amount by purpose ----

ppml_amount_other_2017_utilities <- fepois(
  category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "utilities"],
  vcov = vcov_cluster(~state)
)

ppml_amount_other_2017_transportation <- fepois(
  category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "transportation"],
  vcov = vcov_cluster(~state)
)

ppml_amount_other_2017_recreation <- fepois(
  category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "recreation_amenities"],
  vcov = vcov_cluster(~state)
)

ppml_amount_other_2017_public_safety <- fepois(
  category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "public_safety"],
  vcov = vcov_cluster(~state)
)

ppml_amount_other_2017_public_buildings <- fepois(
  category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "other_public_buildings"],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  ppml_amount_other_2017_utilities,
  ppml_amount_other_2017_transportation,
  ppml_amount_other_2017_recreation,
  ppml_amount_other_2017_public_safety,
  ppml_amount_other_2017_public_buildings,
  headers = reported_category_headers,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "pr2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  order = c("%city_go_vote"),
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(
  modified_output,
  "Panel A: Par amount outstanding by purpose (incl. Other)",
  ncols = 6
)
modified_output <- trimws(modified_output, which = "right")
writeLines(
  modified_output,
  file.path(
    tbl_dir_other,
    "point_in_time_purpose_category_amount_ppml_2017_full_sample_with_other.tex"
  )
)

# Panel B: 2017 Revenue fraction of GO + Revenue + Other by purpose ----

r_revenue_other_2017_utilities <- feols(
  share_revenue_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "utilities"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_2017_transportation <- feols(
  share_revenue_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "transportation"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_2017_recreation <- feols(
  share_revenue_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "recreation_amenities"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_2017_public_safety <- feols(
  share_revenue_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "public_safety"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_2017_public_buildings <- feols(
  share_revenue_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "other_public_buildings"],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_revenue_other_2017_utilities,
  r_revenue_other_2017_transportation,
  r_revenue_other_2017_recreation,
  r_revenue_other_2017_public_safety,
  r_revenue_other_2017_public_buildings,
  headers = reported_category_headers,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  order = c("%city_go_vote"),
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(
  modified_output,
  "Panel B: Fraction Revenue by purpose (denominator incl. Other)",
  ncols = 6
)
modified_output <- trimws(modified_output, which = "right")
writeLines(
  modified_output,
  file.path(
    tbl_dir_other,
    "point_in_time_purpose_revenue_share_2017_full_sample_with_other.tex"
  )
)

# Panel C: 2017 Other fraction of GO + Revenue + Other by purpose ----

r_other_2017_utilities <- feols(
  share_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "utilities"],
  vcov = vcov_cluster(~state)
)

r_other_2017_transportation <- feols(
  share_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "transportation"],
  vcov = vcov_cluster(~state)
)

r_other_2017_recreation <- feols(
  share_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "recreation_amenities"],
  vcov = vcov_cluster(~state)
)

r_other_2017_public_safety <- feols(
  share_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "public_safety"],
  vcov = vcov_cluster(~state)
)

r_other_2017_public_buildings <- feols(
  share_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "other_public_buildings"],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_other_2017_utilities,
  r_other_2017_transportation,
  r_other_2017_recreation,
  r_other_2017_public_safety,
  r_other_2017_public_buildings,
  headers = reported_category_headers,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  order = c("%city_go_vote"),
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(
  modified_output,
  "Panel C: Fraction Other by purpose",
  ncols = 6
)
modified_output <- trimws(modified_output, which = "right")
writeLines(
  modified_output,
  file.path(
    tbl_dir_other,
    "point_in_time_purpose_other_share_2017_full_sample_with_other.tex"
  )
)

# Panel D: 2017 Revenue/Other fraction by purpose ----

r_revenue_other_combined_2017_utilities <- feols(
  share_revenue_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "utilities"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_combined_2017_transportation <- feols(
  share_revenue_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "transportation"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_combined_2017_recreation <- feols(
  share_revenue_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "recreation_amenities"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_combined_2017_public_safety <- feols(
  share_revenue_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "public_safety"],
  vcov = vcov_cluster(~state)
)

r_revenue_other_combined_2017_public_buildings <- feols(
  share_revenue_other_of_all_public_amount ~ city_go_vote + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = purpose_2017_full[purpose_category == "other_public_buildings"],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_revenue_other_combined_2017_utilities,
  r_revenue_other_combined_2017_transportation,
  r_revenue_other_combined_2017_recreation,
  r_revenue_other_combined_2017_public_safety,
  r_revenue_other_combined_2017_public_buildings,
  headers = reported_category_headers,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  keep_raw = "^city_go_vote$",
  order = c("%city_go_vote"),
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
outcome_header_idx <- grep(
  "^[[:space:]]*& Pct Revenue/Other",
  modified_output,
  fixed = FALSE
)
if (length(outcome_header_idx) > 0) {
  modified_output[outcome_header_idx[1]] <-
    " & \\multicolumn{5}{c}{Pct Revenue/Other}\\\\"
}
modified_output <- format_table(modified_output, cluster_level = "State")
r2_idx <- grep("R\\$\\^2\\$", modified_output)
stopifnot(length(r2_idx) == 1L)
modified_output <- append(
  modified_output,
  "   Controls                   & Yes & Yes & Yes & Yes & Yes\\\\",
  after = r2_idx
)
modified_output <- add_panel(
  modified_output,
  "Panel D: Pct Revenue/Other by purpose",
  ncols = 6
)
modified_output <- trimws(modified_output, which = "right")
writeLines(
  modified_output,
  file.path(tbl_dir_other, "panel_d_other_pct_revenue_other_purpose.tex")
)

# Assemble the five appendix fragments in the same outcome order as Table A2.
writeLines(c(
  "\\newpage",
  "\\begin{table}[H]\\centering",
  "\\caption{\\textbf{Robustness to Including Other Public Debt}}",
  "\\label{tab:with_other_robustness}",
  paste0(
    "\\parbox{\\textwidth}{This table reports the 2017 point-in-time ",
    "robustness analysis after expanding Mergent debt to include COO, COP, ",
    "and residual Other debt. Panel A reports outstanding Census debt and ",
    "all Mergent public debt. Panels B and C report the shares of UTGO, LTGO, ",
    "and combined Revenue/Other debt under the two city referendum regimes. ",
    "Panel D reports the combined Revenue/Other share within each project ",
    "purpose. Panel E reports the aggregate weighted-average yield spread ",
    "without and with controls. Controls are suppressed. Standard ",
    "errors are clustered by state. z- or t-statistics are reported in ",
    "parentheses. *, **, and *** indicate statistical significance at the ",
    "10\\%, 5\\%, and 1\\% levels.}"
  ),
  "\\end{table}",
  "\\input{tables/clean/raw/with_other/panel_a_other_outstanding_debt}",
  "\\vspace{10pt}",
  "\\input{tables/clean/raw/with_other/panel_b_other_debt_choice_allgo}",
  "\\vspace{10pt}",
  "\\input{tables/clean/raw/with_other/panel_c_other_debt_choice_utgo_only}",
  "\\vspace{10pt}",
  "\\input{tables/clean/raw/with_other/panel_d_other_pct_revenue_other_purpose}",
  "\\vspace{10pt}",
  "\\input{tables/clean/raw/with_other/panel_e_other_yield_spread}"
), file.path(processed_dir, "with_other_robustness.tex"))
