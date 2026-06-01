#trace(stargazer:::.stargazer.wrap, edit = T) 7054
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2506_issuerlvl_mergent"


#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Atlas Muni/Issuer Level Aggregation by Mergent.csv')
data <- data[city_rev_vote == 0]
data[, county_state := paste0(county_name, state)]
data[, go_unlim_vote := ifelse(city_go_vote == 1, 1, 0)]
data[, go_lim_vote := ifelse(all_go_vote == 1, 1, 0)]
data[, odd_vote := ifelse(city_go_vote == 1 & all_go_vote == 0, 1, 0)]

# fidelity scores
scores <- fread('~/Dropbox/Voting on Bonds/Data/Fidelity/UTGO_LTGO_Scores_Cities.csv')
setnames(scores, 'State Abbreviation', 'state')
setnames(scores, 'UTGO Score (Cities)', 'UTGO_Score')
setnames(scores, 'LTGO Score (Cities)', 'LTGO_Score')

data <- scores[data, on = .(state)]

data[, security_score := state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien]
data[, high_security := ifelse(security_score >= 2, 1, 0)]

# gao et al
gao <- fread('~/Dropbox/Voting on Bonds/Data/Gao et al/Table1_State_Policies_Complete.csv')
setnames(gao, 'State', 'state')

data <- gao[data, on = .(state)]

border_data <- fread('~/Dropbox/Voting on Bonds/Data/Atlas Muni/Issuer Level Aggregation by Mergent Border States.csv')
border_data <- border_data[city_rev_vote == 0]
border_data[, county_state := paste0(county_name, state)]


#---------------------------------------
r1a <- felm(perc_rev ~ city_go_vote + Proactive + state_go_vote + state_ltgo_allowed + high_security + 
              ln_amount +  gdp + emp + pers_inc|0|0|county_state, data = data)
r1b <- felm(perc_go~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r2a <- felm(perc_go_unlim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r2b <- felm(perc_go_unlim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r3a <- felm(perc_go_lim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r3b <- felm(perc_go_lim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


r4a <- felm(weighted_yield~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r4b <- felm(weighted_yield~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r5a <- felm(weighted_yield_spread~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r5b <- felm(weighted_yield_spread~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Perc GO Regs, Any GO Vote", 
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('All GO Vote', 
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge",
                               "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_all_go_vote.tex'))

# now output yields
stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Yield Regs, All GO Vote", 
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('All GO Vote', 
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_all_go_vote.tex'))




#--------------------------------------- CITY GO VOTE
r1a <- felm(perc_go~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r1b <- felm(perc_go~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r2a <- felm(perc_go_unlim~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r2b <- felm(perc_go_unlim~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r3a <- felm(perc_go_lim~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r3b <- felm(perc_go_lim~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


r4a <- felm(weighted_yield~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r4b <- felm(weighted_yield~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r5a <- felm(weighted_yield_spread~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r5b <- felm(weighted_yield_spread~ city_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Perc GO Regs, Any GO Vote", 
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('Any GO Vote', 
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_any_go_vote.tex'))

stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Yield Regs, Any GO Vote", 
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('Any GO Vote', 
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax",
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_any_go_vote.tex'))



#--------------------------------------- unlim vs lim
r1a <- felm(perc_go~ go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r1b <- felm(perc_go~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r2a <- felm(perc_go_unlim~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r2b <- felm(perc_go_unlim~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r3a <- felm(perc_go_lim~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r3b <- felm(perc_go_lim~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


r4a <- felm(weighted_yield~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r4b <- felm(weighted_yield~  go_lim_vote + go_unlim_vote +   
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r5a <- felm(weighted_yield_spread~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r5b <- felm(weighted_yield_spread~  go_lim_vote + go_unlim_vote +  
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('GO Unlim Vote', 'GO Lim Vote', 
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_split_vote.tex'))

stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('GO Unlim Vote', 'GO Lim Vote', 
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax",
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_split_vote.tex'))

#--------------------------------------- all go removing states with just limited GO Vote Req
r1a <- felm(perc_go~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])
r1b <- felm(perc_go~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])

r2a <- felm(perc_go_unlim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])
r2b <- felm(perc_go_unlim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])

r3a <- felm(perc_go_lim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r3b <- felm(perc_go_lim~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])


r4a <- felm(weighted_yield~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r4b <- felm(weighted_yield~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])

r5a <- felm(weighted_yield_spread~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r5b <- felm(weighted_yield_spread~ all_go_vote + 
              state_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Perc GO Regs, All GO Vote, Drop GO Unlim Vote Only States", 
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('All GO Vote',
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_all_go_vote_drop_odd.tex'))

stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Yield Regs, All GO Vote, Drop GO Unlim Vote Only States", 
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('All GO Vote',
                               "State GO Vote", "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax",
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_all_go_vote_drop_odd.tex'))


#--------------------------------------- DROP STATE GO VOTE
r1a <- felm(perc_go~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r1b <- felm(perc_go~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r2a <- felm(perc_go_unlim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r2b <- felm(perc_go_unlim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r3a <- felm(perc_go_lim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r3b <- felm(perc_go_lim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


r4a <- felm(weighted_yield~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r4b <- felm(weighted_yield~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r5a <- felm(weighted_yield_spread~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r5b <- felm(weighted_yield_spread~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "GO Perc Regs, All GO Vote, Drop State GO Vote", 
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('All GO Vote', "Lim tax GO allowed", "Full faith pledge",
                               "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_all_go_vote_drop_state.tex'))

# now output yields
stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Yield Regs, All GO Vote, Drop State GO Vote", 
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('All GO Vote', "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_all_go_vote_drop_state.tex'))


#--------------------------------------- DROP STATE GO VOTE
r1a <- felm(perc_go~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)
r1b <- felm(perc_go~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r2a <- felm(perc_go_unlim~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r2b <- felm(perc_go_unlim~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r3a <- felm(perc_go_lim~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r3b <- felm(perc_go_lim~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


r4a <- felm(weighted_yield~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r4b <- felm(weighted_yield~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)

r5a <- felm(weighted_yield_spread~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data)

r5b <- felm(weighted_yield_spread~ city_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data)


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "GO Perc Regs, Any GO Vote, Drop State GO Vote", 
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('Any GO Vote', "Lim tax GO allowed", "Full faith pledge",
                               "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_any_go_vote_drop_state.tex'))

# now output yields
stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Yield Regs, Any GO Vote, Drop State GO Vote", 
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('Any GO Vote', "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_any_go_vote_drop_state.tex'))


#--------------------------------------- DROP STATE GO VOTE and drop odd
r1a <- felm(perc_go~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])
r1b <- felm(perc_go~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])

r2a <- felm(perc_go_unlim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r2b <- felm(perc_go_unlim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])

r3a <- felm(perc_go_lim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r3b <- felm(perc_go_lim~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])


r4a <- felm(weighted_yield~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r4b <- felm(weighted_yield~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])

r5a <- felm(weighted_yield_spread~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|county_state, data = data[odd_vote == 0])

r5b <- felm(weighted_yield_spread~ all_go_vote + state_ltgo_allowed +state_fullfaith + 
              state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien + 
              ln_amount +  gdp + emp + percap_inc + pers_inc|0|0|state, data = data[odd_vote == 0])


# first output percentage variables 
stargazer(r1a, r1b, r2a, r2b, r3a, r3b, 
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "GO Perc Regs, All GO Vote, Drop GO Unlim Vote Only States, Drop State GO Vote", 
          dep.var.labels = c("Percent GO", "Percent GO Unlim.", "Percent GO Lim."),
          covariate.labels = c('All GO Vote', "Lim tax GO allowed", "Full faith pledge",
                               "Debt-service prop tax", "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/go_perc_regs_all_go_vote_drop_state_drop_odd.tex'))

# now output yields
stargazer(r4a, r4b, r5a, r5b,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          table.placement = 'H',
          omit.table.layout = 'n',
          title = "Yield Regs, All GO Vote, Drop GO Unlim Vote Only States, Drop State GO Vote", 
          dep.var.labels = c("Wtd. Avg. Yield", 'Wtd. Avg. Yield Spread'),
          covariate.labels = c('All GO Vote',  "Lim tax GO allowed", "Full faith pledge", "Debt-service prop tax", 
                               "Fund for pledged prop tax", "Statutory lien on pledged prop tax",
                               "Amount",
                               "County ln(GDP)", "County ln(Emp)", "County ln(Percap Inc)", "County ln(Pers. Inc)"),
          add.lines = list(c("Cluster", "County", "State", "County", "State", "County", "State")), 
          out = paste0(tables_wd, '/yield_regs_all_go_vote_drop_state_drop_odd.tex'))
