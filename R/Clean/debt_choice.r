# issuer - level regressions for border-state sample 
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, fixest)
# Load custom etable rounding functions
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/tax_privilege_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/state_policy_definitions.R')
tbl_dir <- '/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables'

#----------------------------
# Load data 
#----------------------------
# first issuer lvl 
data <- as.data.table(read_stata('~/Dropbox/Voting on Bonds/Data/Mergent/clean/260716_city_issuerlevel_yieldspread.dta'))
if (!'issuer_yield_spread' %in% names(data) && 'issuer_spread' %in% names(data)) {
  data[, issuer_yield_spread := issuer_spread]
}

# Preserve the original Gao et al. outcomes, then point the existing table
# variables to the pasted-formula NC/Garrett et al. weighted-average spreads.
spread_variables <- c(
  'issuer_spread', 'issuer_yield_spread', 'issuer_spread_go',
  'issuer_spread_utgo', 'issuer_spread_ltgo', 'issuer_spread_rev'
)
for (variable in spread_variables) {
  data[, (paste0(variable, '_gao')) := get(variable)]
}

nc_spreads <- fread(
  '~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Mergent/Clean/issuer_level_nc_yield_spreads.csv'
)
data <- merge(
  data,
  nc_spreads,
  by = c('state', 'seed_issuer'),
  all.x = TRUE,
  sort = FALSE
)

data[, issuer_spread := issuer_spread_nc]
data[, issuer_yield_spread := issuer_yield_spread_nc]
data[, issuer_spread_go := issuer_spread_go_nc]
data[, issuer_spread_utgo := issuer_spread_utgo_nc]
data[, issuer_spread_ltgo := issuer_spread_ltgo_nc]
data[, issuer_spread_rev := issuer_spread_rev_nc]

data[, city_rev_vote := ifelse(state == 'MO', 1, city_rev_vote)]
data[, city_go_vote := ifelse(state == 'RI', NA, city_go_vote)]
data[, super_majority := ifelse(state %in% super_majority_states, 1, 0)]
data[, tax_disclosure_req := as.integer(state %in% c('AZ', 'AR', 'NC', 'OH', 'OR', 'TX', 'UT', 'WA', 'WV'))]
data[, low_state_tax_privilege := as.integer(state %in% low_state_tax_privilege_states)]
data[, state_year := interaction(state, year, drop = TRUE)]
data[, issuer_amt_mil := issuer_amt / 1000000]
data[, ln_1p_issuer_amt := log1p(issuer_amt)]

data <- data[!is.na(city_go_vote)]
data <- data[!is.na(ln_pop) & !is.na(ln_county_debt_other)]

full_sample <- data
full_sample <- full_sample[insample == 1]
# load border state issuers 
border_state = fread('~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv')
border_state = unique(border_state[, .(state, seed_issuer, group, category)])
# only look at no revenue vote matches
#border_state <- border_state[category != 'grey']
border_state[, border_sample := 1]
data <- border_state[data, on = .(state, seed_issuer)]
#data[state == 'LA', state_ltgo_allowed := 0]
issuer_lvl_all <- data[border_sample == 1]
#issuer_lvl_all <- issuer_lvl_all[group %in% all_border_states]
issuer_lvl_all <- issuer_lvl_all[!is.na(group) & group != 'Rhode Island/Massachusetts']

#----------------------------
# Descriptives - full sample
#----------------------------
full_sample[, city_utgo_only := ifelse(city_go_vote == 1 & state %in% c('WA', 'MI', 'OH'),1 ,0)]
full_sample[, all_go := ifelse(city_go_vote == 1 & city_utgo_only == 0,1 ,0)]
desc <- full_sample[, .(all_go, city_utgo_only, frac_utgo, frac_ltgo, frac_rev, issuer_yield_spread, ln_county_debt_other, glm_proactive, state_ltgo_allowed, state_go_vote, low_state_tax_privilege)]

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
desc_col <- data.table::transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, Variable := c('GO Vote', 'Only UTGO Vote', 'Pct UTGO', 'Pct LTGO', 'Pct Revenue', 'Wtd. Avg. Yield Spread', 'ln(Non-issuer county debt)',
                         'Proactive State', 'LTGO Allowed', 'State GO Vote', 'Low Tax Priv.')]

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
r1 <- feols(frac_utgo ~ city_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r3)
r4 <- feols(frac_ltgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r4)
  r5 <- feols(frac_rev ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
  summary(r5)



table_call <- etable(r1, r3, r4, r5,
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
                     order = c("%city_go_vote"),
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'GO Vote',
                              low_state_tax_privilege = 'Low Tax Priv.',
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

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel A: GO vote required')


writeLines(modified_output, paste0(tbl_dir, '/debt_choice_allgo.tex'))
writeLines(modified_output, paste0(tbl_dir, '/issuer_aggregate_debt_choice_allgo.tex'))

# now, only UTGO
r1 <- feols(frac_utgo ~ city_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r3)
r4 <- feols(frac_ltgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r4)
r5 <- feols(frac_rev ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r5)



table_call <- etable(r1, r3, r4, r5,
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
                     order = c("%city_go_vote"),
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'Only UTGO Vote',
                              low_state_tax_privilege = 'Low Tax Priv.',
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

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required')
writeLines(modified_output, paste0(tbl_dir, '/debt_choice_utgo_only.tex'))
writeLines(modified_output, paste0(tbl_dir, '/issuer_aggregate_debt_choice_utgo_only.tex'))



#----------------------------
# Regressions - full sample yield spreads
#----------------------------


# first, any GO Vote required 
r1 <- feols(issuer_spread ~ city_go_vote, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r1)
r2 <- feols(issuer_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r2)
r3 <- feols(issuer_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r3)
r4 <- feols(issuer_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
 low_state_tax_privilege + issuer_mat + issuer_rating, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r4)
r4b <- feols(issuer_spread_go ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
 low_state_tax_privilege + issuer_mat_go + issuer_rating_go, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r4b)
r4c<- feols(issuer_spread_rev ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
 low_state_tax_privilege + issuer_mat_rev + issuer_rating_rev, data = full_sample[insample_allgo ==1], vcov = vcov_cluster(~state))
summary(r4c)



table_call <- etable(r1, r3, r4, r4b, r4c,
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
                     order = c("%city_go_vote"),
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_spread = 'Wtd. Avg. Yield Spread',
                              city_go_vote = 'GO Vote',
                              low_state_tax_privilege = 'Low Tax Priv.',
                              issuer_spread_go = 'Spread GO', 
                              issuer_spread_rev = 'Spread Rev',
                              state_go_vote = 'State GO Vote',
                              state_ltgo_allowed = 'LTGO Allowed',
                              glm_proactive = 'Proactive State',
                              issuer_mat = 'Wtd. Avg. Maturity',
                              issuer_rating = 'Wtd. Avg. Rating',
                              issuer_mat_go = 'Wtd. Avg. Maturity (GO)',
                              issuer_rating_go = 'Wtd. Avg. Rating (GO)',
                              issuer_mat_rev = 'Wtd. Avg. Maturity (Rev)',
                              issuer_rating_rev = 'Wtd. Avg. Rating (Rev)',
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

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel A: GO vote required', ncols = 6)
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_allgo_bond_type_spreads.tex'))

table_call <- etable(r4, r4b, r4c,
                     coefstat = 'tstat',
                     drop = "Constant",
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'),
                     se.below = TRUE,
                     digits = 3,
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10),
                     tex = TRUE,
                     order = c("%city_go_vote"),
                     dict = c(
                       issuer_spread = 'Full Wtd. Avg. Yield Spread',
                       issuer_spread_go = 'All GO Yield Spread',
                       issuer_spread_rev = 'Revenue Yield Spread',
                       city_go_vote = 'GO Vote',
                       low_state_tax_privilege = 'Low Tax Priv.',
                       state_go_vote = 'State GO Vote',
                       state_ltgo_allowed = 'LTGO Allowed',
                       glm_proactive = 'Proactive State',
                       issuer_mat = 'Wtd. Avg. Maturity',
                       issuer_rating = 'Wtd. Avg. Rating',
                       issuer_mat_go = 'Wtd. Avg. Maturity (GO)',
                       issuer_rating_go = 'Wtd. Avg. Rating (GO)',
                       issuer_mat_rev = 'Wtd. Avg. Maturity (Rev)',
                       issuer_rating_rev = 'Wtd. Avg. Rating (Rev)',
                       ln_county_debt_other = 'ln(Non-issuer county debt)',
                       ln_gdp = 'County ln(GDP)',
                       ln_pop = 'County ln(Pop)',
                       ln_pers_inc = 'County ln(Pers. Inc)'
                     ),
                     placement = 'H',
                     replace = TRUE)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel A: GO vote required', ncols = 4)
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_allgo.tex'))

# now, only UTGO
r1 <- feols(issuer_yield_spread ~ city_go_vote, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r1)
r2 <- feols(issuer_yield_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r2)
r3 <- feols(issuer_yield_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive  + state_go_vote + low_state_tax_privilege, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r3)
r4 <- feols(issuer_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
 low_state_tax_privilege + issuer_mat + issuer_rating, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r4)
r4b <- feols(issuer_spread_go ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
 low_state_tax_privilege + issuer_mat_go + issuer_rating_go, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r4b)
r4c<- feols(issuer_spread_rev ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
 low_state_tax_privilege + issuer_mat_rev + issuer_rating_rev, data = full_sample[insample_utgo_only ==1], vcov = vcov_cluster(~state))
summary(r4c)





table_call <- etable(r1,  r3, r4, r4b, r4c,
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
                     order = c("%city_go_vote"),
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              issuer_spread_go = 'Spread GO',
                              issuer_spread_rev = 'Spread Rev',
                              city_go_vote = 'Only UTGO Vote',
                              low_state_tax_privilege = 'Low Tax Priv.',
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

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required', ncols = 6)
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_utgo_only_bond_type_spreads.tex'))










table_call <- etable(r4, r4b, r4c,
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
                     order = c("%city_go_vote"),
                     dict = c(frac_utgo ='Pct UTGO',
                              frac_ltgo = 'Pct LTGO',
                              frac_rev = 'Pct Revenue',
                              issuer_spread = 'Full Wtd. Avg. Yield Spread',
                              issuer_spread_go = 'All GO Yield Spread',
                              issuer_spread_rev = 'Revenue Yield Spread',
                              city_go_vote = 'Only UTGO Vote',
                              low_state_tax_privilege = 'Low Tax Priv.',
                              state_go_vote = 'State GO Vote',
                              state_ltgo_allowed = 'LTGO Allowed',
                              glm_proactive = 'Proactive State',
                              issuer_mat = 'Wtd. Avg. Maturity',
                              issuer_rating = 'Wtd. Avg. Rating',
                              issuer_mat_go = 'Wtd. Avg. Maturity (GO)',
                              issuer_rating_go = 'Wtd. Avg. Rating (GO)',
                              issuer_mat_rev = 'Wtd. Avg. Maturity (Rev)',
                              issuer_rating_rev = 'Wtd. Avg. Rating (Rev)',
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

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel B: Only UTGO vote required', ncols = 4)
writeLines(modified_output, paste0(tbl_dir, '/yield_spread_utgo_only.tex'))



#----------------------------
# Regressions - border state
#----------------------------

fixed_border <- issuer_lvl_all[!(group %in% c('Ohio/Kentucky', 'Michigan/Wisconsin'))]
fixed_border[, state_year := interaction(state, year, drop = TRUE)]



r1 <- feols(frac_utgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + ln_county_debt_other + state_go_vote + low_state_tax_privilege|group, data = fixed_border, vcov = vcov_cluster(~state_year))
summary(r1)
r2 <- feols(frac_ltgo ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + ln_county_debt_other + state_go_vote + low_state_tax_privilege|group, data = fixed_border, vcov = vcov_cluster(~state_year))
summary(r2)
r3 <- feols(frac_rev ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + ln_county_debt_other + state_go_vote + low_state_tax_privilege|group, data = fixed_border, vcov = vcov_cluster(~state_year))
summary(r3)
r4 <- feols(issuer_yield_spread ~ city_go_vote  + ln_gdp + ln_pop + ln_pers_inc  + ln_county_debt_other + state_go_vote + low_state_tax_privilege |group, data = fixed_border,  vcov = vcov_cluster(~state_year))
summary(r4)




table_call <- etable(r1, r4, 
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
                              low_state_tax_privilege = 'Low Tax Priv.',
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

modified_output <- format_table(modified_output, cluster_level = "State-Year")
#modified_output <- add_panel(modified_output, 'Panel A: Debt choice - Border sample')

writeLines(modified_output, paste0(tbl_dir, '/debt_choice_border_state_all_go_only.tex'))

#----------------------------
# Regressions - supermajority split
#----------------------------

# first, any GO Vote required 
r1 <- feols(frac_utgo ~ city_go_vote*super_majority, data = full_sample, vcov = vcov_cluster(~state))
summary(r1)
r2 <- feols(frac_utgo ~ city_go_vote*super_majority  + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample, vcov = vcov_cluster(~state))
summary(r2)
r3 <- feols(frac_utgo ~ city_go_vote*super_majority  + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample, vcov = vcov_cluster(~state))
summary(r3)

r1y <- feols(issuer_yield_spread ~ city_go_vote*super_majority, data = full_sample, vcov = vcov_cluster(~state))
summary(r1y)
r2y <- feols(issuer_yield_spread ~ city_go_vote*super_majority  + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample, vcov = vcov_cluster(~state))
summary(r2y)
r3y <- feols(issuer_yield_spread ~ city_go_vote*super_majority  + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege, data = full_sample, vcov = vcov_cluster(~state))
summary(r3y)

table_call <- etable(r1, r3,
                     coefstat = 'tstat',
                     keep_raw = c("^city_go_vote$", "^super_majority$"),
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
                              super_majority = 'Supermajority State',
                              issuer_yield_spread = 'Wtd. Avg. Yield Spread',
                              low_state_tax_privilege = 'Low Tax Priv.',
                              city_go_vote = 'Vote',
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
                     #file = paste0(tbl_dir, '/debt_choice_super_majority.tex'), 
                     replace = TRUE)



modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State")
adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
if (length(adj_r2_idx) > 0) {
  modified_output <- append(modified_output, "   Controls                   & Yes            & Yes\\\\", after = adj_r2_idx[1])
}
modified_output <- add_panel(modified_output, 'Panel C: Full sample - supermajority split')


writeLines(modified_output, paste0(tbl_dir, '/debt_choice_super_majority.tex'))


#----------------------------
# Regressions - supermajority split - treat vs treat
#----------------------------


# first, any GO Vote required 
r1 <- feols(frac_utgo ~ super_majority, data = full_sample[city_go_vote == 1], vcov = vcov_cluster(~state))
summary(r1)
r2 <- feols(frac_utgo ~ super_majority  + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other, data = full_sample[city_go_vote == 1], vcov = vcov_cluster(~state))
summary(r2)
r3 <- feols(frac_utgo ~ super_majority  + ln_gdp + ln_pop + ln_pers_inc + ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote, data = full_sample[city_go_vote == 1], vcov = vcov_cluster(~state))
summary(r3)




table_call <- etable(r1, r3,
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
                              super_majority = 'Supermajority State',
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
                     #file = paste0(tbl_dir, '/debt_choice_super_majority_treat_only.tex'), 
                     replace = TRUE)



modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel B: GO Vote States Only')


writeLines(modified_output, paste0(tbl_dir, '/debt_choice_super_majority_treat_only.tex'))

#==============================================================================
# Issuer-aggregate analogues of the point-in-time tables
#==============================================================================
# These models use debt issued over the full 2000-2020 sample. Census debt is
# unavailable at this unit, so county debt issued by other entities replaces
# the point-in-time county debt measure and Census debt is not a control.

issuer_dict <- c(
  frac_utgo = 'Pct UTGO',
  issuer_spread = 'Full Wtd. Avg. Yield Spread',
  issuer_spread_go = 'All GO Yield Spread',
  issuer_spread_rev = 'Revenue Yield Spread',
  issuer_amt_mil = 'Mergent GO + Revenue Debt',
  ln_1p_issuer_amt = 'ln(1 + Mergent GO + Revenue Debt)',
  city_go_vote = 'GO Vote',
  super_majority = 'GO Vote $\\times$ Supermajority',
  tax_disclosure_req = 'GO Vote $\\times$ Tax Disclosure Req',
  ln_gdp = 'County ln(GDP)',
  ln_pop = 'City ln(Pop)',
  ln_pers_inc = 'County ln(Pers. Inc)',
  ln_county_debt_other = 'ln(Non-issuer county debt)',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  low_state_tax_privilege = 'Low Tax Priv.',
  issuer_mat = 'Wtd. Avg. Maturity',
  issuer_rating = 'Wtd. Avg. Rating',
  issuer_mat_go = 'Wtd. Avg. Maturity (GO)',
  issuer_rating_go = 'Wtd. Avg. Rating (GO)',
  issuer_mat_rev = 'Wtd. Avg. Maturity (Rev)',
  issuer_rating_rev = 'Wtd. Avg. Rating (Rev)',
  group = 'State-Border'
)

add_controls_row <- function(table_output, values) {
  adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", table_output)
  if (length(adj_r2_idx) > 0) {
    row <- paste0('   Controls                   & ', paste(values, collapse = '            & '), '\\\\')
    table_output <- append(table_output, row, after = adj_r2_idx[1])
  }
  table_output
}

#----------------------------
# Full-sample cross-sectional policy tests
#----------------------------
issuer_policy_super <- feols(
  frac_utgo ~ city_go_vote + super_majority + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
    low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

issuer_policy_disclosure <- feols(
  frac_utgo ~ city_go_vote + tax_disclosure_req + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
    low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  issuer_policy_super, issuer_policy_disclosure,
  coefstat = 'tstat',
  drop = 'Constant',
  keep_raw = c('^city_go_vote$', '^super_majority$', '^tax_disclosure_req$'),
  order = c('%city_go_vote', '%super_majority', '%tax_disclosure_req'),
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = issuer_dict,
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_controls_row(modified_output, c('Yes', 'Yes'))
modified_output <- add_panel(
  modified_output,
  'Panel C: Full-period issuer aggregates, cross-sectional policy tests',
  ncols = 3
)
writeLines(modified_output, file.path(tbl_dir, 'issuer_aggregate_debt_choice_policy_tests.tex'))

issuer_yield_policy_super <- feols(
  issuer_spread ~ city_go_vote + super_majority + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating + issuer_mat + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

issuer_yield_policy_disclosure <- feols(
  issuer_spread ~ city_go_vote + tax_disclosure_req + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating + issuer_mat + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  issuer_yield_policy_super, issuer_yield_policy_disclosure,
  coefstat = 'tstat',
  drop = 'Constant',
  keep_raw = c('^city_go_vote$', '^super_majority$', '^tax_disclosure_req$'),
  order = c('%city_go_vote', '%super_majority', '%tax_disclosure_req'),
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = issuer_dict,
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_controls_row(modified_output, c('Yes', 'Yes'))
modified_output <- add_panel(
  modified_output,
  'Panel D: Full-period aggregate yield spread, cross-sectional policy tests',
  ncols = 3
)
writeLines(modified_output, file.path(tbl_dir, 'issuer_aggregate_yield_policy_tests.tex'))

#----------------------------
# Full-sample aggregate yield spreads
#----------------------------
issuer_yield_all <- feols(
  issuer_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating + issuer_mat + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

issuer_yield_go <- feols(
  issuer_spread_go ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating_go + issuer_mat_go + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

issuer_yield_rev <- feols(
  issuer_spread_rev ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating_rev + issuer_mat_rev + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  issuer_yield_all, issuer_yield_go, issuer_yield_rev,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = issuer_dict,
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel C: Full-period issuer aggregate yield spreads, full sample',
  ncols = 4
)
modified_output <- append(modified_output, '\\small', after = 1)
writeLines(modified_output, file.path(tbl_dir, 'issuer_aggregate_yields_full_sample.tex'))

#----------------------------
# Full-sample Mergent debt stock
#----------------------------
issuer_debt_ols <- feols(
  ln_1p_issuer_amt ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
    low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  issuer_debt_ols,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = issuer_dict,
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel A: Full-period Mergent debt issued, full sample',
  ncols = 2
)
writeLines(modified_output, file.path(tbl_dir, 'issuer_aggregate_debt_stock_ols_full_sample.tex'))

issuer_debt_ppml <- fepois(
  issuer_amt_mil ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
    low_state_tax_privilege,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

table_call <- etable(
  issuer_debt_ppml,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = issuer_dict,
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel D: PPML full-period Mergent debt issued, full sample',
  ncols = 2
)
writeLines(modified_output, file.path(tbl_dir, 'issuer_aggregate_debt_stock_ppml_full_sample.tex'))

#----------------------------
# Border-state analogue
#----------------------------
# The point-in-time table excludes the RI/MA and ME/NH groups. Keep the same
# border pairs here; unlike the older aggregate table, do not drop OH/KY or MI/WI.
issuer_border_comparable <- issuer_lvl_all[group != 'Maine/New Hampshire']

issuer_border_choice <- feols(
  frac_utgo ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + state_go_vote + low_state_tax_privilege | group,
  data = issuer_border_comparable,
  vcov = vcov_cluster(~state_year)
)

issuer_border_yield <- feols(
  issuer_spread ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + issuer_rating + issuer_mat + state_go_vote +
    low_state_tax_privilege | group,
  data = issuer_border_comparable,
  vcov = vcov_cluster(~state_year)
)

issuer_border_debt <- fepois(
  issuer_amt_mil ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
    ln_county_debt_other + state_go_vote + low_state_tax_privilege | group,
  data = issuer_border_comparable,
  vcov = vcov_cluster(~state_year)
)

table_call <- etable(
  issuer_border_choice, issuer_border_yield, issuer_border_debt,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(issuer_dict, city_go_vote = 'Vote'),
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State-Year')
modified_output <- modified_output[!trimws(modified_output) %in% c('& \\\\', '\\\\')]
modified_output <- add_panel(
  modified_output,
  'Panel E: Full-period issuer aggregates, border-state sample',
  ncols = 4
)
writeLines(modified_output, file.path(tbl_dir, 'issuer_aggregate_border_state.tex'))

#----------------------------
# Full-period purpose substitution
#----------------------------
# The DPC panel is already at bond x purpose-category. Re-aggregate its GO and
# revenue bonds to issuer x category, then attach the current issuer-level
# sample and controls by state and issuer name. This avoids unsafe ID-only joins.
purpose_categories <- c(
  'other_public_buildings',
  'public_safety',
  'recreation_amenities',
  'transportation',
  'utilities',
  'other'
)
purpose_headers <- c(
  'Public Bldg.',
  'Public Safety',
  'Recreation',
  'Transport.',
  'Utilities',
  'Other'
)

purpose_bonds <- fread(file.path(
  '/Users/kmunevar/Dropbox/Voting on Bonds/Data/DPC Data/Use Of Proceeds/Purposes Substitution',
  '260707_dpc_purpose_substitution_cusip_category_panel.csv'
))
purpose_covered_issuers <- unique(
  purpose_bonds[go_any == 1 | revenue_bond == 1, .(state, seed_issuer)]
)
purpose_bonds <- purpose_bonds[purpose_category %in% purpose_categories]

purpose_amounts <- purpose_bonds[
  , .(
    category_amount = sum(ifelse(go_any == 1 | revenue_bond == 1, amount, 0), na.rm = TRUE),
    revenue_amount = sum(ifelse(revenue_bond == 1, amount, 0), na.rm = TRUE)
  ),
  by = .(state, seed_issuer, purpose_category)
]

issuer_purpose_controls <- unique(
  full_sample[, .(
    state,
    seed_issuer,
    seed_issuer_id,
    city_go_vote,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    low_state_tax_privilege
  )],
  by = c('state', 'seed_issuer')
)
issuer_purpose_controls <- purpose_covered_issuers[
  issuer_purpose_controls,
  on = .(state, seed_issuer),
  nomatch = 0
]

issuer_purpose <- issuer_purpose_controls[
  , .(purpose_category = purpose_categories),
  by = .(
    state,
    seed_issuer,
    seed_issuer_id,
    city_go_vote,
    ln_gdp,
    ln_pop,
    ln_pers_inc,
    ln_county_debt_other,
    glm_proactive,
    state_ltgo_allowed,
    state_go_vote,
    low_state_tax_privilege
  )
]
issuer_purpose <- purpose_amounts[
  issuer_purpose,
  on = .(state, seed_issuer, purpose_category)
]
issuer_purpose[is.na(category_amount), category_amount := 0]
issuer_purpose[is.na(revenue_amount), revenue_amount := 0]
issuer_purpose[, category_amount_mil := category_amount / 1000000]
issuer_purpose[, share_revenue_vs_go_amount := fifelse(
  category_amount > 0,
  revenue_amount / category_amount,
  NA_real_
)]

purpose_amount_models <- lapply(purpose_categories, function(category) {
  fepois(
    category_amount_mil ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
      ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
      low_state_tax_privilege,
    data = issuer_purpose[purpose_category == category],
    vcov = vcov_cluster(~state)
  )
})

purpose_no_vote_means <- vapply(purpose_categories, function(category) {
  mean(
    issuer_purpose[purpose_category == category & city_go_vote == 0]$category_amount_mil,
    na.rm = TRUE
  )
}, numeric(1))
purpose_pct_effects <- vapply(purpose_amount_models, function(model) {
  100 * expm1(coef(model)[['city_go_vote']])
}, numeric(1))

table_call <- etable(
  purpose_amount_models[[1]], purpose_amount_models[[2]], purpose_amount_models[[3]],
  purpose_amount_models[[4]], purpose_amount_models[[5]], purpose_amount_models[[6]],
  headers = purpose_headers,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(issuer_dict, category_amount_mil = 'Par Issued (millions)'),
  extralines = list(
    'No-vote mean (millions)' = sprintf('%.1f', purpose_no_vote_means),
    'Implied pct. effect' = sprintf('%.1f', purpose_pct_effects)
  ),
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel B: Full-period purpose-category amounts, full sample',
  ncols = 7
)
modified_output <- append(modified_output, '\\small', after = 1)
writeLines(
  modified_output,
  file.path(tbl_dir, 'issuer_aggregate_purpose_category_amount_ppml_full_sample.tex')
)

purpose_revenue_models <- lapply(purpose_categories, function(category) {
  feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc +
      ln_county_debt_other + glm_proactive + state_ltgo_allowed + state_go_vote +
      low_state_tax_privilege,
    data = issuer_purpose[purpose_category == category],
    vcov = vcov_cluster(~state)
  )
})

table_call <- etable(
  purpose_revenue_models[[1]], purpose_revenue_models[[2]], purpose_revenue_models[[3]],
  purpose_revenue_models[[4]], purpose_revenue_models[[5]], purpose_revenue_models[[6]],
  headers = purpose_headers,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(issuer_dict, share_revenue_vs_go_amount = 'Revenue Amt. Share'),
  placement = 'H'
)
modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel C: Full-period revenue share within purpose category, full sample',
  ncols = 7
)
modified_output <- append(modified_output, '\\small', after = 1)
writeLines(
  modified_output,
  file.path(tbl_dir, 'issuer_aggregate_purpose_revenue_share_full_sample.tex')
)

#----------------------------
# Printable wrappers corresponding to the four point-in-time draft tables
#----------------------------
processed_dir <- '/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/processed'
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

writeLines(c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption{\\textbf{Debt Choice: Full-Period Issuer Aggregates}}',
  '\\label{tab:debt_choice_full_sample_issuer_aggregate}',
  '\\parbox{\\textwidth}{This table repeats the point-in-time debt-choice specifications using debt issued by each issuer over the full 2000--2020 sample. County controls use GDP, personal income, city population, and debt issued by other entities in the county. Standard errors are clustered by state.}',
  '\\end{table}',
  '\\input{tables/clean/raw/issuer_aggregate_debt_choice_allgo}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/issuer_aggregate_debt_choice_utgo_only}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/issuer_aggregate_debt_choice_policy_tests}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/issuer_aggregate_yield_policy_tests}'
), file.path(processed_dir, 'debt_choice_full_sample_issuer_aggregate.tex'))

writeLines(c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption{\\textbf{Debt Choice and Aggregate Yields: Full-Period Border-State Issuer Aggregates}}',
  '\\label{tab:debt_choice_border_state_issuer_aggregate}',
  '\\parbox{\\textwidth}{This table repeats the point-in-time border-state specifications using debt issued by each issuer over the full 2000--2020 sample. Column 3 uses total Mergent GO plus revenue debt rather than Census debt. State-border fixed effects are included and standard errors are clustered by state-year; year is fixed at 2001 in this issuer-level cross section, so these clusters coincide with state clusters.}',
  '\\end{table}',
  '\\input{tables/clean/raw/issuer_aggregate_border_state}'
), file.path(processed_dir, 'debt_choice_border_state_issuer_aggregate.tex'))

writeLines(c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption{\\textbf{Aggregate Yields and Debt: Full-Period Issuer Aggregates}}',
  '\\label{tab:issuer_yields_full_sample_issuer_aggregate}',
  '\\parbox{\\textwidth}{This table repeats the point-in-time aggregate-yield and PPML debt specifications using debt issued by each issuer over the full 2000--2020 sample. The yield regressions omit Census total debt, which is unavailable at this unit, and control for debt issued by other entities in the county. The debt panel reports only total Mergent GO plus revenue debt. Standard errors are clustered by state.}',
  '\\end{table}',
  '\\input{tables/clean/raw/issuer_aggregate_yields_full_sample}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/issuer_aggregate_debt_stock_ppml_full_sample}'
), file.path(processed_dir, 'issuer_yields_full_sample_issuer_aggregate.tex'))

writeLines(c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption{\\textbf{Debt and Revenue Substitution: Full-Period Issuer Aggregates}}',
  '\\label{tab:substitution_issuer_aggregate}',
  '\\parbox{\\textwidth}{This table repeats the point-in-time substitution specifications using debt issued over the full 2000--2020 sample. Panel A reports only total Mergent GO plus revenue debt because Census debt outcomes are unavailable in the issuer aggregate. Panels B and C aggregate DPC use-of-proceeds categories over the full sample. Standard errors are clustered by state.}',
  '\\end{table}',
  '\\input{tables/clean/raw/issuer_aggregate_debt_stock_ols_full_sample}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/issuer_aggregate_purpose_category_amount_ppml_full_sample}',
  '\\vspace{10pt}',
  '\\input{tables/clean/raw/issuer_aggregate_purpose_revenue_share_full_sample}'
), file.path(processed_dir, 'substitution_issuer_aggregate.tex'))
