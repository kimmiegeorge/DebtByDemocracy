# output everything border state for restricted sample

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, fixest)
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2507_tableupdate'

good_groups <-c("Tennesee/Georgia","Kentucky/Missouri","Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                               "Tennesee/North Carolina", "Tennessee/Missouri")

#good_groups <-c("Tennesee/Georgia","Kentucky/Missouri","West Virginia/Kentucky",
 #               "Tennesee/North Carolina", "Tennessee/Missouri")

good_groups_allgo <-c("Tennesee/Georgia","Kentucky/Missouri", "West Virginia/Kentucky",
                      "Louisiana/Mississippi","Tennesee/North Carolina", "Tennessee/Missouri")

good_groups_utgo <-c( "Michigan/Indiana",
                "Ohio/Indiana")

#----------------------------
# Load data 
#----------------------------

# first issuer lvl 
data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/250701_city_issuerlevel_yieldspread.dta'))
data <- data[city_rev_vote == 0 & !is.na(city_go_vote)]
data <- data[!is.na(ln_pop) & !is.na(ln_county_debt_other)]
# load border state issuers 
border_state = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 100000 20250903.csv')
border_state = unique(border_state[, .(seed_issuer_id, group, category)])
border_state = border_state[category != 'green']
border_state[, border_sample := 1]
data <- border_state[data, on = .(seed_issuer_id)]
#data[state == 'LA', state_ltgo_allowed := 0]
issuer_lvl <- data[border_sample == 1]
issuer_lvl[, issuer_yield_spread_win := Winsorize(issuer_yield_spread, val = quantile(issuer_yield_spread, probs = c(0.01, 0.99), na.rm = T))]
issuer_lvl <- issuer_lvl[state != 'IN']

# now media 

# articles
articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Buffer 100000 20250903.csv')
#articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Smaller Buffer/Border Matches RP Issuance Lvl 20250715.csv')
articles = as.data.table(articles)
setnames(articles, 'total_rp_articles_6_2', 'total_rp_articles_6_1')
setnames(articles, 'total_rp_articles_12_10', 'total_rp_articles_12_0')
articles = articles[!is.na(ln_employment) & !is.na(ln_pop) & !is.na(ln_percap_inc) & !is.na(ln_pers_inc) & !is.na(ln_gdp)]
articles = articles[!is.na(city_go_vote)]
articles[, issuance_month_total_articles_raw := issuance_month_total_articles]
articles[, issuance_month_total_articles := log(1 + issuance_month_total_articles)]
articles[, total_rp_articles_1_1_raw := total_rp_articles_1_1]
articles[, total_rp_articles_1_1 := log(1+total_rp_articles_1_1)]
articles[, total_rp_articles_1_0_raw := total_rp_articles_1_0]
articles[, total_rp_articles_1_0 := log(1+total_rp_articles_1_0)]
articles[, total_rp_articles_6_0_raw := total_rp_articles_6_0]
articles[, total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
articles[, total_rp_articles_6_1_raw := total_rp_articles_6_1]
articles[, total_rp_articles_6_1 := log(1+total_rp_articles_6_1)]
articles[, total_rp_articles_12_0_raw := total_rp_articles_12_0]
articles[, total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]
articles[, rolling_sum_monthly_article_count_6 := log(1+rolling_sum_monthly_article_count_6)]
articles[, rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]
# quarter 
articles[, quarter := ifelse(month %in% c(1,2,3), 1, 
                                 ifelse(month %in% c(4,5,6), 2, 
                                        ifelse(month %in% c(7,8,9), 3, 4)))]
articles[, yq := paste0(year, quarter)]
articles[, ym := paste0(year, month)]
articles[, unique_sources_6_raw := unique_sources_6]
articles[, unique_sources_6 := log(1+unique_sources_6)]
articles[, unique_sources_12_raw := unique_sources_12]
articles[, unique_sources_12 := log(1+unique_sources_12)]
articles <- articles[category != 'green']
articles[, group_year := paste0(group, year)]

# now websites 
websites <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_20250312.csv')
websites <- websites[total_subs > 1]

# now bonds 
bonds <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 100000 20250903.csv')
#bonds <- fread('~/Dropbox/Voting on Bonds/bonds/Border States/Smaller Buffer/Border Matches All Mergent bonds 20250715.csv')
bonds[, yearq := as.yearqtr(offering_date)]
bonds[, qtr := substr(yearq, 6,7)]
bonds <- bonds[!is.na(pop)]
bonds[, yrmonth := format(offering_date, '%Y%m')]
bonds[, month := format(offering_date, '%m')]

#bonds <- bonds[go_unlim == 1 & category != 'green']
bonds <- bonds[go_unlim == 1 | go_lim == 1]
bonds[, group_year := paste0(group, year)]
bonds[, county_purp := paste0(fips, purp_broad)]
bonds[, group_yq := paste0(group, yearq)]
bonds[, purp_year := paste0(purp_broad, year)]
bonds[, group_ym := paste0(group, yrmonth)]


#----------------------------
# FILTER
#----------------------------
articles <- articles[(group %in% good_groups)]
bonds <- bonds[(group %in% good_groups)]
issuer_lvl_allgo <- issuer_lvl[group %in% good_groups]
#----------------------------
# issuer lvl regs
#----------------------------


r4a1 <- feols(frac_utgo ~ city_go_vote|group, data = issuer_lvl_allgo, vcov = vcov_cluster(~fips))
summary(r4a1)
r4b1 <- feols(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group, data = issuer_lvl_allgo, vcov = vcov_cluster(~fips))
summary(r4b1)
r4c1 <- feols(frac_utgo ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group, data = issuer_lvl_allgo, vcov = vcov_cluster(~fips))
summary(r4c1)  
r4e1 <- feols(frac_rev ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote |group, data = issuer_lvl_allgo, vcov = vcov_cluster(~fips))
summary(r4e1)


etable(r4a1, r4b1, r4c1, r4e1,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(frac_utgo ='Pct UTGO', 
                frac_ltgo = 'Pct LTGO',
                frac_rev = 'Pct Rev',
                city_go_vote = 'City GO Vote',
                ln_county_debt_other = 'ln(Non-issuer county debt)',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                fips = 'County'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/debt_choice.tex', 
       replace = TRUE)


r4a1 <- feols(issuer_yield_spread ~ city_go_vote|group, data = issuer_lvl_allgo,  vcov = vcov_cluster(~fips))
summary(r4a1)
r4b1 <- feols(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp|group, data = issuer_lvl_allgo,  vcov = vcov_cluster(~fips))
summary(r4b1)
r4c1 <- feols(issuer_yield_spread ~ city_go_vote + ln_county_debt_other + ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote|group, data = issuer_lvl_allgo,  vcov = vcov_cluster(~fips))
summary(r4c1)

etable(r4a1, r4b1, r4c1,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(issuer_yield_spread ='Yield Spread',
                city_go_vote = 'City GO Vote',
                ln_county_debt_other = 'ln(Non-issuer county debt)',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                fips = 'County'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/debt_yield.tex', 
       replace = TRUE)



#----------------------------
#  media regs
#----------------------------

articles[, coverage := ifelse(total_rp_articles_6_0 > 0, 1, 0)]
articles[, group_year := paste0(group, year)]
articles[, group_ym := paste0(group, ym)]
go_unlim_articles <- articles[go_unlim_bond_issuance == 1]
go_unlim_articles[, total_rp_articles_12_0_win := Winsorize(total_rp_articles_12_0_raw, val = quantile(total_rp_articles_12_0_raw, probs = c(0.01, 0.99)))]
go_unlim_articles[, total_rp_articles_6_0_win := Winsorize(total_rp_articles_6_0_raw, val = quantile(total_rp_articles_6_0_raw, probs = c(0.01, 0.99)))]

go_unlim_articles[, supermajority := ifelse(state %in% c('CA', 'ID', 'MO', 'ND', 'OK', 'SD', 'WA'), 1, 0)]
go_unlim_articles[, majority := ifelse(city_go_vote == 1 & supermajority == 0, 1, 0)]
go_unlim_articles[, max_sources := max(unique_sources_12_raw), .(seed_issuer_id)]
articles[, go := ifelse(go_unlim_bond_issuance ==1 | go_lim_bond_issuance == 1, 1, 0)]
#go_umlim_articles <- go_unlim_articles[max_sources > 0]
r1 <- felm(total_rp_articles_6_0~ city_go_vote*go + unique_sources_12 + ln_amount  + ln_gdp + ln_pers_inc  + ln_employment|group + year + purp_broad|0|fips, data = articles)
r2 <- felm(total_rp_articles_12_0~ city_go_vote*go + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|group + year + purp_broad|0|fips, data = articles)
r3 <- felm(total_rp_articles_1_1 ~ city_go_vote + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_percap_inc + ln_employment|group + year + purp_broad|0|fips, data = articles[go_unlim_bond_issuance == 1],psdef = FALSE)
summary(r1)
summary(r2)
summary(r3)

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
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/articles.tex')


r1 <- feols(total_rp_articles_12_0~ city_go_vote*go + unique_sources_12 + ln_amount  + ln_gdp + ln_pers_inc  + ln_employment|group + year + purp_broad, data = articles, vcov = vcov_cluster(~fips))
r2 <- feols(total_rp_articles_6_0~ city_go_vote*go + unique_sources_12 + ln_amount + ln_gdp + ln_pers_inc + ln_employment|group + year + purp_broad, data = articles, vcov = vcov_cluster(~fips))



etable(r1, r2, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(total_rp_articles_12_0 ='Total Articles [-12, 0]',
                total_rp_articles_6_0 = 'Total Articles [-6, 0]',
                unique_sources_12 = 'Num Sources',
                city_go_vote = 'Vote',
                ln_amount = 'Amount',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                go = 'GO',
                year = 'Year',
                purp_broad = 'Purpose'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/border_sample_alt_articles.tex', 
       replace = TRUE)



#----------------------------
#  website
#----------------------------


# ROBUST
r1 <- felm(ln_debt_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year|0|fips, data = websites)
r2 <- felm(ln_all_finance_count ~ city_go_vote + ln_cum_num_issues  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year|0|fips, data = websites)
r3 <- felm(percent_debt_url ~ city_go_vote + ln_cum_num_issues  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year|0|fips, data = websites)
summary(r1)
summary(r2)
summary(r3)


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
          add.lines = list(c("Border FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"), 
                           c("Year FE", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes", "Yes"), 
                           c("Cluster", "County", "County", "County", "County", "Robust", "Robust", "Robust", "Robust")),
          out = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/websites.tex')


#----------------------------
#  bonds
#----------------------------
bonds[, promis_refund := ifelse(
  grepl("promissory|refund", issue_description, ignore.case = TRUE), 
  1, 
  0
)]
bonds <- bonds[promis_refund == 0]
r1 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group + yrmonth + purp_broad, data = bonds[group %in% good_groups], vcov = vcov_cluster(~issue_id))
r2 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
             ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive+ state_go_vote|group_ym + purp_broad, data = bonds[group %in% good_groups], vcov = vcov_cluster(~issue_id))
summary(r1)
summary(r2)

etable(r1, r2,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(ln_pop ='Yield Spread',
                city_go_vote = 'City GO Vote',
                ln_amount = 'Amount',
                ln_maturity_mths = 'Maturity',
                callable = 'Callable',
                sinkable = 'Sinkable',
                insured = 'Insured', 
                rated = 'Rated',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                glm_proactive = 'Proactive State',
                state_go_vote = 'State GO Vote',
                group = 'Border', 
                yrmonth = 'YM',
                purp_broad = 'Purpose',
                group_ym = 'Group-YM',
                issue_id = 'Issue'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/bond_yield.tex', 
       replace = TRUE)


bonds <- bonds[!(group %in% c("Ohio/Kentucky",  "Michigan/Wisconsin" ))]
bonds[, go := go_unlim == 1 | go_lim == 1]
r1 <- feols(offering_yield_spread ~ city_go_vote*go + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
              ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive + state_go_vote|group + yrmonth + purp_broad, data = bonds[group %in% good_groups], vcov = vcov_cluster(~issue_id))
r2 <- feols(offering_yield_spread ~ city_go_vote*go + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
              ln_gdp + ln_pop + ln_pers_inc + ln_emp + glm_proactive+ state_go_vote|group_ym + purp_broad, data = bonds[group %in% good_groups], vcov = vcov_cluster(~issue_id))
summary(r1)
summary(r2)

