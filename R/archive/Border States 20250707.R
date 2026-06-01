#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, car)
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_km_issuerlvl"

#---------------------------------------
data <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data 20250707.csv')
#data <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Smaller Buffer/Border Matches All Mergent Data 20250715.csv')
data[, yearq := as.yearqtr(offering_date)]
data[, qtr := substr(yearq, 6,7)]
data <- data[!is.na(pop)]
data[, yrmonth := format(offering_date, '%Y%m')]
data[, month := format(offering_date, '%m')]

data <- data[go_unlim == 1 & category != 'green']
data[, group_year := paste0(group, year)]


#---------------------------------------
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250707_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
full_data[state == 'CA', city_rev_vote := 0]
#full_data[state == 'ME', city_rev_vote := 0]
#full_data[state == 'OK', city_rev_vote := 0]
full_data <- full_data[city == 1 &!is.na(city_go_vote) & city_rev_vote == 0]
full_data <- full_data[go_unlim == 1]
# drop school boards
full_data[, school_adj := grepl('BRD ED',issuer_long_name )]
full_data[, school_adj := ifelse(school_adj == 1 & state == 'NJ', 1, 0)]
full_data <- full_data[school_adj == 0]
full_data <- full_data[state != 'HI']
full_data <- full_data[!is.na(callable) & !is.na(ln_maturity_mths)]
full_data <- full_data[!is.na(ln_pop)]
full_data <- full_data[state != 'IA']
#full_data <- full_data[state != 'IN']
#---------------------------------------

# output pairings
pairings <-data[category != 'green' & go_unlim == 1, list(Bonds = .N), .(group)]
colnames(pairings) <- c('State-Pairs', 'Bonds')
stargazer(pairings, summary = F, rownames = F, type = 'latex', table.placement = 'H', header = FALSE,
          no.space = T, column.sep.width = '-5pt', title = 'Border States', out= paste0(tables_wd, '/List Border States.tex'))

#---------------------------------------
# desc
vars = c('offering_yield', 'offering_yield_spread', 'city_go_vote',
         'ln_amount', 'ln_maturity_mths', 'callable', 'sinkable', 'insured', 'rated')

all_desc = data.table()
for (var in vars){
  print(var)
  desc <- full_data[!is.na(get(var)), list(Mean = mean(get(var)), 
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

varnames = c('Yield', 'Yield Spread',  'Vote', 'ln(Size)', 'ln(Maturity)', 'Callable', 'Sinkable', 'Insured', 'Rated')
varnames = data.table(varnames)
all_desc <- cbind(varnames, all_desc)


stargazer(all_desc, summary = F, no.space = T, rownames = F, 
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/descriptives/bond_lvl_desc.tex')





#----------------
# REGS - offering yield


# Group-year FE from A Ljungqvist, M Smolyansky
data[, county_purp := paste0(fips, purp_broad)]
data[, group_yq := paste0(group, yearq)]
data[, purp_year := paste0(purp_broad, year)]
data[, group_ym := paste0(group, yrmonth)]
data[, group_year]

good_groups = c("Tennesee/Georgia","Kentucky/Missouri", "Tennessee/Missouri", "Tennesee/North Carolina", "West Virginia/Kentucky",
               "Louisiana/Mississippi")

good_groups = c("Tennesee/Georgia","Kentucky/Missouri", "West Virginia/Kentucky","Tennesee/North Carolina",
               "Louisiana/Mississippi", "Ohio/Indiana", "Michigan/Indiana")

data <- data[group %in% good_groups]

# TRIM 
upper <- quantile(data$offering_yield_spread, 0.99, na.rm = T)
lower <- quantile(data$offering_yield_spread, 0.01, na.rm = T)
data[, offering_yield_spread_tr := ifelse(offering_yield_spread > upper | offering_yield_spread < lower, NA, offering_yield_spread)]

upper <- quantile(full_data$offering_yield_spread, 0.99, na.rm = T)
lower <- quantile(full_data$offering_yield_spread, 0.01, na.rm = T)
full_data[, offering_yield_spread_tr := ifelse(offering_yield_spread > upper | offering_yield_spread < lower, NA, offering_yield_spread)]

full_data[, promis_refund := ifelse(
  grepl("promissory|refund", issue_description, ignore.case = TRUE), 
  1, 
  0
)]

data[, promis_refund := ifelse(
  grepl("promissory|refund", issue_description, ignore.case = TRUE), 
  1, 
  0
)]

#data[, mean_debt := (state_godebt_limit + state_fullfaith + state_sep_debtservice_levy + state_sep_pledgerev + state_statutorylien)/5]
r1 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote |yrmonth + purp_broad|0|issue_id, data = full_data)
r2 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|yrmonth + purp_broad|0|issue_id, data = full_data)
r3 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|yrmonth + purp_broad |0|issue_id, data = data)
r4 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|yrmonth + group + purp_broad|0|issue_id, data = data)
r5 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group_year +  purp_broad|0|issue_id, data = data)
r6 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive  + state_go_vote|group + yrmonth + purp_broad|0|issue_id, data = data)



stargazer(r2, r1, r4, r3, r6, r5,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Border States Offering Yields',
          dep.var.caption = "",
          dep.var.labels = c("Yield Spread", 'Yield', "Yield Spread", "Yield", "Yield Spread", "Yield"),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "County ln(GDP)", "County ln(Pop)", "County ln(Pers. Inc)", "County ln(Emp)",
                               "Proactive State", "LTGO Allowed", "State GO Vote"),
          add.lines = list(c("YM FE", "Yes", "Yes", "Yes", "Yes", 'No', 'No'),
                           c("Border-State-YM FE", "No", "No", "No", "No", 'Yes', 'Yes'),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("State-Pair FE", "No", "No", "No", "No", "Yes", "Yes"),
                           c("Cluster", "Issue", "Issue", "Issue", "Issue", "Issue", "Issue")),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/raw_tables/full_sample_and_border_state_yields_v2.tex')




for (s in unique(full_data$state)) {
  #sub <- full_data[(state != s) & (state != 'IN')]
  sub <- full_data[(state != s)]
  r1 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity_mths + callable + sinkable + insured + rated + 
               ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote | yrmonth + purp_broad | 0 | issue_id, data = sub)
  print(paste0('Drop ', s))
  print(paste0(r1$coefficients[1], " p-value: ", r1$pval[1]))
}

sub <- full_data[(state != 'IN')]
r1 <- felm(offering_yield ~ city_go_vote*go_unlim + ln_amount + ln_maturity_mths + callable + sinkable + insured + rated  | yrmonth + purp_broad | 0 | issue_id, data = full_data)
r1 <- felm(offering_yield ~ city_go_vote*go_unlim  | yrmonth + purp_broad | 0 | issue_id, data = full_data)
r1 <- felm(offering_yield_spread ~ city_go_vote*go_unlim + ln_amount + ln_maturity_mths + callable + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote | yrmonth + purp_broad | 0 | issue_id, data = full_data)

r1 <- felm(offering_yield_tr ~ city_go_vote + ln_amount + ln_maturity_mths + callable + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote | year + purp_broad | 0 | issue_id, data = sub)
print(paste0('Drop ', s))
print(paste0(r1$coefficients[1], " p-value: ", r1$pval[1]))





# alternative FE options for border-state
data[, group_yrmonth := paste0(group, yrmonth)]
r1 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group+  purp_broad|0|issue_id, data = data)


r1 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp|group + year + purp_broad |0|issue_id, data = data)
r2 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp|group_year + purp_broad|0|issue_id, data = data)
r3 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group_year + purp_broad |0|issue_id, data = data)
r4 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive  + state_go_vote|group_year + purp_broad|0|issue_id, data = data)
r5 <- felm(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group_year + purp_broad |0|issue_id, data = data)
r6 <- felm(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group + year +  purp_broad|0|issue_id, data = data[!(group == 'Tennesee/North Carolina')])


stargazer(r1, r2, r3, r4, r5, r6,
          type = "latex",  table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          omit.table.layout = "n",
          font.size = 'small',
          column.sep.width = '-5pt',
          title = 'Border States Offering Yields',
          dep.var.caption = "",
          dep.var.labels = c('Yield', "Yield Spread", 'Yield', "Yield Spread",'Yield', "Yield Spread",'Yield', "Yield Spread"),
          covariate.labels = c("City GO Vote", "ln(Size)", "ln(Maturity)", "Callable", "Sinkable", "Insured", "Rated", 
                               "County ln(GDP)", "County ln(Pop)", "County ln(Pers. Inc)", "County ln(Emp)",
                               "Proactive State", "LTGO Allowed", "State GO Vote"),
          add.lines = list(c("Time FE", "Border-Year", "Border-Year", "Border-Year", "Border-Year", "Border-Year"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "Issue", "Issue", "Issue", "Issue", "Issue", "Issue", "Issue", "Issue")),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/border_state_bond_yield_20250730_superrestrictive.tex')



#----------------
# Investigate border state 
exp <- felm(city_go_vote ~ as.factor(yrmonth) + as.factor(purp_broad)|0|0|0, data = data)
exp2 <- felm(city_go_vote ~ as.factor(group) + as.factor(yrmonth) + as.factor(purp_broad)|0|0|0, data = data)
exp <- felm(city_go_vote ~ as.factor(yrmonth) + as.factor(purp_broad)|0|0|0, data = full_data)
group_year_variation <- data[, list(variation = uniqueN(city_go_vote)), .(group_year)]
nrow(group_year_variation[variation > 1])/nrow(group_year_variation) #34% of group-years have variation 
group_variation <- data[, list(variation = uniqueN(city_go_vote)), .(group)]
nrow(group_variation[variation > 1])/nrow(group_variation) #90% of groups have variation 

yrmonth_variation <- data[, list(variation = uniqueN(city_go_vote)), .(yrmonth)]
nrow(yrmonth_variation[variation > 1])/nrow(yrmonth_variation) #27% of groups have variation 

year_variation <- data[, list(variation = uniqueN(city_go_vote)), .(year)]
nrow(year_variation[variation > 1])/nrow(year_variation) #100% of years have variation 

purp_variation <- data[, list(variation = uniqueN(city_go_vote)), .(purp_broad)]
nrow(purp_variation[variation > 1])/nrow(purp_variation) #90% of purposes have variation 

groupym_variation <- data[, list(variation = uniqueN(city_go_vote)), .(group_ym)]
nrow(groupym_variation[variation > 1])/nrow(groupym_variation) #90% of purposes have variation 

#---------------------------------------

# articles
issuance_lvl <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl 20250801.csv')
#issuance_lvl <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Smaller Buffer/Border Matches RP Issuance Lvl 20250715.csv')
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

issuance_lvl[, group_year := paste0(group, year)]

purp_variation <- issuance_lvl[, list(variation = uniqueN(city_go_vote)), .(purp_broad)]
nrow(purp_variation[variation > 1])/nrow(purp_variation) #64% of purposes have variation 
group_year_variation <- issuance_lvl[, list(variation = uniqueN(city_go_vote)), .(group_year)]
nrow(group_year_variation[variation > 1])/nrow(group_year_variation) #42% of group-year have variation 

drop_groups = c('Michigan/Wisconsin', 
                'Ohio/Kentucky',
                'Michigan/Indiana', 
                'Ohio/Indiana')

issuance_lvl <- issuance_lvl[group %in% good_groups]
issuance_lvl <- issuance_lvl[!(group %in% drop_groups)]
r1 <- felm(total_rp_articles_12_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|group + year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|group + year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r3 <- felm(total_rp_articles_1_1 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|group + year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1, r2,
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
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/raw_tables/Border States Article Counts.tex'
)


r1 <- felm(total_rp_articles_12_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r2 <- felm(total_rp_articles_6_0 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)
r3 <- felm(total_rp_articles_1_1 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad|0|fips, data = issuance_lvl[go_unlim_bond_issuance == 1],psdef = FALSE)


stargazer(r1, r2,r3,
          type = "latex", table.placement = "H",
          digits = 3, omit.stat = c("ser", "f", "rsq"), df = F,
          report = "vc*t", no.space = T,
          dep.var.caption = "",
          omit.table.layout = "n",
          column.sep.width = '-5pt',
          title = 'Border States Issuance Level Counts of Articles',
          dep.var.labels = c("Total Articles [-12, 0]", "Total Articles [-6, 0]", "Total Articles [-1, +1]"),
          covariate.labels = c("City GO Vote",  "Number of Sources","ln(Size)", "County ln(GDP)", "County ln(Pop)", "County ln(Pers Inc)", "County ln(Emp)"),
          add.lines = list(c("Time FE", "Year", "Year", "Year", "Year"),
                           c("Purpose FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"),
                           c("Cluster", "County", 'County', "County", 'County')),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate/raw_tables/Border States Article Counts.tex'
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


