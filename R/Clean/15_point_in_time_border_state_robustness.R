# Set up ----

# 15: Point-in-time border-state robustness specifications
rm(list = ls())

library(pacman)
p_load(data.table, fixest)

source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R")
source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_tax_privilege_definitions.R")
source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_border_pair_definitions.R")

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"
)
processed_dir <- "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/processed"
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

border_2017 <- fread(
  file.path(
    root,
    "Data/Clean_Intermediate/Census COG Finance/processed/no_refundings",
    "census_mergent_debt_cross_section_2017_border_sample.csv"
  )
)

border_2017[, fips := as.character(fips)]
add_low_state_tax_privilege(border_2017, year_value = 2017)

border_2017[, ln_census_population := log(census_population)]
border_2017[, state_year := interaction(state, year, drop = TRUE)]

border_2017 <- filter_debt_yield_border_pairs(border_2017, "border_group")

border_2017 <- border_2017[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

# Match the full-sample eligibility rule. Every configured debt/yield border
# pair has within-pair variation in the city vote requirement after this screen.
border_2017 <- border_2017[
  insample == 1 &
    !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]


border_utgo_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + state_ltgo_allowed + glm_proactive + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

border_yield_2017 <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated + mergent_wavg_original_maturity_years_go_revenue +
    mergent_wavg_insured_go_revenue + mergent_wavg_sinkable_go_revenue + state_go_vote + low_state_tax_privilege |
    border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

control_dict <- c(
  frac_utgo_outstanding = "Pct UTGO",
  mergent_wavg_yield_spread_go_revenue = "Wtd. Avg. Yield Spread",
  ln_1p_county_nonmunicipal_total_debt = "County Non-City Debt",
  mergent_wavg_original_maturity_years_go_revenue = "Wtd. Avg. Original Maturity",
  mergent_wavg_rating_go_revenue_zero_unrated = "Wtd. Avg. Rating",
  mergent_wavg_insured_go_revenue = "Wtd. Avg. Insured",
  mergent_wavg_sinkable_go_revenue = "Wtd. Avg. Sinkable",
  state_go_vote = "State GO Vote",
  low_state_tax_privilege = "Low Tax Priv.",
  strict_municipal_debt_limit = "Strict Municipal Debt Limit",
  ln_gdp = "County ln(GDP)",
  ln_census_population = "City ln(Pop)",
  ln_pers_inc = "County ln(Pers. Inc)",
  border_group = "State-Border",
  city_go_vote = "Vote"
)

table_call <- etable(
  border_utgo_2017, border_yield_2017,
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
  order = "%city_go_vote",
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State-Year")
adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    "   Controls                   & Yes            & Yes\\\\",
    after = adj_r2_idx[1]
  )
}
modified_output <- add_panel(modified_output, "Panel A: Border-city sample", ncols = 3)
writeLines(
  modified_output,
  file.path(tbl_dir, "point_in_time_robustness_border_state.tex")
)

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  "\\newpage",
  "\\begin{table}[H]\\centering",
  "\\caption{\\textbf{Point-in-Time Robustness: Border-City and Supermajority Specifications}}",
  "\\label{tab:point_in_time_robustness}",
  paste0(
    "\\parbox{\\textwidth}{This table reports 2017 point-in-time cross-sectional estimates. ",
    "Panel A applies the full-sample eligibility rule, restricts the sample to cities near state borders, ",
    "retains only state-border pairs containing both vote and non-vote cities, and includes state-border fixed effects. ",
    "Panel B adds the supermajority-state indicator to the full-sample specification. ",
    "Both panels use the strict outcome-specific controls from the main debt-choice and aggregate-yield tables. ",
    "Controls are suppressed. Standard errors are clustered by state-year in Panel A and by state in Panel B.}"
  ),
  "\\end{table}",
  "\\input{tables/clean/raw/point_in_time_robustness_border_state}",
  "\\vspace{10pt}",
  "\\input{tables/clean/raw/point_in_time_robustness_super_majority}"
), file.path(processed_dir, "point_in_time_robustness.tex"))
