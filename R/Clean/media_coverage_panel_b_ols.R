# Media coverage Panel B: OLS estimates for log(1 + total articles)

rm(list = ls())

library(data.table)
library(fixest)
library(haven)

project_dir <- path.expand("~/Dropbox/Voting on Bonds")
data_dir <- file.path(project_dir, "Data")
clean_data_dir <- file.path(data_dir, "Clean_Intermediate")
table_dir <- file.path(project_dir, "Code", "R", "Clean", "output", "revision_tables")

source(file.path(project_dir, "Code", "R", "Clean", "modify_etable_rounding.R"))
source(file.path(project_dir, "Code", "R", "Clean", "border_pair_definitions.R"))

output_file <- file.path(table_dir, "media_coverage_panel_b_ols.tex")


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

border_articles <- fread(file.path(
  clean_data_dir,
  "Border States",
  "Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv"
))

issuance_lvl[, city_go_vote := fifelse(state == "RI", NA_real_, city_go_vote)]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & !is.na(ln_employment)]
border_articles <- border_articles[!is.na(ln_employment)]
border_articles <- filter_paper_border_pairs(border_articles)
border_articles[, state_year := interaction(state, year, drop = TRUE)]

add_media_variables <- function(dt) {
  setorder(dt, seed_issuer_id, issuance_year_month_id)
  dt[, lag_issuance_ym_id := shift(issuance_year_month_id), by = seed_issuer_id]
  dt[, months_since_prior_issuance := issuance_year_month_id - lag_issuance_ym_id]
  dt[, bond_prior_12 := fifelse(
    !is.na(months_since_prior_issuance) & months_since_prior_issuance <= 12,
    1,
    0
  )]
  dt[, log_sources := log1p(unique_sources_12)]
  dt[, log_total_articles_12_0 := log1p(total_rp_articles_12_0)]
  invisible(dt)
}

add_media_variables(issuance_lvl)
add_media_variables(border_articles)

full_sample <- issuance_lvl[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]
border_sample <- border_articles[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]


# -----------------------------------------------------------------------------
# Panel B regressions
# -----------------------------------------------------------------------------

r1 <- feols(
  log_total_articles_12_0 ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount | issuance_year_month_id + purp_broad,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

r1b <- feols(
  log_total_articles_12_0 ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc |
    issuance_year_month_id + purp_broad,
  data = full_sample,
  vcov = vcov_cluster(~state)
)

r2 <- feols(
  log_total_articles_12_0 ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount | issuance_year_month_id + group + purp_broad,
  data = border_sample,
  vcov = vcov_cluster(~state_year)
)

r2b <- feols(
  log_total_articles_12_0 ~ city_go_vote + bond_prior_12 + log_sources +
    ln_amount + ln_gdp + ln_pop + ln_pers_inc |
    issuance_year_month_id + group + purp_broad,
  data = border_sample,
  vcov = vcov_cluster(~state_year)
)

outcome_label <- "Log(1 + Total Articles - 12mo)"

table_call <- etable(
  r1, r1b, r2, r2b,
  coefstat = "tstat",
  style.tex = style.tex(
    main = "aer",
    fixef.suffix = " FE",
    yesNo = c("Yes", "No")
  ),
  fitstat = c("n", "ar2"),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  dict = c(
    log_total_articles_12_0 = outcome_label,
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

dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(table_output, output_file)

message("Wrote ", output_file)
