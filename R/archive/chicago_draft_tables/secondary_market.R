'''
Secondary market yields tests at the BOND level
'''
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/Bond_Level_Secondary_Market_Vars_With_Bond_Vars_2005_2023.csv')
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote) & !is.na(ln_pop) & go_unlim == 1 & !is.na(callable)]


data[, yrmonth := paste0(year, month)]
#data <- data[!is.na(markup_3yr) & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)]


col_list = c('yield_volatility_1yr', 'yield_volatility_6mo', 'yield_volatility_3yr', 
             'markup_1yr', 'markup_3yr', 'markup_6mo','markup_retail_1yr', 'markup_retail_3yr', 'markup_retail_6mo',
             'markup_small_retail_1yr', 'markup_small_retail_3yr', 'markup_small_retail_6mo'
)

Wins <- function(df, col_list){
  for (col in col_list){
    df[, (col) := Winsorize(df[[col]], val = quantile(df[[col]], probs = c(0.01, 0.99), na.rm = T))]
  }
  return(df)
}

#data <- Wins(data, col_list)

#data <- Wins(data, col_list)

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states <- border_states[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts', 'Missouri/Tennessee', 'Missouri/Kentucky'))]
#border_states <- Wins(border_states, col_list)
border_states <- unique(border_states[, .(seed_issuer_id,group)])
border_states <- data[border_states, on = .(seed_issuer_id)]



data[,markup_1yr := markup_1yr/100]
data[,markup_retail_1yr := markup_retail_1yr/100]
data[,markup_institutional_1yr := markup_institutional_1yr/100]

border_states[,markup_1yr := markup_1yr/100]
border_states[,markup_retail_1yr := markup_retail_1yr/100]
border_states[,markup_institutional_1yr := markup_institutional_1yr/100]

#---------------------------------------

vars = c('markup_3yr', 'markup_retail_3yr', 'markup_institutional_3yr', 'callable', 'sinkable', 'insured', 'rated')

all_desc = data.table()
for (var in vars){
  print(var)
  desc <- data[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr), list(Mean = mean(get(var)), 
                                      SD = sd(get(var)), 
                                      Min = min(get(var)),
                                      p1 = quantile(get(var), 0.01), 
                                      Median = median(get(var)), 
                                      p99 = quantile(get(var), 0.99), 
                                      Max = max(get(var)), 
                                      N = .N[!is.na(get(var))])][1]
  desc <- round(desc, 2)
  all_desc <- rbind(all_desc, desc)
}

varnames = c('Markup', 'Retail Markup', 'Institutional Markup', 'Callable', 'Sinkable', 'Insured', 'Rated')
varnames = data.table(varnames)
all_desc <- cbind(varnames, all_desc)


stargazer(all_desc, summary = F, no.space = T, rownames = F, 
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables/markup_desc.tex')



#---------------------------------------

mean(data$markup_institutional_3yr, na.rm = T)

data[, log_num_trades_1yr := log(number_of_trades_1yr)]
data[, log_num_trades_3yr := log(number_of_trades_3yr)]
data[, log_num_trades_6mo := log(number_of_trades_6mo)]
border_states[, log_num_trades_1yr := log(number_of_trades_1yr)]
border_states[, log_num_trades_3yr := log(number_of_trades_3yr)]
border_states[, log_num_trades_6mo := log(number_of_trades_6mo)]
border_states[, group_year := paste0(group, year)]

data[, small_premium:= markup_retail_buy_1yr - markup_institutional_buy_1yr]
data[, small_discount:= markup_retail_sell_3yr - markup_institutional_sell_3yr]
data[is.na(city_rev_vote), city_rev_vote := 0]

data[, amount_quintile := ntile(ln_amount, 5)]
border_states[, amount_quintile := ntile(ln_amount, 5)]

data[, state_tax := ifelse(!(state %in% c('AK', 'TX', 'FL', 'NV', 'NH', 'SD', 'TN', 'TX', 'WA', 'WY')), 1, 0)]

r1 <- feols(retail_price_dispersion_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, data = data[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r1)
r2 <- feols(markup_retail_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths+ callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, data = data[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r2)
r3 <- feols(markup_institutional_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed |yrmonth + purp_broad, 
            data = data[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r3)


r4 <- feols(markup_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote  |group + year + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r4)
r5 <- feols(markup_retail_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + year  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r5)
r6 <- feols(markup_institutional_3yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
             ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + year  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r6)


table_call <- etable(r1, r2, r3,r4,r5,r6,
                     title = 'Transaction Costs and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     fontsize = 'small',
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(markup_1yr ='Markup',
                              markup_retail_1yr ='Retail Markup',
                              markup_institutional_1yr ='Institutional Markup',
                              city_go_vote = 'Vote',
                              high_articles_12_0 = 'I(Media Coverage - 12mo)',
                              ln_amount = 'Amount',
                              amount_quintile = "Amount Quintile",
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rated = 'Rated',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              unique_sources_12 = 'Num Sources',
                              rolling_sum = 'City News Coverage',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              state_go_vote = 'State GO Vote',
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
writeLines(modified_output, paste0(tables_wd, '/transaction_costs.tex'))



r1 <- feols(markup_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_num_trades_3yr +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, 
            data = data[as.Date(offering_date) < as.Date('2009-07-01' ) & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r1)
r2 <- feols(markup_retail_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths+ callable  + sinkable + insured + rated + log_num_trades_3yr +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, data = data[as.Date(offering_date) < as.Date('2009-07-01' )  & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r2)
r3 <- feols(markup_institutional_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_num_trades_3yr +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed |yrmonth + purp_broad , 
            data = data[as.Date(offering_date) < as.Date('2009-07-01' )  & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r3)

r4 <- feols(markup_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote  |group + year + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr) & as.Date(offering_date) < as.Date('2009-07-01' )], vcov = ~issue_id)
summary(r4)
r5 <- feols(markup_retail_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + year  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr) & as.Date(offering_date) < as.Date('2009-07-01' )], vcov = ~issue_id)
summary(r5)
r6 <- feols(markup_institutional_3yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + yrmonth  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr) & as.Date(offering_date) < as.Date('2009-07-01' )], vcov = ~issue_id)
summary(r6)


table_call <- etable(r1, r2, r3,r4,r5,r6,
                     title = 'Transaction Costs and Referendum Requirements (Pre-EMMA)',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     fontsize = 'small',
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(markup_1yr ='Markup',
                              markup_retail_1yr ='Retail Markup',
                              markup_institutional_1yr ='Institutional Markup',
                              city_go_vote = 'Vote',
                              high_articles_12_0 = 'I(Media Coverage - 12mo)',
                              ln_amount = 'Amount',
                              amount_quintile = "Amount Quintile",
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rated = 'Rated',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              unique_sources_12 = 'Num Sources',
                              rolling_sum = 'City News Coverage',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              state_go_vote = 'State GO Vote',
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
writeLines(modified_output, paste0(tables_wd, '/transaction_costs_pre_EMMA.tex'))

r1 <- feols(markup_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_num_trades_3yr +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, data = data[as.Date(offering_date) >= as.Date('2009-07-01' ) & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r1)
r2 <- feols(markup_retail_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths+ callable  + sinkable + insured + rated + log_num_trades_3yr +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, data = data[as.Date(offering_date) >= as.Date('2009-07-01' ) & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r2)
r3 <- feols(markup_institutional_3yr ~ city_go_vote  + ln_amount +ln_maturity_mths + callable  + sinkable + insured + rated + log_num_trades_3yr +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed |yrmonth + purp_broad, 
            data = data[as.Date(offering_date) >= as.Date('2009-07-01' )  & !is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r3)



r4 <- feols(markup_3yr ~ city_go_vote  + ln_amount +ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote  |group + yrmonth + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr) & as.Date(offering_date) >= as.Date('2009-07-01' )], vcov = ~issue_id)
summary(r4)
r5 <- feols(markup_retail_3yr ~ city_go_vote  + ln_amount +ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + yrmonth  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr) & as.Date(offering_date) >= as.Date('2009-07-01' )], vcov = ~issue_id)
summary(r5)
r6 <- feols(markup_institutional_3yr ~ city_go_vote + ln_amount +ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + yrmonth  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr) & as.Date(offering_date) >= as.Date('2009-07-01' )], vcov = ~issue_id)
summary(r6)

table_call <- etable(r1, r2, r3,r4,r5,r6,
                     title = 'Transaction Costs and Referendum Requirements (Pre-EMMA)',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     fontsize = 'small',
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(markup_1yr ='Markup',
                              markup_retail_1yr ='Retail Markup',
                              markup_institutional_1yr ='Institutional Markup',
                              city_go_vote = 'Vote',
                              high_articles_12_0 = 'I(Media Coverage - 12mo)',
                              ln_amount = 'Amount',
                              amount_quintile = "Amount Quintile",
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rated = 'Rated',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              unique_sources_12 = 'Num Sources',
                              rolling_sum = 'City News Coverage',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              state_go_vote = 'State GO Vote',
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
writeLines(modified_output, paste0(tables_wd, '/transaction_costs_post_EMMA.tex'))




r1 <- feols(markup_2_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|yrmonth + purp_broad, data = data[!is.na(markup_retail_2_3yr) & !is.na(markup_institutional_2_3yr)], vcov = ~issue_id)
summary(r1)
r2 <- feols(markup_retail_2_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths+ callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp|yrmonth + purp_broad, data = data[!is.na(markup_retail_2_3yr) & !is.na(markup_institutional_2_3yr)], vcov = ~issue_id)
summary(r2)
r3 <- feols(markup_institutional_2_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed |yrmonth + purp_broad, 
            data = data[!is.na(markup_retail_2_3yr) & !is.na(markup_institutional_2_3yr)], vcov = ~issue_id)
summary(r3)


r4 <- feols(markup_2_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote  |group + year + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r4)
r5 <- feols(markup_retail_2_3yr ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group + year  + purp_broad, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r5)
r6 <- feols(markup_institutional_2_3yr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote |group, data = border_states[!is.na(markup_retail_3yr) & !is.na(markup_institutional_3yr)], vcov = ~issue_id)
summary(r6)


