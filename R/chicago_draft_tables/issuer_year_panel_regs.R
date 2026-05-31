rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
data_wd <- "~/Dropbox/Voting on Bonds/Data/"
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"



chi_square <- function(reg1, reg2){
  
  reg1_se = reg1$se[[1]]
  reg2_se = reg2$se[[1]]
  
  diff = reg1$coefficients[[1]] - reg2$coefficients[[1]] 
  
  se = reg1_se^2 + reg2_se^2
  
  test_stat = diff/sqrt(se)
  test_stat = test_stat^2
  
  test_stat_return = as.character(round(test_stat, 3))
  
  #print(diff)
  
  p_xs = pchisq(test_stat, df = 1, lower.tail = F)
  #p_xs = pchisq(test_stat, df = 1)
  
  if (p_xs < 0.01){
    p_xs = paste0(as.character(round(p_xs, 3)), '***')
  } else if (p_xs < 0.05){
    p_xs = paste0(as.character(round(p_xs, 3)), '**')
  } else if (p_xs < 0.1){
    p_xs = paste0(as.character(round(p_xs, 3)), '*')
  } else {
    p_xs = as.character(round(p_xs, 3))
  }
  
  return(c(diff, test_stat_return, p_xs))
  
}
# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

cd_data <- fread(paste0(data_wd, 'Continuing Disclosure/Processed/issuer_year_panel_20251113.csv'))
cd_data <- cd_data[!is.na(city_go_vote)]




border_cd_data <- fread(paste0(data_wd, 'Continuing Disclosure/Processed/border_issuer_year_panel_20251113.csv'))
cd_data <- cd_data[!is.na(city_go_vote)]


state_policy <- fread('/Users/kmunevar/Dropbox/Voting on Bonds/Data/State Monitoring Policy/state_enforcement_adoption_years.csv')
state_policy[, AdoptionYear := ifelse(AdoptionYear == 'before_sample', 2009, AdoptionYear )]
setnames(state_policy, 'Abbreviation', 'state')

cd_data <- state_policy[cd_data, on = .(state)]
cd_data[, state_monitor := ifelse(!is.na(AdoptionYear) & year >= AdoptionYear, 1, 0)]

border_cd_data <- state_policy[border_cd_data, on = .(state)]
border_cd_data[, state_monitor := ifelse(!is.na(AdoptionYear) & year >= AdoptionYear, 1, 0)]

# ===============================================================================
# regressions
# ===============================================================================
# filter 
cd_data[, cd_required := ifelse(total_outstanding_debt > 10000000, 1, 0)]
border_cd_data[, cd_required := ifelse(total_outstanding_debt > 10000000, 1, 0)]

cd_data <- cd_data[num_go_unlim_bonds_outstanding > 0]
border_cd_data <- border_cd_data[num_go_unlim_bonds_outstanding > 0]
#cd_data <- cd_data[total_outstanding_debt > 10000000]
#border_cd_data <- border_cd_data[total_outstanding_debt > 10000000]
border_cd_data[, high_bond_count := ifelse(bond_count > median(bond_count, na.rm = T), 1, 0)]
border_cd_data[, high_fiscal_count := ifelse(fiscal_count > mean(fiscal_count, na.rm = T), 1, 0)]
border_cd_data[, high_fiscal_url := ifelse(fiscal_count > mean(fiscal_url, na.rm = T), 1, 0)]
border_cd_data[, high_financial_pdf := ifelse(financial_pdf_urls > median(financial_pdf_urls, na.rm = T), 1, 0)]
border_cd_data[, fiscal_tercile := ntile(fiscal_count, 4)]
border_cd_data[, upper_tercile_fiscal := ifelse(fiscal_tercile == 4, 1, 0)]

cd_data[, media_decile := ntile(cumavg_media_coverage, 10)]

border_cd_data[, fiscal_count_win := Winsorize(fiscal_count, val = quantile(fiscal_count, probs = c(0.01, 0.99), na.rm = T))]

cd_data[, num_num_go_bonds := num_bonds_outstanding - num_go_unlim_bonds_outstanding]
cd_data[, fraction_go := num_num_go_bonds/num_bonds_outstanding]
cd_data[, avg_timeliness_win := Winsorize(avg_timeliness_days, val = quantile(avg_timeliness_days, probs = c(0.01, 0.99), na.rm = T))]
border_cd_data[, avg_timeliness_win := Winsorize(avg_timeliness_days, val = quantile(avg_timeliness_days, probs = c(0.01, 0.99), na.rm = T))]

cd_data[, log_debt_outstanding := log(total_outstanding_debt)]
border_cd_data[, log_debt_outstanding := log(total_outstanding_debt)]

r1 <- feols(filed_financial_disclosure ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote + glm_proactive + state_ltgo_allowed|year, data = cd_data[], vcov = ~seed_issuer_id)
summary(r1)
r2 <- fixest::fepois(num_financial_operating_disclosures ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote + glm_proactive + state_ltgo_allowed|year, data = cd_data[], vcov = ~seed_issuer_id)
summary(r2)

r3 <- feols(filed_financial_disclosure ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote + glm_proactive + state_ltgo_allowed|year, data = cd_data[cd_required  == 1], vcov = ~seed_issuer_id)
summary(r3)
r4 <- fixest::fepois(num_financial_operating_disclosures ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote + glm_proactive + state_ltgo_allowed|year, data = cd_data[cd_required  == 1], vcov = ~seed_issuer_id)
summary(r4)


table_call <- etable(r1, r2, r3, r4, 
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'pr2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     headers = list(
                       "Full Sample" = 2,
                       "Restricted Sample" = 2
                     ),
                     dict = c(filed_financial_disclosure ='Compliant',
                              num_financial_operating_disclosures ='Total Financial Disclosures',
                              log_debt_outstanding = 'Total Outstanding Debt',
                              city_go_vote = 'Vote',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              purp_broad = 'Purpose',
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/251116_panel_full_sample_cd.tex'))


r1 <- feols(filed_financial_disclosure ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote|year + group, data = border_cd_data, vcov = ~seed_issuer_id)
summary(r1)
r2 <- fixest::fepois(num_financial_operating_disclosures ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote|year + group, data = border_cd_data, vcov = ~seed_issuer_id)
summary(r2)

r3 <- feols(filed_financial_disclosure ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote|year + group, data = border_cd_data[cd_required  == 1], vcov = ~seed_issuer_id)
summary(r3)
r4 <- fixest::fepois(num_financial_operating_disclosures ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote|year + group, data = border_cd_data[cd_required  == 1], vcov = ~seed_issuer_id)
summary(r4)



table_call <- etable(r1, r2, r3, r4, 
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'pr2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     headers = list(
                       "Full Sample" = 2,
                       "Restricted Sample" = 2
                     ),
                     dict = c(filed_financial_disclosure ='Compliant',
                              num_financial_operating_disclosures ='Total Financial Disclosures',
                              log_debt_outstanding = 'Total Outstanding Debt',
                              city_go_vote = 'Vote',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              purp_broad = 'Purpose',
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/251116_panel_border_sample_cd.tex'))




# ===============================================================================
# BIG FILING DELAY
# ===============================================================================


cd_data[, log_timeliness := log(avg_timeliness_days)]
border_cd_data[, log_timeliness := log(avg_timeliness_days)]

cd_data[, timely_tercile := ntile(avg_timeliness_days, 3)]
cd_data[, timely := ifelse(timely_tercile == 1, 1, 0)]
cd_data[is.na(timely), timely := 0]

border_cd_data[, timely_tercile := ntile(avg_timeliness_days, 3)]
border_cd_data[, timely := ifelse(timely_tercile == 1, 1, 0)]
border_cd_data[is.na(timely), timely := 0]




#### TIMELY - FULL SAMPLE #######
r1 <- feols(timely ~ city_go_vote |year, data = cd_data[cd_required ==1 & !is.na(ln_emp)], vcov = ~seed_issuer_id)
summary(r1)

r2 <- feols(timely ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_monitor |year, data = cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r2)

r3 <- feols(timely ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_go_vote + glm_proactive + state_ltgo_allowed |year, data = cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r3)

#### TIMELINESS - FULL SAMPLE #######
r4 <- feols(log_timeliness ~ city_go_vote |year, data = cd_data[cd_required ==1 & !is.na(ln_emp)], vcov = ~seed_issuer_id)
summary(r4)

r5 <- feols(log_timeliness ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_monitor |year, data = cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r5)

r6 <- feols(log_timeliness ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp +  state_go_vote + glm_proactive + state_ltgo_allowed  |year, data = cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r6)



table_call <- etable(r1, r2, r3, r4, r5,r6,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'pr2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     dict = c(timely ='Timely',
                              log_timeliness ='log(Delay)',
                              log_debt_outstanding = 'Total Outstanding Debt',
                              city_go_vote = 'Vote',
                              state_monitor = 'State Monitor',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              purp_broad = 'Purpose',
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/timeliness_fullsample.tex'))





#### TIMELY - BORDER SAMPLE #######
r1 <- feols(timely ~ city_go_vote  |year + group, data = border_cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r1)

r2 <- feols(timely ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_monitor |year + group, data = border_cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r2)

r3 <- feols(timely ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp+ state_go_vote|year + group, data = border_cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r3)


#### TIMELINESS - BORDER SAMPLE #######
r4 <- feols(log_timeliness ~ city_go_vote |year + group, data = border_cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r4)

r5 <- feols(log_timeliness ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp + state_monitor |year + group, data = border_cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r5)

r6 <- feols(log_timeliness ~ city_go_vote + log_debt_outstanding +  ln_emp + ln_pers_inc + ln_pop + ln_gdp +  state_go_vote + glm_proactive + state_ltgo_allowed  |year + group, data = border_cd_data[cd_required ==1], vcov = ~seed_issuer_id)
summary(r6)



table_call <- etable(r1, r2, r3, r4, r5,r6,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'pr2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     fontsize = 'small',
                     dict = c(timely ='Timely',
                              log_timeliness ='log(Delay)',
                              log_debt_outstanding = 'Total Outstanding Debt',
                              city_go_vote = 'Vote',
                              state_monitor = 'State Monitor',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              purp_broad = 'Purpose',
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/timeliness_bordersample.tex'))




