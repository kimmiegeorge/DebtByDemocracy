# output everything border state for restricted sample

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, fixest)
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation'

all_border_states <-c("Tennesee/Georgia","Kentucky/Missouri","Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                               "Tennesee/North Carolina", "Tennessee/Missouri")

#good_groups <-c("Tennesee/Georgia","Kentucky/Missouri","West Virginia/Kentucky",
 #               "Tennesee/North Carolina", "Tennessee/Missouri")

same_ltgo_border_states <-c("Tennesee/Georgia","Kentucky/Missouri", "West Virginia/Kentucky",
                      "Tennesee/North Carolina", "Tennessee/Missouri")

#----------------------------
# Load data 
#----------------------------

# first issuer lvl 
data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/250827_city_issuerlevel_yieldspread.dta'))
data <- data[city_rev_vote == 0 & !is.na(city_go_vote)]
data <- data[!is.na(ln_pop) & !is.na(ln_county_debt_other)]
# load border state issuers 
border_state = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 100000 20250828.csv')
border_state = unique(border_state[, .(seed_issuer_id, group, category)])
border_state = border_state[category != 'green']
border_state[, border_sample := 1]
data <- border_state[data, on = .(seed_issuer_id)]
#data[state == 'LA', state_ltgo_allowed := 0]
issuer_lvl <- data[border_sample == 1]
issuer_lvl[, issuer_yield_spread_win := Winsorize(issuer_yield_spread, val = quantile(issuer_yield_spread, probs = c(0.01, 0.99), na.rm = T))]


#  output laws 
border_pairs = unique(issuer_lvl[, list(issuers = .N), .(group, state, city_go_vote, state_ltgo_allowed, state_go_vote, glm_proactive)])
border_pairs = unique(issuer_lvl[, .(group, state, city_go_vote, state_ltgo_allowed, state_go_vote, glm_proactive)])
stargazer(border_pairs[order(group,city_go_vote)], summary = F, no.space = T, placement = 'H', type = 'latex', out = paste0(tbl_dir, '/border_pair_laws.tex'))

# articles
articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Buffer 100000 20250828.csv')
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
bonds <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Buffer 100000 20250827.csv')
#bonds <- fread('~/Dropbox/Voting on Bonds/bonds/Border States/Smaller Buffer/Border Matches All Mergent bonds 20250715.csv')
bonds[, yearq := as.yearqtr(offering_date)]
bonds[, qtr := substr(yearq, 6,7)]
bonds <- bonds[!is.na(pop)]
bonds[, yrmonth := format(offering_date, '%Y%m')]
bonds[, month := format(offering_date, '%m')]

bonds <- bonds[go_unlim == 1 & category != 'green']
bonds[, group_year := paste0(group, year)]
bonds[, county_purp := paste0(fips, purp_broad)]
bonds[, group_yq := paste0(group, yearq)]
bonds[, purp_year := paste0(purp_broad, year)]
bonds[, group_ym := paste0(group, yrmonth)]


#----------------------------
# FILTER
#----------------------------
articles_all <- articles[(group %in% all_border_states)]
articles_same <- articles[(group %in% same_ltgo_border_states)]


bonds_all <- bonds[(group %in% all_border_states)]
bonds_same <- bonds[(group %in% same_ltgo_border_states)]


issuer_lvl_all <- issuer_lvl[group %in% all_border_states]
issuer_lvl_same <- issuer_lvl[group %in% same_ltgo_border_states]

websites_all <-websites[group %in% all_border_states]
#----------------------------
# issuer lvl regs
#----------------------------

r1 <- feols(frac_utgo ~ city_go_vote|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(issuer_yield_spread ~ city_go_vote|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r4)
r5<- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r5)
r6 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote+ glm_proactive + state_ltgo_allowed|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r6)



etable(r1, r2, r3, r4,r5, r6,
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
                issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                city_go_vote = 'City GO Vote',
                state_go_vote = 'State GO Vote',
                state_ltgo_allowed = 'LTGO Allowed',
                glm_proactive = 'Practive State',
                ln_county_debt_other = 'ln(Non-issuer county debt)',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                fips = 'County'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/debt_choice_all.tex', 
       replace = TRUE)




#----------------------------
#  media regs
#----------------------------

test_coef = function(model, var1, var2){
  # Check the class of the model to determine which test to use
  if (inherits(model, "felm")) {
    # For felm models from lfe package
    hyp_test = car::wald(model, paste0(var1, ' = ', var2))
    chi_sq = hyp_test$Chisq[2]
    p_val = hyp_test$`Pr(>Chisq)`[2]
  } else {
    # Use linearHypothesis from car package for fixest models
    hyp_test = car::linearHypothesis(model, paste0(var1, ' - ', var2, ' = 0'))
    chi_sq = hyp_test$Chisq[2]
    p_val = hyp_test$`Pr(>Chisq)`[2]
  }
  
  return(c(round(chi_sq, 3), round(p_val, 3)))
}

articles_all[, coverage := ifelse(total_rp_articles_12_0 > 0, 1, 0)]
articles[, group_year := paste0(group, year)]
articles[, group_ym := paste0(group, ym)]
articles_all[, super_majority := ifelse(state == 'MO', 1, 0)]
articles_all[, majority := ifelse(city_go_vote == 1 & super_majority == 0, 1, 0)]
articles_all[, total_rp_articles_6_0_win := Winsorize(total_rp_articles_6_0_raw, val = quantile(total_rp_articles_6_0_raw, probs = c(0.01, 0.99)))]
articles_all[, total_rp_articles_12_0_win := Winsorize(total_rp_articles_12_0_raw, val = quantile(total_rp_articles_12_0_raw, probs = c(0.01, 0.99)))]
r1 <- feols(total_rp_articles_12_0~ super_majority + majority + unique_sources_12 + ln_num_cusip + ln_amount + ln_gdp + ln_pop + ln_pers_inc  +ln_employment|group + year, data = articles_all[go_unlim_bond_issuance == 1],vcov = vcov_cluster(~fips))
r2 <- feols(total_rp_articles_6_0_win ~ super_majority + majority  + unique_sources_12 + ln_amount  + ln_gdp + ln_pop + ln_pers_inc  +ln_employment|group + year + purp_broad, data = articles_all[go_unlim_bond_issuance == 1],  vcov = vcov_cluster(~fips))
r3 <- feols(total_rp_articles_12_6 ~ city_go_vote + unique_sources_12  + ln_amount + ln_gdp + ln_pop + ln_pers_inc  +ln_employment|group + year + purp_broad, data = articles_all[go_unlim_bond_issuance == 1], vcov = vcov_cluster(~fips))
summary(r1)
summary(r2)
summary(r3)

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
                total_rp_articles_6_0 ='Total Articles [-6, 0]',
                unique_sources_12 = 'Number of Sourcse',
                city_go_vote = 'Vote',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                ln_amount = 'Amount',
                group = 'Border', 
                year = 'Year',
                purp_broad = 'Purpose',
                group_ym = 'Group-YM',
                issue_id = 'Issue'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/articles.tex', 
       replace = TRUE)


#----------------------------
#  website
#----------------------------


# ROBUST
r1 <- feols(ln_debt_count ~ city_go_vote + ln_cum_num_issues  +  ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year, data = websites_all, vcov = vcov_cluster(~fips))
r2 <- feols(ln_bond_count ~ city_go_vote + ln_cum_num_issues  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year, data = websites_all, vcov = vcov_cluster(~fips))
r3 <- feols(percent_bond_or_debt_url ~ city_go_vote + ln_cum_num_issues  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp|group + year, data = websites_all, vcov = vcov_cluster(~fips))
summary(r1)
summary(r2)
summary(r3)



etable(r1, r2,r3,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(ln_debt_count ='Debt Count',
                ln_bond_count ='Bond Count',
                percent_bond_or_debt_url = 'Bond and Debt URLs',
                ln_cum_num_issues = 'Num Issues',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                year = 'Year',
                city_go_vote = 'Vote',
                purp_broad = 'Purpose',
                group_ym = 'Group-YM',
                issue_id = 'Issue'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/websites.tex', 
       replace = TRUE)


#----------------------------
#  bonds
#----------------------------
r1 <- feols(offering_yield ~ city_go_vote|group + yrmonth + purp_broad, data = bonds_all, vcov = vcov_cluster(~issue_id))
r2 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote|group + yrmonth + purp_broad, data = bonds_all, vcov = vcov_cluster(~issue_id))
r2b <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|group + yrmonth + purp_broad, data = bonds_all, vcov = vcov_cluster(~issue_id))
r3 <- feols(offering_yield_spread ~ city_go_vote|group + yrmonth + purp_broad, data = bonds_all, vcov = vcov_cluster(~issue_id))
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote|group + yrmonth + purp_broad, data = bonds_all, vcov = vcov_cluster(~issue_id))
r4b <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + 
              ln_gdp + ln_pop + ln_pers_inc + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed|group + yrmonth + purp_broad, data = bonds_all, vcov = vcov_cluster(~issue_id))



summary(r1)
summary(r2)
summary(r3)
summary(r4)

etable(r1, r2, r2b, r3, r4, r4b,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(offering_yield ='Yield',
                offering_yield_spread ='Yield Spread',
                city_go_vote = 'Vote',
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
                state_ltgo_allowed = 'LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'Border', 
                yrmonth = 'YM',
                purp_broad = 'Purpose',
                group_ym = 'Group-YM',
                issue_id = 'Issue'),
       placement = 'H',
       file = '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/2508_borderinvestigation/bond_yield.tex', 
       replace = TRUE)



