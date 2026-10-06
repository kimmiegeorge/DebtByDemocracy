# 01b: City-year GFOA award results

rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, fixest)
tables_wd <- Sys.getenv(
  "RESULTS_DIR",
  unset = "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"
)
dir.create(tables_wd, recursive = TRUE, showWarnings = FALSE)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R')
tbl_dir <- tables_wd

#---------------------------------------
# Python prepares the award panel, sample restrictions, merged controls, and
# source-missing indicators. COA FY2019 nonmatches are zero.
data <- fread(Sys.getenv(
  "GFOA_REGRESSION_DATA",
  unset = "~/Dropbox/Voting on Bonds/Data/GFOA Awards/analysis/city_year_pafr/city_year_gfoa_awards_regression_data.csv"
))
data[, fiscal_year := as.factor(fiscal_year)]

#---------------------------------
# regs: preserve the four existing specifications and state clustering
#---------------------------------

# City GO-vote requirement with GAAP and audit controls and fiscal-year FE.
r1 <- fixest::feols(
  coa_award ~ city_go_vote + gasb_municipal_gaap_required_any +
    nasact_audits_cities_towns_villages +
    nasact_audits_cities_towns_villages_source_missing | fiscal_year,
  data = data,
  cluster = ~state,
  notes = FALSE
)

# Add lagged county characteristics to the GAAP and audit controls.
r2 <- fixest::feols(
  coa_award ~ city_go_vote  + ln_county_gdp_l1 +
    ln_county_percap_inc_l1 + ln_county_pop_l1 +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    nasact_audits_cities_towns_villages_source_missing | fiscal_year,
  data = data,
  cluster = ~state,
  notes = FALSE
)

# Add current-year issuance and adoption-based fiscal monitoring.
r3 <- fixest::feols(
  coa_award ~ city_go_vote + bond_issued_current_year + ln_county_gdp_l1 +
    ln_county_percap_inc_l1 + ln_county_pop_l1 +
    gasb_municipal_gaap_required_any + state_monitor + nasact_audits_cities_towns_villages | fiscal_year,
  data = data,
  cluster = ~state,
  notes = FALSE
)

# All supermajority states have city_go_vote = 1 in this panel, so the
# identified supermajority comparison is estimated within GO-vote states.
r4 <- fixest::feols(
  pafr_award ~ supermajority + city_rev_vote + state_go_vote +
    state_utgo_allowed + glm_proactive + low_state_tax_privilege +
    municipal_debt_limit + municipal_debt_limit_source_missing +
    lincoln_property_tax_rate_cap_2024 + municipal_tel_index +
    state_monitor + gasb_municipal_gaap_required_any +
    nasact_audits_cities_towns_villages +
    nasact_audits_cities_towns_villages_source_missing +
    ln_county_employment_l1 + ln_county_gdp_l1 +
    ln_county_percap_inc_l1 + ln_county_pop_l1 | fiscal_year,
  data = data[city_go_vote == 1L],
  cluster = ~state,
  notes = FALSE
)

#---------------------------------
# Output regression tables using the website etable conventions
#---------------------------------

table_call <- etable(r1, r2, r3, r4,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
       fitstat = c('n', 'ar2'),
       se.below = TRUE,
       digits = 3,
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10),
       tex = TRUE,
       dict = c(coa_award = 'COA Award',
                pafr_award = 'PAFR Award',
                city_go_vote = 'Vote',
                supermajority = 'Supermajority State',
                bond_issued_current_year = 'Bond Issued',
                state_monitor = 'State Fiscal Monitor',
                gasb_municipal_gaap_required_any = 'GAAP Required',
                nasact_audits_cities_towns_villages = 'State Audit',
                nasact_audits_cities_towns_villages_source_missing = 'State Audit Source Missing',
                ln_1p_outstanding_debt_lag1 = 'Outstanding Debt',
                ln_county_gdp_l1 = 'County ln(GDP)',
                ln_county_pop_l1 = 'County ln(Pop)',
                ln_county_percap_inc_l1 = 'County ln(Per Cap. Inc)',
                ln_county_employment_l1 = 'County ln(Emp)',
                city_rev_vote = 'Revenue Vote',
                state_go_vote = 'State GO Vote',
                state_utgo_allowed = 'UTGO Allowed',
                glm_proactive = 'Proactive GLM',
                low_state_tax_privilege = 'Low Tax Privilege',
                municipal_debt_limit = 'Municipal Debt Limit',
                municipal_debt_limit_source_missing = 'Debt Limit Source Missing',
                lincoln_property_tax_rate_cap_2024 = 'Property Tax Rate Cap',
                municipal_tel_index = 'Municipal TEL Index',
                fiscal_year = 'Year'),
       placement = 'H',
       replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel B: GFOA award regression analyses', ncols = 5)
writeLines(trimws(modified_output, which = 'right'),
           paste0(tables_wd, '/gfoa_awards_regression.tex'))

# Retain inspectable text and coefficient outputs beside the LaTeX table.
text_output <- capture.output(etable(r1, r2, r3, r4, se.below = TRUE, digits = 4))
writeLines(trimws(text_output, which = 'right'),
           paste0(tables_wd, '/gfoa_awards_models.txt'))

tidy_r1 <- as.data.frame(coeftable(r1))
tidy_r1 <- data.frame(model = "baseline_year_fe", term = rownames(tidy_r1), tidy_r1, row.names = NULL)
tidy_r2 <- as.data.frame(coeftable(r2))
tidy_r2 <- data.frame(model = "bond_policy_year_fe", term = rownames(tidy_r2), tidy_r2, row.names = NULL)
tidy_r3 <- as.data.frame(coeftable(r3))
tidy_r3 <- data.frame(model = "expanded_policy_year_fe", term = rownames(tidy_r3), tidy_r3, row.names = NULL)
tidy_r4 <- as.data.frame(coeftable(r4))
tidy_r4 <- data.frame(model = "supermajority_among_go_vote_year_fe", term = rownames(tidy_r4), tidy_r4, row.names = NULL)
fwrite(rbindlist(list(tidy_r1, tidy_r2, tidy_r3, tidy_r4)),
       paste0(tables_wd, '/gfoa_awards_model_coefficients.csv'))
