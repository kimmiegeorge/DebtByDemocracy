# Merge DPC CUSIP-level use-of-proceeds indicators into the bond-level
# Mergent data, restricted to issuers in the issuer-level debt choice samples.

rm(list = ls())

library(data.table)
library(haven)
library(ggplot2)
library(scales)

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"

issuer_file <- file.path(root, "Data/Mergent/Clean/260611_city_issuerlevel_yieldspread.dta")
bond_file <- file.path(root, "Data/Mergent/Clean/260610_city_cusiplevel_statereq_purpose_yieldspread.dta")
dpc_file <- file.path(root, "Data/DPC Data/Use Of Proceeds/260223_dpcdata_cusip_purpose.csv")
city_education_file <- file.path(root, "Data/Mergent/Education Funding/260707_education_bond_issuer_type_state_details.csv")
out_dir <- file.path(root, "Data/DPC Data/Use Of Proceeds")
plot_dir <- file.path(out_dir, "plots")
dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

purpose_vars <- c(
  "educ", "wtrswr", "fire", "police", "parksrec", "pubtransit", "street",
  "elec", "waste", "sport", "health", "gas", "libarts", "econdev",
  "refund", "otherpubbldg", "other"
)

purpose_labels <- data.table(
  purpose = c(purpose_vars, "transport"),
  purpose_label = c(
    "Education", "Water/sewer", "Fire", "Police", "Parks/recreation",
    "Public transit", "Street/road", "Electric", "Waste", "Sports",
    "Health", "Gas", "Libraries/arts", "Economic development",
    "Refunding", "Other public buildings", "Other", "Transportation"
  )
)

city_education_excluded_states <- character()
if (file.exists(city_education_file)) {
  city_education <- fread(city_education_file)
  city_education_excluded_states <- city_education[
    pct_bonds_City > 50,
    state
  ]
}

normalize_cusip <- function(x) {
  toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))
}

# Match the sample construction in Code/R/submission_tables/debt_choice.r.
issuers <- as.data.table(read_stata(issuer_file))
issuers[state == "MO", city_rev_vote := 1]
issuers[state == "RI", city_go_vote := NA_real_]
issuers <- issuers[!is.na(city_go_vote)]
issuers <- issuers[!is.na(ln_pop) & !is.na(ln_county_debt_other)]
issuers <- issuers[insample == 1]
issuers <- unique(issuers[, .(
  seed_issuer_id,
  control = as.integer(control == 1),
  allgo_only = as.integer(allgo_only == 1),
  utgo_only = as.integer(utgo_only == 1),
  in_debt_choice_allgo = as.integer(insample_allgo == 1),
  in_debt_choice_utgo_only = as.integer(insample_utgo_only == 1)
)])

bonds <- as.data.table(read_stata(bond_file))
bonds[state == "MO", city_rev_vote := 1]
bonds[state == "RI", city_go_vote := NA_real_]
bonds[, cusip_norm := normalize_cusip(cusip)]

keep_bond_vars <- c(
  "cusip_norm", "cusip", "state", "seed_issuer", "seed_issuer_id",
  "year", "issue_id", "offering_date", "city_go_vote", "city_rev_vote",
  "go_unlim", "go_lim", "rev", "security_code", "source_of_repayment", "amount", "purp_broad"
)
bonds <- bonds[, ..keep_bond_vars]

dpc <- fread(dpc_file)
dpc[, CUSIP := normalize_cusip(CUSIP)]
for (v in purpose_vars) {
  dpc[, (v) := fifelse(is.na(get(v)), 0L, as.integer(get(v) > 0))]
}

# DPC should be CUSIP-level, but aggregate defensively in case a CUSIP appears
# in multiple disclosure documents.
dpc <- dpc[, c(
  .(n_dpc_rows = .N, dpc_docids = paste(unique(DOCID), collapse = ";")),
  lapply(.SD, max, na.rm = TRUE)
), by = .(cusip_norm = CUSIP), .SDcols = purpose_vars]
dpc[, dpc_match := 1L]

merged <- issuers[bonds, on = "seed_issuer_id"]
merged <- merged[in_debt_choice_allgo == 1 | in_debt_choice_utgo_only == 1]
merged <- dpc[merged, on = "cusip_norm"]
merged[is.na(dpc_match), dpc_match := 0L]
for (v in purpose_vars) {
  merged[is.na(get(v)), (v) := 0L]
}

merged[, vote_status := fcase(
  city_go_vote == 1, "Vote required",
  city_go_vote == 0, "No vote required",
  default = NA_character_
)]
merged[, vote_group := fcase(
  control == 1, "No vote",
  allgo_only == 1, "GO vote",
  utgo_only == 1, "UTGO-only vote",
  default = NA_character_
)]
merged[, vote_group := factor(vote_group, levels = c("No vote", "GO vote", "UTGO-only vote"))]
merged[, vote_group_combined := fcase(
  control == 1, "No vote",
  allgo_only == 1 | utgo_only == 1, "Vote required",
  default = NA_character_
)]
merged[, vote_group_combined := factor(vote_group_combined, levels = c("No vote", "Vote required"))]

merged[, sample_allgo := fifelse(in_debt_choice_allgo == 1, 1L, 0L)]
merged[, sample_utgo_only := fifelse(in_debt_choice_utgo_only == 1, 1L, 0L)]
merged[, transport := as.integer(pubtransit == 1 | street == 1)]
merged[, recreation := as.integer(parksrec == 1 | libarts == 1 | health == 1 | sport == 1)]
merged[, publicsafety := as.integer(police == 1 | fire == 1)]
merged[, utilities_combined := as.integer(elec == 1 | gas == 1 | waste == 1 | wtrswr == 1)]
summary_purpose_vars <- c(setdiff(purpose_vars, c("pubtransit", "street")), "transport")
combined_category_vars <- c(
  "educ", "transport", "utilities_combined", "publicsafety", "recreation",
  "econdev", "otherpubbldg", "other"
)
combined_category_labels <- data.table(
  purpose = combined_category_vars,
  purpose_label = c(
    "Education", "Transportation", "Utilities", "Public safety",
    "Recreation/amenities", "Economic development", "Other public buildings", "Other"
  )
)

sample_specs <- list(
  allgo = list(flag = "sample_allgo", label = "Debt choice: GO vote required sample"),
  utgo_only = list(flag = "sample_utgo_only", label = "Debt choice: only UTGO vote required sample")
)

diagnostics <- rbindlist(lapply(names(sample_specs), function(s) {
  flag <- sample_specs[[s]]$flag
  dt <- merged[get(flag) == 1 & !is.na(vote_status)]
  dt[, .(
    sample = s,
    sample_label = sample_specs[[s]]$label,
    n_bonds = .N,
    n_issuers = uniqueN(seed_issuer_id),
    n_dpc_matched_bonds = sum(dpc_match == 1),
    pct_dpc_matched_bonds = round(100 * mean(dpc_match == 1), 2),
    amount_total = sum(amount, na.rm = TRUE),
    amount_dpc_matched = sum(fifelse(dpc_match == 1, amount, 0), na.rm = TRUE)
  ), by = vote_status]
}), use.names = TRUE)

purpose_summary <- rbindlist(lapply(names(sample_specs), function(s) {
  flag <- sample_specs[[s]]$flag
  dt <- merged[get(flag) == 1 & !is.na(vote_status) & dpc_match == 1]
  long <- melt(
    dt,
    id.vars = c("vote_status", "amount"),
    measure.vars = summary_purpose_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_bonds = round(100 * mean(has_purpose == 1), 2),
    amount_dpc_matched = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_amount = round(
      100 * sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) /
        sum(amount, na.rm = TRUE),
      2
    )
  ), by = .(vote_status, purpose)]
  out[, `:=`(sample = s, sample_label = sample_specs[[s]]$label)]
  out
}), use.names = TRUE)

purpose_summary <- purpose_labels[purpose_summary, on = "purpose"]
setcolorder(
  purpose_summary,
  c(
    "sample", "sample_label", "vote_status", "purpose", "purpose_label",
    "n_dpc_matched_bonds", "n_bonds_with_purpose", "pct_dpc_matched_bonds",
    "amount_dpc_matched", "amount_with_purpose", "pct_dpc_matched_amount"
  )
)
setorder(purpose_summary, sample, vote_status, -n_bonds_with_purpose)

purpose_summary_wide <- dcast(
  purpose_summary,
  sample + sample_label + purpose + purpose_label ~ vote_status,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_bonds", "amount_with_purpose"),
  fill = 0
)

bond_universe_specs <- list(
  all_bonds = list(
    label = "All bonds",
    filter = function(dt) rep(TRUE, nrow(dt))
  ),
  go_only = list(
    label = "GO only",
    filter = function(dt) dt$go_unlim == 1 | dt$go_lim == 1
  ),
  utgo_only = list(
    label = "UTGO only",
    filter = function(dt) dt$go_unlim == 1
  ),
  revenue_only = list(
    label = "Revenue only",
    filter = function(dt) dt$rev == 1
  ),
  revenue_security_g_only = list(
    label = "Revenue only: security code G",
    filter = function(dt) dt$rev == 1 & dt$security_code == "G"
  ),
  revenue_security_g_source_g_only = list(
    label = "Revenue only: security code G, source repayment G",
    filter = function(dt) dt$rev == 1 & dt$security_code == "G" & dt$source_of_repayment == "G"
  )
)

purpose_plot_summary <- rbindlist(lapply(names(bond_universe_specs), function(u) {
  spec <- bond_universe_specs[[u]]
  dt <- merged[spec$filter(merged) & !is.na(vote_group) & dpc_match == 1]
  long <- melt(
    dt,
    id.vars = c("vote_group", "amount"),
    measure.vars = summary_purpose_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_bonds = 100 * mean(has_purpose == 1),
    amount_dpc_matched = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_amount = 100 * sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) /
      sum(amount, na.rm = TRUE)
  ), by = .(vote_group, purpose)]
  out[, `:=`(
    bond_universe = u,
    bond_universe_label = spec$label
  )]
  out
}), use.names = TRUE)

purpose_plot_summary <- purpose_labels[purpose_plot_summary, on = "purpose"]
purpose_plot_summary[, pct_dpc_matched_bonds := round(pct_dpc_matched_bonds, 2)]
purpose_plot_summary[, pct_dpc_matched_amount := round(pct_dpc_matched_amount, 2)]
setcolorder(
  purpose_plot_summary,
  c(
    "bond_universe", "bond_universe_label", "vote_group", "purpose", "purpose_label",
    "n_dpc_matched_bonds", "n_bonds_with_purpose", "pct_dpc_matched_bonds",
    "amount_dpc_matched", "amount_with_purpose", "pct_dpc_matched_amount"
  )
)
setorder(purpose_plot_summary, bond_universe, purpose_label, vote_group)

purpose_plot_summary_wide <- dcast(
  purpose_plot_summary,
  bond_universe + bond_universe_label + purpose + purpose_label ~ vote_group,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_bonds", "amount_with_purpose"),
  fill = 0
)

plot_order <- purpose_plot_summary[
  bond_universe == "all_bonds",
  .(avg_pct = mean(pct_dpc_matched_bonds, na.rm = TRUE)),
  by = .(purpose_label)
][order(avg_pct), purpose_label]

plot_colors <- c(
  "No vote" = "#4C78A8",
  "GO vote" = "#F58518",
  "UTGO-only vote" = "#54A24B"
)

for (u in names(bond_universe_specs)) {
  spec <- bond_universe_specs[[u]]
  plot_dt <- copy(purpose_plot_summary[bond_universe == u])
  plot_dt[, purpose_label := factor(purpose_label, levels = plot_order)]
  max_pct <- max(plot_dt$pct_dpc_matched_bonds, na.rm = TRUE)
  p <- ggplot(
    plot_dt,
    aes(x = purpose_label, y = pct_dpc_matched_bonds / 100, fill = vote_group)
  ) +
    geom_col(position = position_dodge2(width = 0.78, preserve = "single"), width = 0.7) +
    coord_flip() +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, max_pct / 100 * 1.12),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(values = plot_colors, drop = FALSE) +
    labs(
      title = paste0("DPC use of proceeds: ", spec$label),
      subtitle = "Issuer-level debt choice regression sample; denominator is DPC-matched bonds",
      x = NULL,
      y = "Percent of bonds",
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  ggsave(
    filename = file.path(plot_dir, paste0("260622_dpc_use_proceeds_", u, "_horizontal_bars.png")),
    plot = p,
    width = 10,
    height = 7.25,
    dpi = 300
  )
}

combined_vote_universe_specs <- bond_universe_specs[c("all_bonds", "utgo_only", "revenue_only")]
combined_vote_security_g_universe_specs <- bond_universe_specs[c("all_bonds", "utgo_only", "revenue_security_g_only")]
combined_vote_security_g_source_g_universe_specs <- bond_universe_specs[c("all_bonds", "utgo_only", "revenue_security_g_source_g_only")]

combined_vote_summary <- rbindlist(lapply(names(combined_vote_universe_specs), function(u) {
  spec <- combined_vote_universe_specs[[u]]
  dt <- merged[spec$filter(merged) & !is.na(vote_group_combined) & dpc_match == 1]
  long <- melt(
    dt,
    id.vars = c("vote_group_combined", "amount"),
    measure.vars = combined_category_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_bonds = 100 * mean(has_purpose == 1),
    amount_dpc_matched = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_amount = 100 * sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) /
      sum(amount, na.rm = TRUE)
  ), by = .(vote_group_combined, purpose)]
  out[, `:=`(
    bond_universe = u,
    bond_universe_label = spec$label
  )]
  out
}), use.names = TRUE)

combined_vote_summary <- combined_category_labels[combined_vote_summary, on = "purpose"]
combined_vote_summary[, pct_dpc_matched_bonds := round(pct_dpc_matched_bonds, 2)]
combined_vote_summary[, pct_dpc_matched_amount := round(pct_dpc_matched_amount, 2)]
setcolorder(
  combined_vote_summary,
  c(
    "bond_universe", "bond_universe_label", "vote_group_combined", "purpose", "purpose_label",
    "n_dpc_matched_bonds", "n_bonds_with_purpose", "pct_dpc_matched_bonds",
    "amount_dpc_matched", "amount_with_purpose", "pct_dpc_matched_amount"
  )
)
setorder(combined_vote_summary, bond_universe, purpose_label, vote_group_combined)

combined_vote_summary_wide <- dcast(
  combined_vote_summary,
  bond_universe + bond_universe_label + purpose + purpose_label ~ vote_group_combined,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_bonds", "amount_with_purpose"),
  fill = 0
)

no_education_category_vars <- setdiff(combined_category_vars, "educ")

combined_vote_no_education_summary <- rbindlist(lapply(names(combined_vote_universe_specs), function(u) {
  spec <- combined_vote_universe_specs[[u]]
  dt <- merged[spec$filter(merged) & !is.na(vote_group_combined) & dpc_match == 1 & educ != 1]
  long <- melt(
    dt,
    id.vars = c("vote_group_combined", "amount"),
    measure.vars = no_education_category_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_non_education_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_non_education_bonds = 100 * mean(has_purpose == 1),
    amount_dpc_matched_non_education = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_non_education_amount = 100 *
      sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) / sum(amount, na.rm = TRUE)
  ), by = .(vote_group_combined, purpose)]
  out[, `:=`(
    bond_universe = u,
    bond_universe_label = spec$label
  )]
  out
}), use.names = TRUE)

combined_vote_no_education_summary <- combined_category_labels[combined_vote_no_education_summary, on = "purpose"]
combined_vote_no_education_summary[, pct_dpc_matched_non_education_bonds := round(pct_dpc_matched_non_education_bonds, 2)]
combined_vote_no_education_summary[, pct_dpc_matched_non_education_amount := round(pct_dpc_matched_non_education_amount, 2)]
setcolorder(
  combined_vote_no_education_summary,
  c(
    "bond_universe", "bond_universe_label", "vote_group_combined", "purpose", "purpose_label",
    "n_dpc_matched_non_education_bonds", "n_bonds_with_purpose",
    "pct_dpc_matched_non_education_bonds", "amount_dpc_matched_non_education",
    "amount_with_purpose", "pct_dpc_matched_non_education_amount"
  )
)
setorder(combined_vote_no_education_summary, bond_universe, purpose_label, vote_group_combined)

combined_vote_no_education_summary_wide <- dcast(
  combined_vote_no_education_summary,
  bond_universe + bond_universe_label + purpose + purpose_label ~ vote_group_combined,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_non_education_bonds", "amount_with_purpose"),
  fill = 0
)

combined_plot_order <- combined_vote_summary[
  bond_universe == "all_bonds",
  .(avg_pct = mean(pct_dpc_matched_bonds, na.rm = TRUE)),
  by = .(purpose_label)
][order(avg_pct), purpose_label]

combined_plot_colors <- c(
  "No vote" = "#4C78A8",
  "Vote required" = "#F58518"
)

for (u in names(combined_vote_universe_specs)) {
  spec <- combined_vote_universe_specs[[u]]
  plot_dt <- copy(combined_vote_summary[bond_universe == u])
  plot_dt[, purpose_label := factor(purpose_label, levels = combined_plot_order)]
  max_pct <- max(plot_dt$pct_dpc_matched_bonds, na.rm = TRUE)
  p <- ggplot(
    plot_dt,
    aes(x = purpose_label, y = pct_dpc_matched_bonds / 100, fill = vote_group_combined)
  ) +
    geom_col(position = position_dodge2(width = 0.72, preserve = "single"), width = 0.68) +
    coord_flip() +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, max_pct / 100 * 1.12),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(values = combined_plot_colors, drop = FALSE) +
    labs(
      title = paste0("DPC use of proceeds: ", spec$label),
      subtitle = "Issuer-level debt choice regression sample; GO-vote and UTGO-only-vote cities combined",
      x = NULL,
      y = "Percent of bonds",
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  ggsave(
    filename = file.path(plot_dir, paste0("260707_dpc_use_proceeds_", u, "_combined_vote_horizontal_bars.png")),
    plot = p,
    width = 10,
    height = 7,
    dpi = 300
  )
}

combined_vote_security_g_summary <- rbindlist(lapply(names(combined_vote_security_g_universe_specs), function(u) {
  spec <- combined_vote_security_g_universe_specs[[u]]
  dt <- merged[spec$filter(merged) & !is.na(vote_group_combined) & dpc_match == 1]
  long <- melt(
    dt,
    id.vars = c("vote_group_combined", "amount"),
    measure.vars = combined_category_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_bonds = 100 * mean(has_purpose == 1),
    amount_dpc_matched = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_amount = 100 * sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) /
      sum(amount, na.rm = TRUE)
  ), by = .(vote_group_combined, purpose)]
  out[, `:=`(
    bond_universe = u,
    bond_universe_label = spec$label
  )]
  out
}), use.names = TRUE)

combined_vote_security_g_summary <- combined_category_labels[combined_vote_security_g_summary, on = "purpose"]
combined_vote_security_g_summary[, pct_dpc_matched_bonds := round(pct_dpc_matched_bonds, 2)]
combined_vote_security_g_summary[, pct_dpc_matched_amount := round(pct_dpc_matched_amount, 2)]
setcolorder(
  combined_vote_security_g_summary,
  c(
    "bond_universe", "bond_universe_label", "vote_group_combined", "purpose", "purpose_label",
    "n_dpc_matched_bonds", "n_bonds_with_purpose", "pct_dpc_matched_bonds",
    "amount_dpc_matched", "amount_with_purpose", "pct_dpc_matched_amount"
  )
)
setorder(combined_vote_security_g_summary, bond_universe, purpose_label, vote_group_combined)

combined_vote_security_g_summary_wide <- dcast(
  combined_vote_security_g_summary,
  bond_universe + bond_universe_label + purpose + purpose_label ~ vote_group_combined,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_bonds", "amount_with_purpose"),
  fill = 0
)

for (u in names(combined_vote_security_g_universe_specs)) {
  spec <- combined_vote_security_g_universe_specs[[u]]
  plot_dt <- copy(combined_vote_security_g_summary[bond_universe == u])
  plot_dt[, purpose_label := factor(purpose_label, levels = combined_plot_order)]
  max_pct <- max(plot_dt$pct_dpc_matched_bonds, na.rm = TRUE)
  p <- ggplot(
    plot_dt,
    aes(x = purpose_label, y = pct_dpc_matched_bonds / 100, fill = vote_group_combined)
  ) +
    geom_col(position = position_dodge2(width = 0.72, preserve = "single"), width = 0.68) +
    coord_flip() +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, max_pct / 100 * 1.12),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(values = combined_plot_colors, drop = FALSE) +
    labs(
      title = paste0("DPC use of proceeds: ", spec$label),
      subtitle = "Issuer-level debt choice regression sample; revenue bonds restricted to security code G",
      x = NULL,
      y = "Percent of bonds",
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  ggsave(
    filename = file.path(plot_dir, paste0("260707_dpc_use_proceeds_", u, "_combined_vote_security_g_horizontal_bars.png")),
    plot = p,
    width = 10,
    height = 7,
    dpi = 300
  )
}

combined_vote_security_g_source_g_summary <- rbindlist(lapply(names(combined_vote_security_g_source_g_universe_specs), function(u) {
  spec <- combined_vote_security_g_source_g_universe_specs[[u]]
  dt <- merged[spec$filter(merged) & !is.na(vote_group_combined) & dpc_match == 1]
  long <- melt(
    dt,
    id.vars = c("vote_group_combined", "amount"),
    measure.vars = combined_category_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_bonds = 100 * mean(has_purpose == 1),
    amount_dpc_matched = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_amount = 100 * sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) /
      sum(amount, na.rm = TRUE)
  ), by = .(vote_group_combined, purpose)]
  out[, `:=`(
    bond_universe = u,
    bond_universe_label = spec$label
  )]
  out
}), use.names = TRUE)

combined_vote_security_g_source_g_summary <- combined_category_labels[combined_vote_security_g_source_g_summary, on = "purpose"]
combined_vote_security_g_source_g_summary[, pct_dpc_matched_bonds := round(pct_dpc_matched_bonds, 2)]
combined_vote_security_g_source_g_summary[, pct_dpc_matched_amount := round(pct_dpc_matched_amount, 2)]
setcolorder(
  combined_vote_security_g_source_g_summary,
  c(
    "bond_universe", "bond_universe_label", "vote_group_combined", "purpose", "purpose_label",
    "n_dpc_matched_bonds", "n_bonds_with_purpose", "pct_dpc_matched_bonds",
    "amount_dpc_matched", "amount_with_purpose", "pct_dpc_matched_amount"
  )
)
setorder(combined_vote_security_g_source_g_summary, bond_universe, purpose_label, vote_group_combined)

combined_vote_security_g_source_g_summary_wide <- dcast(
  combined_vote_security_g_source_g_summary,
  bond_universe + bond_universe_label + purpose + purpose_label ~ vote_group_combined,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_bonds", "amount_with_purpose"),
  fill = 0
)

for (u in names(combined_vote_security_g_source_g_universe_specs)) {
  spec <- combined_vote_security_g_source_g_universe_specs[[u]]
  plot_dt <- copy(combined_vote_security_g_source_g_summary[bond_universe == u])
  plot_dt[, purpose_label := factor(purpose_label, levels = combined_plot_order)]
  max_pct <- max(plot_dt$pct_dpc_matched_bonds, na.rm = TRUE)
  p <- ggplot(
    plot_dt,
    aes(x = purpose_label, y = pct_dpc_matched_bonds / 100, fill = vote_group_combined)
  ) +
    geom_col(position = position_dodge2(width = 0.72, preserve = "single"), width = 0.68) +
    coord_flip() +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, max_pct / 100 * 1.12),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(values = combined_plot_colors, drop = FALSE) +
    labs(
      title = paste0("DPC use of proceeds: ", spec$label),
      subtitle = "Issuer-level debt choice regression sample; revenue bonds restricted to security code G and source repayment G",
      x = NULL,
      y = "Percent of bonds",
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  ggsave(
    filename = file.path(plot_dir, paste0("260707_dpc_use_proceeds_", u, "_combined_vote_security_g_source_g_horizontal_bars.png")),
    plot = p,
    width = 10,
    height = 7,
    dpi = 300
  )
}

combined_vote_drop_city_education_summary <- rbindlist(lapply(names(combined_vote_universe_specs), function(u) {
  spec <- combined_vote_universe_specs[[u]]
  dt <- merged[
    spec$filter(merged) &
      !is.na(vote_group_combined) &
      dpc_match == 1 &
      !(state %in% city_education_excluded_states)
  ]
  long <- melt(
    dt,
    id.vars = c("vote_group_combined", "amount"),
    measure.vars = combined_category_vars,
    variable.name = "purpose",
    value.name = "has_purpose"
  )
  out <- long[, .(
    n_dpc_matched_bonds = .N,
    n_bonds_with_purpose = sum(has_purpose == 1),
    pct_dpc_matched_bonds = 100 * mean(has_purpose == 1),
    amount_dpc_matched = sum(amount, na.rm = TRUE),
    amount_with_purpose = sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE),
    pct_dpc_matched_amount = 100 *
      sum(fifelse(has_purpose == 1, amount, 0), na.rm = TRUE) / sum(amount, na.rm = TRUE)
  ), by = .(vote_group_combined, purpose)]
  out[, `:=`(
    bond_universe = u,
    bond_universe_label = spec$label,
    excluded_states = paste(city_education_excluded_states, collapse = ";")
  )]
  out
}), use.names = TRUE)

combined_vote_drop_city_education_summary <- combined_category_labels[
  combined_vote_drop_city_education_summary,
  on = "purpose"
]
combined_vote_drop_city_education_summary[, pct_dpc_matched_bonds := round(pct_dpc_matched_bonds, 2)]
combined_vote_drop_city_education_summary[, pct_dpc_matched_amount := round(pct_dpc_matched_amount, 2)]
setcolorder(
  combined_vote_drop_city_education_summary,
  c(
    "bond_universe", "bond_universe_label", "vote_group_combined", "purpose", "purpose_label",
    "n_dpc_matched_bonds", "n_bonds_with_purpose", "pct_dpc_matched_bonds",
    "amount_dpc_matched", "amount_with_purpose", "pct_dpc_matched_amount", "excluded_states"
  )
)
setorder(combined_vote_drop_city_education_summary, bond_universe, purpose_label, vote_group_combined)

combined_vote_drop_city_education_summary_wide <- dcast(
  combined_vote_drop_city_education_summary,
  bond_universe + bond_universe_label + purpose + purpose_label + excluded_states ~ vote_group_combined,
  value.var = c("n_bonds_with_purpose", "pct_dpc_matched_bonds", "amount_with_purpose"),
  fill = 0
)

drop_city_education_plot_order <- combined_vote_drop_city_education_summary[
  bond_universe == "all_bonds",
  .(avg_pct = mean(pct_dpc_matched_bonds, na.rm = TRUE)),
  by = .(purpose_label)
][order(avg_pct), purpose_label]

excluded_states_label <- ifelse(
  length(city_education_excluded_states) > 0,
  paste(city_education_excluded_states, collapse = ", "),
  "none"
)

for (u in names(combined_vote_universe_specs)) {
  spec <- combined_vote_universe_specs[[u]]
  plot_dt <- copy(combined_vote_drop_city_education_summary[bond_universe == u])
  plot_dt[, purpose_label := factor(purpose_label, levels = drop_city_education_plot_order)]
  max_pct <- max(plot_dt$pct_dpc_matched_bonds, na.rm = TRUE)
  p <- ggplot(
    plot_dt,
    aes(x = purpose_label, y = pct_dpc_matched_bonds / 100, fill = vote_group_combined)
  ) +
    geom_col(position = position_dodge2(width = 0.72, preserve = "single"), width = 0.68) +
    coord_flip() +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, max_pct / 100 * 1.12),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(values = combined_plot_colors, drop = FALSE) +
    labs(
      title = paste0("DPC use of proceeds: ", spec$label),
      subtitle = paste0(
        "Excludes states where cities issue >50% of education bonds: ",
        excluded_states_label
      ),
      x = NULL,
      y = "Percent of bonds",
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  ggsave(
    filename = file.path(plot_dir, paste0("260707_dpc_use_proceeds_", u, "_combined_vote_drop_city_education_states_horizontal_bars.png")),
    plot = p,
    width = 10,
    height = 6.5,
    dpi = 300
  )
}

no_education_plot_order <- combined_vote_no_education_summary[
  bond_universe == "all_bonds",
  .(avg_pct = mean(pct_dpc_matched_non_education_bonds, na.rm = TRUE)),
  by = .(purpose_label)
][order(avg_pct), purpose_label]

for (u in names(combined_vote_universe_specs)) {
  spec <- combined_vote_universe_specs[[u]]
  plot_dt <- copy(combined_vote_no_education_summary[bond_universe == u])
  plot_dt[, purpose_label := factor(purpose_label, levels = no_education_plot_order)]
  max_pct <- max(plot_dt$pct_dpc_matched_non_education_bonds, na.rm = TRUE)
  p <- ggplot(
    plot_dt,
    aes(x = purpose_label, y = pct_dpc_matched_non_education_bonds / 100, fill = vote_group_combined)
  ) +
    geom_col(position = position_dodge2(width = 0.72, preserve = "single"), width = 0.68) +
    coord_flip() +
    scale_y_continuous(
      labels = percent_format(accuracy = 1),
      limits = c(0, max_pct / 100 * 1.12),
      expand = expansion(mult = c(0, 0.02))
    ) +
    scale_fill_manual(values = combined_plot_colors, drop = FALSE) +
    labs(
      title = paste0("DPC use of proceeds: ", spec$label),
      subtitle = "Education-coded bonds excluded from denominator; GO-vote and UTGO-only-vote cities combined",
      x = NULL,
      y = "Percent of non-education bonds",
      fill = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  ggsave(
    filename = file.path(plot_dir, paste0("260707_dpc_use_proceeds_", u, "_combined_vote_no_education_horizontal_bars.png")),
    plot = p,
    width = 10,
    height = 6.5,
    dpi = 300
  )
}

merged_out <- merged[, c(
  keep_bond_vars,
  "vote_status", "vote_group", "dpc_match", "n_dpc_rows", "dpc_docids",
  "sample_allgo", "sample_utgo_only", purpose_vars, "transport"
), with = FALSE]

fwrite(merged_out, file.path(out_dir, "260622_dpc_use_proceeds_merged_debt_choice_bonds.csv"))
fwrite(diagnostics, file.path(out_dir, "260622_dpc_use_proceeds_debt_choice_match_diagnostics.csv"))
fwrite(purpose_summary, file.path(out_dir, "260622_dpc_use_proceeds_debt_choice_summary_long.csv"))
fwrite(purpose_summary_wide, file.path(out_dir, "260622_dpc_use_proceeds_debt_choice_summary_wide.csv"))
fwrite(purpose_plot_summary, file.path(out_dir, "260622_dpc_use_proceeds_vote_group_by_bond_type_summary_long.csv"))
fwrite(purpose_plot_summary_wide, file.path(out_dir, "260622_dpc_use_proceeds_vote_group_by_bond_type_summary_wide.csv"))
fwrite(combined_vote_summary, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_summary_long.csv"))
fwrite(combined_vote_summary_wide, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_summary_wide.csv"))
fwrite(combined_vote_security_g_summary, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_security_g_summary_long.csv"))
fwrite(combined_vote_security_g_summary_wide, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_security_g_summary_wide.csv"))
fwrite(combined_vote_security_g_source_g_summary, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_security_g_source_g_summary_long.csv"))
fwrite(combined_vote_security_g_source_g_summary_wide, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_security_g_source_g_summary_wide.csv"))
fwrite(combined_vote_no_education_summary, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_no_education_summary_long.csv"))
fwrite(combined_vote_no_education_summary_wide, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_no_education_summary_wide.csv"))
fwrite(combined_vote_drop_city_education_summary, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_drop_city_education_states_summary_long.csv"))
fwrite(combined_vote_drop_city_education_summary_wide, file.path(out_dir, "260707_dpc_use_proceeds_combined_vote_by_bond_type_drop_city_education_states_summary_wide.csv"))

message("Wrote merged bond file, DPC purpose summaries, and plots to: ", out_dir)
