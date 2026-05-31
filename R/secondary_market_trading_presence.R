library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables/"


data <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/liquidity_1yr.csv')
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
data[, secondary_trade := ifelse(number_of_trades_3yr > 0, 1, 0)]
data[, year := year(offering_date)]
data[, ym := as.yearmon(offering_date)]

data[, log_trades := log(1+number_of_trades_3yr)]
data[, log_amount := log(1+total_par_traded_3yr)]

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states <- border_states[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states <- unique(border_states[, .(seed_issuer_id,group)])
border_states <- data[border_states, on = .(seed_issuer_id)]
border_states <- border_states[!is.na(cusip)]


r0 <- feols(secondary_trade ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data[year >=2005], vcov = ~issue_id)
summary(r0)
r1 <- feols(secondary_trade ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment +  state_go_vote + glm_proactive + state_ltgo_allowed |year + purp_broad, data = data[year >=2005], vcov = ~issue_id)
summary(r1)
r2 <- feols(log_amount ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data[year >= 2005], vcov = ~issue_id )
summary(r2)
r3 <- feols(log_amount ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment  + state_go_vote + glm_proactive + state_ltgo_allowed |year + purp_broad, data = data[year >= 2005], vcov = ~issue_id )
summary(r3)

r0b <- feols(secondary_trade ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment   |year + purp_broad, data = border_states[year >= 2005], vcov = ~issue_id )
summary(r0b)
r1b <- feols(secondary_trade ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment  + state_go_vote   |year + purp_broad + group, data = border_states[year >= 2005], vcov = ~issue_id )
summary(r1b)
r2b <- feols(log_amount ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment    |year + purp_broad + group, data = border_states[year >= 2005], vcov = ~issue_id)
summary(r2b)
r3b <- feols(log_amount ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment + state_go_vote   |year + purp_broad + group, data = border_states[year >= 2005], vcov = ~issue_id)
summary(r3b)



table_call <- etable(r0, r1, r2, r3, r0b, r1b,r2b, r3b,
                     title = 'Secondary Market Trading and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     fontsize = 'small',
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(secondary_trade ='I(Secondary Market Trade)',
                              log_amount = 'Par Value Traded',
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
writeLines(modified_output, paste0(tables_wd, '/liquidity_options/bond_level_trade_activity_18mo.tex'))



