#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_border_states"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data 20250314.csv')
data[, yearq := as.yearqtr(offering_date)]
data[, qtr := substr(yearq, 6,7)]
data <- data[!is.na(pop)]
data[, yrmonth := format(offering_date, '%Y%m')]
data[, month := format(offering_date, '%m')]


# articles
issuance_lvl <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl 20250312.csv')
issuance_lvl = as.data.table(issuance_lvl)
setnames(issuance_lvl, 'total_rp_articles_6_2', 'total_rp_articles_6_1')
setnames(issuance_lvl, 'total_rp_articles_12_10', 'total_rp_articles_12_0')

issuance_lvl = issuance_lvl[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
issuance_lvl = issuance_lvl[!is.na(city_go_vote)]

issuance_lvl[, issuance_month_total_articles_raw := issuance_month_total_articles]
issuance_lvl[, issuance_month_total_articles := log(1 + issuance_month_total_articles)]
issuance_lvl[, total_rp_articles_1_1_raw := total_rp_articles_1_1]
issuance_lvl[, total_rp_articles_1_1 := log(1+total_rp_articles_1_1)]
issuance_lvl[, total_rp_articles_1_0_raw := total_rp_articles_1_0]
issuance_lvl[, total_rp_articles_1_0 := log(1+total_rp_articles_1_0)]
issuance_lvl[, total_rp_articles_6_0_raw := total_rp_articles_6_0]
issuance_lvl[, total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
issuance_lvl[, total_rp_articles_6_1_raw := total_rp_articles_6_1]
issuance_lvl[, total_rp_articles_6_1 := log(1+total_rp_articles_6_1)]
issuance_lvl[, total_rp_articles_12_0_raw := total_rp_articles_12_0]
issuance_lvl[, total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]

issuance_lvl[, rolling_sum_monthly_article_count_6 := log(1+rolling_sum_monthly_article_count_6)]
issuance_lvl[, rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]

# quarter 
issuance_lvl[, quarter := ifelse(month %in% c(1,2,3), 1, 
                                 ifelse(month %in% c(4,5,6), 2, 
                                        ifelse(month %in% c(7,8,9), 3, 4)))]
issuance_lvl[, yq := paste0(year, quarter)]

issuance_lvl[, ym := paste0(year, month)]


issuance_lvl[, unique_sources_6_raw := unique_sources_6]
issuance_lvl[, unique_sources_6 := log(1+unique_sources_6)]

issuance_lvl[, unique_sources_12_raw := unique_sources_12]
issuance_lvl[, unique_sources_12 := log(1+unique_sources_12)]
issuance_lvl <- issuance_lvl[category != 'green']

#---------------------------------------
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250313_citycountyschool_cusiplevel_statereq_purpose.dta')
full_data <- as.data.table(full_data)
full_data <- full_data[city == 1 &!is.na(city_go_vote) & city_rev_vote == 0]
full_data <- full_data[go_unlim == 1]
# drop school boards
full_data[, school_adj := grepl('BRD ED',issuer_long_name )]
full_data[, school_adj := ifelse(school_adj == 1 & state == 'NJ', 1, 0)]
full_data <- full_data[school_adj == 0]
full_data <- full_data[state != 'HI']
#---------------------------------------
# REGS - FULL SAMPLE

# just show state cluster and issue cluster and don't tabulate controls 

data <- data[go_unlim == 1 & category != 'green']
data[, state_year := paste0(state, year) ]
#data[, mean_debt := (state_godebt_limit + state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien)/5]
r1 <- felm(offering_yield_tr ~ city_go_vote + ln_amount_tr + ln_maturity_tr + callable  + sinkable + insured + rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |0|0|state, data = full_data, psdef = F)
r2 <- felm(offering_yield_tr ~ city_go_vote + ln_amount_tr + ln_maturity_tr + callable  + sinkable + insured + rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |yrmonth + purp_broad|0|state, data = full_data, psdef = F)
r3 <- felm(offering_yield_tr ~ city_go_vote + ln_amount_tr + ln_maturity_tr + callable  + sinkable + insured + rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |yrmonth + purp_broad|0|issue_id, data = full_data, psdef = F)
r4 <- felm(offering_yield_tr ~ city_go_vote + ln_amount_tr + ln_maturity_tr + callable  + sinkable + insured + rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |group|0|state, data = data, psdef = F)
r5 <- felm(offering_yield_tr ~ city_go_vote + ln_amount_tr + ln_maturity_tr + callable  + sinkable + insured + rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |yrmonth+ group + purp_broad|0|state, data = data, psdef = F)
r6 <- felm(offering_yield_tr ~ city_go_vote + ln_amount_tr + ln_maturity_tr + callable  + sinkable + insured + rated + 
             state_go_vote + state_ltgo_allowed  + state_sep_debtservice_levy   +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |yrmonth+ group + purp_broad|0|issue_id, data = data, psdef = F)

summary(r6)


stargazer(r1, r2, r3, r4, r5, r6,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Border States Offering Yields',
          dep.var.caption = "",
          dep.var.labels = c('Yield'),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Time FE", "No", "YM", "YM", "No", "YM", "YM"),
                           c("Purpose FE", "No", "Yes", "Yes", "No", "Yes", "Yes"),
                           c("State-Pair FE", "No", "No", "No", "Yes", "Yes", "Yes"),
                           c("Cluster", "State", "State", "Issue", "State", "State", "Issue")),
          out = paste0(tables_wd, '/Border States Yields FINAL All 6 Col.tex'))

data <- data[go_unlim == 1 & category != 'green']
r1 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated|yrmonth+ group + purp_broad|0|state, data = data, psdef = F)
r2 <- felm(offering_yield  ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |yrmonth+ group + purp_broad|0|state, data = data, psdef = F)
r3 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |yrmonth+ group + purp_broad|0|state, data = data, psdef = F)
r4 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             state_godebt_limit + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp |yrmonth+ group + purp_broad|0|issue_id, data = data, psdef = F)




stargazer(r1,r2,r3,r4,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Border States Offering Yields',
          dep.var.caption = "",
          dep.var.labels = c('Offering Yield (Trimmed)'),
          covariate.labels = c("City GO Vote", "Size", "Maturity", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "County GDP", "County Emp", "County Percap Inc", "County Pers. Inc"),
          add.lines = list(c("Time FE", "YM", "YM", "YM", "YM"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "State", "State", "State", "Issue")),
          out = paste0(tables_wd, '/Border States Yields FINAL.tex'))


# output pairings
pairings <-data[category != 'green' & go_unlim == 1, list(Bonds = .N), .(group)]
colnames(pairings) <- c('State-Pairs', 'Bonds')
stargazer(pairings, summary = F, rownames = F, type = 'latex', table.placement = 'H', header = FALSE,
          no.space = T, column.sep.width = '-5pt', title = 'Border States', out= paste0(tables_wd, '/List Border States.tex'))


#---------------------------------------
desc <- data[!is.na(pop) & !is.na(offering_yield_tr) & category != 'green' & go_unlim == 1, .(city_go_vote, offering_yield_tr, ln_amount, ln_maturity, callable, sinkable, insured, rated, 
                 state_godebt_limit, state_ltgo_allowed, state_fullfaith, state_statutorylien, state_sep_pledgerev, state_sep_debtservice_levy, 
                 ln_gdp, ln_emp, ln_percap_inc, ln_pers_inc)]

stargazer(desc, min.max = T, median = T, iqr = T, type = 'latex', no.space = T, header = T, title = 'Border Cities Sample Statistics', 
          covariate.labels = c("City GO Vote", 'Offering Yield', "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO Debt Limit", "Lim Tax GO Allowed", "Full Faith Pledge", "Debt-Service Prop Tax", "Fund for Pledged Prop Tax", "Statutory Lien on Pledged Prop Tax",
                               "Lag County ln(GDP)", "Lag County ln(Emp)", "Lag County ln(Percap Inc)", "Lag County ln(Pers. Inc)"),
          out = paste0(tables_wd, '/Border States Desc.tex'))


#---------------------------------------
issuance_lvl


r1 <- felm(total_rp_articles_12_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r3 <- felm(total_rp_articles_1_1 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1, r2,r3,
          type = "latex", table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          dep.var.caption = "",
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Border States Issuance Level Counts of Articles',
          dep.var.labels = c("Total Articles [-12, 0]", "Total Articles [-6, 0]", "Total Articles [-1, +1]"),
          covariate.labels = c("City GO Vote",  "Number of Sources","ln(Size)", "County ln(GDP)", "County ln(Pers Inc)","County ln(Percap Inc)", "County ln(Emp)"),
          add.lines = list(c("Time FE", "Year", "Year", "Year", "Year"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "State", 'State', "State", 'State')),
          out = paste0(tables_wd, '/Border States Article Counts FINAL.tex')
)



r1 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + group + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + group + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r3 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + group + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r4 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + group + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r5 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + quarter + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r6 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + group + quarter + purp_broad|0|state + ym + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r7 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + group + purp_broad|0|seed_issuer_id + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r8 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + group + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1,r2,r3,r4,r5,r6,r7,r8,
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Issuance Level Counts of Articles',
          dep.var.labels = c("Total Articles [-1, +1]"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc","Percap Inc", "Emp"),
          add.lines = list(c("Time FE", "Y,M", "Y,M", "YM", "YM", "Y,Q", "Y,Q", "YQ", "YQ"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issuer, YM", "State, YM", "Issuer, YM", "State, YM", "Issuer, YM", "State, YM", "Issuer, YM", "State, YM")),
          out = paste0(tables_wd, '/Border States Article Counts (6 Month Window) FE and Cluster Options.tex')
)


r1 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1])
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r3 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1])
r4 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|state + purp_broad, data = issuance_lvl[go_unlim_bond_issuance == 1])
r5 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + quarter + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1])
r6 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + quarter + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r7 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + purp_broad|0|state, data = issuance_lvl[go_unlim_bond_issuance == 1])
r8 <- felm(total_rp_articles_6_0 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + purp_broad|0|state + purp_broad, data = issuance_lvl[go_unlim_bond_issuance == 1])


stargazer(r1,r2,r3,r4,r5,r6,r7,r8,
          type = "latex",  header = FALSE, table.placement = "H",
          digits = 3, omit.stat = c("ser", "f"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Border States Issuance Level Counts of Articles',
          dep.var.labels = c("Total Articles [-6, 0]"),
          covariate.labels = c("I(Vote)", "Amount", "GDP", "Pers Inc","Percap Inc", "Emp"),
          add.lines = list(c("Time FE", "Y,M", "Y,M", "YM", "YM", "Y,Q", "Y,Q", "YQ", "YQ"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "State", "State, Purp", "State", "State, Purp", "State", "State, Purp", "State", "State, Purp")),
          out = paste0(tables_wd, '/Border States Article Counts (6 Month Window) FE and Cluster Options.tex')
)

issuance_lvl[, state_year := paste0(state, year)]

r1 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r2 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + month + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r3 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r4 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|ym + purp_broad|0|state + ym + purp_broad, data = issuance_lvl[go_unlim_bond_issuance == 1])
r5 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + quarter + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r6 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|year + quarter + purp_broad|0|state + ym + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r7 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + purp_broad|0|state + ym, data = issuance_lvl[go_unlim_bond_issuance == 1])
r8 <- felm(total_rp_articles_1_1 ~ city_go_vote + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|yq + purp_broad|0|state + ym + purp_broad, data = issuance_lvl[go_unlim_bond_issuance == 1])


