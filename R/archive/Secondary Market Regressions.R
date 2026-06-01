'''
Secondary market yields tests 
'''

#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2505_secondary"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data//Mergent/Clean/251012_issue_level_aggregation.csv')
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote) & !is.na(ln_pop)]
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
border_states <- border_states[go_unlim == 1]
border_states <- unique(border_states[, .(seed_issuer_id,group)])
border_states <- data[border_states, on = .(seed_issuer_id)]
#---------------------------------------

mean(data$markup_institutional_3yr, na.rm = T)

r1 <- felm(markup_3yr ~ city_go_vote|yrmonth + purp_broad|0|seed_issuer_id, data = data, psdef = F)
r1 <- felm(markup_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + ln_gdp + ln_pers_inc + ln_percap_inc + 
             ln_emp + state_go_vote + state_ltgo_allowed + glm_proactive |yrmonth + purp_broad|0|seed_issuer_id, data = data)

r1 <- felm(markup_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + ln_gdp + ln_pers_inc + ln_percap_inc + 
             ln_emp + state_go_vote + state_ltgo_allowed + glm_proactive |yrmonth + purp_broad|0|seed_issuer_id, data = data)

r1 <- felm(markup_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|0|0|state, data = data, psdef = F)
r2 <- felm(markup_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|state, data = data, psdef = F)
r3 <- felm(markup_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|seed_issuer_id, data = data, psdef = F)

r4 <- felm(markup_retail_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|0|0|state, data = data, psdef = F)
r5 <- felm(markup_retail_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|state, data = data, psdef = F)
r6 <- felm(markup_retail_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|seed_issuer_id, data = data, psdef = F)

r7 <- felm(markup_institutional_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|0|0|state, data = data, psdef = F)
r8 <- felm(markup_institutional_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|state, data = data, psdef = F)
r9 <- felm(markup_institutional_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|seed_issuer_id, data = data, psdef = F)



stargazer(r1,r2,r3,r4,r5,r6,r7,r8,r9,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Vote Requirements and Liquidity',
          dep.var.caption = "",
          dep.var.labels = c('Markup', 'Markup - Retail', 'Markup - Institutional'),
          covariate.labels = c("City GO Vote", "Size", "Maturity", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "County GDP", "County Emp", "County Percap Inc", "County Pers. Inc"),
          add.lines = list(c("Time FE", "No", "YM", "YM", "No", "YM", "YM", "No", "YM", "YM"),
                           c("Purpose FE", "No", "Yes", "Yes", "No", "Yes", "Yes", "No", "Yes", "Yes"),
                           c("Cluster", "State", "State", "Issuer", "State", "State", "Issuer","State", "State", "Issuer")),
          out = paste0(tables_wd, '/full_sample_markup.tex'))


r1 <- felm(yield_volatility_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|0|0|state, data = data, psdef = F)
r2 <- felm(yield_volatility_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|state, data = data, psdef = F)
r3 <- felm(yield_volatility_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|yrmonth + purp_broad|0|seed_issuer_id, data = data, psdef = F)


stargazer(r1,r2,r3,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Vote Requirements and Yield Volatility',
          dep.var.caption = "",
          dep.var.labels = c('Yield Volatility'),
          covariate.labels = c("City GO Vote", "Size", "Maturity", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "County GDP", "County Emp", "County Percap Inc", "County Pers. Inc"),
          add.lines = list(c("Time FE", "No", "YM", "YM", "No", "YM", "YM", "No", "YM", "YM"),
                           c("Purpose FE", "No", "Yes", "Yes", "No", "Yes", "Yes", "No", "Yes", "Yes"),
                           c("Cluster", "State", "State", "Issuer", "State", "State", "Issuer","State", "State", "Issuer")),
          out = paste0(tables_wd, '/full_sample_yield_vol.tex'))





r1 <- felm(markup_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group|0|state, data = border_states, psdef = F)

r2 <- felm(markup_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|state, data = border_states, psdef = F)

r3 <- felm(markup_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|seed_issuer_id, data = border_states, psdef = F)


r4 <- felm(markup_retail_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group|0|state, data = border_states, psdef = F)

r5 <- felm(markup_retail_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|state, data = border_states, psdef = F)

r6 <- felm(markup_retail_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|seed_issuer_id, data = border_states, psdef = F)

r7 <- felm(markup_institutional_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group|0|state, data = border_states, psdef = F)

r8 <- felm(markup_institutional_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|state, data = border_states, psdef = F)

r9 <- felm(markup_institutional_3yr ~city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|seed_issuer_id, data = border_states, psdef = F)




stargazer(r1,r2,r3,r4,r5,r6,r7,r8,r9,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Vote Requirements and Liquidity',
          dep.var.caption = "",
          dep.var.labels = c('Markup', 'Markup - Retail', 'Markup - Institutional'),
          covariate.labels = c("City GO Vote", "Size", "Maturity", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "County GDP", "County Emp", "County Percap Inc", "County Pers. Inc"),
          add.lines = list(c("Time FE", "No", "YM", "YM", "No", "YM", "YM", "No", "YM", "YM"),
                           c("Purpose FE", "No", "Yes", "Yes", "No", "Yes", "Yes", "No", "Yes", "Yes"),
                           c("State-Pair FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "State", "State", "Issuer", "State", "State", "Issuer","State", "State", "Issuer")),
          out = paste0(tables_wd, '/border_state_markup.tex'))



r1 <- felm(yield_volatility_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group|0|state, data = border_states, psdef = F)
r2 <- felm(yield_volatility_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|state, data = border_states, psdef = F)
r3 <- felm(yield_volatility_3yr ~ city_go_vote + log_issue_size + log_avg_maturity +weighted_avg_callable  + weighted_avg_sinkable + 
             weighted_avg_insured + weighted_avg_rated + 
             state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien +
             ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|year + group + purp_broad|0|seed_issuer_id, data = border_states, psdef = F)


stargazer(r1,r2,r3,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Vote Requirements and Yield Volatility',
          dep.var.caption = "",
          dep.var.labels = c('Yield Volatility'),
          covariate.labels = c("City GO Vote", "Size", "Maturity", "Callable", "Sinkable", "Insured", "Rated", 
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "County GDP", "County Emp", "County Percap Inc", "County Pers. Inc"),
          add.lines = list(c("Time FE", "No", "YM", "YM", "No", "YM", "YM", "No", "YM", "YM"),
                           c("Purpose FE", "No", "Yes", "Yes", "No", "Yes", "Yes", "No", "Yes", "Yes"),
                           c("State-Pair FE", "Yes", "Yes", "Yes", "No", "Yes", "Yes", "No", "Yes", "Yes"),
                           c("Cluster", "State", "State", "Issuer", "State", "State", "Issuer","State", "State", "Issuer")),
          out = paste0(tables_wd, '/border_state_yield_vol.tex'))