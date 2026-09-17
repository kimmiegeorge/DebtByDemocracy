
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, xtable)
tables_wd <- "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/state_policy_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/border_pair_definitions.R')
tbl_dir <- "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Websites/border_state_website_data_with_recovered.csv')
data <- filter_paper_border_pairs(data)
data[, state_year := interaction(state, year, drop = TRUE)]

data <- data[!is.na(total_subs)]
data <- data[!is.na(city_go_vote)]
data <- data[total_subs == 50]
data <- data[seed_issuer != 'BONDUEL WIS']
data[, super_majority := as.integer(state %in% super_majority_states)]


# Merge the shared full-Mergent end-of-year outstanding-debt panel. The Python
# builder counts a CUSIP in year t when it was offered by December 31 of t and
# matures after December 31 of t. Use a composite issuer key because
# seed_issuer_id is reused for a few issuers in the Mergent files.
data[, year_int := as.integer(year)]
data[, issuer_key := paste(
  sprintf('%.0f', round(as.numeric(seed_issuer_id) * 10)),
  toupper(trimws(state)),
  toupper(gsub('\\s+', ' ', trimws(seed_issuer))),
  sep = '|'
)]

expected_website_years <- nrow(data)
debt_panel <- fread(
  '/Users/kmunevar/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv',
  select = c(
    'issuer_key', 'year', 'total_outstanding_debt',
    'ln_1p_total_outstanding_debt'
  )
)
debt_panel[, year_int := as.integer(year) + 1L]
debt_panel[, year := NULL]
setnames(
  debt_panel,
  c('total_outstanding_debt', 'ln_1p_total_outstanding_debt'),
  c('total_outstanding_debt_lag1', 'ln_1p_outstanding_debt_lag1')
)

if (debt_panel[, anyDuplicated(paste(issuer_key, year_int))] > 0L) {
  stop('The shared outstanding-debt panel has duplicate issuer-year keys.')
}

data <- debt_panel[data, on = .(issuer_key, year_int)]

if (data[is.na(ln_1p_outstanding_debt_lag1), .N] > 0L) {
  stop('The shared outstanding-debt panel is missing website issuer-years.')
}

message(sprintf(
  paste0(
    'Merged prior-year-end debt for %s website-years and %s issuers; ',
    '%s issuer-years have zero outstanding debt.'
  ),
  format(nrow(data), big.mark = ','),
  format(uniqueN(data$issuer_key), big.mark = ','),
  format(data[total_outstanding_debt_lag1 == 0, .N], big.mark = ',')
))

if (nrow(data) != expected_website_years) {
  warning(sprintf(
    'The debt-panel merge produced %s website-years; expected %s.',
    format(nrow(data), big.mark = ','),
    format(expected_website_years, big.mark = ',')
  ))
}


# variable adjustments 
data[, group := as.factor(group)]
data[, year := as.factor(year)]


state_policy <- fread('/Users/kmunevar/Dropbox/Voting on Bonds/Data/State Monitoring Policy/state_enforcement_adoption_years.csv')
state_policy[, AdoptionYear := ifelse(AdoptionYear == 'before_sample', 2009, AdoptionYear )]
setnames(state_policy, 'Abbreviation', 'state')

data <- state_policy[data, on = .(state)]
data[, state_monitor := ifelse(!is.na(AdoptionYear) & year_int >= AdoptionYear, 1, 0)]


# Use observed order statistics for the count-variable caps so winsorization
# preserves integer-valued website disclosure counts.
website_count_variables <- c(
  'fiscal_url', 'fiscal_count', 'bond_url', 'bond_count',
  'financial_pdf_urls'
)
for (variable in website_count_variables) {
  website_count_caps <- quantile(
    data[[variable]],
    probs = c(0.01, 0.99),
    na.rm = TRUE,
    type = 1
  )
  set(
    data,
    j = variable,
    value = Winsorize(data[[variable]], val = website_count_caps)
  )
}

#---------------------------------------
# Descriptives
#---------------------------------------

desc <- data[, .(city_go_vote, bond_url,
                 bond_count,
                 fiscal_url, fiscal_count, financial_pdf_urls,
                 ln_1p_outstanding_debt_lag1, state_monitor)]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Unit = 'City-Year',
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
desc_col <- data.table::transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
desc_col[, variable := c('Vote', 'Bond URLs',  'Bond Count', 
                         'Fiscal URLs', 'Fiscal Count', 'Financial Docs',
                         'Outstanding Debt', 'State Fiscal Monitor')]
setnames(desc_col, 'variable', 'Variable')

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
desc_table_output <- add_panel(desc_table_output, 'Panel A: Website disclosure descriptive statistics', ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tbl_dir, "/website_descriptives.tex"))



#---------------------------------
# Output differences
#---------------------------------


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
      pval = pval,
      n_0 = sum(!is.na(dt[get(group_var) == 0, get(v)])),
      n_1 = sum(!is.na(dt[get(group_var) == 1, get(v)])),
      stars = stars
    )
  })
  
  res <- rbindlist(out)
  
  # format columns
  res[, mean_0 := round(mean_0, 2)]
  res[, mean_1 := round(mean_1, 2)]
  res[, diff_fmt := sprintf("%.2f%s (%.2f)", get("diff"), stars, abs(tstat))]
  
  
  return(res)
}


vars <- c("bond_url", "bond_count",
          "fiscal_url", "fiscal_count", "financial_pdf_urls",
          "ln_1p_outstanding_debt_lag1", "ln_gdp", "ln_pop", "ln_pers_inc")

table_out <- diff_table(data[total_subs == 50], "city_go_vote", vars)

# View formatted table
print(table_out[, .(variable, mean_0, mean_1, diff_fmt)])


diff_tbl <- table_out[, .(
  Variable = c(
    "Bond URLs", "Bond Count",
    "Fiscal URLs", "Fiscal Count", "Financial Docs", "Outstanding Debt",
    "County ln(GDP)", "County ln(Pop)", "County ln(Pers. Inc)"
  ),
  `Mean (Vote = 0)` = mean_0,
  `Mean (Vote = 1)` = mean_1,
  Difference = diff_fmt
)]

latex_table <- xtable(
  diff_tbl
)

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
    # Pattern: \begin{tabular*}{\textwidth}{lccc}
    # We want: \begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lccc}
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
writeLines(diff_table_output, paste0(tables_wd, "/website_diff_means_table.tex"))

fwrite(
  table_out[variable == 'ln_1p_outstanding_debt_lag1',
            .(variable, mean_0, mean_1, diff, tstat, pval, n_0, n_1)],
  paste0(tables_wd, '/website_debt_outstanding_diff_means.csv')
)

#---------------------------------
# regs
#---------------------------------

r1 <- fixest::fepois(bond_url ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year, data = data, cluster = ~state_year)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year, data = data, cluster = ~state_year)
r3 <- fixest::fepois(fiscal_url ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year, data = data, cluster = ~state_year)
r4 <- fixest::fepois(fiscal_count ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year, data = data, cluster = ~state_year)
r5 <- fixest::fepois(financial_pdf_urls ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year, data = data, cluster = ~state_year)




table_call <- etable(r1, r2, r3, r4,r5,
       coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       #fontsize = 'small',
       dict = c(bond_url ='Bond URLs',
                bond_count ='Bond Count',
                fiscal_url = 'Fiscal URLs',
                fiscal_count = 'Fiscal Count',
                liabil_count = 'Liabilities Count',
                revenue_count = 'Revenue Count',
                expense_count = 'Expense Count',
                financial_pdf_urls = 'Financial Docs',
                city_go_vote = 'Vote',
                state_monitor = 'State Fiscal Monitor',
                ln_1p_outstanding_debt_lag1 = 'Outstanding Debt',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'State-Border', 
                year = 'Year'),
       placement = 'H',
       #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
       replace = TRUE)





modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)



modified_output <- format_table(modified_output, cluster_level = "State-Year")
modified_output <- add_panel(modified_output, 'Panel B: Regression analyses')

writeLines(modified_output, paste0(tables_wd, '/websites_regression.tex'))


#---------------------------------
# Supermajority-state specification
#---------------------------------

sm_r1 <- fixest::fepois(bond_url ~ city_go_vote + super_majority + ln_1p_outstanding_debt_lag1 +
                          state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year,
                        data = data, cluster = ~state_year)
sm_r2 <- fixest::fepois(bond_count ~ city_go_vote + super_majority + ln_1p_outstanding_debt_lag1 +
                          state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year,
                        data = data, cluster = ~state_year)
sm_r3 <- fixest::fepois(fiscal_url ~ city_go_vote + super_majority + ln_1p_outstanding_debt_lag1 +
                          state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year,
                        data = data, cluster = ~state_year)
sm_r4 <- fixest::fepois(fiscal_count ~ city_go_vote + super_majority + ln_1p_outstanding_debt_lag1 +
                          state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year,
                        data = data, cluster = ~state_year)
sm_r5 <- fixest::fepois(financial_pdf_urls ~ city_go_vote + super_majority + ln_1p_outstanding_debt_lag1 +
                          state_monitor + ln_gdp + ln_pop + ln_pers_inc | group + year,
                        data = data, cluster = ~state_year)

sm_table_call <- etable(
  sm_r1, sm_r2, sm_r3, sm_r4, sm_r5,
  coefstat = 'tstat',
  keep_raw = c('^city_go_vote$', '^super_majority$'),
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
  fitstat = c('n', 'pr2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    bond_url = 'Bond URLs',
    bond_count = 'Bond Count',
    fiscal_url = 'Fiscal URLs',
    fiscal_count = 'Fiscal Count',
    financial_pdf_urls = 'Financial Docs',
    city_go_vote = 'Vote',
    super_majority = 'Supermajority State',
    group = 'State-Border',
    year = 'Year'
  ),
  placement = 'H',
  replace = TRUE
)

sm_modified_output <- modify_etable_rounding(
  sm_table_call,
  coef_digits = 3,
  tstat_digits = 2
)

sm_modified_output <- format_table(sm_modified_output, cluster_level = "State-Year")
sm_modified_output <- add_panel(
  sm_modified_output,
  'Panel C: Supermajority-state specification',
  ncols = 6
)

writeLines(
  sm_modified_output,
  paste0(tables_wd, '/websites_regression_super_majority.tex')
)


#---------------------------------
# Time series: issuance years and website disclosure
#---------------------------------

website_city_year <- copy(data)
website_city_year[, year := year_int]
website_city_year[, state_year := interaction(state, year, drop = TRUE)]

issue_level <- haven::read_dta(
  '~/Dropbox/Voting on Bonds/Data/Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta',
  col_select = c('seed_issuer_id', 'year', 'issue_id', 'go_unlim', 'go_lim')
)
issue_level <- as.data.table(issue_level)
issue_level <- unique(issue_level[, .(seed_issuer_id, year, issue_id, go_unlim, go_lim)])
issue_level <- unique(issue_level[!is.na(seed_issuer_id) & !is.na(year),
                                  .(seed_issuer_id, year, issue_id, go_unlim, go_lim)])
issue_city_year <- issue_level[, .(num_issues_bond_data = uniqueN(issue_id), 
                                   num_issues_go = uniqueN(issue_id[go_unlim == 1 | go_lim == 1])),
                               by = .(seed_issuer_id, year)]

website_city_year <- issue_city_year[website_city_year, on = .(seed_issuer_id, year)]
website_city_year[is.na(num_issues_bond_data), num_issues_bond_data := 0L]
website_city_year[, issuance_window := ifelse(num_issues_bond_data > 0, 1, 0)]
website_city_year[, issuance_window_go := ifelse(num_issues_go > 0, 1, 0)]
website_city_year[is.na(issuance_window_go), issuance_window_go := 0]
website_city_year[is.na(issuance_window), issuance_window := 0]
website_city_year[, total_words := bond_count]

website_city_year_lag2 <- website_city_year[, .(seed_issuer,
                                                year = year + 1L,
                                                total_words_lag2 = total_words)]
website_city_year <- website_city_year_lag2[website_city_year, on = .(seed_issuer, year)]
website_city_year[, delta_bond_debt_count := total_words - total_words_lag2]
website_city_year[, positive_delta_bond_debt := ifelse(delta_bond_debt_count > 0, 1, 0)]

r1 <- feols(positive_delta_bond_debt ~ issuance_window_go | seed_issuer + year,
            data = website_city_year[!is.na(total_words_lag2)],
            cluster = ~state_year)

r2 <- feols(positive_delta_bond_debt ~ issuance_window_go + issuance_window_go:city_go_vote | seed_issuer + year,
            data = website_city_year[!is.na(total_words_lag2)],
            cluster = ~state_year)

r3 <- feols(positive_delta_bond_debt ~ issuance_window_go  +
              state_monitor + ln_gdp + ln_pop + ln_pers_inc | seed_issuer + year,
            data = website_city_year[!is.na(total_words_lag2) & city_go_vote == 1],
            cluster = ~state_year)

table_call <- etable(r1, r2, r3,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'),
                     se.below = TRUE,
                     digits = 3,
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10),
                     tex = TRUE,
                     dict = c(positive_delta_bond_debt = 'Increase in Bond Text',
                              issuance_window = 'Bond Issuance Year',
                              city_go_vote = 'Vote',
                              `issuance_window:city_go_vote` = 'Bond Issuance Year $\\times$ Vote',
                              state_monitor = 'State Fiscal Monitor',
                              ln_gdp = 'County ln(GDP)',
                              ln_pop = 'County ln(Pop)',
                              ln_pers_inc = 'County ln(Pers. Inc)',
                              seed_issuer = 'City',
                              year = 'Year'),
                     placement = 'H',
                     replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State-Year")
modified_output <- add_panel(modified_output, 'Panel A: Issuance years and website disclosure over time', ncols = 4)

writeLines(modified_output, paste0(tables_wd, '/websites_issuance_time_series_reg.tex'))
