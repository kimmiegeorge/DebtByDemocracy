# 04: Secondary-market trading results (Table 6; also Table 1 inputs)
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_tax_privilege_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_border_pair_definitions.R')
tables_wd <- "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables/"

#----------------------------------
# main df
#----------------------------------

data <- fread('~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/MSRB/Processed/Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv')
data[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
data[state == 'MO', city_rev_vote := 1]
data[state == 'RI', city_go_vote := NA]
data <- data[city == 1 & !is.na(city_go_vote)  & go_unlim == 1 & !is.na(callable)]
add_low_state_tax_privilege(data)

# Use the exact raw customer-trade outcomes and rating-category fixed effects
# reported in Table 6. Sensitivity variants were removed because they are not
# used by the paper or either response document.
outcome_sources <- paste0(
  c(
    'traded_before_maturity',
    'retail_traded_before_maturity',
    'institutional_traded_before_maturity'
  ),
  '_raw'
)
missing_raw_outcomes <- setdiff(outcome_sources, names(data))
if (length(missing_raw_outcomes) > 0L) {
  stop('Missing raw trade outcomes: ', paste(missing_raw_outcomes, collapse = ', '))
}
data[, traded_before_maturity := get(outcome_sources[1L])]
data[, retail_traded_before_maturity := get(outcome_sources[2L])]
data[, institutional_traded_before_maturity := get(outcome_sources[3L])]
data[, disclosure_control := disclosed_before_maturity]
disclosure_label <- 'Continuing Disclosure'

if (!'rating_fe' %in% names(data) || any(is.na(data$rating_fe))) {
  stop('rating_fe is required and cannot contain missing values')
}

data[, state_year := interaction(state, year, drop = TRUE)]
#----------------------------------
# border state
#----------------------------------

border_states <- fread('~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv')
border_states <- filter_paper_border_pairs(border_states)
border_states <- border_states[go_unlim == 1]
#border_states <- Wins(border_states, col_list)
# seed_issuer_id is reused by three pairs of municipalities. State and issuer
# name are the stable border-sample key used elsewhere in the clean R code.
border_states <- unique(border_states[, .(state, seed_issuer, group)])
border_states <- data[border_states, on = .(state, seed_issuer)]
border_states <- border_states[!is.na(cusip)]
border_states[, state_year := interaction(state, year, drop = TRUE)]

#----------------------------------
# descriptives
#----------------------------------
# DESCRIPTIVES - ELECTION LEVEL 
desc_vars <- c(
  'city_go_vote', 'traded_before_maturity', 'retail_traded_before_maturity',
  'institutional_traded_before_maturity', 'low_state_tax_privilege',
  'disclosure_control', 'ln_amount', 'ln_maturity_mths', 'callable',
  'sinkable', 'insured'
)
desc <- data[year > 2004 & !is.na(ln_gdp), ..desc_vars]

desc_col <- desc[, lapply(.SD, function(col) {
  stats <- c(Unit = 'Bond',
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

desc_labels <- c(
  'Vote', 'Trade', 'Retail Trade', 'Inst. Trade', 'Low Tax Priv.',
  disclosure_label, 'Amount', 'Maturity', 'Callable', 'Sinkable',
  'Insured'
)
desc_col[, Variable := desc_labels]

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
desc_table_output <- add_panel(desc_table_output, 'Panel D: Secondary market trading descriptive statistics', ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tables_wd, '/secondary_market_descriptives.tex'))



#----------------------------------
# reg
#----------------------------------


r1 <- feols(traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~state, 
            data = data[year > 2004])

r2 <- feols(traded_before_maturity ~ city_go_vote + low_state_tax_privilege + disclosure_control +  ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
            + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad, 
            ~state, 
            data = data[year > 2004])



#----------------------------------
# reg - border state
#----------------------------------

r1b <- feols(traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~state_year, 
            data = border_states[year > 2004])


r2b <- feols(traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~state_year, 
            data = border_states[year > 2004])


#----------------------------------
# reg
#----------------------------------


r1_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~state, 
            data = data[year > 2004])

r2_r <- feols(retail_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~state, 
            data = data[year > 2004])



#----------------------------------
# reg - border state
#----------------------------------

r1b_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~state_year, 
             data = border_states[year > 2004])


r2b_r <- feols(retail_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~state_year, 
             data = border_states[year > 2004])


#----------------------------------
# reg
#----------------------------------


r1_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~state, 
            data = data[year > 2004])


r2_i <- feols(institutional_traded_before_maturity ~ city_go_vote +  low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~state, 
            data = data[year > 2004])



#----------------------------------
# reg - border state
#----------------------------------

r1b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosure_control +  ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~state_year, 
             data = border_states[year > 2004])


r2b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~state_year, 
             data = border_states[year > 2004])


r2 <- update(r2, . ~ . - rating_num | . + rating_fe)
r2_r <- update(r2_r, . ~ . - rating_num | . + rating_fe)
r2_i <- update(r2_i, . ~ . - rating_num | . + rating_fe)
r2b <- update(r2b, . ~ . - rating_num | . + rating_fe)
r2b_r <- update(r2b_r, . ~ . - rating_num | . + rating_fe)
r2b_i <- update(r2b_i, . ~ . - rating_num | . + rating_fe)






#----------------------------------
# alternative output
#----------------------------------

# full sample
table_call <- etable(r2, r2_r, r2_i, 
                     #title = 'Secondary Market Trading and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     #headers = list("Full Sample" = 2, "State-Border Sample" = 2),
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     drop_raw = c("ln_gdp", "ln_pop", "ln_pers_inc", "ln_emp"),
                     order = c("%city_go_vote", "%low_state_tax_privilege", "%disclosure_control"),
                     extralines = list("-^County Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              low_state_tax_privilege = 'Low Tax Priv.',
                              disclosure_control = disclosure_label,
                              avg_disclosures_per_year_before_maturity = 'CD Per Year',
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rating_num = 'Rating',
                              rating_fe = 'Rating',
                              unrated = 'Unrated',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              
                              group = 'Border', 
                              yrmonth = 'YM',
                              year = 'Year',
                              purp_broad = 'Purpose',
                              ym = 'Year-Month',
                              issue_id = 'Issue'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/bond_yields.tex'), 
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, 'Panel A: Full sample')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_full_sample_tax.tex'))


# border sample
table_call <- etable(r2b, r2b_r, r2b_i,  
                     #title = 'Secondary Market Trading and Referendum Requirements',
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3", 
                     #headers = list("Full Sample" = 2, "State-Border Sample" = 2),
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep_raw = c("city_go_vote", "low_state_tax_privilege", "disclosure_control"),
                     order = c("%city_go_vote", "%low_state_tax_privilege", "%disclosure_control"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              disclosure_control = disclosure_label,
                              low_state_tax_privilege = 'Low Tax Priv.',
                              avg_disclosures_per_year_before_maturity = 'CD Per Year',
                              ln_amount = 'Amount',
                              ln_maturity_mths = 'Maturity',
                              callable = 'Callable',
                              sinkable = 'Sinkable',
                              insured = 'Insured', 
                              rating_num = 'Rating',
                              rating_fe = 'Rating',
                              unrated = 'Unrated',
                              ln_gdp =  'County ln(GDP)', 
                              ln_pop = 'County ln(Pop)' , 
                              ln_pers_inc = 'County ln(Pers. Inc)', 
                              ln_emp = 'County ln(Emp)', 
                              
                              group = 'State-Border', 
                              yrmonth = 'YM',
                              year = 'Year',
                              purp_broad = 'Purpose',
                              ym = 'Year-Month',
                              issue_id = 'Issue'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/bond_yields.tex'), 
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State-Year")
modified_output <- add_panel(modified_output, 'Panel B: Border-city sample')

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_border_sample_tax.tex'))
