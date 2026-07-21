# Point-in-time DPC purpose substitution tests
rm(list = ls())

library(pacman)
p_load(data.table, fixest, ggplot2)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/tax_privilege_definitions.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
panel_dir <- file.path(root, 'Data/DPC Data/Use Of Proceeds/Purposes Substitution')
tbl_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')
fig_dir <- file.path(root, 'Code/R/Clean/output/revision_figures')
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

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

reported_categories <- rev(categories[categories != 'other'])
reported_category_headers <- rev(category_headers[categories != 'other'])

control_dict <- c(
  city_go_vote = 'Vote',
  ln_gdp = 'County ln(GDP)',
  ln_census_population = 'City ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  ln_1p_census_total_debt = 'ln(1 + Census Total Debt)',
  ln_1p_county_nonmunicipal_total_debt = 'County Non-City Debt',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  low_state_tax_privilege = 'Low Tax Priv.',
  category_amount_share_of_go_or_revenue = 'Category Amt. Share',
  category_amount_mil = 'Par of Outstanding Bonds (millions)',
  share_revenue_vs_go_amount = 'Pct Revenue'
)

write_revenue_amount_pie_charts <- function(sample_data, year, sample_suffix) {
  # The figure is saved at 13 inches and then scaled to roughly half that width
  # in the paper. Use display sizes here so the printed type remains near 8--9 pt.
  pie_base_size <- 15
  pie_label_size <- 4

  pie_categories <- reported_categories
  pie_headers <- reported_category_headers

  pie_totals <- sample_data[
    purpose_category %in% pie_categories & city_go_vote %in% c(0, 1),
    .(
      total_amount = sum(go_or_revenue_category_amount, na.rm = TRUE),
      revenue_amount = sum(revenue_category_amount, na.rm = TRUE)
    ),
    by = .(city_go_vote, purpose_category)
  ]

  pie_totals[, go_amount := total_amount - revenue_amount]
  if (any(pie_totals$go_amount < -1e-6)) {
    stop('Revenue par exceeds total GO-or-revenue par in the pie-chart sample.')
  }
  pie_totals[go_amount < 0, go_amount := 0]

  pie_data <- melt(
    pie_totals,
    id.vars = c('city_go_vote', 'purpose_category', 'total_amount'),
    measure.vars = c('revenue_amount', 'go_amount'),
    variable.name = 'security_type',
    value.name = 'amount'
  )
  pie_data[
    ,
    security_type := factor(
      security_type,
      levels = c('revenue_amount', 'go_amount'),
      labels = c('Revenue', 'GO')
    )
  ]
  pie_data[
    ,
    purpose_label := factor(
      purpose_category,
      levels = pie_categories,
      labels = pie_headers
    )
  ]
  pie_data[
    ,
    vote_group := factor(
      city_go_vote,
      levels = c(0, 1),
      labels = c('Vote = 0', 'Vote = 1')
    )
  ]
  pie_data[, share := fifelse(total_amount > 0, amount / total_amount, NA_real_)]
  pie_data[, percentage_label := sprintf('%.0f%%', 100 * share)]

  revenue_amount_pies <- ggplot(
    pie_data,
    aes(x = 1, y = share, fill = security_type)
  ) +
    geom_col(width = 1, color = 'white', linewidth = 0.35) +
    geom_text(
      aes(label = percentage_label),
      position = position_stack(vjust = 0.5),
      color = 'white',
      family = 'serif',
      fontface = 'bold',
      size = pie_label_size
    ) +
    coord_polar(theta = 'y') +
    facet_grid(
      rows = vars(vote_group),
      cols = vars(purpose_label),
      switch = 'y'
    ) +
    scale_fill_manual(values = c('Revenue' = '#3D3D3D', 'GO' = '#BDBDBD')) +
    labs(fill = NULL) +
    guides(
      fill = guide_legend(
        override.aes = list(color = 'black', linewidth = 0.4)
      )
    ) +
    theme_void(base_size = pie_base_size, base_family = 'serif') +
    theme(
      strip.background = element_rect(fill = 'white', color = 'black', linewidth = 0.35),
      strip.text.x = element_text(
        size = pie_base_size,
        face = 'bold',
        margin = margin(5, 3, 5, 3)
      ),
      strip.text.y.left = element_text(
        size = pie_base_size,
        angle = 0,
        face = 'bold',
        margin = margin(4, 6, 4, 6)
      ),
      strip.placement = 'outside',
      panel.spacing.x = unit(0.35, 'lines'),
      panel.spacing.y = unit(0.8, 'lines'),
      legend.position = 'bottom',
      legend.text = element_text(size = pie_base_size),
      legend.key.height = unit(0.7, 'lines'),
      legend.key.width = unit(1.1, 'lines'),
      plot.margin = margin(10, 12, 10, 12),
      panel.background = element_rect(fill = 'white', color = NA),
      plot.background = element_rect(fill = 'white', color = NA),
      legend.background = element_rect(fill = 'white', color = NA)
    )

  output_stem <- file.path(
    fig_dir,
    sprintf('point_in_time_purpose_revenue_amount_pies_%s_%s', year, sample_suffix)
  )
  ggsave(
    paste0(output_stem, '.pdf'),
    plot = revenue_amount_pies,
    width = 13,
    height = 6,
    units = 'in',
    bg = 'white'
  )
  ggsave(
    paste0(output_stem, '.png'),
    plot = revenue_amount_pies,
    width = 13,
    height = 6,
    units = 'in',
    dpi = 300,
    bg = 'white'
  )

  invisible(list(plot = revenue_amount_pies, totals = pie_totals))
}

write_category_amount_ppml_table <- function(
    sample_data,
    year,
    sample_suffix,
    vote_label,
    panel_label) {
  models <- lapply(reported_categories, function(category) {
    fepois(
      category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
      data = sample_data[purpose_category == category],
      vcov = vcov_cluster(~state)
    )
  })

  no_vote_means <- vapply(
    reported_categories,
    function(category) {
      mean(
        sample_data[purpose_category == category & city_go_vote == 0]$category_amount_mil,
        na.rm = TRUE
      )
    },
    numeric(1)
  )
  pct_effects <- vapply(
    models,
    function(model) 100 * expm1(coef(model)[['city_go_vote']]),
    numeric(1)
  )

  table_call <- etable(
    models[[1]], models[[2]], models[[3]], models[[4]], models[[5]],
    headers = reported_category_headers,
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
    dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = vote_label),
    placement = 'H'
  )

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = 'State')
  modified_output <- add_panel(modified_output, panel_label, ncols = 6)
  writeLines(
    modified_output,
    file.path(
      tbl_dir,
      sprintf('point_in_time_purpose_category_amount_ppml_%s_%s.tex', year, sample_suffix)
    )
  )

  results <- data.table(
    year = year,
    sample = sample_suffix,
    category = reported_category_headers,
    estimate = vapply(models, function(model) coef(model)[['city_go_vote']], numeric(1)),
    z_stat = vapply(
      models,
      function(model) coeftable(model)['city_go_vote', 3],
      numeric(1)
    ),
    p_value = vapply(
      models,
      function(model) coeftable(model)['city_go_vote', 4],
      numeric(1)
    ),
    implied_pct_effect = pct_effects,
    no_vote_mean_mil = no_vote_means,
    observations = vapply(models, nobs, numeric(1))
  )
  print(results)
  invisible(list(models = models, results = results))
}

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
add_low_state_tax_privilege(purpose_2017, year_value = 2017)

purpose_2017[, fips := as.character(fips)]

purpose_2017 <- purpose_2017[
  !is.na(city_go_vote) &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) &
    mergent_go_revenue_bonds_outstanding >= 2
]

purpose_2017_allgo <- purpose_2017[insample_allgo == 1]
purpose_2017_utgo <- purpose_2017[insample_utgo_only == 1]
purpose_2017_full <- purpose_2017[insample == 1]
purpose_2017_allgo[, category_amount_mil := category_amount / 1000000]
purpose_2017_utgo[, category_amount_mil := category_amount / 1000000]
purpose_2017_full[, category_amount_mil := category_amount / 1000000]

purpose_pies_2017_full <- write_revenue_amount_pie_charts(
  sample_data = purpose_2017_full,
  year = 2017,
  sample_suffix = 'full_sample'
)

ppml_amount_2017_allgo <- write_category_amount_ppml_table(
  sample_data = purpose_2017_allgo,
  year = 2017,
  sample_suffix = 'allgo',
  vote_label = 'Vote',
  panel_label = 'Panel A: Par amount outstanding by purpose'
)
ppml_amount_2017_utgo <- write_category_amount_ppml_table(
  sample_data = purpose_2017_utgo,
  year = 2017,
  sample_suffix = 'utgo_only',
  vote_label = 'Vote',
  panel_label = 'Panel A: Par amount outstanding by purpose'
)
ppml_amount_2017_full <- write_category_amount_ppml_table(
  sample_data = purpose_2017_full,
  year = 2017,
  sample_suffix = 'full_sample',
  vote_label = 'Vote',
  panel_label = 'Panel A: Par amount outstanding by purpose'
)

#----------------------------
# 2017 category composition: GO vote required
#----------------------------
r_comp_2017_allgo_other <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_allgo_pub_build <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_allgo_safety <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_allgo_rec <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_allgo_trans <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_allgo_util <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
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
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel A: 2017 category share, GO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_category_share_2017_allgo.tex'))

#----------------------------
# 2017 category composition: only UTGO vote required
#----------------------------
r_comp_2017_utgo_other <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_utgo_pub_build <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_utgo_safety <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_utgo_rec <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_utgo_trans <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_utgo_util <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
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
  dict = c(control_dict[names(control_dict) != 'city_go_vote'], city_go_vote = 'Vote'),
  placement = 'H'
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel B: 2017 category share, only UTGO vote required')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_category_share_2017_utgo_only.tex'))

#----------------------------
# 2017 category composition: full sample
#----------------------------
r_comp_2017_full_other <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_full_pub_build <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_full_safety <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_full_rec <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_full_trans <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_comp_2017_full_util <- feols(
  category_amount_share_of_go_or_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_census_total_debt +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
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
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel C: 2017 category share, full sample')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_category_share_2017_full_sample.tex'))

#----------------------------
# 2017 revenue share: GO vote required
#----------------------------
r_rev_2017_allgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_allgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_allgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_allgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_allgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_allgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_allgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_rev_2017_allgo_util, r_rev_2017_allgo_trans, r_rev_2017_allgo_rec,
  r_rev_2017_allgo_safety, r_rev_2017_allgo_pub_build,
  headers = reported_category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: Pct Revenue by purpose')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2017_allgo.tex'))

#----------------------------
# 2017 revenue share: only UTGO vote required
#----------------------------
r_rev_2017_utgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_utgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_utgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_utgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_utgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_utgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_utgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_rev_2017_utgo_util, r_rev_2017_utgo_trans, r_rev_2017_utgo_rec,
  r_rev_2017_utgo_safety, r_rev_2017_utgo_pub_build,
  headers = reported_category_headers,
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
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel B: Pct Revenue by purpose')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2017_utgo_only.tex'))

#----------------------------
# 2017 revenue share: full sample
#----------------------------
r_rev_2017_full_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_full_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_full_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_full_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_full_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_rev_2017_full_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2017_full[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_rev_2017_full_util, r_rev_2017_full_trans, r_rev_2017_full_rec,
  r_rev_2017_full_safety, r_rev_2017_full_pub_build,
  headers = reported_category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: Pct Revenue by purpose')
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
add_low_state_tax_privilege(purpose_2012, year_value = 2012)

purpose_2012[, fips := as.character(fips)]

purpose_2012 <- purpose_2012[
  !is.na(city_go_vote) &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) &
    mergent_go_revenue_bonds_outstanding >= 2
]

purpose_2012_allgo <- purpose_2012[insample_allgo == 1]
purpose_2012_utgo <- purpose_2012[insample_utgo_only == 1]
purpose_2012_full <- purpose_2012[insample == 1]
purpose_2012_allgo[, category_amount_mil := category_amount / 1000000]
purpose_2012_utgo[, category_amount_mil := category_amount / 1000000]
purpose_2012_full[, category_amount_mil := category_amount / 1000000]

purpose_pies_2012_full <- write_revenue_amount_pie_charts(
  sample_data = purpose_2012_full,
  year = 2012,
  sample_suffix = 'full_sample'
)

ppml_amount_2012_allgo <- write_category_amount_ppml_table(
  sample_data = purpose_2012_allgo,
  year = 2012,
  sample_suffix = 'allgo',
  vote_label = 'Vote',
  panel_label = 'Panel A: Par amount outstanding by purpose'
)
ppml_amount_2012_utgo <- write_category_amount_ppml_table(
  sample_data = purpose_2012_utgo,
  year = 2012,
  sample_suffix = 'utgo_only',
  vote_label = 'Vote',
  panel_label = 'Panel A: Par amount outstanding by purpose'
)
ppml_amount_2012_full <- write_category_amount_ppml_table(
  sample_data = purpose_2012_full,
  year = 2012,
  sample_suffix = 'full_sample',
  vote_label = 'Vote',
  panel_label = 'Panel A: Par amount outstanding by purpose'
)

#----------------------------
# 2012 revenue share: GO vote required
#----------------------------
r_rev_2012_allgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_allgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_allgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_allgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_allgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_allgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_allgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_rev_2012_allgo_util, r_rev_2012_allgo_trans, r_rev_2012_allgo_rec,
  r_rev_2012_allgo_safety, r_rev_2012_allgo_pub_build,
  headers = reported_category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: Pct Revenue by purpose')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2012_allgo.tex'))

#----------------------------
# 2012 revenue share: only UTGO vote required
#----------------------------
r_rev_2012_utgo_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_utgo_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_utgo_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_utgo_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_utgo_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_utgo_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_utgo[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_rev_2012_utgo_util, r_rev_2012_utgo_trans, r_rev_2012_utgo_rec,
  r_rev_2012_utgo_safety, r_rev_2012_utgo_pub_build,
  headers = reported_category_headers,
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
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(modified_output, 'Panel B: Pct Revenue by purpose')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2012_utgo_only.tex'))

#----------------------------
# 2012 revenue share: full sample
#----------------------------
r_rev_2012_full_other <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'other'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_full_pub_build <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'other_public_buildings'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_full_safety <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'public_safety'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_full_rec <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'recreation_amenities'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_full_trans <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'transportation'],
  vcov = vcov_cluster(~state)
)
r_rev_2012_full_util <- feols(
  share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = purpose_2012_full[purpose_category == 'utilities'],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  r_rev_2012_full_util, r_rev_2012_full_trans, r_rev_2012_full_rec,
  r_rev_2012_full_safety, r_rev_2012_full_pub_build,
  headers = reported_category_headers,
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
modified_output <- add_panel(modified_output, 'Panel B: Pct Revenue by purpose')
writeLines(modified_output, file.path(tbl_dir, 'point_in_time_purpose_revenue_share_2012_full_sample.tex'))
