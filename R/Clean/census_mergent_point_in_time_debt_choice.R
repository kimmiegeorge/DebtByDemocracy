# Point-in-time Census/Mergent debt choice regressions
rm(list = ls())

library(pacman)
p_load(data.table, fixest, xtable)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/tax_privilege_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/state_policy_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/border_pair_definitions.R')

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
  mergent_wavg_yield_spread_all_go = 'Wtd. Avg. Yield Spread (GO)',
  mergent_wavg_yield_spread_utgo = 'Wtd. Avg. Yield Spread (UTGO)',
  mergent_wavg_yield_spread_ltgo = 'Wtd. Avg. Yield Spread (LTGO)',
  mergent_wavg_yield_spread_revenue = 'Wtd. Avg. Yield Spread (Rev)',
  census_total_debt_mil = 'Census Total Debt',
  census_lt_debt_mil = 'Census Long-Term Debt',
  census_total_debt_per_capita = 'Census Total Debt per Capita',
  mergent_go_revenue_outstanding_debt_mil = 'Mergent GO + Revenue Debt',
  ln_1p_census_total_debt = 'ln(1 + Census Total Debt)',
  ln_1p_county_nonmunicipal_total_debt = 'County Non-City Debt',
  ln_1p_census_lt_debt = 'ln(1 + Census Long-Term Debt)',
  ln_1p_census_total_debt_pc = 'ln(1 + Census Total Debt per Capita)',
  ln_1p_mergent_go_revenue_outstanding_debt = 'ln(1 + Mergent GO + Revenue Debt)',
  mergent_wavg_original_maturity_years_go_revenue = 'Wtd. Avg. Original Maturity',
  mergent_wavg_original_maturity_years_all_go = 'Wtd. Avg. Original Maturity (GO)',
  mergent_wavg_original_maturity_years_utgo = 'Wtd. Avg. Original Maturity (UTGO)',
  mergent_wavg_original_maturity_years_ltgo = 'Wtd. Avg. Original Maturity (LTGO)',
  mergent_wavg_original_maturity_years_revenue = 'Wtd. Avg. Original Maturity (Rev)',
  mergent_wavg_rating_go_revenue_zero_unrated = 'Wtd. Avg. Rating',
  mergent_wavg_rating_all_go_zero_unrated = 'Wtd. Avg. Rating (GO)',
  mergent_wavg_rating_utgo_zero_unrated = 'Wtd. Avg. Rating (UTGO)',
  mergent_wavg_rating_ltgo_zero_unrated = 'Wtd. Avg. Rating (LTGO)',
  mergent_wavg_rating_revenue_zero_unrated = 'Wtd. Avg. Rating (Rev)',
  mergent_wavg_insured_go_revenue = 'Wtd. Avg. Insured',
  mergent_wavg_insured_all_go = 'Wtd. Avg. Insured (GO)',
  mergent_wavg_insured_utgo = 'Wtd. Avg. Insured (UTGO)',
  mergent_wavg_insured_ltgo = 'Wtd. Avg. Insured (LTGO)',
  mergent_wavg_insured_revenue = 'Wtd. Avg. Insured (Rev)',
  mergent_any_insured_go_revenue = 'Any Insured',
  mergent_any_callable_go_revenue = 'Any Callable',
  mergent_any_sinkable_go_revenue = 'Any Sinkable',
  mergent_any_insured_all_go = 'Any Insured',
  mergent_any_callable_all_go = 'Any Callable',
  mergent_any_sinkable_all_go = 'Any Sinkable',
  mergent_any_insured_utgo = 'Any Insured',
  mergent_any_callable_utgo = 'Any Callable',
  mergent_any_sinkable_utgo = 'Any Sinkable',
  mergent_any_insured_ltgo = 'Any Insured',
  mergent_any_callable_ltgo = 'Any Callable',
  mergent_any_sinkable_ltgo = 'Any Sinkable',
  mergent_any_insured_revenue = 'Any Insured',
  mergent_any_callable_revenue = 'Any Callable',
  mergent_any_sinkable_revenue = 'Any Sinkable',
  wavg_original_maturity = 'Wtd. Avg. Original Maturity',
  wavg_rating = 'Wtd. Avg. Rating',
  wavg_insured = 'Wtd. Avg. Insured',
  any_insured = 'Any Insured',
  any_callable = 'Any Callable',
  any_sinkable = 'Any Sinkable',
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

write_policy_yield_table <- function(sample_data, year) {
  super_model <- feols(
    mergent_wavg_yield_spread_go_revenue ~ city_go_vote + super_majority +
      ln_gdp + ln_census_population + ln_pers_inc  +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
      any_insured + any_callable + any_sinkable +
      glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~state)
  )
  summary(super_model)

  disclosure_model <- feols(
    mergent_wavg_yield_spread_go_revenue ~ city_go_vote + tax_disclosure_req +
      ln_gdp + ln_census_population + ln_pers_inc  +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
      any_insured + any_callable + any_sinkable +
      glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~state)
  )
  summary(disclosure_model)

  table_call <- etable(
    super_model, disclosure_model,
    coefstat = 'tstat',
    drop = 'Constant',
    style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
    fitstat = c('n', 'ar2'),
    se.below = TRUE,
    digits = 3,
    digits.stats = 3,
    signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
    tex = TRUE,
    keep_raw = c('^city_go_vote$', '^super_majority$', '^tax_disclosure_req$'),
    order = c('%city_go_vote', '%super_majority', '%tax_disclosure_req'),
    dict = c(
      control_dict[names(control_dict) != 'city_go_vote'],
      city_go_vote = 'GO Vote',
      super_majority = 'GO Vote $\\times$ Supermajority',
      tax_disclosure_req = 'GO Vote $\\times$ Tax Disclosure Req'
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
  modified_output <- add_panel(
    modified_output,
    'Panel D: Aggregate yield spread, cross-sectional policy tests',
    ncols = 3
  )
  writeLines(
    modified_output,
    file.path(tbl_dir, sprintf('point_in_time_yield_spread_%s_super_majority.tex', year))
  )
}

write_full_sample_yield_tables <- function(sample_data, year) {
  prepare_yield_data <- function(rating_col, maturity_col, feature_suffix) {
    yield_data <- copy(sample_data)
    yield_data[, wavg_rating := get(rating_col)]
    yield_data[, wavg_original_maturity := get(maturity_col)]
    yield_data[, any_insured := get(paste0('mergent_any_insured_', feature_suffix))]
    yield_data[, any_callable := get(paste0('mergent_any_callable_', feature_suffix))]
    yield_data[, any_sinkable := get(paste0('mergent_any_sinkable_', feature_suffix))]
    yield_data
  }

  controlled_formula <- function(outcome) {
    as.formula(paste0(
      outcome,
      ' ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ',
      'ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity + ',
      'any_insured + any_callable + any_sinkable + ',
      'glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege'
    ))
  }

  estimate_controlled_yield <- function(outcome, rating_col, maturity_col, feature_suffix) {
    model_data <- prepare_yield_data(rating_col, maturity_col, feature_suffix)
    feols(
      controlled_formula(outcome),
      data = model_data,
      vcov = vcov_cluster(~state)
    )
  }

  write_yield_panel <- function(
    models,
    headers,
    panel_label,
    output_file,
    collapse_outcome_header = FALSE,
    suppress_control_coefficients = FALSE,
    zero_width_panel_title = FALSE
  ) {
    table_call <- etable(
      models,
      headers = headers,
      coefstat = 'tstat',
      drop = 'Constant',
      style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
      fitstat = c('n', 'ar2'),
      se.below = TRUE,
      digits = 3,
      digits.stats = 3,
      signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
      tex = TRUE,
      keep_raw = if (isTRUE(suppress_control_coefficients)) '^city_go_vote$' else NULL,
      order = c('%city_go_vote'),
      dict = control_dict,
      placement = 'H'
    )

    modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
    if (isTRUE(collapse_outcome_header)) {
      outcome_header_idx <- grep(
        '^[[:space:]]*& Wtd\\. Avg\\. Yield Spread',
        modified_output
      )
      if (length(outcome_header_idx) > 0) {
        modified_output[outcome_header_idx[1]] <- paste0(
          ' & \\multicolumn{',
          length(models),
          '}{c}{Wtd. Avg. Yield Spread}\\\\'
        )
      }
    }
    modified_output <- format_table(modified_output, cluster_level = 'State')
    if (isTRUE(suppress_control_coefficients)) {
      adj_r2_idx <- grep(
        "^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&",
        modified_output
      )
      if (length(adj_r2_idx) > 0) {
        controls_row <- paste0(
          '   Controls                   & ',
          paste(rep('Yes', length(models)), collapse = ' & '),
          '\\\\'
        )
        modified_output <- append(
          modified_output,
          controls_row,
          after = adj_r2_idx[1]
        )
      }
    }
    modified_output <- add_panel(
      modified_output,
      panel_label,
      ncols = length(models) + 1,
      zero_width = zero_width_panel_title
    )
    writeLines(modified_output, file.path(tbl_dir, output_file))
  }

  yield_all <- prepare_yield_data(
    'mergent_wavg_rating_go_revenue_zero_unrated',
    'mergent_wavg_original_maturity_years_go_revenue',
    'go_revenue'
  )

  panel_a_uncontrolled <- feols(
    mergent_wavg_yield_spread_go_revenue ~ city_go_vote,
    data = yield_all,
    vcov = vcov_cluster(~state)
  )
  panel_a_controlled <- feols(
    controlled_formula('mergent_wavg_yield_spread_go_revenue'),
    data = yield_all,
    vcov = vcov_cluster(~state)
  )

  write_yield_panel(
    list(panel_a_uncontrolled, panel_a_controlled),
    headers = NULL,
    panel_label = 'Panel A: Weighted average yield spread',
    output_file = sprintf('point_in_time_yield_spread_%s_full_sample.tex', year)
  )

  panel_b_utgo <- estimate_controlled_yield(
    'mergent_wavg_yield_spread_utgo',
    'mergent_wavg_rating_utgo_zero_unrated',
    'mergent_wavg_original_maturity_years_utgo',
    'utgo'
  )
  panel_b_ltgo <- estimate_controlled_yield(
    'mergent_wavg_yield_spread_ltgo',
    'mergent_wavg_rating_ltgo_zero_unrated',
    'mergent_wavg_original_maturity_years_ltgo',
    'ltgo'
  )
  panel_b_revenue <- estimate_controlled_yield(
    'mergent_wavg_yield_spread_revenue',
    'mergent_wavg_rating_revenue_zero_unrated',
    'mergent_wavg_original_maturity_years_revenue',
    'revenue'
  )

  write_yield_panel(
    list(panel_b_utgo, panel_b_ltgo, panel_b_revenue),
    headers = c('UTGO', 'LTGO', 'Revenue'),
    panel_label = 'Panel B: Weighted average yield spread by bond type',
    output_file = sprintf(
      'point_in_time_yield_spread_%s_full_sample_panel_b_utgo_ltgo_revenue.tex',
      year
    ),
    collapse_outcome_header = TRUE,
    suppress_control_coefficients = identical(as.integer(year), 2017L),
    zero_width_panel_title = identical(as.integer(year), 2017L)
  )

  panel_b_all_go <- estimate_controlled_yield(
    'mergent_wavg_yield_spread_all_go',
    'mergent_wavg_rating_all_go_zero_unrated',
    'mergent_wavg_original_maturity_years_all_go',
    'all_go'
  )

  write_yield_panel(
    list(panel_b_all_go, panel_b_revenue),
    headers = c('All GO', 'Revenue'),
    panel_label = 'Panel B: Weighted average yield spread by bond type',
    output_file = sprintf(
      'point_in_time_yield_spread_%s_full_sample_panel_b_go_revenue.tex',
      year
    ),
    collapse_outcome_header = TRUE,
    suppress_control_coefficients = TRUE,
    zero_width_panel_title = identical(as.integer(year), 2017L)
  )

  invisible(yield_all)
}

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
data_2017[state == 'ME', city_go_vote := NA_real_]
data_2017 <- data_2017[!is.na(city_go_vote)]
data_2017[, super_majority := as.integer(state %in% super_majority_states)]
data_2017[, tax_disclosure_req := as.integer(state %in% c('AZ', 'AR', 'NC', 'OH', 'OR', 'TX', 'UT', 'WA', 'WV'))]
add_low_state_tax_privilege(data_2017, year_value = 2017)

data_2017[, frac_utgo_outstanding := mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2017[, frac_ltgo_outstanding := mergent_ltgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2017[, frac_rev_outstanding := mergent_revenue_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2017[mergent_go_revenue_outstanding_debt <= 0, `:=`(
  frac_utgo_outstanding = NA_real_,
  frac_ltgo_outstanding = NA_real_,
  frac_rev_outstanding = NA_real_
)]

data_2017[, ln_1p_census_total_debt := log1p(census_total_debt_mil * 1000000)]
data_2017[, ln_1p_census_lt_debt := log1p(census_lt_debt_mil * 1000000)]
data_2017[, ln_1p_census_total_debt_pc := log1p(census_total_debt_per_capita)]
data_2017[, ln_1p_mergent_go_revenue_outstanding_debt := log1p(mergent_go_revenue_outstanding_debt)]
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
r1_2017_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r1_2017_allgo)

r2_2017_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r2_2017_allgo)

r3_2017_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r3_2017_allgo)

r4_2017_allgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r4_2017_allgo)

r5_2017_allgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r5_2017_allgo)
  
table_call <- etable(
  r1_2017_allgo, r3_2017_allgo, r4_2017_allgo, r5_2017_allgo,
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
r1_2017_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r1_2017_utgo)

r2_2017_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r2_2017_utgo)

r3_2017_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r3_2017_utgo)

r4_2017_utgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r4_2017_utgo)

r5_2017_utgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r5_2017_utgo)

table_call <- etable(
  r1_2017_utgo, r3_2017_utgo, r4_2017_utgo, r5_2017_utgo,
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
# 2017 full sample debt substitution: cross-sectional policy tests
#----------------------------
r_2017_super <- feols(
  frac_utgo_outstanding ~ city_go_vote + super_majority + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(r_2017_super)

r_2017_tax_disclosure <- feols(
  frac_utgo_outstanding ~ city_go_vote + tax_disclosure_req + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(r_2017_tax_disclosure)

table_call <- etable(
  r_2017_super, r_2017_tax_disclosure,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  keep_raw = c("^city_go_vote$", "^super_majority$", "^tax_disclosure_req$"),
  order = c('%city_go_vote', '%super_majority', '%tax_disclosure_req'),
  dict = c(
    control_dict[names(control_dict) != 'city_go_vote'],
    city_go_vote = 'GO Vote',
    super_majority = 'GO Vote $\\times$ Supermajority',
    tax_disclosure_req = 'GO Vote $\\times$ Tax Disclosure Req'
  ),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(modified_output, "   Controls                   & Yes            & Yes\\\\", after = adj_r2_idx[1])
}
modified_output <- add_panel(modified_output, 'Panel C: Full sample, cross-sectional policy tests', ncols = 3)
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2017_super_majority.tex'))

#----------------------------
# 2017 full sample yield spreads: GO vote required
#----------------------------
yield_2017_allgo_all <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_zero_unrated]
yield_2017_allgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]
yield_2017_allgo_all[, `:=`(any_insured = mergent_any_insured_go_revenue, any_callable = mergent_any_callable_go_revenue, any_sinkable = mergent_any_sinkable_go_revenue)]

yield_2017_allgo_utgo <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_zero_unrated]
yield_2017_allgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]
yield_2017_allgo_utgo[, `:=`(any_insured = mergent_any_insured_utgo, any_callable = mergent_any_callable_utgo, any_sinkable = mergent_any_sinkable_utgo)]

yield_2017_allgo_ltgo <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_zero_unrated]
yield_2017_allgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]
yield_2017_allgo_ltgo[, `:=`(any_insured = mergent_any_insured_ltgo, any_callable = mergent_any_callable_ltgo, any_sinkable = mergent_any_sinkable_ltgo)]

yield_2017_allgo_rev <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_rev[, wavg_rating := mergent_wavg_rating_revenue_zero_unrated]
yield_2017_allgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]
yield_2017_allgo_rev[, `:=`(any_insured = mergent_any_insured_revenue, any_callable = mergent_any_callable_revenue, any_sinkable = mergent_any_sinkable_revenue)]

r1_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2017_allgo_all,
  vcov = vcov_cluster(~state)
)
summary(r1_2017_yield_allgo_sample)

r2_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2017_allgo_utgo,
  vcov = vcov_cluster(~state)
)
summary(r2_2017_yield_allgo_sample)

r3_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2017_allgo_ltgo,
  vcov = vcov_cluster(~state)
)
summary(r3_2017_yield_allgo_sample)

r4_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2017_allgo_rev,
  vcov = vcov_cluster(~state)
)
summary(r4_2017_yield_allgo_sample)

table_call <- etable(
  r1_2017_yield_allgo_sample, r2_2017_yield_allgo_sample, r3_2017_yield_allgo_sample, r4_2017_yield_allgo_sample,
  headers = c('All', 'UTGO', 'LTGO', 'Revenue'),
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
modified_output <- sub(
  ' & Wtd. Avg. Yield Spread & Wtd. Avg. Yield Spread (UTGO) & Wtd. Avg. Yield Spread (LTGO) & Wtd. Avg. Yield Spread (Rev)\\\\',
  paste0(' & ', '\\', 'multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel A: Yield spreads, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2017_allgo.tex'))

#----------------------------
# 2017 full sample yield spreads: only UTGO vote required
#----------------------------
yield_2017_utgo_all <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_zero_unrated]
yield_2017_utgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]
yield_2017_utgo_all[, `:=`(any_insured = mergent_any_insured_go_revenue, any_callable = mergent_any_callable_go_revenue, any_sinkable = mergent_any_sinkable_go_revenue)]

yield_2017_utgo_utgo <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_zero_unrated]
yield_2017_utgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]
yield_2017_utgo_utgo[, `:=`(any_insured = mergent_any_insured_utgo, any_callable = mergent_any_callable_utgo, any_sinkable = mergent_any_sinkable_utgo)]

yield_2017_utgo_ltgo <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_zero_unrated]
yield_2017_utgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]
yield_2017_utgo_ltgo[, `:=`(any_insured = mergent_any_insured_ltgo, any_callable = mergent_any_callable_ltgo, any_sinkable = mergent_any_sinkable_ltgo)]

yield_2017_utgo_rev <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_rev[, wavg_rating := mergent_wavg_rating_revenue_zero_unrated]
yield_2017_utgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]
yield_2017_utgo_rev[, `:=`(any_insured = mergent_any_insured_revenue, any_callable = mergent_any_callable_revenue, any_sinkable = mergent_any_sinkable_revenue)]

r1_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2017_utgo_all,
  vcov = vcov_cluster(~state)
)
summary(r1_2017_yield_utgo_sample)

r2_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2017_utgo_utgo,
  vcov = vcov_cluster(~state)
)
summary(r2_2017_yield_utgo_sample)

r3_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2017_utgo_ltgo,
  vcov = vcov_cluster(~state)
)
summary(r3_2017_yield_utgo_sample)

r4_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2017_utgo_rev,
  vcov = vcov_cluster(~state)
)
summary(r4_2017_yield_utgo_sample)

table_call <- etable(
  r1_2017_yield_utgo_sample, r2_2017_yield_utgo_sample, r3_2017_yield_utgo_sample, r4_2017_yield_utgo_sample,
  headers = c('All', 'UTGO', 'LTGO', 'Revenue'),
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & Wtd. Avg. Yield Spread & Wtd. Avg. Yield Spread (UTGO) & Wtd. Avg. Yield Spread (LTGO) & Wtd. Avg. Yield Spread (Rev)\\\\',
  paste0(' & ', '\\', 'multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel B: Yield spreads, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2017_utgo_only.tex'))

#----------------------------
# 2017 full sample yield spreads: all city GO vote variation
#----------------------------
yield_2017_full_all <- write_full_sample_yield_tables(full_sample_2017, 2017)
write_policy_yield_table(yield_2017_full_all, 2017)

#----------------------------
# 2017 robustness table, Panel B: supermajority cross section
#----------------------------
r_2017_yield_super <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + super_majority +
    ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2017_full_all,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_2017_super, r_2017_yield_super,
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
# 2017 Census debt stock: GO vote required
#----------------------------
r1_2017_census_debt_allgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r1_2017_census_debt_allgo)

r2_2017_census_debt_allgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r2_2017_census_debt_allgo)

r3_2017_census_debt_allgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r3_2017_census_debt_allgo)

r4_2017_census_debt_allgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(r4_2017_census_debt_allgo)

table_call <- etable(
  r1_2017_census_debt_allgo, r2_2017_census_debt_allgo, r3_2017_census_debt_allgo, r4_2017_census_debt_allgo,
  headers = c('Total', 'Long-term', 'Per capita', 'GO + Revenue'),
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
modified_output <- sub(
  ' & ln(1 + Census Total Debt) & ln(1 + Census Long-Term Debt) & ln(1 + Census Total Debt per Capita) & ln(1 + Mergent GO + Revenue Debt)\\\\',
  paste0(' & ', '\\', 'multicolumn{3}{c}{ln(1 + Census Debt)} & ', '\\', 'multicolumn{1}{c}{ln(1 + Mergent Debt)}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & Per capita & GO + Revenue \\\\',
  ' & Total & Long-term & Per capita & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2017_allgo.tex'))

#----------------------------
# 2017 Census debt stock: only UTGO vote required
#----------------------------
r1_2017_census_debt_utgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r1_2017_census_debt_utgo)

r2_2017_census_debt_utgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r2_2017_census_debt_utgo)

r3_2017_census_debt_utgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r3_2017_census_debt_utgo)

r4_2017_census_debt_utgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(r4_2017_census_debt_utgo)

table_call <- etable(
  r1_2017_census_debt_utgo, r2_2017_census_debt_utgo, r3_2017_census_debt_utgo, r4_2017_census_debt_utgo,
  headers = c('Total', 'Long-term', 'Per capita', 'GO + Revenue'),
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & ln(1 + Census Total Debt) & ln(1 + Census Long-Term Debt) & ln(1 + Census Total Debt per Capita) & ln(1 + Mergent GO + Revenue Debt)\\\\',
  paste0(' & ', '\\', 'multicolumn{3}{c}{ln(1 + Census Debt)} & ', '\\', 'multicolumn{1}{c}{ln(1 + Mergent Debt)}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & Per capita & GO + Revenue \\\\',
  ' & Total & Long-term & Per capita & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2017_utgo_only.tex'))

#----------------------------
# 2017 Census debt stock: all city GO vote variation
#----------------------------
r1_2017_census_debt_full <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(r1_2017_census_debt_full)

r2_2017_census_debt_full <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(r2_2017_census_debt_full)

r3_2017_census_debt_full <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(r3_2017_census_debt_full)

r4_2017_census_debt_full <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(r4_2017_census_debt_full)

table_call <- etable(
  r1_2017_census_debt_full, r2_2017_census_debt_full, r3_2017_census_debt_full, r4_2017_census_debt_full,
  headers = c('Total', 'Long-term', 'Per capita', 'GO + Revenue'),
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
modified_output <- sub(
  ' & ln(1 + Census Total Debt) & ln(1 + Census Long-Term Debt) & ln(1 + Census Total Debt per Capita) & ln(1 + Mergent GO + Revenue Debt)\\\\',
  paste0(' & ', '\\', 'multicolumn{3}{c}{ln(1 + Census Debt)} & ', '\\', 'multicolumn{1}{c}{ln(1 + Mergent Debt)}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & Per capita & GO + Revenue \\\\',
  ' & Total & Long-term & Per capita & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2017_full_sample.tex'))

#----------------------------
# 2017 PPML debt stock: GO vote required
#----------------------------
p1_2017_census_debt_allgo <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p1_2017_census_debt_allgo)

p2_2017_census_debt_allgo <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p2_2017_census_debt_allgo)

p3_2017_census_debt_allgo <- fepois(
  census_total_debt_per_capita ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p3_2017_census_debt_allgo)

p4_2017_census_debt_allgo <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p4_2017_census_debt_allgo)

table_call <- etable(
  p1_2017_census_debt_allgo, p2_2017_census_debt_allgo, p4_2017_census_debt_allgo,
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
# Column padding varies with coefficient width, so use label-based fallbacks.
debt_header_idx <- grep('Census Total Debt', modified_output, fixed = TRUE)
modified_output[debt_header_idx] <- paste0(
  ' & ', '\\', 'multicolumn{2}{c}{Census Debt} & ', '\\', 'multicolumn{1}{c}{Mergent Debt}\\\\'
)
column_header_idx <- grep('GO + Revenue', modified_output, fixed = TRUE)
column_header_idx <- column_header_idx[grepl('Total', modified_output[column_header_idx], fixed = TRUE)]
modified_output[column_header_idx] <- ' & Total & Long-term & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-3}\\cmidrule(lr){4-4}'
modified_output <- format_table(modified_output, cluster_level = 'State')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_poisson_2017_allgo.tex'))

#----------------------------
# 2017 PPML debt stock: only UTGO vote required
#----------------------------
p1_2017_census_debt_utgo <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p1_2017_census_debt_utgo)

p2_2017_census_debt_utgo <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p2_2017_census_debt_utgo)

p3_2017_census_debt_utgo <- fepois(
  census_total_debt_per_capita ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p3_2017_census_debt_utgo)

p4_2017_census_debt_utgo <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p4_2017_census_debt_utgo)

table_call <- etable(
  p1_2017_census_debt_utgo, p2_2017_census_debt_utgo, p4_2017_census_debt_utgo,
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
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
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_poisson_2017_utgo_only.tex'))

#----------------------------
# 2017 PPML debt stock: all city GO vote variation
#----------------------------
p1_2017_census_debt_full <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(p1_2017_census_debt_full)

p2_2017_census_debt_full <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(p2_2017_census_debt_full)

p3_2017_census_debt_full <- fepois(
  census_total_debt_per_capita ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(p3_2017_census_debt_full)

p4_2017_census_debt_full <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)
summary(p4_2017_census_debt_full)

table_call <- etable(
  p1_2017_census_debt_full, p2_2017_census_debt_full, p4_2017_census_debt_full,
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
border_2017[state == 'ME', city_go_vote := NA_real_]
border_2017 <- border_2017[!is.na(city_go_vote)]
add_low_state_tax_privilege(border_2017, year_value = 2017)
border_2017[, frac_utgo_outstanding := mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
border_2017[, frac_ltgo_outstanding := mergent_ltgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
border_2017[, frac_rev_outstanding := mergent_revenue_outstanding_debt / mergent_go_revenue_outstanding_debt]
border_2017[mergent_go_revenue_outstanding_debt <= 0, `:=`(
  frac_utgo_outstanding = NA_real_,
  frac_ltgo_outstanding = NA_real_,
  frac_rev_outstanding = NA_real_
)]
border_2017[, ln_1p_census_total_debt := log1p(census_total_debt_mil * 1000000)]
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

r1_2017_border <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

r4_2017_border <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated + mergent_wavg_original_maturity_years_go_revenue +
    state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

p1_2017_border <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

table_call <- etable(
  r1_2017_border, r4_2017_border, p1_2017_border,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(control_dict, city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State-Year')
modified_output <- modified_output[!trimws(modified_output) %in% c('& \\\\', '\\\\')]
modified_output <- add_panel(modified_output, 'Panel E: Border-state sample', ncols = 4)
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_border_state_2017.tex'))

#----------------------------
# 2017 robustness table, Panel A: border-state cross section
#----------------------------
r_2017_border_robust_frac <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

r_2017_border_robust_yield <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  + ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated + mergent_wavg_original_maturity_years_go_revenue +
    mergent_wavg_insured_go_revenue + mergent_wavg_sinkable_go_revenue +
    state_go_vote + low_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~state_year)
)

table_call <- etable(
  r_2017_border_robust_frac, r_2017_border_robust_yield,
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


#==============================================================================
# 2012 robustness cross section
#==============================================================================

#----------------------------
# Load and clean 2012 data
#----------------------------
data_2012 <- fread(
  file.path(root, 'Data/Clean_Intermediate/Census COG Finance/processed/census_mergent_debt_cross_section_2012.csv')
)

data_2012[, fips := as.character(fips)]
if ('nh_city' %in% names(data_2012)) {
  data_2012 <- data_2012[!(state == 'NH' & nh_city == 0)]
} else {
  data_2012 <- data_2012[!(state == 'NH' & government_type_label == 'township')]
}
data_2012[state == 'ME', city_go_vote := NA_real_]
data_2012 <- data_2012[!is.na(city_go_vote)]
data_2012[, super_majority := as.integer(state %in% super_majority_states)]
data_2012[, tax_disclosure_req := as.integer(state %in% c('AZ', 'AR', 'NC', 'OH', 'OR', 'TX', 'UT', 'WA', 'WV'))]
add_low_state_tax_privilege(data_2012, year_value = 2012)

data_2012[, frac_utgo_outstanding := mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2012[, frac_ltgo_outstanding := mergent_ltgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2012[, frac_rev_outstanding := mergent_revenue_outstanding_debt / mergent_go_revenue_outstanding_debt]
data_2012[mergent_go_revenue_outstanding_debt <= 0, `:=`(
  frac_utgo_outstanding = NA_real_,
  frac_ltgo_outstanding = NA_real_,
  frac_rev_outstanding = NA_real_
)]

data_2012[, ln_1p_census_total_debt := log1p(census_total_debt_mil * 1000000)]
data_2012[, ln_1p_census_lt_debt := log1p(census_lt_debt_mil * 1000000)]
data_2012[, ln_1p_census_total_debt_pc := log1p(census_total_debt_per_capita)]
data_2012[, ln_1p_mergent_go_revenue_outstanding_debt := log1p(mergent_go_revenue_outstanding_debt)]
data_2012[, ln_census_population := log(census_population)]

full_sample_2012 <- data_2012[insample == 1]
full_sample_2012 <- full_sample_2012[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

# Apply the same point-in-time outstanding-CUSIP rule used in 2017, while
# preserving the broader sample for the Census debt-stock regressions below.
full_sample_2012_unrestricted <- copy(full_sample_2012)
full_sample_2012 <- full_sample_2012[
  !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]

#----------------------------
# 2012 full sample debt substitution: GO vote required
#----------------------------
r1_2012_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r2_2012_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r3_2012_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r4_2012_allgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r5_2012_allgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_allgo, r3_2012_allgo, r4_2012_allgo, r5_2012_allgo,
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
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2012_allgo.tex'))

#----------------------------
# 2012 full sample debt substitution: only UTGO vote required
#----------------------------
r1_2012_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r2_2012_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r3_2012_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r4_2012_utgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r5_2012_utgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_utgo, r3_2012_utgo, r4_2012_utgo, r5_2012_utgo,
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
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2012_utgo_only.tex'))

#----------------------------
# 2012 full sample debt substitution: cross-sectional policy tests
#----------------------------
r_2012_super <- feols(
  frac_utgo_outstanding ~ city_go_vote + super_majority + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)
summary(r_2012_super)

r_2012_tax_disclosure <- feols(
  frac_utgo_outstanding ~ city_go_vote + tax_disclosure_req + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)
summary(r_2012_tax_disclosure)

table_call <- etable(
  r_2012_super, r_2012_tax_disclosure,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  keep_raw = c("^city_go_vote$", "^super_majority$", "^tax_disclosure_req$"),
  order = c('%city_go_vote', '%super_majority', '%tax_disclosure_req'),
  dict = c(
    control_dict[names(control_dict) != 'city_go_vote'],
    city_go_vote = 'GO Vote',
    super_majority = 'GO Vote $\\times$ Supermajority',
    tax_disclosure_req = 'GO Vote $\\times$ Tax Disclosure Req'
  ),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(modified_output, "   Controls                   & Yes            & Yes\\\\", after = adj_r2_idx[1])
}
modified_output <- add_panel(modified_output, 'Panel C: Full sample, cross-sectional policy tests', ncols = 3)
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2012_super_majority.tex'))

#----------------------------
# 2012 full sample yield spreads: GO vote required
#----------------------------
yield_2012_allgo_all <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_zero_unrated]
yield_2012_allgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]
yield_2012_allgo_all[, `:=`(any_insured = mergent_any_insured_go_revenue, any_callable = mergent_any_callable_go_revenue, any_sinkable = mergent_any_sinkable_go_revenue)]

yield_2012_allgo_utgo <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_zero_unrated]
yield_2012_allgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]
yield_2012_allgo_utgo[, `:=`(any_insured = mergent_any_insured_utgo, any_callable = mergent_any_callable_utgo, any_sinkable = mergent_any_sinkable_utgo)]

yield_2012_allgo_ltgo <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_zero_unrated]
yield_2012_allgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]
yield_2012_allgo_ltgo[, `:=`(any_insured = mergent_any_insured_ltgo, any_callable = mergent_any_callable_ltgo, any_sinkable = mergent_any_sinkable_ltgo)]

yield_2012_allgo_rev <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_rev[, wavg_rating := mergent_wavg_rating_revenue_zero_unrated]
yield_2012_allgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]
yield_2012_allgo_rev[, `:=`(any_insured = mergent_any_insured_revenue, any_callable = mergent_any_callable_revenue, any_sinkable = mergent_any_sinkable_revenue)]

r1_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2012_allgo_all,
  vcov = vcov_cluster(~state)
)

r2_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2012_allgo_utgo,
  vcov = vcov_cluster(~state)
)

r3_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2012_allgo_ltgo,
  vcov = vcov_cluster(~state)
)

r4_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = yield_2012_allgo_rev,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_yield_allgo_sample, r2_2012_yield_allgo_sample, r3_2012_yield_allgo_sample, r4_2012_yield_allgo_sample,
  headers = c('All', 'UTGO', 'LTGO', 'Revenue'),
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
modified_output <- sub(
  ' & Wtd. Avg. Yield Spread & Wtd. Avg. Yield Spread (UTGO) & Wtd. Avg. Yield Spread (LTGO) & Wtd. Avg. Yield Spread (Rev)\\\\',
  paste0(' & ', '\\', 'multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel A: Yield spreads, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2012_allgo.tex'))

#----------------------------
# 2012 full sample yield spreads: only UTGO vote required
#----------------------------
yield_2012_utgo_all <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_zero_unrated]
yield_2012_utgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]
yield_2012_utgo_all[, `:=`(any_insured = mergent_any_insured_go_revenue, any_callable = mergent_any_callable_go_revenue, any_sinkable = mergent_any_sinkable_go_revenue)]

yield_2012_utgo_utgo <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_zero_unrated]
yield_2012_utgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]
yield_2012_utgo_utgo[, `:=`(any_insured = mergent_any_insured_utgo, any_callable = mergent_any_callable_utgo, any_sinkable = mergent_any_sinkable_utgo)]

yield_2012_utgo_ltgo <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_zero_unrated]
yield_2012_utgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]
yield_2012_utgo_ltgo[, `:=`(any_insured = mergent_any_insured_ltgo, any_callable = mergent_any_callable_ltgo, any_sinkable = mergent_any_sinkable_ltgo)]

yield_2012_utgo_rev <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_rev[, wavg_rating := mergent_wavg_rating_revenue_zero_unrated]
yield_2012_utgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]
yield_2012_utgo_rev[, `:=`(any_insured = mergent_any_insured_revenue, any_callable = mergent_any_callable_revenue, any_sinkable = mergent_any_sinkable_revenue)]

r1_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2012_utgo_all,
  vcov = vcov_cluster(~state)
)

r2_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2012_utgo_utgo,
  vcov = vcov_cluster(~state)
)

r3_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2012_utgo_ltgo,
  vcov = vcov_cluster(~state)
)

r4_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    any_insured + any_callable + any_sinkable +
    glm_proactive + state_go_vote + low_state_tax_privilege,
  data = yield_2012_utgo_rev,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_yield_utgo_sample, r2_2012_yield_utgo_sample, r3_2012_yield_utgo_sample, r4_2012_yield_utgo_sample,
  headers = c('All', 'UTGO', 'LTGO', 'Revenue'),
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & Wtd. Avg. Yield Spread & Wtd. Avg. Yield Spread (UTGO) & Wtd. Avg. Yield Spread (LTGO) & Wtd. Avg. Yield Spread (Rev)\\\\',
  paste0(' & ', '\\', 'multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel B: Yield spreads, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2012_utgo_only.tex'))

#----------------------------
# 2012 full sample yield spreads: all city GO vote variation
#----------------------------
yield_2012_full_all <- write_full_sample_yield_tables(full_sample_2012, 2012)
write_policy_yield_table(yield_2012_full_all, 2012)

full_sample_2012 <- full_sample_2012_unrestricted

#----------------------------
# 2012 Census debt stock: GO vote required
#----------------------------
r1_2012_census_debt_allgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r2_2012_census_debt_allgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r3_2012_census_debt_allgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

r4_2012_census_debt_allgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_census_debt_allgo, r2_2012_census_debt_allgo, r3_2012_census_debt_allgo, r4_2012_census_debt_allgo,
  headers = c('Total', 'Long-term', 'Per capita', 'GO + Revenue'),
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
modified_output <- sub(
  ' & ln(1 + Census Total Debt) & ln(1 + Census Long-Term Debt) & ln(1 + Census Total Debt per Capita) & ln(1 + Mergent GO + Revenue Debt)\\\\',
  paste0(' & ', '\\', 'multicolumn{3}{c}{ln(1 + Census Debt)} & ', '\\', 'multicolumn{1}{c}{ln(1 + Mergent Debt)}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & Per capita & GO + Revenue \\\\',
  ' & Total & Long-term & Per capita & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2012_allgo.tex'))

#----------------------------
# 2012 Census debt stock: only UTGO vote required
#----------------------------
r1_2012_census_debt_utgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r2_2012_census_debt_utgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r3_2012_census_debt_utgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

r4_2012_census_debt_utgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_census_debt_utgo, r2_2012_census_debt_utgo, r3_2012_census_debt_utgo, r4_2012_census_debt_utgo,
  headers = c('Total', 'Long-term', 'Per capita', 'GO + Revenue'),
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & ln(1 + Census Total Debt) & ln(1 + Census Long-Term Debt) & ln(1 + Census Total Debt per Capita) & ln(1 + Mergent GO + Revenue Debt)\\\\',
  paste0(' & ', '\\', 'multicolumn{3}{c}{ln(1 + Census Debt)} & ', '\\', 'multicolumn{1}{c}{ln(1 + Mergent Debt)}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & Per capita & GO + Revenue \\\\',
  ' & Total & Long-term & Per capita & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2012_utgo_only.tex'))

#----------------------------
# 2012 Census debt stock: all city GO vote variation
#----------------------------
r1_2012_census_debt_full <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)

r2_2012_census_debt_full <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)

r3_2012_census_debt_full <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)

r4_2012_census_debt_full <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r1_2012_census_debt_full, r2_2012_census_debt_full, r3_2012_census_debt_full, r4_2012_census_debt_full,
  headers = c('Total', 'Long-term', 'Per capita', 'GO + Revenue'),
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
modified_output <- sub(
  ' & ln(1 + Census Total Debt) & ln(1 + Census Long-Term Debt) & ln(1 + Census Total Debt per Capita) & ln(1 + Mergent GO + Revenue Debt)\\\\',
  paste0(' & ', '\\', 'multicolumn{3}{c}{ln(1 + Census Debt)} & ', '\\', 'multicolumn{1}{c}{ln(1 + Mergent Debt)}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  ' & Total & Long-term & Per capita & GO + Revenue \\\\',
  ' & Total & Long-term & Per capita & GO + Revenue \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-5}',
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2012_full_sample.tex'))

#----------------------------
# 2012 PPML debt stock: GO vote required
#----------------------------
p1_2012_census_debt_allgo <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p1_2012_census_debt_allgo)

p2_2012_census_debt_allgo <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p2_2012_census_debt_allgo)

p3_2012_census_debt_allgo <- fepois(
  census_total_debt_per_capita ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p3_2012_census_debt_allgo)

p4_2012_census_debt_allgo <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(p4_2012_census_debt_allgo)

table_call <- etable(
  p1_2012_census_debt_allgo, p2_2012_census_debt_allgo, p4_2012_census_debt_allgo,
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
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_poisson_2012_allgo.tex'))

#----------------------------
# 2012 PPML debt stock: only UTGO vote required
#----------------------------
p1_2012_census_debt_utgo <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p1_2012_census_debt_utgo)

p2_2012_census_debt_utgo <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p2_2012_census_debt_utgo)

p3_2012_census_debt_utgo <- fepois(
  census_total_debt_per_capita ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p3_2012_census_debt_utgo)

p4_2012_census_debt_utgo <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(p4_2012_census_debt_utgo)

table_call <- etable(
  p1_2012_census_debt_utgo, p2_2012_census_debt_utgo, p4_2012_census_debt_utgo,
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
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
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_poisson_2012_utgo_only.tex'))

#----------------------------
# 2012 PPML debt stock: all city GO vote variation
#----------------------------
p1_2012_census_debt_full <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)
summary(p1_2012_census_debt_full)

p2_2012_census_debt_full <- fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)
summary(p2_2012_census_debt_full)

p3_2012_census_debt_full <- fepois(
  census_total_debt_per_capita ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)
summary(p3_2012_census_debt_full)

p4_2012_census_debt_full <- fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~state)
)
summary(p4_2012_census_debt_full)

table_call <- etable(
  p1_2012_census_debt_full, p2_2012_census_debt_full, p4_2012_census_debt_full,
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
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_poisson_2012_full_sample.tex'))

#----------------------------
# 2012 border-state test
#----------------------------
border_2012 <- fread(
  file.path(root, 'Data/Clean_Intermediate/Census COG Finance/processed/census_mergent_debt_cross_section_2012_border_sample.csv')
)

border_2012[, fips := as.character(fips)]
if ('nh_city' %in% names(border_2012)) {
  border_2012 <- border_2012[!(state == 'NH' & nh_city == 0)]
} else {
  border_2012 <- border_2012[!(state == 'NH' & government_type_label == 'township')]
}
border_2012[state == 'ME', city_go_vote := NA_real_]
border_2012 <- border_2012[!is.na(city_go_vote)]
add_low_state_tax_privilege(border_2012, year_value = 2012)
border_2012[, frac_utgo_outstanding := mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
border_2012[, frac_ltgo_outstanding := mergent_ltgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
border_2012[, frac_rev_outstanding := mergent_revenue_outstanding_debt / mergent_go_revenue_outstanding_debt]
border_2012[mergent_go_revenue_outstanding_debt <= 0, `:=`(
  frac_utgo_outstanding = NA_real_,
  frac_ltgo_outstanding = NA_real_,
  frac_rev_outstanding = NA_real_
)]
border_2012[, ln_1p_census_total_debt := log1p(census_total_debt_mil * 1000000)]
border_2012[, ln_census_population := log(census_population)]
border_2012[, state_year := interaction(state, year, drop = TRUE)]

border_2012 <- filter_debt_yield_border_pairs(border_2012, 'border_group')

border_2012 <- border_2012[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

border_2012 <- border_2012[
  !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]

r1_2012_border <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~state_year)
)

r4_2012_border <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc  +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated + mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue +
    state_go_vote + low_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~state_year)
)

p1_2012_border <- fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~state_year)
)

table_call <- etable(
  r1_2012_border, r4_2012_border, p1_2012_border,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(control_dict, city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State-Year')
modified_output <- modified_output[!trimws(modified_output) %in% c('& \\\\', '\\\\')]
modified_output <- add_panel(modified_output, 'Panel E: Border-state sample', ncols = 4)
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_border_state_2012.tex'))
