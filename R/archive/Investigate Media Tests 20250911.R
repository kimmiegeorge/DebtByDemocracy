# Merge Full Sample Yield Tests with Media Coverage - XS Test 
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, car,)

tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"
 
#_______________Bonds________________
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
issuers <- full_data[, list(fips = first(fips), issuer_long_name = first(issuer_long_name)), .(seed_issuer_id)]
full_data <- full_data[city == 1 &!is.na(city_go_vote) & city_rev_vote == 0]
#full_data <- full_data[city == 1 &!is.na(city_go_vote)]
full_data <- full_data[go_unlim == 1]



#_______________Issuance Level________________
issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_250908.csv'))
#setnames(issuance_lvl, 'total_rp_articles_12_10', 'total_rp_articles_12_0')
issuance_lvl[, log_total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]
issuance_lvl[, log_total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]

# keep seed issuer, year and month and merge with ful data 
issuance_lvl_merge <- issuance_lvl[, .(seed_issuer_id, year, month, unique_sources_12, total_rp_articles_6_0,rolling_sum_monthly_article_count_12,
                                       total_rp_articles_12_0, total_rp_articles_1_1, log_total_rp_articles_12_0, log_total_rp_articles_6_0)]

issuance_lvl[, go := ifelse(go_unlim_bond_issuance == 1 | go_lim_bond_issuance == 1, 1, 0)]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & city_rev_vote == 0]
#issuance_lvl <- issuance_lvl[!is.na(city_go_vote)]

# filter to cities in the ravenpack data
full_data <- full_data[seed_issuer_id %in% issuance_lvl_merge$seed_issuer_id]
full_data <- issuance_lvl_merge[full_data, on = .(seed_issuer_id, year, month)]
full_data[, log_rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]

#_______________Indicators________________
full_data[, high_articles_6_0 := ifelse(total_rp_articles_6_0 > median(total_rp_articles_6_0, na.rm = T), 1, 0)]
full_data[, high_articles_12_0 := ifelse(total_rp_articles_12_0 > median(total_rp_articles_12_0, na.rm = T), 1, 0)]
full_data[, ym := paste0(year, month)]



#_______________Border________________
# load border state issuers
border_full_data = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250908.csv')
border_full_data[, ym := paste0(year, month)]
for_merge <- unique(full_data[, .(seed_issuer_id, ym, total_rp_articles_6_0, rolling_sum_monthly_article_count_12,
                                  total_rp_articles_12_0, high_articles_6_0, high_articles_12_0, log_total_rp_articles_12_0,log_total_rp_articles_6_0, unique_sources_12 )])
border_full_data <- for_merge[border_full_data, on = .(seed_issuer_id, ym)]
border_full_data <- border_full_data[seed_issuer_id %in% issuance_lvl_merge$seed_issuer_id]
border_full_data[, log_rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]

good_groups <-c("Tennesee/Georgia","Kentucky/Missouri","Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                "Tennesee/North Carolina", "Tennessee/Missouri")

#border_full_data <- border_full_data[group %in% good_groups]
#border_full_data <- border_full_data[category != 'grey']
#border_full_data <- border_full_data[go_unlim == 1 |go_lim == 1]
border_full_data <- border_full_data[go_unlim == 1]

# articles
border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000 20250908.csv')
#articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Smaller Buffer/Border Matches RP Issuance Lvl 20250715.csv')
border_articles = as.data.table(border_articles)
#setnames(border_articles, 'total_rp_articles_6_2', 'total_rp_articles_6_1')
#setnames(border_articles, 'total_rp_articles_12_10', 'total_rp_articles_12_0')
border_articles[, log_total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]
border_articles[, log_total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
#border_articles[, log_total_rp_articles_12_neg1 := log(1+total_rp_articles_12_neg1)]
#border_articles[, log_total_rp_articles_6_neg1 := log(1+total_rp_articles_6_neg1)]
border_articles[, go := ifelse(go_unlim_bond_issuance == 1 | go_lim_bond_issuance == 1, 1, 0)]
#border_articles <- border_articles[group %in% good_groups]
#border_articles <- border_articles[group %in% good_groups]


# websites 
websites <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_20250312.csv')
websites <- websites[, list(bond_debt_count = mean(bond_debt_count)), .(seed_issuer_id)]
border_full_data <- websites[border_full_data, on = .(seed_issuer_id)]


#_______________descriptives of high/low media by vote ________________






#_______________Regressions________________
full_data[, purpose_year := paste0(purp_broad, year)]

full_data[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]
border_full_data[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]

r1 <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r2)
r3 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r4)

r1b <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |group + ym + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r1b)
r2b <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum  + state_go_vote|group + ym + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r2b)
r3b <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |group + ym + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r3b)
r4b <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum +  state_go_vote|group + ym  + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r4b)



r1 <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |ym + purp_broad, data = full_data vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r2)
r3 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r4)

r1b <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |group + ym + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r1b)
r2b <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum  + state_go_vote|group + ym + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r2b)
r3b <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum |group + ym + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r3b)
r4b <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum +  state_go_vote|group + ym  + purp_broad, data = border_full_data[category != 'grey' & purp_broad != 'genpubimprov'], vcov = vcov_cluster(~issue_id))
summary(r4b)



etable(r1, r2, r3, r4, r1b, r2b, r3b, r4b,
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       fontsize = 'small',
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(offering_yield ='Yield',
                offering_yield_spread ='Yield Spread',
                city_go_vote = 'Vote',
                high_articles_12_0 = 'High Articles [-12, 0]',
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
                unique_sources_12 = 'Num Sources',
                rolling_sum = 'City News Coverage',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'Border', 
                yrmonth = 'YM',
                purp_broad = 'Purpose',
                ym = 'Year-Month',
                issue_id = 'Issue'),
       placement = 'H',
       file = paste0(tables_wd, '/bond_yield_by_coverage.tex'), 
       replace = TRUE)





r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data[high_articles_12_0 == 0 & year > 2014], vcov = vcov_cluster(~issue_id))
summary(r1)
r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data[high_articles_12_0 == 1 & year > 2014], vcov = vcov_cluster(~issue_id))
summary(r1)
r3 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote |ym + purp_broad, data = full_data[high_articles_12_0 == 0 & year > 2014], vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data[high_articles_12_0 == 1 & year > 2014], vcov = vcov_cluster(~issue_id))
summary(r4)


r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r1)
r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r1)
r3 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote |year + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r4)


r1 <- feols(offering_yield ~ city_go_vote*bond_debt_count + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|year + purp_broad + group, data = border_full_data[category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r1)
r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r1)
r3 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + rolling_sum + glm_proactive + state_ltgo_allowed + state_go_vote |ym + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r4)



#_______________Ravenpack________________
issuance_lvl[, covered_12_0 := ifelse(total_rp_articles_12_0 > 0, 1, 0)]
issuance_lvl[, covered_6_0 := ifelse(total_rp_articles_6_0 > 0, 1, 0)]
issuance_lvl[, total_rp_articles_12_0_win := Winsorize(total_rp_articles_12_0, val = quantile(total_rp_articles_12_0, probs = c(0.01, 0.99)))]
issuance_lvl[, total_rp_articles_6_0_win := Winsorize(total_rp_articles_6_0, val = quantile(total_rp_articles_6_0, probs = c(0.01, 0.99)))]
border_articles[, covered_12_0 := ifelse(total_rp_articles_12_0 > 0, 1, 0)]
border_articles[, covered_6_0 := ifelse(total_rp_articles_6_0 > 0, 1, 0)]

state_year_rev <- issuance_lvl[rev_bond_issuance == 1, list(avg_rev_bond_cov = mean(total_rp_articles_12_0)), .(state)]
border_articles <- state_year_rev[border_articles, on = .(state)]
issuance_lvl <- state_year_rev[issuance_lvl, on = .(state)]
border_articles <- issuers[border_articles, on = .(seed_issuer_id)]
border_articles[, total_rp_articles_12_0_win := Winsorize(total_rp_articles_12_0, val = quantile(total_rp_articles_12_0, probs = c(0.01, 0.99)))]
border_articles[, total_rp_articles_6_0_win := Winsorize(total_rp_articles_6_0, val = quantile(total_rp_articles_6_0, probs = c(0.01, 0.99)))]

border_articles[, total_rp_articles_12_0_scaled_by_articles_win := Winsorize(total_rp_articles_12_0_scaled_by_articles, val = quantile(total_rp_articles_12_0_scaled_by_articles, probs = c(0.01, 0.99)))]
border_articles[, total_rp_articles_6_0_scaled_by_articles_win := Winsorize(total_rp_articles_6_0_scaled_by_articles, val = quantile(total_rp_articles_6_0_scaled_by_articles, probs = c(0.01, 0.99)))]
issuance_lvl[, total_rp_articles_12_0_scaled_by_articles_win := Winsorize(total_rp_articles_12_0_scaled_by_articles, val = quantile(total_rp_articles_12_0_scaled_by_articles, probs = c(0.01, 0.99)))]
issuance_lvl[, total_rp_articles_6_0_scaled_by_articles_win := Winsorize(total_rp_articles_6_0_scaled_by_articles, val = quantile(total_rp_articles_6_0_scaled_by_articles, probs = c(0.01, 0.99)))]


issuance_lvl[, log_rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]
border_articles[, log_rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]

issuance_lvl[, log_total_rp_articles_12_0_scaled_by_articles := log(1+total_rp_articles_12_0_scaled_by_articles)]
border_articles[, log_total_rp_articles_12_0_scaled_by_articles := log(1+total_rp_articles_12_0_scaled_by_articles)]


issuance_lvl[, log_total_rp_articles_6_0_scaled_by_articles := log(1+total_rp_articles_6_0_scaled_by_articles)]
border_articles[, log_total_rp_articles_6_0_scaled_by_articles := log(1+total_rp_articles_6_0_scaled_by_articles)]

issuance_lvl[, articles_1_1_scaled := total_rp_articles_1_1/rolling_sum_monthly_article_count_12]
issuance_lvl[is.infinite(articles_1_1_scaled), articles_1_1_scaled := 0]

issuance_lvl[, log_total_rp_articles_12_neg1 := log(1+total_rp_articles_12_neg1)]
issuance_lvl[, log_total_rp_articles_6_neg1 := log(1+total_rp_articles_6_neg1)]
border_articles[, log_total_rp_articles_12_neg1 := log(1+total_rp_articles_12_neg1)]
border_articles[, log_total_rp_articles_6_neg1 := log(1+total_rp_articles_6_neg1)]

# winsorized counts work here 
r1 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go   + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl,vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(log_total_rp_articles_6_0 ~ city_go_vote*go  +  unique_sources_12   + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year+ purp_broad , data = issuance_lvl,vcov = vcov_cluster(~fips))
summary(r2)

r1 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go   + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[!(state %in% c('MI', 'OH', 'WA'))],vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(log_total_rp_articles_6_0 ~ city_go_vote*go  +  unique_sources_12   + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year+ purp_broad , data = issuance_lvl[!(state %in% c('MI', 'OH', 'WA'))],vcov = vcov_cluster(~fips))
summary(r2)

issuance_lvl[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]
border_articles[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]
r1 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go   + rolling_sum  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(log_total_rp_articles_6_0 ~ city_go_vote*go  +  rolling_sum   + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year+ purp_broad , data = issuance_lvl[go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r2)


r1 <- feols(log_total_rp_articles_6_0 ~ go_unlim_bond_issuance + go_lim_bond_issuance   + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[city_go_vote ==1],vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(log_total_rp_articles_6_0 ~ city_go_vote*go  +  rolling_sum   + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year+ purp_broad , data = issuance_lvl[go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r2)


r3 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category != 'grey'],vcov = vcov_cluster(~fips))
summary(r3)
r4<- feols(log_total_rp_articles_6_0~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category != 'grey'],vcov = vcov_cluster(~fips))
summary(r4)

r3 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category == 'green'],vcov = vcov_cluster(~fips))
summary(r3)
r4<- feols(log_total_rp_articles_6_0~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category == 'green'],vcov = vcov_cluster(~fips))
summary(r4)

r3 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category != 'grey' & go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r3)
r4<- feols(log_total_rp_articles_6_0~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category != 'grey' & go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r4)


r3 <- feols(log_total_rp_articles_12_0~ city_go_vote  + log_rolling_sum_monthly_article_count_12 +  ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[go_unlim_bond_issuance == 1  & category != 'grey'],vcov = vcov_cluster(~fips))
summary(r3)
r3 <- feols(log_total_rp_articles_12_0~ city_go_vote  + log_rolling_sum_monthly_article_count_12  + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1],vcov = vcov_cluster(~fips))
summary(r3)

#_______________Regressions________________

# TABULATE THE YIELD TESTS, THE GO INTERACTION FOR UNLIMITED ONLY AND THE GO UNLIM ONLY MEDIA REGS 

r1 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go   + rolling_sum  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(log_total_rp_articles_6_0 ~ city_go_vote*go  +  rolling_sum   + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year+ purp_broad , data = issuance_lvl[go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(log_total_rp_articles_12_0 ~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category != 'grey' & go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r3)
r4<- feols(log_total_rp_articles_6_0~ city_go_vote*go  + rolling_sum + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[category != 'grey' & go_lim_bond_issuance == 0],vcov = vcov_cluster(~fips))
summary(r4)

etable(r1, r2, r3, r4, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       fontsize = 'small',
       order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(log_total_rp_articles_12_0 ='Total Articles [-12, 0]',
                log_total_rp_articles_6_0 ='Total Articles [-6, 0]',
                city_go_vote = 'Vote',
                go = 'GO',
                rolling_sum = 'City News Coverage',
                ln_amount = 'Amount',
                ln_maturity_mths = 'Maturity',
                callable = 'Callable',
                sinkable = 'Sinkable',
                insured = 'Insured', 
                rated = 'Rated',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                unique_sources_12 = 'Num Sources',
                rolling_sum = 'City News Coverage',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'Border', 
                yrmonth = 'YM',
                purp_broad = 'Purpose',
                year = 'Year',
                ym = 'Year-Month',
                issue_id = 'Issue'),
       placement = 'H',
       file = paste0(tables_wd, '/total_articles_go_rev.tex'), 
       replace = TRUE)


r1 <- feols(log_total_rp_articles_12_0~ city_go_vote  + rolling_sum  + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & year > 2014],vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(log_total_rp_articles_6_0~ city_go_vote  + rolling_sum  + ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|year + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1],vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(log_total_rp_articles_12_0~ city_go_vote  + rolling_sum +  ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[go_unlim_bond_issuance == 1  & category != 'grey' & year > 2014],vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(log_total_rp_articles_6_0~ city_go_vote  + rolling_sum +  ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment|group + year + purp_broad , data = border_articles[go_unlim_bond_issuance == 1  & category != 'grey'],vcov = vcov_cluster(~fips))
summary(r4)



etable(r1, r2, r3, r4, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       fontsize = 'small',
       digits = 3, 
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
      # order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(log_total_rp_articles_12_0 ='Total Articles [-12, 0]',
                log_total_rp_articles_6_0 ='Total Articles [-6, 0]',
                city_go_vote = 'Vote',
                go = 'GO',
                rolling_sum = 'City News Coverage',
                ln_amount = 'Amount',
                ln_maturity_mths = 'Maturity',
                callable = 'Callable',
                sinkable = 'Sinkable',
                insured = 'Insured', 
                rated = 'Rated',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                unique_sources_12 = 'Num Sources',
                rolling_sum = 'City News Coverage',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'Border', 
                yrmonth = 'YM',
                purp_broad = 'Purpose',
                year = 'Year',
                ym = 'Year-Month',
                issue_id = 'Issue'),
       placement = 'H',
       file = paste0(tables_wd, '/total_articles_go_only.tex'), 
       replace = TRUE)

