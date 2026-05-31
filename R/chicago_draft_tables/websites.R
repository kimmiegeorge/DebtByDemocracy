
#trace(stargazer:::.stargazer.wrap, edit = T) # 950 change round to 2 digits
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, xtable)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_251015.csv')
data <- data[!(group %in% c('Rhode Island/Massachusetts'))]

data <- data[!is.na(total_subs)]
data <- data[!is.na(city_go_vote)]
data <- data[total_subs > 1]
#data <- data[total_subs == 50]

# variable adjustments 
data[, ln_cum_num_issues_all := log(1+cum_num_issues_all)]
data[, group := as.factor(group)]
data[, year := as.factor(year)]


#data <- data[!(group %in% c('Rhode Island/Massachusetts', 'Missouri/Kentucky', 'Missouri/Tennessee'))]




#---------------------------------------
# Descriptives
#---------------------------------------

desc <- data[, .(city_go_vote, bond_url, 
                 bond_count,
                 fiscal_url, fiscal_count, cum_num_issues_all)]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Mean = mean(col, na.rm = TRUE),
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
colnames(desc_col) <- c("variable", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
desc_col[, variable := c('Vote', 'Bond or Debt URL Count', 'Bond or Debt Count', 'Fiscal URL Count', 'Fiscal Count', 'Num Issuances')]

stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Website Descriptives.tex'))




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
  res[, diff_fmt := sprintf("%.2f%s\n(%.2f)", diff, stars, abs(tstat))]
  
  return(res)
}

#---------------------------------
# Example usage
#---------------------------------
data[, tax2_count := tax_count + valorem_count + advalorem_count + homestead_count  + abatement_count   + apprais_count]

data[, budget_appro := budget_count + appro_count]
data[, revenue_exp := revenue_count + expense_count]
data[, liabil_debt := liabil_count + debt_count]
data[, capital_project := capital_count + project_count]

vars <- c('cum_num_issues_all', "bond_url", "bond_count", "fiscal_url", "fiscal_count")

table_out <- diff_table(data[total_subs == 50], "city_go_vote", vars)

# View formatted table
print(table_out[, .(variable, mean_0, mean_1, diff_fmt)])

#---------------------------------
# Export to LaTeX
#---------------------------------
latex_table <- xtable(table_out[, .(Variable = c('Num Issuances', 'Bond or Debt URL Count', 'Bond or Debt Count', 'Fiscal URL Count', 'Fiscal Count'),
                                    `Mean (0)` = mean_0,
                                    `Mean (1)` = mean_1,
                                    `Difference` = diff_fmt)],
                      caption = "Difference in Means with t-statistics",
                      label = "tab:diff_means")

print(latex_table,
      include.rownames = FALSE,
      sanitize.text.function = identity, # keeps parentheses and stars
      file = paste0(tables_wd, "/website_diff_means_table.tex"))

data[, tax_revenue := tax_count + revenue_count]
data[, max_issues := max(num_issues_all), .(seed_issuer)]
data[, tax2_win := Winsorize(tax2_count, val = quantile(tax2_count, probs = c(0.01, 0.99)))]
data[, tax2_win := Winsorize(tax2_count, val = quantile(tax2_count, probs = c(0.01, 0.99)))]

data[is.na(fiscal_count), fiscal_count := 0]
data[is.na(bond_url), bond_url := 0]
data[is.na(fiscal_url), fiscal_url := 0]
data[is.na(bond_count), bond_count := 0]

data[, bond_debt := bond_count + debt_count]
data[, bond_debt_url := bond_url + debt_count]
data[is.na(fy_count), fy_count := 0]
data[, fiscal_count2 := fiscal_count + fy_count]

r1 <- fixest::fepois(bond_url ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + state_go_vote|group + year, data = data[total_subs == 50], cluster ~ fips)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + state_go_vote |group + year, data = data[total_subs == 50], cluster ~ fips)
r3 <- fixest::fepois(fiscal_url ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + state_go_vote  |group + year, data = data[total_subs == 50], cluster ~ fips)
r4 <- fixest::fepois(fiscal_count ~ city_go_vote + ln_cum_num_issues_all  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + state_go_vote |group + year, data = data[total_subs == 50], cluster ~ fips)


table_call <- etable(r1, r2, r3, r4,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       fontsize = 'small',
       dict = c(bond_url ='Bond or Debt URL Count',
                bond_count ='Bond or Debt Count',
                fiscal_url = 'Fiscal URL Count',
                fiscal_count = 'Fiscal Count',
                liabil_count = 'Liabilities Count',
                revenue_count = 'Revenue Count',
                expense_count = 'Expense Count',
                city_go_vote = 'Vote',
                ln_cum_num_issues_all = 'Num Issuances',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                year = 'Year'),
       placement = 'H',
       #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
       replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tables_wd, '/websites_Expanded.tex'))

