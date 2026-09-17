rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/tax_privilege_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/state_policy_definitions.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/border_pair_definitions.R')
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

# The official specification uses all raw customer trades and rating-category
# fixed effects. Environment variables retain the audited sensitivity variants.
# raw_yield additionally requires a reported trade yield; raw_buys keeps customer
# buys only; same_day_match retains the legacy interdealer match but permits
# negative finite markups; and the gt_100k variants use a strict institutional
# cutoff.
outcome_variant <- tolower(Sys.getenv('TRADE_BEFORE_MATURITY_OUTCOMES', unset = 'raw'))
if (!outcome_variant %in% c('legacy', 'same_day_match', 'raw', 'raw_yield', 'raw_buys', 'raw_gt_100k', 'raw_buys_gt_100k')) {
  stop('TRADE_BEFORE_MATURITY_OUTCOMES must be legacy, same_day_match, raw, raw_yield, raw_buys, raw_gt_100k, or raw_buys_gt_100k')
}
disclosure_variant <- tolower(Sys.getenv('TRADE_BEFORE_MATURITY_DISCLOSURE', unset = 'indicator'))
if (!disclosure_variant %in% c('indicator', 'amount')) {
  stop('TRADE_BEFORE_MATURITY_DISCLOSURE must be indicator or amount')
}
rating_variant <- tolower(Sys.getenv('TRADE_BEFORE_MATURITY_RATING', unset = 'rating_fe'))
if (!rating_variant %in% c('legacy', 'unrated_indicator', 'rating_fe')) {
  stop('TRADE_BEFORE_MATURITY_RATING must be legacy, unrated_indicator, or rating_fe')
}
official_spec <- outcome_variant == 'raw' &
  disclosure_variant == 'indicator' & rating_variant == 'rating_fe'
sensitivity_suffix <- paste0(
  switch(
    outcome_variant,
    legacy = '', same_day_match = '_same_day_match', raw = '_raw',
    raw_yield = '_raw_yield', raw_buys = '_raw_buys',
    raw_gt_100k = '_raw_gt_100k', raw_buys_gt_100k = '_raw_buys_gt_100k'
  ),
  ifelse(disclosure_variant == 'amount', '_cd_amount', ''),
  switch(
    rating_variant,
    legacy = '', unrated_indicator = '_unrated_indicator', rating_fe = '_rating_fe'
  )
)
output_suffix <- if (official_spec) {
  ''
} else if (nzchar(sensitivity_suffix)) {
  sensitivity_suffix
} else {
  '_legacy_numeric_rating'
}
panel_details <- if (official_spec) character(0) else {
  c(
    if (outcome_variant == 'same_day_match') 'same-day match; any finite markup',
    if (outcome_variant == 'raw') 'raw customer trades',
    if (outcome_variant == 'raw_yield') 'raw customer trades; nonmissing yield',
    if (outcome_variant == 'raw_buys') 'raw customer buys',
    if (outcome_variant == 'raw_gt_100k') 'raw customer trades; institutional > $100,000',
    if (outcome_variant == 'raw_buys_gt_100k') 'raw customer buys; institutional > $100,000',
    if (disclosure_variant == 'amount') 'CD per year',
    if (rating_variant == 'unrated_indicator') 'unrated indicator',
    if (rating_variant == 'rating_fe') 'rating FE'
  )
}
panel_suffix <- if (length(panel_details) > 0) {
  paste0(' (', paste(panel_details, collapse = '; '), ')')
} else {
  ''
}
if (outcome_variant != 'legacy') {
  outcome_sources <- switch(
    outcome_variant,
    same_day_match = paste0(
      c('traded_before_maturity', 'retail_traded_before_maturity',
        'institutional_traded_before_maturity'), '_same_day_match'
    ),
    raw = paste0(
      c('traded_before_maturity', 'retail_traded_before_maturity',
        'institutional_traded_before_maturity'), '_raw'
    ),
    raw_yield = paste0(
      c('traded_before_maturity', 'retail_traded_before_maturity',
        'institutional_traded_before_maturity'), '_raw_yield'
    ),
    raw_buys = paste0(
      c('traded_before_maturity', 'retail_traded_before_maturity',
        'institutional_traded_before_maturity'), '_raw_buys'
    ),
    raw_gt_100k = c(
      'traded_before_maturity_raw', 'retail_traded_before_maturity_raw',
      'institutional_traded_before_maturity_raw_gt_100k'
    ),
    raw_buys_gt_100k = c(
      'traded_before_maturity_raw_buys', 'retail_traded_before_maturity_raw_buys',
      'institutional_traded_before_maturity_raw_buys_gt_100k'
    )
  )
  required_raw_outcomes <- outcome_sources
  missing_raw_outcomes <- setdiff(required_raw_outcomes, names(data))
  if (length(missing_raw_outcomes) > 0) {
    stop(paste('Missing raw trade outcomes:', paste(missing_raw_outcomes, collapse = ', ')))
  }
  data[, traded_before_maturity := get(outcome_sources[1])]
  data[, retail_traded_before_maturity := get(outcome_sources[2])]
  data[, institutional_traded_before_maturity := get(outcome_sources[3])]
}
disclosure_label <- ifelse(
  disclosure_variant == 'indicator', 'Continuing Disclosure', 'CD Per Year'
)
data[, disclosure_control := if (disclosure_variant == 'indicator') {
  disclosed_before_maturity
} else {
  avg_disclosures_per_year_before_maturity
}]

if (rating_variant == 'unrated_indicator') {
  if (!'rated' %in% names(data)) {
    stop('Missing rated indicator needed for the unrated_indicator specification')
  }
  if (any(is.na(data$rated))) {
    stop('The rated indicator contains missing values')
  }
  data[, unrated := as.integer(rated == 0)]
  data[unrated == 1, rating_num := 0]
} else if (rating_variant == 'rating_fe') {
  if (!'rating_fe' %in% names(data)) {
    stop('Missing rating_fe needed for the rating FE specification')
  }
  if (any(is.na(data$rating_fe))) {
    stop('rating_fe contains missing values')
  }
}

data[, super_majority := ifelse(state %in% super_majority_states, 1, 0)]
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
# disclosure measures for heterogeneity tests
#----------------------------------

# Website disclosure is only available for the border sample. Match the
# election-outcomes specification: high bond disclosure is above-median bond text.
website_disclosure <- fread(
  '~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/Websites/border_state_website_data_with_recovered.csv',
  select = c('seed_issuer_id', 'seed_issuer', 'year', 'total_subs', 'bond_count')
)
website_disclosure[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
website_disclosure <- website_disclosure[total_subs == 50 & !is.na(seed_issuer_id)]
website_disclosure <- unique(website_disclosure[, .(seed_issuer_id, seed_issuer, year, bond_count)])
website_disclosure[, high_bond_count := ifelse(bond_count > median(bond_count, na.rm = TRUE), 1, 0)]
border_states <- website_disclosure[, .(seed_issuer_id, seed_issuer, year, bond_count, high_bond_count)][
  border_states,
  on = .(seed_issuer_id, seed_issuer, year)
]

# Media disclosure is available for the full sample at the issuer-month level.
# The source file has duplicate issuer-month rows with identical coverage values,
# so unique() avoids multiplying the bond-level sample during the merge.
media_disclosure <- fread(
  '~/Dropbox/Voting on Bonds/Data/Clean_Intermediate/News/Issuance_Lvl_News_With_Lagged_News.csv',
  select = c('seed_issuer_id', 'state', 'year', 'month', 'total_rp_articles_12_0')
)
media_disclosure[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
media_disclosure <- unique(media_disclosure)
media_disclosure[, high_articles_12_0 := ifelse(
  total_rp_articles_12_0 > median(total_rp_articles_12_0, na.rm = TRUE), 1, 0
)]
data <- media_disclosure[, .(seed_issuer_id, state, year, month, total_rp_articles_12_0, high_articles_12_0)][
  data,
  on = .(seed_issuer_id, state, year, month)
]


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
if (rating_variant != 'rating_fe') {
  desc_vars <- c(desc_vars, 'rating_num')
}
if (rating_variant == 'unrated_indicator') {
  desc_vars <- c(desc_vars, 'unrated')
}
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
if (rating_variant != 'rating_fe') {
  desc_labels <- c(desc_labels, 'Rating')
}
if (rating_variant == 'unrated_indicator') {
  desc_labels <- c(desc_labels, 'Unrated')
}
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
desc_table_output <- add_panel(desc_table_output, paste0('Panel D: Secondary market trading descriptive statistics', panel_suffix), ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tables_wd, '/secondary_market_descriptives', output_suffix, '.tex'))



#----------------------------------
# reg
#----------------------------------


r1 <- feols(traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~state, 
            data = data[year > 2004])
summary(r1)

r2 <- feols(traded_before_maturity ~ city_go_vote + low_state_tax_privilege + disclosure_control +  ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
            + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad, 
            ~state, 
            data = data[year > 2004])
summary(r2)



#----------------------------------
# reg - border state
#----------------------------------

r1b <- feols(traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~state_year, 
            data = border_states[year > 2004])
summary(r1b)


r2b <- feols(traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~state_year, 
            data = border_states[year > 2004])
summary(r2b)


#----------------------------------
# reg
#----------------------------------


r1_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~state, 
            data = data[year > 2004])
summary(r1_r)

r2_r <- feols(retail_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~state, 
            data = data[year > 2004])
summary(r2_r)



#----------------------------------
# reg - border state
#----------------------------------

r1b_r <- feols(retail_traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~state_year, 
             data = border_states[year > 2004])
summary(r1b_r)


r2b_r <- feols(retail_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~state_year, 
             data = border_states[year > 2004])
summary(r2b_r)


#----------------------------------
# reg
#----------------------------------


r1_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosure_control + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num 
            +ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad, 
            ~state, 
            data = data[year > 2004])
summary(r1_i)


r2_i <- feols(institutional_traded_before_maturity ~ city_go_vote +  low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
              callable + sinkable + insured + rating_num + 
              + ln_gdp + ln_pop + ln_pers_inc  |year + purp_broad , 
            ~state, 
            data = data[year > 2004])
summary(r2_i)



#----------------------------------
# reg - border state
#----------------------------------

r1b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + disclosure_control +  ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc   |year + purp_broad + group, 
            ~state_year, 
             data = border_states[year > 2004])
summary(r1b_i)


r2b_i <- feols(institutional_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +  disclosure_control  + ln_amount +ln_maturity_mths + 
               callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc    |year + purp_broad + group , 
            ~state_year, 
             data = border_states[year > 2004])
summary(r2b_i)


#----------------------------------
# reg - investor response by website disclosure
#----------------------------------

r_web <- feols(traded_before_maturity ~ city_go_vote * high_bond_count + disclosure_control + ln_amount + ln_maturity_mths + 
                 callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group,
            ~state_year, 
               data = border_states[year > 2004 & !is.na(high_bond_count)])
summary(r_web)

r_web_r <- feols(retail_traded_before_maturity ~ city_go_vote * high_bond_count + disclosure_control + ln_amount + ln_maturity_mths + 
                   callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group,
            ~state_year, 
                 data = border_states[year > 2004 & !is.na(high_bond_count)])
summary(r_web_r)

r_web_i <- feols(institutional_traded_before_maturity ~ city_go_vote * high_bond_count + disclosure_control + ln_amount + ln_maturity_mths + 
                   callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group,
            ~state_year, 
                 data = border_states[year > 2004 & !is.na(high_bond_count)])
summary(r_web_i)


#----------------------------------
# reg - investor response by media disclosure
#----------------------------------

r_media <- feols(traded_before_maturity ~ city_go_vote * high_articles_12_0 + disclosure_control + ln_amount + ln_maturity_mths + 
                   callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad,
            ~state, 
                 data = data[year > 2004 & !is.na(high_articles_12_0)])
summary(r_media)

r_media_r <- feols(retail_traded_before_maturity ~ city_go_vote * high_articles_12_0 + disclosure_control + ln_amount + ln_maturity_mths + 
                     callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad,
            ~state, 
                   data = data[year > 2004 & !is.na(high_articles_12_0)])
summary(r_media_r)

r_media_i <- feols(institutional_traded_before_maturity ~ city_go_vote * high_articles_12_0 + disclosure_control + ln_amount + ln_maturity_mths + 
                     callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc | year + purp_broad,
            ~state, 
                   data = data[year > 2004 & !is.na(high_articles_12_0)])
summary(r_media_i)

if (rating_variant == 'unrated_indicator') {
  # Add the unrated intercept shift while retaining the existing 0--16 rating
  # scale. The source data already code unrated bonds' rating_num as zero; the
  # assignment above makes that convention explicit for this specification.
  r2 <- update(r2, . ~ . + unrated)
  r2_r <- update(r2_r, . ~ . + unrated)
  r2_i <- update(r2_i, . ~ . + unrated)
  r2b <- update(r2b, . ~ . + unrated)
  r2b_r <- update(r2b_r, . ~ . + unrated)
  r2b_i <- update(r2b_i, . ~ . + unrated)
  r_web <- update(r_web, . ~ . + unrated)
  r_web_r <- update(r_web_r, . ~ . + unrated)
  r_web_i <- update(r_web_i, . ~ . + unrated)
  r_media <- update(r_media, . ~ . + unrated)
  r_media_r <- update(r_media_r, . ~ . + unrated)
  r_media_i <- update(r_media_i, . ~ . + unrated)
} else if (rating_variant == 'rating_fe') {
  r2 <- update(r2, . ~ . - rating_num | . + rating_fe)
  r2_r <- update(r2_r, . ~ . - rating_num | . + rating_fe)
  r2_i <- update(r2_i, . ~ . - rating_num | . + rating_fe)
  r2b <- update(r2b, . ~ . - rating_num | . + rating_fe)
  r2b_r <- update(r2b_r, . ~ . - rating_num | . + rating_fe)
  r2b_i <- update(r2b_i, . ~ . - rating_num | . + rating_fe)
  r_web <- update(r_web, . ~ . - rating_num | . + rating_fe)
  r_web_r <- update(r_web_r, . ~ . - rating_num | . + rating_fe)
  r_web_i <- update(r_web_i, . ~ . - rating_num | . + rating_fe)
  r_media <- update(r_media, . ~ . - rating_num | . + rating_fe)
  r_media_r <- update(r_media_r, . ~ . - rating_num | . + rating_fe)
  r_media_i <- update(r_media_i, . ~ . - rating_num | . + rating_fe)
}






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
modified_output <- add_panel(modified_output, paste0('Panel A: Full sample', panel_suffix))

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_full_sample_tax', output_suffix, '.tex'))


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
modified_output <- add_panel(modified_output, paste0('Panel B: Border-city sample', panel_suffix))

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_border_sample_tax', output_suffix, '.tex'))


# website disclosure heterogeneity
table_call <- etable(r_web, r_web_r, r_web_i,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3",
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep_raw = c("city_go_vote", "high_bond_count", "city_go_vote:high_bond_count", "disclosure_control"),
                     order = c("%city_go_vote:high_bond_count", "%city_go_vote", "%high_bond_count", "%disclosure_control"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              high_bond_count = 'High Bond Text',
                              'city_go_vote:high_bond_count' = 'Vote $\\times$ High Bond Text',
                              disclosure_control = disclosure_label,
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
                              group = 'State-Border', 
                              year = 'Year',
                              purp_broad = 'Purpose',
                              issue_id = 'Issue'),
                     placement = 'H',
                     replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State-Year")
modified_output <- add_panel(modified_output, paste0('Panel C: Border-city sample by website disclosure', panel_suffix))

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_border_sample_website_disclosure', output_suffix, '.tex'))


# media disclosure heterogeneity
table_call <- etable(r_media, r_media_r, r_media_i,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = "r3",
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     keep_raw = c("city_go_vote", "high_articles_12_0", "city_go_vote:high_articles_12_0", "disclosure_control"),
                     order = c("%city_go_vote:high_articles_12_0", "%city_go_vote", "%high_articles_12_0", "%disclosure_control"),
                     extralines = list("-^County Controls" = rep("Yes", 3),
                                       "-^Bond Controls" = rep("Yes", 3)),
                     dict = c(institutional_traded_before_maturity ='Inst. Trade',
                              retail_traded_before_maturity ='Retail Trade',
                              traded_before_maturity = 'Trade',
                              city_go_vote = 'Vote',
                              high_articles_12_0 = 'High Media Coverage',
                              'city_go_vote:high_articles_12_0' = 'Vote $\\times$ High Media Coverage',
                              disclosure_control = disclosure_label,
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
                              year = 'Year',
                              purp_broad = 'Purpose',
                              issue_id = 'Issue'),
                     placement = 'H',
                     replace = TRUE)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, paste0('Panel D: Full sample by media coverage', panel_suffix))

writeLines(modified_output, paste0(tables_wd, '/trade_before_maturity_full_sample_media_disclosure', output_suffix, '.tex'))
