# Atlas Muni Debt Outstanding Data Regressions
#trace(stargazer:::.stargazer.wrap, edit = T) 7054
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2505_atlas_muni"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Atlas Muni/250519_atlas_mergent_merged.csv')
data <- data[!is.na(city_go_vote) & !is.na(city_rev_vote)]
data <- data[city_rev_vote == 0]
data[, num_obs := .N, ,.(seed_issuer_id)]
data <- data[num_obs == 11]
data <- data[!is.na(ln_pop)]

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Atlas Muni/250519_atlas_mergent_border_states.csv')
#border_states <- border_states[!is.na(city_go_vote) & !is.na(city_rev_vote)]
#border_states <- border_states[city_rev_vote == 0]
border_states <- border_states[category != 'green']
#---------------------------------------
desc <- data[, .(ln_GOOutstanding, 
                 ln_GOOutstanding_percap,
                 ln_RevOutstanding,
                 ln_RevOutstanding_percap,
                 ln_TotalOutstanding,
                 ln_TotalOutstanding_percap,
                 Percent_GOOutstanding, 
                 city_go_vote,
                 all_go_vote,
                 go_unlim_vote_only,
                 city_rev_vote)]

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


stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tables_wd, '/Atlas Muni Descriptives.tex'))


#---------------------------------------
r1_i <- felm(Percent_GOOutstanding ~ all_go_vote |year|0|seed_issuer_id, data = data)
r1_s <- felm(Percent_GOOutstanding ~ all_go_vote |year|0|state, data = data)
r2_i <- felm(Percent_GOOutstanding ~ all_go_vote +
             ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|seed_issuer_id, data = data)
r2_s <- felm(Percent_GOOutstanding ~ all_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = data)
r3_i <- felm(Percent_GOOutstanding ~ city_go_vote |year|0|seed_issuer_id, data = data)
r3_s <- felm(Percent_GOOutstanding ~ city_go_vote |year|0|state, data = data)
r4_i <- felm(Percent_GOOutstanding ~ city_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|year|0|seed_issuer_id, data = data)
r4_s <- felm(Percent_GOOutstanding ~ city_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = data)



stargazer(r1_i, r1_s, r2_i, r2_s, r3_i, r3_s, r4_i, r4_s,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          dep.var.labels = "Fraction GO Debt Outstanding",
          tile = 'Full Sample Fraction GO Debt Outstanding', 
          order = c(1, 12, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
          covariate.labels = c('All City GO Vote', 'City GO Vote', 
                             "Ln Pop", "Ln GDP", "Ln Emp", "Ln Pers Inc", "Ln Percap Inc",
                             "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", 
                             "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax"
                             ),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issuer", "State", "Issuer", "State", "Issuer", "State", "Issuer", "State")),
          out = paste0(tables_wd, '/percent_go_full_sample.tex'))





#---------------------------------------
r1_i <- felm(Percent_GOOutstanding ~ all_go_vote |year|0|seed_issuer_id, data = data)
r1_s <- felm(Percent_GOOutstanding ~ all_go_vote |year|0|state, data = data)
r2_i <- felm(Percent_GOOutstanding ~ all_go_vote +
             ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|seed_issuer_id, data = data)
r2_s <- felm(Percent_GOOutstanding ~ all_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = data)
r3_i <- felm(Percent_GOOutstanding ~ city_go_vote |year|0|seed_issuer_id, data = data)
r3_s <- felm(Percent_GOOutstanding ~ city_go_vote |year|0|state, data = data)
r4_i <- felm(Percent_GOOutstanding ~ city_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|year|0|seed_issuer_id, data = data)
r4_s <- felm(Percent_GOOutstanding ~ city_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = data)



stargazer(r1_i, r1_s, r2_i, r2_s, r3_i, r3_s, r4_i, r4_s,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          dep.var.labels = "Fraction GO Debt Outstanding",
          title = 'Full Sample Fraction GO Debt Outstanding', 
          order = c(1, 13, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12),
          covariate.labels = c('All City GO Vote', 'City GO Vote', 
                             "Ln Pop", "Ln GDP", "Ln Emp", "Ln Pers Inc", "Ln Percap Inc",
                             "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", 
                             "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax"
                             ),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issuer", "State", "Issuer", "State", "Issuer", "State", "Issuer", "State")),
          out = paste0(tables_wd, '/percent_go_full_sample.tex'))

restricted <- data[go_unlim_vote_only == 0]

r1_i <- felm(Percent_GOOutstanding ~ all_go_vote |year|0|seed_issuer_id, data = restricted)
r1_s <- felm(Percent_GOOutstanding ~ all_go_vote |year|0|state, data = restricted)
r2_i <- felm(Percent_GOOutstanding ~ all_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|seed_issuer_id, data = restricted)
r2_s <- felm(Percent_GOOutstanding ~ all_go_vote +
               ln_pop + ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = restricted)


stargazer(r1_i, r1_s, r2_i, r2_s,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          dep.var.labels = "Fraction GO Debt Outstanding",
          title =  'Drop GO Unlim Only Vote Fraction GO Debt Outstanding', 
          #order = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
          covariate.labels = c('All City GO Vote', 
                               "Ln Pop", "Ln GDP", "Ln Emp", "Ln Pers Inc", "Ln Percap Inc",
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", 
                               "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax"
          ),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issuer", "State", "Issuer", "State", "Issuer", "State", "Issuer", "State")),
          out = paste0(tables_wd, '/percent_go_restricted.tex'))





#---------------------------------------
r1_i <- felm(ln_GOOutstanding_percap ~ all_go_vote |year|0|seed_issuer_id, data = data)
r1_s <- felm(ln_GOOutstanding_percap ~ all_go_vote |year|0|state, data = data)
r2_i <- felm(ln_GOOutstanding_percap ~ all_go_vote +ln_TotalOutstanding_percap +
                ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|seed_issuer_id, data = data)
r2_s <- felm(ln_GOOutstanding_percap ~ all_go_vote + ln_TotalOutstanding_percap +
               ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = data)
r3_i <- felm(ln_GOOutstanding_percap ~ city_go_vote |year|0|seed_issuer_id, data = data)
r3_s <- felm(ln_GOOutstanding_percap ~ city_go_vote |year|0|state, data = data)
r4_i <- felm(ln_GOOutstanding_percap ~ city_go_vote + ln_TotalOutstanding_percap +
               ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien|year|0|seed_issuer_id, data = data)
r4_s <- felm(ln_GOOutstanding_percap ~ city_go_vote + ln_TotalOutstanding_percap+ 
               ln_gdp + ln_employment + ln_pers_inc + ln_percap_inc + 
               state_go_vote + state_ltgo_allowed +state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien |year|0|state, data = data)



stargazer(r1_i, r1_s, r2_i, r2_s, r3_i, r3_s, r4_i, r4_s,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          dep.var.labels = "Log GO Debt Per Capita",
          title = 'Full Sample Fraction GO Debt Outstanding', 
          order = c(1, 13, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),
          covariate.labels = c('All City GO Vote', 'City GO Vote', 'Log Total Debt Per Capita',
                              "Ln GDP", "Ln Emp", "Ln Pers Inc", "Ln Percap Inc",
                               "State GO debt limit", "Lim tax GO allowed", "Full faith pledge", 
                               "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax"
          ),
          add.lines = list(c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issuer", "State", "Issuer", "State", "Issuer", "State", "Issuer", "State")),
          out = paste0(tables_wd, '/go_per_capita_full_sample.tex'))



