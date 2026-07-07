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
