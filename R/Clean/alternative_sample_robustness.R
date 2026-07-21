# Robustness to the 2012 point-in-time and full-period aggregate measures
rm(list = ls())

library(data.table)
library(fixest)
library(haven)

# Resolve paths from this script so it can be run from any working directory.
file_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg) > 0) {
  normalizePath(sub('^--file=', '', file_arg[[1]]), mustWork = TRUE)
} else {
  normalizePath(file.path(getwd(), 'Code/R/Clean/alternative_sample_robustness.R'), mustWork = TRUE)
}
root <- normalizePath(file.path(dirname(script_path), '..', '..', '..'), mustWork = TRUE)

source(file.path(root, 'Code/R/Clean/modify_etable_rounding.R'))
source(file.path(root, 'Code/R/Clean/tax_privilege_definitions.R'))

tbl_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')
processed_dir <- file.path(root, 'Code/R/Clean/output/processed')
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

purpose_categories <- c(
  'utilities',
  'transportation',
  'recreation_amenities',
  'public_safety',
  'other_public_buildings'
)
purpose_headers <- c(
  'Utilities',
  'Transport.',
  'Recreation',
  'Public Safety',
  'Public Bldg.'
)

table_dict <- c(
  city_go_vote = 'Vote',
  frac_utgo_outstanding = 'Pct UTGO',
  frac_ltgo_outstanding = 'Pct LTGO',
  frac_rev_outstanding = 'Pct Revenue',
  frac_utgo = 'Pct UTGO',
  frac_ltgo = 'Pct LTGO',
  frac_rev = 'Pct Revenue',
  mergent_wavg_yield_spread_go_revenue = 'Wtd. Avg. Yield Spread',
  issuer_spread = 'Wtd. Avg. Yield Spread',
  share_revenue_vs_go_amount = 'Pct Revenue'
)

debt_2012_controls <- paste(
  'ln_gdp + ln_census_population + ln_pers_inc +',
  'ln_1p_county_nonmunicipal_total_debt + glm_proactive +',
  'state_ltgo_allowed + state_go_vote + low_state_tax_privilege'
)

aggregate_controls <- paste(
  'ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other +',
  'glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege'
)

purpose_2012_controls <- debt_2012_controls
aggregate_purpose_controls <- aggregate_controls

make_formula <- function(outcome, controls) {
  as.formula(paste(outcome, '~ city_go_vote +', controls))
}

write_robustness_panel <- function(models, headers, panel_title, output_file,
                                   treatment_label = 'Vote', fontsize = NULL) {
  panel_dict <- c(
    table_dict[names(table_dict) != 'city_go_vote'],
    city_go_vote = treatment_label
  )

  table_call <- etable(
    models,
    headers = headers,
    coefstat = 'tstat',
    keep_raw = '^city_go_vote$',
    order = '%city_go_vote',
    depvar = FALSE,
    style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
    fitstat = c('n', 'ar2'),
    se.below = TRUE,
    digits = 3,
    digits.stats = 3,
    signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
    tex = TRUE,
    dict = panel_dict,
    placement = 'H'
  )

  table_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  table_output <- format_table(
    table_output,
    cluster_level = 'State',
    drop_covariance = TRUE
  )
  table_output <- table_output[
    !trimws(table_output) %in% c('& \\\\', '\\\\')
  ]
  hline_idx <- grep('^[[:space:]]*\\\\hline[[:space:]]*$', table_output)
  if (length(hline_idx) == 0) {
    stop('Could not find the pre-statistics horizontal rule in ', output_file)
  }
  controls_row <- paste0(
    '   Controls       & ',
    paste(rep('Yes', length(models)), collapse = ' & '),
    '\\\\'
  )
  table_output <- append(table_output, controls_row, after = hline_idx[1])
  table_output <- add_panel(
    table_output,
    panel_title,
    ncols = length(models) + 1
  )
  if (!is.null(fontsize)) {
    table_output <- append(table_output, paste0('\\', fontsize), after = 1)
  }
  writeLines(table_output, file.path(tbl_dir, output_file))
}

#==============================================================================
# 2012 point-in-time debt choice and weighted-average yields
#==============================================================================

point_2012 <- fread(file.path(
  root,
  'Data/Clean_Intermediate/Census COG Finance/processed',
  'census_mergent_debt_cross_section_2012.csv'
))

point_2012[, fips := as.character(fips)]
if ('nh_city' %in% names(point_2012)) {
  point_2012 <- point_2012[!(state == 'NH' & nh_city == 0)]
} else {
  point_2012 <- point_2012[!(state == 'NH' & government_type_label == 'township')]
}
point_2012[state == 'ME', city_go_vote := NA_real_]
point_2012 <- point_2012[!is.na(city_go_vote)]
add_low_state_tax_privilege(point_2012)

point_2012[, `:=`(
  frac_utgo_outstanding = mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt,
  frac_ltgo_outstanding = mergent_ltgo_outstanding_debt / mergent_go_revenue_outstanding_debt,
  frac_rev_outstanding = mergent_revenue_outstanding_debt / mergent_go_revenue_outstanding_debt,
  ln_census_population = log(census_population)
)]
point_2012[mergent_go_revenue_outstanding_debt <= 0, `:=`(
  frac_utgo_outstanding = NA_real_,
  frac_ltgo_outstanding = NA_real_,
  frac_rev_outstanding = NA_real_
)]

point_2012 <- point_2012[
  insample == 1 &
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

#==============================================================================
# Full-period issuer aggregates
#==============================================================================

issuer_aggregate <- as.data.table(read_dta(file.path(
  root,
  'Data/Mergent/Clean/260716_city_issuerlevel_yieldspread.dta'
)))

# Use the paper's current NC/Garrett et al. weighted-average spread measure.
nc_spreads <- fread(file.path(
  root,
  'Data/Clean_Intermediate/Mergent/Clean/issuer_level_nc_yield_spreads.csv'
))
issuer_aggregate <- merge(
  issuer_aggregate,
  nc_spreads,
  by = c('state', 'seed_issuer'),
  all.x = TRUE,
  sort = FALSE
)
issuer_aggregate[, issuer_spread := issuer_spread_nc]

issuer_aggregate[state == 'RI', city_go_vote := NA_real_]
add_low_state_tax_privilege(issuer_aggregate)
issuer_aggregate <- issuer_aggregate[
  insample == 1 &
    !is.na(city_go_vote) &
    !is.na(ln_gdp) &
    !is.na(ln_pop) &
    !is.na(ln_pers_inc) &
    !is.na(ln_county_debt_other) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

aggregate_indicator_patterns <- c('insured', 'callable', 'sinkable')
available_aggregate_indicators <- grep(
  paste(aggregate_indicator_patterns, collapse = '|'),
  names(issuer_aggregate),
  value = TRUE,
  ignore.case = TRUE
)
if (length(available_aggregate_indicators) == 0) {
  message(
    'Issuer aggregate has no insured/callable/sinkable controls; ',
    'Panel C omits these indicators in the aggregate column.'
  )
}

#==============================================================================
# Panels A and B: debt choice
#==============================================================================

estimate_debt_models <- function(data, outcomes, controls, sample_flag) {
  lapply(outcomes, function(outcome) {
    feols(
      make_formula(outcome, controls),
      data = data[get(sample_flag) == 1],
      vcov = vcov_cluster(~state)
    )
  })
}

point_outcomes <- c(
  'frac_utgo_outstanding',
  'frac_ltgo_outstanding',
  'frac_rev_outstanding'
)
aggregate_outcomes <- c('frac_utgo', 'frac_ltgo', 'frac_rev')

panel_a_models <- c(
  estimate_debt_models(point_2012, point_outcomes, debt_2012_controls, 'insample_allgo'),
  estimate_debt_models(issuer_aggregate, aggregate_outcomes, aggregate_controls, 'insample_allgo')
)

panel_ab_headers <- list(
  '^ ' = list('2012 Point in Time' = 3, 'Full Sample Aggregate' = 3),
  '- ' = rep(c('UTGO', 'LTGO', 'Revenue'), 2)
)

write_robustness_panel(
  panel_a_models,
  headers = panel_ab_headers,
  panel_title = 'Panel A: Debt type, GO vote required',
  output_file = 'alternative_sample_robustness_panel_a_debt_choice_allgo.tex',
  treatment_label = 'GO Vote',
  fontsize = 'small'
)

panel_b_models <- c(
  estimate_debt_models(point_2012, point_outcomes, debt_2012_controls, 'insample_utgo_only'),
  estimate_debt_models(issuer_aggregate, aggregate_outcomes, aggregate_controls, 'insample_utgo_only')
)

write_robustness_panel(
  panel_b_models,
  headers = panel_ab_headers,
  panel_title = 'Panel B: Debt type, only UTGO vote required',
  output_file = 'alternative_sample_robustness_panel_b_debt_choice_utgo_only.tex',
  treatment_label = 'UTGO Only Vote',
  fontsize = 'small'
)

#==============================================================================
# Panel C: weighted-average yield spread
#==============================================================================

point_yield_2012 <- copy(point_2012)
point_yield_2012[, `:=`(
  wavg_rating = mergent_wavg_rating_go_revenue_zero_unrated,
  wavg_original_maturity = mergent_wavg_original_maturity_years_go_revenue,
  any_insured = mergent_any_insured_go_revenue,
  any_callable = mergent_any_callable_go_revenue,
  any_sinkable = mergent_any_sinkable_go_revenue
)]

point_yield_controls <- paste(
  debt_2012_controls,
  '+ wavg_rating + wavg_original_maturity + any_insured + any_callable + any_sinkable'
)

point_yield_model <- feols(
  make_formula('mergent_wavg_yield_spread_go_revenue', point_yield_controls),
  data = point_yield_2012,
  vcov = vcov_cluster(~state)
)

# The issuer aggregate contains weighted-average rating and maturity, but not
# the insured/callable/sinkable indicators used in the point-in-time model.
aggregate_yield_controls <- paste(
  aggregate_controls,
  '+ issuer_rating + issuer_mat'
)
aggregate_yield_model <- feols(
  make_formula('issuer_spread', aggregate_yield_controls),
  data = issuer_aggregate,
  vcov = vcov_cluster(~state)
)

write_robustness_panel(
  list(point_yield_model, aggregate_yield_model),
  headers = c('2012 Point in Time', 'Full Sample Aggregate'),
  panel_title = 'Panel C: Weighted average yield spread',
  output_file = 'alternative_sample_robustness_panel_c_yield_spread.tex',
  treatment_label = 'Vote'
)

#==============================================================================
# Panel D: 2012 point-in-time purpose substitution
#==============================================================================

purpose_2012 <- fread(file.path(
  root,
  'Data/DPC Data/Use Of Proceeds/Purposes Substitution',
  '260719_dpc_point_in_time_purpose_substitution_2012_issuer_category_panel.csv'
))

if ('nh_city' %in% names(purpose_2012)) {
  purpose_2012 <- purpose_2012[!(state == 'NH' & nh_city == 0)]
} else if ('government_type_label' %in% names(purpose_2012)) {
  purpose_2012 <- purpose_2012[!(state == 'NH' & government_type_label == 'township')]
} else {
  purpose_2012 <- purpose_2012[
    !(state == 'NH' & grepl('\\b(TOWN|TWP|TOWNSHIP)\\b', toupper(seed_issuer)))
  ]
}
purpose_2012[state == 'ME', city_go_vote := NA_real_]
add_low_state_tax_privilege(purpose_2012)
purpose_2012 <- purpose_2012[
  insample == 1 &
    purpose_category %in% purpose_categories &
    !is.na(city_go_vote) &
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

purpose_2012_models <- lapply(purpose_categories, function(category) {
  feols(
    make_formula('share_revenue_vs_go_amount', purpose_2012_controls),
    data = purpose_2012[purpose_category == category],
    vcov = vcov_cluster(~state)
  )
})

write_robustness_panel(
  purpose_2012_models,
  headers = purpose_headers,
  panel_title = 'Panel D: Purpose substitution, 2012 point in time',
  output_file = 'alternative_sample_robustness_panel_d_purpose_2012.tex',
  treatment_label = 'Vote',
  fontsize = 'small'
)

#==============================================================================
# Panel E: full-period aggregate purpose substitution
#==============================================================================

purpose_bonds <- fread(file.path(
  root,
  'Data/DPC Data/Use Of Proceeds/Purposes Substitution',
  '260707_dpc_purpose_substitution_cusip_category_panel.csv'
))
purpose_covered_issuers <- unique(
  purpose_bonds[go_any == 1 | revenue_bond == 1, .(state, seed_issuer)]
)
purpose_bonds <- purpose_bonds[purpose_category %in% purpose_categories]

purpose_amounts <- purpose_bonds[
  , .(
    category_amount = sum(ifelse(go_any == 1 | revenue_bond == 1, amount, 0), na.rm = TRUE),
    revenue_amount = sum(ifelse(revenue_bond == 1, amount, 0), na.rm = TRUE)
  ),
  by = .(state, seed_issuer, purpose_category)
]

issuer_purpose_controls <- unique(
  issuer_aggregate[, .(
    state,
    seed_issuer,
    seed_issuer_id,
    city_go_vote,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    low_state_tax_privilege
  )],
  by = c('state', 'seed_issuer')
)
issuer_purpose_controls <- purpose_covered_issuers[
  issuer_purpose_controls,
  on = .(state, seed_issuer),
  nomatch = 0
]

issuer_purpose <- issuer_purpose_controls[
  , .(purpose_category = purpose_categories),
  by = .(
    state,
    seed_issuer,
    seed_issuer_id,
    city_go_vote,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    low_state_tax_privilege
  )
]
issuer_purpose <- purpose_amounts[
  issuer_purpose,
  on = .(state, seed_issuer, purpose_category)
]
issuer_purpose[is.na(category_amount), category_amount := 0]
issuer_purpose[is.na(revenue_amount), revenue_amount := 0]
issuer_purpose[, share_revenue_vs_go_amount := fifelse(
  category_amount > 0,
  revenue_amount / category_amount,
  NA_real_
)]

aggregate_purpose_models <- lapply(purpose_categories, function(category) {
  feols(
    make_formula('share_revenue_vs_go_amount', aggregate_purpose_controls),
    data = issuer_purpose[purpose_category == category],
    vcov = vcov_cluster(~state)
  )
})

write_robustness_panel(
  aggregate_purpose_models,
  headers = purpose_headers,
  panel_title = 'Panel E: Purpose substitution, full sample aggregate',
  output_file = 'alternative_sample_robustness_panel_e_purpose_aggregate.tex',
  treatment_label = 'Vote',
  fontsize = 'small'
)

#==============================================================================
# Printable online-appendix wrapper
#==============================================================================

writeLines(c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption{\\textbf{Robustness to Alternative Measurement Periods}}',
  '\\label{tab:alternative_sample_robustness}',
  paste0(
    '\\parbox{\\textwidth}{This table repeats the debt-choice, weighted-average yield-spread, ',
    'and purpose-substitution analyses using the 2012 point-in-time measures and full-period ',
    'issuer aggregates. Panels A and B report debt composition. Panel C reports the weighted-average ',
    'yield spread. Panels D and E report the revenue share within each purpose category. ',
    'The 2012 specifications use the point-in-time controls. The full-sample aggregate specifications ',
    'use county population and debt issued by other entities in the county. The aggregate yield ',
    'regression also controls for available weighted-average rating and maturity, but the issuer-level ',
    'data do not contain the insured, callable, and sinkable indicators used in the point-in-time ',
    'specification. Controls are suppressed. Standard errors are clustered by state.}'
  ),
  '\\end{table}',
  '\\input{tables/clean/raw/alternative_sample_robustness_panel_a_debt_choice_allgo}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/alternative_sample_robustness_panel_b_debt_choice_utgo_only}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/alternative_sample_robustness_panel_c_yield_spread}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/alternative_sample_robustness_panel_d_purpose_2012}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/alternative_sample_robustness_panel_e_purpose_aggregate}'
), file.path(processed_dir, 'alternative_sample_robustness.tex'))

cat('Wrote alternative-sample robustness panels and wrapper.\n')
