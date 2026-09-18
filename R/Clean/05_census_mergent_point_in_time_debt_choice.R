# 05: Point-in-time Census/Mergent results (Tables 7, 8, 10, and 11; also Table 1 inputs)
rm(list = ls())

library(pacman)
p_load(data.table, fixest, xtable)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_tax_privilege_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_state_policy_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_border_pair_definitions.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
tbl_dir <- '/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables'
processed_dir <- '/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/processed'

#----------------------------
# Shared table labels
#----------------------------
control_dict <- c(
  frac_utgo_outstanding = 'Pct UTGO',
  frac_ltgo_outstanding = 'Pct LTGO',
  frac_rev_outstanding = 'Pct Revenue',
  mergent_wavg_yield_spread_go_revenue = 'Wtd. Avg. Yield Spread',
  mergent_wavg_yield_spread_utgo = 'Wtd. Avg. Yield Spread (UTGO)',
  mergent_wavg_yield_spread_ltgo = 'Wtd. Avg. Yield Spread (LTGO)',
  mergent_wavg_yield_spread_revenue = 'Wtd. Avg. Yield Spread (Rev)',
  census_total_debt_mil = 'Census Total Debt',
  census_lt_debt_mil = 'Census Long-Term Debt',
  mergent_go_revenue_outstanding_debt_mil = 'Mergent GO + Revenue Debt',
  ln_1p_county_nonmunicipal_total_debt = 'County Non-City Debt',
  mergent_wavg_original_maturity_years_go_revenue = 'Wtd. Avg. Original Maturity',
  mergent_wavg_original_maturity_years_utgo = 'Wtd. Avg. Original Maturity (UTGO)',
  mergent_wavg_original_maturity_years_ltgo = 'Wtd. Avg. Original Maturity (LTGO)',
  mergent_wavg_original_maturity_years_revenue = 'Wtd. Avg. Original Maturity (Rev)',
  mergent_wavg_rating_go_revenue_zero_unrated = 'Wtd. Avg. Rating',
  mergent_wavg_rating_utgo_zero_unrated = 'Wtd. Avg. Rating (UTGO)',
  mergent_wavg_rating_ltgo_zero_unrated = 'Wtd. Avg. Rating (LTGO)',
  mergent_wavg_rating_revenue_zero_unrated = 'Wtd. Avg. Rating (Rev)',
  mergent_wavg_insured_go_revenue = 'Wtd. Avg. Insured',
  mergent_any_insured_go_revenue = 'Any Insured',
  mergent_any_callable_go_revenue = 'Any Callable',
  mergent_any_sinkable_go_revenue = 'Any Sinkable',
  mergent_any_insured_utgo = 'Any Insured',
  mergent_any_callable_utgo = 'Any Callable',
  mergent_any_sinkable_utgo = 'Any Sinkable',
  mergent_any_insured_ltgo = 'Any Insured',
  mergent_any_callable_ltgo = 'Any Callable',
  mergent_any_sinkable_ltgo = 'Any Sinkable',
  mergent_any_insured_revenue = 'Any Insured',
  mergent_any_callable_revenue = 'Any Callable',
  mergent_any_sinkable_revenue = 'Any Sinkable',
  city_go_vote = 'Vote',
  super_majority = 'Supermajority State',
  low_state_tax_privilege = 'Low Tax Priv.',
  state_go_vote = 'State GO Vote',
  state_ltgo_allowed = 'LTGO Allowed',
  glm_proactive = 'Proactive State',
  ln_gdp = 'County ln(GDP)',
  ln_census_population = 'City ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  fips = 'County',
  border_group = 'State-Border'
)

#==============================================================================
# 2017 main cross section
#==============================================================================

#----------------------------
# Load and clean 2017 data
#----------------------------
data_2017 <- fread(
  file.path(root, 'Data/Clean_Intermediate/Census COG Finance/processed/census_mergent_debt_cross_section_2017.csv')
)

data_2017[, fips := as.character(fips)]
if ('nh_city' %in% names(data_2017)) {
  data_2017 <- data_2017[!(state == 'NH' & nh_city == 0)]
} else {
  data_2017 <- data_2017[!(state == 'NH' & government_type_label == 'township')]
}
data_2017 <- data_2017[!is.na(city_go_vote)]
data_2017[, super_majority := as.integer(state %in% super_majority_states)]
add_low_state_tax_privilege(data_2017, year_value = 2017)

data_2017[, ln_census_population := log(census_population)]

full_sample_2017 <- data_2017[insample == 1]
full_sample_2017 <- full_sample_2017[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

# Debt-choice and yield tests require at least two GO/revenue CUSIPs
# outstanding at the point-in-time measurement date. Preserve the broader
# sample for the Census debt-stock regressions below.
full_sample_2017_unrestricted <- copy(full_sample_2017)
full_sample_2017 <- full_sample_2017[
  !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]

#----------------------------
# 2017 point-in-time summary statistics
#----------------------------
# Use the common 2017 control screen. Debt-composition and yield outcomes are
# summarized only for cities satisfying the main point-in-time requirement of
# at least two outstanding GO/revenue CUSIPs. Census/Mergent debt-stock outcomes
# retain the broader sample used by the outstanding-debt regressions.
summary_2017 <- copy(full_sample_2017_unrestricted)
summary_2017[, utgo_only_vote := as.integer(city_go_vote == 1 & insample_utgo_only == 1)]

restricted_summary_vars <- c(
  'frac_utgo_outstanding',
  'frac_ltgo_outstanding',
  'frac_rev_outstanding',
  'mergent_wavg_yield_spread_go_revenue',
  'mergent_wavg_yield_spread_utgo',
  'mergent_wavg_yield_spread_ltgo',
  'mergent_wavg_yield_spread_revenue'
)
summary_2017[
  is.na(mergent_go_revenue_bonds_outstanding) |
    mergent_go_revenue_bonds_outstanding < 2,
  (restricted_summary_vars) := NA_real_
]

summary_vars_2017 <- c(
  'city_go_vote',
  'utgo_only_vote',
  'super_majority',
  'census_total_debt_mil',
  'census_lt_debt_mil',
  'mergent_go_revenue_outstanding_debt_mil',
  'frac_utgo_outstanding',
  'frac_ltgo_outstanding',
  'frac_rev_outstanding',
  'mergent_wavg_yield_spread_go_revenue',
  'mergent_wavg_yield_spread_utgo',
  'mergent_wavg_yield_spread_ltgo',
  'mergent_wavg_yield_spread_revenue',
  'ln_census_population',
  'ln_1p_county_nonmunicipal_total_debt',
  'glm_proactive',
  'state_ltgo_allowed',
  'state_go_vote',
  'low_state_tax_privilege'
)

summary_labels_2017 <- c(
  'GO Vote',
  'Only UTGO Vote',
  'Supermajority State',
  'Census Debt (mil.)',
  'Census LT Debt (mil.)',
  'Mergent Debt (mil.)',
  'Pct UTGO',
  'Pct LTGO',
  'Pct Revenue',
  'Wtd. Avg. Yld. Spread',
  'Wtd. Avg. Yld. Spread (UTGO)',
  'Wtd. Avg. Yld. Spread (LTGO)',
  'Wtd. Avg. Yld. Spread (Rev)',
  'City ln(Pop)',
  'County Non-City Debt',
  'Proactive State',
  'LTGO Allowed',
  'State GO Vote',
  'Low Tax Priv.'
)

summary_desc_2017 <- summary_2017[, ..summary_vars_2017]
summary_desc_2017 <- summary_desc_2017[, lapply(.SD, function(col) {
  c(
    Unit = 'City',
    Mean = mean(col, na.rm = TRUE),
    Std = sd(col, na.rm = TRUE),
    Min = min(col, na.rm = TRUE),
    P1 = quantile(col, probs = 0.01, na.rm = TRUE),
    Median = median(col, na.rm = TRUE),
    P99 = quantile(col, probs = 0.99, na.rm = TRUE),
    Max = max(col, na.rm = TRUE),
    N = sum(!is.na(col))
  )
})]
summary_desc_2017 <- data.table::transpose(summary_desc_2017, keep.names = 'variable')
setnames(
  summary_desc_2017,
  c('Variable', 'Unit', 'Mean', 'Std', 'Min', 'P1', 'Median', 'P99', 'Max', 'N')
)
summary_desc_2017[, Variable := summary_labels_2017]
for (stat_col in c('Mean', 'Std', 'Min', 'P1', 'Median', 'P99', 'Max')) {
  set(summary_desc_2017, j = stat_col, value = round(as.numeric(summary_desc_2017[[stat_col]]), 2))
}
summary_desc_2017[, N := format(as.integer(N), big.mark = ',')]

summary_tex_2017 <- capture.output(print(
  xtable(summary_desc_2017),
  include.rownames = FALSE,
  sanitize.text.function = identity,
  tabular.environment = 'tabular*',
  width = '\\textwidth',
  table.placement = 'H'
))

for (i in seq_along(summary_tex_2017)) {
  if (grepl('\\\\begin\\{tabular\\*\\}', summary_tex_2017[i])) {
    summary_tex_2017[i] <- gsub(
      '\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}',
      '\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}',
      summary_tex_2017[i]
    )
    break
  }
}
for (i in seq_along(summary_tex_2017)) {
  if (grepl('\\\\end\\{tabular\\*\\}', summary_tex_2017[i])) {
    summary_tex_2017[i] <- gsub('\\\\end\\{tabular\\*\\}', '\\\\end{tabular*}', summary_tex_2017[i])
    break
  }
}
for (i in seq_along(summary_tex_2017)) {
  if (grepl('^[[:space:]]*\\\\hline[[:space:]]*$', summary_tex_2017[i])) {
    summary_tex_2017[i] <- '  \\toprule'
    break
  }
}

summary_tex_2017 <- add_panel(
  summary_tex_2017,
  'Panel E: Debt choice descriptive statistics',
  ncols = 10
)
writeLines(summary_tex_2017, file.path(tbl_dir, 'issuer_level_desc.tex'))

#----------------------------
# 2017 full sample debt substitution: GO vote required
#----------------------------
allgo_utgo_uncontrolled_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_utgo_controlled_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_ltgo_controlled_2017 <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_revenue_controlled_2017 <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
  
table_call <- etable(
  allgo_utgo_uncontrolled_2017,
  allgo_utgo_controlled_2017,
  allgo_ltgo_controlled_2017,
  allgo_revenue_controlled_2017,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'GO Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel A: GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2017_allgo.tex'))

#----------------------------
# 2017 full sample debt substitution: only UTGO vote required
#----------------------------
utgo_only_utgo_uncontrolled_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

utgo_only_utgo_controlled_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

utgo_only_ltgo_controlled_2017 <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

utgo_only_revenue_controlled_2017 <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  utgo_only_utgo_uncontrolled_2017,
  utgo_only_utgo_controlled_2017,
  utgo_only_ltgo_controlled_2017,
  utgo_only_revenue_controlled_2017,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'UTGO Only Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2017_utgo_only.tex'))

#----------------------------
# 2017 supermajority specification used in Table 11
#----------------------------
supermajority_utgo_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote + super_majority + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

# 2017 full sample yield spreads: all city GO vote variation
#----------------------------
yield_2017_all_uncontrolled <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

yield_2017_all_controlled <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  yield_2017_all_uncontrolled, yield_2017_all_controlled,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel A: Weighted average yield spread',
  ncols = 3
)
writeLines(
  modified_output,
  file.path(tbl_dir, 'point_in_time_yield_spread_2017_full_sample.tex')
)

#----------------------------
# 2017 full sample yield spreads by bond type
#----------------------------
yield_2017_utgo_controlled <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_utgo_zero_unrated +
    mergent_wavg_original_maturity_years_utgo +
    mergent_any_insured_utgo + mergent_any_callable_utgo +
    mergent_any_sinkable_utgo + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

yield_2017_ltgo_controlled <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_ltgo_zero_unrated +
    mergent_wavg_original_maturity_years_ltgo +
    mergent_any_insured_ltgo + mergent_any_callable_ltgo +
    mergent_any_sinkable_ltgo + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

yield_2017_revenue_controlled <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_revenue +
    mergent_any_insured_revenue + mergent_any_callable_revenue +
    mergent_any_sinkable_revenue + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  yield_2017_utgo_controlled,
  yield_2017_ltgo_controlled,
  yield_2017_revenue_controlled,
  headers = c('UTGO', 'LTGO', 'Revenue'),
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  keep_raw = '^city_go_vote$',
  order = c('%city_go_vote'),
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
outcome_header_idx <- grep(
  '^[[:space:]]*& Wtd\\. Avg\\. Yield Spread',
  modified_output
)
if (length(outcome_header_idx) > 0) {
  modified_output[outcome_header_idx[1]] <-
    ' & \\multicolumn{3}{c}{Wtd. Avg. Yield Spread}\\\\'
}
modified_output <- format_table(modified_output, cluster_level = 'State')
adj_r2_idx <- grep(
  "^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&",
  modified_output
)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    '   Controls                   & Yes & Yes & Yes\\\\',
    after = adj_r2_idx[1]
  )
}
modified_output <- add_panel(
  modified_output,
  'Panel B: Weighted average yield spread by bond type',
  ncols = 4,
  zero_width = TRUE
)
writeLines(
  modified_output,
  file.path(
    tbl_dir,
    'point_in_time_yield_spread_2017_full_sample_panel_b_utgo_ltgo_revenue.tex'
  )
)

#----------------------------
# 2017 robustness table, Panel B: supermajority cross section
#----------------------------
supermajority_yield_2017 <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + super_majority +
    ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  supermajority_utgo_2017, supermajority_yield_2017,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  keep_raw = c('^city_go_vote$', '^super_majority$'),
  order = c('%city_go_vote', '%super_majority'),
  dict = c(
    control_dict[!(names(control_dict) %in% c('city_go_vote', 'super_majority'))],
    city_go_vote = 'Vote',
    super_majority = 'Vote $\\times$ Supermajority'
  ),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    "   Controls                   & Yes            & Yes\\\\",
    after = adj_r2_idx[1]
  )
}
modified_output <- add_panel(modified_output, 'Panel B: Supermajority cross section', ncols = 3)
writeLines(
  modified_output,
  file.path(tbl_dir, 'point_in_time_robustness_super_majority.tex')
)

full_sample_2017 <- full_sample_2017_unrestricted

#----------------------------
# 2017 PPML debt stock: all city GO vote variation
#----------------------------
census_total_debt_ppml_2017 <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

census_long_term_debt_ppml_2017 <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

mergent_debt_ppml_2017 <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  census_total_debt_ppml_2017,
  census_long_term_debt_ppml_2017,
  mergent_debt_ppml_2017,
  headers = c('Total', 'Long-term', 'GO + Revenue'),
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'pr2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & Census Total Debt & Census Long-Term Debt & Mergent GO + Revenue Debt\\\\',
  paste0(' & ', '\\', 'multicolumn{2}{c}{Census Debt} & ', '\\', 'multicolumn{1}{c}{Mergent Debt}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & GO + Revenue \\\\',
  ' & Total & Long-term & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-3}\\cmidrule(lr){4-4}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_poisson_2017_full_sample.tex'))

#----------------------------
# 2017 border-state test
#----------------------------
border_2017 <- fread(
  file.path(root, 'Data/Clean_Intermediate/Census COG Finance/processed/census_mergent_debt_cross_section_2017_border_sample.csv')
)

border_2017[, fips := as.character(fips)]
if ('nh_city' %in% names(border_2017)) {
  border_2017 <- border_2017[!(state == 'NH' & nh_city == 0)]
} else {
  border_2017 <- border_2017[!(state == 'NH' & government_type_label == 'township')]
}
border_2017 <- border_2017[!is.na(city_go_vote)]
add_low_state_tax_privilege(border_2017, year_value = 2017)
border_2017[, ln_census_population := log(census_population)]
border_2017[, state_year := interaction(state, year, drop = TRUE)]

border_2017 <- filter_debt_yield_border_pairs(border_2017, 'border_group')

border_2017 <- border_2017[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

# Match the full-sample eligibility rule before estimating the border design.
# The full-sample tables use insample == 1, which excludes cities where revenue
# bonds also require voter approval. After that restriction and the common
# control screen, retain only state-border groups with both city_go_vote values;
# groups without within-pair treatment variation do not identify the vote effect.
border_2017 <- border_2017[
  insample == 1 &
    !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]
identifying_border_groups_2017 <- border_2017[
  , .(vote_values = uniqueN(city_go_vote)),
  by = border_group
][vote_values == 2, border_group]
border_2017 <- border_2017[border_group %in% identifying_border_groups_2017]

#----------------------------
# 2017 robustness table, Panel A: border-state cross section
#----------------------------
border_utgo_2017 <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

border_yield_2017 <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  + ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated + mergent_wavg_original_maturity_years_go_revenue +
    mergent_wavg_insured_go_revenue + mergent_wavg_sinkable_go_revenue +
    state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

table_call <- etable(
  border_utgo_2017, border_yield_2017,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  keep_raw = '^city_go_vote$',
  order = '%city_go_vote',
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State-Year')
adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    "   Controls                   & Yes            & Yes\\\\",
    after = adj_r2_idx[1]
  )
}
modified_output <- add_panel(modified_output, 'Panel A: Border-city sample', ncols = 3)
writeLines(
  modified_output,
  file.path(tbl_dir, 'point_in_time_robustness_border_state.tex')
)

dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption{\\textbf{Point-in-Time Robustness: Border-City and Supermajority Specifications}}',
  '\\label{tab:point_in_time_robustness}',
  paste0(
    '\\parbox{\\textwidth}{This table reports 2017 point-in-time cross-sectional estimates. ',
    'Panel A applies the full-sample eligibility rule, restricts the sample to cities near state borders, ',
    'retains only state-border pairs containing both vote and non-vote cities, and includes state-border fixed effects. ',
    'Panel B adds the supermajority-state indicator to the full-sample specification. ',
    'Both panels use the strict outcome-specific controls from the main debt-choice and aggregate-yield tables. ',
    'Controls are suppressed. Standard errors are clustered by state-year in Panel A and by state in Panel B.}'
  ),
  '\\end{table}',
  '\\input{tables/clean/raw/point_in_time_robustness_border_state}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/point_in_time_robustness_super_majority}'
), file.path(processed_dir, 'point_in_time_robustness.tex'))
