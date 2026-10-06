# 03: Texas election timing and outcome results (Tables 4 and 5; also Table 1 inputs)
# -------------------------------------------------------------------------------
# Data preparation is performed in:
# Code/Python/Clean/Election_Outcomes/05_prepare_tx_regression_inputs.py
#
# That step assigns county FIPS and applies prior-year county controls. County
# GDP for 2001 is the sole documented exception: the BEA series begins in 2001,
# so that year uses the earliest available GDP value.

rm(list = ls())

root <- normalizePath(getwd(), mustWork = TRUE)
source(file.path(root, 'Code/R/Clean/00_modify_etable_rounding.R'))
tbl_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')
regression_data_dir <- file.path(root, 'Data/Clean_Intermediate/TX/Regression')
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

city_month <- fread(file.path(regression_data_dir, 'city_month_media_regression_ready.csv'))
election <- fread(file.path(regression_data_dir, 'election_media_regression_ready.csv'))
website_city_year_input <- fread(file.path(regression_data_dir, 'website_city_year_regression_ready.csv'))
website_election_input <- fread(file.path(regression_data_dir, 'website_election_regression_ready.csv'))

election_brb_all <- copy(election)

# Python supplies coverage indicators, logs, county-year IDs, and vote margins.
# The election-level regressions retain elections where pre-election source
# diversity is positive. This matches the paper's media-analysis sample.
election <- election[unique_sources_12m_prior > 0]


city_month[, seed_issuer := tolower(trimws(seed_issuer))]
election[, seed_issuer := tolower(trimws(seed_issuer))]
website_city_year_input[, seed_issuer := tolower(trimws(seed_issuer))]
website_election_input[, seed_issuer := tolower(trimws(seed_issuer))]


# ===============================================================================
# DESCRIPTIVES - COMBINED
# ===============================================================================

summarize_desc_cols <- function(dt, unit, labels) {
  desc_col <- dt[, lapply(.SD, function(col) {
    stats <- c(Unit = unit,
               Mean = mean(col, na.rm = TRUE),
               Std = sd(col, na.rm = TRUE),
               Min = min(col, na.rm = TRUE),
               p1 = quantile(col, probs = 0.01, na.rm = TRUE),
               Median = median(col, na.rm = TRUE),
               p99 = quantile(col, probs = 0.99, na.rm = TRUE),
               Max = max(col, na.rm = TRUE),
               N = sum(!is.na(col)))
    return(stats)
  }), .SDcols = colnames(dt)]
  desc_col <- data.table::transpose(desc_col, keep.names = "variable")
  colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
  desc_col[, Variable := labels]
  return(desc_col)
}

# City-Year Level website descriptives
website_city_year_desc <- copy(website_city_year_input)
website_city_year_desc <- website_city_year_desc[!is.na(seed_issuer) & seed_issuer != '']
setorder(website_city_year_desc, seed_issuer, year)
website_city_year_desc <- unique(website_city_year_desc, by = c('seed_issuer', 'year'))
website_city_year_desc[, total_words := bond_count]
website_city_year_desc_lag1 <- website_city_year_desc[, .(seed_issuer,
                                                          year = year + 1L,
                                                          total_words_lag1 = total_words)]
website_city_year_desc <- website_city_year_desc_lag1[website_city_year_desc, on = .(seed_issuer, year)]
website_city_year_desc[, delta_bond_debt_count1 := total_words - total_words_lag1]
website_city_year_desc[, positive_delta_bond_debt1 := ifelse(delta_bond_debt_count1 > 0, 1, 0)]

desc_city_year <- website_city_year_desc[!is.na(positive_delta_bond_debt1),
                                         .(seed_issuer,
                                           year,
                                           positive_delta_bond_debt1,
                                           election,
                                           issuance_year)]

# Match fixest's iterative removal of singleton city and year fixed effects.
repeat {
  rows_before <- nrow(desc_city_year)
  eligible_cities <- desc_city_year[, .N, by = seed_issuer][N > 1L, seed_issuer]
  eligible_years <- desc_city_year[, .N, by = year][N > 1L, year]
  desc_city_year <- desc_city_year[
    seed_issuer %in% eligible_cities & year %in% eligible_years
  ]
  if (nrow(desc_city_year) == rows_before) break
}

desc_city_year[, c('seed_issuer', 'year') := NULL]
desc_city_year_col <- summarize_desc_cols(
  desc_city_year,
  'City-Year',
  c('Increase in Bond Text', 'Election Year', 'Bond Issuance Year')
)

# City-Month Level descriptives
desc_city_month <- city_month[, .(covered, 
                                   election_window,
                                   issuance_window)]

desc_city_month_col <- summarize_desc_cols(
  desc_city_month,
  'City-Month',
  c('Bond Coverage', 'Election [0, +3]', 'Bond Issuance [0, +3]')
)

# Election Level descriptives
desc_election <- election_brb_all[year >= 2000 & year <= 2021,
                                  .(failed,
                                    abs_vote_margin)]
desc_election_col <- summarize_desc_cols(
  desc_election,
  'Election',
  c('Failed', 'Margin')
)

website_election_desc <- copy(website_election_input)
# Match the unrestricted Texas website-outcome regression sample: merge the
# covered-media election file, retain nonmissing bond text, and remove the same
# year/purpose fixed-effect singletons as the regression below.
website_election_desc <- election[, .(
  GovernmentName,
  ElectionDate,
  PropNumber,
  unique_sources_12m_prior,
  articles_2m_before_to_election
)][website_election_desc, on = .(GovernmentName, ElectionDate, PropNumber)]
website_election_desc[, high_bond_count := ifelse(
  bond_count > median(bond_count, na.rm = TRUE),
  1,
  0
)]
website_desc_sample_model <- feols(
  failed ~ high_bond_count | year + purp_broad_new,
  data = website_election_desc,
  cluster = ~County,
  fixef.rm = 'singleton',
  notes = FALSE
)
desc_bond_text <- website_election_desc[obs(website_desc_sample_model), .(bond_count)]
desc_bond_text_col <- summarize_desc_cols(
  desc_bond_text,
  'Election',
  c('Bond Count')
)

desc_election_coverage <- election[, .(
  coverage_3,
  ln_Amount,
  unique_sources_12m_prior
)]
desc_election_coverage_col <- summarize_desc_cols(
  desc_election_coverage,
  'Election',
  c(
    'Bond Coverage [-3, 0]',
    'Amount',
    'Num Sources'
  )
)

# Combine tables in requested order.
desc_col <- rbind(desc_city_year_col,
                  desc_city_month_col,
                  desc_election_col,
                  desc_bond_text_col,
                  desc_election_coverage_col)

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

# Add \toprule after the first \hline (which comes after the column headers)
for (i in seq_along(desc_table_output)) {
  if (grepl("^[[:space:]]*\\\\hline[[:space:]]*$", desc_table_output[i])) {
    desc_table_output[i] <- "  \\toprule"
    break
  }
}

# Add panel title using add_panel function
desc_table_output <- add_panel(desc_table_output, 'Panel C: Texas election descriptive statistics', ncols = 10)

# Write to file
writeLines(desc_table_output, paste0(tbl_dir, '/election_descriptives.tex'))


# ===============================================================================
# REGRESSION -ELECTION LEVEL 
# ===============================================================================


r0 <- feols(failed ~ coverage_3|year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
r1 <- feols(failed ~ coverage_3 + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |year + purp_broad_new, data = election[ unique_sources_12m_prior > 0], cluster = ~County)
r2 <- feols(abs_vote_margin  ~ coverage_3 |year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
r3 <- feols(abs_vote_margin ~ coverage_3  + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior|year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)



table_call <- etable(r0, r1, r2, r3,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(failed = 'Failed',
                              pct_yes = 'Pct Yes',
                              coverage_3 = 'Bond Coverage[-3, 0]',
                              abs_vote_margin = 'Margin',
                              ln_Amount = "Amount",
                              unique_sources_12m_prior = 'Num Sources',
                              ln_county_gdp_prior = 'County ln(GDP)', 
                              ln_county_pop_prior = 'County ln(Pop)', 
                              ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                              ln_county_employment_prior = 'County ln(Emp)',
                              year = 'Year',
                              purp_broad_new = 'Purpose'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel B: Media coverage and election outcomes')

writeLines(modified_output, paste0(tbl_dir, '/tx_failed_and_margin.tex'))





# Keep the original paper's 2003--2024 media sample in both columns.  The
# earlier table implicitly began in 2003 because the prior-year county
# employment series was unavailable in 2001--02.  State the date window
# directly so the common sample does not depend on an unused control.
media_panel_sample <- city_month[
  seed_issuer %in% election$seed_issuer & year >= 2003L &
    !is.na(fips) & !is.na(ln_county_gdp_prior) &
    !is.na(ln_county_pop_prior) & !is.na(ln_county_pers_inc_prior)
]

r1 <- feols(covered ~ election_window | seed_issuer_id + year_month_id,
            data = media_panel_sample, cluster = ~fips)
r2 <- feols(covered ~ election_window + issuance_window + ln_county_gdp_prior +
              ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer_id + year_month_id,
            data = media_panel_sample, cluster = ~fips)




table_call <- etable(r1, r2,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(covered = 'Bond Coverage',
                            pct_yes = 'Pct Yes',
                              election_window = 'Election [0, +3]',
                              issuance_window = "Bond Issuance [0, +3]",
                             seed_issuer_id = 'City',
                             ln_county_gdp_prior = 'County ln(GDP)', 
                             ln_county_pop_prior = 'County ln(Pop)', 
                             ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                             ln_county_employment_prior = 'County ln(Emp)',
                              year_month_id = 'Year-Month'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)




modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel B: Elections and media coverage over time', ncols = 3)

writeLines(modified_output, paste0(tbl_dir, '/tx_city_month_reg.tex'))

# ===============================================================================
# DATA LOADING AND PREPARATION - WEBSITES
# ===============================================================================
election_media <- copy(election)
website_city_year <- copy(website_city_year_input)
election <- copy(website_election_input)
# ===============================================================================
# REGRESSION - WEBSITE TIME SERIES
# ===============================================================================

website_city_year <- website_city_year[!is.na(seed_issuer) & seed_issuer != '']
setorder(website_city_year, seed_issuer, year)
website_city_year <- unique(website_city_year, by = c('seed_issuer', 'year'))

website_city_year[, total_words := bond_count ]
website_city_year_lag1 <- website_city_year[, .(seed_issuer,
                                                year = year + 1L,
                                                total_words_lag1 = total_words)]
website_city_year <- website_city_year_lag1[website_city_year, on = .(seed_issuer, year)]
website_city_year[, delta_bond_debt_count1 := total_words - total_words_lag1]
website_city_year[, positive_delta_bond_debt1 := ifelse(delta_bond_debt_count1 > 0, 1, 0)]


r1 <- feols(positive_delta_bond_debt1 ~ election | seed_issuer + year,
                    data = website_city_year[!is.na(fips)], cluster = ~fips)

r2 <- feols(positive_delta_bond_debt1 ~ election + issuance_year + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
                    data = website_city_year[!is.na(fips)], cluster = ~fips)

table_call <- etable(r1, r2,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(positive_delta_bond_debt1 = 'Increase in Bond Text',
                              election = 'Election Year',
                              issuance_year = 'Bond Issuance Year',
                              ln_county_gdp_prior = 'County ln(GDP)',
                              ln_county_pop_prior = 'County ln(Pop)',
                              ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                              ln_county_employment_prior = 'County ln(Emp)',
                              seed_issuer = 'City',
                              year = 'Year'),
                     placement = 'H',
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel A: Elections and website disclosure over time', ncols = 3)

writeLines(modified_output, paste0(tbl_dir, '/tx_website_time_series_reg.tex'))


# Response 2: estimate the website-disclosure specification in levels using
# PPML. Restrict the sample to city-years with 50 processed sub-URLs so Bond
# Count is measured over comparable website content across observations.
website_city_year_poisson <- website_city_year[
  !is.na(fips) & total_subs == 50
]

r1_poisson <- fepois(
  bond_count ~ election | seed_issuer + year,
  data = website_city_year_poisson,
  cluster = ~fips
)

r2_poisson <- fepois(
  bond_count ~ election + issuance_year + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
  data = website_city_year_poisson,
  cluster = ~fips
)

table_call <- etable(
  r1_poisson, r2_poisson,
  coefstat = 'tstat',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
  fitstat = c('n', 'pr2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    bond_count = 'Bond Count',
    election = 'Election Year',
    issuance_year = 'Bond Issuance Year',
    ln_county_gdp_prior = 'County ln(GDP)',
    ln_county_pop_prior = 'County ln(Pop)',
    ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
    seed_issuer = 'City',
    year = 'Year'
  ),
  placement = 'H',
  replace = TRUE
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(
  modified_output,
  'Panel A: Elections and website disclosure over time',
  ncols = 3
)
writeLines(
  modified_output,
  paste0(tbl_dir, '/tx_website_time_series_reg_2yr_poisson.tex')
)






# merge media with election website 
election <- election_media[, .(GovernmentName, ElectionDate, PropNumber, unique_sources_12m_prior, articles_2m_before_to_election)][election, on = .(GovernmentName, ElectionDate, PropNumber)]
election[, covered_3 := ifelse(articles_2m_before_to_election > 0, 1, 0)]


election[, abs_vote_margin := abs(vote_margin)]
election[, high_bond_count := ifelse(bond_count > median(bond_count, na.rm = TRUE), 1, 0)]



r0 <- feols(failed ~ high_bond_count|year + purp_broad_new, data = election, cluster = ~County, fixef.rm = 'singleton')
r1 <- feols(failed ~ high_bond_count + ln_amount  + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior  |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
r2 <- feols(abs_vote_margin  ~ high_bond_count |year + purp_broad_new, data = election, cluster = ~County,  fixef.rm = 'singleton')
r3 <- feols(abs_vote_margin ~ high_bond_count + ln_amount  + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior   |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')


table_call <- etable(r0, r1, r2, r3,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(failed = 'Failed',
                              pct_yes = 'Pct Yes',
                              high_bond_count = 'High Bond Text',
                              abs_vote_margin = 'Margin',
                              ln_cum_num_issues_unlim = 'Num Issuance',
                              ln_amount = "Amount",
                              ln_county_gdp_prior = 'County ln(GDP)', 
                              ln_county_pop_prior = 'County ln(Pop)', 
                              ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
                              ln_county_employment_prior = 'County ln(Emp)',
                              year = 'Year',
                              purp_broad_new = 'Purpose'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)


modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel A: Website disclosure and election outcomes')

writeLines(modified_output, paste0(tbl_dir, '/tx_failed_and_margin_websites.tex'))
