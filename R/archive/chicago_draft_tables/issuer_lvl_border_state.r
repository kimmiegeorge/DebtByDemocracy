# issuer - level regressions for border-state sample 

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, fixest)
# Load custom etable rounding functions
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/250917_kmtables'

all_border_states <-c("Tennesee/Georgia", "Kentucky/Missouri","Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                      "Tennesee/North Carolina", "Tennessee/Missouri")

all_border_states <-c("Tennesee/Georgia", "Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                      "Tennesee/North Carolina")
#----------------------------
# Load data 
#----------------------------
# first issuer lvl 
data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/250827_city_issuerlevel_yieldspread.dta'))
data <- data[city_rev_vote == 0 & !is.na(city_go_vote)]
data <- data[!is.na(ln_pop) & !is.na(ln_county_debt_other)]
# load border state issuers 
border_state = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_state = unique(border_state[, .(seed_issuer_id, group, category)])
# only look at no revenue vote matches
border_state <- border_state[category != 'grey']
border_state[, border_sample := 1]
data <- border_state[data, on = .(seed_issuer_id)]
#data[state == 'LA', state_ltgo_allowed := 0]
issuer_lvl_all <- data[border_sample == 1]
issuer_lvl_all <- issuer_lvl_all[group %in% all_border_states]

#----------------------------
# Regressions
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



table_call <- etable(r2, r5, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       dict = c(frac_utgo ='Pct UTGO', 
                frac_ltgo = 'Pct LTGO',
                frac_rev = 'Pct Rev',
                issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                city_go_vote = 'City GO Vote',
                state_go_vote = 'State GO Vote',
                state_ltgo_allowed = 'LTGO Allowed',
                glm_proactive = 'Proactive State',
                ln_county_debt_other = 'ln(Non-issuer county debt)',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'Border', 
                fips = 'County'),
       placement = 'H',
       #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
       replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/debt_choice_border_state.tex'))
