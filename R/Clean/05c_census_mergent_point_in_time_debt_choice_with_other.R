#----------------------------
# 2017 full sample debt substitution (with other category): GO vote required
# first descriptives
#----------------------------
summary_2017 <- copy(full_sample_2017_unrestricted)
summary_2017[, utgo_only_vote := as.integer(city_go_vote == 1 & insample_utgo_only == 1)]

restricted_summary_vars <- c(
  "frac_utgo_outstanding",
  "frac_ltgo_outstanding",
  "frac_rev_outstanding",
  "mergent_wavg_yield_spread_go_revenue",
  "mergent_wavg_yield_spread_utgo",
  "mergent_wavg_yield_spread_ltgo",
  "mergent_wavg_yield_spread_revenue"
)
summary_2017[
  !is.na(mergent_total_bonds_outstanding) &
    mergent_total_bonds_outstanding >= 2,
  (restricted_summary_vars) := NA_real_
]

summary_vars_2017 <- c(
  "frac_utgo_outstanding_all",
  "frac_ltgo_outstanding_all",
  "frac_rev_outstanding_all",
  "frac_other_outstanding_all"
)

summary_labels_2017 <- c(
  "Pct UTGO",
  "Pct LTGO",
  "Pct Revenue",
  "Pct Other"
)

summary_desc_2017 <- summary_2017[, ..summary_vars_2017]
summary_desc_2017 <- summary_desc_2017[, lapply(.SD, function(col) {
  c(
    Unit = "City",
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
summary_desc_2017 <- data.table::transpose(summary_desc_2017, keep.names = "variable")
setnames(
  summary_desc_2017,
  c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
)
summary_desc_2017[, Variable := summary_labels_2017]
for (stat_col in c("Mean", "Std", "Min", "P1", "Median", "P99", "Max")) {
  set(summary_desc_2017, j = stat_col, value = round(as.numeric(summary_desc_2017[[stat_col]]), 2))
}
summary_desc_2017[, N := format(as.integer(N), big.mark = ",")]

summary_tex_2017 <- capture.output(print(
  xtable(summary_desc_2017),
  include.rownames = FALSE,
  sanitize.text.function = identity,
  tabular.environment = "tabular*",
  width = "\\textwidth",
  table.placement = "H"
))

for (i in seq_along(summary_tex_2017)) {
  if (grepl("\\\\begin\\{tabular\\*\\}", summary_tex_2017[i])) {
    summary_tex_2017[i] <- gsub(
      "\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}",
      "\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}",
      summary_tex_2017[i]
    )
    break
  }
}
for (i in seq_along(summary_tex_2017)) {
  if (grepl("\\\\end\\{tabular\\*\\}", summary_tex_2017[i])) {
    summary_tex_2017[i] <- gsub("\\\\end\\{tabular\\*\\}", "\\\\end{tabular*}", summary_tex_2017[i])
    break
  }
}
for (i in seq_along(summary_tex_2017)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", summary_tex_2017[i])) {
    summary_tex_2017[i] <- "  \\toprule"
    break
  }
}

summary_tex_2017 <- add_panel(
  summary_tex_2017,
  "Panel: Debt choice descriptive statistics with Other category",
  ncols = 10
)
writeLines(summary_tex_2017, file.path(tbl_dir_other, "issuer_level_desc_other.tex"))


#----------------------------
# 2017 full sample debt substitution (with other category): GO vote required
#----------------------------
full_sample_other_2017 <- full_sample_2017_unrestricted[
  !is.na(mergent_total_bonds_outstanding) &
    mergent_total_bonds_outstanding >= 2
]
allgo_utgo_uncontrolled_2017 <- feols(
  frac_utgo_outstanding_all ~ city_go_vote,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_utgo_uncontrolled_2017)

allgo_utgo_controlled_2017 <- feols(
  frac_utgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_utgo_controlled_2017)

allgo_ltgo_controlled_2017 <- feols(
  frac_ltgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_ltgo_controlled_2017)
allgo_revenue_controlled_2017 <- feols(
  frac_rev_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_revenue_controlled_2017)

allgo_other_controlled_2017 <- feols(
  frac_other_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_other_controlled_2017)

table_call <- etable(
  allgo_utgo_uncontrolled_2017,
  allgo_utgo_controlled_2017,
  allgo_ltgo_controlled_2017,
  allgo_revenue_controlled_2017,
  allgo_other_controlled_2017,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  order = c("%city_go_vote"),
  dict = c(control_dict[names(control_dict) != "city_go_vote"], city_go_vote = "GO Vote"),
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, "Panel A: GO vote required")
writeLines(modified_output, file.path(tbl_dir_other, "point_in_time_debt_choice_2017_allgo_all.tex"))

#----------------------------
# 2017 full sample debt substitution: only UTGO vote required
#----------------------------
utgo_only_utgo_uncontrolled_2017 <- feols(
  frac_utgo_outstanding_all ~ city_go_vote,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_utgo_uncontrolled_2017)

utgo_only_utgo_controlled_2017 <- feols(
  frac_utgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_utgo_controlled_2017)

utgo_only_ltgo_controlled_2017 <- feols(
  frac_ltgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_ltgo_controlled_2017)

utgo_only_revenue_controlled_2017 <- feols(
  frac_rev_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_revenue_controlled_2017)

utgo_only_other_controlled_2017 <- feols(
  frac_other_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_other_controlled_2017)

table_call <- etable(
  utgo_only_utgo_uncontrolled_2017,
  utgo_only_utgo_controlled_2017,
  utgo_only_ltgo_controlled_2017,
  utgo_only_revenue_controlled_2017,
  utgo_only_other_controlled_2017,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  order = c("%city_go_vote"),
  dict = c(control_dict[names(control_dict) != "city_go_vote"], city_go_vote = "UTGO Only Vote"),
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, "Panel B: Only UTGO vote required")
writeLines(modified_output, file.path(tbl_dir_other, "point_in_time_debt_choice_2017_utgo_only_all.tex"))

#----------------------------
# 2017 full sample yield spreads: all city GO vote variation - with other
#----------------------------
yield_2017_all_uncontrolled <- feols(
  mergent_wavg_yield_spread_all ~ city_go_vote,
  data = full_sample_other_2017,
  vcov = vcov_cluster(~state)
)

yield_2017_all_controlled <- feols(
  mergent_wavg_yield_spread_all ~ city_go_vote +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_all_zero_unrated +
    mergent_wavg_original_maturity_years_all +
    mergent_any_insured_all + mergent_any_callable_all +
    mergent_any_sinkable_all + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  yield_2017_all_uncontrolled, yield_2017_all_controlled,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  order = c("%city_go_vote"),
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(
  modified_output,
  "Panel A: Weighted average yield spread",
  ncols = 3
)
writeLines(
  modified_output,
  file.path(tbl_dir_other, "point_in_time_yield_spread_2017_full_sample_all_with_other.tex")
)

#----------------------------
# 2017 full sample yield spreads by bond type - with other
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
  data = full_sample_other_2017,
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
  data = full_sample_other_2017,
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
  data = full_sample_other_2017,
  vcov = vcov_cluster(~state)
)

yield_2017_other_controlled <- feols(
  mergent_wavg_yield_spread_other ~ city_go_vote +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_other_zero_unrated +
    mergent_wavg_original_maturity_years_other +
    mergent_any_insured_other + mergent_any_callable_other +
    mergent_any_sinkable_other + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  yield_2017_utgo_controlled,
  yield_2017_ltgo_controlled,
  yield_2017_revenue_controlled,
  yield_2017_other_controlled,
  headers = c("UTGO", "LTGO", "Revenue", "Other"),
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  keep_raw = "^city_go_vote$",
  order = c("%city_go_vote"),
  dict = control_dict,
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
outcome_header_idx <- grep(
  "^[[:space:]]*& Wtd\\. Avg\\. Yield Spread",
  modified_output
)
if (length(outcome_header_idx) > 0) {
  modified_output[outcome_header_idx[1]] <-
    " & \\multicolumn{3}{c}{Wtd. Avg. Yield Spread}\\\\"
}
modified_output <- format_table(modified_output, cluster_level = "State")
adj_r2_idx <- grep(
  "^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&",
  modified_output
)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    "   Controls                   & Yes & Yes & Yes\\\\",
    after = adj_r2_idx[1]
  )
}
modified_output <- add_panel(
  modified_output,
  "Panel B: Weighted average yield spread by bond type",
  ncols = 4,
  zero_width = TRUE
)
writeLines(
  modified_output,
  file.path(
    tbl_dir_other,
    "point_in_time_yield_spread_2017_full_sample_panel_b_utgo_ltgo_revenue_other.tex"
  )
)
