# Merge Full Sample Yield Tests with Media Coverage - XS Test 
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, car)

tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"

# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

#_______________Bonds________________
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
issuers <- full_data[, list(fips = first(fips), issuer_long_name = first(issuer_long_name)), .(seed_issuer_id)]
full_data <- full_data[city == 1 &!is.na(city_go_vote) & city_rev_vote == 0]
full_data <- full_data[go_unlim == 1]

#_______________Issuance Level________________
issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_250908.csv'))
issuance_lvl[, log_total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]
issuance_lvl[, log_total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]

# keep seed issuer, year and month and merge with full data 
issuance_lvl_merge <- issuance_lvl[, .(seed_issuer_id, year, month, unique_sources_12, total_rp_articles_6_0,rolling_sum_monthly_article_count_12,
                                       total_rp_articles_12_0, total_rp_articles_1_1, log_total_rp_articles_12_0, log_total_rp_articles_6_0)]

issuance_lvl[, go := ifelse(go_unlim_bond_issuance == 1 | go_lim_bond_issuance == 1, 1, 0)]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & city_rev_vote == 0]

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

border_full_data <- border_full_data[go_unlim == 1]

# articles
border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000 20250908.csv')
border_articles = as.data.table(border_articles)
border_articles[, log_total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]
border_articles[, log_total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
border_articles[, go := ifelse(go_unlim_bond_issuance == 1 | go_lim_bond_issuance == 1, 1, 0)]

# websites 
websites <- fread('~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_20250312.csv')
websites <- websites[, list(bond_debt_count = mean(bond_debt_count)), .(seed_issuer_id)]
border_full_data <- websites[border_full_data, on = .(seed_issuer_id)]

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

# ===============================================================================
# ANALYSIS
# ===============================================================================

#_______________Regressions - Yields________________
full_data[, purpose_year := paste0(purp_broad, year)]

full_data[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]
border_full_data[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]

# Main yield regressions
r1 <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 |ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r2)
r3 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 |ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data, vcov = vcov_cluster(~issue_id))
summary(r4)

# Border regressions
r1b <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 |group + ym + purp_broad, data = border_full_data[category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r1b)
r2b <- feols(offering_yield ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12  + state_go_vote|group + ym + purp_broad, data = border_full_data[category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r2b)
r3b <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 |group + ym + purp_broad, data = border_full_data[category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r3b)
r4b <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|group + ym  + purp_broad, data = border_full_data[category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r4b)

# Export main table
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


ym_variation = full_data[high_articles_12_0 == 1, mean(city_go_vote), .(ym)]
print(nrow(ym_variation[!(V1 %in% c(0,1))])/nrow(ym_variation)) # 68% of ym have variation in full sample
year_variation = full_data[high_articles_12_0 == 1, mean(city_go_vote), .(year)]
print(nrow(year_variation[!(V1 %in% c(0,1))])/nrow(year_variation)) # 100% of year have variation in full sample
ym_variation = border_full_data[high_articles_12_0 == 1, mean(city_go_vote), .(ym)]
print(nrow(ym_variation[!(V1 %in% c(0,1))])/nrow(ym_variation)) # 5% of ym have variation in full sample
year_variation = border_full_data[high_articles_12_0 == 1, mean(city_go_vote), .(year)]
print(nrow(year_variation[!(V1 %in% c(0,1))])/nrow(year_variation)) # 44% of year have variation in full sample

# Subsample regressions by high/low media coverage
r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data[rolling_sum_monthly_article_count_12 >0], vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data[high_articles_12_0 == 1], vcov = vcov_cluster(~issue_id))
summary(r2)
r1b <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|year + purp_broad, data = full_data[rolling_sum_monthly_article_count_12 >0], vcov = vcov_cluster(~issue_id))
summary(r1b)
r2b <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|year + purp_broad, data = full_data[high_articles_12_0 == 1], vcov = vcov_cluster(~issue_id))
summary(r2b)
r3 <- feols(offering_yield_spread ~ city_go_vote*log_total_rp_articles_12_0 + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote |ym + purp_broad, data = full_data[rolling_sum_monthly_article_count_12 > 0], vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|ym + purp_broad, data = full_data[high_articles_12_0 == 1], vcov = vcov_cluster(~issue_id))
summary(r4)
r3b <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote |year + purp_broad, data = full_data[high_articles_12_0 == 0], vcov = vcov_cluster(~issue_id))
summary(r3b)
r4b <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + glm_proactive + state_ltgo_allowed + state_go_vote|year + purp_broad, data = full_data[unique_sources_12 > 5], vcov = vcov_cluster(~issue_id))
summary(r4b)

etable(r1, r2, r1b, r2b, r3, r4, r3b, r4b,
       title = 'Full Sample Yield Spreads by Media Coverage',
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       fontsize = 'small',
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       headers = c('No Coverage', 'Coverage', 'No Coverage', 'Coverage', 'No Coverage', 'Coverage', 'No Coverage', 'Coverage'),
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
                year = 'Year',
                purp_broad = 'Purpose',
                ym = 'Year-Month',
                issue_id = 'Issue'),
       placement = 'H',
       file = paste0(tables_wd, '/bond_yield_full_sample_split_by_cov.tex'), 
       replace = TRUE)




# Border subsample regressions
r1 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|ym + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote|ym + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r2)
r1b <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey' ], vcov = vcov_cluster(~issue_id))
summary(r1b)
r2b <- feols(offering_yield ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r2b)
r3 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote |ym + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|ym + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r4)
r3b <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + state_go_vote |year + purp_broad + group, data = border_full_data[high_articles_12_0 == 0 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r3b)
r4b <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 +  state_go_vote|year + purp_broad + group, data = border_full_data[high_articles_12_0 == 1 & category != 'grey'], vcov = vcov_cluster(~issue_id))
summary(r4b)


etable(r1, r2, r1b, r2b, r3, r4, r3b, r4b,
       title = 'Border Sample Yield Spreads by Media Coverage',
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       fontsize = 'small',
       digits.stats = 2,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       headers = c('No Coverage', 'Coverage', 'No Coverage', 'Coverage', 'No Coverage', 'Coverage', 'No Coverage', 'Coverage'),
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
                year = 'Year',
                purp_broad = 'Purpose',
                ym = 'Year-Month',
                issue_id = 'Issue'),
       placement = 'H',
       file = paste0(tables_wd, '/bond_yield_border_sample_split_by_cov.tex'), 
       replace = TRUE)





#_______________Regressions - Media________________

# Media coverage regressions
issuance_lvl[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]
border_articles[, rolling_sum := log(1 + (rolling_sum_monthly_article_count_12 - total_rp_articles_12_0))]

issuance_lvl <- issuance_lvl[!is.na(ln_employment)]
issuance_lvl <- issuance_lvl[!is.na(rolling_sum) & !is.infinite(rolling_sum)]
border_articles <- border_articles[!is.na(ln_employment)]
border_articles <- border_articles[!is.na(rolling_sum) & !is.infinite(rolling_sum)]

# indicator for other bond issued in prior 12 months 
issuance_lvl <- issuance_lvl[order(seed_issuer_id, issuance_year_month_id)]
issuance_lvl[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), .(seed_issuer_id)]
issuance_lvl[, diff := issuance_year_month_id - lag_issuance_ym_id]
issuance_lvl[, bond_prior_12 := ifelse(!is.na(diff) & diff < 12, 1, 0)]

border_articles <- border_articles[order(seed_issuer_id, issuance_year_month_id)]
border_articles[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), .(seed_issuer_id)]
border_articles[, diff := issuance_year_month_id - lag_issuance_ym_id]
border_articles[, bond_prior_12 := ifelse(!is.na(diff) & diff < 12, 1, 0)]

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



# POISSON REGRESSIONS - ORIGINAL SPECIFICATION 
r1a <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & unique_sources_12 >5], vcov = vcov_cluster(~fips))
summary(r1a)
r2a <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + group + purp_broad , data = border_articles[go_unlim_bond_issuance == 1 & unique_sources_12 >5], vcov = vcov_cluster(~fips))
summary(r2a)

ym_border <- border_articles[go_unlim_bond_issuance == 1, uniqueN(city_go_vote), .(issuance_year_month_id)] # close to 70% of ym have variation

r1b <- fixest::fepois(total_rp_articles_6_neg1 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & unique_sources_12 >5], vcov = vcov_cluster(~fips))
summary(r1b)
r2b <- fixest::fepois(total_rp_articles_6_neg1 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + group + purp_broad  , data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 >0], vcov = vcov_cluster(~fips))
summary(r2b)

etable(r1a, r1b, r2a, r2b,
       headers = list("Full Sample" = 2, "Border-State Sample" = 2),
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
       dict = c(total_rp_articles_12_neg1 ='Total Articles [-12, -1]',
                total_rp_articles_6_neg1 ='Total Articles [-6, -1]',
                city_go_vote = 'Vote',
                go = 'GO',
                rolling_sum = 'City News Coverage',
                bond_prior_12 = 'Bond Issuance [-12, -1]',
                ln_amount = 'Amount',
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
                purp_broad = 'Purpose',
                issuance_year_month_id = 'Year-Month'),
       placement = 'H',
       file = paste0(tables_wd, '/poisson_total_articles_go_unlim.tex'), 
       replace = TRUE)


# POISSON REGRESSIONS - ORIGINAL SPECIFICATION POST 2014
r1a <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & year > 2010], vcov = vcov_cluster(~fips))
summary(r1a)
r2a <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + group + purp_broad , data = border_articles[go_unlim_bond_issuance == 1 & year > 2010], vcov = vcov_cluster(~fips))
summary(r2a)

r1b <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & year > 2010 & year < 2019], vcov = vcov_cluster(~fips))
summary(r1b)
r2b <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + group + purp_broad , data = border_articles[go_unlim_bond_issuance == 1 & year > 2010 & year < 2019], vcov = vcov_cluster(~fips))
summary(r2b)



etable(r1a, r2a, r1b, r2b,
       headers = list("[2010:]" = 2, "[2010:2018]" = 2),
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
       dict = c(total_rp_articles_12_neg1 ='Total Articles [-12, -1]',
                total_rp_articles_6_neg1 ='Total Articles [-6, -1]',
                city_go_vote = 'Vote',
                go = 'GO',
                rolling_sum = 'City News Coverage',
                bond_prior_12 = 'Bond Issuance [-12, -1]',
                ln_amount = 'Amount',
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
                purp_broad = 'Purpose',
                issuance_year_month_id = 'Year-Month'),
       placement = 'H',
       file = paste0(tables_wd, '/poisson_total_articles_go_unlim_time_split.tex'), 
       replace = TRUE)




# POISSON REGRESSIONS - SPLIT ON CITY GO VOTE 
r1a <- fixest::fepois(total_rp_articles_12_neg1 ~go  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + purp_broad , data = issuance_lvl[go_lim_bond_issuance == 0 & city_go_vote ==0], vcov = vcov_cluster(~fips))
summary(r1a)
r2a <- fixest::fepois(total_rp_articles_12_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + group + purp_broad , data = border_articles[go_unlim_bond_issuance == 1], vcov = vcov_cluster(~fips))
summary(r2a)

ym_border <- border_articles[go_unlim_bond_issuance == 1, uniqueN(city_go_vote), .(issuance_year_month_id)] # close to 70% of ym have variation

r1b <- fixest::fepois(total_rp_articles_6_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1], vcov = vcov_cluster(~fips))
summary(r1b)
r2b <- fixest::fepois(total_rp_articles_6_neg1 ~city_go_vote  + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment|issuance_year_month_id + group + purp_broad  , data = border_articles[go_unlim_bond_issuance == 1], vcov = vcov_cluster(~fips))
summary(r2b)





