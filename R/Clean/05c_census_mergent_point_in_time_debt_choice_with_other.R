#----------------------------
# Refresh the 2017 all-public-debt composition from the October 2026 file
#----------------------------
# Step 05 builds the Census/control sample and the submitted GO/revenue
# outcomes. For this response-only extension, replace only the all-debt count,
# amounts, and shares with the expanded city CUSIP universe. The four-category
# definition remains exhaustive: Other includes COO, COP, and residual other
# debt. The source's bond_type == "cop" combines debt_type COO and COP, so the
# sensitivity results below report those two debt types separately.
expanded_bond_file <- file.path(
  root,
  "Data/Mergent/Clean/261013_city_cusiplevel_finsample_allpubdebt.dta"
)
expanded_bond_cols <- c(
  "cusip",
  "seed_issuer_id",
  "state",
  "offering_date",
  "maturity_date",
  "amount",
  "go_unlim",
  "go_lim",
  "rev",
  "debt_type",
  "bond_type"
)

expanded_bonds_2017 <- as.data.table(haven::read_dta(
  expanded_bond_file,
  col_select = tidyselect::all_of(expanded_bond_cols)
))
expanded_bonds_2017[, seed_issuer_id_join := round(as.numeric(seed_issuer_id), 1)]
expanded_bonds_2017 <- expanded_bonds_2017[
  !is.na(seed_issuer_id_join) &
    !is.na(amount) & amount > 0 &
    offering_date <= as.Date("2017-12-31") &
    maturity_date > as.Date("2017-12-31")
]

expanded_debt_2017 <- expanded_bonds_2017[, .(
  expanded_total_bonds = uniqueN(cusip),
  expanded_go_revenue_bonds = uniqueN(cusip[go_unlim == 1 | go_lim == 1 | rev == 1]),
  expanded_all_go_bonds = uniqueN(cusip[go_unlim == 1 | go_lim == 1]),
  expanded_utgo_bonds = uniqueN(cusip[go_unlim == 1]),
  expanded_ltgo_bonds = uniqueN(cusip[go_lim == 1]),
  expanded_revenue_bonds = uniqueN(cusip[rev == 1]),
  expanded_total_debt = sum(amount),
  expanded_utgo_debt = sum(amount[go_unlim == 1], na.rm = TRUE),
  expanded_ltgo_debt = sum(amount[go_lim == 1], na.rm = TRUE),
  expanded_revenue_debt = sum(amount[rev == 1], na.rm = TRUE),
  expanded_certificate_debt = sum(amount[bond_type == "cop"], na.rm = TRUE),
  expanded_coo_debt = sum(amount[debt_type == "COO"], na.rm = TRUE),
  expanded_cop_debt = sum(amount[debt_type == "COP"], na.rm = TRUE),
  expanded_other_ex_certificate_debt =
    sum(amount[bond_type == "other"], na.rm = TRUE)
), by = .(seed_issuer_id_join, state)]

expanded_debt_2017[, expanded_classified_debt :=
  expanded_utgo_debt + expanded_ltgo_debt + expanded_revenue_debt +
    expanded_certificate_debt + expanded_other_ex_certificate_debt]
partition_error <- expanded_debt_2017[
  abs(expanded_total_debt - expanded_classified_debt) >
    pmax(1, expanded_total_debt * 1e-10)
]
if (nrow(partition_error) > 0) {
  stop("The expanded Mergent debt categories do not exhaust total debt.")
}

expanded_debt_2017[, `:=`(
  expanded_other_debt =
    expanded_certificate_debt + expanded_other_ex_certificate_debt,
  frac_utgo_outstanding_expanded = expanded_utgo_debt / expanded_total_debt,
  frac_ltgo_outstanding_expanded = expanded_ltgo_debt / expanded_total_debt,
  frac_rev_outstanding_expanded = expanded_revenue_debt / expanded_total_debt,
  frac_other_outstanding_expanded =
    (expanded_certificate_debt + expanded_other_ex_certificate_debt) /
      expanded_total_debt,
  frac_certificate_outstanding_expanded =
    expanded_certificate_debt / expanded_total_debt,
  frac_coo_outstanding_expanded = expanded_coo_debt / expanded_total_debt,
  frac_cop_outstanding_expanded = expanded_cop_debt / expanded_total_debt,
  frac_other_ex_certificate_outstanding_expanded =
    expanded_other_ex_certificate_debt / expanded_total_debt
)]

full_sample_2017_unrestricted[, seed_issuer_id_join :=
  round(as.numeric(seed_issuer_id), 1)]
full_sample_2017_unrestricted[, `:=`(
  mergent_total_bonds_outstanding = NA_integer_,
  mergent_go_revenue_bonds_outstanding = NA_integer_,
  mergent_all_go_bonds_outstanding = NA_integer_,
  mergent_utgo_bonds_outstanding = NA_integer_,
  mergent_ltgo_bonds_outstanding = NA_integer_,
  mergent_revenue_bonds_outstanding = NA_integer_,
  mergent_total_outstanding_debt = NA_real_,
  mergent_total_outstanding_debt_mil = NA_real_,
  mergent_go_revenue_outstanding_debt = NA_real_,
  mergent_go_revenue_outstanding_debt_mil = NA_real_,
  mergent_all_go_outstanding_debt = NA_real_,
  mergent_all_go_outstanding_debt_mil = NA_real_,
  mergent_utgo_outstanding_debt = NA_real_,
  mergent_utgo_outstanding_debt_mil = NA_real_,
  mergent_ltgo_outstanding_debt = NA_real_,
  mergent_ltgo_outstanding_debt_mil = NA_real_,
  mergent_revenue_outstanding_debt = NA_real_,
  mergent_revenue_outstanding_debt_mil = NA_real_,
  mergent_other_outstanding_debt = NA_real_,
  mergent_other_outstanding_debt_mil = NA_real_,
  mergent_certificate_outstanding_debt = NA_real_,
  mergent_certificate_outstanding_debt_mil = NA_real_,
  mergent_coo_outstanding_debt = NA_real_,
  mergent_coo_outstanding_debt_mil = NA_real_,
  mergent_cop_outstanding_debt = NA_real_,
  mergent_cop_outstanding_debt_mil = NA_real_,
  mergent_other_ex_certificate_outstanding_debt = NA_real_,
  mergent_other_ex_certificate_outstanding_debt_mil = NA_real_,
  frac_go_outstanding_all = NA_real_,
  frac_utgo_outstanding_all = NA_real_,
  frac_ltgo_outstanding_all = NA_real_,
  frac_rev_outstanding_all = NA_real_,
  frac_other_outstanding_all = NA_real_,
  frac_certificate_outstanding_all = NA_real_,
  frac_coo_outstanding_all = NA_real_,
  frac_cop_outstanding_all = NA_real_,
  frac_other_ex_certificate_outstanding_all = NA_real_
)]
full_sample_2017_unrestricted[
  expanded_debt_2017,
  on = .(seed_issuer_id_join, state),
  `:=`(
    mergent_total_bonds_outstanding = i.expanded_total_bonds,
    mergent_go_revenue_bonds_outstanding = i.expanded_go_revenue_bonds,
    mergent_all_go_bonds_outstanding = i.expanded_all_go_bonds,
    mergent_utgo_bonds_outstanding = i.expanded_utgo_bonds,
    mergent_ltgo_bonds_outstanding = i.expanded_ltgo_bonds,
    mergent_revenue_bonds_outstanding = i.expanded_revenue_bonds,
    mergent_total_outstanding_debt = i.expanded_total_debt,
    mergent_total_outstanding_debt_mil = i.expanded_total_debt / 1e6,
    mergent_go_revenue_outstanding_debt =
      i.expanded_utgo_debt + i.expanded_ltgo_debt + i.expanded_revenue_debt,
    mergent_go_revenue_outstanding_debt_mil =
      (i.expanded_utgo_debt + i.expanded_ltgo_debt + i.expanded_revenue_debt) / 1e6,
    mergent_all_go_outstanding_debt = i.expanded_utgo_debt + i.expanded_ltgo_debt,
    mergent_all_go_outstanding_debt_mil =
      (i.expanded_utgo_debt + i.expanded_ltgo_debt) / 1e6,
    mergent_utgo_outstanding_debt = i.expanded_utgo_debt,
    mergent_utgo_outstanding_debt_mil = i.expanded_utgo_debt / 1e6,
    mergent_ltgo_outstanding_debt = i.expanded_ltgo_debt,
    mergent_ltgo_outstanding_debt_mil = i.expanded_ltgo_debt / 1e6,
    mergent_revenue_outstanding_debt = i.expanded_revenue_debt,
    mergent_revenue_outstanding_debt_mil = i.expanded_revenue_debt / 1e6,
    mergent_other_outstanding_debt = i.expanded_other_debt,
    mergent_other_outstanding_debt_mil = i.expanded_other_debt / 1e6,
    mergent_certificate_outstanding_debt = i.expanded_certificate_debt,
    mergent_certificate_outstanding_debt_mil = i.expanded_certificate_debt / 1e6,
    mergent_coo_outstanding_debt = i.expanded_coo_debt,
    mergent_coo_outstanding_debt_mil = i.expanded_coo_debt / 1e6,
    mergent_cop_outstanding_debt = i.expanded_cop_debt,
    mergent_cop_outstanding_debt_mil = i.expanded_cop_debt / 1e6,
    mergent_other_ex_certificate_outstanding_debt =
      i.expanded_other_ex_certificate_debt,
    mergent_other_ex_certificate_outstanding_debt_mil =
      i.expanded_other_ex_certificate_debt / 1e6,
    frac_go_outstanding_all =
      (i.expanded_utgo_debt + i.expanded_ltgo_debt) / i.expanded_total_debt,
    frac_utgo_outstanding_all = i.frac_utgo_outstanding_expanded,
    frac_ltgo_outstanding_all = i.frac_ltgo_outstanding_expanded,
    frac_rev_outstanding_all = i.frac_rev_outstanding_expanded,
    frac_other_outstanding_all = i.frac_other_outstanding_expanded,
    frac_certificate_outstanding_all = i.frac_certificate_outstanding_expanded,
    frac_coo_outstanding_all = i.frac_coo_outstanding_expanded,
    frac_cop_outstanding_all = i.frac_cop_outstanding_expanded,
    frac_other_ex_certificate_outstanding_all =
      i.frac_other_ex_certificate_outstanding_expanded
  )
]
full_sample_2017_unrestricted[, seed_issuer_id_join := NULL]

control_dict["frac_other_outstanding_all"] <- "Pct Other (incl. COO/COP)"
control_dict <- c(
  control_dict,
  frac_certificate_outstanding_all = "Pct COO/COP",
  frac_coo_outstanding_all = "Pct COO",
  frac_cop_outstanding_all = "Pct COP",
  frac_other_ex_certificate_outstanding_all = "Pct Other (excl. COO/COP)"
)

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
  "frac_utgo_outstanding_all",
  "frac_ltgo_outstanding_all",
  "frac_rev_outstanding_all",
  "frac_other_outstanding_all",
  "frac_certificate_outstanding_all",
  "frac_coo_outstanding_all",
  "frac_cop_outstanding_all",
  "frac_other_ex_certificate_outstanding_all",
  "mergent_wavg_yield_spread_go_revenue",
  "mergent_wavg_yield_spread_utgo",
  "mergent_wavg_yield_spread_ltgo",
  "mergent_wavg_yield_spread_revenue"
)
summary_2017[
  is.na(mergent_total_bonds_outstanding) |
    mergent_total_bonds_outstanding < 2,
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
  "Pct Other (incl. COO/COP)"
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
# 2017 COO/COP breakout sensitivity
#----------------------------
# These outcomes partition the main Other share into COO, COP, and all
# remaining public debt. Keep the main tables above on the inclusive Other
# definition so their four debt-choice outcomes continue to sum to one.
allgo_coo_controlled_2017 <- feols(
  frac_coo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_cop_controlled_2017 <- feols(
  frac_cop_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_other_ex_certificate_controlled_2017 <- feols(
  frac_other_ex_certificate_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

# COO is identically zero in the UTGO-only sample, so only COP and residual
# Other are estimable for that comparison.
utgo_only_cop_controlled_2017 <- feols(
  frac_cop_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

utgo_only_other_ex_certificate_controlled_2017 <- feols(
  frac_other_ex_certificate_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  allgo_coo_controlled_2017,
  allgo_cop_controlled_2017,
  allgo_other_ex_certificate_controlled_2017,
  utgo_only_cop_controlled_2017,
  utgo_only_other_ex_certificate_controlled_2017,
  headers = list(
    "^ " = list("GO vote required" = 3, "Only UTGO vote required" = 2),
    "- " = c("COO", "COP", "Other excl. COO/COP", "COP", "Other excl. COO/COP")
  ),
  depvar = FALSE,
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
  dict = c(control_dict[names(control_dict) != "city_go_vote"], city_go_vote = "Vote"),
  placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(
  modified_output,
  "Panel: COO/COP breakout of the Other category",
  ncols = 6
)
writeLines(
  modified_output,
  file.path(tbl_dir_other, "point_in_time_debt_choice_2017_coo_cop_breakout.tex")
)

#----------------------------
# 2017 full sample yield spreads: all city GO vote variation - with other
#----------------------------
# These yield fields remain the step-05 measures. The October composition
# refresh above updates debt amounts and shares only; the current NC spread
# file has no matched spreads for the newly classified COO/COP bonds.
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
