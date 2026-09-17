rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/border_pair_definitions.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables/"

#----------------------------------
# main df
#----------------------------------

data <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/Bond_Level_Any_Trade_Before_Maturity_with_CD_Data_260611.csv')
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
high_state_tax_privilege_states <- c('CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN',
                                     'NC', 'ID', 'NY', 'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE')
data[, high_state_tax_privilege := ifelse(state %in% high_state_tax_privilege_states, 1, 0)]

super_majority_states <- c('CA', 'ID', 'MO','ND','SD', 'WA')
data[, super_majority := ifelse(state %in% super_majority_states, 1, 0)]
#----------------------------------
# border state
#----------------------------------

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20260611.csv')
border_states <- filter_paper_border_pairs(border_states)
border_states <- border_states[go_unlim == 1]
#border_states <- Wins(border_states, col_list)
border_states <- unique(border_states[, .(seed_issuer_id,group)])
border_states <- data[border_states, on = .(seed_issuer_id)]
border_states <- border_states[!is.na(cusip)]

#----------------------------------
# disclosure measures for heterogeneity tests
#----------------------------------

# Website disclosure is only available for the border sample. Match the
# election-outcomes specification: high bond disclosure is above-median bond text.
website_disclosure <- fread(
  '~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_260611_with_recovered.csv',
  select = c('seed_issuer_id', 'year', 'total_subs', 'bond_count')
)
website_disclosure <- website_disclosure[total_subs == 50 & !is.na(seed_issuer_id)]
website_disclosure <- unique(website_disclosure[, .(seed_issuer_id, year, bond_count)])
website_disclosure[, high_bond_count := ifelse(bond_count > median(bond_count, na.rm = TRUE), 1, 0)]
border_states <- website_disclosure[, .(seed_issuer_id, year, bond_count, high_bond_count)][
  border_states,
  on = .(seed_issuer_id, year)
]

# Media disclosure is available for the full sample at the issuer-month level.
# The source file has duplicate issuer-month rows with identical coverage values,
# so unique() avoids multiplying the bond-level sample during the merge.
media_disclosure <- fread(
  '~/Dropbox/Voting on Bonds/Data/News/Issuance_Lvl_News_With_Lagged_News_260611.csv',
  select = c('seed_issuer_id', 'year', 'month', 'total_rp_articles_12_0')
)
media_disclosure <- unique(media_disclosure)
media_disclosure[, high_articles_12_0 := ifelse(
  total_rp_articles_12_0 > median(total_rp_articles_12_0, na.rm = TRUE), 1, 0
)]
data <- media_disclosure[, .(seed_issuer_id, year, month, total_rp_articles_12_0, high_articles_12_0)][
  data,
  on = .(seed_issuer_id, year, month)
]


#----------------------------------
# descriptives
#----------------------------------
# DESCRIPTIVES - ELECTION LEVEL 
desc <- data[year > 2004 & !is.na(ln_gdp), .(city_go_vote, traded_before_maturity, retail_traded_before_maturity, institutional_traded_before_maturity,
                 high_state_tax_privilege, disclosed_before_maturity, 
                 ln_amount, ln_maturity_mths, 
                 callable, sinkable, insured, rating_num)]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Unit = 'Bond',
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
colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, Variable := c('Vote','Trade', 'Retail Trade', 'Inst. Trade', 'High Tax Priv.',  'Continuing Disclosure', 'Amount',
                         'Maturity', 'Callable', 'Sinkable', 'Insured', 'Rating')]

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

library(xtable)
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

# Add \toprule after the first \hline
for (i in seq_along(desc_table_output)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", desc_table_output[i])) {
    desc_table_output[i] <- "  \\toprule"
    break
  }
}

# Add panel title using add_panel function
desc_table_output <- add_panel(desc_table_output, 'Panel D: Secondary market trading descriptive statistics', ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tables_wd, '/secondary_market_descriptives.tex'))



#----------------------------------
# reg
#----------------------------------


r1 <- feols(traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r1)

r2 <- feols(traded_before_maturity ~ city_go_vote + high_state_tax_privilege + disclosed_before_maturity +  ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
            + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r2)



#----------------------------------
# reg - border state
#----------------------------------

r1b <- feols(traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~issue_id, 
            data = border_states[year > 2004])
summary(r1b)


r2b <- feols(traded_before_maturity ~ city_go_vote + high_state_tax_privilege +  disclosed_before_maturity  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~issue_id, 
            data = border_states[year > 2004])
summary(r2b)


#----------------------------------
# reg
#----------------------------------


r1_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r1_r)

r2_r <- feols(retail_traded_before_maturity ~ city_go_vote + high_state_tax_privilege +  disclosed_before_maturity  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~issue_id, 
            data = data[year > 2004])
summary(r2_r)



#----------------------------------
# reg - border state
#----------------------------------

r1b_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r1b_r)


r2b_r <- feols(retail_traded_before_maturity ~ city_go_vote + high_state_tax_privilege +  disclosed_before_maturity  + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r2b_r)


#----------------------------------
# reg
#----------------------------------


r1_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r1_i)


r2_i <- feols(institutional_traded_before_maturity ~ city_go_vote +  high_state_tax_privilege +  disclosed_before_maturity  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~issue_id, 
            data = data[year > 2004])
summary(r2_i)



#----------------------------------
# reg - border state
#----------------------------------

r1b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosed_before_maturity +  ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r1b_i)


r2b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + high_state_tax_privilege +  disclosed_before_maturity  + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r2b_i)


#----------------------------------
# reg - investor response by website disclosure
#----------------------------------

r_web <- feols(traded_before_maturity ~ city_go_vote * high_bond_count + disclosed_before_maturity + ln_amount + ln_maturity_mths + 
                 callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group,
               ~issue_id,
               data = border_states[year > 2004 & !is.na(high_bond_count)])
summary(r_web)

r_web_r <- feols(retail_traded_before_maturity ~ city_go_vote * high_bond_count + disclosed_before_maturity + ln_amount + ln_maturity_mths + 
                   callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group,
                 ~issue_id,
                 data = border_states[year > 2004 & !is.na(high_bond_count)])
summary(r_web_r)

r_web_i <- feols(institutional_traded_before_maturity ~ city_go_vote * high_bond_count + disclosed_before_maturity + ln_amount + ln_maturity_mths + 
                   callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group,
                 ~issue_id,
                 data = border_states[year > 2004 & !is.na(high_bond_count)])
summary(r_web_i)


#----------------------------------
# reg - investor response by media disclosure
#----------------------------------

r_media <- feols(traded_before_maturity ~ city_go_vote * high_articles_12_0 + disclosed_before_maturity + ln_amount + ln_maturity_mths + 
                   callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad,
                 ~issue_id,
                 data = data[year > 2004 & !is.na(high_articles_12_0)])
summary(r_media)

r_media_r <- feols(retail_traded_before_maturity ~ city_go_vote * high_articles_12_0 + disclosed_before_maturity + ln_amount + ln_maturity_mths + 
                     callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad,
                   ~issue_id,
                   data = data[year > 2004 & !is.na(high_articles_12_0)])
summary(r_media_r)

r_media_i <- feols(institutional_traded_before_maturity ~ city_go_vote * high_articles_12_0 + disclosed_before_maturity + ln_amount + ln_maturity_mths + 
                     callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad,
                   ~issue_id,
                   data = data[year > 2004 & !is.na(high_articles_12_0)])
summary(r_media_i)






#----------------------------------
# alternative output
#----------------------------------

# full sample
table_call <- etable(r2, r2_r, r2_i, 
                     #title = 'Secondary Market Trading and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     #headers = list("Full Sample" = 2, "State-Border Sample" = 2),
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     drop_raw = c("ln_gdp", "ln_pop", "ln_pers_inc", "ln_emp"),
                     order = c("%city_go_vote", "%high_state_tax_privilege", "%disclosed_before_maturity"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              high_state_tax_privilege = 'High Tax Priv.',
                              disclosed_before_maturity = 'Continuing Disclosure',
                              avg_disclosures_per_year_before_maturity = 'CD Per Year',
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rating_num = 'Rating',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              
                              group = 'Border', 
                              yrmonth = 'YM',
                              year = 'Year',
                              purp_broad = 'Purpose',
                              ym = 'Year-Month',
                              issue_id = 'Issue'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/bond_yields.tex'), 
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "Issue")
modified_output <- add_panel(modified_output, 'Panel A: Full sample')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_full_sample_tax.tex'))


# border sample
table_call <- etable(r2b, r2b_r, r2b_i,  
                     #title = 'Secondary Market Trading and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     #headers = list("Full Sample" = 2, "State-Border Sample" = 2),
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep_raw = c("city_go_vote", "high_state_tax_privilege", "disclosed_before_maturity"),
                     order = c("%city_go_vote", "%high_state_tax_privilege", "%disclosed_before_maturity"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              disclosed_before_maturity = 'Continuing Disclosure',
                              high_state_tax_privilege = 'High Tax Priv.',
                              avg_disclosures_per_year_before_maturity = 'CD Per Year',
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rating_num = 'Rating',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              
                              group = 'State-Border', 
                              yrmonth = 'YM',
                              year = 'Year',
                              purp_broad = 'Purpose',
                              ym = 'Year-Month',
                              issue_id = 'Issue'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/bond_yields.tex'), 
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "Issue")
modified_output <- add_panel(modified_output, 'Panel B: Border-city sample')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_border_sample_tax.tex'))


# website disclosure heterogeneity
table_call <- etable(r_web, r_web_r, r_web_i,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3",
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep_raw = c("city_go_vote", "high_bond_count", "city_go_vote:high_bond_count", "disclosed_before_maturity"),
                     order = c("%city_go_vote:high_bond_count", "%city_go_vote", "%high_bond_count", "%disclosed_before_maturity"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              high_bond_count = 'High Bond Text',
                              'city_go_vote:high_bond_count' = 'Vote $\\times$ High Bond Text',
                              disclosed_before_maturity = 'Continuing Disclosure',
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rating_num = 'Rating',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              group = 'State-Border', 
                              year = 'Year',
                              purp_broad = 'Purpose',
                              issue_id = 'Issue'),
                     placement = 'H',
                     replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "Issue")
modified_output <- add_panel(modified_output, 'Panel C: Border-city sample by website disclosure')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_border_sample_website_disclosure.tex'))


# media disclosure heterogeneity
table_call <- etable(r_media, r_media_r, r_media_i,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3",
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep_raw = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0", "disclosed_before_maturity"),
                     order = c("%city_go_vote:high_articles_12_0", "%city_go_vote", "%high_articles_12_0", "%disclosed_before_maturity"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              high_articles_12_0 = 'High Media Coverage',
                              'city_go_vote:high_articles_12_0' = 'Vote $\\times$ High Media Coverage',
                              disclosed_before_maturity = 'Continuing Disclosure',
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rating_num = 'Rating',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              year = 'Year',
                              purp_broad = 'Purpose',
                              issue_id = 'Issue'),
                     placement = 'H',
                     replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "Issue")
modified_output <- add_panel(modified_output, 'Panel D: Full sample by media coverage')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_full_sample_media_disclosure.tex'))



#----------------------------------
# reg - supermajority
#----------------------------------

r1b_r <- feols(retail_traded_before_maturity ~ city_go_vote + super_majority + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
             ~issue_id, 
             data = data[year > 2004])
summary(r1b_r)
