# 02: RavenPack media coverage results (Table 3; also Table 1 inputs)
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven, xtable)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R')
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"
)
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)
excluded_state <- Sys.getenv("EXCLUDE_STATE", unset = "")

add_media_sample_headers <- function(tex) {
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]

  lines <- lines[!grepl("^\\s*Full Sample\\s*&\\s*\\\\multicolumn\\{4\\}\\{c\\}\\{2\\}", lines)]
  lines <- lines[!grepl("^\\s*Border-State Sample\\s*&\\s*\\\\multicolumn\\{4\\}\\{c\\}\\{2\\}", lines)]

  dep_header_idx <- grep("\\\\multicolumn\\{4\\}\\{c\\}\\{Total Articles - 12mo\\}", lines)
  if (length(dep_header_idx) == 0) {
    return(lines)
  }

  insert_idx <- dep_header_idx[1] + 1
  if (insert_idx <= length(lines) && grepl("\\\\cmidrule\\(lr\\)\\{2-5\\}", lines[insert_idx])) {
    new_header <- c(
      "    & \\multicolumn{2}{c}{Full Sample} & \\multicolumn{2}{c}{Border-State Sample}\\\\",
      "   \\cmidrule(lr){2-3}\\cmidrule(lr){4-5}"
    )
    lines <- append(lines, new_header, after = insert_idx)
  }

  return(lines)
}

add_media_border_sample_header <- function(tex) {
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]

  lines <- lines[!grepl(
    "^\\s*&\\s*\\\\multicolumn\\{2\\}\\{c\\}\\{Border-State Sample: Drop Dark Green\\}",
    lines
  )]

  dep_header_idx <- grep("\\\\multicolumn\\{2\\}\\{c\\}\\{Total Articles - 12mo\\}", lines)
  if (length(dep_header_idx) == 0) {
    return(lines)
  }

  insert_idx <- dep_header_idx[1] + 1
  if (insert_idx <= length(lines) && grepl("\\\\cmidrule\\(lr\\)\\{2-3\\}", lines[insert_idx])) {
    new_header <- c(
      "    & \\multicolumn{2}{c}{Border-State Sample: Drop Dark Green}\\\\",
      "   \\cmidrule(lr){2-3}"
    )
    lines <- append(lines, new_header, after = insert_idx)
  }

  return(lines)
}

# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

# Step 06 in Python prepares issuer metadata, sample restrictions, issuance
# lags, logged sources, shared percentile caps, and robustness indicators.
issuance_lvl <- fread(Sys.getenv(
  "MEDIA_FULL_REGRESSION_DATA",
  unset = "~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/News/media_full_sample_regression_data.csv"
))
border_articles <- fread(Sys.getenv(
  "MEDIA_BORDER_REGRESSION_DATA",
  unset = "~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/News/media_border_state_regression_data.csv"
))
# Retain the existing runtime state-exclusion option for sensitivity runs.
if (nzchar(excluded_state)) border_articles <- border_articles[state != excluded_state]

#_______________Descriptives________________

desc <- issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0, .(city_go_vote, total_articles_12_0_win,
                            bond_prior_12, log_sources, ln_amount,
                            ln_gdp, ln_pop, ln_pers_inc)]




desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Unit = 'Issuance',
            Mean = mean(col, na.rm = TRUE),
             Std = sd(col, na.rm = TRUE),
             Min = min(col, na.rm = TRUE),
             p1 = quantile(col, probs = 0.01, na.rm = TRUE),
             Median = median(col, na.rm = TRUE),
             p99 = quantile(col, probs = 0.99, na.rm = TRUE),
             Max = max(col, na.rm = TRUE),
             N = sum(!is.na(col)))
  return(stats)
}), .SDcols = colnames(desc)]
desc_col <- transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, Variable := c('Vote', 'Total Articles - 12mo', 'Bond Issuance - 12mo', 'Num Sources', 'Amount',
                         'County ln(GDP)', 'County ln(Pop)', 'County ln(Pers. Inc)')]

# Report empirical integer percentiles for the count variable. Other variables
# retain R's default interpolated quantiles.
desc_col[Variable == 'Total Articles - 12mo', `:=`(
  P1 = quantile(desc$total_articles_12_0_win, probs = 0.01, na.rm = TRUE, type = 1),
  P99 = quantile(desc$total_articles_12_0_win, probs = 0.99, na.rm = TRUE, type = 1)
)]

# Round numeric columns to 2 decimal places
desc_col[, Mean := round(as.numeric(Mean), 2)]
desc_col[, Std := round(as.numeric(Std), 2)]
desc_col[, Min := round(as.numeric(Min), 2)]
desc_col[, P1 := round(as.numeric(P1), 2)]
desc_col[, Median := round(as.numeric(Median), 2)]
desc_col[, P99 := round(as.numeric(P99), 2)]
desc_col[, Max := round(as.numeric(Max), 2)]
# Format N with comma separator for thousands
desc_col[, N := format(as.integer(N), big.mark = ",")]

latex_table <- xtable(
  desc_col
)

# Capture the xtable output
desc_table_output <- capture.output(
  print(
    latex_table,
    include.rownames = FALSE,
    sanitize.text.function = identity,
    tabular.environment = "tabular*",
    width = "\\textwidth",
    table.placement = "H"
  )
)

# Convert tabular* to use @{\extracolsep{\fill}} format
for (i in seq_along(desc_table_output)) {
  if (grepl("\\\\begin\\{tabular\\*\\}", desc_table_output[i])) {
    # xtable already includes {\textwidth}, so we need to handle it properly
    desc_table_output[i] <- gsub(
      "\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}",
      "\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}",
      desc_table_output[i]
    )
    break
  }
}

# Replace \end{tabular*}
for (i in seq_along(desc_table_output)) {
  if (grepl("\\\\end\\{tabular\\*\\}", desc_table_output[i])) {
    desc_table_output[i] <- gsub("\\\\end\\{tabular\\*\\}", "\\\\end{tabular*}", desc_table_output[i])
    break
  }
}

# Add \toprule after the first \hline (which comes after the column headers)
for (i in seq_along(desc_table_output)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", desc_table_output[i])) {
    desc_table_output[i] <- "  \\toprule"
    break
  }
}

# Add panel title using add_panel function
desc_table_output <- add_panel(desc_table_output, 'Panel B: Media coverage descriptive statistics', ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tbl_dir, '/media_descriptives.tex'))



#_______________Regressions ________________




diff_table <- function(dt, group_var, vars) {
  out <- lapply(vars, function(v) {
    # t-test for difference
    ttest <- t.test(get(v) ~ get(group_var), data = dt)
    
    # compute group means
    means <- dt[, .(
      mean_0 = mean(get(v)[get(group_var) == 0], na.rm = TRUE),
      mean_1 = mean(get(v)[get(group_var) == 1], na.rm = TRUE)
    )]
    
    # extract stats
    pval <- ttest$p.value
    tstat <- round(ttest$statistic, 2)
    
    # significance stars
    stars <- if (pval < 0.01) "***"
    else if (pval < 0.05) "**"
    else if (pval < 0.1) "*"
    else ""
    
    data.table(
      variable = v,
      mean_0 = means$mean_0,
      mean_1 = means$mean_1,
      diff = round(means$mean_1 - means$mean_0, 2),
      tstat = tstat,
      stars = stars
    )
  })
  
  res <- rbindlist(out)
  
  # format columns
  res[, mean_0 := round(mean_0, 2)]
  res[, mean_1 := round(mean_1, 2)]
  res[, diff_fmt := sprintf("%.2f%s (%.2f)", diff, stars, abs(tstat))]
  
  return(res)
}


vars <- c(
  "total_articles_12_0_win", "bond_prior_12", "log_sources", "ln_amount",
  "ln_gdp", "ln_pop", "ln_pers_inc"
)

table_out <- diff_table(issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], "city_go_vote", vars)

diff_tbl <- table_out[, .(
  Variable = c(
    "Total Articles - 12mo", "Bond Issuance - 12mo", "Num Sources", "Amount",
    "County ln(GDP)", "County ln(Pop)", "County ln(Pers. Inc)"
  ),
  `Mean (Vote = 0)` = mean_0,
  `Mean (Vote = 1)` = mean_1,
  Difference = diff_fmt
)]

latex_table <- xtable(diff_tbl)
align(latex_table) <- c("l", "l", "c", "c", "c")

# Capture the xtable output
diff_table_output <- capture.output(
  print(
    latex_table,
    include.rownames = FALSE,
    sanitize.text.function = identity,
    tabular.environment = "tabular*",
    width = "\\textwidth"
  )
)

# Convert tabular* to use @{\extracolsep{\fill}} format
for (i in seq_along(diff_table_output)) {
  if (grepl("\\\\begin\\{tabular\\*\\}", diff_table_output[i])) {
    # xtable already includes {\textwidth}, so we need to handle it properly
    diff_table_output[i] <- gsub(
      "\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}",
      "\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}",
      diff_table_output[i]
    )
    break
  }
}

# Replace \end{tabular*}
for (i in seq_along(diff_table_output)) {
  if (grepl("\\\\end\\{tabular\\*\\}", diff_table_output[i])) {
    diff_table_output[i] <- gsub("\\\\end\\{tabular\\*\\}", "\\\\end{tabular*}", diff_table_output[i])
    break
  }
}

# Add panel title using add_panel function
diff_table_output <- add_panel(diff_table_output, 'Panel A: Mean values by vote requirement', ncols = 4)

# Write to file
writeLines(diff_table_output, paste0(tbl_dir, "/media_diff_means_table.tex"))

r1 <- fixest::fepois(total_articles_12_0_win ~city_go_vote + bond_prior_12 + log_sources +
                        ln_amount | issuance_year_month_id + purp_broad,
                      data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], 
                      vcov = vcov_cluster(~state))
r1b <- fixest::fepois(total_articles_12_0_win ~city_go_vote  + bond_prior_12 + log_sources + ln_amount + 
                       ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + purp_broad,
                     data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], 
                     vcov = vcov_cluster(~state))

r2 <- fixest::fepois(total_articles_12_0_win ~city_go_vote + bond_prior_12 + log_sources + 
                        ln_amount | issuance_year_month_id + group + purp_broad,
                      data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                      vcov = vcov_cluster(~state_year))

r2b <- fixest::fepois(total_articles_12_0_win ~city_go_vote  + bond_prior_12 + log_sources + ln_amount +
                       ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + group + purp_broad,
                     data = border_articles[(go_unlim_bond_issuance == 1) & rolling_sum_monthly_article_count_12 > 0], 
                     vcov = vcov_cluster(~state_year))





  
table_call <- etable(r1, r1b, r2, r2b,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       #fontsize = 'small',
       #order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(total_articles_12_0_win ='Total Articles - 12mo',
                total_rp_articles_6_0 ='Total Articles - 6mo',
                city_go_vote = 'Vote',
                city_rev_vote = "Rev Vote",
                go = 'GO',
                rolling_sum = 'City News Coverage',
                bond_prior_12 = 'Bond Issuance - 12mo',
                ln_amount = 'Amount',
                ln_gdp =  'County ln(GDP)', 
                ln_num_cusip = "Num Bonds",
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                log_sources = 'Num Sources',
                rolling_sum = 'City News Coverage',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'State-Border', 
                purp_broad = 'Purpose',
                issuance_year_month_id = 'Year-Month'),
       placement = 'H',
       #file = paste0(tables_wd, '/media_coverage.tex'), 
       replace = TRUE)







modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(
  modified_output,
  cluster_level = c("State", "State", "State-Year", "State-Year"),
  drop_covariance = TRUE
)
modified_output <- add_media_sample_headers(modified_output)
modified_output <- add_panel(modified_output, 'Panel B: Regression analyses')

writeLines(modified_output, paste0(tbl_dir, '/media_coverage.tex'))

#===============================
# border-state sample: drop dark green comparisons
#===============================

# Python marks complete paper pairs whose treated state requires a GO vote
# and does not require a revenue-bond vote.
border_articles_drop_dark_green <- border_articles[keep_drop_dark_green == 1L]

r1_drop_dark_green <- fixest::fepois(total_articles_12_0_win ~city_go_vote + bond_prior_12 + log_sources +
                        ln_amount | issuance_year_month_id + purp_broad,
                      data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 & dark_green == 0], 
                      vcov = vcov_cluster(~state))
r1_drop_dark_green_controls <- fixest::fepois(total_articles_12_0_win ~city_go_vote  + bond_prior_12 + log_sources + ln_amount + 
                       ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + purp_broad,
                     data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 & dark_green == 0], 
                     vcov = vcov_cluster(~state))

r2_drop_dark_green <- fixest::fepois(total_articles_12_0_win ~ city_go_vote + bond_prior_12 + log_sources +
                                      ln_amount | issuance_year_month_id + group + purp_broad,
                                    data = border_articles_drop_dark_green[
                                      go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
                                    ],
                                    vcov = vcov_cluster(~state_year))
r2_drop_dark_green_controls <- fixest::fepois(total_articles_12_0_win ~ city_go_vote + bond_prior_12 + log_sources + ln_amount +
                                               ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + group + purp_broad,
                                             data = border_articles_drop_dark_green[
                                               go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
                                             ],
                                             vcov = vcov_cluster(~state_year))

table_call_drop_dark_green <- etable(r1_drop_dark_green, r1_drop_dark_green_controls, r2_drop_dark_green,r2_drop_dark_green_controls,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
       fitstat = c('n', 'pr2'),
       se.below = TRUE,
       digits = 3,
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10),
       tex = TRUE,
       dict = c(total_articles_12_0_win ='Total Articles - 12mo',
                total_rp_articles_6_0 ='Total Articles - 6mo',
                city_go_vote = 'Vote',
                city_rev_vote = "Rev Vote",
                go = 'GO',
                rolling_sum = 'City News Coverage',
                bond_prior_12 = 'Bond Issuance - 12mo',
                ln_amount = 'Amount',
                ln_gdp =  'County ln(GDP)',
                ln_num_cusip = "Num Bonds",
                ln_pop = 'County ln(Pop)' ,
                ln_pers_inc = 'County ln(Pers. Inc)',
                ln_employment = 'County ln(Emp)',
                log_sources = 'Num Sources',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'State-Border',
                purp_broad = 'Purpose',
                issuance_year_month_id = 'Year-Month'),
       placement = 'H',
       replace = TRUE)

modified_output_drop_dark_green <- modify_etable_rounding(
  table_call_drop_dark_green,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output_drop_dark_green <- format_table(
  modified_output_drop_dark_green,
  cluster_level = c("State", "State", "State-Year", "State-Year"),
  drop_covariance = TRUE
)
modified_output_drop_dark_green <- add_media_sample_headers(modified_output_drop_dark_green)



writeLines(
  modified_output_drop_dark_green,
  paste0(tbl_dir, '/media_coverage_drop_dark_green.tex')
)
#===============================
# super majority 
#===============================
r1 <- fixest::fepois(total_articles_12_0_win ~city_go_vote + super_majority + bond_prior_12 + log_sources +
                        ln_amount | issuance_year_month_id + purp_broad,
                      data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                      vcov = vcov_cluster(~state))
r1b <- fixest::fepois(total_articles_12_0_win ~city_go_vote + super_majority + bond_prior_12 + log_sources + ln_amount + 
                       ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + purp_broad,
                     data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                     vcov = vcov_cluster(~state))




  
table_call <- etable(r1, r1b, 
       coefstat = 'tstat',
       keep_raw = c("^city_go_vote$", "^super_majority$"),
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       #fontsize = 'small',
       #order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(total_articles_12_0_win ='Total Articles - 12mo',
                total_rp_articles_6_0 ='Total Articles - 6mo',
                city_go_vote = 'Vote',
                super_majority = 'Supermajority State',
                city_rev_vote = "Rev Vote",
                go = 'GO',
                rolling_sum = 'City News Coverage',
                bond_prior_12 = 'Bond Issuance - 12mo',
                ln_amount = 'Amount',
                ln_gdp =  'County ln(GDP)', 
                ln_num_cusip = "Num Bonds",
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                log_sources = 'Num Sources',
                rolling_sum = 'City News Coverage',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'State-Border', 
                purp_broad = 'Purpose',
                issuance_year_month_id = 'Year-Month'),
       placement = 'H',
       #file = paste0(tables_wd, '/media_coverage.tex'), 
       replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_media_sample_headers(modified_output)
pseudo_r2_idx <- grep("^[[:space:]]*Pseudo R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(pseudo_r2_idx) > 0) {
  modified_output <- append(
    modified_output,
    c("   City Controls              & Yes           & Yes\\\\",
      "   County Controls            & No            & Yes\\\\"),
    after = pseudo_r2_idx[1]
  )
}
modified_output <- add_panel(modified_output, 'Panel C: Supermajority split', ncols = 3)

writeLines(modified_output, paste0(tbl_dir, '/media_coverage_super_majority.tex'))
