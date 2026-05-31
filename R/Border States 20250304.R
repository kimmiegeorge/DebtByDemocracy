#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_border_states"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data 20250306.csv')
data[, yearq := as.yearqtr(offering_date)]
data <- data[!is.na(pop)]

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|seed_issuer_id, data = data[go_unlim ==1])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[go_unlim ==1])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[go_unlim ==1])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[go_unlim == 1])

stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities Offering Yields',
          dep.var.labels = c('Offering Yield'),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO Debt Limit", "Lim Tax GO Allowed", "Full Faith Pledge", "Debt-Service Prop Tax", "Fund for Pledged Prop Tax", "Statutory Lien on Pledged Prop Tax",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year-Month FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "Yes", "Yes")),
          out = paste0(tables_wd, '/Border States All Pairings Only GO Unlimited.tex'))

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|seed_issuer_id, data = data[rev ==0])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[rev == 0])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[rev ==0])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[rev == 0])

stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities Offering Yields (All GO)',
          dep.var.labels = c('Offering Yield'),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO Debt Limit", "Lim Tax GO Allowed", "Full Faith Pledge", "Debt-Service Prop Tax", "Fund for Pledged Prop Tax", "Statutory Lien on Pledged Prop Tax",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year-Month FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "Yes", "Yes")),
          out = paste0(tables_wd, '/Border States All Pairings All GO.tex'))




reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|seed_issuer_id, data = data[go_unlim == 1 & category != 'green'])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[go_unlim == 1 & category != 'green'])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[go_unlim == 1 & category != 'green'])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[go_unlim == 1 & category != 'green'])

stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities Offering Yields',
          dep.var.labels = c('Offering Yield'),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO Debt Limit", "Lim Tax GO Allowed", "Full Faith Pledge", "Debt-Service Prop Tax", "Fund for Pledged Prop Tax", "Statutory Lien on Pledged Prop Tax",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year-Month FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "Yes", "Yes")),
          out = paste0(tables_wd, '/Border States Drop Green.tex'))

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|seed_issuer_id, data = data[rev == 0 & category != 'green'])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[rev == 0  & category != 'green'])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[rev == 0  & category != 'green'])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + purp_broad|0|seed_issuer_id, data = data[rev == 0  & category != 'green'])

stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities Offering Yields All GO (Drop Green State Pairings)',
          dep.var.labels = c('Offering Yield'),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO Debt Limit", "Lim Tax GO Allowed", "Full Faith Pledge", "Debt-Service Prop Tax", "Fund for Pledged Prop Tax", "Statutory Lien on Pledged Prop Tax",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year-Month FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "Yes", "Yes")),
          out = paste0(tables_wd, '/Border States Drop Green All GO.tex'))





# output pairings
pairings <-data[, list(Bonds = .N), .(group)]
colnames(pairings) <- c('State-Pairs', 'Bonds')
stargazer(pairings, summary = F, rownames = F, type = 'latex', table.placement = 'H', header = FALSE,
          no.space = T, column.sep.width = '-5pt', title = 'Border States', out= paste0(tables_wd, '/List Border States.tex'))


#---------------------------------------
desc <- data[!is.na(pop) & !is.na(offering_yield_tr), .(city_go_vote, offering_yield_tr, ln_amount, ln_maturity, callable, sinkable, insured, rated, 
                 state_godebt_limit, state_ltgo_allowed, state_fullfaith, state_statutorylien, state_sep_pledgerev, state_sep_debtservice_levy, 
                 ln_gdp, ln_emp, ln_percap_inc, ln_pers_inc)]

stargazer(desc, min.max = T, median = T, iqr = T, type = 'latex', no.space = T, header = T, title = 'Border Cities Sample Statistics', 
          covariate.labels = c("City GO Vote", 'Offering Yield', "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO Debt Limit", "Lim Tax GO Allowed", "Full Faith Pledge", "Debt-Service Prop Tax", "Fund for Pledged Prop Tax", "Statutory Lien on Pledged Prop Tax",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          out = paste0(tables_wd, '/Border States Desc.tex'))


#---------------------------------------
# articles
issuance_lvl <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl 20250306.csv')

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
issuance_lvl = issuance_lvl[!is.na(city_go_vote)]
issuance_lvl[, ym := paste0(year, month)]
issuance_lvl[, issuance_month_total_articles := log(1+issuance_month_total_articles)]
issuance_lvl[, total_rp_articles_6mo_window_event := log(1+total_rp_articles_6mo_window_event)]

issuance_lvl[, num_groups := n_distinct(group), .(seed_issuer_id)]
issuance_lvl[, is_dup := ifelse(num_groups > 1, 1, 0)]


reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|seed_issuer_id, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[go_unlim_bond_issuance == 1])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|seed_issuer_id, data = issuance_lvl[go_unlim_bond_issuance == 1])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage (Only GO Unlimited Bonds)',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Only GO Unlimited.tex'))


reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage (All GO Bonds)',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles All GO Bonds.tex'))



reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0 & category != 'green'])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0 & category != 'green'])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0 & category != 'green'])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0 & category != 'green'])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage (All GO Bonds, Drop Green Pairings)',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Green Drop All GO.tex'))




