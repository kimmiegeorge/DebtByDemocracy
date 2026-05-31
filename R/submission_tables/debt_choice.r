# issuer - level regressions for border-state sample 
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, fixest)
# Load custom etable rounding functions
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/submission_tables'


#----------------------------
# Load data 
#----------------------------
# first issuer lvl 
#data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/251027_city_issuerlevel_yieldspread.dta'))
data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/260324_city_issuerlevel_yieldspread.dta'))
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
desc <- full_sample[, .(all_go, city_utgo_only, frac_utgo, frac_ltgo, frac_rev, issuer_yield_spread, glm_proactive, state_ltgo_allowed, state_go_vote)]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Unit = 'Issuer',
             Mean = mean(col, na.rm = TRUE),
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
colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, Variable := c('GO Vote', 'Only UTGO Vote', 'Pct UTGO', 'Pct LTGO', 'Pct Revenue', 'Wtd. Avg. Yield Spread',
                         'Proactive State', 'LTGO Allowed', 'State GO Vote')]

# Round numeric columns to 2 decimal places
desc_col[, Mean := round(as.numeric(Mean), 2)]
desc_col[, Std := round(as.numeric(Std), 2)]
desc_col[, Min := round(as.numeric(Min), 2)]
desc_col[, P1 := round(as.numeric(P1), 2)]
desc_col[, Median := round(as.numeric(Median), 2)]
desc_col[, P99 := round(as.numeric(P99), 2)]
desc_col[, Max := round(as.numeric(Max), 2)]
# Format N with comma separator for thousands
desc_col[, N := format(as.integer(N), big.mark = ",")]

library(xtable)
latex_table <- xtable(
  desc_col
)

# Capture the xtable output
desc_table_output <- capture.output(
  print(
    latex_table,
    include.rownames = FALSE,
    sanitize.text.function = identity,
    tabular.environment = "tabular*",
    width = "\\textwidth",
    table.placement = "H"
  )
)

# Convert tabular* to use @{\extracolsep{\fill}} format
for (i in seq_along(desc_table_output)) {
  if (grepl("\\\\begin\\{tabular\\*\\}", desc_table_output[i])) {
    desc_table_output[i] <- gsub(
      "\\\\begin\\{tabular\\*\\}\\{\\\\textwidth\\}\\{([^}]+)\\}",
      "\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}\\1}",
      desc_table_output[i]
    )
    break
  }
}

# Replace \end{tabular*}
for (i in seq_along(desc_table_output)) {
  if (grepl("\\\\end\\{tabular\\*\\}", desc_table_output[i])) {
    desc_table_output[i] <- gsub("\\\\end\\{tabular\\*\\}", "\\\\end{tabular*}", desc_table_output[i])
    break
  }
}

# Add \toprule after the first \hline
for (i in seq_along(desc_table_output)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", desc_table_output[i])) {
    desc_table_output[i] <- "  \\toprule"
    break
  }
}

# Add panel title using add_panel function
desc_table_output <- add_panel(desc_table_output, 'Panel E: Debt choice descriptive statistics', ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tbl_dir, '/issuer_level_desc.tex'))



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
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     #fontsize = 'small',
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'GO Vote',
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



modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel A: GO vote required')


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
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     #fontsize = 'small',
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'Only UTGO Vote',
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




modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required')
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
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     #fontsize = 'small',
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'GO Vote',
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

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel A: GO vote required')
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_allgo.tex'))

# now, only UTGO
r1 <- feols(issuer_yield_spread ~ city_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc + glm_proactive  + state_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~fips))
summary(r3)





table_call <- etable(r1, r2, r3, 
                     coefstat = 'tstat',
                     drop = "Constant",
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     #fontsize = 'small',
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'Only UTGO Vote',
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

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required')
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_utgo_only.tex'))




#----------------------------
# Regressions
#----------------------------

issuer_lvl_all[, issuer_yield_spread_win := Winsorize(issuer_yield_spread, val = quantile(issuer_yield_spread, probs = c(0.01, 0.99), na.rm = T))]
cuts <- issuer_lvl_all[, quantile(issuer_yield_spread, probs = c(0.01, 0.99), na.rm = TRUE)]


r1 <- feols(frac_utgo ~ city_go_vote|group, data = issuer_lvl_all, vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote|group, data = issuer_lvl_all[utgo_only == 0], vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote + glm_proactive + state_ltgo_allowed|group, data = issuer_lvl_all[utgo_only == 0], vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(issuer_yield_spread ~ city_go_vote|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r4)
r5<- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote |group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r5)
r6 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote+ glm_proactive + state_ltgo_allowed|group, data = issuer_lvl_all,  vcov = vcov_cluster(~fips))
summary(r6)



table_call <- etable(r2, r5, 
       coefstat = 'tstat',
       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
       fitstat = c('n', 'ar2'), 
       se.below = TRUE, 
       digits = 3, 
       digits.stats = 3,
       signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
       tex = TRUE,
       #fontsize = 'small',
       dict = c(frac_utgo ='Pct UTGO',
                frac_ltgo = 'Pct LTGO',
                frac_rev = 'Pct Rev',
                issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                city_go_vote = 'Vote',
                state_go_vote = 'State GO Vote',
                state_ltgo_allowed = 'LTGO Allowed',
                glm_proactive = 'Proactive State',
                ln_county_debt_other = 'ln(Non-issuer county debt)',
                ln_gdp =  'County ln(GDP)', 
                ln_pop = 'County ln(Pop)' , 
                ln_pers_inc = 'County ln(Pers. Inc)', 
                ln_emp = 'County ln(Emp)', 
                group = 'State-Border', 
                fips = 'County'),
       placement = 'H',
       #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
       replace = TRUE)



modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
#modified_output <- add_panel(modified_output, 'Panel A: Debt choice - Border sample')

writeLines(modified_output, paste0(tbl_dir, '/debt_choice_border_state.tex'))



#----------------------------
# Regressions
#----------------------------

issuer_lvl_all[, issuer_yield_spread_win := Winsorize(issuer_yield_spread, val = quantile(issuer_yield_spread, probs = c(0.01, 0.99), na.rm = T))]
cuts <- issuer_lvl_all[, quantile(issuer_yield_spread, probs = c(0.01, 0.99), na.rm = TRUE)]

fixed_border <- issuer_lvl_all[!(group %in% c('Ohio/Kentucky', 'Michigan/Wisconsin'))]



r1 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote|group, data = fixed_border, vcov = vcov_cluster(~fips))
summary(r1)
r2 <- feols(frac_ltgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote|group, data = fixed_border, vcov = vcov_cluster(~fips))
summary(r2)
r3 <- feols(frac_rev ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote|group, data = fixed_border, vcov = vcov_cluster(~fips))
summary(r3)
r4 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + state_go_vote |group, data = fixed_border,  vcov = vcov_cluster(~fips))
summary(r4)




table_call <- etable(r2, r5, 
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     #fontsize = 'small',
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Rev',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'Vote',
                              state_go_vote = 'State GO Vote',
                              state_ltgo_allowed = 'LTGO Allowed',
                              glm_proactive = 'Proactive State',
                              ln_county_debt_other = 'ln(Non-issuer county debt)',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              group = 'State-Border', 
                              fips = 'County'),
                     placement = 'H',
                     #file = paste0(tbl_dir, '/debt_choice_border_state.tex'), 
                     replace = TRUE)



modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
#modified_output <- add_panel(modified_output, 'Panel A: Debt choice - Border sample')

writeLines(modified_output, paste0(tbl_dir, '/debt_choice_border_state_all_go_only.tex'))



