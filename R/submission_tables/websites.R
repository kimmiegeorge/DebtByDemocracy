
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, xtable)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/submission_tables"
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/submission_tables"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_251111_with_recovered.csv')
data <- data[!(group %in% c('Rhode Island/Massachusetts'))]

data <- data[!is.na(total_subs)]
data <- data[!is.na(city_go_vote)]
data <- data[total_subs == 50]


# variable adjustments 
data[, ln_cum_num_issues_all := log(1+cum_num_issues_all)]
data[, group := as.factor(group)]
data[, year_int := year]
data[, year := as.factor(year)]


#data <- data[!(group %in% c('Rhode Island/Massachusetts', 'Missouri/Kentucky', 'Missouri/Tennessee'))]
state_policy <- fread('/Users/kmunevar/Dropbox/Voting on Bonds/Data/State Monitoring Policy/state_enforcement_adoption_years.csv')
state_policy[, AdoptionYear := ifelse(AdoptionYear == 'before_sample', 2009, AdoptionYear )]
setnames(state_policy, 'Abbreviation', 'state')

data <- state_policy[data, on = .(state)]
data[, state_monitor := ifelse(!is.na(AdoptionYear) & year_int >= AdoptionYear, 1, 0)]


# create indicator variables 
data[, has_bond_url := ifelse(bond_url > 0, 1, 0)]
data[, has_fiscal_url := ifelse(fiscal_url > 0, 1, 0)]

data[, log_total_content_length := log(total_content_length)]
data[, log_numeric_tokens := log(1 + total_numeric_tokens)]

# issue with bond counts
data <- data[seed_issuer != 'BONDUEL WIS']


data[, fiscal_url := Winsorize(fiscal_url, val = quantile(fiscal_url, probs = c(0.01, 0.99)))]
data[, fiscal_count := Winsorize(fiscal_count, val = quantile(fiscal_count, probs = c(0.01, 0.99)))]
data[, bond_url := Winsorize(bond_url, val = quantile(bond_url, probs = c(0.01, 0.99)))]
data[, bond_count := Winsorize(bond_count, val = quantile(bond_count, probs = c(0.01, 0.99)))]
data[, financial_pdf_urls := Winsorize(financial_pdf_urls, val = quantile(financial_pdf_urls, probs = c(0.01, 0.99)))]

#---------------------------------------
# Descriptives
#---------------------------------------

desc <- data[, .(city_go_vote, bond_url,
                 bond_count,
                 fiscal_url, fiscal_count,financial_pdf_urls, cum_num_issues_all, state_monitor)]

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
desc_col <- transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
desc_col[, variable := c('Vote', 'Bond URLs',  'Bond Count', 
                         'Fiscal URLs', 'Fiscal Count', 'Financial Docs', 'Num Issuances', 'State Fiscal Monitor')]
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


vars <- c('cum_num_issues_all', "bond_url", "bond_count",
          "fiscal_url", "fiscal_count", "financial_pdf_urls")

table_out <- diff_table(data[total_subs == 50], "city_go_vote", vars)

# View formatted table
print(table_out[, .(variable, mean_0, mean_1, diff_fmt)])


diff_tbl <- table_out[, .(
  Variable = c(
    "Num Issuances", "Bond URLs", "Bond Count",
    "Fiscal URLs", "Fiscal Count", "Financial Docs"
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

#---------------------------------
# regs
#---------------------------------

r1 <- fixest::fepois(bond_url ~ city_go_vote + ln_cum_num_issues_all  + state_monitor+   ln_gdp + ln_pop +  ln_pers_inc  |group + year, data = data, cluster ~ fips)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_cum_num_issues_all  + state_monitor+   ln_gdp + ln_pop +  ln_pers_inc  |group + year, data = data, cluster ~ fips)
r3 <- fixest::fepois(fiscal_url ~ city_go_vote + ln_cum_num_issues_all  + state_monitor +   ln_gdp + ln_pop +  ln_pers_inc  |group + year, data = data, cluster ~ fips)
r4 <- fixest::fepois(fiscal_count ~ city_go_vote + ln_cum_num_issues_all  + state_monitor +  ln_gdp + ln_pop +  ln_pers_inc   |group + year, data = data, cluster ~ fips)
r5 <- fixest::fepois(financial_pdf_urls ~ city_go_vote + ln_cum_num_issues_all  + state_monitor +   ln_gdp + ln_pop +  ln_pers_inc   |group + year, data = data, cluster ~ fips)




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
                ln_cum_num_issues_all = 'Num Issuances',
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



modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel B: Regression analyses')

writeLines(modified_output, paste0(tables_wd, '/websites_regression.tex'))


