# Outstanding debt stock regressions
rm(list = ls())

library(pacman)
p_load(data.table, fixest)

# Load custom etable rounding functions
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
panel_file <- file.path(
  root,
  'Data/Mergent/Outstanding Debt/260709_issuer_year_outstanding_debt.csv'
)
out_dir <- file.path(root, 'Results/Outstanding Debt')
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

#----------------------------
# Load data
#----------------------------
issuer_year <- fread(panel_file)
issuer_year[, vote_required := as.integer(vote_required)]
issuer_year[, year := as.integer(year)]
issuer_year[, fips := as.character(fips)]

controls <- c(
  'ln_gdp',
  'ln_pop',
  'ln_pers_inc',
  'ln_county_debt_other',
  'glm_proactive',
  'state_ltgo_allowed',
  'state_go_vote',
  'high_state_tax_privilege'
)

control_rhs <- paste(controls, collapse = ' + ')

control_dict <- c(
  vote_required = 'Vote Required',
  ln_1p_total_outstanding_debt = 'ln(1 + Total Outstanding Debt)',
  ln_1p_go_outstanding_debt = 'ln(1 + GO Outstanding Debt)',
  ln_1p_strict_gg_revenue_outstanding_debt =
    'ln(1 + Strict Revenue Outstanding Debt)',
  ln_gdp = 'County ln(GDP)',
  ln_pop = 'County ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  ln_county_debt_other = 'ln(Non-issuer county debt)',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  high_state_tax_privilege = 'High Tax Priv.'
)

reg_data <- issuer_year[
  complete.cases(issuer_year[, c('vote_required', 'fips', controls), with = FALSE])
]

#----------------------------
# Pooled issuer-year regressions with year fixed effects
#----------------------------
r_total <- feols(
  as.formula(
    paste0('ln_1p_total_outstanding_debt ~ vote_required + ', control_rhs, ' | year')
  ),
  data = reg_data,
  vcov = vcov_cluster(~fips)
)

r_go <- feols(
  as.formula(
    paste0('ln_1p_go_outstanding_debt ~ vote_required + ', control_rhs, ' | year')
  ),
  data = reg_data,
  vcov = vcov_cluster(~fips)
)

r_rev <- feols(
  as.formula(
    paste0(
      'ln_1p_strict_gg_revenue_outstanding_debt ~ vote_required + ',
      control_rhs,
      ' | year'
    )
  ),
  data = reg_data,
  vcov = vcov_cluster(~fips)
)

mean_total_no_vote <- reg_data[
  vote_required == 0,
  mean(ln_1p_total_outstanding_debt, na.rm = TRUE)
]
mean_go_no_vote <- reg_data[
  vote_required == 0,
  mean(ln_1p_go_outstanding_debt, na.rm = TRUE)
]
mean_rev_no_vote <- reg_data[
  vote_required == 0,
  mean(ln_1p_strict_gg_revenue_outstanding_debt, na.rm = TRUE)
]

pct_total <- 100 * (exp(coef(r_total)['vote_required']) - 1)
pct_go <- 100 * (exp(coef(r_go)['vote_required']) - 1)
pct_rev <- 100 * (exp(coef(r_rev)['vote_required']) - 1)

table_call <- etable(
  r_total,
  r_go,
  r_rev,
  headers = c('Total', 'GO', 'Strict Revenue'),
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%vote_required'),
  dict = control_dict,
  extralines = list(
    'No-vote mean' = c(
      sprintf('%.3f', mean_total_no_vote),
      sprintf('%.3f', mean_go_no_vote),
      sprintf('%.3f', mean_rev_no_vote)
    ),
    'Implied pct. effect' = c(
      sprintf('%.1f', pct_total),
      sprintf('%.1f', pct_go),
      sprintf('%.1f', pct_rev)
    )
  ),
  placement = 'H'
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(
  modified_output,
  'Panel A: Outstanding debt stock'
)
writeLines(
  modified_output,
  file.path(out_dir, '260709_outstanding_debt_stock_year_fe_controls.tex')
)
