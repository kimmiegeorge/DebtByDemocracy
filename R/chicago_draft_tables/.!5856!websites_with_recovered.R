
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, xtable)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251217_kmtables"
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251217_kmtables"

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

#---------------------------------------
# Descriptives
#---------------------------------------

desc <- data[, .(city_go_vote, bond_url,
                 bond_count,
                 fiscal_url, fiscal_count,financial_pdf_urls, cum_num_issues_all)]

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
desc_col[, variable := c('Vote', 'Bond URL Count',  'Bond Count', 
                         'Fiscal URL Count', 'Fiscal Count', 'PDF Financial Docs', 'Num Issuances')]

latex_table <- xtable(
  desc_col,
  caption = "Descriptive Statistics",
  label = "tab:website_descriptives",
  digits = c(
    0,  # row names (required, even if not printed)
    0,  # Variable (character column)
    2,  # Mean
    2,  # Std
    2,  # Min
    2,  # P1
    2,  # Median
    2,  # P99
    2,  # Max
    0   # N (integer)
  )
)

print(
  latex_table,
  include.rownames = FALSE,
  sanitize.text.function = identity,
  tabular.environment = "tabular*",
  width = "\\textwidth",
  add.to.row = list(
    pos = list(0),
    command = paste0(
      "\\setlength{\\tabcolsep}{4pt}\n",
      "\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lcccccccc}\n"
    )
  ),
  file = paste0(tbl_dir, "/Website_Descriptives.tex")
)


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

#---------------------------------
# Example usage
#---------------------------------


vars <- c('cum_num_issues_all', "bond_url", "bond_count",
          "fiscal_url", "fiscal_count", "financial_pdf_urls")

table_out <- diff_table(data[total_subs == 50], "city_go_vote", vars)

# View formatted table
print(table_out[, .(variable, mean_0, mean_1, diff_fmt)])


diff_tbl <- table_out[, .(
  Variable = c(
    "Num Issuances", "Bond URL Count", "Bond Count",
    "Fiscal URL Count", "Fiscal Count", "Financial Docs"
  ),
  `Mean (Vote = 0)` = mean_0,
  `Mean (Vote = 1)` = mean_1,
  Difference = diff_fmt
)]

latex_table <- xtable(
  diff_tbl
)

addtorow <- list(
  pos = list(-1),
  command = paste0(
    "\\setlength{\\tabcolsep}{6pt}\n",
    "\\multicolumn{4}{l}{\\textbf{Panel A: Mean Values by Vote Requirement}} \\\\\n",
    "\\addlinespace\n"
  )
)

print(
  latex_table,
  include.rownames = FALSE,
  sanitize.text.function = identity,
  tabular.environment = "tabular*",
  width = "\\textwidth",
  add.to.row = addtorow,
  file = paste0(tables_wd, "/website_diff_means_table.tex")
)

#---------------------------------
# regs
#---------------------------------

data[, ln_cum_issues_5 := log(1 + rolling_sum_num_issues_5_all)]

r1 <- fixest::fepois(bond_url ~ city_go_vote + ln_cum_num_issues_all  + state_monitor+   ln_gdp + ln_pop +  ln_pers_inc  |group + year, data = data, cluster ~ fips)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_cum_num_issues_all  + state_monitor+   ln_gdp + ln_pop +  ln_pers_inc  |group + year, data = data, cluster ~ fips)
r3 <- fixest::fepois(fiscal_url ~ city_go_vote + ln_cum_num_issues_all  + state_monitor +   ln_gdp + ln_pop +  ln_pers_inc  |group + year, data = data, cluster ~ fips)
r4 <- fixest::fepois(fiscal_count ~ city_go_vote + ln_cum_num_issues_all  + state_monitor +  ln_gdp + ln_pop +  ln_pers_inc   |group + year, data = data, cluster ~ fips)
r5 <- fixest::fepois(financial_pdf_urls ~ city_go_vote + ln_cum_num_issues_all  + state_monitor +   ln_gdp + ln_pop +  ln_pers_inc   |group + year, data = data, cluster ~ fips)




table_call <- etable(r1, r2, r3, r4,r5,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       fontsize = 'small',
       dict = c(bond_url ='Bond URL Count',
                bond_count ='Bond Count',
                fiscal_url = 'Fiscal URL Count',
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
                group = 'Border', 
                year = 'Year'),
       placement = 'H',
       #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
       replace = TRUE)


add_panel_B <- function(tex) {
  gsub(
    "(\\\\begin\\{tabular\\}\\{[^}]+\\})",
    "\\1\n\\\\multicolumn{6}{l}{\\\\textbf{Panel B: Regression Results}} \\\\\\n\\\\addlinespace\n",
    tex
  )
}


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- add_panel_B(modified_output)

add_vote_rowcolor <- function(tex) {
  # color coefficient row
  tex <- gsub(
    "(^\\s*Vote\\s*&)",
    "\\\\rowcolor{ltblue}\n\\1",
    tex,
    perl = TRUE
  )
  
  # color the immediately following t-stat row
  tex <- gsub(
    "(\\\\rowcolor\\{ltblue\\}[\\s\\S]*?\\\\\\\\\\n)(\\s*&)",
    "\\1\\\\rowcolor{ltblue}\n\\2",
    tex,
    perl = TRUE
  )
  
  tex
}

modified_output <- add_vote_rowcolor(modified_output)


writeLines(modified_output, paste0(tables_wd, '/websites_regression.tex'))




#---------------------------------
# XS
#---------------------------------

more_than_majority <- c('CA', 'ID', 'MO', 'ND', 'OK', 'SD', 'WA', 'WV')




# GET CLOSE HERE 
data[, has_bond_url := ifelse(bond_url >0, 1,)]
r1 <- fixest::fepois(bond_url ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  + state_monitor  |group + year, data = data, cluster ~ fips)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  +state_monitor    |group + year, data = data, cluster ~ fips)
r3 <- fixest::fepois(fiscal_url ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  + state_monitor   |group + year, data = data, cluster ~ fips)
r4 <- fixest::fepois(fiscal_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  +state_monitor  |group + year, data = data, cluster ~ fips)
r5 <- fixest::fepois(financial_pdf_urls ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  +state_monitor  |group + year, data = data, cluster ~ fips)


data[, has_bond_url := ifelse(bond_or_debt_url > 0, 1, 0)]
data[, has_fiscal_url := ifelse(fiscal_url > 0, 1, 0)]
data[, bond_debt_url_win := Winsorize(bond_or_debt_url, val = quantile(bond_or_debt_url, probs = c(0.01, 0.99)))]
r1 <- feols(has_bond_url ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc    |group + year, data = data, cluster ~ fips)
r2 <- fixest::fepois(bond_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc      |group + year, data = data, cluster ~ fips)
r3 <- fixest::fepois(fiscal_url ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc     |group + year, data = data, cluster ~ fips)
r4 <- fixest::fepois(fiscal_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc   |group + year, data = data, cluster ~ fips)
r5 <- fixest::fepois(financial_pdf_urls ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc   |group + year, data = data, cluster ~ fips)


#---------------------------------------
# XS
#---------------------------------------

chi_sq_coef_diff <- function(model1, model2, coef_name) {
  # Extract coefficient estimates using generic coef()
  b1 <- coef(model1)[coef_name]
  b2 <- coef(model2)[coef_name]
  
  # Extract clustered SEs using fixest::se()
  se1 <- fixest::se(model1)[coef_name]
  se2 <- fixest::se(model2)[coef_name]
  
  # Difference in coefficients
  diff <- b1 - b2
  
  # Variance of the difference (independent samples)
  var_diff <- se1^2 + se2^2
  
  # Chi-square statistic (df = 1)
  chi_sq <- (diff^2) / var_diff
  
  # p-value
  p_val <- 1 - pchisq(chi_sq, df = 1)
  
  data.frame(
    coef = coef_name,
    estimate_group1 = b1,
    estimate_group0 = b2,
    difference = diff,
    chi_sq = chi_sq,
    p_value = p_val
  )
}



# turnout data 
turnout <- load('/Users/kmunevar/Dropbox/Voting on Bonds/Data/ICPSR_38506/DS0001/38506-0001-Data.rda')
turnout <- as.data.table(get(turnout))



turnout[, year := as.integer(YEAR) + 1]
turnout[, YEAR := NULL]
turnout[, fips := as.integer(as.character(STCOFIPS10))]
turnout[, STCOFIPS10 := NULL]

# turnout has fips, year, and many turnout variables
setDT(turnout)

# Identify turnout variables (all except fips/year)
turnout_cols <- setdiff(names(turnout), c("fips", "year"))

# Ensure year numeric
turnout[, year := as.integer(year)]

