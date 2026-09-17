# 02: RavenPack media coverage results (Table 3; also Table 1 inputs)
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven, xtable)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_state_policy_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_border_pair_definitions.R')
tbl_dir <- "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"
clean_data_wd <- "~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/"

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

# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

#_______________Bonds________________
 #load full data to get county
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
issuers <- full_data[, list(fips = first(fips), issuer_long_name = first(issuer_long_name)), .(seed_issuer_id)]
# load news coverage 
#issuance_lvl = fread(paste0(clean_data_wd, 'News/Issuance_Lvl_News_With_Lagged_News.csv'))
issuance_lvl = fread(paste0(clean_data_wd, 'News/Issuance_Lvl_News_With_Lagged_News.csv'))
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]
issuance_lvl[, city_rev_vote := ifelse(state == 'MO', 1, city_rev_vote)]
issuance_lvl[, city_go_vote := ifelse(state == 'RI', NA, city_go_vote)]

# filter to sample 
#issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & city_rev_vote == 0]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote)]

issuance_lvl[, super_majority := ifelse(state %in% super_majority_states, 1, 0)]

#_______________Border________________


#border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv')
border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv')
border_articles = as.data.table(border_articles)
#border_articles <- border_articles[category != 'grey']


# filter to non-missing demo 
issuance_lvl <- issuance_lvl[!is.na(ln_employment)]
#issuance_lvl <- issuance_lvl[!is.na(rolling_sum) & !is.infinite(rolling_sum)]
border_articles <- border_articles[!is.na(ln_employment)]
#border_articles <- border_articles[!is.na(rolling_sum) & !is.infinite(rolling_sum)]

# indicator for other bond issued in prior 12 months 
issuance_lvl <- issuance_lvl[order(seed_issuer_id, issuance_year_month_id)]
issuance_lvl[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), .(seed_issuer_id)]
issuance_lvl[, diff := issuance_year_month_id - lag_issuance_ym_id]
issuance_lvl[, bond_prior_12 := ifelse(!is.na(diff) & diff <= 12, 1, 0)]

border_articles <- border_articles[order(seed_issuer_id, issuance_year_month_id)]
border_articles[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), .(seed_issuer_id)]
border_articles[, diff := issuance_year_month_id - lag_issuance_ym_id]
border_articles[, bond_prior_12 := ifelse(!is.na(diff) & diff <=  12, 1, 0)]

border_articles <- filter_paper_border_pairs(border_articles)
border_articles[, state_year := interaction(state, year, drop = TRUE)]


border_articles[, log_sources := log(1+unique_sources_12)]
issuance_lvl[, log_sources := log(1+unique_sources_12)]
#_______________Descriptives________________

# Define the winsorized media outcome once from the full analysis sample and
# apply the same integer-valued empirical percentile caps to both samples.
# This keeps the dependent variable comparable across the full-sample and
# border-state columns.
media_article_caps <- quantile(
  issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0, total_rp_articles_12_0],
  probs = c(0.01, 0.99),
  type = 1
)
issuance_lvl[, total_articles_12_0_win := Winsorize(
  total_rp_articles_12_0,
  val = media_article_caps
)]
border_articles[, total_articles_12_0_win := Winsorize(
  total_rp_articles_12_0,
  val = media_article_caps
)]

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
issuance_lvl[is.na(city_rev_vote), city_rev_vote := 1]
border_articles[is.na(city_rev_vote), city_rev_vote := 1]




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
