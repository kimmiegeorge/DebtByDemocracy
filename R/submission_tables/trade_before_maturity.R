rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/submission_tables/"

#----------------------------------
# main df
#----------------------------------

data <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv')
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]

#----------------------------------
# border state
#----------------------------------

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states <- border_states[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states <- unique(border_states[, .(seed_issuer_id,group)])
border_states <- data[border_states, on = .(seed_issuer_id)]
border_states <- border_states[!is.na(cusip)]


#----------------------------------
# descriptives
#----------------------------------
# DESCRIPTIVES - ELECTION LEVEL 
desc <- data[year > 2004 & !is.na(ln_gdp), .(city_go_vote, traded_before_maturity, retail_traded_before_maturity, institutional_traded_before_maturity,
                 disclosed_before_maturity, 
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
desc_col <- transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, Variable := c('Vote','Trade', 'Retail Trade', 'Inst. Trade',   'Continuing Disclosure', 'Amount',
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


r2 <- feols(traded_before_maturity ~ city_go_vote + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r2)

r3 <- feols(traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
            + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r3)

r4 <- feols(traded_before_maturity ~ city_go_vote +  avg_disclosures_per_year_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
            + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~issue_id, 
            data = data[year > 2004])
summary(r4)



#----------------------------------
# reg - border state
#----------------------------------

r2b <- feols(traded_before_maturity ~ city_go_vote + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~issue_id, 
            data = border_states[year > 2004])
summary(r2b)

r3b <- feols(traded_before_maturity ~ city_go_vote + disclosed_before_maturity +  ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad + group, 
            ~issue_id, 
            data = border_states[year > 2004])
summary(r3b)

r4b <- feols(traded_before_maturity ~ city_go_vote + avg_disclosures_per_year_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~issue_id, 
            data = border_states[year > 2004])
summary(r4b)


#----------------------------------
# reg
#----------------------------------


r2_r <- feols(retail_traded_before_maturity ~ city_go_vote + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r2_r)

r3_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r3_r)

r4_r <- feols(retail_traded_before_maturity ~ city_go_vote +  avg_disclosures_per_year_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~issue_id, 
            data = data[year > 2004])
summary(r4_r)



#----------------------------------
# reg - border state
#----------------------------------

r2b_r <- feols(retail_traded_before_maturity ~ city_go_vote + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r2b_r)

r3b_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosed_before_maturity +  ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad + group, 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r3b_r)

r4b_r <- feols(retail_traded_before_maturity ~ city_go_vote + avg_disclosures_per_year_before_maturity + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r4b_r)


#----------------------------------
# reg
#----------------------------------


r2_i <- feols(institutional_traded_before_maturity ~ city_go_vote + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r2_i)

r3_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosed_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad, 
            ~issue_id, 
            data = data[year > 2004])
summary(r3_i)

r4_i <- feols(institutional_traded_before_maturity ~ city_go_vote +  avg_disclosures_per_year_before_maturity + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~issue_id, 
            data = data[year > 2004])
summary(r4_i)



#----------------------------------
# reg - border state
#----------------------------------

r2b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r2b_i)

r3b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosed_before_maturity +  ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad + group, 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r3b_i)

r4b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + avg_disclosures_per_year_before_maturity + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
             ~issue_id, 
             data = border_states[year > 2004])
summary(r4b_i)






#----------------------------------
# alternative output
#----------------------------------

# full sample
table_call <- etable(r2, r3, r2_r, r3_r, r2_i, r3_i,
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
                     order = c("%city_go_vote", "%disclosed_before_maturity"),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
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
modified_output <- add_panel(modified_output, 'Panel A: Regression analyses - Full Sample')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_full_sample.tex'))


# border sample
table_call <- etable(r2b, r3b, r2b_r, r3b_r, r2b_i, r3b_i,
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
                     order = c("%city_go_vote", "%disclosed_before_maturity"),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
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
modified_output <- add_panel(modified_output, 'Panel B: Regression analyses - Border-City Sample')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_border_sample.tex'))






