# issuer - level regressions for border-state sample 
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, fixest)
# Load custom etable rounding functions
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/chicago_draft_tables/modify_etable_rounding.R')
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/251008_kmtables'

#all_border_states <-c("Tennesee/Georgia", "Kentucky/Missouri","Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
 #                     "Tennesee/North Carolina", "Tennessee/Missouri")

all_border_states <-c("Tennesee/Georgia", "Louisiana/Mississippi","West Virginia/Kentucky","Ohio/Kentucky", "Michigan/Wisconsin" ,
                      "Tennesee/North Carolina")
#----------------------------
# Load data 
#----------------------------
# first issuer lvl 
data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/251027_city_issuerlevel_yieldspread.dta'))
data[, city_rev_vote := ifelse(state == 'MO', 1, city_rev_vote)]
data[, city_go_vote := ifelse(state == 'RI', NA, city_go_vote)]

data <- data[!is.na(city_go_vote)]
data <- data[!is.na(ln_pop) & !is.na(ln_county_debt_other)]
full_sample <- data
full_sample <- full_sample[insample == 1]
# load border state issuers 
border_state = fread('~/Dropbox/Voting on Bonds/Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20250916.csv')
border_state = unique(border_state[, .(seed_issuer_id, group, category)])
# only look at no revenue vote matches
#border_state <- border_state[category != 'grey']
border_state[, border_sample := 1]
data <- border_state[data, on = .(seed_issuer_id)]
#data[state == 'LA', state_ltgo_allowed := 0]
issuer_lvl_all <- data[border_sample == 1]
#issuer_lvl_all <- issuer_lvl_all[group %in% all_border_states]
issuer_lvl_all <- issuer_lvl_all[!is.na(group) & group != 'Rhode Island/Massachusetts']

#----------------------------
# Descriptives - full sample
#----------------------------
full_sample[, city_utgo_only := ifelse(city_go_vote == 1 & state %in% c('WA', 'MI', 'OH'),1 ,0)]
full_sample[, all_go := ifelse(city_go_vote == 1 & city_utgo_only == 0,1 ,0)]
desc <- full_sample[, .(all_go, city_utgo_only, frac_utgo, frac_ltgo, frac_rev, issuer_yield_spread)]

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

desc_col[, variable := c('GO Vote Required', 'Only UTGO Vote Required', 'Pct UTGO', 'Pct LTGO', 'Pct Revenue', 'Weighted Average Yield Spread')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/issuer_level_desc.tex'))



#----------------------------
# Regressions - full sample debt substitution
#----------------------------


# first, any GO Vote required 
r1 <- feols(frac_utgo ~ city_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(frac_ltgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r4)
r5 <- feols(frac_rev ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r5)



table_call <- etable(r1, r2, r3, r4, r5,
                     coefstat = 'tstat',
                     drop = "Constant",
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(frac_utgo ='Pct UTGO', 
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
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
                              fips = 'County'),
                     placement = 'H',
                     #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/debt_choice_allgo.tex'))

# now, only UTGO
r1 <- feols(frac_utgo ~ city_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(frac_ltgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r4)
r5 <- feols(frac_rev ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r5)



table_call <- etable(r1, r2, r3, r4, r5,
                     coefstat = 'tstat',
                     drop = "Constant",
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(frac_utgo ='Pct UTGO', 
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
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
                              fips = 'County'),
                     placement = 'H',
                     #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/debt_choice_utgo_only.tex'))



#----------------------------
# Regressions - full sample yield spreads
#----------------------------


# first, any GO Vote required 
r1 <- feols(issuer_yield_spread ~ city_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~fips))
summary(r3)



table_call <- etable(r1, r2, r3,
                     coefstat = 'tstat',
                     drop = "Constant",
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(frac_utgo ='Pct UTGO', 
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
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
                              fips = 'County'),
                     placement = 'H',
                     #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_allgo.tex'))

# now, only UTGO
r1 <- feols(issuer_yield_spread ~ city_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r3)



table_call <- etable(r1, r2, r3, 
                     coefstat = 'tstat',
                     drop = "Constant",
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = "Yes"),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(frac_utgo ='Pct UTGO', 
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
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
                              fips = 'County'),
                     placement = 'H',
                     #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_utgo_only.tex'))




#----------------------------
# Regressions
#----------------------------

r1 <- feols(frac_utgo ~ city_go_vote|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote + glm_proactive + state_ltgo_allowed|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(issuer_yield_spread ~ city_go_vote|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r4)
r5<- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r5)
r6 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote+ glm_proactive + state_ltgo_allowed|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
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



#----------------------------
# Regressions
#----------------------------



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

turnout_full[, max_partisan := pmax(PARTISAN_INDEX_DEM, PARTISAN_INDEX_REP, na.rm = T)]
turnout_full[,  hhi := (PARTISAN_INDEX_DEM^2 + PARTISAN_INDEX_REP^2)]


turnout_avg <- turnout_full[year >= 2000 & year <= 2022, list(avg_turnmout = mean(REG_VOTER_TURNOUT_PCT, na.rm = T), 
                                                              first_turnout = first(REG_VOTER_TURNOUT_PCT), 
                                                              avg_partisan = mean(max_partisan, na.rm = T), 
                                                              first_partisan = first(max_partisan), 
                                                              avg_reg_perc = mean(REG_VOTERS_PCT, na.rm = T), 
                                                              first_reg_perc = first(REG_VOTERS_PCT), 
                                                              avg_hhi = mean(hhi, na.rm = T), 
                                                              first_hhi = first(hhi)), .(fips)]

data[, fips := as.integer(fips)]
data <- turnout_avg[data, on = .(fips)]

data <- data[!is.na(city_go_vote)]

data[, high_turnout := ifelse(first_turnout > quantile(first_turnout, 2/3, na.rm = T), 1, 0)]

data[, low_turnout := ifelse(V1 < quantile(V1, 1/4, na.rm = T), 1, 0)]


r1 <- feols(frac_utgo ~ city_go_vote*high_turnout + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed, data = data, vcov = vcov_cluster(~fips))
summary(r1)


table_call <- etable(r1, 
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
                              high_turnout = 'High Turnout',
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
writeLines(modified_output, paste0(tbl_dir, '/debt_choice_turnout_xs.tex'))



data[, high_turnout := ifelse(first_turnout > quantile(first_turnout, 2/3, na.rm = T), 1, 0)]
data[, high_reg := ifelse(avg_reg_perc > quantile(avg_reg_perc, 2/3, na.rm = T), 1, 0 )]
data[, high_hhi := ifelse(avg_hhi > quantile(avg_hhi, 2/3, na.rm = T), 1, 0)]

r_turn <- feols(frac_utgo ~ city_go_vote*high_turnout + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed, data = data, vcov = vcov_cluster(~fips))
summary(r_turn)

r_reg <- feols(frac_utgo ~ city_go_vote*high_reg + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed, data = data, vcov = vcov_cluster(~fips))
summary(r_reg)

r_hhi <- feols(frac_utgo ~ city_go_vote*high_hhi + ln_gdp + ln_pop + ln_pers_inc + ln_emp + state_go_vote + glm_proactive + state_ltgo_allowed, data = data, vcov = vcov_cluster(~fips))
summary(r_hhi)


table_call <- fixest::etable(
  list(
    "High Turnout"  = r_turn,
    "High Reg."     = r_reg,
    "High Partisan" = r_hhi
  ),
  keep = c(
    "%^city_go_vote$",
    "%^high_turnout$|^high_reg$|^high_hhi$",
    "%^city_go_vote:high_turnout$|^city_go_vote:high_reg$|^city_go_vote:high_hhi$"
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
writeLines(modified_output, paste0(tbl_dir, '/debt_choice_all_voter_xs.tex'))
