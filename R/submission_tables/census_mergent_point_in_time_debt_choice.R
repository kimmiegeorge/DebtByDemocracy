# Point-in-time Census/Mergent debt choice regressions
rm(list = ls())

library(pacman)
p_load(data.table, fixest)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables'

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
  composition_contribution = 'Composition',
  within_yield_contribution = 'Within-type yield',
  total_contribution = 'Total contribution',
  total_yield_effect = 'Full-sample yield effect',
  census_total_debt_mil = 'Census Total Debt',
  any_census_total_debt = 'Any Census Total Debt',
  ln_census_total_debt_mil_pos = 'ln(Census Total Debt)',
  census_lt_debt_mil = 'Census Long-Term Debt',
  any_census_lt_debt = 'Any Census Long-Term Debt',
  ln_census_lt_debt_mil_pos = 'ln(Census Long-Term Debt)',
  census_total_debt_per_capita = 'Census Total Debt per Capita',
  mergent_go_revenue_outstanding_debt_mil = 'Mergent GO + Revenue Debt',
  any_mergent_go_revenue_outstanding_debt = 'Any Mergent GO + Revenue Debt',
  ln_mergent_go_revenue_outstanding_debt_mil_pos = 'ln(Mergent GO + Revenue Debt)',
  ln_1p_census_total_debt = 'ln(1 + Census Total Debt)',
  ln_1p_county_nonmunicipal_total_debt = 'ln(1 + County Noncity Debt)',
  ln_1p_census_lt_debt = 'ln(1 + Census Long-Term Debt)',
  ln_1p_census_total_debt_pc = 'ln(1 + Census Total Debt per Capita)',
  ln_1p_mergent_go_revenue_outstanding_debt = 'ln(1 + Mergent GO + Revenue Debt)',
  mergent_wavg_original_maturity_years_go_revenue = 'Wtd. Avg. Original Maturity',
  mergent_wavg_original_maturity_years_all_go = 'Wtd. Avg. Original Maturity (GO)',
  mergent_wavg_original_maturity_years_utgo = 'Wtd. Avg. Original Maturity (UTGO)',
  mergent_wavg_original_maturity_years_ltgo = 'Wtd. Avg. Original Maturity (LTGO)',
  mergent_wavg_original_maturity_years_revenue = 'Wtd. Avg. Original Maturity (Rev)',
  mergent_wavg_rating_go_revenue_rated = 'Wtd. Avg. Rating',
  mergent_wavg_rating_all_go_rated = 'Wtd. Avg. Rating (GO)',
  mergent_wavg_rating_utgo_rated = 'Wtd. Avg. Rating (UTGO)',
  mergent_wavg_rating_ltgo_rated = 'Wtd. Avg. Rating (LTGO)',
  mergent_wavg_rating_revenue_rated = 'Wtd. Avg. Rating (Rev)',
  wavg_original_maturity = 'Wtd. Avg. Original Maturity',
  wavg_rating = 'Wtd. Avg. Rating',
  city_go_vote = 'GO Vote',
  high_state_tax_privilege = 'High Tax Priv.',
  state_go_vote = 'State GO Vote',
  state_ltgo_allowed = 'LTGO Allowed',
  glm_proactive = 'Proactive State',
  ln_gdp = 'County ln(GDP)',
  ln_census_population = 'City ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  fips = 'County',
  border_group = 'State-Border'
)

write_debt_decomposition_table <- function(sample_data, vote_label, panel_label, output_file) {
  total_ppml <- fepois(
    census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~fips)
  )
  total_any <- feols(
    any_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~fips)
  )
  total_log <- feols(
    ln_census_total_debt_mil_pos ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data[census_total_debt_mil > 0],
    vcov = vcov_cluster(~fips)
  )

  lt_ppml <- fepois(
    census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~fips)
  )
  lt_any <- feols(
    any_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~fips)
  )
  lt_log <- feols(
    ln_census_lt_debt_mil_pos ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data[census_lt_debt_mil > 0],
    vcov = vcov_cluster(~fips)
  )

  mergent_ppml <- fepois(
    mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~fips)
  )
  mergent_any <- feols(
    any_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data,
    vcov = vcov_cluster(~fips)
  )
  mergent_log <- feols(
    ln_mergent_go_revenue_outstanding_debt_mil_pos ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = sample_data[mergent_go_revenue_outstanding_debt_mil > 0],
    vcov = vcov_cluster(~fips)
  )

  table_call <- etable(
    total_ppml, total_any, total_log,
    lt_ppml, lt_any, lt_log,
    mergent_ppml, mergent_any, mergent_log,
    headers = rep(c('PPML', 'Any debt', 'Log debt'), 3),
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
    dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = vote_label),
    placement = 'H'
  )

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- sub(
    ' & Census Total Debt & Any Census Total Debt & ln(Census Total Debt) & Census Long-Term Debt & Any Census Long-Term Debt & ln(Census Long-Term Debt) & Mergent GO + Revenue Debt & Any Mergent GO + Revenue Debt & ln(Mergent GO + Revenue Debt)\\\\',
    paste0(
      ' & ', '\\', 'multicolumn{3}{c}{Census Total Debt} & ',
      '\\', 'multicolumn{3}{c}{Census Long-Term Debt} & ',
      '\\', 'multicolumn{3}{c}{Mergent GO + Revenue Debt}\\\\'
    ),
    modified_output,
    fixed = TRUE
  )
  modified_output <- sub(
    ' & PPML & Any debt & Log debt & PPML & Any debt & Log debt & PPML & Any debt & Log debt \\\\',
    ' & PPML & Any debt & Log debt & PPML & Any debt & Log debt & PPML & Any debt & Log debt \\\\\n   \\\\cmidrule(lr){2-4}\\cmidrule(lr){5-7}\\cmidrule(lr){8-10}',
    modified_output,
    fixed = TRUE
  )
  modified_output <- format_table(modified_output, cluster_level = 'County')
  modified_output <- add_panel(modified_output, panel_label)
  writeLines(modified_output, file.path(tbl_dir, output_file))
}

write_yield_composition_decomposition <- function(sample_data, year_label, output_stub) {
  decomposition_sample <- copy(sample_data)
  decomposition_sample <- decomposition_sample[
    !is.na(frac_utgo_outstanding) &
      !is.na(frac_ltgo_outstanding) &
      !is.na(frac_rev_outstanding)
  ]

  yield_all <- copy(decomposition_sample)
  yield_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
  yield_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

  yield_utgo <- copy(decomposition_sample)
  yield_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
  yield_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

  yield_ltgo <- copy(decomposition_sample)
  yield_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
  yield_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

  yield_rev <- copy(decomposition_sample)
  yield_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
  yield_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

  total_yield_model <- feols(
    mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
      glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = yield_all,
    vcov = vcov_cluster(~fips)
  )

  share_utgo_model <- feols(
    frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = decomposition_sample,
    vcov = vcov_cluster(~fips)
  )
  share_ltgo_model <- feols(
    frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = decomposition_sample,
    vcov = vcov_cluster(~fips)
  )
  share_rev_model <- feols(
    frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = decomposition_sample,
    vcov = vcov_cluster(~fips)
  )

  yield_utgo_model <- feols(
    mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
      glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = yield_utgo,
    vcov = vcov_cluster(~fips)
  )
  yield_ltgo_model <- feols(
    mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
      glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = yield_ltgo,
    vcov = vcov_cluster(~fips)
  )
  yield_rev_model <- feols(
    mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
      glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
    data = yield_rev,
    vcov = vcov_cluster(~fips)
  )

  share_effects <- c(
    UTGO = coef(share_utgo_model)['city_go_vote'],
    LTGO = coef(share_ltgo_model)['city_go_vote'],
    Revenue = coef(share_rev_model)['city_go_vote']
  )
  yield_effects <- c(
    UTGO = coef(yield_utgo_model)['city_go_vote'],
    LTGO = coef(yield_ltgo_model)['city_go_vote'],
    Revenue = coef(yield_rev_model)['city_go_vote']
  )
  mean_shares <- c(
    UTGO = mean(decomposition_sample$frac_utgo_outstanding, na.rm = TRUE),
    LTGO = mean(decomposition_sample$frac_ltgo_outstanding, na.rm = TRUE),
    Revenue = mean(decomposition_sample$frac_rev_outstanding, na.rm = TRUE)
  )
  mean_yields <- c(
    UTGO = mean(decomposition_sample$mergent_wavg_yield_spread_utgo, na.rm = TRUE),
    LTGO = mean(decomposition_sample$mergent_wavg_yield_spread_ltgo, na.rm = TRUE),
    Revenue = mean(decomposition_sample$mergent_wavg_yield_spread_revenue, na.rm = TRUE)
  )

  decomposition <- data.table(
    year = year_label,
    component = c('UTGO', 'LTGO', 'Revenue'),
    mean_share = as.numeric(mean_shares),
    go_vote_share_effect = as.numeric(share_effects),
    mean_type_yield_spread = as.numeric(mean_yields),
    go_vote_type_yield_effect = as.numeric(yield_effects)
  )
  decomposition[, composition_contribution := go_vote_share_effect * mean_type_yield_spread]
  decomposition[, within_yield_contribution := mean_share * go_vote_type_yield_effect]
  decomposition[, total_contribution := composition_contribution + within_yield_contribution]
  decomposition[, total_yield_effect := as.numeric(coef(total_yield_model)['city_go_vote'])]

  summary_rows <- decomposition[
    ,
    .(
      mean_share = sum(mean_share, na.rm = TRUE),
      go_vote_share_effect = sum(go_vote_share_effect, na.rm = TRUE),
      mean_type_yield_spread = NA_real_,
      go_vote_type_yield_effect = NA_real_,
      composition_contribution = sum(composition_contribution, na.rm = TRUE),
      within_yield_contribution = sum(within_yield_contribution, na.rm = TRUE),
      total_contribution = sum(total_contribution, na.rm = TRUE),
      total_yield_effect = total_yield_effect[1]
    )
  ]
  summary_rows[, `:=`(year = year_label, component = 'Total')]
  decomposition <- rbindlist(list(decomposition, summary_rows), use.names = TRUE)
  decomposition[, residual_gap := total_yield_effect - total_contribution]
  fwrite(decomposition, file.path(tbl_dir, paste0(output_stub, '.csv')))

  table_data <- transpose(
    decomposition[
      ,
      .(
        Composition = composition_contribution,
        `Within-type yield` = within_yield_contribution,
        `Total contribution` = total_contribution
      )
    ],
    keep.names = 'channel'
  )
  setnames(table_data, c('channel', decomposition$component))
  table_data[, channel := c('Composition', 'Within-type yield', 'Total contribution')]
  table_data[, `Full-sample yield effect` := c(NA_real_, NA_real_, decomposition[component == 'Total', total_yield_effect])]
  table_data[, Residual := c(NA_real_, NA_real_, decomposition[component == 'Total', residual_gap])]

  tex_lines <- c(
    '\\begingroup',
    '\\centering',
    '\\begin{tabular}{lrrrrr}',
    paste0('\\multicolumn{6}{l}{\\textbf{Panel C: Yield-spread decomposition, full sample (', year_label, ')}}\\\\'),
    '\\toprule',
    'Channel & UTGO & LTGO & Revenue & Total & Full-sample effect\\\\',
    '\\midrule',
    sprintf(
      '%s & %.3f & %.3f & %.3f & %.3f & \\\\',
      table_data$channel[1],
      table_data$UTGO[1],
      table_data$LTGO[1],
      table_data$Revenue[1],
      table_data$Total[1]
    ),
    sprintf(
      '%s & %.3f & %.3f & %.3f & %.3f & \\\\',
      table_data$channel[2],
      table_data$UTGO[2],
      table_data$LTGO[2],
      table_data$Revenue[2],
      table_data$Total[2]
    ),
    sprintf(
      '%s & %.3f & %.3f & %.3f & %.3f & %.3f\\\\',
      table_data$channel[3],
      table_data$UTGO[3],
      table_data$LTGO[3],
      table_data$Revenue[3],
      table_data$Total[3],
      table_data$`Full-sample yield effect`[3]
    ),
    '\\bottomrule',
    '\\end{tabular}',
    '\\par\\endgroup'
  )
  writeLines(tex_lines, file.path(tbl_dir, paste0(output_stub, '.tex')))
}


#==============================================================================
# 2017 main cross section
#==============================================================================

#----------------------------
# Load and clean 2017 data
#----------------------------
data_2017 <- fread(
  file.path(root, 'Data/Census COG Finance/processed/census_mergent_debt_cross_section_2017.csv')
)

data_2017[, fips := as.character(fips)]
if ('nh_city' %in% names(data_2017)) {
  data_2017 <- data_2017[!(state == 'NH' & nh_city == 0)]
} else {
  data_2017 <- data_2017[!(state == 'NH' & government_type_label == 'township')]
}
data_2017[state == 'ME', city_go_vote := NA_real_]
data_2017 <- data_2017[!is.na(city_go_vote)]

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
data_2017[, any_census_total_debt := as.integer(census_total_debt_mil > 0)]
data_2017[, any_census_lt_debt := as.integer(census_lt_debt_mil > 0)]
data_2017[, any_mergent_go_revenue_outstanding_debt := as.integer(mergent_go_revenue_outstanding_debt_mil > 0)]
data_2017[, ln_census_total_debt_mil_pos := fifelse(census_total_debt_mil > 0, log(census_total_debt_mil), NA_real_)]
data_2017[, ln_census_lt_debt_mil_pos := fifelse(census_lt_debt_mil > 0, log(census_lt_debt_mil), NA_real_)]
data_2017[, ln_mergent_go_revenue_outstanding_debt_mil_pos := fifelse(
  mergent_go_revenue_outstanding_debt_mil > 0,
  log(mergent_go_revenue_outstanding_debt_mil),
  NA_real_
)]
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
    !is.na(high_state_tax_privilege)
]

#----------------------------
# 2017 full sample debt substitution: GO vote required
#----------------------------
r1_2017_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_allgo)

r2_2017_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_allgo)

r3_2017_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_allgo)

r4_2017_allgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r4_2017_allgo)

r5_2017_allgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
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
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel A: GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2017_allgo.tex'))

#----------------------------
# 2017 full sample debt substitution: only UTGO vote required
#----------------------------
r1_2017_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_utgo)

r2_2017_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_utgo)

r3_2017_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_utgo)

r4_2017_utgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r4_2017_utgo)

r5_2017_utgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Only UTGO Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2017_utgo_only.tex'))

#----------------------------
# 2017 full sample yield spreads: GO vote required
#----------------------------
yield_2017_allgo_all <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
yield_2017_allgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

yield_2017_allgo_utgo <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
yield_2017_allgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

yield_2017_allgo_ltgo <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
yield_2017_allgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

yield_2017_allgo_rev <- copy(full_sample_2017[insample_allgo == 1])
yield_2017_allgo_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
yield_2017_allgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

r1_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_allgo_all,
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_yield_allgo_sample)

r2_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_allgo_utgo,
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_yield_allgo_sample)

r3_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_allgo_ltgo,
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_yield_allgo_sample)

r4_2017_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_allgo_rev,
  vcov = vcov_cluster(~fips)
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel A: Yield spreads, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2017_allgo.tex'))

#----------------------------
# 2017 full sample yield spreads: only UTGO vote required
#----------------------------
yield_2017_utgo_all <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
yield_2017_utgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

yield_2017_utgo_utgo <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
yield_2017_utgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

yield_2017_utgo_ltgo <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
yield_2017_utgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

yield_2017_utgo_rev <- copy(full_sample_2017[insample_utgo_only == 1])
yield_2017_utgo_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
yield_2017_utgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

r1_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2017_utgo_all,
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_yield_utgo_sample)

r2_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2017_utgo_utgo,
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_yield_utgo_sample)

r3_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2017_utgo_ltgo,
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_yield_utgo_sample)

r4_2017_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2017_utgo_rev,
  vcov = vcov_cluster(~fips)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Only UTGO Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & Wtd. Avg. Yield Spread & Wtd. Avg. Yield Spread (UTGO) & Wtd. Avg. Yield Spread (LTGO) & Wtd. Avg. Yield Spread (Rev)\\\\',
  paste0(' & ', '\\', 'multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel B: Yield spreads, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2017_utgo_only.tex'))

#----------------------------
# 2017 full sample yield spreads: all city GO vote variation
#----------------------------
yield_2017_full_all <- copy(full_sample_2017)
yield_2017_full_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
yield_2017_full_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

yield_2017_full_utgo <- copy(full_sample_2017)
yield_2017_full_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
yield_2017_full_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

yield_2017_full_ltgo <- copy(full_sample_2017)
yield_2017_full_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
yield_2017_full_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

yield_2017_full_rev <- copy(full_sample_2017)
yield_2017_full_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
yield_2017_full_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

r1_2017_yield_full_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_full_all,
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_yield_full_sample)

r2_2017_yield_full_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_full_utgo,
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_yield_full_sample)

r3_2017_yield_full_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_full_ltgo,
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_yield_full_sample)

r4_2017_yield_full_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2017_full_rev,
  vcov = vcov_cluster(~fips)
)
summary(r4_2017_yield_full_sample)

table_call <- etable(
  r1_2017_yield_full_sample, r2_2017_yield_full_sample, r3_2017_yield_full_sample, r4_2017_yield_full_sample,
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel C: Yield spreads, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2017_full_sample.tex'))

write_yield_composition_decomposition(
  sample_data = full_sample_2017,
  year_label = '2017',
  output_stub = 'point_in_time_yield_spread_decomposition_2017_full_sample'
)

#----------------------------
# 2017 Census debt stock: GO vote required
#----------------------------
r1_2017_census_debt_allgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_census_debt_allgo)

r2_2017_census_debt_allgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_census_debt_allgo)

r3_2017_census_debt_allgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_census_debt_allgo)

r4_2017_census_debt_allgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2017_allgo.tex'))

#----------------------------
# 2017 Census debt stock: only UTGO vote required
#----------------------------
r1_2017_census_debt_utgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_census_debt_utgo)

r2_2017_census_debt_utgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_census_debt_utgo)

r3_2017_census_debt_utgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_census_debt_utgo)

r4_2017_census_debt_utgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Only UTGO Vote'),
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2017_utgo_only.tex'))

#----------------------------
# 2017 Census debt stock: all city GO vote variation
#----------------------------
r1_2017_census_debt_full <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~fips)
)
summary(r1_2017_census_debt_full)

r2_2017_census_debt_full <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~fips)
)
summary(r2_2017_census_debt_full)

r3_2017_census_debt_full <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~fips)
)
summary(r3_2017_census_debt_full)

r4_2017_census_debt_full <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2017,
  vcov = vcov_cluster(~fips)
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2017_full_sample.tex'))

#----------------------------
# 2017 debt stock decomposition
#----------------------------
write_debt_decomposition_table(
  sample_data = full_sample_2017[insample_allgo == 1],
  vote_label = 'GO Vote',
  panel_label = 'Panel D: Debt stock decomposition, GO vote required',
  output_file = 'point_in_time_census_debt_poisson_2017_allgo.tex'
)

write_debt_decomposition_table(
  sample_data = full_sample_2017[insample_utgo_only == 1],
  vote_label = 'Only UTGO Vote',
  panel_label = 'Panel D: Debt stock decomposition, only UTGO vote required',
  output_file = 'point_in_time_census_debt_poisson_2017_utgo_only.tex'
)

write_debt_decomposition_table(
  sample_data = full_sample_2017,
  vote_label = 'GO Vote',
  panel_label = 'Panel D: Debt stock decomposition, full sample',
  output_file = 'point_in_time_census_debt_poisson_2017_full_sample.tex'
)

#----------------------------
# 2017 border-state test
#----------------------------
border_2017 <- fread(
  file.path(root, 'Data/Census COG Finance/processed/census_mergent_debt_cross_section_2017_border_sample.csv')
)

border_2017[, fips := as.character(fips)]
if ('nh_city' %in% names(border_2017)) {
  border_2017 <- border_2017[!(state == 'NH' & nh_city == 0)]
} else {
  border_2017 <- border_2017[!(state == 'NH' & government_type_label == 'township')]
}
border_2017[state == 'ME', city_go_vote := NA_real_]
border_2017 <- border_2017[!is.na(city_go_vote)]
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

border_2017 <- border_2017[
  !is.na(border_group) &
    border_group != 'Rhode Island/Massachusetts' & border_group != 'Maine/New Hampshire'
    #!(border_group %in% c('Ohio/Kentucky', 'Michigan/Wisconsin', 'Maine/New Hampshire'))
]

border_2017 <- border_2017[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(state_go_vote) &
    !is.na(high_state_tax_privilege)
]

r1_2017_border <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~fips)
)

r2_2017_border <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~fips)
)

r3_2017_border <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~fips)
)

r4_2017_border <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_rated + mergent_wavg_original_maturity_years_go_revenue +
    state_go_vote + high_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~fips)
)

r5_2017_border <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2017,
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r1_2017_border, r3_2017_border, r4_2017_border, r5_2017_border,
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
  dict = c(control_dict, city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel E: Border-state sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_border_state_2017.tex'))


#==============================================================================
# 2012 robustness cross section
#==============================================================================

#----------------------------
# Load and clean 2012 data
#----------------------------
data_2012 <- fread(
  file.path(root, 'Data/Census COG Finance/processed/census_mergent_debt_cross_section_2012.csv')
)

data_2012[, fips := as.character(fips)]
if ('nh_city' %in% names(data_2012)) {
  data_2012 <- data_2012[!(state == 'NH' & nh_city == 0)]
} else {
  data_2012 <- data_2012[!(state == 'NH' & government_type_label == 'township')]
}
data_2012[state == 'ME', city_go_vote := NA_real_]
data_2012 <- data_2012[!is.na(city_go_vote)]

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
data_2012[, any_census_total_debt := as.integer(census_total_debt_mil > 0)]
data_2012[, any_census_lt_debt := as.integer(census_lt_debt_mil > 0)]
data_2012[, any_mergent_go_revenue_outstanding_debt := as.integer(mergent_go_revenue_outstanding_debt_mil > 0)]
data_2012[, ln_census_total_debt_mil_pos := fifelse(census_total_debt_mil > 0, log(census_total_debt_mil), NA_real_)]
data_2012[, ln_census_lt_debt_mil_pos := fifelse(census_lt_debt_mil > 0, log(census_lt_debt_mil), NA_real_)]
data_2012[, ln_mergent_go_revenue_outstanding_debt_mil_pos := fifelse(
  mergent_go_revenue_outstanding_debt_mil > 0,
  log(mergent_go_revenue_outstanding_debt_mil),
  NA_real_
)]
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
    !is.na(high_state_tax_privilege)
]

#----------------------------
# 2012 full sample debt substitution: GO vote required
#----------------------------
r1_2012_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r2_2012_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r3_2012_allgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r4_2012_allgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r5_2012_allgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
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
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel A: GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2012_allgo.tex'))

#----------------------------
# 2012 full sample debt substitution: only UTGO vote required
#----------------------------
r1_2012_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r2_2012_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r3_2012_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r4_2012_utgo <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r5_2012_utgo <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Only UTGO Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_debt_choice_2012_utgo_only.tex'))

#----------------------------
# 2012 full sample yield spreads: GO vote required
#----------------------------
yield_2012_allgo_all <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
yield_2012_allgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

yield_2012_allgo_utgo <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
yield_2012_allgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

yield_2012_allgo_ltgo <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
yield_2012_allgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

yield_2012_allgo_rev <- copy(full_sample_2012[insample_allgo == 1])
yield_2012_allgo_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
yield_2012_allgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

r1_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_allgo_all,
  vcov = vcov_cluster(~fips)
)

r2_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_allgo_utgo,
  vcov = vcov_cluster(~fips)
)

r3_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_allgo_ltgo,
  vcov = vcov_cluster(~fips)
)

r4_2012_yield_allgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_allgo_rev,
  vcov = vcov_cluster(~fips)
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel A: Yield spreads, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2012_allgo.tex'))

#----------------------------
# 2012 full sample yield spreads: only UTGO vote required
#----------------------------
yield_2012_utgo_all <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
yield_2012_utgo_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

yield_2012_utgo_utgo <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
yield_2012_utgo_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

yield_2012_utgo_ltgo <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
yield_2012_utgo_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

yield_2012_utgo_rev <- copy(full_sample_2012[insample_utgo_only == 1])
yield_2012_utgo_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
yield_2012_utgo_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

r1_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2012_utgo_all,
  vcov = vcov_cluster(~fips)
)

r2_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2012_utgo_utgo,
  vcov = vcov_cluster(~fips)
)

r3_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2012_utgo_ltgo,
  vcov = vcov_cluster(~fips)
)

r4_2012_yield_utgo_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_go_vote + high_state_tax_privilege,
  data = yield_2012_utgo_rev,
  vcov = vcov_cluster(~fips)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Only UTGO Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- sub(
  ' & Wtd. Avg. Yield Spread & Wtd. Avg. Yield Spread (UTGO) & Wtd. Avg. Yield Spread (LTGO) & Wtd. Avg. Yield Spread (Rev)\\\\',
  paste0(' & ', '\\', 'multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\'),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel B: Yield spreads, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2012_utgo_only.tex'))

#----------------------------
# 2012 full sample yield spreads: all city GO vote variation
#----------------------------
yield_2012_full_all <- copy(full_sample_2012)
yield_2012_full_all[, wavg_rating := mergent_wavg_rating_go_revenue_rated]
yield_2012_full_all[, wavg_original_maturity := mergent_wavg_original_maturity_years_go_revenue]

yield_2012_full_utgo <- copy(full_sample_2012)
yield_2012_full_utgo[, wavg_rating := mergent_wavg_rating_utgo_rated]
yield_2012_full_utgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_utgo]

yield_2012_full_ltgo <- copy(full_sample_2012)
yield_2012_full_ltgo[, wavg_rating := mergent_wavg_rating_ltgo_rated]
yield_2012_full_ltgo[, wavg_original_maturity := mergent_wavg_original_maturity_years_ltgo]

yield_2012_full_rev <- copy(full_sample_2012)
yield_2012_full_rev[, wavg_rating := mergent_wavg_rating_revenue_rated]
yield_2012_full_rev[, wavg_original_maturity := mergent_wavg_original_maturity_years_revenue]

r1_2012_yield_full_sample <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_full_all,
  vcov = vcov_cluster(~fips)
)

r2_2012_yield_full_sample <- feols(
  mergent_wavg_yield_spread_utgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_full_utgo,
  vcov = vcov_cluster(~fips)
)

r3_2012_yield_full_sample <- feols(
  mergent_wavg_yield_spread_ltgo ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_full_ltgo,
  vcov = vcov_cluster(~fips)
)

r4_2012_yield_full_sample <- feols(
  mergent_wavg_yield_spread_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + wavg_rating + wavg_original_maturity +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = yield_2012_full_rev,
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r1_2012_yield_full_sample, r2_2012_yield_full_sample, r3_2012_yield_full_sample, r4_2012_yield_full_sample,
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel C: Yield spreads, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_yield_spread_2012_full_sample.tex'))

write_yield_composition_decomposition(
  sample_data = full_sample_2012,
  year_label = '2012',
  output_stub = 'point_in_time_yield_spread_decomposition_2012_full_sample'
)

#----------------------------
# 2012 Census debt stock: GO vote required
#----------------------------
r1_2012_census_debt_allgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r2_2012_census_debt_allgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r3_2012_census_debt_allgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
)

r4_2012_census_debt_allgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_allgo == 1],
  vcov = vcov_cluster(~fips)
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2012_allgo.tex'))

#----------------------------
# 2012 Census debt stock: only UTGO vote required
#----------------------------
r1_2012_census_debt_utgo <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r2_2012_census_debt_utgo <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r3_2012_census_debt_utgo <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
)

r4_2012_census_debt_utgo <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012[insample_utgo_only == 1],
  vcov = vcov_cluster(~fips)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Only UTGO Vote'),
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2012_utgo_only.tex'))

#----------------------------
# 2012 Census debt stock: all city GO vote variation
#----------------------------
r1_2012_census_debt_full <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~fips)
)

r2_2012_census_debt_full <- feols(
  ln_1p_census_lt_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~fips)
)

r3_2012_census_debt_full <- feols(
  ln_1p_census_total_debt_pc ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~fips)
)

r4_2012_census_debt_full <- feols(
  ln_1p_mergent_go_revenue_outstanding_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege,
  data = full_sample_2012,
  vcov = vcov_cluster(~fips)
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
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel D: Census debt stock, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_census_debt_2012_full_sample.tex'))

#----------------------------
# 2012 debt stock decomposition
#----------------------------
write_debt_decomposition_table(
  sample_data = full_sample_2012[insample_allgo == 1],
  vote_label = 'GO Vote',
  panel_label = 'Panel D: Debt stock decomposition, GO vote required',
  output_file = 'point_in_time_census_debt_poisson_2012_allgo.tex'
)

write_debt_decomposition_table(
  sample_data = full_sample_2012[insample_utgo_only == 1],
  vote_label = 'Only UTGO Vote',
  panel_label = 'Panel D: Debt stock decomposition, only UTGO vote required',
  output_file = 'point_in_time_census_debt_poisson_2012_utgo_only.tex'
)

write_debt_decomposition_table(
  sample_data = full_sample_2012,
  vote_label = 'GO Vote',
  panel_label = 'Panel D: Debt stock decomposition, full sample',
  output_file = 'point_in_time_census_debt_poisson_2012_full_sample.tex'
)

#----------------------------
# 2012 border-state test
#----------------------------
border_2012 <- fread(
  file.path(root, 'Data/Census COG Finance/processed/census_mergent_debt_cross_section_2012_border_sample.csv')
)

border_2012[, fips := as.character(fips)]
if ('nh_city' %in% names(border_2012)) {
  border_2012 <- border_2012[!(state == 'NH' & nh_city == 0)]
} else {
  border_2012 <- border_2012[!(state == 'NH' & government_type_label == 'township')]
}
border_2012[state == 'ME', city_go_vote := NA_real_]
border_2012 <- border_2012[!is.na(city_go_vote)]
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

border_2012 <- border_2012[
  !is.na(border_group) &
    border_group != 'Rhode Island/Massachusetts' &
    !(border_group %in% c('Ohio/Kentucky', 'Michigan/Wisconsin'))
]

border_2012 <- border_2012[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(state_go_vote) &
    !is.na(high_state_tax_privilege)
]

r1_2012_border <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~fips)
)

r2_2012_border <- feols(
  frac_ltgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~fips)
)

r3_2012_border <- feols(
  frac_rev_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~fips)
)

r4_2012_border <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_rated + mergent_wavg_original_maturity_years_go_revenue +
    state_go_vote + high_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~fips)
)

r5_2012_border <- feols(
  ln_1p_census_total_debt ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + high_state_tax_privilege | border_group,
  data = border_2012,
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r1_2012_border, r3_2012_border, r4_2012_border, r5_2012_border,
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
  dict = c(control_dict, city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'County')
modified_output <- add_panel(modified_output, 'Panel E: Border-state sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_border_state_2012.tex'))
