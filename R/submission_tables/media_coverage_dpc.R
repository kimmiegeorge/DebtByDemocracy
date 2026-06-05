# DPC media coverage tests
rm(list = ls())

# --------------------------------------
# Libraries and paths
# --------------------------------------
library(pacman)
p_load(data.table, DescTools, arrow, fixest, haven, xtable)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"

poisson_glm_iter <- 100
poisson_fixef_iter <- 50000


# ===============================================================================
# Data loading and preparation
# ===============================================================================

issuance_lvl <- as.data.table(
  read_parquet(paste0(data_wd, 'DPC Data/News/Issuance_Lvl_DPC_News_260605.gzip'))
)

# Keep the same county identifier convention used in media_coverage.r.
full_data <- as.data.table(
  read_dta(paste0(data_wd, 'Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta'))
)
issuers <- full_data[, .(fips_from_mergent = first(fips)), by = seed_issuer_id]
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]
issuance_lvl[, fips := as.character(fips)]
issuance_lvl[, fips_from_mergent := as.character(fips_from_mergent)]
issuance_lvl[, fips := fifelse(is.na(fips), fips_from_mergent, fips)]
issuance_lvl[, fips_from_mergent := NULL]

issuance_lvl[, city_rev_vote := fifelse(state == 'MO', 1, city_rev_vote)]
issuance_lvl[, city_go_vote := fifelse(state == 'RI', NA_real_, city_go_vote)]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote)]
issuance_lvl <- issuance_lvl[!is.na(ln_employment)]

issuance_lvl <- issuance_lvl[order(seed_issuer_id, issuance_year_month_id)]
issuance_lvl[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), by = seed_issuer_id]
issuance_lvl[, diff := issuance_year_month_id - lag_issuance_ym_id]
issuance_lvl[, bond_prior_12 := fifelse(!is.na(diff) & diff < 12, 1, 0)]
issuance_lvl[is.na(city_rev_vote), city_rev_vote := 1]

# The table is restricted to issuers that appear in DPC at least once, but a
# given issuance can still have zero DPC articles in the pre-issuance window.
dpc_base_sample <- issuance_lvl[
  go_unlim_bond_issuance == 1 &
    dpc_issuer_has_any_articles == 1 &
    dpc_lifetime_article_count > 0
]

dpc_base_sample[, dpc_log_lifetime_articles := log(1 + dpc_lifetime_article_count)]

dpc_base_sample[, dpc_total_articles_12_0_win := Winsorize(
  dpc_total_articles_12_0,
  val = quantile(dpc_total_articles_12_0, probs = c(0.01, 0.99), na.rm = TRUE)
)]

model_vars <- c(
  'dpc_total_articles_12_0_win',
  'city_go_vote',
  'bond_prior_12',
  'dpc_log_lifetime_articles',
  'ln_amount',
  'ln_gdp',
  'ln_pop',
  'ln_pers_inc',
  'issuance_year_month_id',
  'purp_broad',
  'fips'
)

# Use a common full-control regression sample for Panels A and B so the
# descriptives and differences are for observations entering Panel C.
regression_sample <- dpc_base_sample[complete.cases(dpc_base_sample[, ..model_vars])]
regression_sample[, row_id := .I]


# ===============================================================================
# Panel C: Full-sample regressions
# ===============================================================================

r1 <- fixest::fepois(
  dpc_total_articles_12_0_win ~ city_go_vote + bond_prior_12 + dpc_log_lifetime_articles +
    ln_amount | issuance_year_month_id + purp_broad,
  data = regression_sample,
  vcov = vcov_cluster(~fips),
  glm.iter = poisson_glm_iter,
  fixef.iter = poisson_fixef_iter
)

r2 <- fixest::fepois(
  dpc_total_articles_12_0_win ~ city_go_vote + bond_prior_12 + dpc_log_lifetime_articles +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + purp_broad,
  data = regression_sample,
  vcov = vcov_cluster(~fips),
  glm.iter = poisson_glm_iter,
  fixef.iter = poisson_fixef_iter
)

total_article_row_ids <- regression_sample[unique(c(obs(r1), obs(r2))), row_id]
dpc_table_sample <- regression_sample[row_id %in% total_article_row_ids]


# ===============================================================================
# Panel A: Descriptive statistics
# ===============================================================================

desc <- dpc_table_sample[, .(dpc_total_articles_12_0_win)]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(
    Mean = mean(col, na.rm = TRUE),
    Std = sd(col, na.rm = TRUE),
    Min = min(col, na.rm = TRUE),
    P1 = quantile(col, probs = 0.01, na.rm = TRUE),
    Median = median(col, na.rm = TRUE),
    P99 = quantile(col, probs = 0.99, na.rm = TRUE),
    Max = max(col, na.rm = TRUE),
    N = sum(!is.na(col))
  )
  return(stats)
}), .SDcols = colnames(desc)]

desc_col <- transpose(desc_col, keep.names = "Variable")
colnames(desc_col) <- c("Variable", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, Variable := 'Total Articles (DPC) - 12mo']
desc_col[, Mean := sprintf('%.2f', as.numeric(Mean))]
desc_col[, Std := sprintf('%.2f', as.numeric(Std))]
desc_col[, Min := sprintf('%.2f', as.numeric(Min))]
desc_col[, P1 := sprintf('%.2f', as.numeric(P1))]
desc_col[, Median := sprintf('%.2f', as.numeric(Median))]
desc_col[, P99 := sprintf('%.2f', as.numeric(P99))]
desc_col[, Max := sprintf('%.2f', as.numeric(Max))]
desc_col[, N := format(as.integer(N), big.mark = ',')]

latex_table <- xtable(desc_col)

panel_a <- capture.output(
  print(
    latex_table,
    include.rownames = FALSE,
    sanitize.text.function = identity,
    tabular.environment = "tabular*",
    width = "\\textwidth",
    table.placement = "H"
  )
)

for (i in seq_along(panel_a)) {
  if (grepl("\\\\begin\\{tabular\\*\\}", panel_a[i])) {
    panel_a[i] <- gsub(
      "\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}",
      "\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}",
      panel_a[i]
    )
    break
  }
}

for (i in seq_along(panel_a)) {
  if (grepl("\\\\end\\{tabular\\*\\}", panel_a[i])) {
    panel_a[i] <- gsub("\\\\end\\{tabular\\*\\}", "\\\\end{tabular*}", panel_a[i])
    break
  }
}

for (i in seq_along(panel_a)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", panel_a[i])) {
    panel_a[i] <- "  \\toprule"
    break
  }
}

panel_a <- add_panel(panel_a, 'Panel A: Descriptive statistics', ncols = 9)


# ===============================================================================
# Panel B: Vote/non-vote differences
# ===============================================================================

total_article_0 <- dpc_table_sample[city_go_vote == 0, dpc_total_articles_12_0_win]
total_article_1 <- dpc_table_sample[city_go_vote == 1, dpc_total_articles_12_0_win]
total_article_ttest <- t.test(dpc_total_articles_12_0_win ~ city_go_vote, data = dpc_table_sample)

total_article_pval <- total_article_ttest$p.value
total_article_tstat <- as.numeric(total_article_ttest$statistic)

total_article_stars <- if (total_article_pval < 0.01) {
  '***'
} else if (total_article_pval < 0.05) {
  '**'
} else if (total_article_pval < 0.1) {
  '*'
} else {
  ''
}

total_article_diff <- mean(total_article_1, na.rm = TRUE) - mean(total_article_0, na.rm = TRUE)

diff_tbl <- data.table(
  Variable = 'Total Articles (DPC) - 12mo',
  `Mean (Vote = 0)` = sprintf('%.2f', mean(total_article_0, na.rm = TRUE)),
  `Mean (Vote = 1)` = sprintf('%.2f', mean(total_article_1, na.rm = TRUE)),
  Difference = paste0(
    sprintf('%.2f', total_article_diff),
    total_article_stars,
    ' (',
    sprintf('%.2f', abs(total_article_tstat)),
    ')'
  )
)

latex_table <- xtable(diff_tbl)
align(latex_table) <- c('l', 'l', 'c', 'c', 'c')

panel_b <- capture.output(
  print(
    latex_table,
    include.rownames = FALSE,
    sanitize.text.function = identity,
    tabular.environment = "tabular*",
    width = "\\textwidth",
    table.placement = "H"
  )
)

for (i in seq_along(panel_b)) {
  if (grepl("\\\\begin\\{tabular\\*\\}", panel_b[i])) {
    panel_b[i] <- gsub(
      "\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}",
      "\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}",
      panel_b[i]
    )
    break
  }
}

for (i in seq_along(panel_b)) {
  if (grepl("\\\\end\\{tabular\\*\\}", panel_b[i])) {
    panel_b[i] <- gsub("\\\\end\\{tabular\\*\\}", "\\\\end{tabular*}", panel_b[i])
    break
  }
}

for (i in seq_along(panel_b)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", panel_b[i])) {
    panel_b[i] <- "  \\toprule"
    break
  }
}

panel_b <- add_panel(panel_b, 'Panel B: Mean values by vote requirement', ncols = 4)


# ===============================================================================
# Panel C: Regression table
# ===============================================================================

table_call <- etable(
  r1, r2,
  headers = list("Total Articles (DPC) - 12mo" = 2),
  coefstat = 'tstat',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
  fitstat = c('n', 'pr2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    dpc_total_articles_12_0_win = 'Total Articles (DPC) - 12mo',
    city_go_vote = 'Vote',
    dpc_log_lifetime_articles = 'Total DPC Coverage',
    bond_prior_12 = 'Bond Issuance - 12mo',
    ln_amount = 'Amount',
    ln_gdp = 'County ln(GDP)',
    ln_pop = 'County ln(Pop)',
    ln_pers_inc = 'County ln(Pers. Inc)',
    purp_broad = 'Purpose',
    issuance_year_month_id = 'Year-Month'
  ),
  placement = 'H',
  replace = TRUE
)

panel_c <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

panel_c <- format_table(panel_c, cluster_level = "County")
panel_c <- panel_c[!grepl(
  "^[[:space:]]*Total Articles \\(DPC\\) - 12mo[[:space:]]*&[[:space:]]*\\\\multicolumn\\{2\\}\\{c\\}\\{2\\}",
  panel_c
)]
panel_c <- add_panel(panel_c, 'Panel C: Regression analyses', ncols = 3)


# ===============================================================================
# Save table
# ===============================================================================

output_file <- paste0(tbl_dir, '/media_coverage_dpc.tex')
writeLines(
  c(
    panel_a,
    '',
    '\\vspace{0.5em}',
    panel_b,
    '',
    '\\vspace{0.5em}',
    panel_c
  ),
  output_file
)

cat('Wrote ', output_file, '\n', sep = '')
