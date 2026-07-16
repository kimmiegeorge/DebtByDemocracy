# Purpose substitution tests using DPC use-of-proceeds categories
rm(list = ls())

library(pacman)
p_load(data.table, fixest)

# Load custom etable rounding functions
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
panel_dir <- file.path(root, 'Data/DPC Data/Use Of Proceeds/Purposes Substitution')
out_dir <- file.path(root, 'Results/Purposes Substitution')
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cusip_panel_file <- file.path(panel_dir, '260707_dpc_purpose_substitution_cusip_category_panel.csv')
issuer_category_file <- file.path(panel_dir, '260707_dpc_purpose_substitution_issuer_category_panel.csv')

states_city_issue_education <- c('MA', 'AL', 'CT', 'KY', 'MA')

#----------------------------
# Load data
#----------------------------
cusip_panel <- fread(cusip_panel_file)
issuer_category <- fread(issuer_category_file)

cusip_panel[, vote_required := as.integer(vote_required)]
cusip_panel[, cities_issue_education := as.integer(state %in% states_city_issue_education)]
issuer_category[, vote_required := as.integer(vote_required)]
issuer_category[, cities_issue_education := as.integer(state %in% states_city_issue_education)]

controls <- c(
  'ln_gdp',
  'ln_pop',
  'ln_pers_inc',
  'ln_county_debt_other',
  'glm_proactive',
  'state_ltgo_allowed',
  'state_go_vote',
  'high_state_tax_privilege',
  'cities_issue_education'
)

control_rhs <- paste(controls, collapse = ' + ')

control_dict <- c(
  vote_required = 'Vote Required',
  ln_gdp = 'County ln(GDP)',
  ln_pop = 'County ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  ln_county_debt_other = 'ln(Non-issuer county debt)',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  high_state_tax_privilege = 'High Tax Priv.',
  cities_issue_education = 'Cities Issue Education Debt',
  category_amount_share_of_go_or_strict_gg = 'Category Amt. Share',
  share_revenue_security_g_source_g_vs_go_amount = 'Strict Rev. Amt. Share'
)

#----------------------------
# Table 1: Category composition of GO + strict revenue amount
#----------------------------
# Unit: issuer-category. For each issuer, the denominator is total amount issued
# as either GO debt or strict G/G revenue debt. The outcome is the fraction of
# that amount attached to each DPC category. Categories are not mutually
# exclusive, so category shares can sum above one.
restricted_cusip <- cusip_panel[
  go_any == 1 | revenue_bond_security_g_source_g == 1
]

issuer_denominator <- unique(
  restricted_cusip[, .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    cusip,
    amount
  )]
)[
  ,
  .(
    total_go_or_strict_gg_amount = sum(amount, na.rm = TRUE),
    total_go_or_strict_gg_bonds = uniqueN(cusip)
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education
  )
]

issuer_category_amount <- restricted_cusip[
  ,
  .(
    category_amount = sum(amount, na.rm = TRUE),
    category_bonds = uniqueN(cusip)
  ),
  by = .(seed_issuer_id, purpose_category)
]

issuer_category_composition <- CJ(
  seed_issuer_id = issuer_denominator$seed_issuer_id,
  purpose_category = c(
    'economic_development',
    'education',
    'other',
    'other_public_buildings',
    'public_safety',
    'recreation_amenities',
    'transportation',
    'utilities'
  ),
  unique = TRUE
)

issuer_category_composition <- issuer_category_amount[
  issuer_category_composition,
  on = .(seed_issuer_id, purpose_category)
]
issuer_category_composition[is.na(category_amount), category_amount := 0]
issuer_category_composition[is.na(category_bonds), category_bonds := 0]

issuer_category_composition <- issuer_denominator[
  issuer_category_composition,
  on = .(seed_issuer_id)
]
issuer_category_composition[
  ,
  category_amount_share_of_go_or_strict_gg :=
    category_amount / total_go_or_strict_gg_amount
]
issuer_category_composition <- issuer_category_composition[
  complete.cases(issuer_category_composition[, ..controls])
]

r_comp_econ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'economic_development'],
  vcov = vcov_cluster(~fips)
)
r_comp_educ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'education'],
  vcov = vcov_cluster(~fips)
)
r_comp_pub_build <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_comp_safety <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_comp_rec <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_comp_trans <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_comp_util <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)
r_comp_other <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = issuer_category_composition[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_comp_econ,
  r_comp_educ,
  r_comp_pub_build,
  r_comp_safety,
  r_comp_rec,
  r_comp_trans,
  r_comp_util,
  r_comp_other,
  headers = c(
    'Econ. Dev.',
    'Education',
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities',
    'Other'
  ),
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
  'Panel A: Category share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_category_amount_composition_controls.tex')
)

#----------------------------
# Table 2: Strict revenue share within GO + strict revenue
#----------------------------
# Unit: issuer-category. The denominator is the issuer-category amount issued as
# either GO debt or strict G/G revenue debt. The outcome is the fraction of that
# amount issued as strict G/G revenue debt.
issuer_category <- issuer_category[complete.cases(issuer_category[, ..controls])]

r_rev_econ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'economic_development'],
  vcov = vcov_cluster(~fips)
)
r_rev_educ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'education'],
  vcov = vcov_cluster(~fips)
)

r_rev_pub_build <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_safety <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_rec <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_trans <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_util <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)
r_rev_other <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = issuer_category[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)

mean_rev_econ_no_vote <- issuer_category[
  purpose_category == 'economic_development' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_educ_no_vote <- issuer_category[
  purpose_category == 'education' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_other_no_vote <- issuer_category[
  purpose_category == 'other' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_pub_build_no_vote <- issuer_category[
  purpose_category == 'other_public_buildings' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_safety_no_vote <- issuer_category[
  purpose_category == 'public_safety' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_rec_no_vote <- issuer_category[
  purpose_category == 'recreation_amenities' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_trans_no_vote <- issuer_category[
  purpose_category == 'transportation' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_rev_util_no_vote <- issuer_category[
  purpose_category == 'utilities' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]

effect_over_mean_rev_econ <- coef(r_rev_econ)['vote_required'] / mean_rev_econ_no_vote
effect_over_mean_rev_educ <- coef(r_rev_educ)['vote_required'] / mean_rev_educ_no_vote
effect_over_mean_rev_other <- coef(r_rev_other)['vote_required'] / mean_rev_other_no_vote
effect_over_mean_rev_pub_build <- coef(r_rev_pub_build)['vote_required'] / mean_rev_pub_build_no_vote
effect_over_mean_rev_safety <- coef(r_rev_safety)['vote_required'] / mean_rev_safety_no_vote
effect_over_mean_rev_rec <- coef(r_rev_rec)['vote_required'] / mean_rev_rec_no_vote
effect_over_mean_rev_trans <- coef(r_rev_trans)['vote_required'] / mean_rev_trans_no_vote
effect_over_mean_rev_util <- coef(r_rev_util)['vote_required'] / mean_rev_util_no_vote

table_call <- etable(
  r_rev_econ,
  r_rev_educ,
  r_rev_other,
  r_rev_pub_build,
  r_rev_safety,
  r_rev_rec,
  r_rev_trans,
  r_rev_util,
  headers = c(
    'Econ. Dev.',
    'Education',
    'Other',
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
      sprintf('%.3f', mean_rev_econ_no_vote),
      sprintf('%.3f', mean_rev_educ_no_vote),
      sprintf('%.3f', mean_rev_other_no_vote),
      sprintf('%.3f', mean_rev_pub_build_no_vote),
      sprintf('%.3f', mean_rev_safety_no_vote),
      sprintf('%.3f', mean_rev_rec_no_vote),
      sprintf('%.3f', mean_rev_trans_no_vote),
      sprintf('%.3f', mean_rev_util_no_vote)
    ),
    'Effect / no-vote mean' = c(
      sprintf('%.1f', effect_over_mean_rev_econ),
      sprintf('%.1f', effect_over_mean_rev_educ),
      sprintf('%.1f', effect_over_mean_rev_other),
      sprintf('%.1f', effect_over_mean_rev_pub_build),
      sprintf('%.1f', effect_over_mean_rev_safety),
      sprintf('%.1f', effect_over_mean_rev_rec),
      sprintf('%.1f', effect_over_mean_rev_trans),
      sprintf('%.1f', effect_over_mean_rev_util)
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
  'Panel B: Strict revenue share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_strict_gg_revenue_share_controls.tex')
)

#----------------------------
# Exploratory test: does substitution rise in categories where control states
# already use revenue debt?
#----------------------------
# This uses the control-state strict G/G revenue amount share within each
# category as a revealed-feasibility measure. The stacked specification includes
# category fixed effects, so the coefficient of interest is the interaction
# between vote-required status and the control-state revenue share.
broad_categories <- c(
  'economic_development',
  'education',
  'other',
  'other_public_buildings',
  'public_safety',
  'recreation_amenities',
  'transportation',
  'utilities'
)

#----------------------------
# Weighted stacked category-bond tables
#----------------------------
# Multi-category bonds remain in the stacked panel, but each CUSIP-category row
# receives weight 1 / number of broad categories attached to the CUSIP.
cusip_category_count <- cusip_panel[
  ,
  .(
    n_broad_categories = uniqueN(purpose_category),
    broad_category_list = paste(sort(unique(purpose_category)), collapse = '; ')
  ),
  by = .(cusip)
]

weighted_cusip <- cusip_category_count[
  restricted_cusip,
  on = .(cusip)
]
weighted_cusip[, category_weight := 1 / n_broad_categories]
weighted_cusip[, weighted_amount := amount * category_weight]
weighted_cusip[
  ,
  weighted_strict_gg_revenue_amount :=
    amount * revenue_bond_security_g_source_g * category_weight
]

weighted_issuer_category_amount <- weighted_cusip[
  ,
  .(
    category_amount = sum(weighted_amount, na.rm = TRUE),
    category_bonds = sum(category_weight, na.rm = TRUE)
  ),
  by = .(seed_issuer_id, purpose_category)
]

weighted_issuer_category_composition <- CJ(
  seed_issuer_id = issuer_denominator$seed_issuer_id,
  purpose_category = broad_categories,
  unique = TRUE
)
weighted_issuer_category_composition <- weighted_issuer_category_amount[
  weighted_issuer_category_composition,
  on = .(seed_issuer_id, purpose_category)
]
weighted_issuer_category_composition[is.na(category_amount), category_amount := 0]
weighted_issuer_category_composition[is.na(category_bonds), category_bonds := 0]
weighted_issuer_category_composition <- issuer_denominator[
  weighted_issuer_category_composition,
  on = .(seed_issuer_id)
]
weighted_issuer_category_composition[
  ,
  category_amount_share_of_go_or_strict_gg :=
    category_amount / total_go_or_strict_gg_amount
]
weighted_issuer_category_composition <- weighted_issuer_category_composition[
  complete.cases(weighted_issuer_category_composition[, ..controls])
]

r_weight_comp_econ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'economic_development'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_educ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'education'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_other <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_pub_build <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_safety <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_rec <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_trans <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_weight_comp_util <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_composition[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_weight_comp_econ,
  r_weight_comp_educ,
  r_weight_comp_other,
  r_weight_comp_pub_build,
  r_weight_comp_safety,
  r_weight_comp_rec,
  r_weight_comp_trans,
  r_weight_comp_util,
  headers = c(
    'Econ. Dev.',
    'Education',
    'Other',
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
  'Panel C: Weighted category share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_weighted_category_amount_composition_controls.tex')
)

weighted_issuer_category_revenue <- weighted_cusip[
  ,
  .(
    go_or_strict_gg_amount = sum(weighted_amount, na.rm = TRUE),
    strict_gg_revenue_amount =
      sum(weighted_strict_gg_revenue_amount, na.rm = TRUE),
    go_or_strict_gg_bonds = sum(category_weight, na.rm = TRUE),
    strict_gg_revenue_bonds =
      sum(category_weight * revenue_bond_security_g_source_g, na.rm = TRUE)
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    purpose_category
  )
]
weighted_issuer_category_revenue[
  ,
  share_revenue_security_g_source_g_vs_go_amount :=
    strict_gg_revenue_amount / go_or_strict_gg_amount
]
weighted_issuer_category_revenue <- weighted_issuer_category_revenue[
  complete.cases(weighted_issuer_category_revenue[, ..controls])
]

r_weight_rev_econ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'economic_development'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_educ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'education'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_other <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_pub_build <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_safety <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_rec <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_trans <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_weight_rev_util <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_issuer_category_revenue[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

mean_weight_rev_econ_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'economic_development' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_educ_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'education' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_other_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'other' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_pub_build_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'other_public_buildings' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_safety_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'public_safety' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_rec_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'recreation_amenities' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_trans_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'transportation' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_rev_util_no_vote <- weighted_issuer_category_revenue[
  purpose_category == 'utilities' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]

table_call <- etable(
  r_weight_rev_econ,
  r_weight_rev_educ,
  r_weight_rev_other,
  r_weight_rev_pub_build,
  r_weight_rev_safety,
  r_weight_rev_rec,
  r_weight_rev_trans,
  r_weight_rev_util,
  headers = c(
    'Econ. Dev.',
    'Education',
    'Other',
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
      sprintf('%.3f', mean_weight_rev_econ_no_vote),
      sprintf('%.3f', mean_weight_rev_educ_no_vote),
      sprintf('%.3f', mean_weight_rev_other_no_vote),
      sprintf('%.3f', mean_weight_rev_pub_build_no_vote),
      sprintf('%.3f', mean_weight_rev_safety_no_vote),
      sprintf('%.3f', mean_weight_rev_rec_no_vote),
      sprintf('%.3f', mean_weight_rev_trans_no_vote),
      sprintf('%.3f', mean_weight_rev_util_no_vote)
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
  'Panel D: Weighted strict revenue share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_weighted_strict_gg_revenue_share_controls.tex')
)

# Grouped weighted version. Economic development and education are folded into
# Other, and Other is shown as the last column.
weighted_cusip_grouped <- copy(weighted_cusip)
weighted_cusip_grouped[
  purpose_category %in% c('economic_development', 'education', 'other'),
  purpose_category_group := 'other'
]
weighted_cusip_grouped[
  is.na(purpose_category_group),
  purpose_category_group := purpose_category
]

weighted_grouped_categories <- c(
  'other_public_buildings',
  'public_safety',
  'recreation_amenities',
  'transportation',
  'utilities',
  'other'
)

weighted_grouped_category_amount <- weighted_cusip_grouped[
  ,
  .(
    category_amount = sum(weighted_amount, na.rm = TRUE),
    category_bonds = sum(category_weight, na.rm = TRUE)
  ),
  by = .(seed_issuer_id, purpose_category_group)
]

weighted_grouped_category_composition <- CJ(
  seed_issuer_id = issuer_denominator$seed_issuer_id,
  purpose_category_group = weighted_grouped_categories,
  unique = TRUE
)
weighted_grouped_category_composition <- weighted_grouped_category_amount[
  weighted_grouped_category_composition,
  on = .(seed_issuer_id, purpose_category_group)
]
weighted_grouped_category_composition[is.na(category_amount), category_amount := 0]
weighted_grouped_category_composition[is.na(category_bonds), category_bonds := 0]
weighted_grouped_category_composition <- issuer_denominator[
  weighted_grouped_category_composition,
  on = .(seed_issuer_id)
]
weighted_grouped_category_composition[
  ,
  category_amount_share_of_go_or_strict_gg :=
    category_amount / total_go_or_strict_gg_amount
]
weighted_grouped_category_composition <- weighted_grouped_category_composition[
  complete.cases(weighted_grouped_category_composition[, ..controls])
]

r_weight_group_comp_pub_build <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_composition[purpose_category_group == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_comp_safety <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_composition[purpose_category_group == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_comp_rec <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_composition[purpose_category_group == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_comp_trans <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_composition[purpose_category_group == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_comp_util <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_composition[purpose_category_group == 'utilities'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_comp_other <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_composition[purpose_category_group == 'other'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_weight_group_comp_pub_build,
  r_weight_group_comp_safety,
  r_weight_group_comp_rec,
  r_weight_group_comp_trans,
  r_weight_group_comp_util,
  r_weight_group_comp_other,
  headers = c(
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities',
    'Other'
  ),
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
  'Panel E: Grouped weighted category share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_weighted_grouped_category_amount_composition_controls.tex')
)

weighted_grouped_category_per_capita <- copy(weighted_grouped_category_composition)
weighted_grouped_category_per_capita[
  ,
  category_amount_per_capita := category_amount / exp(ln_pop)
]
control_dict <- c(
  control_dict,
  category_amount_per_capita = 'Category Amt. Per Capita'
)

r_weight_group_pc_pub_build <- feols(
  as.formula(paste0('category_amount_per_capita ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_per_capita[purpose_category_group == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_pc_safety <- feols(
  as.formula(paste0('category_amount_per_capita ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_per_capita[purpose_category_group == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_pc_rec <- feols(
  as.formula(paste0('category_amount_per_capita ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_per_capita[purpose_category_group == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_pc_trans <- feols(
  as.formula(paste0('category_amount_per_capita ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_per_capita[purpose_category_group == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_pc_util <- feols(
  as.formula(paste0('category_amount_per_capita ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_per_capita[purpose_category_group == 'utilities'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_pc_other <- feols(
  as.formula(paste0('category_amount_per_capita ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_per_capita[purpose_category_group == 'other'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_weight_group_pc_pub_build,
  r_weight_group_pc_safety,
  r_weight_group_pc_rec,
  r_weight_group_pc_trans,
  r_weight_group_pc_util,
  r_weight_group_pc_other,
  headers = c(
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities',
    'Other'
  ),
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
  'Panel F: Grouped weighted category amount per capita'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_weighted_grouped_category_amount_per_capita_controls.tex')
)

# Issuer-level aggregate amount per capita, using the same GO plus strict G/G
# revenue denominator as the category tables.
issuer_denominator[
  ,
  total_go_or_strict_gg_amount_per_capita :=
    total_go_or_strict_gg_amount / exp(ln_pop)
]
control_dict <- c(
  control_dict,
  total_go_or_strict_gg_amount_per_capita =
    'Total GO + Strict Rev. Amt. Per Capita',
  total_go_or_strict_gg_amount_per_capita_winsor =
    'Total GO + Strict Rev. Amt. Per Capita'
)

controls_no_school <- setdiff(controls, 'cities_issue_education')
control_rhs_no_school <- paste(controls_no_school, collapse = ' + ')

issuer_total_pc <- issuer_denominator[
  complete.cases(issuer_denominator[, ..controls_no_school])
]

total_pc_p1 <- quantile(
  issuer_total_pc$total_go_or_strict_gg_amount_per_capita,
  probs = 0.01,
  na.rm = TRUE
)
total_pc_p99 <- quantile(
  issuer_total_pc$total_go_or_strict_gg_amount_per_capita,
  probs = 0.99,
  na.rm = TRUE
)

issuer_total_pc[
  ,
  total_go_or_strict_gg_amount_per_capita_winsor :=
    pmin(
      pmax(total_go_or_strict_gg_amount_per_capita, total_pc_p1),
      total_pc_p99
    )
]

r_total_pc_raw <- feols(
  as.formula(paste0('total_go_or_strict_gg_amount_per_capita ~ vote_required + ', control_rhs_no_school)),
  data = issuer_total_pc,
  vcov = vcov_cluster(~fips)
)
r_total_pc_winsor <- feols(
  as.formula(paste0('total_go_or_strict_gg_amount_per_capita_winsor ~ vote_required + ', control_rhs_no_school)),
  data = issuer_total_pc,
  vcov = vcov_cluster(~fips)
)
r_total_pc_trim <- feols(
  as.formula(paste0('total_go_or_strict_gg_amount_per_capita ~ vote_required + ', control_rhs_no_school)),
  data = issuer_total_pc[
    total_go_or_strict_gg_amount_per_capita >= total_pc_p1 &
      total_go_or_strict_gg_amount_per_capita <= total_pc_p99
  ],
  vcov = vcov_cluster(~fips)
)

mean_total_pc_no_vote_raw <- issuer_total_pc[
  mean(total_go_or_strict_gg_amount_per_capita, na.rm = TRUE)
]
mean_total_pc_no_vote_raw <- issuer_total_pc[
  vote_required == 0,
  mean(total_go_or_strict_gg_amount_per_capita, na.rm = TRUE)
]
mean_total_pc_no_vote_winsor <- issuer_total_pc[
  vote_required == 0,
  mean(total_go_or_strict_gg_amount_per_capita_winsor, na.rm = TRUE)
]
mean_total_pc_no_vote_trim <- issuer_total_pc[
  vote_required == 0 &
    total_go_or_strict_gg_amount_per_capita >= total_pc_p1 &
    total_go_or_strict_gg_amount_per_capita <= total_pc_p99,
  mean(total_go_or_strict_gg_amount_per_capita, na.rm = TRUE)
]

table_call <- etable(
  r_total_pc_raw,
  r_total_pc_winsor,
  r_total_pc_trim,
  headers = c('Raw', 'Winsor 1/99', 'Trim 1/99'),
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
      sprintf('%.3f', mean_total_pc_no_vote_raw),
      sprintf('%.3f', mean_total_pc_no_vote_winsor),
      sprintf('%.3f', mean_total_pc_no_vote_trim)
    ),
    'Winsor/trim p1' = c(
      sprintf('%.3f', total_pc_p1),
      sprintf('%.3f', total_pc_p1),
      sprintf('%.3f', total_pc_p1)
    ),
    'Winsor/trim p99' = c(
      sprintf('%.3f', total_pc_p99),
      sprintf('%.3f', total_pc_p99),
      sprintf('%.3f', total_pc_p99)
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
  'Panel G: Total GO plus strict revenue amount per capita'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_total_go_strict_gg_amount_per_capita_controls.tex')
)

# Split the per-capita amount outcome into GO and strict G/G revenue amount.
issuer_type_amount <- unique(
  restricted_cusip[, .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    cusip,
    amount,
    go_any,
    revenue_bond_security_g_source_g
  )]
)[
  ,
  .(
    total_go_amount = sum(amount * go_any, na.rm = TRUE),
    total_strict_gg_revenue_amount =
      sum(amount * revenue_bond_security_g_source_g, na.rm = TRUE),
    total_go_bonds = uniqueN(cusip[go_any == 1]),
    total_strict_gg_revenue_bonds =
      uniqueN(cusip[revenue_bond_security_g_source_g == 1])
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education
  )
]

issuer_type_amount[
  ,
  `:=`(
    total_go_amount_per_capita = total_go_amount / exp(ln_pop),
    total_strict_gg_revenue_amount_per_capita =
      total_strict_gg_revenue_amount / exp(ln_pop)
  )
]

issuer_type_amount <- issuer_type_amount[
  complete.cases(issuer_type_amount[, ..controls_no_school])
]

go_pc_p1 <- quantile(
  issuer_type_amount$total_go_amount_per_capita,
  probs = 0.01,
  na.rm = TRUE
)
go_pc_p99 <- quantile(
  issuer_type_amount$total_go_amount_per_capita,
  probs = 0.99,
  na.rm = TRUE
)
rev_pc_p1 <- quantile(
  issuer_type_amount$total_strict_gg_revenue_amount_per_capita,
  probs = 0.01,
  na.rm = TRUE
)
rev_pc_p99 <- quantile(
  issuer_type_amount$total_strict_gg_revenue_amount_per_capita,
  probs = 0.99,
  na.rm = TRUE
)

issuer_type_amount[
  ,
  total_go_amount_per_capita_winsor :=
    pmin(pmax(total_go_amount_per_capita, go_pc_p1), go_pc_p99)
]
issuer_type_amount[
  ,
  total_strict_gg_revenue_amount_per_capita_winsor :=
    pmin(
      pmax(total_strict_gg_revenue_amount_per_capita, rev_pc_p1),
      rev_pc_p99
    )
]

control_dict <- c(
  control_dict,
  total_go_amount_per_capita = 'GO Amt. Per Capita',
  total_go_amount_per_capita_winsor = 'GO Amt. Per Capita',
  total_strict_gg_revenue_amount_per_capita =
    'Strict Rev. Amt. Per Capita',
  total_strict_gg_revenue_amount_per_capita_winsor =
    'Strict Rev. Amt. Per Capita'
)

r_go_pc_raw <- feols(
  as.formula(paste0('total_go_amount_per_capita ~ vote_required + ', control_rhs_no_school)),
  data = issuer_type_amount,
  vcov = vcov_cluster(~fips)
)
r_go_pc_winsor <- feols(
  as.formula(paste0('total_go_amount_per_capita_winsor ~ vote_required + ', control_rhs_no_school)),
  data = issuer_type_amount,
  vcov = vcov_cluster(~fips)
)
r_go_pc_trim <- feols(
  as.formula(paste0('total_go_amount_per_capita ~ vote_required + ', control_rhs_no_school)),
  data = issuer_type_amount[
    total_go_amount_per_capita >= go_pc_p1 &
      total_go_amount_per_capita <= go_pc_p99
  ],
  vcov = vcov_cluster(~fips)
)
r_rev_pc_raw <- feols(
  as.formula(paste0('total_strict_gg_revenue_amount_per_capita ~ vote_required + ', control_rhs_no_school)),
  data = issuer_type_amount,
  vcov = vcov_cluster(~fips)
)
r_rev_pc_winsor <- feols(
  as.formula(paste0('total_strict_gg_revenue_amount_per_capita_winsor ~ vote_required + ', control_rhs_no_school)),
  data = issuer_type_amount,
  vcov = vcov_cluster(~fips)
)
r_rev_pc_trim <- feols(
  as.formula(paste0('total_strict_gg_revenue_amount_per_capita ~ vote_required + ', control_rhs_no_school)),
  data = issuer_type_amount[
    total_strict_gg_revenue_amount_per_capita >= rev_pc_p1 &
      total_strict_gg_revenue_amount_per_capita <= rev_pc_p99
  ],
  vcov = vcov_cluster(~fips)
)

mean_go_pc_no_vote_raw <- issuer_type_amount[
  vote_required == 0,
  mean(total_go_amount_per_capita, na.rm = TRUE)
]
mean_go_pc_no_vote_winsor <- issuer_type_amount[
  vote_required == 0,
  mean(total_go_amount_per_capita_winsor, na.rm = TRUE)
]
mean_go_pc_no_vote_trim <- issuer_type_amount[
  vote_required == 0 &
    total_go_amount_per_capita >= go_pc_p1 &
    total_go_amount_per_capita <= go_pc_p99,
  mean(total_go_amount_per_capita, na.rm = TRUE)
]
mean_rev_pc_no_vote_raw <- issuer_type_amount[
  vote_required == 0,
  mean(total_strict_gg_revenue_amount_per_capita, na.rm = TRUE)
]
mean_rev_pc_no_vote_winsor <- issuer_type_amount[
  vote_required == 0,
  mean(total_strict_gg_revenue_amount_per_capita_winsor, na.rm = TRUE)
]
mean_rev_pc_no_vote_trim <- issuer_type_amount[
  vote_required == 0 &
    total_strict_gg_revenue_amount_per_capita >= rev_pc_p1 &
    total_strict_gg_revenue_amount_per_capita <= rev_pc_p99,
  mean(total_strict_gg_revenue_amount_per_capita, na.rm = TRUE)
]

table_call <- etable(
  r_go_pc_raw,
  r_go_pc_winsor,
  r_go_pc_trim,
  r_rev_pc_raw,
  r_rev_pc_winsor,
  r_rev_pc_trim,
  headers = c(
    'GO: Raw',
    'GO: Winsor 1/99',
    'GO: Trim 1/99',
    'Strict Rev.: Raw',
    'Strict Rev.: Winsor 1/99',
    'Strict Rev.: Trim 1/99'
  ),
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
      sprintf('%.3f', mean_go_pc_no_vote_raw),
      sprintf('%.3f', mean_go_pc_no_vote_winsor),
      sprintf('%.3f', mean_go_pc_no_vote_trim),
      sprintf('%.3f', mean_rev_pc_no_vote_raw),
      sprintf('%.3f', mean_rev_pc_no_vote_winsor),
      sprintf('%.3f', mean_rev_pc_no_vote_trim)
    ),
    'Winsor/trim p1' = c(
      sprintf('%.3f', go_pc_p1),
      sprintf('%.3f', go_pc_p1),
      sprintf('%.3f', go_pc_p1),
      sprintf('%.3f', rev_pc_p1),
      sprintf('%.3f', rev_pc_p1),
      sprintf('%.3f', rev_pc_p1)
    ),
    'Winsor/trim p99' = c(
      sprintf('%.3f', go_pc_p99),
      sprintf('%.3f', go_pc_p99),
      sprintf('%.3f', go_pc_p99),
      sprintf('%.3f', rev_pc_p99),
      sprintf('%.3f', rev_pc_p99),
      sprintf('%.3f', rev_pc_p99)
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
  'Panel H: GO and strict revenue amount per capita'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_go_vs_strict_gg_amount_per_capita_controls.tex')
)

issuer_total_pc[
  ,
  ln_total_go_or_strict_gg_amount := log(1 + total_go_or_strict_gg_amount)
]
control_dict <- c(
  control_dict,
  ln_total_go_or_strict_gg_amount = 'ln(1 + Total GO + Strict Rev. Amt.)'
)

r_total_log_amount <- feols(
  as.formula(paste0('ln_total_go_or_strict_gg_amount ~ vote_required + ', control_rhs_no_school)),
  data = issuer_total_pc,
  vcov = vcov_cluster(~fips)
)

mean_total_log_no_vote <- issuer_total_pc[
  vote_required == 0,
  mean(ln_total_go_or_strict_gg_amount, na.rm = TRUE)
]
mean_total_amount_no_vote <- issuer_total_pc[
  vote_required == 0,
  mean(total_go_or_strict_gg_amount, na.rm = TRUE)
]
vote_pct_effect_total_log <- 100 * (exp(coef(r_total_log_amount)['vote_required']) - 1)

table_call <- etable(
  r_total_log_amount,
  headers = c('Total'),
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
    'No-vote mean, log outcome' = sprintf('%.3f', mean_total_log_no_vote),
    'No-vote mean, amount' = sprintf('%.3f', mean_total_amount_no_vote),
    'Implied pct. effect' = sprintf('%.1f', vote_pct_effect_total_log)
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
  'Panel H: Log total GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_log_total_go_strict_gg_amount_controls.tex')
)

weighted_grouped_category_revenue <- weighted_cusip_grouped[
  ,
  .(
    go_or_strict_gg_amount = sum(weighted_amount, na.rm = TRUE),
    strict_gg_revenue_amount =
      sum(weighted_strict_gg_revenue_amount, na.rm = TRUE),
    go_or_strict_gg_bonds = sum(category_weight, na.rm = TRUE),
    strict_gg_revenue_bonds =
      sum(category_weight * revenue_bond_security_g_source_g, na.rm = TRUE)
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    purpose_category_group
  )
]
weighted_grouped_category_revenue[
  ,
  share_revenue_security_g_source_g_vs_go_amount :=
    strict_gg_revenue_amount / go_or_strict_gg_amount
]
weighted_grouped_category_revenue <- weighted_grouped_category_revenue[
  complete.cases(weighted_grouped_category_revenue[, ..controls])
]

r_weight_group_rev_pub_build <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_revenue[purpose_category_group == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_rev_safety <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_revenue[purpose_category_group == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_rev_rec <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_revenue[purpose_category_group == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_rev_trans <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_revenue[purpose_category_group == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_rev_util <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_revenue[purpose_category_group == 'utilities'],
  vcov = vcov_cluster(~fips)
)
r_weight_group_rev_other <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = weighted_grouped_category_revenue[purpose_category_group == 'other'],
  vcov = vcov_cluster(~fips)
)

mean_weight_group_rev_pub_build_no_vote <- weighted_grouped_category_revenue[
  purpose_category_group == 'other_public_buildings' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_group_rev_safety_no_vote <- weighted_grouped_category_revenue[
  purpose_category_group == 'public_safety' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_group_rev_rec_no_vote <- weighted_grouped_category_revenue[
  purpose_category_group == 'recreation_amenities' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_group_rev_trans_no_vote <- weighted_grouped_category_revenue[
  purpose_category_group == 'transportation' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_group_rev_util_no_vote <- weighted_grouped_category_revenue[
  purpose_category_group == 'utilities' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]
mean_weight_group_rev_other_no_vote <- weighted_grouped_category_revenue[
  purpose_category_group == 'other' & vote_required == 0,
  mean(share_revenue_security_g_source_g_vs_go_amount, na.rm = TRUE)
]

table_call <- etable(
  r_weight_group_rev_pub_build,
  r_weight_group_rev_safety,
  r_weight_group_rev_rec,
  r_weight_group_rev_trans,
  r_weight_group_rev_util,
  r_weight_group_rev_other,
  headers = c(
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities',
    'Other'
  ),
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
      sprintf('%.3f', mean_weight_group_rev_pub_build_no_vote),
      sprintf('%.3f', mean_weight_group_rev_safety_no_vote),
      sprintf('%.3f', mean_weight_group_rev_rec_no_vote),
      sprintf('%.3f', mean_weight_group_rev_trans_no_vote),
      sprintf('%.3f', mean_weight_group_rev_util_no_vote),
      sprintf('%.3f', mean_weight_group_rev_other_no_vote)
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
  'Panel F: Grouped weighted strict revenue share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_weighted_grouped_strict_gg_revenue_share_controls.tex')
)

control_revenue_share <- restricted_cusip[
  vote_required == 0,
  .(
    control_state_strict_gg_revenue_amount =
      sum(amount * revenue_bond_security_g_source_g, na.rm = TRUE),
    control_state_go_or_strict_gg_amount = sum(amount, na.rm = TRUE)
  ),
  by = .(purpose_category)
]
control_revenue_share[
  ,
  control_state_strict_gg_revenue_share :=
    control_state_strict_gg_revenue_amount /
    control_state_go_or_strict_gg_amount
]

issuer_category_feasibility <- control_revenue_share[
  issuer_category,
  on = .(purpose_category)
]
issuer_category_feasibility <- issuer_category_feasibility[
  !is.na(control_state_strict_gg_revenue_share) &
    complete.cases(issuer_category_feasibility[, ..controls])
]

r_feasibility_full_stacked <- feols(
  as.formula(
    paste0(
      'share_revenue_security_g_source_g_vs_go_amount ~ ',
      'vote_required + vote_required:control_state_strict_gg_revenue_share + ',
      control_rhs,
      ' | purpose_category'
    )
  ),
  data = issuer_category_feasibility,
  vcov = vcov_cluster(~fips)
)

# Single-category version. Refunding is not a broad category in this collapsed
# panel, so the count below is based only on non-refunding broad use-of-proceeds
# labels attached to each CUSIP.
cusip_category_count <- cusip_panel[
  ,
  .(
    n_broad_categories = uniqueN(purpose_category),
    broad_category_list = paste(sort(unique(purpose_category)), collapse = '; ')
  ),
  by = .(cusip)
]

cusip_unique <- unique(
  cusip_panel[
    ,
    .(
      cusip,
      state,
      seed_issuer,
      seed_issuer_id,
      vote_required,
      go_any,
      revenue_bond_security_g_source_g,
      amount,
      fips,
      ln_gdp,
      ln_pop,
      ln_pers_inc,
      ln_county_debt_other,
      glm_proactive,
      state_ltgo_allowed,
      state_go_vote,
      high_state_tax_privilege,
      cities_issue_education
    )
  ]
)
cusip_unique <- cusip_category_count[cusip_unique, on = .(cusip)]

eligible_cusip_unique <- cusip_unique[
  go_any == 1 | revenue_bond_security_g_source_g == 1
]

single_category_retention <- eligible_cusip_unique[
  ,
  .(
    bonds = .N,
    amount = sum(amount, na.rm = TRUE),
    single_category_bonds = sum(n_broad_categories == 1),
    single_category_amount = sum(amount[n_broad_categories == 1], na.rm = TRUE)
  ),
  by = .(vote_required)
]
single_category_retention[
  ,
  `:=`(
    share_single_category_bonds = single_category_bonds / bonds,
    share_single_category_amount = single_category_amount / amount
  )
]
single_category_retention <- rbind(
  single_category_retention,
  eligible_cusip_unique[
    ,
    .(
      vote_required = NA_integer_,
      bonds = .N,
      amount = sum(amount, na.rm = TRUE),
      single_category_bonds = sum(n_broad_categories == 1),
      single_category_amount = sum(amount[n_broad_categories == 1], na.rm = TRUE),
      share_single_category_bonds = sum(n_broad_categories == 1) / .N,
      share_single_category_amount =
        sum(amount[n_broad_categories == 1], na.rm = TRUE) /
        sum(amount, na.rm = TRUE)
    )
  ],
  fill = TRUE
)
fwrite(
  single_category_retention,
  file.path(out_dir, '260707_purpose_substitution_single_category_retention.csv')
)

single_category_cusips <- cusip_category_count[
  n_broad_categories == 1,
  .(cusip)
]
single_category_cusip_panel <- cusip_panel[
  single_category_cusips,
  on = .(cusip),
  nomatch = 0
]
single_category_restricted_cusip <- single_category_cusip_panel[
  go_any == 1 | revenue_bond_security_g_source_g == 1
]

single_category_by_category <- restricted_cusip[
  ,
  .(
    stacked_cusip_category_rows = .N,
    unique_cusips = uniqueN(cusip),
    amount = sum(amount, na.rm = TRUE),
    single_category_rows = sum(cusip %in% single_category_cusips$cusip),
    single_category_cusips = uniqueN(cusip[cusip %in% single_category_cusips$cusip]),
    single_category_amount =
      sum(amount[cusip %in% single_category_cusips$cusip], na.rm = TRUE)
  ),
  by = .(purpose_category)
]
single_category_by_category[
  ,
  `:=`(
    share_single_category_rows =
      single_category_rows / stacked_cusip_category_rows,
    share_single_category_cusips = single_category_cusips / unique_cusips,
    share_single_category_amount = single_category_amount / amount
  )
]
fwrite(
  single_category_by_category,
  file.path(out_dir, '260707_purpose_substitution_single_category_by_category.csv')
)

single_control_revenue_share <- single_category_restricted_cusip[
  vote_required == 0,
  .(
    control_state_strict_gg_revenue_amount =
      sum(amount * revenue_bond_security_g_source_g, na.rm = TRUE),
    control_state_go_or_strict_gg_amount = sum(amount, na.rm = TRUE)
  ),
  by = .(purpose_category)
]
single_control_revenue_share[
  ,
  control_state_strict_gg_revenue_share :=
    control_state_strict_gg_revenue_amount /
    control_state_go_or_strict_gg_amount
]

single_issuer_denominator <- single_category_restricted_cusip[
  ,
  .(
    go_or_strict_gg_amount = sum(amount, na.rm = TRUE),
    strict_gg_revenue_amount =
      sum(amount * revenue_bond_security_g_source_g, na.rm = TRUE),
    go_or_strict_gg_bonds = uniqueN(cusip),
    strict_gg_revenue_bonds =
      uniqueN(cusip[revenue_bond_security_g_source_g == 1])
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    purpose_category
  )
]
single_issuer_denominator[
  ,
  share_revenue_security_g_source_g_vs_go_amount :=
    strict_gg_revenue_amount / go_or_strict_gg_amount
]

#----------------------------
# Single-category-only tables
#----------------------------
# These mirror Tables 1 and 2, but first restrict to CUSIPs with exactly one
# broad non-refunding use-of-proceeds category.
single_issuer_total <- unique(
  single_category_restricted_cusip[, .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    cusip,
    amount
  )]
)[
  ,
  .(
    total_go_or_strict_gg_amount = sum(amount, na.rm = TRUE),
    total_go_or_strict_gg_bonds = uniqueN(cusip)
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education
  )
]

single_category_amount <- single_category_restricted_cusip[
  ,
  .(
    category_amount = sum(amount, na.rm = TRUE),
    category_bonds = uniqueN(cusip)
  ),
  by = .(seed_issuer_id, purpose_category)
]

single_category_composition <- CJ(
  seed_issuer_id = single_issuer_total$seed_issuer_id,
  purpose_category = broad_categories,
  unique = TRUE
)
single_category_composition <- single_category_amount[
  single_category_composition,
  on = .(seed_issuer_id, purpose_category)
]
single_category_composition[is.na(category_amount), category_amount := 0]
single_category_composition[is.na(category_bonds), category_bonds := 0]
single_category_composition <- single_issuer_total[
  single_category_composition,
  on = .(seed_issuer_id)
]
single_category_composition[
  ,
  category_amount_share_of_go_or_strict_gg :=
    category_amount / total_go_or_strict_gg_amount
]
single_category_composition <- single_category_composition[
  complete.cases(single_category_composition[, ..controls])
]

r_single_comp_econ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'economic_development'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_educ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'education'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_other <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_pub_build <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_safety <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_rec <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_trans <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_single_comp_util <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_category_composition[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_single_comp_econ,
  r_single_comp_educ,
  r_single_comp_other,
  r_single_comp_pub_build,
  r_single_comp_safety,
  r_single_comp_rec,
  r_single_comp_trans,
  r_single_comp_util,
  headers = c(
    'Econ. Dev.',
    'Education',
    'Other',
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
  'Panel C: Single-category category share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_single_category_amount_composition_controls.tex')
)

r_single_rev_econ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'economic_development'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_educ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'education'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_other <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_pub_build <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_safety <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_rec <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_trans <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_single_rev_util <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_issuer_denominator[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_single_rev_econ,
  r_single_rev_educ,
  r_single_rev_other,
  r_single_rev_pub_build,
  r_single_rev_safety,
  r_single_rev_rec,
  r_single_rev_trans,
  r_single_rev_util,
  headers = c(
    'Econ. Dev.',
    'Education',
    'Other',
    'Public Bldg.',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
  'Panel D: Single-category strict revenue share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_single_category_strict_gg_revenue_share_controls.tex')
)

# Group sparse single categories. Public safety and recreation remain separate;
# economic development and other public buildings are folded into Other.
single_category_restricted_grouped <- copy(single_category_restricted_cusip)
single_category_restricted_grouped[
  purpose_category %in% c('economic_development', 'other_public_buildings'),
  purpose_category_group := 'other'
]
single_category_restricted_grouped[
  is.na(purpose_category_group),
  purpose_category_group := purpose_category
]

grouped_categories <- c(
  'education',
  'other',
  'public_safety',
  'recreation_amenities',
  'transportation',
  'utilities'
)

single_grouped_amount <- single_category_restricted_grouped[
  ,
  .(
    category_amount = sum(amount, na.rm = TRUE),
    category_bonds = uniqueN(cusip)
  ),
  by = .(seed_issuer_id, purpose_category_group)
]
single_grouped_composition <- CJ(
  seed_issuer_id = single_issuer_total$seed_issuer_id,
  purpose_category_group = grouped_categories,
  unique = TRUE
)
single_grouped_composition <- single_grouped_amount[
  single_grouped_composition,
  on = .(seed_issuer_id, purpose_category_group)
]
single_grouped_composition[is.na(category_amount), category_amount := 0]
single_grouped_composition[is.na(category_bonds), category_bonds := 0]
single_grouped_composition <- single_issuer_total[
  single_grouped_composition,
  on = .(seed_issuer_id)
]
single_grouped_composition[
  ,
  category_amount_share_of_go_or_strict_gg :=
    category_amount / total_go_or_strict_gg_amount
]
single_grouped_composition <- single_grouped_composition[
  complete.cases(single_grouped_composition[, ..controls])
]

r_single_group_comp_educ <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_grouped_composition[purpose_category_group == 'education'],
  vcov = vcov_cluster(~fips)
)
r_single_group_comp_other <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_grouped_composition[purpose_category_group == 'other'],
  vcov = vcov_cluster(~fips)
)
r_single_group_comp_safety <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_grouped_composition[purpose_category_group == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_single_group_comp_rec <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_grouped_composition[purpose_category_group == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_single_group_comp_trans <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_grouped_composition[purpose_category_group == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_single_group_comp_util <- feols(
  as.formula(paste0('category_amount_share_of_go_or_strict_gg ~ vote_required + ', control_rhs)),
  data = single_grouped_composition[purpose_category_group == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_single_group_comp_educ,
  r_single_group_comp_other,
  r_single_group_comp_safety,
  r_single_group_comp_rec,
  r_single_group_comp_trans,
  r_single_group_comp_util,
  headers = c(
    'Education',
    'Other',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
  'Panel E: Grouped single-category share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_single_category_grouped_amount_composition_controls.tex')
)

single_grouped_issuer_denominator <- single_category_restricted_grouped[
  ,
  .(
    go_or_strict_gg_amount = sum(amount, na.rm = TRUE),
    strict_gg_revenue_amount =
      sum(amount * revenue_bond_security_g_source_g, na.rm = TRUE),
    go_or_strict_gg_bonds = uniqueN(cusip),
    strict_gg_revenue_bonds =
      uniqueN(cusip[revenue_bond_security_g_source_g == 1])
  ),
  by = .(
    seed_issuer_id,
    state,
    seed_issuer,
    vote_required,
    fips,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    high_state_tax_privilege,
    cities_issue_education,
    purpose_category_group
  )
]
single_grouped_issuer_denominator[
  ,
  share_revenue_security_g_source_g_vs_go_amount :=
    strict_gg_revenue_amount / go_or_strict_gg_amount
]

r_single_group_rev_educ <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_grouped_issuer_denominator[purpose_category_group == 'education'],
  vcov = vcov_cluster(~fips)
)
r_single_group_rev_other <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_grouped_issuer_denominator[purpose_category_group == 'other'],
  vcov = vcov_cluster(~fips)
)
r_single_group_rev_safety <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_grouped_issuer_denominator[purpose_category_group == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_single_group_rev_rec <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_grouped_issuer_denominator[purpose_category_group == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_single_group_rev_trans <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_grouped_issuer_denominator[purpose_category_group == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_single_group_rev_util <- feols(
  as.formula(paste0('share_revenue_security_g_source_g_vs_go_amount ~ vote_required + ', control_rhs)),
  data = single_grouped_issuer_denominator[purpose_category_group == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_single_group_rev_educ,
  r_single_group_rev_other,
  r_single_group_rev_safety,
  r_single_group_rev_rec,
  r_single_group_rev_trans,
  r_single_group_rev_util,
  headers = c(
    'Education',
    'Other',
    'Public Safety',
    'Recreation',
    'Transport.',
    'Utilities'
  ),
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
  'Panel F: Grouped single-category strict revenue share of GO plus strict revenue amount'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_single_category_grouped_strict_gg_revenue_share_controls.tex')
)

single_issuer_category_feasibility <- single_control_revenue_share[
  single_issuer_denominator,
  on = .(purpose_category)
]
single_issuer_category_feasibility <- single_issuer_category_feasibility[
  !is.na(control_state_strict_gg_revenue_share) &
    complete.cases(single_issuer_category_feasibility[, ..controls])
]

r_feasibility_single_category <- feols(
  as.formula(
    paste0(
      'share_revenue_security_g_source_g_vs_go_amount ~ ',
      'vote_required + vote_required:control_state_strict_gg_revenue_share + ',
      control_rhs,
      ' | purpose_category'
    )
  ),
  data = single_issuer_category_feasibility,
  vcov = vcov_cluster(~fips)
)

control_dict <- c(
  control_dict,
  'vote_required:control_state_strict_gg_revenue_share' =
    'Vote Required x Control Strict Rev. Share',
  control_state_strict_gg_revenue_share = 'Control Strict Rev. Share'
)

table_call <- etable(
  r_feasibility_full_stacked,
  r_feasibility_single_category,
  headers = c('All category labels', 'Single category only'),
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c(
    '%vote_required:control_state_strict_gg_revenue_share',
    '%vote_required'
  ),
  dict = control_dict,
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
  'Panel C: Control-state revenue use and vote-state substitution'
)
writeLines(
  modified_output,
  file.path(out_dir, '260707_purpose_substitution_control_revenue_feasibility_interaction.tex')
)

full_feasibility <- control_revenue_share[
  ,
  .(
    purpose_category,
    full_control_state_strict_gg_revenue_share =
      control_state_strict_gg_revenue_share,
    full_control_state_strict_gg_revenue_amount =
      control_state_strict_gg_revenue_amount,
    full_control_state_go_or_strict_gg_amount =
      control_state_go_or_strict_gg_amount
  )
]
single_feasibility <- single_control_revenue_share[
  ,
  .(
    purpose_category,
    single_control_state_strict_gg_revenue_share =
      control_state_strict_gg_revenue_share,
    single_control_state_strict_gg_revenue_amount =
      control_state_strict_gg_revenue_amount,
    single_control_state_go_or_strict_gg_amount =
      control_state_go_or_strict_gg_amount
  )
]
feasibility_diagnostics <- merge(
  full_feasibility,
  single_feasibility,
  by = 'purpose_category',
  all = TRUE
)
feasibility_diagnostics <- merge(
  feasibility_diagnostics,
  single_category_by_category,
  by = 'purpose_category',
  all.x = TRUE
)
fwrite(
  feasibility_diagnostics,
  file.path(out_dir, '260707_purpose_substitution_control_revenue_feasibility_by_category.csv')
)

full_coefs <- as.data.table(
  coeftable(r_feasibility_full_stacked),
  keep.rownames = 'term'
)
full_coefs[, sample := 'all_category_labels']
single_coefs <- as.data.table(
  coeftable(r_feasibility_single_category),
  keep.rownames = 'term'
)
single_coefs[, sample := 'single_category_only']
feasibility_coefficients <- rbind(full_coefs, single_coefs, fill = TRUE)
setcolorder(feasibility_coefficients, c('sample', 'term'))
fwrite(
  feasibility_coefficients,
  file.path(out_dir, '260707_purpose_substitution_control_revenue_feasibility_coefficients.csv')
)
