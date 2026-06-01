# ravenpack media coverage tests 
rm(list = ls())
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven, xtable)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251217_kmtables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"

# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

#_______________Bonds________________
 #load full data to get county
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/251119_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
issuers <- full_data[, list(fips = first(fips), issuer_long_name = first(issuer_long_name)), .(seed_issuer_id)]
# load news coverage 
#issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_250916.csv'))
issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_251215.csv'))
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]
issuance_lvl[, city_rev_vote := ifelse(state == 'MO', 1, city_rev_vote)]
issuance_lvl[, city_go_vote := ifelse(state == 'RI', NA, city_go_vote)]

# filter to sample 
#issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & city_rev_vote == 0]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote)]

#_______________Border________________


#border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000 20250916.csv')
border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000 20251215.csv')
border_articles = as.data.table(border_articles)
#border_articles <- border_articles[category != 'grey']


# filter to non-missing demo 
issuance_lvl <- issuance_lvl[!is.na(ln_employment)]
#issuance_lvl <- issuance_lvl[!is.na(rolling_sum) & !is.infinite(rolling_sum)]
border_articles <- border_articles[!is.na(ln_employment)]
#border_articles <- border_articles[!is.na(rolling_sum) & !is.infinite(rolling_sum)]

# indicator for other bond issued in prior 12 months 
issuance_lvl <- issuance_lvl[order(seed_issuer_id, issuance_year_month_id)]
issuance_lvl[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), .(seed_issuer_id)]
issuance_lvl[, diff := issuance_year_month_id - lag_issuance_ym_id]
issuance_lvl[, bond_prior_12 := ifelse(!is.na(diff) & diff < 12, 1, 0)]

border_articles <- border_articles[order(seed_issuer_id, issuance_year_month_id)]
border_articles[, lag_issuance_ym_id := shift(issuance_year_month_id, 1), .(seed_issuer_id)]
border_articles[, diff := issuance_year_month_id - lag_issuance_ym_id]
border_articles[, bond_prior_12 := ifelse(!is.na(diff) & diff < 12, 1, 0)]

#border_articles <- border_articles[group %in% all_border_states]
#border_articles <- border_articles[!(group %in% c('Missouri/Kentucky', 'Missouri/Tennessee', 'Rhode Island/Massachusetts'))]

border_articles <- border_articles[!(group %in% c('Rhode Island/Massachusetts'))]


state_policy <- fread('/Users/kmunevar/Dropbox/Voting on Bonds/Data/State Monitoring Policy/state_enforcement_adoption_years.csv')
state_policy[, AdoptionYear := ifelse(AdoptionYear == 'before_sample', 2009, AdoptionYear )]
setnames(state_policy, 'Abbreviation', 'state')

issuance_lvl <- state_policy[issuance_lvl, on = .(state)]
issuance_lvl[, state_monitor := ifelse(!is.na(AdoptionYear) & year >= AdoptionYear, 1, 0)]

border_articles <- state_policy[border_articles, on = .(state)]
border_articles[, state_monitor := ifelse(!is.na(AdoptionYear) & year >= AdoptionYear, 1, 0)]


border_articles[, log_sources := log(1+unique_sources_12)]
issuance_lvl[, log_sources := log(1+unique_sources_12)]
#_______________Descriptives________________

border_articles[, total_articles_12_0_win := Winsorize(total_rp_articles_12_0, val = quantile(total_rp_articles_12_0, probs = c(0.01, 0.99)))]
issuance_lvl[, total_articles_12_0_win := Winsorize(total_rp_articles_12_0, val = quantile(total_rp_articles_12_0, probs = c(0.01, 0.99)))]

border_articles[, total_articles_6_0_win := Winsorize(total_rp_articles_6_0, val = quantile(total_rp_articles_6_0, probs = c(0.01, 0.99)))]
issuance_lvl[, total_articles_6_0_win := Winsorize(total_rp_articles_6_0, val = quantile(total_rp_articles_6_0, probs = c(0.01, 0.99)))]


desc <- issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0, .(city_go_vote, total_articles_12_0_win,
                            bond_prior_12, log_sources, ln_amount, 
                            ln_gdp, ln_pop, ln_pers_inc)]




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

desc_col[, variable := c('Vote', 'Total Articles - 12mo', 'Bond Issuance - 12mo', 'Num Sources', 'Amount',
                         'County ln(GDP)', 'County ln(Pop)', 'County ln(Pers. Inc)')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Media Descriptives.tex'))



#_______________Regressions ________________
issuance_lvl[is.na(city_rev_vote), city_rev_vote := 1]
border_articles[is.na(city_rev_vote), city_rev_vote := 1]




diff_table <- function(dt, group_var, vars) {
  out <- lapply(vars, function(v) {
    # t-test for difference
    ttest <- t.test(get(v) ~ get(group_var), data = dt)
    
    # compute group means
    means <- dt[, .(
      mean_0 = mean(get(v)[get(group_var) == 0], na.rm = TRUE),
      mean_1 = mean(get(v)[get(group_var) == 1], na.rm = TRUE)
    )]
    
    # extract stats
    pval <- ttest$p.value
    tstat <- round(ttest$statistic, 2)
    
    # significance stars
    stars <- if (pval < 0.01) "***"
    else if (pval < 0.05) "**"
    else if (pval < 0.1) "*"
    else ""
    
    data.table(
      variable = v,
      mean_0 = means$mean_0,
      mean_1 = means$mean_1,
      diff = round(means$mean_1 - means$mean_0, 2),
      tstat = tstat,
      stars = stars
    )
  })
  
  res <- rbindlist(out)
  
  # format columns
  res[, mean_0 := round(mean_0, 2)]
  res[, mean_1 := round(mean_1, 2)]
  res[, diff_fmt := sprintf("%.2f%s\n(%.2f)", diff, stars, abs(tstat))]
  
  return(res)
}


vars <- c('total_articles_12_0_win')

table_out <- diff_table(issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], "city_go_vote", vars)

# View formatted table
print(table_out[, .(variable, mean_0, mean_1, diff_fmt)])

#---------------------------------
# Export to LaTeX
#---------------------------------
latex_table <- xtable(table_out[, .(Variable = c('Total Articles - 12mo'),
                                    `Mean (0)` = mean_0,
                                    `Mean (1)` = mean_1,
                                    `Difference` = diff_fmt)],
                      caption = "Difference in Means with t-statistics",
                      label = "tab:diff_means")

print(latex_table,
      include.rownames = FALSE,
      sanitize.text.function = identity, # keeps parentheses and stars
      file = paste0(tbl_dir, "/media_diff_means_table.tex"))

r1 <- fixest::fepois(total_articles_12_0_win ~city_go_vote + bond_prior_12 + log_sources +
                        ln_amount|issuance_year_month_id + purp_broad , 
                      data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], 
                      vcov = vcov_cluster(~fips))
summary(r1)
r1b <- fixest::fepois(total_articles_12_0_win ~city_go_vote  + bond_prior_12 + log_sources + ln_amount + 
                       ln_gdp + ln_pop + ln_pers_inc |issuance_year_month_id + purp_broad , 
                     data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], 
                     vcov = vcov_cluster(~fips))
summary(r1b)

r2 <- fixest::fepois(total_articles_12_0_win ~city_go_vote + bond_prior_12 + log_sources + 
                        ln_amount|issuance_year_month_id + group + purp_broad , 
                      data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                      vcov = vcov_cluster(~fips))
summary(r2)

r2b <- fixest::fepois(total_articles_12_0_win ~city_go_vote  + bond_prior_12 + log_sources + ln_amount +
                       ln_gdp + ln_pop + ln_pers_inc    |issuance_year_month_id + group + purp_broad ,
                     data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                     vcov = vcov_cluster(~fips))
summary(r2b)



  
table_call <- etable(r1, r1b, r2, r2b,
       headers = list("Full Sample" = 2, "Border-State Sample" = 2),
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'pr2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       fontsize = 'small',
       #order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(total_articles_12_0_win ='Total Articles - 12mo',
                total_rp_articles_6_0 ='Total Articles - 6mo',
                city_go_vote = 'Vote',
                city_rev_vote = "Rev Vote",
                go = 'GO',
                rolling_sum = 'City News Coverage',
                bond_prior_12 = 'Bond Issuance - 12mo',
                ln_amount = 'Amount',
                ln_gdp =  'County ln(GDP)', 
                ln_num_cusip = "Num Bonds",
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_employment = 'County ln(Emp)', 
                log_sources = 'Num Sources',
                rolling_sum = 'City News Coverage',
                glm_proactive = 'Proactive State',
                state_ltgo_allowed = 'State LTGO Allowed',
                state_go_vote = 'State GO Vote',
                group = 'Border', 
                purp_broad = 'Purpose',
                issuance_year_month_id = 'Year-Month'),
       placement = 'H',
       #file = paste0(tables_wd, '/media_coverage.tex'), 
       replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/media_coverage_final.tex'))



#---------------------------------
# XS
#---------------------------------


# turnout data 
turnout <- load('/Users/kmunevar/Dropbox/Voting on Bonds/Data/ICPSR_38506/DS0001/38506-0001-Data.rda')
turnout <- as.data.table(get(turnout))



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



fips <- as.data.table(read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta'))
fips <- fips[, list(fips = first(fips)), .(seed_issuer_id)]



issuance_lvl <- fips[issuance_lvl, on = .(seed_issuer_id)]
issuance_lvl[, fips := as.integer(fips)]

issuance_lvl <- turnout_full[issuance_lvl, on = .(fips, year)]


# TURNOUT
issuance_lvl[, high_turnout := ifelse(REG_VOTER_TURNOUT_PCT >= quantile(REG_VOTER_TURNOUT_PCT, 3/4, na.rm = T), 1, 0)]
issuance_lvl[, low := ifelse(REG_VOTER_TURNOUT_PCT <= quantile(REG_VOTER_TURNOUT_PCT, 1/5, na.rm = T), 1, 0)]




r_all <- fixest::fepois(
  total_rp_articles_12_0 ~ city_go_vote*high_turnout + bond_prior_12 + unique_sources_12 +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment + state_monitor |
    issuance_year_month_id + purp_broad, 
  data = issuance_lvl[go_unlim_bond_issuance == 1 &  
                        rolling_sum_monthly_article_count_12 > 0], 
  vcov = vcov_cluster(~fips)
)
summary(r_all)


table_call <- etable(r_all,
                     #headers = list("Full Sample" = 2, "Border-State Sample" = 2),
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'pr2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     #order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
                     dict = c(total_articles_12_0_win ='Total Articles - 12mo',
                              total_rp_articles_6_0 ='Total Articles - 6mo',
                              city_go_vote = 'Vote',
                              city_rev_vote = "Rev Vote",
                              go = 'GO',
                              high_turnout = 'High Turnout',
                              rolling_sum = 'City News Coverage',
                              bond_prior_12 = 'Bond Issuance - 12mo',
                              ln_amount = 'Amount',
                              ln_gdp =  'County ln(GDP)', 
                              ln_num_cusip = "Num Bonds",
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
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/media_coverage_turnout_xs.tex'))



issuance_lvl[, high_reg := ifelse(REG_VOTERS_PCT >= quantile(REG_VOTERS_PCT, 3/4, na.rm = T), 1, 0)]
issuance_lvl[, hhi := (PARTISAN_INDEX_DEM^2 + PARTISAN_INDEX_REP^2)]
issuance_lvl[, high_partisan := ifelse(hhi >= quantile(hhi, 3/4, na.rm = T), 1, 0)]




r_turn <- fixest::fepois(
  total_rp_articles_12_0 ~ city_go_vote*high_turnout + bond_prior_12 + unique_sources_12 +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment + state_monitor |
    issuance_year_month_id + purp_broad, 
  data = issuance_lvl[go_unlim_bond_issuance == 1 &  
                        rolling_sum_monthly_article_count_12 > 0], 
  vcov = vcov_cluster(~fips)
)
summary(r_turn)


r_reg <- fixest::fepois(
  total_rp_articles_12_0 ~ city_go_vote*high_reg + bond_prior_12 + unique_sources_12 +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment + state_monitor |
    issuance_year_month_id + purp_broad, 
  data = issuance_lvl[go_unlim_bond_issuance == 1 &  
                        rolling_sum_monthly_article_count_12 > 0], 
  vcov = vcov_cluster(~fips)
)
summary(r_reg)

r_part <- fixest::fepois(
  total_rp_articles_12_0 ~ city_go_vote*high_partisan + bond_prior_12 + unique_sources_12 +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc + ln_employment + state_monitor |
    issuance_year_month_id + purp_broad, 
  data = issuance_lvl[go_unlim_bond_issuance == 1 &  
                        rolling_sum_monthly_article_count_12 > 0], 
  vcov = vcov_cluster(~fips)
)
summary(r_part)



table_call <- fixest::etable(
  list(
    "High Turnout"  = r_turn,
    "High Reg."     = r_reg,
    "High Partisan" = r_part
  ),
  keep = c(
    "%^city_go_vote$",
    "%^high_turnout$|^high_reg$|^high_partisan$",
    "%^city_go_vote:high_turnout$|^city_go_vote:high_reg$|^city_go_vote:high_partisan$"
  ),
  coefstat = "tstat",
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
  fitstat = c('n', 'pr2'), 
  se.below = TRUE, 
  digits = 3, 
  digits.stats = 3,
  signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
  tex = TRUE,
  fontsize = 'small',
  dict = c(
    city_go_vote = "Vote",
    high_turnout = "High Turnout",
    high_reg = "High Registered Voters",
    high_partisan = "High Partisan Concentration",
    "city_go_vote:high_turnout"  = "GO Vote × High Turnout",
    "city_go_vote:high_reg"      = "GO Vote × High Registered Voters",
    "city_go_vote:high_partisan" = "GO Vote × High Partisan", 
    issuance_year_month_id = 'Year-Month', 
    purp_broad = 'Purpose'
  ),
  headers = c("Turnout", "Registration", "Partisanship")
)


modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/media_coverage_all_voter_xs.tex'))



#------------- Plot -----------------
event_data = fread(paste0(data_wd, 'News/City_Month_DF_For_Event_Plot_GO_Only.csv'))
event_data[, quarter := ((event_month + 24) %/% 3) + 1]
event_data[, quarter := quarter - 9]
event_data_quarter = event_data[, list(rp_article_count = mean(rp_article_count)), .(city_go_vote, quarter)]

data_city_0 = event_data[city_go_vote == 0]
data_city_1 = event_data[city_go_vote == 1]
#loadfonts()
plot = ggplot() +                                                                                                         
  geom_line(data = data_city_0[event_month %in% c(-12:12)], aes(x = event_month, y = rp_article_count, color = "No"), size = 1.25) +                                                                                                 
  geom_line(data = data_city_1[event_month %in% c(-12:12)], aes(x = event_month, y = rp_article_count, color = "Yes"), size = 1.25) +                                                                                                 
  labs(x = "Event Month", y = "Monthly Article Count", title = "Article Counts Relative to Debt Issuance") +              
  #ylim(0, 0.2) +                                                                                                         
  scale_color_manual(values = c("skyblue2", "salmon2"), name = "Vote") +                                          
  theme_minimal()

ggsave(paste0(tbl_dir, "/article_counts.png"), plot = plot, width = 7, height = 5, dpi = 300)





r1 <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote + bond_prior_12 + unique_sources_12 +
                       ln_amount|issuance_year_month_id + purp_broad , 
                     data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], 
                     vcov = vcov_cluster(~fips))
summary(r1)
r2 <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_employment + city_rev_vote|issuance_year_month_id + purp_broad , 
                     data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], 
                     vcov = vcov_cluster(~fips))
summary(r2)
r3 <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote + bond_prior_12 + unique_sources_12 + 
                       ln_amount|issuance_year_month_id + group + purp_broad , 
                     data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                     vcov = vcov_cluster(~fips))
summary(r3)
r4 <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount  + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_employment + city_rev_vote|issuance_year_month_id + group + purp_broad ,
                     data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], 
                     vcov = vcov_cluster(~fips))
summary(r4)