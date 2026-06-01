rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251217_kmtables/"

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
desc <- data[year > 2004 & !is.na(ln_gdp), .(traded_before_maturity, 
                     city_go_vote,
                 disclosed_before_maturity, 
                 ln_amount, ln_maturity_mths, 
                 callable, sinkable, insured, rating_num)]

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

desc_col[, variable := c('I(Trade)', 'Vote', 'I(Continuing Disclosure)', 'Amount',
                         'Maturity', 'Callable', 'Sinkable', 'Insured', 'Rating')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tables_wd ,'/Trade before Maturity Level Desc.tex'))



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
# output
#----------------------------------


table_call <- etable(r2, r3, r2b, r3b,
                     title = 'Secondary Market Trading and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     fontsize = 'small',
                     headers = list("Full Sample" = 2, "State-Border Sample" = 2),
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(traded_before_maturity ='I(Trade)',
                              city_go_vote = 'Vote',
                              disclosed_before_maturity = 'I(Continuing Disclosure)',
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

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity.tex'))










