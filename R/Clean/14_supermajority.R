#!/usr/bin/env Rscript

# 14: Full-sample supermajority specifications
#
# Combines the controlled media-coverage specification from step 02 with the
# 2017 UTGO-share and weighted-average yield-spread specifications from step 05.
# Each regression adds the indicator for states whose municipal GO bonds require
# more than a simple majority for approval.

rm(list = ls())

required_packages <- c("data.table", "fixest")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop("Missing required R packages: ", paste(missing_packages, collapse = ", "))
}

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

find_project_root <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  start <- if (length(file_arg) > 0L) {
    dirname(normalizePath(sub("^--file=", "", file_arg[[1L]]), mustWork = TRUE))
  } else {
    normalizePath(getwd(), mustWork = TRUE)
  }

  candidate <- start
  for (i in seq_len(8L)) {
    if (dir.exists(file.path(candidate, "Code")) &&
        dir.exists(file.path(candidate, "Data"))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  stop("Could not locate the project root from: ", start)
}

root <- find_project_root()
clean_dir <- file.path(root, "Code", "R", "Clean")
tbl_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = file.path(clean_dir, "output", "revision_tables")
)
dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(clean_dir, "00_modify_etable_rounding.R"))
source(file.path(clean_dir, "00_state_policy_definitions.R"))
source(file.path(clean_dir, "00_tax_privilege_definitions.R"))

# Media-coverage sample and controlled full-sample specification from step 02.
media_file <- Sys.getenv(
  "MEDIA_FULL_REGRESSION_DATA",
  unset = file.path(
    root,
    "Data", "Clean_Intermediate", "News",
    "media_full_sample_regression_data.csv"
  )
)
issuance_lvl <- fread(media_file)
issuance_lvl[, super_majority := as.integer(state %in% super_majority_states)]

supermajority_media <- fepois(
  total_articles_12_0_win ~ city_go_vote + super_majority + bond_prior_12 +
    log_sources + ln_amount + ln_gdp + ln_pop + ln_pers_inc |
    issuance_year_month_id + purp_broad,
  data = issuance_lvl[
    go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
  ],
  vcov = vcov_cluster(~state)
)

# Prepare the 2017 point-in-time sample exactly as in step 05.
point_in_time_file <- file.path(
  root,
  "Data", "Clean_Intermediate", "Census COG Finance", "processed",
  "no_refundings", "census_mergent_debt_cross_section_2017.csv"
)
data_2017 <- fread(point_in_time_file)
data_2017[, `:=`(
  city_go_vote = as.numeric(city_go_vote),
  state_go_vote = as.numeric(state_go_vote),
  city_rev_vote = as.numeric(city_rev_vote)
)]
data_2017[, super_majority := as.integer(state %in% super_majority_states)]
add_low_state_tax_privilege(data_2017, year_value = 2017)
data_2017[, ln_census_population := log(census_population)]

data_2017 <- data_2017[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]
data_2017[is.na(strict_municipal_debt_limit), strict_municipal_debt_limit := 0]

full_sample_2017 <- data_2017[
  insample == 1 &
    !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]

# Point-in-time supermajority specifications from step 05.
supermajority_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + super_majority + ln_gdp +
    ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + glm_proactive +
    state_ltgo_allowed + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

supermajority_yield_spread <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + super_majority +
    ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue +
    mergent_any_insured_go_revenue + mergent_any_callable_go_revenue +
    mergent_any_sinkable_go_revenue + glm_proactive + state_ltgo_allowed +
    state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
  data = full_sample_2017,
  vcov = vcov_cluster(~state)
)

media_pseudo_r2 <- fitstat(supermajority_media, "pr2")[[1L]]
utgo_adjusted_r2 <- fitstat(supermajority_utgo, "ar2")[[1L]]
yield_spread_adjusted_r2 <- fitstat(supermajority_yield_spread, "ar2")[[1L]]

# Three-column table: one controlled specification for each requested outcome.
table_call <- etable(
  supermajority_media,
  supermajority_utgo,
  supermajority_yield_spread,
  coefstat = "tstat",
  drop = "Constant",
  style.tex = style.tex(
    main = "aer",
    fixef.suffix = " FE",
    yesNo = c("Yes", "No")
  ),
  fitstat = "n",
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
  tex = TRUE,
  keep_raw = c("^city_go_vote$", "^super_majority$"),
  order = c("%city_go_vote", "%super_majority"),
  dict = c(
    total_articles_12_0_win = "Media Coverage",
    frac_utgo_outstanding = "UTGO",
    mergent_wavg_yield_spread_go_revenue = "Wtd. Avg. Yield Spread",
    city_go_vote = "Vote",
    super_majority = "Supermajority State",
    issuance_year_month_id = "Year-Month",
    purp_broad = "Purpose"
  ),
  placement = "H"
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output <- format_table(modified_output, cluster_level = "State")

n_idx <- grep("^[[:space:]]*N[[:space:]]*&", modified_output)
if (length(n_idx) == 1L) {
  modified_output <- append(
    modified_output,
    c(
      paste0(
        "   Pseudo R$^2$               & ",
        sprintf("%.3f", media_pseudo_r2),
        " &  & \\\\"
      ),
      paste0(
        "   Adj. R$^2$                 &  & ",
        sprintf("%.3f", utgo_adjusted_r2),
        " & ",
        sprintf("%.3f", yield_spread_adjusted_r2),
        "\\\\"
      ),
      "   Controls                   & Yes & Yes & Yes\\\\"
    ),
    after = n_idx[1L]
  )
}
modified_output <- modified_output[
  !grepl("^[[:space:]]*\\\\\\\\[[:space:]]*$", modified_output)
]

modified_output <- add_panel(
  modified_output,
  "Panel C: Supermajority rejection risk",
  ncols = 4
)
modified_output <- sub("[[:space:]]+$", "", modified_output)
writeLines(modified_output, file.path(tbl_dir, "14_supermajority.tex"))
