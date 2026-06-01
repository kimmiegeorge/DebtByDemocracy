# TX election outcome tests
#---------------------------------------
rm(list = ls())
library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, fixest, haven, xtable)
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')
source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/dpc_purpose_helpers.R')
tbl_dir <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/submission_tables"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"


# ===============================================================================
# DATA LOADING AND PREPARATION - MEDIA FIRST
# ===============================================================================

city_month <- fread(paste0(data_wd, 'TX/City_Month_Elections_News_WithFailed_251014.csv'))
election <- fread(paste0(data_wd, 'TX/News/Election_Level_With_News_WithFailed_251014.csv'))

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

election <- election[!is.na(ln_county_employment_prior) & !is.na(ln_county_gdp_prior) & !is.na(unique_sources_12m_prior)]

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


full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
dpc_purpose <- load_dpc_purpose(data_wd)
# Election data does not include CUSIPs, so this adds DPC classifications
# for bonds issued by the same issuer in the same election year-month.
election_dpc_purpose <- build_dpc_purpose_lookup(
  full_data,
  dpc_purpose,
  by_cols = c("seed_issuer", "year", "month")
)
election <- election_dpc_purpose[election, on = .(seed_issuer, year, month)]

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

# City-Month Level descriptives
desc_city_month <- city_month[, .(covered, 
                                   election_window,
                                   issuance_window)]

desc_city_month_col <- desc_city_month[, lapply(.SD, function(col) {
  stats <- c(Unit = 'City-Month',
             Mean = mean(col, na.rm = TRUE),
             Std = sd(col, na.rm = TRUE),
             Min = min(col, na.rm = TRUE),
             p1 = quantile(col, probs = 0.01, na.rm = TRUE),
             Median = median(col, na.rm = TRUE),
             p99 = quantile(col, probs = 0.99, na.rm = TRUE),
             Max = max(col, na.rm = TRUE),
             N = sum(!is.na(col)))
  return(stats)
}), .SDcols = colnames(desc_city_month)]
desc_city_month_col <- transpose(desc_city_month_col, keep.names = "variable")
colnames(desc_city_month_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
desc_city_month_col[, Variable := c('Bond Coverage', 'Election', 'Bond Issuance')]

# Election Level descriptives
desc_election <- election[, .(failed, 
                               abs_vote_margin,
                               coverage_3)]

desc_election_col <- desc_election[, lapply(.SD, function(col) {
  stats <- c(Unit = 'Election',
             Mean = mean(col, na.rm = TRUE),
             Std = sd(col, na.rm = TRUE),
             Min = min(col, na.rm = TRUE),
             p1 = quantile(col, probs = 0.01, na.rm = TRUE),
             Median = median(col, na.rm = TRUE),
             p99 = quantile(col, probs = 0.99, na.rm = TRUE),
             Max = max(col, na.rm = TRUE),
             N = sum(!is.na(col)))
  return(stats)
}), .SDcols = colnames(desc_election)]
desc_election_col <- transpose(desc_election_col, keep.names = "variable")
colnames(desc_election_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
desc_election_col[, Variable := c('Failed', 'Margin', 'Bond Coverage[-3, 0]')]

# Combine both tables (City-Month first, then Election)
desc_col <- rbind(desc_city_month_col, desc_election_col)

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
                              election_window = 'Election',
                              issuance_window = "Bond Issuance",
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
modified_output <- add_panel(modified_output, 'Panel A: Elections and media coverage')

writeLines(modified_output, paste0(tbl_dir, '/tx_city_month_reg.tex'))


# 
# 
# # ===============================================================================
# # descriptives on elections at the union of website and media samples
# # ===============================================================================
# election_website <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_251209.csv'))
# election_website[, abs_vote_margin := abs(vote_margin)]
# election_website <- election_website[total_subs > 10]
# 
# election_media <- election[, .(GovernmentName, ElectionDate, PropNumber, failed, abs_vote_margin)]
# election_website <- election_website[, .(GovernmentName, ElectionDate, PropNumber, failed, abs_vote_margin)]
# 
# election_all <- rbindlist(list(election_media, election_website))
# election_all <- unique(election_all)
# 
# 
# 
# desc <- election_all[, .(failed, 
#                          abs_vote_margin)]
# 
# desc_col <- desc[, lapply(.SD, function(col) {
#   stats <- c(Mean = mean(col, na.rm = TRUE),
#              Std = sd(col, na.rm = TRUE),
#              Min = min(col, na.rm = TRUE),
#              p1 = quantile(col, probs = 0.01, na.rm = TRUE),
#              Median = median(col, na.rm = TRUE),
#              p99 = quantile(col, probs = 0.99, na.rm = TRUE),
#              Max = max(col, na.rm = TRUE),
#              N = sum(!is.na(col)))
#   return(stats)
# }), .SDcols = colnames(desc)]
# desc_col <- transpose(desc_col, keep.names = "variable")
# colnames(desc_col) <- c("variable", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
# 
# desc_col[, variable := c('Failed', 'Margin')]
# stargazer(desc_col, summary = F,type = 'latex', no.space = T, digits = 2,
#           rownames = F, table.placement = "H", out = paste0(tbl_dir ,'/Election Level Desc.tex'))
# 
# 
# # ===============================================================================
# # DATA LOADING AND PREPARATION - WEBSITES
# # ===============================================================================
# election_media <- election
# city_month <- fread(paste0(data_wd, 'Websites/Texas/time_series_website_data_251217.csv'))
# city_month <- city_month[total_subs == 50]
# election <- fread(paste0(data_wd, 'Websites/Texas/election_level_website_data_251217.csv'))
# 
# 
# # merge media with election website 
# election <- election_media[, .(GovernmentName, ElectionDate, PropNumber, unique_sources_12m_prior, articles_2m_before_to_election)][election, on = .(GovernmentName, ElectionDate, PropNumber)]
# election[, covered_3 := ifelse(articles_2m_before_to_election > 0, 1, 0)]
# 
# 
# election[, abs_vote_margin := abs(vote_margin)]
# election[, bond_debt_count := bond_count + debt_count]
# 
# # THIS IS LOOKING GOOD - check county demo variables
# 
# election <- election[total_subs >= 20]
# election[, log_bond_debt_count := log(1 + fiscal_count + bond_count)]
# election[, high_bond_count := ifelse(bond_debt_count > median(bond_debt_count), 1, 0)]
# election[, fiscal_bond_count := fiscal_count + bond_debt_count]
# election[, high_bond_count := ifelse(fiscal_bond_count >= median(fiscal_bond_count), 1, 0)]
# election[, ln_cum_num_issues_unlim := log(1+cum_num_issues)]
# 
# r0 <- feols(failed ~ high_bond_count|year + purp_broad_new, data = election, cluster = ~County, fixef.rm = 'singleton')
# summary(r0)
# r1 <- feols(failed ~ high_bond_count + ln_amount + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior  |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
# summary(r1)
# r2 <- feols(abs_vote_margin  ~ high_bond_count |year + purp_broad_new, data = election, cluster = ~County,  fixef.rm = 'singleton')
# summary(r2) 
# r3 <- feols(abs_vote_margin ~ high_bond_count + ln_amount  + ln_cum_num_issues_unlim + ln_county_gdp_prior + ln_county_pop_prior +  ln_county_pers_inc_prior   |year + purp_broad_new, data = election,cluster = ~County,  fixef.rm = 'singleton')
# summary(r3)
# 
# 
# table_call <- etable(r0, r1, r2, r3,
#                      coefstat = 'tstat',
#                      style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
#                      fitstat = c('n', 'ar2'), 
#                      se.below = TRUE, 
#                      digits = 3, 
#                      digits.stats = 3,
#                      signif.code = c("***"=0.01, "**"=0.05, "*"=0.10), 
#                      tex = TRUE,
#                      dict = c(failed = 'Failed',
#                               pct_yes = 'Pct Yes',
#                               high_bond_count = 'High Website Disclosure',
#                               abs_vote_margin = 'Margin',
#                               ln_cum_num_issues_unlim = 'Num Issuance',
#                               ln_amount = "Amount",
#                               ln_county_gdp_prior = 'County ln(GDP)', 
#                               ln_county_pop_prior = 'County ln(Pop)', 
#                               ln_county_pers_inc_prior = 'County ln(Pers. Inc)',
#                               ln_county_employment_prior = 'County ln(Emp)',
#                               year = 'Year',
#                               purp_broad_new = 'Purpose'),
#                      placement = 'H',
#                      #file = paste0(tables_wd, '/media_coverage.tex'), 
#                      replace = TRUE)
# 
# 
# modified_output <- modify_etable_rounding(
#   table_call,
#   coef_digits = 3,
#   tstat_digits = 2
# )
# 
# modified_output <- format_table(modified_output, cluster_level = "County")
# modified_output <- add_panel(modified_output, 'Panel D: Website disclosure and election outcomes')
# 
# writeLines(modified_output, paste0(tbl_dir, '/tx_failed_and_margin_websites.tex'))
# 
# 
