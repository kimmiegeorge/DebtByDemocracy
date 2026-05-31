rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"

data <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/Trade_Level_Regression_Dataset.csv')
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote) & !is.na(log_employment) & go_unlim == 1 & !is.na(callable)]
data[, markup := Winsorize(markup, val = quantile(markup, probs = c(0.01, 0.99)))]
data[, markup_markup := ifelse(trade_sign == 1, markup, NA)]
data[, markup_markdown := ifelse(trade_sign == -1, markup, NA)]
data[bond_age_years <0, bond_age_years := 0]

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
#border_states <- border_states[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts', 'Missouri/Tennessee', 'Missouri/Kentucky'))]
border_states <- border_states[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states <- unique(border_states[, .(seed_issuer_id,group)])
border_states <- data[border_states, on = .(seed_issuer_id)]

# filter to trades more than 30 days from offering date and less than 30 days to maturity 
#data <- data[as.integer(trade_date - offering_date) > 30]
data <- data[as.integer(trade_date - offering_date) > 30]
data <- data[as.integer(trade_date - offering_date) <= 365]
data <- data[time_to_maturity_years > 0.16]

border_states <- border_states[as.integer(trade_date - offering_date) > 30]
border_states <- border_states[as.integer(trade_date - offering_date) <= 365]
border_states <- border_states[time_to_maturity_years > 0.16]

# filter to bonds with every trade type 
data[, total := max(small_retail) + max(large_retail) + max(small_institutional) + max(large_institutional), .(cusip)]
#data <- data[total == 4]

border_states[, total := max(small_retail) + max(large_retail) + max(small_institutional) + max(large_institutional), .(cusip)]
#border_states <- border_states[total == 4]

#---------------------------------------

vars = c('markup', 'log_trade_size', 'log_daily_par_volume', 'bond_age_years', 'time_to_maturity_years', 'inventory_indicator')

all_desc = data.table()
for (var in vars){
  print(var)
  desc <- data[, list(Mean = mean(get(var)), 
                                                                                  SD = sd(get(var), na.rm = T), 
                                                                                  Min = min(get(var), na.rm = T),
                                                                                  p1 = quantile(get(var), 0.01, na.rm = T), 
                                                                                  Median = median(get(var), na.rm = T), 
                                                                                  p99 = quantile(get(var), 0.99, na.rm = T), 
                                                                                  Max = max(get(var), na.rm = T), 
                                                                                  N = .N[!is.na(get(var))])][1]
  desc <- round(desc, 2)
  all_desc <- rbind(all_desc, desc)
}

varnames = c('Markup', 'ln(Trade size)', 'ln(Volume)', 'Age', 'Time to maturity', 'Over 1 day in inventory')
varnames = data.table(varnames)
all_desc <- cbind(varnames, all_desc)


stargazer(all_desc, summary = F, no.space = T, rownames = F, 
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables/trade_desc.tex')




#---------------------------------------
data[, ym := paste0(year_fe, month_fe)]
border_states[, ym := paste0(year_fe, month_fe)]

data[, drop := uniqueN(city_go_vote), .(cusip)]

# tends to work without the state debt variables


r1a <- feols(markup ~ city_go_vote+ treasury_10yr +
              log_trade_size + log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator + ln_amount + ln_maturity_mths + rated + sinkable + insured + 
               callable + log_gdp + log_pop + log_pers_inc + log_employment + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad, data = data[trade_sign == 1], vcov = ~cusip + ym)
summary(r1a)

r1b <- feols(markup ~ city_go_vote+ treasury_10yr +
              log_trade_size + log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator + ln_amount + ln_maturity_mths + rated + sinkable + insured + 
               callable + log_gdp + log_pop + log_pers_inc + log_employment + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad, data = data[trade_sign == -1], vcov = ~cusip + ym)
summary(r1b)


r2a <- feols(markup ~ city_go_vote+ treasury_10yr +
              log_trade_size + log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator + ln_amount + ln_maturity_mths + rated + sinkable + insured + 
               callable + log_gdp + log_pop + log_pers_inc + log_employment + state_go_vote|year + purp_broad + group, data = border_states[trade_sign == 1], vcov = ~cusip + ym)
summary(r2a)

r2b <- feols(markup ~ city_go_vote+ treasury_10yr +
               log_trade_size + log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator + ln_amount + ln_maturity_mths + rated + sinkable + insured + callable 
             + log_gdp + log_pop + log_pers_inc + log_employment + state_go_vote|year + purp_broad + group, data = border_states[trade_sign == -1], vcov = ~cusip + ym)
summary(r2b)




table_call <- etable(r1a, r1b, r2a, r2b,
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
                     dict = c(markup ='Markup',
                              city_go_vote = 'Vote',
                              treasury_10yr = 'Treasury yield',
                              log_trade_size = 'ln(Trade size)',
                              log_daily_par_volume = 'ln(Volume)',
                              bond_age_years = 'Age',
                              time_to_maturity_years = 'Time to maturity',
                              inventory_indicator = 'Over 1 day in inventory', 
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rated = 'Rated',
                              log_gdp =  'County ln(GDP)', 
                              log_pop = 'County ln(Pop)' , 
                              log_pers_inc = 'County ln(Pers. Inc)', 
                              log_employment = 'County ln(Emp)', 
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
writeLines(modified_output, paste0(tables_wd, '/liquidity_options/trade_level_transaction_costs_5yr.tex'))





# delphine's paper is 30 days - maybe try offering vs. settlement date. around 36 days seems to work well 



r1a <- feols(markup ~ small_retail + small_retail:city_go_vote + large_retail + large_retail:city_go_vote  + small_institutional + 
               small_institutional:city_go_vote  + treasury_10yr  +  
               log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator +  log_gdp + log_pop + log_pers_inc + log_employment
             |year + cusip, data = data[trade_sign == 1 & total == 4], vcov = ~cusip + ym)
summary(r1a)

r1b <- feols(markup ~ small_retail + small_retail:city_go_vote + large_retail + large_retail:city_go_vote  + small_institutional + 
               small_institutional:city_go_vote  +  log_daily_par_volume + 
               bond_age_years + time_to_maturity_years + inventory_indicator +  
               log_gdp + log_pop + log_pers_inc + log_employment|year + cusip, data = data[trade_sign == -1], vcov = ~cusip + ym)
summary(r1b)


r2a <- feols(markup ~ small_retail + small_retail:city_go_vote + large_retail + large_retail:city_go_vote  + small_institutional + 
               small_institutional:city_go_vote   + log_trade_size + log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator + ln_amount + ln_maturity_mths + rated + sinkable + insured + 
               callable + log_gdp + log_pop + log_pers_inc + log_employment|year + cusip + group, data = border_states[trade_sign == 1], vcov = ~cusip + ym)
summary(r2a)


r2b <- feols(markup ~ small_retail + small_retail:city_go_vote + large_retail + large_retail:city_go_vote  + small_institutional + 
               small_institutional:city_go_vote   + log_trade_size + log_daily_par_volume + bond_age_years + time_to_maturity_years + inventory_indicator + ln_amount + ln_maturity_mths + rated + sinkable + insured + 
               callable + log_gdp + log_pop + log_pers_inc + log_employment|year + cusip + group, data = border_states[trade_sign == -1], vcov = ~cusip + ym)
summary(r2b)





table_call <- etable(r1a, r1b, r2a, r2b,
                     title = 'Transaction Costs by Trade Type and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     fontsize = 'small',
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep = c('%city_go_vote:small_retail', '%city_go_vote:large_retail', '%city_go_vote:small_institutional', '%small_retail', '%large_retail', '%small_institutional'),
                     dict = c(markup ='Markup',
                              city_go_vote = 'Vote',
                              treasury_10yr = 'Treasury yield',
                              log_trade_size = 'ln(Trade size)',
                              log_daily_par_volume = 'ln(Volume)',
                              bond_age_years = 'Age',
                              time_to_maturity_years = 'Time to maturity',
                              inventory_indicator = 'Over 1 day in inventory', 
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              small_retail = 'SmRet',
                              large_retail = 'LgRet',
                              small_institutional = 'SmInst',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rated = 'Rated',
                              log_gdp =  'County ln(GDP)', 
                              log_pop = 'County ln(Pop)' , 
                              log_pers_inc = 'County ln(Pers. Inc)', 
                              log_emp = 'County ln(Emp)', 
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
                              cusip = 'Bond',
                              issue_id = 'Issue'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/bond_yields.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tables_wd, '/trade_level_transaction_costs_by_type.tex'))

