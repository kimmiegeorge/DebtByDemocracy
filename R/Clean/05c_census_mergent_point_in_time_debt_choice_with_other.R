#----------------------------
# Refresh the 2017 all-public-debt composition from the v2020 source file
#----------------------------
# Step 05 builds the Census/control sample and the submitted GO/revenue
# outcomes. For this response-only extension, replace only the all-debt count,
# amounts, and shares with the expanded city CUSIP universe. The four-category
# definition remains exhaustive: Other includes COO, COP, and residual other
# debt. The source's bond_type == "cop" combines debt_type COO and COP, so the
# sensitivity results below report those two debt types separately.
expanded_bond_file <- Sys.getenv(
  "MERGENT_ALLPUBDEBT_FILE",
  unset = file.path(
    root,
    "Data/Mergent/Clean/261013_city_cusiplevel_finsample_allpubdebt_v2020.dta"
  )
)
expanded_bond_cols <- c(
  "issue_id",
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
  "bond_type",
  "new_money",
  "insured",
  "callable",
  "sinkable",
  "rated",
  "rating_f",
  "rating_s",
  "rating_m"
)

expanded_bonds_2017 <- as.data.table(haven::read_dta(
  expanded_bond_file,
  col_select = tidyselect::all_of(expanded_bond_cols)
))
expanded_bonds_2017[, issue_id := as.numeric(issue_id)]
expanded_bonds_2017[, seed_issuer_id_join := round(as.numeric(seed_issuer_id), 1)]

# The v2020 file contains both new-money and refunding bonds. Apply the
# submitted-analysis new-money screen before constructing any debt, yield, or
# bond-control measure so refunding CUSIPs cannot affect the 05c results.
expanded_bonds_2017 <- expanded_bonds_2017[new_money == 1]

# Attach the NC/Garrett et al. spread rebuilt from the same v2020 bond file.
expanded_spread_file <- file.path(
  root,
  "Data/Clean_Intermediate/Mergent/Clean/bond_level_off_yield_spread_allbonds.csv"
)
expanded_spreads <- fread(
  expanded_spread_file,
  select = c("issue_id", "cusip", "offering_yield_spread_nc")
)
expanded_spreads[, `:=`(
  issue_id = as.numeric(issue_id),
  cusip = as.character(cusip)
)]
expanded_bonds_2017[, cusip := as.character(cusip)]
expanded_bonds_2017[
  expanded_spreads,
  on = .(issue_id, cusip),
  offering_yield_spread_nc := i.offering_yield_spread_nc
]

# Reconstruct the issuance-level rating used by the existing point-in-time
# controls. In the v2020 all-public-debt file, rating_m is Moody's and
# rating_s is S&P, so map each raw field directly to its agency's scale.
moody_rating_num <- c(
  Aaa = 16, Aa1 = 15, Aa2 = 14, Aa3 = 13, A1 = 12, A2 = 11,
  A3 = 10, Baa1 = 9, Baa2 = 8, Baa3 = 7, Ba1 = 6, Ba2 = 5,
  Ba3 = 4, WR = 1
)
sp_rating_num <- c(
  AAA = 16, `AA+` = 15, AA = 14, `AA-` = 13, `A+` = 12, A = 11,
  `A-` = 10, `BBB+` = 9, BBB = 8, `BBB-` = 7, `BB+` = 6,
  BB = 5, `BB-` = 4, `B+` = 3, B = 2
)
fitch_rating_num <- c(sp_rating_num, W = 1)

expanded_bonds_2017[, rating_m_clean := trimws(as.character(rating_m))]
expanded_bonds_2017[rating_m_clean == "#Aaa", rating_m_clean := "Aaa"]
expanded_bonds_2017[, rating_s_clean := trimws(as.character(rating_s))]
expanded_bonds_2017[, rating_f_clean := trimws(as.character(rating_f))]
expanded_bonds_2017[, rating_num := fcoalesce(
  unname(moody_rating_num[rating_m_clean]),
  unname(sp_rating_num[rating_s_clean]),
  unname(fitch_rating_num[rating_f_clean])
)]
expanded_bonds_2017[rated == 0, rating_num := 0]

expanded_issue_ratings <- expanded_bonds_2017[, .(
  rating_issue_max_raw = if (all(is.na(rating_num))) {
    NA_real_
  } else {
    max(rating_num, na.rm = TRUE)
  },
  insured_issue = max(insured, na.rm = TRUE)
), by = issue_id]
expanded_issue_ratings[, rating_issue_max := fcase(
  rating_issue_max_raw == 0 & insured_issue == 1, 16,
  rating_issue_max_raw == 0, NA_real_,
  default = rating_issue_max_raw
)]
expanded_bonds_2017[
  expanded_issue_ratings,
  on = "issue_id",
  rating_issue_max := i.rating_issue_max
]

expanded_bonds_2017 <- expanded_bonds_2017[
  !is.na(seed_issuer_id_join) &
    !is.na(amount) & amount > 0 &
    offering_date <= as.Date("2017-12-31") &
    maturity_date > as.Date("2017-12-31")
]
expanded_bonds_2017[, original_maturity_years :=
  as.numeric(maturity_date - offering_date) / 365.25]

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

expanded_weighted_mean <- function(value, weight, mask) {
  valid <- !is.na(mask) & mask & !is.na(value) & !is.na(weight) & weight > 0
  if (!any(valid)) {
    return(NA_real_)
  }
  sum(value[valid] * weight[valid]) / sum(weight[valid])
}

expanded_weighted_mean_zero_missing <- function(value, weight, mask) {
  valid <- !is.na(mask) & mask & !is.na(weight) & weight > 0
  if (!any(valid)) {
    return(NA_real_)
  }
  value[is.na(value)] <- 0
  sum(value[valid] * weight[valid]) / sum(weight[valid])
}

expanded_any_indicator <- function(value, weight, mask) {
  weighted_share <- expanded_weighted_mean_zero_missing(value, weight, mask)
  if (is.na(weighted_share)) {
    return(NA_integer_)
  }
  as.integer(weighted_share > 0)
}

expanded_yield_2017 <- expanded_bonds_2017[, .(
  expanded_wavg_yield_spread_all = expanded_weighted_mean(
    offering_yield_spread_nc, amount, rep(TRUE, .N)
  ),
  expanded_wavg_yield_spread_utgo = expanded_weighted_mean(
    offering_yield_spread_nc, amount, go_unlim == 1
  ),
  expanded_wavg_yield_spread_ltgo = expanded_weighted_mean(
    offering_yield_spread_nc, amount, go_lim == 1
  ),
  expanded_wavg_yield_spread_revenue = expanded_weighted_mean(
    offering_yield_spread_nc, amount, rev == 1
  ),
  expanded_wavg_yield_spread_other = expanded_weighted_mean(
    offering_yield_spread_nc, amount, bond_type %chin% c("cop", "other")
  ),
  expanded_wavg_maturity_all = expanded_weighted_mean(
    original_maturity_years, amount, rep(TRUE, .N)
  ),
  expanded_wavg_maturity_utgo = expanded_weighted_mean(
    original_maturity_years, amount, go_unlim == 1
  ),
  expanded_wavg_maturity_ltgo = expanded_weighted_mean(
    original_maturity_years, amount, go_lim == 1
  ),
  expanded_wavg_maturity_revenue = expanded_weighted_mean(
    original_maturity_years, amount, rev == 1
  ),
  expanded_wavg_maturity_other = expanded_weighted_mean(
    original_maturity_years, amount, bond_type %chin% c("cop", "other")
  ),
  expanded_wavg_rating_all = expanded_weighted_mean_zero_missing(
    rating_issue_max, amount, rep(TRUE, .N)
  ),
  expanded_wavg_rating_utgo = expanded_weighted_mean_zero_missing(
    rating_issue_max, amount, go_unlim == 1
  ),
  expanded_wavg_rating_ltgo = expanded_weighted_mean_zero_missing(
    rating_issue_max, amount, go_lim == 1
  ),
  expanded_wavg_rating_revenue = expanded_weighted_mean_zero_missing(
    rating_issue_max, amount, rev == 1
  ),
  expanded_wavg_rating_other = expanded_weighted_mean_zero_missing(
    rating_issue_max, amount, bond_type %chin% c("cop", "other")
  ),
  expanded_any_insured_all = expanded_any_indicator(
    insured, amount, rep(TRUE, .N)
  ),
  expanded_any_insured_utgo = expanded_any_indicator(
    insured, amount, go_unlim == 1
  ),
  expanded_any_insured_ltgo = expanded_any_indicator(
    insured, amount, go_lim == 1
  ),
  expanded_any_insured_revenue = expanded_any_indicator(
    insured, amount, rev == 1
  ),
  expanded_any_insured_other = expanded_any_indicator(
    insured, amount, bond_type %chin% c("cop", "other")
  ),
  expanded_any_callable_all = expanded_any_indicator(
    callable, amount, rep(TRUE, .N)
  ),
  expanded_any_callable_utgo = expanded_any_indicator(
    callable, amount, go_unlim == 1
  ),
  expanded_any_callable_ltgo = expanded_any_indicator(
    callable, amount, go_lim == 1
  ),
  expanded_any_callable_revenue = expanded_any_indicator(
    callable, amount, rev == 1
  ),
  expanded_any_callable_other = expanded_any_indicator(
    callable, amount, bond_type %chin% c("cop", "other")
  ),
  expanded_any_sinkable_all = expanded_any_indicator(
    sinkable, amount, rep(TRUE, .N)
  ),
  expanded_any_sinkable_utgo = expanded_any_indicator(
    sinkable, amount, go_unlim == 1
  ),
  expanded_any_sinkable_ltgo = expanded_any_indicator(
    sinkable, amount, go_lim == 1
  ),
  expanded_any_sinkable_revenue = expanded_any_indicator(
    sinkable, amount, rev == 1
  ),
  expanded_any_sinkable_other = expanded_any_indicator(
    sinkable, amount, bond_type %chin% c("cop", "other")
  )
), by = .(seed_issuer_id_join, state)]

expanded_debt_2017 <- merge(
  expanded_debt_2017,
  expanded_yield_2017,
  by = c("seed_issuer_id_join", "state"),
  all.x = TRUE
)

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
  frac_other_ex_certificate_outstanding_all = NA_real_,
  mergent_wavg_yield_spread_all = NA_real_,
  mergent_wavg_yield_spread_utgo = NA_real_,
  mergent_wavg_yield_spread_ltgo = NA_real_,
  mergent_wavg_yield_spread_revenue = NA_real_,
  mergent_wavg_yield_spread_other = NA_real_,
  mergent_wavg_original_maturity_years_all = NA_real_,
  mergent_wavg_original_maturity_years_utgo = NA_real_,
  mergent_wavg_original_maturity_years_ltgo = NA_real_,
  mergent_wavg_original_maturity_years_revenue = NA_real_,
  mergent_wavg_original_maturity_years_other = NA_real_,
  mergent_wavg_rating_all_zero_unrated = NA_real_,
  mergent_wavg_rating_utgo_zero_unrated = NA_real_,
  mergent_wavg_rating_ltgo_zero_unrated = NA_real_,
  mergent_wavg_rating_revenue_zero_unrated = NA_real_,
  mergent_wavg_rating_other_zero_unrated = NA_real_,
  mergent_any_insured_all = NA_integer_,
  mergent_any_insured_utgo = NA_integer_,
  mergent_any_insured_ltgo = NA_integer_,
  mergent_any_insured_revenue = NA_integer_,
  mergent_any_insured_other = NA_integer_,
  mergent_any_callable_all = NA_integer_,
  mergent_any_callable_utgo = NA_integer_,
  mergent_any_callable_ltgo = NA_integer_,
  mergent_any_callable_revenue = NA_integer_,
  mergent_any_callable_other = NA_integer_,
  mergent_any_sinkable_all = NA_integer_,
  mergent_any_sinkable_utgo = NA_integer_,
  mergent_any_sinkable_ltgo = NA_integer_,
  mergent_any_sinkable_revenue = NA_integer_,
  mergent_any_sinkable_other = NA_integer_
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
      i.frac_other_ex_certificate_outstanding_expanded,
    mergent_wavg_yield_spread_all = i.expanded_wavg_yield_spread_all,
    mergent_wavg_yield_spread_utgo = i.expanded_wavg_yield_spread_utgo,
    mergent_wavg_yield_spread_ltgo = i.expanded_wavg_yield_spread_ltgo,
    mergent_wavg_yield_spread_revenue = i.expanded_wavg_yield_spread_revenue,
    mergent_wavg_yield_spread_other = i.expanded_wavg_yield_spread_other,
    mergent_wavg_original_maturity_years_all = i.expanded_wavg_maturity_all,
    mergent_wavg_original_maturity_years_utgo = i.expanded_wavg_maturity_utgo,
    mergent_wavg_original_maturity_years_ltgo = i.expanded_wavg_maturity_ltgo,
    mergent_wavg_original_maturity_years_revenue = i.expanded_wavg_maturity_revenue,
    mergent_wavg_original_maturity_years_other = i.expanded_wavg_maturity_other,
    mergent_wavg_rating_all_zero_unrated = i.expanded_wavg_rating_all,
    mergent_wavg_rating_utgo_zero_unrated = i.expanded_wavg_rating_utgo,
    mergent_wavg_rating_ltgo_zero_unrated = i.expanded_wavg_rating_ltgo,
    mergent_wavg_rating_revenue_zero_unrated = i.expanded_wavg_rating_revenue,
    mergent_wavg_rating_other_zero_unrated = i.expanded_wavg_rating_other,
    mergent_any_insured_all = i.expanded_any_insured_all,
    mergent_any_insured_utgo = i.expanded_any_insured_utgo,
    mergent_any_insured_ltgo = i.expanded_any_insured_ltgo,
    mergent_any_insured_revenue = i.expanded_any_insured_revenue,
    mergent_any_insured_other = i.expanded_any_insured_other,
    mergent_any_callable_all = i.expanded_any_callable_all,
    mergent_any_callable_utgo = i.expanded_any_callable_utgo,
    mergent_any_callable_ltgo = i.expanded_any_callable_ltgo,
    mergent_any_callable_revenue = i.expanded_any_callable_revenue,
    mergent_any_callable_other = i.expanded_any_callable_other,
    mergent_any_sinkable_all = i.expanded_any_sinkable_all,
    mergent_any_sinkable_utgo = i.expanded_any_sinkable_utgo,
    mergent_any_sinkable_ltgo = i.expanded_any_sinkable_ltgo,
    mergent_any_sinkable_revenue = i.expanded_any_sinkable_revenue,
    mergent_any_sinkable_other = i.expanded_any_sinkable_other
  )
]
full_sample_2017_unrestricted[, seed_issuer_id_join := NULL]

control_dict["frac_other_outstanding_all"] <- "Pct Other"
control_dict <- c(
  control_dict,
  mergent_total_outstanding_debt_mil = "Mergent Total Public Debt",
  frac_certificate_outstanding_all = "Pct COO/COP",
  frac_coo_outstanding_all = "Pct COO",
  frac_cop_outstanding_all = "Pct COP",
  frac_other_ex_certificate_outstanding_all = "Pct Other (excl. COO/COP)",
  mergent_wavg_yield_spread_all = "Wtd. Avg. Yield Spread",
  mergent_wavg_yield_spread_other = "Wtd. Avg. Yield Spread (Other)",
  mergent_wavg_rating_all_zero_unrated = "Wtd. Avg. Rating",
  mergent_wavg_rating_other_zero_unrated = "Wtd. Avg. Rating (Other)",
  mergent_wavg_original_maturity_years_all = "Wtd. Avg. Original Maturity",
  mergent_wavg_original_maturity_years_other =
    "Wtd. Avg. Original Maturity (Other)",
  mergent_any_insured_all = "Any Insured",
  mergent_any_callable_all = "Any Callable",
  mergent_any_sinkable_all = "Any Sinkable",
  mergent_any_insured_other = "Any Insured",
  mergent_any_callable_other = "Any Callable",
  mergent_any_sinkable_other = "Any Sinkable"
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

#----------------------------
# 2017 PPML debt stock: expanded referendum sample with all public debt
#----------------------------
# Match the expanded-sample table in step 05, then add total Mergent public
# debt rebuilt from the October 2026 all-bond file. Retain the GO + Revenue
# column so the expanded-debt estimate can be compared with the main measure.
expanded_total_debt_sample_2017 <- copy(data_2017[
  insample == 1 |
    (city_go_vote %in% 1 & city_rev_vote %in% 1)
])
expanded_total_debt_sample_2017[, seed_issuer_id_join :=
  round(as.numeric(seed_issuer_id), 1)]
# As in the step 05 cross section, a city with no matched outstanding bonds has
# zero Mergent debt rather than a missing debt outcome.
expanded_total_debt_sample_2017[, `:=`(
  mergent_go_revenue_outstanding_debt_mil = 0,
  mergent_total_outstanding_debt_mil = 0
)]
expanded_total_debt_sample_2017[
  expanded_debt_2017,
  on = .(seed_issuer_id_join, state),
  `:=`(
    mergent_go_revenue_outstanding_debt_mil =
      (i.expanded_utgo_debt + i.expanded_ltgo_debt +
        i.expanded_revenue_debt) / 1e6,
    mergent_total_outstanding_debt_mil = i.expanded_total_debt / 1e6
  )
]
expanded_total_debt_sample_2017[, seed_issuer_id_join := NULL]

census_total_debt_ppml_2017_expanded_other <- fixest::fepois(
  census_total_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = expanded_total_debt_sample_2017,
  vcov = vcov_cluster(~state)
)

census_long_term_debt_ppml_2017_expanded_other <- fixest::fepois(
  census_lt_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = expanded_total_debt_sample_2017,
  vcov = vcov_cluster(~state)
)

mergent_go_revenue_debt_ppml_2017_expanded_other <- fixest::fepois(
  mergent_go_revenue_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = expanded_total_debt_sample_2017,
  vcov = vcov_cluster(~state)
)

mergent_total_debt_ppml_2017_expanded_other <- fixest::fepois(
  mergent_total_outstanding_debt_mil ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = expanded_total_debt_sample_2017,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  census_total_debt_ppml_2017_expanded_other,
  census_long_term_debt_ppml_2017_expanded_other,
  mergent_go_revenue_debt_ppml_2017_expanded_other,
  mergent_total_debt_ppml_2017_expanded_other,
  headers = c("Total", "Long-term", "GO + Revenue", "All public"),
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
  fitstat = c("n", "pr2"),
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
modified_output <- sub(
  " & Census Total Debt & Census Long-Term Debt & Mergent GO + Revenue Debt & Mergent Total Public Debt\\\\",
  paste0(
    " & ", "\\", "multicolumn{2}{c}{Census Debt} & ",
    "\\", "multicolumn{2}{c}{Mergent Debt}\\\\"
  ),
  modified_output,
  fixed = TRUE
)
modified_output <- sub(
  " & Total & Long-term & GO + Revenue & All public \\\\",
  paste0(
    " & Total & Long-term & GO + Revenue & All public \\\\\n   ",
    "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}"
  ),
  modified_output,
  fixed = TRUE
)
modified_output <- format_table(modified_output, cluster_level = "State")
writeLines(
  modified_output,
  file.path(
    tbl_dir_other,
    "point_in_time_census_debt_poisson_2017_expanded_sample_with_other.tex"
  )
)

allgo_utgo_uncontrolled_2017 <- feols(
  frac_utgo_outstanding_all ~ city_go_vote,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_utgo_uncontrolled_2017)

allgo_utgo_controlled_2017 <- feols(
  frac_utgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_utgo_controlled_2017)

allgo_ltgo_controlled_2017 <- feols(
  frac_ltgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_ltgo_controlled_2017)
allgo_revenue_controlled_2017 <- feols(
  frac_rev_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)
summary(allgo_revenue_controlled_2017)

allgo_other_controlled_2017 <- feols(
  frac_other_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_utgo_controlled_2017)

utgo_only_ltgo_controlled_2017 <- feols(
  frac_ltgo_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_ltgo_controlled_2017)

utgo_only_revenue_controlled_2017 <- feols(
  frac_rev_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)
summary(utgo_only_revenue_controlled_2017)

utgo_only_other_controlled_2017 <- feols(
  frac_other_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_cop_controlled_2017 <- feols(
  frac_cop_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

allgo_other_ex_certificate_controlled_2017 <- feols(
  frac_other_ex_certificate_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_allgo == 1],
  vcov = vcov_cluster(~state)
)

# COO is identically zero in the UTGO-only sample, so only COP and residual
# Other are estimable for that comparison.
utgo_only_cop_controlled_2017 <- feols(
  frac_cop_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_other_2017[insample_utgo_only == 1],
  vcov = vcov_cluster(~state)
)

utgo_only_other_ex_certificate_controlled_2017 <- feols(
  frac_other_ex_certificate_outstanding_all ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
# Yield spreads and their bond characteristics are rebuilt above from the
# October all-public-debt source, including COO, COP, and residual Other debt.
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
    state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
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
    " & \\multicolumn{4}{c}{Wtd. Avg. Yield Spread}\\\\"
}
modified_output <- format_table(modified_output, cluster_level = "State")
adj_r2_idx <- grep(
  "^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&",
  modified_output
)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    "   Controls                   & Yes & Yes & Yes & Yes\\\\",
    after = adj_r2_idx[1]
  )
}
modified_output <- add_panel(
  modified_output,
  "Panel B: Weighted average yield spread by bond type",
  ncols = 5,
  zero_width = TRUE
)
writeLines(
  modified_output,
  file.path(
    tbl_dir_other,
    "point_in_time_yield_spread_2017_full_sample_panel_b_utgo_ltgo_revenue_other.tex"
  )
)
