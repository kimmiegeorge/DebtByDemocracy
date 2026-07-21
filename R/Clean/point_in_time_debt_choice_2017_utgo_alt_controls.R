# 2017 point-in-time debt-choice robustness test:
# states requiring a vote only for UTGO debt versus AZ, CO, MO, SD, and VT.

rm(list = ls())

library(data.table)
library(fixest)

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
tbl_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')
processed_dir <- file.path(root, 'Code/R/Clean/output/processed')

source(file.path(root, 'Code/R/Clean/modify_etable_rounding.R'))
source(file.path(root, 'Code/R/Clean/tax_privilege_definitions.R'))

dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

comparison_states <- c('AZ', 'CO', 'MO', 'SD', 'VT')

data_2017 <- fread(file.path(
  root,
  'Data/Clean_Intermediate/Census COG Finance/processed/census_mergent_debt_cross_section_2017.csv'
))

data_2017[, fips := as.character(fips)]
if ('nh_city' %in% names(data_2017)) {
  data_2017 <- data_2017[!(state == 'NH' & nh_city == 0)]
} else {
  data_2017 <- data_2017[!(state == 'NH' & government_type_label == 'township')]
}
data_2017[state == 'ME', city_go_vote := NA_real_]
data_2017 <- data_2017[!is.na(city_go_vote)]
add_low_state_tax_privilege(data_2017, year_value = 2017)

data_2017[, frac_utgo_outstanding :=
  mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2017[, frac_ltgo_outstanding :=
  mergent_ltgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2017[, frac_rev_outstanding :=
  mergent_revenue_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2017[mergent_go_revenue_outstanding_debt <= 0, `:=`(
  frac_utgo_outstanding = NA_real_,
  frac_ltgo_outstanding = NA_real_,
  frac_rev_outstanding = NA_real_
)]
data_2017[, ln_census_population := log(census_population)]

analysis_sample <- data_2017[
  (utgo_only == 1 | state %in% comparison_states) &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) &
    !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]
analysis_sample[, utgo_only_vote := as.integer(utgo_only == 1)]

missing_comparisons <- setdiff(comparison_states, unique(analysis_sample$state))
if (length(missing_comparisons) > 0) {
  warning(
    'Comparison states absent after the analysis filters: ',
    paste(missing_comparisons, collapse = ', ')
  )
}
if (uniqueN(analysis_sample$utgo_only_vote) != 2L) {
  stop('The filtered sample does not contain both treatment categories.')
}

# In this restricted comparison, utgo_only_vote equals state_ltgo_allowed
# exactly. Retain the project's standard formula so fixest records and drops
# the collinear LTGO-allowed control, while keeping the treatment coefficient.
ltgo_control_collinear <- all(
  analysis_sample$utgo_only_vote == analysis_sample$state_ltgo_allowed
)
if (ltgo_control_collinear) {
  message(
    'utgo_only_vote and state_ltgo_allowed are perfectly collinear in this sample; ',
    'fixest will omit state_ltgo_allowed.'
  )
}

controls <- paste(
  'ln_gdp + ln_census_population + ln_pers_inc +',
  'ln_1p_county_nonmunicipal_total_debt + glm_proactive +',
  'state_ltgo_allowed + state_go_vote + low_state_tax_privilege'
)

models <- list(
  utgo_uncontrolled = feols(
    frac_utgo_outstanding ~ utgo_only_vote,
    data = analysis_sample,
    vcov = vcov_cluster(~state)
  ),
  utgo_controlled = feols(
    as.formula(paste('frac_utgo_outstanding ~ utgo_only_vote +', controls)),
    data = analysis_sample,
    vcov = vcov_cluster(~state)
  ),
  ltgo_controlled = feols(
    as.formula(paste('frac_ltgo_outstanding ~ utgo_only_vote +', controls)),
    data = analysis_sample,
    vcov = vcov_cluster(~state)
  ),
  revenue_controlled = feols(
    as.formula(paste('frac_rev_outstanding ~ utgo_only_vote +', controls)),
    data = analysis_sample,
    vcov = vcov_cluster(~state)
  )
)

control_dict <- c(
  frac_utgo_outstanding = 'Pct UTGO',
  frac_ltgo_outstanding = 'Pct LTGO',
  frac_rev_outstanding = 'Pct Revenue',
  utgo_only_vote = 'UTGO Only Vote',
  ln_gdp = 'County ln(GDP)',
  ln_census_population = 'City ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  ln_1p_county_nonmunicipal_total_debt = 'County Non-City Debt',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  low_state_tax_privilege = 'Low Tax Priv.'
)

table_call <- etable(
  models,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%utgo_only_vote'),
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel B: UTGO-only vote states vs. AZ, CO, MO, SD, and VT'
)

table_file <- file.path(
  tbl_dir,
  'point_in_time_debt_choice_2017_utgo_vs_az_co_mo_sd_vt.tex'
)
writeLines(modified_output, table_file)

coefficient_results <- rbindlist(lapply(names(models), function(model_name) {
  model <- models[[model_name]]
  coefficient_row <- coeftable(model)['utgo_only_vote', ]
  data.table(
    model = model_name,
    outcome = as.character(model$fml_all$linear[[2]]),
    estimate = unname(coefficient_row['Estimate']),
    std_error = unname(coefficient_row['Std. Error']),
    t_statistic = unname(coefficient_row['t value']),
    p_value = unname(coefficient_row['Pr(>|t|)']),
    observations = nobs(model),
    adjusted_r_squared = fitstat(model, 'ar2')[[1]],
    dropped_collinear_variables = paste(model$collin.var, collapse = ';')
  )
}))

results_file <- file.path(
  processed_dir,
  'point_in_time_debt_choice_2017_utgo_vs_az_co_mo_sd_vt_results.csv'
)
fwrite(coefficient_results, results_file)

sample_composition <- analysis_sample[, .(
  observations = .N,
  mean_utgo_share = mean(frac_utgo_outstanding, na.rm = TRUE),
  mean_ltgo_share = mean(frac_ltgo_outstanding, na.rm = TRUE),
  mean_revenue_share = mean(frac_rev_outstanding, na.rm = TRUE)
), by = .(utgo_only_vote, state, state_ltgo_allowed)][order(utgo_only_vote, state)]

sample_file <- file.path(
  processed_dir,
  'point_in_time_debt_choice_2017_utgo_vs_az_co_mo_sd_vt_sample.csv'
)
fwrite(sample_composition, sample_file)

print(coefficient_results)
print(sample_composition)
cat('\nLaTeX table:', table_file, '\n')
cat('Coefficient results:', results_file, '\n')
cat('Sample composition:', sample_file, '\n')
