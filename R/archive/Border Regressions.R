library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich)
tables_wd <- "/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2502_border_states"

data <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data 20250227.csv')
data <- data[!is.na(pop)]

issuer_groups <- unique(data[, .(seed_issuer_id, group)])
issuer_groups[, .N, .(group)]
issuer_groups_nodup <- unique(issuer_groups, by = 'seed_issuer_id')

### investigate duplicates 
data[, num_groups := n_distinct(group), .(seed_issuer_id)]
data[, is_dup := ifelse(num_groups > 1, 1, 0)]

counts = data[, list(count = .N), .(group)]
counts_no_dup = data[is_dup == 0, list(counts_no_dup = .N), .(group)]
counts_all <- counts_no_dup[counts, on = .(group)]

stargazer(counts_all, type = 'latex', summary = F, table.placement = 'H', no.space = T, header = F, rownames = F, out = paste0(tables_wd, '/Counts by Pairing.tex'))
dropped_pairings <- c('Ohio/Indiana', 'West Virginia/Kentucky', 'Tennesse/Missouri')

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|seed_issuer_id, data = data[rev == 0])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|seed_issuer_id + yrmonth, data = data[rev == 0])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|seed_issuer_id, data = data[rev == 0])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
              state_godebt_limit  + state_ltgo_allowed +state_fullfaith + state_statutorylien + state_sep_pledgerev + state_sep_debtservice_levy +
              ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|seed_issuer_id, data = data[rev == 0])

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
          out = paste0(tables_wd, '/Border States Offering Yield Drop Dark Blue.tex'))


reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|0, data = data[category != 'green'])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[category != 'dark blue' & category != 'green'])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[category != 'dark blue' & category != 'green'])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit  + state_ltgo_allowed +state_fullfaith + state_statutorylien + state_sep_pledgerev + state_sep_debtservice_levy +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|seed_issuer_id, data = data[category ])

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
          out = paste0(tables_wd, '/Border States Offering Yield Drop Dark Blue.tex'))


reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|0, data = data)
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data)
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data)
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data)

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
          out = paste0(tables_wd, '/Border States Offering Yield Keep Dark Blue.tex'))

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|0, data = data[rev == 0])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[rev == 0])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[rev == 0])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit  + state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[rev == 0])

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
          out = paste0(tables_wd, '/Border States Offering Yield Keep Dark Blue Remove Revenue Bonds.tex'))



reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|0, data = data[is_dup == 0])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[is_dup == 0])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[is_dup == 0])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit  + state_ltgo_allowed +state_fullfaith + state_statutorylien + state_sep_pledgerev + state_sep_debtservice_levy +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[is_dup == 0])

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
          out = paste0(tables_wd, '/Border States Offering Yield Drop Dups.tex'))

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|0, data = data[is_dup == 0 & rev == 0])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[is_dup == 0 & rev == 0])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[is_dup == 0 & rev == 0])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit  + state_ltgo_allowed +state_fullfaith + state_statutorylien + state_sep_pledgerev + state_sep_debtservice_levy +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[is_dup == 0 & rev == 0])

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
          out = paste0(tables_wd, '/Border States Offering Yield Drop Dups and Rev.tex'))

reg1 <- felm(offering_yield_tr ~ city_go_vote|yrmonth + group|0|0, data = data[!(group %in% dropped_pairings)])
reg2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[!(group %in% dropped_pairings)])
reg3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[!(group %in% dropped_pairings)])
reg4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity + callable  + sinkable + insured + rated + 
               state_godebt_limit  + state_ltgo_allowed +state_fullfaith + state_statutorylien + state_sep_pledgerev + state_sep_debtservice_levy +
               ln_gdp + ln_emp + ln_percap_inc + ln_pers_inc|yrmonth + group + use_proceeds|0|issue_id + yrmonth, data = data[!(group %in% dropped_pairings)])

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
          out = paste0(tables_wd, '/Border States Offering Yield Drop Specific Pairings.tex'))



      


full_data <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP City Month Lvl 20250227.csv')

full_data[, rp_article_count := log(1+rp_article_count)]
full_data = full_data[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
full_data[, year_month := paste0(year, '_', month)]
full_data = full_data[!is.na(city_go_vote)]

reg1 <- felm(rp_article_count ~ bond_issuance_month + bond_issuance_month:city_go_vote|year_month + seed_issuer_id|0|seed_issuer_id + year_month, data = full_data)
reg2  <- felm(rp_article_count ~ bond_issuance_next_6mth|year_month|0|seed_issuer_id + year_month, data = full_data)
reg3  <- felm(rp_article_count ~ bond_issuance_next_12mth|year_month|0|seed_issuer_id + year_month, data = full_data)

reg1a <- felm(rp_article_count ~ bond_issuance_month + bond_issuance_month:city_go_vote|year + seed_issuer_id|0|seed_issuer_id, data = full_data)
reg2a  <- felm(rp_article_count ~ bond_issuance_next_6mth*city_go_vote|year_month|0|seed_issuer_id + year_month, data = full_data)
reg3a  <- felm(rp_article_count ~ bond_issuance_next_12mth*city_go_vote|year_month|0|seed_issuer_id + year_month, data = full_data)

reg1b <- felm(rp_article_count ~ bond_issuance_month + bond_issuance_month:city_go_vote + bond_issuance_month:ln_bond_amount_current_month  +  ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp |seed_issuer_id + year_month|0|year_month + seed_issuer_id, data = full_data)
reg2b  <- felm(rp_article_count ~ bond_issuance_next_6mth:city_go_vote +  bond_issuance_next_6mth:ln_bond_amount_next_6mth +  ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp|year_month + seed_issuer_id|0|year_month + seed_issuer_id, data = full_data)
reg3b  <- felm(rp_article_count ~ bond_issuance_next_12mth*city_go_vote + ln_employment + ln_percap_inc + ln_pers_inc + ln_pop + ln_gdp|year_month +|0|year_month + seed_issuer_id, data = full_data)

issuance_lvl <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl 20250227.csv')

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
issuance_lvl = issuance_lvl[!is.na(city_go_vote)]
issuance_lvl[, abnormal_rp_article_count_6mo := ifelse(is.infinite(abnormal_rp_article_count_6mo), NA, abnormal_rp_article_count_6mo)]
issuance_lvl[, abnormal_rp_article_count_issuance_month := ifelse(is.infinite(abnormal_rp_article_count_issuance_month), NA, abnormal_rp_article_count_issuance_month)]
issuance_lvl[, ym := paste0(year, month)]
issuance_lvl[, issuance_month_total_articles := log(1+issuance_month_total_articles)]
issuance_lvl[, total_rp_articles_6mo_window_event := log(1+total_rp_articles_6mo_window_event)]

issuance_lvl[, num_groups := n_distinct(group), .(seed_issuer_id)]
issuance_lvl[, is_dup := ifelse(num_groups > 1, 1, 0)]


reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl)
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl)
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl)
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl)



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Keep Dark Blue.tex'))



reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[category != 'dark blue'])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[category != 'dark blue'])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[category != 'dark blue'])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[category != 'dark blue'])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Remove Dark Blue.tex'))


reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[rev_bond_issuance == 0])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Keep Dark Blue Remove Revenue Bonds.tex'))



reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[is_dup == 0])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[is_dup == 0])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[is_dup == 0])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[is_dup == 0])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Remove Dups.tex'))



reg1 <- felm(issuance_month_total_articles ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[is_dup == 0 & rev_bond_issuance == 0])
reg2 <- felm(issuance_month_total_articles ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[is_dup == 0 & rev_bond_issuance == 0])
reg3 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote|year + group|0|seed_issuer_id, data = issuance_lvl[is_dup == 0 & rev_bond_issuance == 0])
reg4 <- felm(total_rp_articles_6mo_window_event ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + use_proceeds|0|seed_issuer_id, data = issuance_lvl[is_dup == 0 & rev_bond_issuance == 0])



stargazer(reg1, reg2, reg3, reg4, 
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          column.sep.width = '-5pt',
          title = 'Border Cities News Coverage',
          dep.var.caption = 'ln(Total Articles)',
          dep.var.labels = c('Issuance Month', '6 Months Prior'),
          covariate.labels = c("City GO Vote", "ln(Size)",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes"), 
                           c("Bond Purpose FE", "No","Yes", "No", "Yes")),
          out = paste0(tables_wd, '/Border States Articles Remove Dups and Rev Bonds.tex'))




# output pairings
pairings <- unique(issuance_lvl[, .(group, category)])
stargazer(pairings, summary = F, rownames = F, type = 'latex', table.placement = 'H', header = FALSE,
          no.space = T, column.sep.width = '-5pt', title = 'Border States', out= paste0(tables_wd, '/List Border States.tex'))
