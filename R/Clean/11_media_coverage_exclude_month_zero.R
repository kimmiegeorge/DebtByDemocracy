# 11: Media coverage excluding month zero (Online Appendix)

rm(list = ls())

library(data.table)
library(DescTools)
library(fixest)
library(haven)

project_dir <- path.expand("~/Dropbox/Voting on Bonds")
data_dir <- file.path(project_dir, "Data")
clean_data_dir <- file.path(data_dir, "Clean_Intermediate")
raw_table_dir <- file.path(project_dir, "Code", "R", "Clean", "output", "revision_tables")
processed_table_dir <- file.path(project_dir, "Code", "R", "Clean", "output", "processed")

source(file.path(project_dir, "Code", "R", "Clean", "00_modify_etable_rounding.R"))
source(file.path(project_dir, "Code", "R", "Clean", "00_border_pair_definitions.R"))

raw_output_file <- file.path(raw_table_dir, "media_coverage_exclude_month_zero.tex")
processed_output_file <- file.path(processed_table_dir, "media_coverage_exclude_month_zero.tex")


# -----------------------------------------------------------------------------
# Table formatting
# -----------------------------------------------------------------------------

add_media_sample_headers <- function(tex, outcome_label) {
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]

  outcome_header_idx <- grep(outcome_label, lines, fixed = TRUE)
  if (length(outcome_header_idx) == 0) {
    return(lines)
  }

  insert_idx <- outcome_header_idx[1] + 1
  if (insert_idx <= length(lines) && grepl("\\\\cmidrule\\(lr\\)\\{2-5\\}", lines[insert_idx])) {
    sample_header <- c(
      "    & \\multicolumn{2}{c}{Full Sample} & \\multicolumn{2}{c}{Border-State Sample}\\\\",
      "   \\cmidrule(lr){2-3}\\cmidrule(lr){4-5}"
    )
    lines <- append(lines, sample_header, after = insert_idx)
  }

  lines
}


# -----------------------------------------------------------------------------
# Data preparation
# -----------------------------------------------------------------------------

full_data <- as.data.table(read_dta(
  file.path(data_dir, "Mergent", "Clean", "260716_city_cusiplevel_statereq_purpose_yieldspread.dta"),
  col_select = c("seed_issuer_id", "fips", "issuer_long_name")
))

issuers <- full_data[, .(
  fips = first(fips),
  issuer_long_name = first(issuer_long_name)
), by = seed_issuer_id]

issuance_lvl <- fread(file.path(
  clean_data_dir,
  "News",
  "Issuance_Lvl_News_With_Lagged_News.csv"
))
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]
issuance_lvl[, city_rev_vote := fifelse(state == "MO", 1, city_rev_vote)]
issuance_lvl[, city_go_vote := fifelse(state == "RI", NA_real_, city_go_vote)]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & !is.na(ln_employment)]

border_articles <- fread(file.path(
  clean_data_dir,
  "Border States",
  "Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv"
))
border_articles <- border_articles[!is.na(ln_employment)]

add_prior_issuance_indicator <- function(dt) {
  setorder(dt, seed_issuer_id, issuance_year_month_id)
  dt[, lag_issuance_ym_id := shift(issuance_year_month_id), by = seed_issuer_id]
  dt[, months_since_prior_issuance := issuance_year_month_id - lag_issuance_ym_id]
  dt[, bond_prior_12 := fifelse(
    !is.na(months_since_prior_issuance) & months_since_prior_issuance <= 12,
    1,
    0
  )]
  invisible(dt)
}

add_prior_issuance_indicator(issuance_lvl)
add_prior_issuance_indicator(border_articles)

border_articles <- filter_paper_border_pairs(border_articles)
border_articles[, state_year := interaction(state, year, drop = TRUE)]

issuance_lvl[, log_sources := log1p(unique_sources_12)]
border_articles[, log_sources := log1p(unique_sources_12)]

full_sample <- issuance_lvl[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]
border_sample <- border_articles[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]

# Use an empirical nearest-rank percentile so the count cap is an observed
# integer. Compute each cap on the exact sample used by its regressions.
full_article_caps <- quantile(
  full_sample$total_rp_articles_12_neg1,
  probs = c(0.01, 0.99),
  na.rm = TRUE,
  type = 1
)
border_article_caps <- quantile(
  border_sample$total_rp_articles_12_neg1,
  probs = c(0.01, 0.99),
  na.rm = TRUE,
  type = 1
)

full_sample[, total_articles_12_neg1_win := Winsorize(
  total_rp_articles_12_neg1,
  val = full_article_caps
)]
border_sample[, total_articles_12_neg1_win := Winsorize(
  total_rp_articles_12_neg1,
  val = border_article_caps
)]


# -----------------------------------------------------------------------------
# Regressions
# -----------------------------------------------------------------------------

r1 <- fepois(
  total_articles_12_neg1_win ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount | issuance_year_month_id + purp_broad,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

r1b <- fepois(
  total_articles_12_neg1_win ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc |
    issuance_year_month_id + purp_broad,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

r2 <- fepois(
  total_articles_12_neg1_win ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount | issuance_year_month_id + group + purp_broad,
  data = border_sample,
  vcov = vcov_cluster(~state_year)
)

r2b <- fepois(
  total_articles_12_neg1_win ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc |
    issuance_year_month_id + group + purp_broad,
  data = border_sample,
  vcov = vcov_cluster(~state_year)
)


# -----------------------------------------------------------------------------
# Raw regression table
# -----------------------------------------------------------------------------

outcome_label <- "Total Articles - 12mo (Excl. Month 0)"

table_call <- etable(
  r1, r1b, r2, r2b,
  coefstat = "tstat",
  style.tex = style.tex(
    main = "aer",
    fixef.suffix = " FE",
    yesNo = c("Yes", "No")
  ),
  fitstat = c("n", "pr2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    total_articles_12_neg1_win = outcome_label,
    city_go_vote = "Vote",
    bond_prior_12 = "Bond Issuance - 12mo",
    log_sources = "Num Sources",
    ln_amount = "Amount",
    ln_gdp = "County ln(GDP)",
    ln_pop = "County ln(Pop)",
    ln_pers_inc = "County ln(Pers. Inc)",
    group = "State-Border",
    purp_broad = "Purpose",
    issuance_year_month_id = "Year-Month"
  ),
  placement = "H",
  replace = TRUE
)

table_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
table_output <- format_table(
  table_output,
  cluster_level = c("State", "State", "State-Year", "State-Year"),
  drop_covariance = TRUE
)
table_output <- add_media_sample_headers(table_output, outcome_label)

dir.create(raw_table_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(table_output, raw_output_file)


# -----------------------------------------------------------------------------
# Processed supplemental table wrapper
# -----------------------------------------------------------------------------

processed_output <- c(
  "\\clearpage",
  "\\begin{table}[H]\\centering",
  "\\def\\sym#1{\\ifmmode^{#1}\\else\\(^{#1}\\)\\fi}",
  "\\begingroup",
  "\\caption{\\textbf{GO bond referendums and bond-related media coverage: Excluding the issuance month}}",
  "\\label{tab:media_coverage_exclude_month_zero}",
  "",
  paste0(
    "\\parbox{\\textwidth}{This table tests whether a GO bond referendum requirement is associated with media coverage of an issuance when the dependent variable excludes coverage during the issuance month. ",
    "\\textit{Total Articles - 12mo (Excl. Month 0)} is the number of bond-related articles from month $-12$ through month $-1$. ",
    "The article count is winsorized at the empirical 1st and 99th percentiles within each estimation sample. ",
    "The table reports Poisson pseudo-maximum-likelihood estimates. Columns 1--2 compare cities in states with a GO bond referendum requirement to cities in states with no GO bond referendum requirement. ",
    "Columns 3--4 compare cities located along the border of states with and without GO bond referendum requirements and include state-border fixed effects. ",
    "All columns include fixed effects for the issuance month and Mergent project purpose. t-statistics are reported in parentheses. ",
    "Standard errors are clustered by state in columns 1--2 and by state-year in columns 3--4. ",
    "*, **, and *** indicate statistical significance at the 10\\%, 5\\%, and 1\\% levels. All variables are defined in \\textit{Appendix A}.}"
  ),
  "\\endgroup",
  "\\end{table}",
  "",
  "\\input{tables/clean/raw/media_coverage_exclude_month_zero}"
)

dir.create(processed_table_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(processed_output, processed_output_file)
