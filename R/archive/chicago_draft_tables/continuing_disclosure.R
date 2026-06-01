#---------------------------------------
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"

# ===============================================================================
# DATA LOADING AND PREPARATION
# ===============================================================================

cd_data <- fread(paste0(data_wd, 'Continuing Disclosure/Processed/issue_level_with_cd_vars_20251111.csv'))
cd_data <- cd_data[!is.na(city_go_vote)]
cd_data <- cd_data[go_unlim == 1]
cd_data[, year_month := paste0(year, month)]
cd_data[, num_disclosures_within_5_years_win := Winsorize(num_disclosures_within_5_years, val = quantile(num_disclosures_within_5_years, probs = c(0.01, 0.99)))]
cd_data[, log_cum_debt_count := log(1+cum_total_count_before)]

state_policy <- fread('/Users/kmunevar/Dropbox/Voting on Bonds/Data/State Monitoring Policy/state_enforcement_adoption_years.csv')
state_policy[, AdoptionYear := ifelse(AdoptionYear == 'before_sample', 2009, AdoptionYear )]
setnames(state_policy, 'Abbreviation', 'state')

cd_data <- state_policy[cd_data, on = .(state)]

cd_data[, state_monitor := ifelse(!is.na(AdoptionYear) & year >= AdoptionYear, 1, 0)]
cd_data_border <- fread(paste0(data_wd, 'Continuing Disclosure/Processed/border_issue_level_with_cd_vars_20251111.csv'))
cd_data_border <- cd_data_border[!(group %in% c('Rhode Island/Massachusetts'))]
cd_data_border <- cd_data_border[go_unlim == 1]
cd_data_border[, year_month := paste0(year, month)]
cd_data_border[, log_cum_debt_count := log(1+cum_total_count_before)]
#_______________FILTER ________________
print(nrow(cd_data)) # 2635
cd_data_restricted <- cd_data[cum_total_debt_before > 10000000]
print(nrow(cd_data_restricted)) # 1648
cd_data_restricted <- cd_data_restricted[short_maturity_under_18mo == 0]
print(nrow(cd_data_restricted)) # 1648
cd_data_restricted <- cd_data_restricted[small_issue_under_1m == 0]
print(nrow(cd_data_restricted)) # 1610

cd_data_border_restricted <- cd_data_border[issue_id %in% cd_data_restricted$issue_id]

#_______________Regressions - Full Sample ________________
cd_data[, num_financial_operating_data_disclosure_within_3_year_win := Winsorize(num_financial_operating_data_disclosure_within_3_year, val = quantile(num_financial_operating_data_disclosure_within_3_year, probs = c(0.01, 0.99)))]
r1 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad , data = cd_data, vcov = vcov_cluster(~fips))
summary(r1)
r2 <- fixest::fepois(num_audited_cafr_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad , data = cd_data, vcov = vcov_cluster(~fips))
summary(r2)
r3 <- fixest::fepois(num_event_based_disclosures_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad , data = cd_data, vcov = vcov_cluster(~fips))
summary(r3)
r4 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad , data = cd_data_restricted, vcov = vcov_cluster(~fips))
summary(r4)
r5 <- fixest::fepois(num_audited_cafr_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad , data = cd_data_restricted, vcov = vcov_cluster(~fips))
summary(r5)
r6 <- fixest::fepois(num_event_based_disclosures_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed|year + purp_broad , data = cd_data_restricted, vcov = vcov_cluster(~fips))
summary(r6)



table_call <- etable(r1, r2, r3, r4, r5, r6,
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
                       "Full Sample" = 3,
                       "Restricted Sample" = 3
                     ),
                     dict = c(num_financial_operating_data_disclosure_within_3_year ='Total Financial',
                              num_audited_cafr_disclosure_within_3_year ='Total Audited',
                              num_event_based_disclosures_within_3_year = 'Total Event',
                              city_go_vote = 'Vote',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              log_issue_size = 'Issue Size',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/251116_full_sample_cd.tex'))


#_______________Regressions - Border-State ________________

r1 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|year + purp_broad + group , data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r1)
r2 <- fixest::fepois(num_audited_cafr_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|year + purp_broad + group, data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r2)
r3 <- fixest::fepois(num_event_based_disclosures_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|year + purp_broad+ group , data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r3)
r4 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote |year + purp_broad+ group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r4)
r5 <- fixest::fepois(num_audited_cafr_disclosure_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote |year + purp_broad+ group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r5)
r6 <- fixest::fepois(num_event_based_disclosures_within_3_year ~city_go_vote +  log_cum_debt_count + log_issue_size + 
                       ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote |year + purp_broad+ group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r6)


table_call <- etable(r1, r2, r3, r4, r5, r6,
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
                       "Full Sample" = 3,
                       "Restricted Sample" = 3
                     ),
                     dict = c(num_financial_operating_data_disclosure_within_3_year ='Total Financial',
                              num_audited_cafr_disclosure_within_3_year ='Total Audited',
                              num_event_based_disclosures_within_3_year = 'Total Event',
                              city_go_vote = 'Vote',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_issue_size = 'Issue Size',
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
writeLines(modified_output, paste0(tbl_dir, '/251116_border_sample_cd.tex'))



#_______________Regressions - Border-State ________________


cd_data_border[, high_bond_count := ifelse(bond_count > mean(bond_count, na.rm = T), 1, 0)]
cd_data_border[, high_fiscal_count := ifelse(fiscal_count > mean(fiscal_count, na.rm = T), 1, 0)]
cd_data_border_restricted[, high_bond_count := ifelse(bond_count > mean(bond_count, na.rm = T), 1, 0)]
cd_data_border_restricted[, high_fiscal_count := ifelse(fiscal_count > mean(fiscal_count, na.rm = T), 1, 0)]
cd_data_border[, cd_required := ifelse(cum_total_debt_before > 10000000, 1, 0)]

#cd_data_border_restricted[, log_total_debt_before := log(1+cum_total_debt_before)]

r1 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote + cd_required + log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp |year + purp_broad + group , data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r1)

r2 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*bond_count +cd_required + log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote |year + purp_broad + group , data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r2)

r3 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*fiscal_count + log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r3)

r4 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r4)

r5 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*bond_count +log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote |year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r5)

r6 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*fiscal_count + log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote|year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r6)

table_call <- etable(r1, r2, r3, r4, r5, r6,
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
                       "Full Sample" = 3,
                       "Restricted Sample" = 3
                     ),
                     order =  c(
                       "Vote", "Vote $\times$ High Bond Count", "Vote $\times$ High Fiscal Count",
                       "High Bond Count", 'High Fiscal Count'
                     ),
                     dict = c(num_financial_operating_data_disclosure_within_3_year ='Total Financial Disclosures',
                              city_go_vote = 'Vote',
                              high_bond_count = 'High Bond Count',
                              high_fiscal_count = 'High Fiscal Count',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              log_issue_size = 'Size',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tables_wd, '/251113_border_sample_cd.tex'))



r1 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp |year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r1)

r2 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*high_bond_count +log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp |year + purp_broad + group , data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r2)

r3 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*high_fiscal_count + log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp|year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r3)

r4 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote +log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp|year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r4)

r5 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*high_bond_count +log_cum_debt_count +  log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp |year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r5)

r6 <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*high_fiscal_count + log_cum_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp|year + purp_broad + group , data = cd_data_border_restricted, vcov = vcov_cluster(~fips))
summary(r6)

table_call <- etable(r1, r2, r3, r4, r5, r6,
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
                       "Full Sample" = 3,
                       "Restricted Sample" = 3
                     ),
                     order =  c(
                       "Vote", "Vote $\times$ High Bond Count", "Vote $\times$ High Fiscal Count",
                       "High Bond Count", 'High Fiscal Count'
                     ),
                     dict = c(num_financial_operating_data_disclosure_within_3_year ='Total Financial Disclosures',
                              city_go_vote = 'Vote',
                              high_bond_count = 'High Bond Count',
                              high_fiscal_count = 'High Fiscal Count',
                              state_go_vote = 'State GO Vote',
                              glm_proactive = 'Proactive State',
                              state_ltgo_allowed = 'State LTGO Allowed',
                              log_cum_debt_count = 'Num Issuances',
                              log_issue_size = 'Size',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'Border', 
                              year = 'Year'),
                     placement = 'H',
                     #file = paste0('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate/tbls_0916/updated_website_regs.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tables_wd, '/251113_border_sample_cd_no_state_go.tex'))




for (s in unique(cd_data$state)){
  print(paste0('Dropping state ', s))
  r1b <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote + log_cum_debt_count + log_issue_size  + ln_num_cusip + log_weighted_avg_maturity +  weighted_avg_callable + 
                          weighted_avg_sinkable + weighted_avg_rated + ln_gdp + ln_pop + ln_pers_inc + ln_emp |year + purp_broad , data = cd_data_restricted[state != s], vcov = vcov_cluster(~fips))
  print(summary(r1b))
  
}

cd_data_border <- cd_data_border[!is.na(bond_count)]
cd_data_border[, high_fiscal_url := ifelse(fiscal_url > median(fiscal_url), 1, 0)]
cd_data_border[, high_fiscal_count := ifelse(fiscal_count > median(fiscal_count), 1, 0)]
cd_data_border[, high_bond_debt_url := ifelse(bond_debt_url > median(bond_debt_url), 1, 0)]
cd_data_border[, high_bond_debt_count := ifelse(bond_debt_count > median(bond_debt_count), 1, 0)]


r1b <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*bond_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp   |year + purp_broad+ group, data = cd_data_border[], vcov = vcov_cluster(~fips))
summary(r1b)

r1b <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*fiscal_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp   |year + purp_broad+ group, data = cd_data_border[], vcov = vcov_cluster(~fips))
summary(r1b)


r1b <- fixest::fepois(num_event_based_disclosures_within_3_year ~city_go_vote*bond_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp   |year + purp_broad+ group, data = cd_data_border[], vcov = vcov_cluster(~fips))
summary(r1b)

r1b <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*high_bond_debt_count + log_issue_size + ln_gdp + ln_pop + ln_pers_inc + ln_emp |year + purp_broad+ group, data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r1b)


r1b <- fixest::fepois(num_financial_operating_data_disclosure_within_3_year ~city_go_vote*fiscal_url + log_issue_size + ln_gdp + ln_pop + 
                        ln_pers_inc + ln_emp |year + purp_broad+ group, data = cd_data_border, vcov = vcov_cluster(~fips))
summary(r1b)