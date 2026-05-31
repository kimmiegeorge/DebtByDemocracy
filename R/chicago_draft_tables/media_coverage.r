# ravenpack media coverage tests 
#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"


all_border_states <-c("Tennesee/Georgia", "Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                      "Tennesee/North Carolina")
# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

#_______________Bonds________________
 #load full data to get county
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
issuers <- full_data[, list(fips = first(fips), issuer_long_name = first(issuer_long_name)), .(seed_issuer_id)]
# load news coverage 
issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_250916.csv'))
#issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_2501013.csv'))
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]

# filter to sample 
#issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & city_rev_vote == 0]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote)]

#_______________Border________________


border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000 20250916.csv')
#border_articles <- fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches RP Issuance Lvl Expanded Set Buffer 100000 20251013.csv')
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
border_articles <- border_articles[!(group %in% c('Missouri/Kentucky', 'Missouri/Tennessee', 'Rhode Island/Massachusetts'))]

#_______________Descriptives________________

desc <- issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0, .(total_rp_articles_12_0, total_rp_articles_6_0,
                            bond_prior_12, unique_sources_12)]

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

desc_col[, variable := c('Total Articles - 12mo', 'Total Articles - 6mo', 'Bond Issuance - 12mo', 'Num Sources')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Media Descriptives.tex'))



#_______________Regressions ________________
issuance_lvl[is.na(city_rev_vote), city_rev_vote := 1]
border_articles[is.na(city_rev_vote), city_rev_vote := 1]
r1a <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote + bond_prior_12 + unique_sources_12 + ln_amount|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], vcov = vcov_cluster(~fips))
summary(r1a)
r1b <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount +  ln_gdp + ln_pop + ln_pers_inc + ln_employment + state_ltgo_allowed + glm_proactive + state_go_vote|issuance_year_month_id + purp_broad , data = issuance_lvl[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0 ], vcov = vcov_cluster(~fips))
summary(r1b)
r2a <- fixest::fepois(total_rp_articles_12_0 ~city_go_vote + bond_prior_12 + unique_sources_12 + ln_amount|issuance_year_month_id + group + purp_broad , data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], vcov = vcov_cluster(~fips))
summary(r2a)
r2b<- fixest::fepois(total_rp_articles_12_0 ~city_go_vote  + bond_prior_12 + unique_sources_12  + ln_amount  + ln_gdp + ln_pop + ln_pers_inc + ln_employment +  state_go_vote|issuance_year_month_id + group + purp_broad , data = border_articles[go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0], vcov = vcov_cluster(~fips))
summary(r2b)




table_call <- etable(r1a, r1b, r2a, r2b,
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
       order = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0"),
       dict = c(total_rp_articles_12_0 ='Total Articles - 12mo',
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
writeLines(modified_output, paste0(tbl_dir, '/media_coverage_final.tex'))


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