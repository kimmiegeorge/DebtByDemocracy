# bond yields tests
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
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
full_data[, city_rev_vote := ifelse(state == 'MO', 1, city_rev_vote)]
full_data[, city_go_vote := ifelse(state == 'RI', NA, city_go_vote)]
#full_data <- full_data[city == 1 &!is.na(city_go_vote) & city_rev_vote == 0]
full_data <- full_data[city == 1 &!is.na(city_go_vote)]
full_data[, ym := paste0(year, month)]
full_data <- full_data[go_unlim == 1]
full_data <- full_data[!is.na(ln_emp) & !is.na(ln_gdp) & !is.na(callable)]
full_data <- full_data[maturity_mths > 0]



#_______________Border________________
# load border state issuers
border_full_data = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
#border_full_data = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 40000 20251008.csv')
border_full_data[, ym := paste0(year, month)]

#border_full_data <- border_full_data[category != 'grey']

border_full_data <- border_full_data[go_unlim == 1]

#border_full_data <- border_full_data[group %in% all_border_states]
border_full_data <- border_full_data[!(group %in% c('Rhode Island/Massachusetts'))]
border_full_data <- border_full_data[cusip %in% full_data$cusip]


# trim spread 
p1 <- quantile(full_data$offering_yield_spread, 0.01, na.rm = T)
p99 <- quantile(full_data$offering_yield_spread, 0.99, na.rm = T)
full_data[, offering_yield_spread_tr := ifelse(offering_yield_spread > p99 | offering_yield_spread < p1, NA, offering_yield_spread)]

p1 <- quantile(border_full_data$offering_yield_spread, 0.01, na.rm = T)
p99 <- quantile(border_full_data$offering_yield_spread, 0.99, na.rm = T)
border_full_data[, offering_yield_spread_tr := ifelse(offering_yield_spread > p99 | offering_yield_spread < p1, NA, offering_yield_spread)]

# amount quintile
full_data[, amount_quintile := ntile(ln_amount, 5)]
border_full_data[, amount_quintile := ntile(ln_amount, 5)]

#--------------Descriptives --------------------

desc <- full_data[, .(offering_yield, 
                   offering_yield_spread,
                 city_go_vote, ln_amount, 
                 ln_maturity_mths, callable, sinkable, insured, rated)]

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

desc_col[, variable := c('Yield', 'Yield Spread', 'Vote', 'Amount', 'Maturity', 'Callable', 'Sinkable', 'Insured', 'Rated')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Bond Yield Descriptives.tex'))



#-------------- Regressions --------------------
full_data[is.na(city_rev_vote), city_rev_vote := 1]
border_full_data[is.na(city_rev_vote), city_rev_vote := 1]
border_full_data[, group_ym := paste0(group, ym)]

r1 <- feols(offering_yield ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated  + 
              ln_gdp + ln_pop +  ln_pers_inc  + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed   |ym + purp_broad, 
            data = full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield_spread ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + rated +
               ln_gdp + ln_pop +  ln_pers_inc  + ln_emp  + state_go_vote + glm_proactive + state_ltgo_allowed |ym + purp_broad,
            data = full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r2)
r3 <- feols(offering_yield ~ city_go_vote  + ln_amount + ln_maturity_mths + callable  + sinkable + insured + 
              rated  + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + 
              state_go_vote |group + ym + purp_broad , 
            data = border_full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + ln_amount + ln_maturity_mths  + 
              callable  + sinkable + insured + rated + ln_gdp + ln_pop +  
              ln_pers_inc  + ln_emp  + state_go_vote |group + ym + purp_broad , 
            data = border_full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r4)





table_call <- etable(r1, r2, r3,r4,
       title = 'Bond Yields and Vote Requirements',
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       fontsize = 'small',
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(offering_yield ='Yield',
                offering_yield_spread ='Yield Spread',
                city_go_vote = 'Vote',
                city_rev_vote = 'Rev Vote',
                high_articles_12_0 = 'I(Media Coverage - 12mo)',
                ln_amount = 'Amount',
                amount_quintile = "Amount Quintile",
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
       #file = paste0(tables_wd, '/bond_yields.tex'), 
       replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/bond_yields_no_media.tex'))


# suggest to june maybe running the samples split, also maybe try merging with website disclosure
border_full_data[, group_year := paste0(group, year)]
r1 <- feols(offering_yield_spread ~ city_go_vote  + city_rev_vote + ln_amount + maturity_mths + callable  + sinkable + insured + rated + unique_sources_12 + ln_gdp + ln_pop +  ln_pers_inc  + 
              ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + glm_proactive + 
              state_ltgo_allowed |ym + purp_broad, data = full_data[rolling_sum_monthly_article_count_12 > 0 & high_articles_12_0 == 0], vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield_spread_tr ~ city_go_vote  + city_rev_vote + maturity_mths_tr + callable  + sinkable + insured + rated + unique_sources_12 + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + glm_proactive + state_ltgo_allowed |ym + purp_broad + amount_quintile, data = full_data[rolling_sum_monthly_article_count_12 > 0 & high_articles_12_0 == 1], vcov = vcov_cluster(~issue_id))
summary(r2)
r3 <- feols(offering_yield_spread_tr ~ city_go_vote  + city_rev_vote + maturity_mths_tr + callable  + sinkable + insured + rated + unique_sources_12 + 
              ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + glm_proactive + state_ltgo_allowed + state_go_vote + glm_proactive + state_ltgo_allowed |purp_broad  + group + year, data = border_full_data[rolling_sum_monthly_article_count_12 > 0 & high_articles_12_0 == 0 ], vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread_tr ~ city_go_vote  + city_rev_vote +  maturity_mths_tr + callable  + sinkable + insured + rated + unique_sources_12 + 
              ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + glm_proactive + state_go_vote + glm_proactive + state_ltgo_allowed |purp_broad + amount_quintile + group + year, data = border_full_data[rolling_sum_monthly_article_count_12 > 0 & high_articles_12_0 == 1], vcov = vcov_cluster(~issue_id))
summary(r4)


table_call <- etable(r1, r2, r3,r4,
                     title = 'Bond Yields, Vote Requirements, and Media Coverage',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     fontsize = 'small',
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(offering_yield_tr ='Yield',
                              offering_yield_spread_tr ='Yield Spread',
                              city_go_vote = 'Vote',
                              high_articles_12_0 = 'I(Media Coverage - 12mo)',
                              ln_amount = 'Amount',
                              amount_quintile = "Amount Quintile",
                              maturity_mths_tr = 'Maturity',
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
                     #file = paste0(tables_wd, '/bond_yields.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/bond_yields_expanded.tex'))




r1 <- feols(offering_yield ~ city_go_vote  + maturity_mths + callable  + sinkable + insured + rated +  
              ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + city_rev_vote + state_go_vote +glm_proactive + state_ltgo_allowed   |ym + purp_broad + amount_quintile, 
            data = full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r1)
r2 <- feols(offering_yield_spread ~ city_go_vote*high_articles_12_0  + maturity_mths + callable  + sinkable + insured + rated +
               ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + city_rev_vote + state_go_vote + glm_proactive + state_ltgo_allowed |ym + purp_broad + amount_quintile,
            data = full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r2)
r3 <- feols(offering_yield ~ city_go_vote  + city_rev_vote + maturity_mths + callable  + sinkable + insured + 
              rated + ln_gdp + ln_pop +  ln_pers_inc  + ln_emp + 
              city_rev_vote + state_go_vote |group + ym + purp_broad + amount_quintile, 
            data = border_full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r3)
r4 <- feols(offering_yield_spread ~ city_go_vote + city_rev_vote + maturity_mths  + 
              callable  + sinkable + insured + rated + ln_gdp + ln_pop +  
              ln_pers_inc  + ln_emp + city_rev_vote + state_go_vote |group + ym + purp_broad + amount_quintile, 
            data = border_full_data, 
            vcov = vcov_cluster(~issue_id))
summary(r4)

