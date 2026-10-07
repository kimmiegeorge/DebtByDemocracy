# Point-in-time DPC purpose substitution tests
rm(list = ls())

library(pacman)
p_load(data.table, fixest)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
panel_dir <- file.path(root, 'Data/DPC Data/Use Of Proceeds/Purposes Substitution')
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables'

categories <- c(
  'other_public_buildings',
  'public_safety',
  'recreation_amenities',
  'transportation',
  'utilities',
  'other'
)

category_headers <- c(
  'Public Bldg.',
  'Public Safety',
  'Recreation',
  'Transport.',
  'Utilities',
  'Other'
)

control_dict <- c(
  city_go_vote = 'GO Vote',
  ln_gdp = 'County ln(GDP)',
  ln_census_population = 'City ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  ln_1p_census_total_debt = 'ln(1 + Census Total Debt)',
  ln_1p_county_nonmunicipal_total_debt = 'ln(1 + County Noncity Debt)',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  high_state_tax_privilege = 'High Tax Priv.',
  category_amount_share_of_go_or_revenue = 'Category Amt. Share',
  share_revenue_vs_go_amount = 'Revenue Amt. Share'
)

#==============================================================================
# 2017 point-in-time purpose substitution
#==============================================================================

purpose_2017 <- fread(
  file.path(panel_dir, '260719_dpc_point_in_time_purpose_substitution_2017_issuer_category_panel.csv')
)

if ('nh_city' %in% names(purpose_2017)) {
  purpose_2017 <- purpose_2017[!(state == 'NH' & nh_city == 0)]
} else if ('government_type_label' %in% names(purpose_2017)) {
  purpose_2017 <- purpose_2017[!(state == 'NH' & government_type_label == 'township')]
} else {
  purpose_2017 <- purpose_2017[
    !(state == 'NH' & grepl('\\b(TOWN|TWP|TOWNSHIP)\\b', toupper(seed_issuer)))
  ]
}
purpose_2017[state == 'ME', city_go_vote := NA_real_]

purpose_2017[, fips := as.character(fips)]

purpose_2017 <- purpose_2017[
  !is.na(city_go_vote) &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_census_total_debt) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(high_state_tax_privilege)
]

purpose_2017_allgo <- purpose_2017[insample_allgo == 1]
purpose_2017_utgo <- purpose_2017[insample_utgo_only == 1]
purpose_2017_full <- purpose_2017[insample == 1]

#----------------------------
# 2017 category composition: GO vote required
#----------------------------
r_comp_2017_allgo_other <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_allgo_pub_build <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_allgo_safety <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_allgo_rec <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_allgo_trans <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_allgo_util <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_comp_2017_allgo_pub_build, r_comp_2017_allgo_safety, r_comp_2017_allgo_rec,
  r_comp_2017_allgo_trans, r_comp_2017_allgo_util, r_comp_2017_allgo_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel A: 2017 category share, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_category_share_2017_allgo.tex'))

#----------------------------
# 2017 category composition: only UTGO vote required
#----------------------------
r_comp_2017_utgo_other <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_utgo_pub_build <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_utgo_safety <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_utgo_rec <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_utgo_trans <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_utgo_util <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_comp_2017_utgo_pub_build, r_comp_2017_utgo_safety, r_comp_2017_utgo_rec,
  r_comp_2017_utgo_trans, r_comp_2017_utgo_util, r_comp_2017_utgo_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: 2017 category share, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_category_share_2017_utgo_only.tex'))

#----------------------------
# 2017 category composition: full sample
#----------------------------
r_comp_2017_full_other <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_full_pub_build <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_full_safety <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_full_rec <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_full_trans <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_comp_2017_full_util <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_comp_2017_full_pub_build, r_comp_2017_full_safety, r_comp_2017_full_rec,
  r_comp_2017_full_trans, r_comp_2017_full_util, r_comp_2017_full_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel C: 2017 category share, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_category_share_2017_full_sample.tex'))

#----------------------------
# 2017 revenue share: GO vote required
#----------------------------
r_rev_2017_allgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_allgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_allgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_allgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_allgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_allgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_rev_2017_allgo_pub_build, r_rev_2017_allgo_safety, r_rev_2017_allgo_rec,
  r_rev_2017_allgo_trans, r_rev_2017_allgo_util, r_rev_2017_allgo_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel A: 2017 revenue share, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2017_allgo.tex'))

#----------------------------
# 2017 revenue share: only UTGO vote required
#----------------------------
r_rev_2017_utgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_utgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_utgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_utgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_utgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_utgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_rev_2017_utgo_pub_build, r_rev_2017_utgo_safety, r_rev_2017_utgo_rec,
  r_rev_2017_utgo_trans, r_rev_2017_utgo_util, r_rev_2017_utgo_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: 2017 revenue share, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2017_utgo_only.tex'))

#----------------------------
# 2017 revenue share: full sample
#----------------------------
r_rev_2017_full_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_full_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_full_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_full_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_full_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_2017_full_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_rev_2017_full_pub_build, r_rev_2017_full_safety, r_rev_2017_full_rec,
  r_rev_2017_full_trans, r_rev_2017_full_util, r_rev_2017_full_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel C: 2017 revenue share, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2017_full_sample.tex'))

#==============================================================================
# 2012 point-in-time purpose substitution
#==============================================================================

purpose_2012 <- fread(
  file.path(panel_dir, '260719_dpc_point_in_time_purpose_substitution_2012_issuer_category_panel.csv')
)

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

purpose_2012[, fips := as.character(fips)]

purpose_2012 <- purpose_2012[
  !is.na(city_go_vote) &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_census_total_debt) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(high_state_tax_privilege)
]

purpose_2012_allgo <- purpose_2012[insample_allgo == 1]
purpose_2012_utgo <- purpose_2012[insample_utgo_only == 1]
purpose_2012_full <- purpose_2012[insample == 1]

#----------------------------
# 2012 revenue share: GO vote required
#----------------------------
r_rev_2012_allgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_allgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_allgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_allgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_allgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_allgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_rev_2012_allgo_pub_build, r_rev_2012_allgo_safety, r_rev_2012_allgo_rec,
  r_rev_2012_allgo_trans, r_rev_2012_allgo_util, r_rev_2012_allgo_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel A: 2012 revenue share, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2012_allgo.tex'))

#----------------------------
# 2012 revenue share: only UTGO vote required
#----------------------------
r_rev_2012_utgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_utgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_utgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_utgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_utgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_utgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_rev_2012_utgo_pub_build, r_rev_2012_utgo_safety, r_rev_2012_utgo_rec,
  r_rev_2012_utgo_trans, r_rev_2012_utgo_util, r_rev_2012_utgo_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: 2012 revenue share, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2012_utgo_only.tex'))

#----------------------------
# 2012 revenue share: full sample
#----------------------------
r_rev_2012_full_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'other'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_full_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_full_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_full_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_full_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'transportation'],
  vcov = vcov_cluster(~fips)
)
r_rev_2012_full_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + high_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'utilities'],
  vcov = vcov_cluster(~fips)
)

table_call <- etable(
  r_rev_2012_full_pub_build, r_rev_2012_full_safety, r_rev_2012_full_rec,
  r_rev_2012_full_trans, r_rev_2012_full_util, r_rev_2012_full_other,
  headers = category_headers,
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
modified_output <- add_panel(modified_output, 'Panel C: 2012 revenue share, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2012_full_sample.tex'))
