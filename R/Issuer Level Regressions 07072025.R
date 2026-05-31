# trace(stargazer:::.stargazer.wrap, edit = T) # 950 is format t stat
#----------------------------
# Issuer Level Regressions 
#----------------------------

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven)
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate'

#----------------------------
# Load data 
#----------------------------

data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/250701_city_issuerlevel_yieldspread.dta'))
#data[state == 'CA', city_rev_vote := 0]
#data[state == 'ME', city_rev_vote := 0]
#data[state == 'OK', city_rev_vote := 0]
data <- data[city_rev_vote == 0 & !is.na(city_go_vote)]

data <- data[!is.na(ln_pop) & !is.na(ln_county_debt_other)]

# load border state issuers 
border_state = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 80000 20250801.csv')
border_state = unique(border_state[, .(seed_issuer_id, group, category)])
border_state = border_state[category != 'green']
border_state[, border_sample := 1]

data <- border_state[data, on = .(seed_issuer_id)]

# only utgo states 
only_utgo <- data[city_go_vote == 0 | state %in% c('OH', 'MI', 'WA')]
all_go <- data[city_go_vote == 0 | !(state %in% c('OH', 'MI', 'WA'))]


#----------------------------
# descriptives
#----------------------------
data[, utgo_vote := ifelse(state %in% c('OH', 'MI', 'WA'), 1, 0)]
data[, allgo_vote := ifelse(city_go_vote == 1 & utgo_vote == 0, 1, 0)]

vars = c('utgo_vote', 'allgo_vote', 'frac_utgo', 'frac_ltgo', 'frac_rev', 'issuer_yield_spread',
         'ln_county_debt_other', 'ln_gdp', 'ln_pop', 'ln_pers_inc', 'ln_emp',
         'glm_proactive', 'state_ltgo_allowed', 'state_go_vote')

all_desc = data.table()
for (var in vars){
  print(var)
  desc <- data[!is.na(get(var)), list(Mean = mean(get(var)), 
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

varnames = c('UTGO Vote', 'All GO Vote', 'Pct UTGO', 'Pct LTGO', 'Pct Rev', 
             'Wtd. Avg. Yield Spread', 'ln(Non-issuer county debt)', 
             'County ln(GDP)', 'County ln(Pop)', 'County ln(Pers. Inc)', 
             'County ln(Emp)', 'Proactive State', 'LTGO Allowed', 'State GO Vote')
varnames = data.table(varnames)
all_desc <- cbind(varnames, all_desc)


stargazer(all_desc, summary = F, no.space = T, rownames = F, 
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/descriptives/issuer_lvl_desc.tex')


#----------------------------
# only UTGO regs
#----------------------------
r1a <- felm(frac_utgo ~ city_go_vote|0|0|fips, data = only_utgo)
summary(r1a)
r1b <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = only_utgo)
summary(r1b)
r1c <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = only_utgo)
summary(r1c)
r1d <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_fullfaith + sepfund_statlien + state_go_vote + state_sep_debtservice_levy|0|0|fips, data = only_utgo)
summary(r1d)
r2a <- felm(frac_ltgo ~ city_go_vote|0|0|fips, data = only_utgo)
summary(r2a)
r2b <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = only_utgo)
summary(r2b)
r2c <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = only_utgo)
summary(r2c)
r2d <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_fullfaith + sepfund_statlien + state_go_vote + state_sep_debtservice_levy|0|0|fips, data = only_utgo)
summary(r2d)
r3a <- felm(frac_rev ~ city_go_vote|0|0|fips, data = only_utgo)
summary(r3a)
r3b <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = only_utgo)
summary(r3b)
r3c <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = only_utgo)
summary(r3c)
r3d <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_fullfaith + sepfund_statlien + state_go_vote|0|0|fips, data = only_utgo)
summary(r3d)




stargazer(r1a, r1b, r1c, r2c, r3c,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "GO Vote Requirements and City Debt Choice - UTGO Vote Only",
          dep.var.labels = c("Pct UTGO", "Pct LTGO", "Pct Rev"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          out = paste0(tbl_dir, '/debt_choice_utgo_only_v2_option1.tex'))






r4a <- felm(issuer_yield_spread ~ city_go_vote|0|0|fips, data = only_utgo)
summary(r4a)
r4b <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = only_utgo)
summary(r4b)
r4c <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = only_utgo)
summary(r4c)
r4d <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_fullfaith + sepfund_statlien|0|0|fips, data = only_utgo)
summary(r4d)

stargazer(r4a, r4b, r4c,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "GO Vote Requirements and City Aggregate Yields - UTGO Vote Only",
          dep.var.labels = c("Wtd. Avg. Yield Spread"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          out = paste0(tbl_dir, '/yield_spread_utgo_only_option1.tex'))



#----------------------------
# all GO regs
#----------------------------
r1a <- felm(frac_utgo ~ city_go_vote|0|0|fips, data = all_go)
summary(r1a)
r1b <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = all_go)
summary(r1b)
r1c <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = all_go)
summary(r1c)
r1d <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + state_fullfaith + state_sep_debtservice_levy + sepfund_statlien |0|0|fips, data = all_go)
summary(r1d)
r2a <- felm(frac_ltgo ~ city_go_vote|0|0|fips, data = all_go)
summary(r2a)
r2b <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = all_go)
summary(r2b)
r2c <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = all_go)
summary(r2c)
r2d <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = all_go)
summary(r2d)
r3a <- felm(frac_rev ~ city_go_vote|0|0|fips, data = only_utgo)
summary(r3a)
r3b <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = all_go)
summary(r3b)
r3c <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = all_go)
summary(r3c)
r3d <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = all_go)
summary(r3d)







stargazer(r1a, r1b, r1c, r2c, r3c,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "GO Vote Requirements and City Debt Choice - All GO Vote",
          dep.var.labels = c("Pct UTGO", "Pct LTGO", "Pct Rev"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          out = paste0(tbl_dir, '/debt_choice_all_go_v2_option1.tex'))




r4a <- felm(issuer_yield_spread ~ city_go_vote|0|0|fips, data = all_go)
summary(r4a)
r4b <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = all_go)
summary(r4b)
r4c <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = all_go)
summary(r4c)
r4d <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_fullfaith + sepfund_statlien|0|0|fips, data = all_go)
summary(r4d)

stargazer(r4a, r4b, r4c,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "GO Vote Requirements and City Aggregate Yields - All GO Vote",
          dep.var.labels = c("Wtd. Avg. Yield Spread"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          out = paste0(tbl_dir, '/yield_spread_all_go_option1.tex'))




#----------------------------
# border - first for all go vote
#----------------------------
good_groups = c("Tennesee/Georgia","Kentucky/Missouri", "West Virginia/Kentucky", "Tennesee/North Carolina",
                "Michigan/Indiana", "Ohio/Indiana", "Louisiana/Mississippi")

border_all_go_vote <- all_go[group %in% good_groups & !(group %in% c('Michigan/Wisconsin', 
                                                                 'Ohio/Kentucky',
                                                                 'Michigan/Indiana', 
                                                                 'Ohio/Indiana'))]
desc <- border_all_go_vote[, list( mean(frac_utgo), mean(frac_ltgo), mean(frac_rev)), .(city_go_vote)]
colnames(desc) <- c('Vote', 'Frac UTGO', 'Frac LTGO', 'Frac Rev')
stargazer(desc[order(Vote)], summary = F, type = 'latex', rownames = F, out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/border_state_desc_20250730.tex',
          table.placement = "H", title = "Descriptives - Border State All GO Vote")


r4a1 <- felm(frac_utgo ~ city_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4a1)
r4b1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group|0|fips, data = border_all_go_vote)
summary(r4b1)
r4c1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4c1)  
r4d1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4d1)  
r4e1 <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4e1)


stargazer(r4a1, r4b1, r4c1, r4d1, r4e1,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "Border States GO Vote Requirements and City Debt Choice - All GO Vote (50 Miles - Restricted Group)",
          dep.var.labels = c("Pct UTGO", "Pct Rev"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          add.lines = list(c('Border FE', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes')),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/border_state_issuer_lvl_20250730_super_restrictive.tex')




r4a1 <- felm(issuer_yield_spread ~ city_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4a1)
r4b1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group|0|fips, data = border_all_go_vote)
summary(r4b1)
r4c1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4c1)
r4d1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border_all_go_vote)
summary(r4d1)
stargazer(r4a1, r4b1, r4c1, r4d1,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "Border States GO Vote Requirements and City Yield Spreads - All GO Vote (50 Miles - Restricted Group)",
          dep.var.labels = c("Wtd. Avg. Yield Spread"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          add.lines = list(c('Border FE', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes')),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/border_state_issuer_lvlyields_20250730_super_restrictive.tex')




#----------------------------
# border - now for utgo vote only
#----------------------------
border_utgo_vote <- only_utgo[group %in% good_groups & (group %in% c('Michigan/Wisconsin', 
                                                                 'Ohio/Kentucky',
                                                                 'Michigan/Indiana', 
                                                                 'Ohio/Indiana'))]

desc <- border_utgo_vote[, list( mean(frac_utgo), mean(frac_ltgo), mean(frac_rev)), .(city_go_vote)]
colnames(desc) <- c('Vote', 'Frac UTGO', 'Frac LTGO', 'Frac Rev')
stargazer(desc[order(Vote)], summary = F, type = 'latex', rownames = F, out = paste0(tbl_dir, '/border_utgo_only_desc.tex'),
          table.placement = "H", title = "Descriptives - Border State UTGO Vote Only")
r4a <- felm(frac_utgo ~ city_go_vote|0|0|fips, data = border_utgo_vote)
summary(r4a)
r4a1 <- felm(frac_utgo ~ city_go_vote|group|0|fips, data = border_utgo_vote)
summary(r4a1)
r4b <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = border_utgo_vote)
summary(r4b)
r4b1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group|0|fips, data = border_utgo_vote)
summary(r4b1)
r4c <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border_utgo_vote)
summary(r4c)    
r4c1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border_utgo_vote)
summary(r4c1)  
r4d <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border_utgo_vote)
summary(r4d)
r4d1 <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border_utgo_vote)
summary(r4d1)
r4e <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border_utgo_vote)
summary(r4e)
r4e1 <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border_utgo_vote)
summary(r4e1)


stargazer(r4a, r4a1, r4b, r4b1, r4c, r4c1, r4d, r4d1, r4e, r4e1,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "Border States GO Vote Requirements and City Debt Choice - UTGO Vote Only",
          dep.var.labels = c("Pct UTGO", "Pct LTGO", "Pct Rev"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          add.lines = list(c('Border FE', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes')),
          out = paste0(tbl_dir, '/border_state_choice_utgo_only.tex'))




r4a <- felm(issuer_yield_spread ~ city_go_vote|0|0|fips, data = border_utgo_vote)
summary(r4a)
r4a1 <- felm(issuer_yield_spread ~ city_go_vote|group|0|fips, data = border_utgo_vote)
summary(r4a1)
r4b <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = border_utgo_vote)
summary(r4b)
r4b1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group|0|fips, data = border_utgo_vote)
summary(r4b1)
r4c <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border_utgo_vote)
summary(r4c)
r4c1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border_utgo_vote)
summary(r4c1)
stargazer(r4a, r4a1, r4b, r4b1, r4c, r4c1,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "Border States GO Vote Requirements and City Yield Spreads - UTGO Vote Only",
          dep.var.labels = c("Wtd. Avg. Yield Spread"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          add.lines = list(c('Border FE', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes')),
          out = paste0(tbl_dir, '/border_state_spreads_utgo_only.tex'))




#----------------------------
# border - now forall
#----------------------------
border <- data[border_sample == 1]

desc <- border[, list( mean(frac_utgo), mean(frac_ltgo), mean(frac_rev)), .(city_go_vote)]
colnames(desc) <- c('Vote', 'Frac UTGO', 'Frac LTGO', 'Frac Rev')
stargazer(desc[order(Vote)], summary = F, type = 'latex', rownames = F, out = paste0(tbl_dir, '/border_all_desc.tex'),
          table.placement = "H", title = "Descriptives - Border State All Combined")


r4a <- felm(frac_utgo ~ city_go_vote|0|0|fips, data = border)
summary(r4a)
r4a1 <- felm(frac_utgo ~ city_go_vote|group|0|fips, data = border)
summary(r4a1)
r4b <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = border)
summary(r4b)
r4b1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group|0|fips, data = border)
summary(r4b1)
r4c <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border)
summary(r4c)    
r4c1 <- felm(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border)
summary(r4c1)  
r4d <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border)
summary(r4d)
r4d1 <- felm(frac_ltgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border)
summary(r4d1)
r4e <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border)
summary(r4e)
r4e1 <- felm(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border)
summary(r4e1)


stargazer(r4a, r4a1, r4b, r4b1, r4c, r4c1, r4d, r4d1, r4e, r4e1,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "Border States GO Vote Requirements and City Debt Choice - All Border State Pairs",
          dep.var.labels = c("Pct UTGO", "Pct LTGO", "Pct Rev"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          add.lines = list(c('Border FE', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes')),
          out = paste0(tbl_dir, '/border_state_choice_all.tex'))




r4a <- felm(issuer_yield_spread ~ city_go_vote|0|0|fips, data = border)
summary(r4a)
r4a1 <- felm(issuer_yield_spread ~ city_go_vote|group|0|fips, data = border)
summary(r4a1)
r4b <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|0|0|fips, data = border)
summary(r4b)
r4b1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group|0|fips, data = border)
summary(r4b1)
r4c <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|0|0|fips, data = border)
summary(r4c)
r4c1 <- felm(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group|0|fips, data = border)
summary(r4c1)
stargazer(r4a, r4a1, r4b, r4b1, r4c, r4c1,
          type = "latex",  header = FALSE,
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          omit.table.layout = "n",
          table.placement = 'H',
          dep.var.caption = "",
          title = "Border States GO Vote Requirements and City Yield Spreads - All Border State Pairs",
          dep.var.labels = c("Wtd. Avg. Yield Spread"),
          covariate.labels = c('City GO Vote', 'ln(Non-issuer county debt)',  
                               'County ln(GDP)', 'County ln(Pop)', 
                               'County ln(Pers. Inc)', 'County ln(Emp)', 
                               'Proactive State', 'LTGO Allowed',  'State GO Vote'),
          add.lines = list(c('Border FE', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes', 'No', 'Yes')),
          out = paste0(tbl_dir, '/border_state_spreads_all.tex'))

