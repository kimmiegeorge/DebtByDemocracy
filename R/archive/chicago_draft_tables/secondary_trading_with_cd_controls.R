rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables/"

#----------------------------------
# ONE YEAR 
#----------------------------------

data_1yr <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/liquidity_1yr.csv')
data_1yr[state == 'MO', city_rev_vote := 1]
data_1yr[state == 'RI', city_go_vote := NA]
data_1yr <- data_1yr[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
data_1yr[, secondary_trade := ifelse(number_of_trades_3yr > 0, 1, 0)]
data_1yr[, year := year(offering_date)]
data_1yr[, ym := as.yearmon(offering_date)]

data_1yr[, log_trades := log(1+number_of_trades_3yr)]
data_1yr[, log_amount := log(1+total_par_traded_3yr)]

# add continuing disclosure variables 
cd <- fread('~/Dropbox/Voting on Bonds/Data/Continuing Disclosure/Processed/issue_level_with_cd_vars_20251201.csv')
cd <- cd[, .(issue_id, num_financial_operating_data_disclosure_within_1_year,
             num_disclosures_within_1_year)]
cd[, num_financial_operating_data_disclosure_within_1_year := log(1+num_financial_operating_data_disclosure_within_1_year)]
cd[, num_disclosures_within_1_year := log(1+num_disclosures_within_1_year)]
data_1yr <- cd[data_1yr, on = .(issue_id)]

border_states_1yr <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states_1yr <- border_states_1yr[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states_1yr <- unique(border_states_1yr[, .(seed_issuer_id,group)])
border_states_1yr <- data_1yr[border_states_1yr, on = .(seed_issuer_id)]
border_states_1yr <- border_states_1yr[!is.na(cusip)]


#----------------------------------
# THREE YEAR 
#----------------------------------

data_3yr <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/liquidity_3yr.csv')
data_3yr[state == 'MO', city_rev_vote := 1]
data_3yr[state == 'RI', city_go_vote := NA]
data_3yr <- data_3yr[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
data_3yr[, secondary_trade := ifelse(number_of_trades_3yr > 0, 1, 0)]
data_3yr[, year := year(offering_date)]
data_3yr[, ym := as.yearmon(offering_date)]

data_3yr[, log_trades := log(1+number_of_trades_3yr)]
data_3yr[, log_amount := log(1+total_par_traded_3yr)]

# add continuing disclosure variables 
cd <- fread('~/Dropbox/Voting on Bonds/Data/Continuing Disclosure/Processed/issue_level_with_cd_vars_20251201.csv')
cd <- cd[, .(issue_id, num_financial_operating_data_disclosure_within_3_year,
             num_disclosures_within_3_years)]
cd[, num_financial_operating_data_disclosure_within_3_year := log(1+num_financial_operating_data_disclosure_within_3_year)]
cd[, num_disclosures_within_3_years := log(1+num_disclosures_within_3_years)]
data_3yr <- cd[data_3yr, on = .(issue_id)]

border_states_3yr <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states_3yr <- border_states_3yr[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states_3yr <- unique(border_states_3yr[, .(seed_issuer_id,group)])
border_states_3yr <- data_3yr[border_states_3yr, on = .(seed_issuer_id)]
border_states_3yr <- border_states_3yr[!is.na(cusip)]



#----------------------------------
# FIVE YEAR 
#----------------------------------

data_5yr <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/liquidity_5yr.csv')
data_5yr[state == 'MO', city_rev_vote := 1]
data_5yr[state == 'RI', city_go_vote := NA]
data_5yr <- data_5yr[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
data_5yr[, secondary_trade := ifelse(number_of_trades_3yr > 0, 1, 0)]
data_5yr[, year := year(offering_date)]
data_5yr[, ym := as.yearmon(offering_date)]

data_5yr[, log_trades := log(1+number_of_trades_3yr)]
data_5yr[, log_amount := log(1+total_par_traded_3yr)]

# add continuing disclosure variables 
cd <- fread('~/Dropbox/Voting on Bonds/Data/Continuing Disclosure/Processed/issue_level_with_cd_vars_20251201.csv')
cd <- cd[, .(issue_id, num_financial_operating_data_disclosure_within_5_year,
             num_disclosures_within_5_years)]
cd[, num_financial_operating_data_disclosure_within_5_year := log(1+num_financial_operating_data_disclosure_within_5_year)]
cd[, num_disclosures_within_5_years := log(1+num_disclosures_within_5_years)]
data_5yr <- cd[data_5yr, on = .(issue_id)]

border_states_5yr <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states_5yr <- border_states_5yr[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states_5yr <- unique(border_states_5yr[, .(seed_issuer_id,group)])
border_states_5yr <- data_5yr[border_states_5yr, on = .(seed_issuer_id)]
border_states_5yr <- border_states_5yr[!is.na(cusip)]



#----------------------------------
# ALL YEAR 
#----------------------------------

data_allyr <- fread('~/Dropbox/Voting on Bonds/Data/MSRB/Processed/liquidity_allyr.csv')
data_allyr[state == 'MO', city_rev_vote := 1]
data_allyr[state == 'RI', city_go_vote := NA]
data_allyr <- data_allyr[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
data_allyr[, secondary_trade := ifelse(number_of_trades_3yr > 0, 1, 0)]
data_allyr[, year := year(offering_date)]
data_allyr[, ym := as.yearmon(offering_date)]

data_allyr[, log_trades := log(1+number_of_trades_3yr)]
data_allyr[, log_amount := log(1+total_par_traded_3yr)]

# add continuing disclosure variables 
cd <- fread('~/Dropbox/Voting on Bonds/Data/Continuing Disclosure/Processed/issue_level_with_cd_vars_20251201.csv')
cd <- cd[, .(issue_id, num_financial_operating_data_disclosure_full_msrb,
             num_disclosures_full_msrb)]
cd[, num_financial_operating_data_disclosure_full_msrb := log(1+num_financial_operating_data_disclosure_full_msrb)]
cd[, num_disclosures_full_msrb := log(1+num_disclosures_full_msrb)]
data_allyr <- cd[data_allyr, on = .(issue_id)]


border_states_allyr <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_states_allyr <- border_states_allyr[go_unlim == 1 & !(group %in% c('Rhode Island/Massachusetts'))]
#border_states <- Wins(border_states, col_list)
border_states_allyr <- unique(border_states_allyr[, .(seed_issuer_id,group)])
border_states_allyr <- data_allyr[border_states_allyr, on = .(seed_issuer_id)]
border_states_allyr <- border_states_allyr[!is.na(cusip)]


#----------------------------------
# FULL SAMPLE
#----------------------------------

r1 <- feols(secondary_trade ~ city_go_vote + num_disclosures_within_1_year + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_1yr[year >=2009], vcov = ~issue_id)
summary(r1)
r2 <- feols(log_amount ~ city_go_vote + num_disclosures_within_1_year + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_1yr[year >= 2009], vcov = ~issue_id )
summary(r2)

r3 <- feols(secondary_trade ~ city_go_vote + num_disclosures_within_3_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_3yr[year >=2009], vcov = ~issue_id)
summary(r3)
r4 <- feols(log_amount ~ city_go_vote + num_disclosures_within_3_years + ln_amount  + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_3yr[year >= 2009], vcov = ~issue_id )
summary(r4)

r5 <- feols(secondary_trade ~ city_go_vote + num_disclosures_within_5_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_5yr[year >=2009], vcov = ~issue_id)
summary(r5)
r6 <- feols(log_amount ~ city_go_vote + num_disclosures_within_5_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_5yr[year >= 2009], vcov = ~issue_id )
summary(r6)

r7 <- feols(secondary_trade ~ city_go_vote + num_disclosures_full_msrb + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_allyr[year >=2009], vcov = ~issue_id)
summary(r7)
r8 <- feols(log_amount ~ city_go_vote + num_disclosures_full_msrb +  ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad, data = data_allyr[year >= 2009], vcov = ~issue_id )
summary(r8)



table_call <- etable(r1, r2, r3, r4, r5, r6, r7, r8,
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
                     dict = c(secondary_trade ='I(Trade)',
                              city_go_vote = 'Vote',
                              num_disclosures_within_1_year = 'Disclosures (1yr)',
                              num_disclosures_within_3_years = 'Disclosures (3yr)',
                              num_disclosures_within_5_years = 'Disclosures (5yr)',
                              num_disclosures_full_msrb = 'Disclosures (All yr)',
                              log_amount = 'Par Val. Vol.',
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
writeLines(modified_output, paste0(tables_wd, '/liquidity_options/cd_control_full_sample_bond_level_trade_activity_time_horizons.tex'))


#----------------------------------
# BORDER STATE SAMPLE
#----------------------------------

r1 <- feols(secondary_trade ~ city_go_vote + num_disclosures_within_1_year + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_1yr[year >=2009], vcov = ~issue_id)
summary(r1)
r2 <- feols(log_amount ~ city_go_vote + num_disclosures_within_1_year + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_1yr[year >= 2009], vcov = ~issue_id )
summary(r2)

r3 <- feols(secondary_trade ~ city_go_vote + num_disclosures_within_3_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_3yr[year >=2009], vcov = ~issue_id)
summary(r3)
r4 <- feols(log_amount ~ city_go_vote + num_disclosures_within_3_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_3yr[year >= 2009], vcov = ~issue_id )
summary(r4)

r5 <- feols(secondary_trade ~ city_go_vote + num_disclosures_within_5_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_5yr[year >=2009], vcov = ~issue_id)
summary(r5)
r6 <- feols(log_amount ~ city_go_vote + num_disclosures_within_5_years + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_5yr[year >= 2009], vcov = ~issue_id )
summary(r6)


r7 <- feols(secondary_trade ~ city_go_vote + num_disclosures_full_msrb + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_allyr[year >=2009], vcov = ~issue_id)
summary(r7)
r8 <- feols(log_amount ~ city_go_vote + num_disclosures_full_msrb + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + log_pop + log_gdp + log_pers_inc + log_employment|year + purp_broad + group, data = border_states_allyr[year >= 2009], vcov = ~issue_id )
summary(r8)



table_call <- etable(r1, r2, r3, r4, r5, r6, r7, r8,
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
                     dict = c(secondary_trade ='I(Trade)',
                              city_go_vote = 'Vote',
                              num_disclosures_within_1_year = 'Disclosures (1yr)',
                              num_disclosures_within_3_years = 'Disclosures (3yr)',
                              num_disclosures_within_5_years = 'Disclosures (5yr)',
                              num_disclosures_full_msrb = 'Disclosures (All yr)',
                              log_amount = 'Par Val. Vol.',
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
writeLines(modified_output, paste0(tables_wd, '/liquidity_options/cd_control_border_state_bond_level_trade_activity_time_horizons.tex'))



