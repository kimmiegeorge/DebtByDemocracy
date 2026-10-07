# TX election outcome tests
#---------------------------------------
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven, xtable)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"


# ===============================================================================
# DATA LOADING AND PREPARATION - MEDIA FIRST
# ===============================================================================

city_month <- fread(paste0(data_wd, 'TX/City_Month_Elections_News_WithFailed_260611.csv'))
election <- fread(paste0(data_wd, 'TX/News/Election_Level_With_News_WithFailed_260611.csv'))
election_brb_all <- copy(election)
election_brb_all[, abs_vote_margin := abs(vote_margin)]

county_demo_vars <- c('ln_county_pop_prior',
                      'ln_county_gdp_prior',
                      'ln_county_pers_inc_prior',
                      'ln_county_percap_inc_prior',
                      'ln_county_employment_prior')

summarize_county_demo_missingness <- function(dt, label) {
  demo_vars <- intersect(county_demo_vars, names(dt))
  if (length(demo_vars) == 0) {
    message(label, ': no county demographic variables found.')
    return(invisible(NULL))
  }

  out <- dt[, c(list(N = .N,
                    missing_any_county_demo = sum(Reduce(`|`, lapply(.SD, is.na)))),
                setNames(lapply(.SD, function(x) sum(is.na(x))),
                         paste0('missing_', demo_vars))),
            by = year,
            .SDcols = demo_vars][order(year)]

  out[, pct_missing_any_county_demo := round(missing_any_county_demo / N, 3)]

  message('\nCounty demographic missingness: ', label)
  print(out[, .(year, N, missing_any_county_demo, pct_missing_any_county_demo)])
  invisible(out)
}

first_nonmissing <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) {
    return(x[NA_integer_][1])
  }
  return(x[1])
}

format_fips <- function(x) {
  fifelse(is.na(x), NA_character_, sprintf('%05d', as.integer(x)))
}

build_actual_issue_city_year <- function(data_wd) {
  issue_level <- as.data.table(read_dta(paste0(data_wd, 'Mergent/Clean/260610_city_cusiplevel_statereq_purpose_yieldspread.dta')))
  issue_level <- unique(issue_level[state == 'TX' & !is.na(seed_issuer) & !is.na(year),
                                    .(seed_issuer_key = tolower(seed_issuer),
                                      year,
                                      issue_id,
                                      go_unlim,
                                      go_lim)])
  issue_level[, year := as.integer(year)]
  issue_city_year <- issue_level[, .(num_issues_bond_data = uniqueN(issue_id),
                                     num_issues_go = uniqueN(issue_id[go_unlim == 1 | go_lim == 1])),
                                 by = .(seed_issuer_key, year)]
  return(issue_city_year)
}

actual_issue_city_year <- build_actual_issue_city_year(data_wd)

#county_demo_source <- as.data.table(read_dta(paste0(data_wd, 'BEA/countydemos_2001_2022.dta')))
county_demo_source <- as.data.table(read_dta(paste0(data_wd, 'BEA/countydemos_1999_2026.dta')))
message('\nBEA county demographic source coverage:')
print(county_demo_source[, .(min_year = min(year, na.rm = TRUE),
                             max_year = max(year, na.rm = TRUE),
                             county_years = .N,
                             counties = uniqueN(fips))])

updated_county_controls <- copy(county_demo_source)
updated_county_controls[, fips := format_fips(fips)]
updated_county_controls[, `:=`(
  ln_county_pop_prior = log(pop),
  ln_county_gdp_prior = log(gdp),
  ln_county_pers_inc_prior = log(pers_inc),
  ln_county_percap_inc_prior = log(percap_inc),
  ln_county_employment_prior = log(employment)
)]
updated_county_controls <- updated_county_controls[, .(fips,
                                                       year,
                                                       ln_county_gdp_prior,
                                                       ln_county_pop_prior,
                                                       ln_county_pers_inc_prior,
                                                       ln_county_percap_inc_prior,
                                                       ln_county_employment_prior)]

tx_county_fips_map <- unique(county_demo_source[grepl(', TX$', geoname),
                                                .(County = sub(', TX$', '', geoname),
                                                  fips = format_fips(fips))])
tx_county_fips_map <- tx_county_fips_map[, .(fips = first_nonmissing(fips)), by = County]

fill_missing_fips_from_tx_county <- function(dt, county_fips_map) {
  dt <- copy(dt)
  if (!all(c('County', 'fips') %in% names(dt))) {
    return(dt)
  }

  county_fips_map <- copy(county_fips_map)
  setnames(county_fips_map, 'fips', 'fips_from_county')
  dt <- county_fips_map[dt, on = .(County)]
  dt[, fips := fifelse(is.na(fips), fips_from_county, fips)]
  dt[, fips_from_county := NULL]
  return(dt)
}

fill_missing_county_controls_earliest <- function(dt, county_controls) {
  dt <- copy(dt)
  control_vars <- intersect(county_demo_vars, names(dt))
  if (length(control_vars) == 0 || !('fips' %in% names(dt))) {
    return(dt)
  }

  fallback <- county_controls[order(year),
                              lapply(.SD, first_nonmissing),
                              by = fips,
                              .SDcols = control_vars]
  setnames(fallback, control_vars, paste0(control_vars, '_fallback'))
  dt <- fallback[dt, on = .(fips)]

  for (var in control_vars) {
    fallback_var <- paste0(var, '_fallback')
    dt[is.na(get(var)), (var) := get(fallback_var)]
  }
  dt[, paste0(control_vars, '_fallback') := NULL]
  return(dt)
}

add_updated_county_controls <- function(dt,
                                        county_controls,
                                        fips_map = NULL,
                                        demo_year_offset = 0L) {
  dt <- copy(dt)
  stale_controls <- intersect(county_demo_vars, names(dt))
  if (length(stale_controls) > 0) {
    dt[, (stale_controls) := NULL]
  }

  if (!('fips' %in% names(dt))) {
    if (is.null(fips_map)) {
      stop('No fips column found and no fips_map supplied.')
    }
    dt[, seed_issuer_key := tolower(seed_issuer)]
    dt <- fips_map[dt, on = .(seed_issuer_key)]
  }

  dt[, fips := format_fips(fips)]
  dt[, county_demo_year := year + demo_year_offset]

  controls_for_join <- copy(county_controls)
  setnames(controls_for_join, 'year', 'county_demo_year')
  dt <- controls_for_join[dt, on = .(fips, county_demo_year)]
  dt[, county_demo_year := NULL]
  return(dt)
}

election_missing_raw <- summarize_county_demo_missingness(election, 'raw election-level media file')
city_month_missing_raw <- summarize_county_demo_missingness(city_month, 'raw city-month media file')

election_missing_sources <- summarize_county_demo_missingness(
  election[unique_sources_12m_prior > 0],
  'election-level media file after unique_sources_12m_prior > 0'
)

city_month_missing_sources <- summarize_county_demo_missingness(
  city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer],
  'city-month media file restricted to issuers with covered elections'
)

media_election_fips_map <- city_month[!is.na(fips),
                                      .(fips = first_nonmissing(fips)),
                                      by = .(seed_issuer_key = tolower(seed_issuer))]
media_election_fips_map <- media_election_fips_map[!is.na(seed_issuer_key) & seed_issuer_key != '']
media_election_fips_map[, fips := format_fips(fips)]
election <- add_updated_county_controls(election,
                                        updated_county_controls,
                                        fips_map = media_election_fips_map,
                                        demo_year_offset = -1L)
election_missing_updated <- summarize_county_demo_missingness(
  election,
  'raw election-level media file after updated BEA prior-year merge'
)

city_month <- city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer &!is.na(ln_county_employment_prior)]
#election <- election[year >= 2010 & unique_sources_12m_prior > 0]
election <- election[unique_sources_12m_prior > 0]


election[, `:=` (ln_election_month_articles = log(1 + articles_election_month), 
                 ln_2m_election_articles = log(1 + articles_2m_before_to_election), 
                 ln_6m_election_articles = log(1 + articles_6m_before_to_election))]

election[, coverage_3 := ifelse(articles_3m_before_to_election > 0, 1, 0)]

election[, year_month := paste0(year, month)]

election[, ln_Amount := log(Amount)]
election[, log_sources := log(unique_sources_12m_prior)]

election[, log_votes := log(votestotal)]
election[, county_year := paste0(County, year)]
election[, coverage_3 := ifelse(articles_3m_before_to_election > 0, 1, 0)]
election[, coverage_6 := ifelse(articles_6m_before_to_election > 0, 1, 0)]

election[, abs_vote_margin := abs(vote_margin)]

election <- election[!is.na(ln_county_gdp_prior) & !is.na(unique_sources_12m_prior)]

# ===============================================================================
# DATA LOADING AND PREPARATION - CITY MONTH
# ===============================================================================

# need to filter this to cities that get coverage 
# add bond issuance indicators for city_month data 

# create ym and ym_id
city_month[, ym := paste0(year, month)]
yms <- unique(city_month[, .(ym)])
yms[, ym_id := 1:.N]
city_month <- yms[city_month, on = .(ym)]


full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/260610_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
full_data[, ym := paste0(year, month)]
full_data <- unique(full_data[, .(seed_issuer_id, ym)])
full_data <- yms[full_data, on = .(ym)]
full_data[, ym := NULL]
full_data[, bond_issuance := 1]

city_month <- full_data[city_month, on = .(seed_issuer_id, ym_id)]
city_month[, next_month_bond_issuance := ifelse(shift(bond_issuance, type = 'lead') == 1, 1, 0), .(seed_issuer_id)]
city_month[, next_next_month_bond_issuance := ifelse(shift(bond_issuance, type = 'lead', 2) == 1, 1, 0), .(seed_issuer_id)]
#city_month[, next_next_next_month_bond_issuance := ifelse(shift(bond_issuance, type = 'lead', 3) == 1, 1, 0), .(seed_issuer_id)]
#city_month[, issuance_window := ifelse(next_month_bond_issuance == 1 | bond_issuance == 1 |next_next_month_bond_issuance == 1 | next_next_next_month_bond_issuance == 1,1, 0)]
city_month[, issuance_window := ifelse(bond_issuance == 1   ,1, 0)]
city_month[is.na(issuance_window), issuance_window := 0]

city_month[, prev_month_election := ifelse(shift(has_bond_election, type = 'lag', 1) == 1, 1, 0), .(seed_issuer_id)]
city_month[, next_next_month_election := ifelse(shift(has_bond_election, type = 'lead', 2) == 1, 1, 0), .(seed_issuer_id)]
city_month[, next_next_next_month_election := ifelse(shift(has_bond_election, type = 'lead',3) == 1, 1, 0), .(seed_issuer_id)]
city_month[, election_window := ifelse(has_bond_election == 1 | has_election_next_month ==1 | next_next_month_election == 1 | next_next_next_month_election == 1, 1, 0)]
city_month[is.na(election_window), election_window := 0]
city_month[, covered := ifelse(rp_article_count > 0, 1, 0)]

city_month <- city_month[!is.na(ln_county_gdp_prior) & !is.na(ln_county_employment_prior)]


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
website_city_year_desc <- fread(paste0(data_wd, 'Websites/Texas/time_series_website_data_260611.csv'))
# website_city_year_desc <- website_city_year_desc[total_subs == 50]
website_city_year_desc <- website_city_year_desc[!is.na(seed_issuer) & seed_issuer != '']
setorder(website_city_year_desc, seed_issuer, year)
website_city_year_desc[, seed_issuer_key := tolower(seed_issuer)]
website_city_year_desc <- actual_issue_city_year[website_city_year_desc, on = .(seed_issuer_key, year)]
website_city_year_desc[is.na(num_issues_bond_data), num_issues_bond_data := 0L]
website_city_year_desc[is.na(num_issues_go), num_issues_go := 0L]
website_city_year_desc[, issuance_year := ifelse(num_issues_bond_data > 0, 1, 0)]
website_city_year_desc[, total_words := bond_count]
website_city_year_desc_lag1 <- website_city_year_desc[, .(seed_issuer,
                                                          year = year + 1L,
                                                          total_words_lag1 = total_words)]
website_city_year_desc <- website_city_year_desc_lag1[website_city_year_desc, on = .(seed_issuer, year)]
website_city_year_desc[, delta_bond_debt_count1 := total_words - total_words_lag1]
website_city_year_desc[, positive_delta_bond_debt1 := ifelse(delta_bond_debt_count1 > 0, 1, 0)]

desc_city_year <- website_city_year_desc[, .(positive_delta_bond_debt1,
                                             election,
                                             issuance_year)]
desc_city_year <- desc_city_year[!is.na(positive_delta_bond_debt1)]
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

website_election_desc <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_260611.csv'))
desc_bond_text <- website_election_desc[total_subs == 50 & !is.na(bond_count), .(bond_count)]
desc_bond_text_col <- summarize_desc_cols(
  desc_bond_text,
  'Election',
  c('Bond Count')
)

desc_election_coverage <- election[, .(coverage_3)]
desc_election_coverage_col <- summarize_desc_cols(
  desc_election_coverage,
  'Election',
  c('Bond Coverage [-3, 0]')
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
summary(r0)
r1 <- feols(failed ~ coverage_3 + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |year + purp_broad_new, data = election[ unique_sources_12m_prior > 0], cluster = ~County)
summary(r1)
r2 <- feols(abs_vote_margin  ~ coverage_3 |year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(r2)
r3 <- feols(abs_vote_margin ~ coverage_3  + ln_Amount + unique_sources_12m_prior + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior|year + purp_broad_new, data = election[unique_sources_12m_prior > 0], cluster = ~County)
summary(r3)



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





city_month[, rp_article_count_win := Winsorize(rp_article_count, val = quantile(rp_article_count, probs = c(0.01, 0.99)))]


r1 <- feols(covered ~ election_window|seed_issuer_id + ym_id, data = city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer & !is.na(ln_county_employment_prior)], cluster = ~fips)
summary(r1)
r2 <- feols(covered ~ election_window + issuance_window + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior |seed_issuer_id + ym_id, data = city_month[seed_issuer %in% election[unique_sources_12m_prior > 0]$seed_issuer ], cluster = ~fips)
summary(r2)




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
                              ym_id = 'Year-Month'),
                     placement = 'H',
                     #file = paste0(tables_wd, '/media_coverage.tex'), 
                     replace = TRUE)




modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = "County")
modified_output <- add_panel(modified_output, 'Panel B: Elections and media coverage over time')

writeLines(modified_output, paste0(tbl_dir, '/tx_city_month_reg.tex'))




# ===============================================================================
# descriptives on elections at the union of website and media samples
# ===============================================================================
#election_website <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_260611.csv'))
election_website <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_260611.csv'))
election_website[, abs_vote_margin := abs(vote_margin)]
election_website <- election_website[total_subs > 10]

election_media <- election[, .(GovernmentName, ElectionDate, PropNumber, failed, abs_vote_margin)]
election_website <- election_website[, .(GovernmentName, ElectionDate, PropNumber, failed, abs_vote_margin)]

election_all <- rbindlist(list(election_media, election_website))
election_all <- unique(election_all)



desc <- election_all[, .(failed, 
                         abs_vote_margin)]

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
desc_col <- data.table::transpose(desc_col, keep.names = "variable")
colnames(desc_col) <- c("variable", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")

desc_col[, variable := c('Failed', 'Margin')]
stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
          rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Election Level Desc.tex'))


# ===============================================================================
# DATA LOADING AND PREPARATION - WEBSITES
# ===============================================================================
election_media <- election
city_month <- fread(paste0(data_wd, 'Websites/Texas/time_series_website_data_260611.csv'))
# city_month <- city_month[total_subs == 50]
election <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_260611.csv'))
election[, fips := format_fips(fips)]
election <- fill_missing_fips_from_tx_county(election, tx_county_fips_map)

website_election_missing_raw <- summarize_county_demo_missingness(
  election[total_subs == 50],
  'raw website election-level file, total_subs == 50'
)

if (all(c('gdp', 'gdp_right', 'ln_county_gdp_prior') %in% names(election))) {
  message('\nWebsite file GDP collision diagnostic:')
  print(election[total_subs == 50,
                 .(N = .N,
                   missing_ln_county_gdp_prior = sum(is.na(ln_county_gdp_prior)),
                   has_gdp_right_when_ln_county_gdp_missing = sum(is.na(ln_county_gdp_prior) & !is.na(gdp_right)),
                   has_unsuffixed_gdp_when_ln_county_gdp_missing = sum(is.na(ln_county_gdp_prior) & !is.na(gdp))),
                 by = year][order(year)])
}

election <- add_updated_county_controls(election,
                                        updated_county_controls,
                                        demo_year_offset = -1L)
election <- fill_missing_county_controls_earliest(election, updated_county_controls)
website_election_missing_updated <- summarize_county_demo_missingness(
  election[total_subs == 50],
  'raw website election-level file after updated BEA prior-year merge, total_subs == 50'
)

# ===============================================================================
# REGRESSION - WEBSITE TIME SERIES
# ===============================================================================

website_city_year <- city_month[!is.na(seed_issuer) & seed_issuer != '']
setorder(website_city_year, seed_issuer, year)

website_city_year[, seed_issuer_key := tolower(seed_issuer)]

website_fips_map <- election[!is.na(fips),
                             .(fips = first_nonmissing(fips)),
                             by = .(seed_issuer_key = tolower(seed_issuer))]

media_fips_map <- fread(paste0(data_wd, 'TX/City_Month_Elections_News_WithFailed_260611.csv'))
media_fips_map <- media_fips_map[!is.na(fips),
                                 .(fips = first_nonmissing(fips)),
                                 by = .(seed_issuer_key = tolower(seed_issuer))]

fips_map <- rbindlist(list(website_fips_map, media_fips_map), use.names = TRUE, fill = TRUE)
fips_map <- fips_map[!is.na(seed_issuer_key) & seed_issuer_key != '']
fips_map <- fips_map[, .(fips = first_nonmissing(fips)), by = seed_issuer_key]
fips_map[, fips := format_fips(fips)]

county_controls <- copy(updated_county_controls)

website_city_year <- fips_map[website_city_year, on = .(seed_issuer_key)]
website_city_year <- county_controls[website_city_year, on = .(fips, year)]
website_city_year <- actual_issue_city_year[website_city_year, on = .(seed_issuer_key, year)]
website_city_year[is.na(num_issues_bond_data), num_issues_bond_data := 0L]
website_city_year[is.na(num_issues_go), num_issues_go := 0L]
website_city_year[, issuance_window := ifelse(num_issues_bond_data > 0, 1, 0)]

website_city_year[, total_words := bond_count ]
website_city_year_lag2 <- website_city_year[, .(seed_issuer,
                                                year = year + 2L,
                                                total_words_lag2 = total_words)]
website_city_year <- website_city_year_lag2[website_city_year, on = .(seed_issuer, year)]
website_city_year[, delta_bond_debt_count := total_words - total_words_lag2]
website_city_year[, positive_delta_bond_debt := ifelse(delta_bond_debt_count > 0, 1, 0)]

website_city_year_lag1 <- website_city_year[, .(seed_issuer,
                                                year = year + 1L,
                                                total_words_lag1 = total_words)]
website_city_year <- website_city_year_lag1[website_city_year, on = .(seed_issuer, year)]
website_city_year[, delta_bond_debt_count1 := total_words - total_words_lag1]
website_city_year[, positive_delta_bond_debt1 := ifelse(delta_bond_debt_count1 > 0, 1, 0)]


r1 <- feols(positive_delta_bond_debt1 ~ election | seed_issuer + year,
                    data = website_city_year[!is.na(fips)], cluster = ~fips)
summary(r1)

r2 <- feols(positive_delta_bond_debt1 ~ election + issuance_window + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
                    data = website_city_year[!is.na(fips)], cluster = ~fips)
summary(r2)

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
                              issuance_window = 'Bond Issuance Year',
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


r1 <- feols(positive_delta_bond_debt ~ election | seed_issuer + year,
                    data = website_city_year[!is.na(fips)], cluster = ~fips)
summary(r1)

r2 <- feols(positive_delta_bond_debt ~ election + issuance_window + ln_county_gdp_prior + ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
                    data = website_city_year[!is.na(fips)], cluster = ~fips)
summary(r2)

table_call <- etable(r1, r2,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'ar2'), 
                     se.below = TRUE, 
                     digits = 3, 
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
                     tex = TRUE,
                     dict = c(positive_delta_bond_debt = 'Increase in Bond Text (2yr)',
                              election = 'Election Year',
                              issuance_window = 'Bond Issuance Year',
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

writeLines(modified_output, paste0(tbl_dir, '/tx_website_time_series_reg_2yr.tex'))


# Estimate the website-disclosure specification in levels using PPML. Restrict
# the sample to city-years with 50 processed sub-URLs so Bond Count is measured
# over a comparable amount of website content across observations.
website_city_year_poisson <- website_city_year[
  !is.na(fips) & total_subs == 50
]

r1_poisson <- fepois(
  bond_count ~ election | seed_issuer + year,
  data = website_city_year_poisson,
  cluster = ~fips
)
summary(r1_poisson)

r2_poisson <- fepois(
  bond_count ~ election + issuance_window + ln_county_gdp_prior +
    ln_county_pop_prior + ln_county_pers_inc_prior | seed_issuer + year,
  data = website_city_year_poisson,
  cluster = ~fips
)
summary(r2_poisson)

table_call <- etable(r1_poisson, r2_poisson,
                     coefstat = 'tstat',
                     style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                     fitstat = c('n', 'pr2'),
                     se.below = TRUE,
                     digits = 3,
                     digits.stats = 3,
                     signif.code = c("***"=0.01, "**"=0.05, "*"=0.10),
                     tex = TRUE,
                     dict = c(bond_count = 'Bond Count',
                              election = 'Election Year',
                              issuance_window = 'Bond Issuance Year',
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

writeLines(modified_output, paste0(tbl_dir, '/tx_website_time_series_reg_2yr_poisson.tex'))






# merge media with election website 
election <- election_media[, .(GovernmentName, ElectionDate, PropNumber, unique_sources_12m_prior, articles_2m_before_to_election)][election, on = .(GovernmentName, ElectionDate, PropNumber)]
election[, covered_3 := ifelse(articles_2m_before_to_election > 0, 1, 0)]


election[, abs_vote_margin := abs(vote_margin)]
election[, bond_debt_count := bond_count + debt_count]

# THIS IS LOOKING GOOD - check county demo variables

election[, log_bond_debt_count := log(1  + bond_count)]
election[, high_bond_count := ifelse(bond_count > median(bond_count, na.rm = TRUE), 1, 0)]



r0 <- feols(failed ~ high_bond_count|year + purp_broad_new, data = election, cluster = ~County, fixef.rm = 'singleton')
summary(r0)
r1 <- feols(failed ~ high_bond_count + ln_amount  + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior  |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r1)
r2 <- feols(abs_vote_margin  ~ high_bond_count |year + purp_broad_new, data = election, cluster = ~County,  fixef.rm = 'singleton')
summary(r2) 
r3 <- feols(abs_vote_margin ~ high_bond_count + ln_amount  + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior   |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
summary(r3)


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
