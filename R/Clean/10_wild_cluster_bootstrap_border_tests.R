# Set up ----

# 10: Wild-cluster score bootstrap inference for the current border specifications.
# Fit every unrestricted, null, and auxiliary regression explicitly. Enumerate
# distinct two-sided Rademacher signs by state without refitting per draw.
rm(list = ls())

library(data.table)
library(fixest)

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
output_dir <- Sys.getenv(
  "RESULTS_DIR",
  unset = "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables"
)
processed_output_dir <- Sys.getenv(
  "PROCESSED_RESULTS_DIR",
  unset = "/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/processed"
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_output_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "Code/R/Clean/00_tax_privilege_definitions.R"))
source(file.path(root, "Code/R/Clean/00_border_pair_definitions.R"))

output_tex <- file.path(output_dir, "wild_cluster_bootstrap_border_tests.tex")
output_processed_tex <- file.path(processed_output_dir, "wild_cluster_bootstrap_border_tests.tex")
treatment <- "city_go_vote"
poisson_glm_iter <- 100
poisson_fixef_iter <- 50000

# Score-bootstrap and result helpers ----

enumerated_rademacher_p <- function(cluster_scores, max_exact_clusters = 20L,
                                    B = 99999L, seed = 20260720L) {
  cluster_scores <- as.numeric(cluster_scores)
  if (any(!is.finite(cluster_scores))) {
    stop('Cluster scores must all be finite.')
  }

  G <- length(cluster_scores)
  if (G < 2L) {
    stop('Wild-cluster inference requires at least two clusters.')
  }

  observed_sum <- abs(sum(cluster_scores))
  tolerance <- 100 * .Machine$double.eps * max(1, observed_sum)

  # For a two-sided test, w and -w yield the same statistic. Fixing the first
  # cluster's sign at +1 therefore enumerates every distinct sign assignment.
  if (G <= max_exact_clusters) {
    draws <- 2^(G - 1L)
    exceedances <- 0L
    batch_size <- 65536L

    for (batch_start in seq.int(0, draws - 1L, by = batch_size)) {
      batch_end <- min(draws - 1L, batch_start + batch_size - 1L)
      ids <- batch_start:batch_end
      weights <- vapply(
        0:(G - 2L),
        function(bit) 2L * bitwAnd(bitwShiftR(ids, bit), 1L) - 1L,
        FUN.VALUE = integer(length(ids))
      )
      if (G == 2L) {
        weights <- matrix(weights, ncol = 1L)
      }
      bootstrap_sums <- cluster_scores[1L] +
        as.numeric(weights %*% cluster_scores[-1L])
      exceedances <- exceedances + sum(abs(bootstrap_sums) >= observed_sum - tolerance)
    }

    return(list(
      p_value = exceedances / draws,
      draws = draws,
      enumeration = 'exact'
    ))
  }

  set.seed(seed)
  weights <- matrix(
    sample(c(-1, 1), B * G, replace = TRUE),
    nrow = B,
    ncol = G
  )
  bootstrap_sums <- as.numeric(weights %*% cluster_scores)

  list(
    p_value = (1 + sum(abs(bootstrap_sums) >= observed_sum - tolerance)) / (B + 1),
    draws = B,
    enumeration = 'simulation'
  )
}

extract_p_value <- function(model, cluster_formula, coefficient = treatment) {
  coefficient_table <- fixest::coeftable(
    model,
    vcov = fixest::vcov_cluster(cluster_formula)
  )
  p_column <- grep('^Pr\\(', colnames(coefficient_table), value = TRUE)
  if (length(p_column) != 1L || !(coefficient %in% rownames(coefficient_table))) {
    stop('Could not extract the clustered p-value for ', coefficient, '.')
  }
  unname(coefficient_table[coefficient, p_column])
}

# These helpers summarize already-fitted models; no regressions run in functions.
wild_cluster_score_test <- function(model, model_data, restricted_model,
                                    auxiliary_model, outcome, family, cluster = "state") {
  if (nobs(model) != nrow(model_data) || nobs(restricted_model) != nrow(model_data) ||
      nobs(auxiliary_model) != nrow(model_data)) {
    stop("The unrestricted, null, and auxiliary models must use the same rows.")
  }
  treatment_residual <- as.numeric(residuals(auxiliary_model))
  if (family == "poisson") {
    null_mean <- as.numeric(fitted(restricted_model))
    score_observation <- treatment_residual * (model_data[[outcome]] - null_mean)
  } else {
    score_observation <- treatment_residual * as.numeric(residuals(restricted_model))
  }
  if (length(score_observation) != nrow(model_data) || any(!is.finite(score_observation))) {
    stop("Could not construct finite observation-level scores for ", outcome, ".")
  }
  cluster_id <- as.character(model_data[[cluster]])
  if (anyNA(cluster_id)) {
    stop("The bootstrap cluster variable contains missing values.")
  }
  cluster_scores <- rowsum(score_observation, cluster_id, reorder = TRUE)[, 1L]
  bootstrap <- enumerated_rademacher_p(cluster_scores)
  list(
    estimate = unname(coef(model)[treatment]),
    p_value = bootstrap$p_value,
    observations = nobs(model),
    state_clusters = length(cluster_scores),
    bootstrap_draws = bootstrap$draws,
    enumeration = bootstrap$enumeration,
    score_statistic = sum(cluster_scores) / sqrt(sum(cluster_scores^2)),
    model_data = model_data
  )
}

summarize_specification <- function(model, model_data, restricted_model, auxiliary_model,
                                    panel, column, outcome_label, outcome, family,
                                    baseline_cluster) {
  bootstrap <- wild_cluster_score_test(
    model, model_data, restricted_model, auxiliary_model, outcome, family
  )
  model_sample <- bootstrap$model_data
  state_year_clusters <- if ('state_year' %in% names(model_sample)) {
    uniqueN(model_sample$state_year)
  } else {
    NA_integer_
  }

  data.table(
    panel = panel,
    column = column,
    outcome = outcome_label,
    outcome_variable = outcome,
    estimator = ifelse(family == 'poisson', 'PPML', 'OLS'),
    coefficient = bootstrap$estimate,
    baseline_cluster = baseline_cluster,
    baseline_p_value = extract_p_value(
      model,
      as.formula(paste0('~', baseline_cluster))
    ),
    state_cluster_p_value = extract_p_value(model, ~state),
    wild_cluster_p_value = bootstrap$p_value,
    fit_statistic = as.numeric(fixest::fitstat(
      model,
      if (family == 'poisson') 'pr2' else 'ar2'
    )[[1L]]),
    fit_statistic_label = if (family == 'poisson') 'Pseudo R$^2$' else 'Adj. R$^2$',
    observations = bootstrap$observations,
    state_clusters = bootstrap$state_clusters,
    state_year_clusters = state_year_clusters,
    bootstrap_draws = bootstrap$bootstrap_draws,
    bootstrap_enumeration = bootstrap$enumeration,
    score_statistic = bootstrap$score_statistic
  )
}

# Panel A: Website disclosure ----

# Read the exact prepared sample used by step 01, including prior-year controls.
website_data <- fread(Sys.getenv(
  "WEBSITE_REGRESSION_DATA",
  unset = file.path(root, "Data/Clean_Intermediate/Websites/border_state_website_regression_data.csv")
))
website_data[, group := factor(group)]
website_data[, year := factor(year)]
website_data[, state_year := factor(state_year)]

website_bond_url <- fepois(
  bond_url ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_bond_url_sample <- copy(website_data[obs(website_bond_url)])
website_bond_url_null <- fepois(
  bond_url ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_bond_url_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_bond_url_aux <- feols(
  city_go_vote ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_bond_url_sample, weights = fitted(website_bond_url_null)
)

website_bond_count <- fepois(
  bond_count ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_bond_count_sample <- copy(website_data[obs(website_bond_count)])
website_bond_count_null <- fepois(
  bond_count ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_bond_count_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_bond_count_aux <- feols(
  city_go_vote ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_bond_count_sample, weights = fitted(website_bond_count_null)
)

website_fiscal_url <- fepois(
  fiscal_url ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_fiscal_url_sample <- copy(website_data[obs(website_fiscal_url)])
website_fiscal_url_null <- fepois(
  fiscal_url ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_fiscal_url_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_fiscal_url_aux <- feols(
  city_go_vote ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_fiscal_url_sample, weights = fitted(website_fiscal_url_null)
)

website_fiscal_count <- fepois(
  fiscal_count ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_fiscal_count_sample <- copy(website_data[obs(website_fiscal_count)])
website_fiscal_count_null <- fepois(
  fiscal_count ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_fiscal_count_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_fiscal_count_aux <- feols(
  city_go_vote ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_fiscal_count_sample, weights = fitted(website_fiscal_count_null)
)

website_financial_docs <- fepois(
  financial_pdf_urls ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_financial_docs_sample <- copy(website_data[obs(website_financial_docs)])
website_financial_docs_null <- fepois(
  financial_pdf_urls ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_financial_docs_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
website_financial_docs_aux <- feols(
  city_go_vote ~ ln_1p_outstanding_debt_lag1 + state_monitor +
    gasb_municipal_gaap_required_any + nasact_audits_cities_towns_villages +
    ln_gdp + ln_pop + ln_pers_inc | group + year,
  data = website_financial_docs_sample, weights = fitted(website_financial_docs_null)
)

website_results <- rbindlist(list(
  summarize_specification(website_bond_url, website_bond_url_sample,
    website_bond_url_null, website_bond_url_aux, "A", 1L, "Bond URLs", "bond_url", "poisson", "state_year"),
  summarize_specification(website_bond_count, website_bond_count_sample,
    website_bond_count_null, website_bond_count_aux, "A", 2L, "Bond Count", "bond_count", "poisson", "state_year"),
  summarize_specification(website_fiscal_url, website_fiscal_url_sample,
    website_fiscal_url_null, website_fiscal_url_aux, "A", 3L, "Fiscal URLs", "fiscal_url", "poisson", "state_year"),
  summarize_specification(website_fiscal_count, website_fiscal_count_sample,
    website_fiscal_count_null, website_fiscal_count_aux, "A", 4L, "Fiscal Count", "fiscal_count", "poisson", "state_year"),
  summarize_specification(website_financial_docs, website_financial_docs_sample,
    website_financial_docs_null, website_financial_docs_aux, "A", 5L, "Financial Docs", "financial_pdf_urls", "poisson", "state_year")
))

# Panel B: Border-state media coverage ----

# Reuse step 02's prior-year BEA controls, GDP fallback, and article caps.
media_data <- fread(Sys.getenv(
  "MEDIA_BORDER_REGRESSION_DATA",
  unset = file.path(root, "Data/Clean_Intermediate/News/media_border_state_regression_data.csv")
))
media_data <- media_data[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]
submission_border_prior <- fread(file.path(
  root, "Code/R/Clean/input/media_submission_border_prior_12.csv"
))
submission_border_keys <- c("seed_issuer_id", "issuance_year_month_id", "group")
stopifnot(!anyDuplicated(submission_border_prior[, ..submission_border_keys]))
submission_border_matches <- media_data[
  submission_border_prior, on = submission_border_keys, nomatch = 0
]
if (nrow(submission_border_matches) != nrow(submission_border_prior)) {
  stop("Submitted media border rows are missing or duplicated in the current input.")
}
media_data[submission_border_prior, on = submission_border_keys,
  bond_prior_12 := i.bond_prior_12]

media_no_demographics <- fepois(
  total_articles_12_0_win ~ city_go_vote + bond_prior_12 + log_sources + ln_amount |
    issuance_year_month_id + group + purp_broad,
  data = media_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
media_no_demographics_sample <- copy(media_data[obs(media_no_demographics)])
stopifnot(fsetequal(media_no_demographics_sample[, ..submission_border_keys],
  submission_border_prior[, ..submission_border_keys]))
media_no_demographics_null <- fepois(
  total_articles_12_0_win ~ bond_prior_12 + log_sources + ln_amount |
    issuance_year_month_id + group + purp_broad,
  data = media_no_demographics_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
media_no_demographics_aux <- feols(
  city_go_vote ~ bond_prior_12 + log_sources + ln_amount |
    issuance_year_month_id + group + purp_broad,
  data = media_no_demographics_sample, weights = fitted(media_no_demographics_null)
)

media_demographics <- fepois(
  total_articles_12_0_win ~ city_go_vote + bond_prior_12 + log_sources + ln_amount +
    ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + group + purp_broad,
  data = media_data, vcov = ~state_year,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
media_demographics_sample <- copy(media_data[obs(media_demographics)])
stopifnot(nrow(fsetdiff(media_demographics_sample[, ..submission_border_keys],
  submission_border_prior[, ..submission_border_keys])) == 0)
media_demographics_null <- fepois(
  total_articles_12_0_win ~ bond_prior_12 + log_sources + ln_amount +
    ln_gdp + ln_pop + ln_pers_inc | issuance_year_month_id + group + purp_broad,
  data = media_demographics_sample,
  glm.iter = poisson_glm_iter, fixef.iter = poisson_fixef_iter
)
media_demographics_aux <- feols(
  city_go_vote ~ bond_prior_12 + log_sources + ln_amount + ln_gdp + ln_pop +
    ln_pers_inc | issuance_year_month_id + group + purp_broad,
  data = media_demographics_sample, weights = fitted(media_demographics_null)
)

media_results <- rbindlist(list(
  summarize_specification(media_no_demographics, media_no_demographics_sample,
    media_no_demographics_null, media_no_demographics_aux, "B", 1L,
    "No demographics", "total_articles_12_0_win", "poisson", "state_year"),
  summarize_specification(media_demographics, media_demographics_sample,
    media_demographics_null, media_demographics_aux, "B", 2L,
    "Demographics", "total_articles_12_0_win", "poisson", "state_year")
))

# Panel C: Secondary-market trading before maturity ----

# Reuse step 04's exact sample, raw trade indicators, and rating fixed effects.
regression_data_dir <- Sys.getenv(
  "MSRB_REGRESSION_DIR",
  unset = file.path(root, "Data/Clean_Intermediate/MSRB/Regression")
)
trade_border_data <- fread(file.path(regression_data_dir,
  "trade_border_sample_regression_ready.csv"))

trade_any <- feols(
  traded_before_maturity ~ city_go_vote + low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_border_data, vcov = ~state_year
)
trade_any_sample <- copy(trade_border_data[obs(trade_any)])
trade_any_null <- feols(
  traded_before_maturity ~ low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_any_sample
)
trade_any_aux <- feols(
  city_go_vote ~ low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_any_sample
)

trade_retail <- feols(
  retail_traded_before_maturity ~ city_go_vote + low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_border_data, vcov = ~state_year
)
trade_retail_sample <- copy(trade_border_data[obs(trade_retail)])
trade_retail_null <- feols(
  retail_traded_before_maturity ~ low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_retail_sample
)
trade_retail_aux <- feols(
  city_go_vote ~ low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_retail_sample
)

trade_institutional <- feols(
  institutional_traded_before_maturity ~ city_go_vote + low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_border_data, vcov = ~state_year
)
trade_institutional_sample <- copy(trade_border_data[obs(trade_institutional)])
trade_institutional_null <- feols(
  institutional_traded_before_maturity ~ low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_institutional_sample
)
trade_institutional_aux <- feols(
  city_go_vote ~ low_state_tax_privilege + disclosure_control +
    ln_amount + ln_maturity_mths + callable + sinkable + insured +
    ln_gdp + ln_pop + ln_pers_inc | year + purp_broad + group + rating_fe,
  data = trade_institutional_sample
)

trade_results <- rbindlist(list(
  summarize_specification(trade_any, trade_any_sample, trade_any_null, trade_any_aux,
    "C", 1L, "Trade", "traded_before_maturity", "linear", "state_year"),
  summarize_specification(trade_retail, trade_retail_sample, trade_retail_null, trade_retail_aux,
    "C", 2L, "Retail Trade", "retail_traded_before_maturity", "linear", "state_year"),
  summarize_specification(trade_institutional, trade_institutional_sample,
    trade_institutional_null, trade_institutional_aux,
    "C", 3L, "Inst. Trade", "institutional_traded_before_maturity", "linear", "state_year")
))

# Panel D: 2017 point-in-time debt choice and yield ----

# Mirror step 05's border construction and identifying-pair screen.
point_data <- fread(file.path(root,
  "Data/Clean_Intermediate/Census COG Finance/processed/no_refundings/census_mergent_debt_cross_section_2017_border_sample.csv"
))
point_data[, fips := as.character(fips)]
add_low_state_tax_privilege(point_data, year_value = 2017)
point_data[, ln_census_population := log(census_population)]
point_data[, state_year := interaction(state, year, drop = TRUE)]
point_data <- filter_debt_yield_border_pairs(point_data, "border_group")
point_data <- point_data[
  !is.na(ln_gdp) & !is.na(ln_census_population) & !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) & !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) & insample == 1 &
    !is.na(mergent_go_revenue_bonds_outstanding) & mergent_go_revenue_bonds_outstanding >= 2
]
identifying_groups <- point_data[, .(vote_values = uniqueN(city_go_vote)),
  by = border_group][vote_values == 2, border_group]
point_data <- point_data[border_group %in% identifying_groups]
# Numeric binary regressors preserve the treatment name used by score tests.
point_data[, `:=`(city_go_vote = as.numeric(city_go_vote),
  state_go_vote = as.numeric(state_go_vote))]

point_utgo <- feols(
  frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit | border_group,
  data = point_data, vcov = ~state_year
)
point_utgo_sample <- copy(point_data[obs(point_utgo)])
point_utgo_null <- feols(
  frac_utgo_outstanding ~ ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit | border_group,
  data = point_utgo_sample
)
point_utgo_aux <- feols(
  city_go_vote ~ ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit | border_group,
  data = point_utgo_sample
)

point_yield <- feols(
  mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp + ln_census_population +
    ln_pers_inc + ln_1p_county_nonmunicipal_total_debt +
    mergent_wavg_rating_go_revenue_zero_unrated + mergent_wavg_original_maturity_years_go_revenue +
    mergent_wavg_insured_go_revenue + mergent_wavg_sinkable_go_revenue +
    state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit | border_group,
  data = point_data, vcov = ~state_year
)
point_yield_sample <- copy(point_data[obs(point_yield)])
point_yield_null <- feols(
  mergent_wavg_yield_spread_go_revenue ~ ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue + mergent_wavg_insured_go_revenue +
    mergent_wavg_sinkable_go_revenue + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit | border_group,
  data = point_yield_sample
)
point_yield_aux <- feols(
  city_go_vote ~ ln_gdp + ln_census_population + ln_pers_inc +
    ln_1p_county_nonmunicipal_total_debt + mergent_wavg_rating_go_revenue_zero_unrated +
    mergent_wavg_original_maturity_years_go_revenue + mergent_wavg_insured_go_revenue +
    mergent_wavg_sinkable_go_revenue + state_go_vote + low_state_tax_privilege +
    strict_municipal_debt_limit | border_group,
  data = point_yield_sample
)

point_results <- rbindlist(list(
  summarize_specification(point_utgo, point_utgo_sample, point_utgo_null, point_utgo_aux,
    "D", 1L, "Pct UTGO", "frac_utgo_outstanding", "linear", "state_year"),
  summarize_specification(point_yield, point_yield_sample, point_yield_null, point_yield_aux,
    "D", 2L, "Wtd. Avg. Yield Spread", "mergent_wavg_yield_spread_go_revenue", "linear", "state_year")
))

# Results and compact four-panel LaTeX table ----

results <- rbindlist(
  list(website_results, media_results, point_results, trade_results),
  fill = TRUE
)
setorder(results, panel, column)
# Save full-precision estimates and inference so agreement with the main tables
# can be checked without reverse-engineering rounded LaTeX output.
fwrite(results, file.path(output_dir, "wild_cluster_bootstrap_border_tests_diagnostics.csv"))
significance_stars <- function(p_value) {
  ifelse(
    p_value < 0.01, '***',
    ifelse(p_value < 0.05, '**', ifelse(p_value < 0.10, '*', ''))
  )
}

format_coefficient <- function(estimate, p_value) {
  stars <- significance_stars(p_value)
  paste0(
    sprintf('%.3f', estimate),
    ifelse(stars == '', '', paste0('$^{', stars, '}$'))
  )
}

format_p_value <- function(p_value) {
  ifelse(p_value < 0.001, '$[p<0.001]$', sprintf('$[p=%.3f]$', p_value))
}

latex_row <- function(label, values) {
  paste0(paste(c(label, values), collapse = ' & '), '\\\\')
}

panel_table_lines <- function(panel_data, panel_title, header_lines,
                              fixed_effect_labels,
                              controls_label = 'Controls',
                              controls_values = NULL) {
  n_models <- nrow(panel_data)
  coefficient_values <- vapply(
    seq_len(n_models),
    function(i) format_coefficient(
      panel_data$coefficient[i], panel_data$wild_cluster_p_value[i]
    ),
    FUN.VALUE = character(1)
  )
  p_values <- vapply(
    panel_data$wild_cluster_p_value,
    format_p_value,
    FUN.VALUE = character(1)
  )
  observations <- format(
    panel_data$observations,
    big.mark = ',',
    scientific = FALSE,
    trim = TRUE
  )
  fit_statistics <- sprintf('%.3f', panel_data$fit_statistic)
  fit_label <- unique(panel_data$fit_statistic_label)
  if (length(fit_label) != 1L) {
    stop('Each panel must use a single fit-statistic label.')
  }
  if (is.null(controls_values)) {
    controls_values <- rep('Yes', n_models)
  }
  if (length(controls_values) != n_models) {
    stop('controls_values must have one entry per model in the panel.')
  }

  fixed_effect_lines <- vapply(
    fixed_effect_labels,
    function(label) latex_row(label, rep('Yes', n_models)),
    FUN.VALUE = character(1)
  )

  c(
    '\\begingroup',
    '\\centering',
    paste0(
      '\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}l',
      strrep('c', n_models),
      '}'
    ),
    paste0(
      '\\multicolumn{', n_models + 1L, '}{l}{\\textbf{', panel_title, '}}\\\\'
    ),
    '',
    '\\addlinespace',
    '   \\toprule',
    header_lines,
    latex_row('', paste0('(', seq_len(n_models), ')')),
    '   \\midrule ',
    latex_row('Vote', coefficient_values),
    latex_row('', p_values),
    '   \\hline',
    latex_row('N', observations),
    latex_row(fit_label, fit_statistics),
    latex_row(controls_label, controls_values),
    fixed_effect_lines,
    latex_row('Cluster', rep('State', n_models)),
    '   \\bottomrule',
    '\\end{tabular*}',
    '\\par\\endgroup'
  )
}

website_panel <- results[panel == 'A']
media_panel <- results[panel == 'B']
trade_panel <- results[panel == 'C']
point_panel <- results[panel == 'D']

raw_latex_lines <- c(
  panel_table_lines(
    website_panel,
    'Panel A: Website disclosure',
    latex_row('', website_panel$outcome),
    c('State-Border FE', 'Year FE')
  ),
  '',
  '\\vspace{0.75em}',
  '',
  panel_table_lines(
    media_panel,
    'Panel B: Media coverage',
    c(
      '    & \\multicolumn{2}{c}{Total Articles - 12mo}\\\\',
      '   \\cmidrule(lr){2-3}'
    ),
    c('Year-Month FE', 'Purpose FE', 'State-Border FE'),
    controls_label = 'County Controls',
    controls_values = c('No', 'Yes')
  ),
  '',
  '\\vspace{0.75em}',
  '',
  panel_table_lines(
    trade_panel,
    'Panel C: Secondary-market trade before maturity',
    latex_row('', c('Trade', 'Retail Trade', 'Inst. Trade')),
    c('Year FE', 'Purpose FE', 'State-Border FE', 'Rating FE'),
    controls_label = 'Bond and County Controls'
  ),
  '',
  '\\vspace{0.75em}',
  '',
  panel_table_lines(
    point_panel,
    'Panel D: Debt choice and aggregate yield spread',
    latex_row('', c('Pct UTGO', 'Wtd. Avg. Yield Spread')),
    'State-Border FE'
  )
)

table_note <- paste0(
  'This table re-estimates the border-state specifications reported in the paper. ',
  'Panel A reports fixed-effects Poisson estimates of website disclosure, Panel B ',
  'reports the border-state fixed-effects Poisson estimates from columns 3--4 of ',
  'the media-coverage table, and Panel C reports linear state-border fixed-effects ',
  'estimates for the three raw customer-trade-before-maturity outcomes, with ',
  'rating-category fixed effects. Panel D reports linear state-border fixed-effects ',
  'estimates for the 2017 point-in-time outcomes. Square brackets contain two-sided ',
  'p-values from null-imposed wild-cluster score tests by state using Rademacher ',
  'weights. Because each panel contains at most 15 state clusters, the tests ',
  'enumerate all distinct two-sided sign assignments. Controls and fixed effects ',
  'from the paper specifications are included but suppressed. Significance levels ',
  'are denoted by $^{***}p<0.01$, $^{**}p<0.05$, and $^{*}p<0.10$.'
)

processed_latex_lines <- c(
  '\\clearpage',
  '\\begin{table}[H]\\centering',
  '\\def\\sym#1{\\ifmmode^{#1}\\else\\(^{#1}\\)\\fi}',
  '\\begingroup',
  '\\caption{\\textbf{Wild Cluster Bootstrap Inference for Border-State Tests}}',
  '\\label{tab:wild_cluster_bootstrap_border_tests}',
  paste0(
    '\\parbox{\\textwidth}{', table_note, '}'
  ),
  '\\endgroup',
  '\\end{table}',
  '',
  '\\input{tables/clean/raw/wild_cluster_bootstrap_border_tests}'
)

writeLines(raw_latex_lines, output_tex)
writeLines(processed_latex_lines, output_processed_tex)
