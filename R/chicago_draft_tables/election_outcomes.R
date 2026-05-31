# TX election outcome tests
#---------------------------------------
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251217_kmtables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"


# ===============================================================================
# DATA LOADING AND PREPARATION - MEDIA FIRST
# ===============================================================================

city_month <- fread(paste0(data_wd, 'TX/City_Month_Elections_News_WithFailed_251014.csv'))
election <- fread(paste0(data_wd, 'TX/News/Election_Level_With_News_WithFailed_251014.csv'))

city_month <- city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer &!is.na(ln_county_employment_prior)]
#election <- election[year >= 2010 & unique_sources_12m_prior > 0]
election <- election[unique_sources_12m_prior > 0]


election[, `:=` (ln_election_month_articles = log(1 + articles_election_month), 
                 ln_2m_election_articles = log(1 + articles_2m_before_to_election), 
                 ln_6m_election_articles = log(1 + articles_6m_before_to_election))]

election[, coverage_3 := ifelse(articles_2m_before_to_election > 0, 1, 0)]

election[, year_month := paste0(year, month)]

election[, ln_Amount := log(Amount)]
election[, log_sources := log(unique_sources_12m_prior)]

election[, log_votes := log(votestotal)]
election[, county_year := paste0(County, year)]
election[, coverage_3 := ifelse(articles_2m_before_to_election > 0, 1, 0)]
election[, coverage_6 := ifelse(articles_6m_before_to_election > 0, 1, 0)]

election[, abs_vote_margin := abs(vote_margin)]


# DESCRIPTIVES - ELECTION LEVEL 
desc <- election[, .(failed, 
                     abs_vote_margin,
                      coverage_3)]

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

desc_col[, variable := c('Failed', 'Margin', 'I(Bond Coverage)')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Election Level Desc.tex'))


election[, votes_scaled := votestotal/exp(ln_county_pop_prior)]


r0 <- feols(failed ~ coverage_3|year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(r0)
r1 <- feols(failed ~ coverage_3 + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |year + purp_broad_new, data = election[ unique_sources_12m_prior > 0], cluster = ~County)
summary(r1)
r2 <- feols(vote_margin  ~ coverage_3 |year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(r2)
r3 <- feols(abs_vote_margin ~ coverage_3  + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior|year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(r3)



table_call <- etable(r0, r1, r2, r3,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     dict = c(failed ='I(Failed)',
                              coverage_3 = 'I(Bond Coverage)[-1, 0]',
                              abs_vote_margin = 'Margin',
                              ln_Amount = "Amount",
                              unique_sources_12m_prior = 'Num Sources',
                              ln_county_gdp_prior = 'County ln(GDP)', 
                              ln_county_pop_prior = 'County ln(Pop)', 
                              ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                              ln_county_employment_prior = 'County ln(Emp)',
                              year = 'Year',
                              purp_broad_new = 'Purpose'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/tx_failed_and_margin.tex'))



# turnout data 
turnout <- load('/Users/kmunevar/Dropbox/Voting on Bonds/Data/ICPSR_38506/DS0001/38506-0001-Data.rda')
turnout <- as.data.table(get(turnout))

fips <- as.data.table(read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta'))
fips <- fips[state == 'TX', list(fips = first(fips)), .(seed_issuer)]
fips[, seed_issuer := tolower(seed_issuer)]

election <- fips[election, on = .(seed_issuer)]

# get average turnout
#turnout <- turnout[as.integer(YEAR) > 2010]
dt <- turnout[, list(avg_voter_turnout_pct = mean(VOTER_TURNOUT_PCT, na.rm = T), 
                avg_reg_voter_turnout_pct = mean(REG_VOTER_TURNOUT_PCT, na.rm = T), 
                avg_partisan_index_dem = mean(PARTISAN_INDEX_DEM, na.rm = T), 
                avg_partisan_index_rep = mean(PARTISAN_INDEX_REP, na.r = T), 
                avg_diff = mean(abs(PARTISAN_INDEX_DEM - PARTISAN_INDEX_REP), na.rm = T),
                avg_cvap = mean(CVAP, na.rm = T)), .(STCOFIPS10)]
dt[, fips := as.character(STCOFIPS10)]
dt[, disagreement := 1-avg_diff]

election <- dt[election, on = .(fips)]
election[, high_turnout := ifelse(avg_reg_voter_turnout_pct > median(avg_reg_voter_turnout_pct, na.rm = T), 1, 0)]




turnout[, year := as.integer(YEAR) + 1]
turnout[, YEAR := NULL]
turnout[, fips := as.integer(as.character(STCOFIPS10))]
turnout[, STCOFIPS10 := NULL]

# turnout has fips, year, and many turnout variables
setDT(turnout)

# Identify turnout variables (all except fips/year)
turnout_cols <- setdiff(names(turnout), c("fips", "year"))

# Ensure year numeric
turnout[, year := as.integer(year)]

# Step 1: Create complete fips × year grid
turnout_full <- turnout[
  , CJ(fips = unique(fips),
       year = seq(min(year), max(year))),
]

# Step 2: Merge original turnout values
turnout_full <- turnout[turnout_full, on = .(fips, year)]

# Step 3: Fill missing with LAST OBSERVATION CARRIED FORWARD
turnout_full[
  order(fips, year),
  (turnout_cols) := lapply(.SD, nafill, type = "locf"),
  by = fips,
  .SDcols = turnout_cols
]

# Step 4 (optional): Fill remaining leading gaps with next observation (NOCB)
turnout_full[
  order(fips, year),
  (turnout_cols) := lapply(.SD, nafill, type = "nocb"),
  by = fips,
  .SDcols = turnout_cols
]

turnout_full[, year := year + 1]
turnout_full[, reg_vote_prior_year := REG_VOTER_TURNOUT_PCT]
turnout_full[, reg_voters_prior_year := REG_VOTERS_PCT]
turnout_full <- turnout_full[, .(year, reg_vote_prior_year,reg_voters_prior_year, fips)]

election[, fips := as.integer(fips)]
election <- turnout_full[election, on = .(fips, year)]

election[, high_registered := ifelse(reg_voters_prior_year > quantile(reg_voters_prior_year, 1/2, na.rm = T), 1 ,0)]


test <- feols(abs_vote_margin ~ high_registered + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(test)

test <- feols(abs_vote_margin ~ coverage_3*high_registered + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(test)

test <- feols(failed ~ high_registered + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(test)

test <- feols(failed ~ coverage_3*high_registered + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(test)



# need to filter this to cities that get coverage 
# add bond issuance indicators for city_month data 

# create ym and ym_id
city_month[, ym := paste0(year, month)]
yms <- unique(city_month[, .(ym)])
yms[, ym_id := 1:.N]
city_month <- yms[city_month, on = .(ym)]


full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
full_data[, ym := paste0(year, month)]
full_data <- unique(full_data[, .(seed_issuer_id, ym)])
full_data <- yms[full_data, on = .(ym)]
full_data[, ym := NULL]
full_data[, bond_issuance := 1]

city_month <- full_data[city_month, on = .(seed_issuer_id, ym_id)]
city_month[, next_month_bond_issuance := ifelse(shift(bond_issuance, type = 'lead') == 1, 1, 0), .(seed_issuer_id)]
city_month[, next_next_month_bond_issuance := ifelse(shift(bond_issuance, type = 'lead', 2) == 1, 1, 0), .(seed_issuer_id)]
city_month[, issuance_window := ifelse(next_month_bond_issuance == 1 | bond_issuance == 1 ,1, 0)]
city_month[is.na(issuance_window), issuance_window := 0]

city_month[, next_next_month_election := ifelse(shift(has_bond_election, type = 'lead', 2) == 1, 1, 0), .(seed_issuer_id)]
city_month[, election_window := ifelse(has_bond_election == 1 | has_election_next_month ==1, 1, 0)]
city_month[is.na(election_window), election_window := 0]
city_month[, covered := ifelse(rp_article_count > 0, 1, 0)]



# DESCRIPTIVES - City-Month LEVEL 
desc <- city_month[, .(covered, 
                     election_window,
                     issuance_window)]

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

desc_col[, variable := c('I(Bond Coverage)', 'Election', 'Issuance')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Election City Month Level Desc.tex'))


r1 <- feols(covered ~ election_window|seed_issuer_id + ym_id, data = city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer & !is.na(ln_county_employment_prior)], cluster = ~seed_issuer + ym_id)
summary(r1)
r2 <- feols(covered ~ election_window + issuance_window + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |seed_issuer_id + ym_id, data = city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer], cluster = ~seed_issuer + ym_id)
summary(r2)




table_call <- etable(r1, r2,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     dict = c(covered ='I(Bond Coverage)',
                              election_window = 'Election',
                              issuance_window = "Bond Issuance",
                             seed_issuer_id = 'City',
                             ln_county_gdp_prior = 'County ln(GDP)', 
                             ln_county_pop_prior = 'County ln(Pop)', 
                             ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                             ln_county_employment_prior = 'County ln(Emp)',
                              ym_id = 'Year-Month'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/tx_city_month_reg.tex'))


# ===============================================================================
# descriptives on elections at the union of website and media samples
# ===============================================================================
election_website <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_251209.csv'))
election_website[, abs_vote_margin := abs(vote_margin)]
election_website <- election_website[total_subs > 10]

election_media <- election[, .(GovernmentName, ElectionDate, PropNumber, failed, abs_vote_margin)]
election_website <- election_website[, .(GovernmentName, ElectionDate, PropNumber, failed, abs_vote_margin)]

election_all <- rbindlist(list(election_media, election_website))
election_all <- unique(election_all)



desc <- election_all[, .(failed, 
                         abs_vote_margin)]

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

desc_col[, variable := c('Failed', 'Margin')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Election Level Desc.tex'))


# ===============================================================================
# DATA LOADING AND PREPARATION - WEBSITES
# ===============================================================================
election_media <- election
city_month <- fread(paste0(data_wd, 'Websites/Texas/time_series_website_data_251217.csv'))
city_month <- city_month[total_subs == 50]
election <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_251217.csv'))


# merge media with election website 
election <- election_media[, .(GovernmentName, ElectionDate, PropNumber, unique_sources_12m_prior, articles_2m_before_to_election)][election, on = .(GovernmentName, ElectionDate, PropNumber)]
election[, covered_3 := ifelse(articles_2m_before_to_election > 0, 1, 0)]


election[, abs_vote_margin := abs(vote_margin)]
election[, bond_debt_count := bond_count + debt_count]

# THIS IS LOOKING GOOD - check county demo variables

election <- election[total_subs >= 20]
election[, log_bond_debt_count := log(1 + fiscal_count + bond_count)]
election[, high_bond_count := ifelse(bond_debt_count > median(bond_debt_count), 1, 0)]
election[, fiscal_bond_count := fiscal_count + bond_debt_count]
election[, high_bond_count := ifelse(fiscal_bond_count >= median(fiscal_bond_count), 1, 0)]
election[, ln_cum_num_issues_unlim := log(1+cum_num_issues)]

r0 <- feols(failed ~ high_bond_count|year + purp_broad_new, data = election, cluster = ~County, fixef.rm = 'singleton')
summary(r0)
r1 <- feols(failed ~ high_bond_count + ln_amount + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior  |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r1)
r2 <- feols(abs_vote_margin  ~ high_bond_count |year + purp_broad_new, data = election, cluster = ~County,  fixef.rm = 'singleton')
summary(r2) 
r3 <- feols(abs_vote_margin ~ high_bond_count + ln_amount  + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior   |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r3)


table_call <- etable(r0, r1, r2, r3,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     dict = c(failed ='I(Failed)',
                              high_bond_count = 'I(High Website Disclosure)',
                              vote_margin = 'Margin',
                              ln_cum_num_issues_unlim = 'Num Issuance',
                              ln_amount = "Amount",
                              ln_county_gdp_prior = 'County ln(GDP)', 
                              ln_county_pop_prior = 'County ln(Pop)', 
                              ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                              ln_county_employment_prior = 'County ln(Emp)',
                              year = 'Year',
                              purp_broad_new = 'Purpose'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/tx_failed_and_margin_websites.tex'))


r0 <- feols(failed ~ high_bond_count|year, data = election[unique_sources_12m_prior >0], cluster = ~County, fixef.rm = 'singleton')
summary(r0)

r0 <- feols(failed ~ high_bond_count*covered_3|year, data = election, cluster = ~County, fixef.rm = 'singleton')
summary(r0)
r1 <- feols(failed ~ bond_or_debt_url*covered_3 + ln_amount + unique_sources_12m_prior + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |year, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r1)
r1 <- feols(failed ~ fiscal_bond_count*covered_3 + ln_amount + unique_sources_12m_prior + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |year, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r1)
r2 <- feols(abs_vote_margin  ~ fiscal_bond_count*covered_3  |year + purp_broad_new, data = election, cluster = ~County,  fixef.rm = 'singleton')
summary(r2) 
r3 <- feols(abs_vote_margin ~ fiscal_bond_count*covered_3  + ln_amount  + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior + ln_county_employment_prior  |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r3)


