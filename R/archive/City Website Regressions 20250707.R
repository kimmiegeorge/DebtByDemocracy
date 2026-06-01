
#trace(stargazer:::.stargazer.wrap, edit = T) # 950 change round to 2 digits
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2503_websites"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_20250312.csv')
data <- data[total_subs > 1]

data <- data[!(group %in% c('Tennessee/Arkansas', 'Arkansas/Mississippi'))]

# number issuers  112
#---------------------------------------

desc <- data[, .(ln_debt_count, 
                 ln_all_finance_count,
                         percent_debt_url, ln_cum_num_issues)]

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
          rownames = F, table.placement = "H", out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/descriptives/Website Descriptives.tex')



#---------------------------------
# now just control 


# ROBUST
r1 <- felm(ln_debt_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year|0|fips, data = data)
r2 <- felm(ln_all_finance_count ~ city_go_vote + ln_cum_num_issues  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year|0|fips, data = data)
r3 <- felm(percent_debt_url ~ city_go_vote + ln_cum_num_issues  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year|0|fips, data = data)



stargazer(r1, r2, r3,
          type = "latex",  
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          font.size = 'small',
          omit.table.layout = "n",
          table.placement = 'H',
          title = 'City Website Regressions', 
          order = c(1, 2, 7, 3, 4, 5, 6),
          dep.var.labels = c( "Debt-Related Count", "All Finance Count", "Debt-Related URLs"),
          covariate.labels = c("City GO Vote", "Num Issuances", 
                               "County ln(GDP)",  "County ln(Pop)", "County ln(Pers Inc)", "County ln(GDP)"),
          #se = list(r1a_se, r1b_se, r2a_se, r2b_se, r3a_se, r3b_se, r4a_se, r4b_se),
          add.lines = list(c("State-Pair FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"), 
                           c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"), 
                           c("Cluster", "County", "County", "County", "County", "Robust", "Robust", "Robust", "Robust")),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/raw_tables/website.tex')


# ROBUST
data[, group_year := paste0(group, year)]
r1a <- felm(ln_bond_and_debt_count ~ city_go_vote|group + year|0|fips, data = data)
r1a_se = summary(r1a, robust = T)$coefficients[, 2]
r1b <- felm(ln_bond_and_debt_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group + year|0|fips, data = data)
r1b_se = summary(r1b, robust = T)$coefficients[, 2]
r2a <- felm(ln_debt_count ~ city_go_vote|group + year|0|fips, data = data)
r2a_se = summary(r2a, robust = T)$coefficients[, 2]
r2b <- felm(ln_debt_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group + year |0|fips, data = data)
r2b_se = summary(r2b, robust = T)$coefficients[, 2]
r3a <- felm(ln_tax_count ~ city_go_vote|group + year|0|fips, data = data)
r3a_se = summary(r3a, robust = T)$coefficients[, 2]
r3b <- felm(ln_tax_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop + ln_pers_inc  + ln_emp|group + year|0|fips, data = data)
r3b_se = summary(r3b, robust = T)$coefficients[, 2]
r4a <- felm(percent_bond_or_debt_url ~ city_go_vote|group + year|0|state, data = data)
r4a_se = summary(r4a, robust = T)$coefficients[, 2]
r4b <- felm(percent_bond_or_debt_url ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group_year|0|fips, data = data)
r4b_se = summary(r4b, robust = T)$coefficients[, 2]



stargazer(r4b, r1b, r3b,
          type = "latex",  
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t",  
          column.sep.width = '-5pt',
          dep.var.labels.include = T,
          no.space = T,
          font.size = 'small',
          omit.table.layout = "n",
          table.placement = 'H',
          tile = 'City Website Regressions', 
          order = c(1, 2, 7, 3, 4, 5, 6),
          dep.var.labels = c("Bond-Related URLs", "Bond-Related Count", "Tax Count"),
          covariate.labels = c("City GO Vote", "Num Issuances", 
                               "County ln(GDP)", "County ln(Pers Inc)", "County ln(Percap Inc)", "County ln(GDP)"),
          #se = list(r1a_se, r1b_se, r2a_se, r2b_se, r3a_se, r3b_se, r4a_se, r4b_se),
          add.lines = list(c("State-Pair FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"), 
                           c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"), 
                           c("Cluster", "State", "State", "State", "State", "Robust", "Robust", "Robust", "Robust")),
          out = paste0(tables_wd, '/full_sample_state_se_just_control.tex'))





r4b <- felm(percent_all_finance_url ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pers_inc + ln_percap_inc + ln_emp|group + year |0|state, data = data)
r4b_se = summary(r4b, robust = T)$coefficients[, 2]

