# 10: Wild-cluster bootstrap inference (Online Appendix)
#
# This script reproduces the current website, border-state media-coverage, 2017
# point-in-time, and secondary-market trading border specifications. Inference is
# based on a null-imposed wild-cluster score bootstrap by state. With at most 15
# states in these samples, all distinct two-sided Rademacher sign assignments are
# enumerated rather than simulated. Controls and fixed effects are included in
# estimation but suppressed in the output table.

rm(list = ls())

required_packages <- c('data.table', 'DescTools', 'fixest')
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))
]
if (length(missing_packages) > 0L) {
  stop(
    'Install the following R packages before running this script: ',
    paste(missing_packages, collapse = ', ')
  )
}

library(data.table)
library(fixest)

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
output_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')
processed_output_dir <- file.path(root, 'Code/R/Clean/output/processed')
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_output_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, 'Code/R/Clean/00_tax_privilege_definitions.R'))
source(file.path(root, 'Code/R/Clean/00_border_pair_definitions.R'))

output_tex <- file.path(output_dir, 'wild_cluster_bootstrap_border_tests.tex')
output_processed_tex <- file.path(
  processed_output_dir,
  'wild_cluster_bootstrap_border_tests.tex'
)

treatment <- 'city_go_vote'
poisson_glm_iter <- 100
poisson_fixef_iter <- 50000


# ==============================================================================
# Wild-cluster score bootstrap helpers
# ==============================================================================

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


fit_paper_model <- function(data, outcome, controls, fixed_effects, family,
                            baseline_cluster) {
  rhs <- paste(c(treatment, controls), collapse = ' + ')
  model_formula <- as.formula(sprintf(
    '%s ~ %s | %s', outcome, rhs, paste(fixed_effects, collapse = ' + ')
  ))

  if (family == 'poisson') {
    return(fixest::fepois(
      model_formula,
      data = data,
      vcov = fixest::vcov_cluster(as.formula(paste0('~', baseline_cluster))),
      glm.iter = poisson_glm_iter,
      fixef.iter = poisson_fixef_iter
    ))
  }

  fixest::feols(
    model_formula,
    data = data,
    vcov = fixest::vcov_cluster(as.formula(paste0('~', baseline_cluster)))
  )
}


wild_cluster_score_test <- function(model, data, outcome, controls,
                                    fixed_effects, family, cluster = 'state') {
  used_rows <- fixest::obs(model)
  model_data <- copy(data[used_rows])

  restricted_formula <- as.formula(sprintf(
    '%s ~ %s | %s',
    outcome,
    paste(controls, collapse = ' + '),
    paste(fixed_effects, collapse = ' + ')
  ))
  auxiliary_formula <- as.formula(sprintf(
    '%s ~ %s | %s',
    treatment,
    paste(controls, collapse = ' + '),
    paste(fixed_effects, collapse = ' + ')
  ))

  if (family == 'poisson') {
    restricted_model <- fixest::fepois(
      restricted_formula,
      data = model_data,
      glm.iter = poisson_glm_iter,
      fixef.iter = poisson_fixef_iter
    )
    if (nobs(restricted_model) != nrow(model_data)) {
      stop('The restricted PPML model changed the unrestricted estimation sample.')
    }

    null_mean <- as.numeric(fitted(restricted_model))
    auxiliary_model <- fixest::feols(
      auxiliary_formula,
      data = model_data,
      weights = null_mean
    )
    treatment_residual <- as.numeric(residuals(auxiliary_model))
    score_observation <- treatment_residual *
      (model_data[[outcome]] - null_mean)
  } else {
    restricted_model <- fixest::feols(restricted_formula, data = model_data)
    if (nobs(restricted_model) != nrow(model_data)) {
      stop('The restricted linear model changed the unrestricted estimation sample.')
    }

    auxiliary_model <- fixest::feols(auxiliary_formula, data = model_data)
    treatment_residual <- as.numeric(residuals(auxiliary_model))
    score_observation <- treatment_residual * as.numeric(residuals(restricted_model))
  }

  if (length(score_observation) != nrow(model_data) || any(!is.finite(score_observation))) {
    stop('Could not construct finite observation-level scores for ', outcome, '.')
  }

  cluster_id <- as.character(model_data[[cluster]])
  if (anyNA(cluster_id)) {
    stop('The bootstrap cluster variable contains missing values.')
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


estimate_specification <- function(data, panel, column, outcome_label, outcome,
                                   controls, fixed_effects, family,
                                   baseline_cluster) {
  model <- fit_paper_model(
    data = data,
    outcome = outcome,
    controls = controls,
    fixed_effects = fixed_effects,
    family = family,
    baseline_cluster = baseline_cluster
  )
  bootstrap <- wild_cluster_score_test(
    model = model,
    data = data,
    outcome = outcome,
    controls = controls,
    fixed_effects = fixed_effects,
    family = family,
    cluster = 'state'
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


# ==============================================================================
# Panel A: Website disclosure
# ==============================================================================

website_data <- fread(file.path(
  root,
  'Data/Clean_Intermediate/Websites/border_state_website_data_with_recovered.csv'
))
website_data <- filter_paper_border_pairs(website_data)
website_data <- website_data[
  !is.na(total_subs) &
    !is.na(city_go_vote) &
    total_subs == 50 &
    seed_issuer != 'BONDUEL WIS'
]
website_data[, year_int := as.integer(year)]
website_data[, state_year := interaction(state, year_int, drop = TRUE)]
website_data[, issuer_key := paste(
  sprintf('%.0f', round(as.numeric(seed_issuer_id) * 10)),
  toupper(trimws(state)),
  toupper(gsub('\\s+', ' ', trimws(seed_issuer))),
  sep = '|'
)]

debt_panel <- fread(
  file.path(
    root,
    'Data/Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv'
  ),
  select = c('issuer_key', 'year', 'ln_1p_total_outstanding_debt')
)
debt_panel[, year_int := as.integer(year) + 1L]
debt_panel[, year := NULL]
setnames(debt_panel, 'ln_1p_total_outstanding_debt', 'ln_1p_outstanding_debt_lag1')
if (debt_panel[, anyDuplicated(paste(issuer_key, year_int))] > 0L) {
  stop('The outstanding-debt panel has duplicate issuer-year keys.')
}
website_data <- debt_panel[website_data, on = .(issuer_key, year_int)]
if (website_data[, anyNA(ln_1p_outstanding_debt_lag1)]) {
  stop('The outstanding-debt panel is missing website issuer-years.')
}

state_policy <- fread(file.path(
  root,
  'Data/State Monitoring Policy/state_enforcement_adoption_years.csv'
))
state_policy[, AdoptionYear := fifelse(AdoptionYear == 'before_sample', '2009', AdoptionYear)]
state_policy[, AdoptionYear := as.integer(AdoptionYear)]
setnames(state_policy, 'Abbreviation', 'state')
website_data <- state_policy[website_data, on = .(state)]
website_data[, state_monitor := as.integer(
  !is.na(AdoptionYear) & year_int >= AdoptionYear
)]
website_data[, group := factor(group)]
website_data[, year := factor(year_int)]

# Use observed order statistics for the count-variable caps so winsorization
# matches the main website analysis and preserves integer-valued counts.
for (variable in c(
  'fiscal_url', 'fiscal_count', 'bond_url', 'bond_count', 'financial_pdf_urls'
)) {
  website_data[, (variable) := DescTools::Winsorize(
    get(variable),
    val = quantile(
      get(variable),
      probs = c(0.01, 0.99),
      na.rm = TRUE,
      type = 1
    )
  )]
}

website_controls <- c(
  'ln_1p_outstanding_debt_lag1', 'state_monitor',
  'ln_gdp', 'ln_pop', 'ln_pers_inc'
)
website_outcomes <- data.table(
  column = 1:5,
  outcome = c(
    'Bond URLs', 'Bond Count', 'Fiscal URLs', 'Fiscal Count', 'Financial Docs'
  ),
  variable = c(
    'bond_url', 'bond_count', 'fiscal_url', 'fiscal_count', 'financial_pdf_urls'
  )
)

website_results <- rbindlist(lapply(seq_len(nrow(website_outcomes)), function(i) {
  estimate_specification(
    data = website_data,
    panel = 'A',
    column = website_outcomes$column[i],
    outcome_label = website_outcomes$outcome[i],
    outcome = website_outcomes$variable[i],
    controls = website_controls,
    fixed_effects = c('group', 'year'),
    family = 'poisson',
    baseline_cluster = 'state_year'
  )
}))


# ==============================================================================
# Panel B: RavenPack media coverage, border-state columns (3)--(4)
# ==============================================================================

media_data <- fread(file.path(
  root,
  paste0(
    'Data/Clean_Intermediate/Border States/',
    'Border Matches RP Issuance Lvl Expanded Set Buffer 100000.csv'
  )
))
media_data <- media_data[!is.na(ln_employment)]
setorder(media_data, seed_issuer_id, issuance_year_month_id)
media_data[, lag_issuance_ym_id := shift(issuance_year_month_id), by = seed_issuer_id]
media_data[, issuance_gap := issuance_year_month_id - lag_issuance_ym_id]
media_data[, bond_prior_12 := fifelse(
  !is.na(issuance_gap) & issuance_gap <= 12,
  1,
  0
)]
media_data <- filter_paper_border_pairs(media_data)
media_data[, log_sources := log1p(unique_sources_12)]

# Match the media table's outcome definition: calculate the empirical 1st and
# 99th percentile caps in the full media analysis sample, then apply those same
# caps to the border-state sample. The RI treatment recode and the employment
# and analysis-sample screens mirror 02_media_coverage.R; the issuer merge in that
# script adds labels only and does not affect the percentile calculation.
media_cap_data <- fread(file.path(
  root,
  'Data/Clean_Intermediate/News/Issuance_Lvl_News_With_Lagged_News.csv'
))
media_cap_data[state == 'RI', city_go_vote := NA_real_]
media_cap_data <- media_cap_data[
  !is.na(city_go_vote) &
    !is.na(ln_employment) &
    go_unlim_bond_issuance == 1 &
    rolling_sum_monthly_article_count_12 > 0
]
media_article_caps <- quantile(
  media_cap_data$total_rp_articles_12_0,
  probs = c(0.01, 0.99),
  na.rm = TRUE,
  type = 1
)
media_data[, total_articles_12_0_win := DescTools::Winsorize(
  total_rp_articles_12_0,
  val = media_article_caps
)]
media_data[, state_year := interaction(state, year, drop = TRUE)]
media_data <- media_data[
  go_unlim_bond_issuance == 1 &
    rolling_sum_monthly_article_count_12 > 0
]

# The paper's two columns are estimated separately. Do not impose the full-
# controls complete-case screen on the no-demographics column.

media_controls_no_demographics <- c(
  'bond_prior_12', 'log_sources', 'ln_amount'
)
media_controls_demographics <- c(
  media_controls_no_demographics, 'ln_gdp', 'ln_pop', 'ln_pers_inc'
)

media_results <- rbindlist(list(
  estimate_specification(
    data = media_data,
    panel = 'B',
    column = 1L,
    outcome_label = 'No demographics',
    outcome = 'total_articles_12_0_win',
    controls = media_controls_no_demographics,
    fixed_effects = c('issuance_year_month_id', 'group', 'purp_broad'),
    family = 'poisson',
    baseline_cluster = 'state_year'
  ),
  estimate_specification(
    data = media_data,
    panel = 'B',
    column = 2L,
    outcome_label = 'Demographics',
    outcome = 'total_articles_12_0_win',
    controls = media_controls_demographics,
    fixed_effects = c('issuance_year_month_id', 'group', 'purp_broad'),
    family = 'poisson',
    baseline_cluster = 'state_year'
  )
))


# ==============================================================================
# Panel D: 2017 point-in-time fraction UTGO and aggregate yield
# ==============================================================================

point_data <- fread(file.path(
  root,
  paste0(
    'Data/Clean_Intermediate/Census COG Finance/processed/',
    'census_mergent_debt_cross_section_2017_border_sample.csv'
  )
))
point_data[, fips := as.character(fips)]
if ('nh_city' %in% names(point_data)) {
  point_data <- point_data[!(state == 'NH' & nh_city == 0)]
} else {
  point_data <- point_data[!(state == 'NH' & government_type_label == 'township')]
}
point_data <- point_data[!is.na(city_go_vote)]
add_low_state_tax_privilege(point_data)
point_data[, frac_utgo_outstanding :=
  mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
point_data[mergent_go_revenue_outstanding_debt <= 0, frac_utgo_outstanding := NA_real_]
point_data[, ln_census_population := log(census_population)]
point_data[, state_year := interaction(state, year, drop = TRUE)]

point_data <- filter_debt_yield_border_pairs(point_data, 'border_group')
point_data <- point_data[
  !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) &
    insample == 1 &
    !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]
identifying_groups <- point_data[
  , .(vote_values = uniqueN(city_go_vote)),
  by = border_group
][vote_values == 2, border_group]
point_data <- point_data[border_group %in% identifying_groups]

point_common_controls <- c(
  'ln_gdp', 'ln_census_population', 'ln_pers_inc',
  'ln_1p_county_nonmunicipal_total_debt', 'state_go_vote',
  'low_state_tax_privilege'
)
point_yield_controls <- c(
  'ln_gdp', 'ln_census_population', 'ln_pers_inc',
  'ln_1p_county_nonmunicipal_total_debt',
  'mergent_wavg_rating_go_revenue_zero_unrated',
  'mergent_wavg_original_maturity_years_go_revenue',
  'mergent_wavg_insured_go_revenue',
  'mergent_wavg_sinkable_go_revenue',
  'state_go_vote', 'low_state_tax_privilege'
)

point_results <- rbindlist(list(
  estimate_specification(
    data = point_data,
    panel = 'D',
    column = 1L,
    outcome_label = 'Pct UTGO',
    outcome = 'frac_utgo_outstanding',
    controls = point_common_controls,
    fixed_effects = 'border_group',
    family = 'linear',
    baseline_cluster = 'state_year'
  ),
  estimate_specification(
    data = point_data,
    panel = 'D',
    column = 2L,
    outcome_label = 'Wtd. Avg. Yield Spread',
    outcome = 'mergent_wavg_yield_spread_go_revenue',
    controls = point_yield_controls,
    fixed_effects = 'border_group',
    family = 'linear',
    baseline_cluster = 'state_year'
  )
))


# ==============================================================================
# Panel C: Secondary-market trading before maturity
# ==============================================================================

trade_data <- fread(file.path(
  root,
  paste0(
    'Data/Clean_Intermediate/MSRB/Processed/',
    'Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv'
  )
))
trade_data[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
trade_data[state == 'MO', city_rev_vote := 1]
trade_data[state == 'RI', city_go_vote := NA_real_]
trade_data <- trade_data[
  city == 1 & !is.na(city_go_vote) & go_unlim == 1 & !is.na(callable)
]
add_low_state_tax_privilege(trade_data)
trade_data[, disclosure_control := disclosed_before_maturity]

required_trade_fields <- c(
  'traded_before_maturity_raw',
  'retail_traded_before_maturity_raw',
  'institutional_traded_before_maturity_raw',
  'rating_fe'
)
missing_trade_fields <- setdiff(required_trade_fields, names(trade_data))
if (length(missing_trade_fields) > 0L) {
  stop('Missing official trade fields: ', paste(missing_trade_fields, collapse = ', '))
}
if (trade_data[, anyNA(rating_fe)]) {
  stop('rating_fe contains missing values in the trade-before-maturity data.')
}

trade_border_matches <- fread(file.path(
  root,
  paste0(
    'Data/Clean_Intermediate/Border States/',
    'Border Matches All Mergent Data Expanded Set Buffer 100000.csv'
  )
))
trade_border_matches <- filter_paper_border_pairs(trade_border_matches)
trade_border_matches <- trade_border_matches[go_unlim == 1]
trade_border_matches <- unique(
  trade_border_matches[, .(state, seed_issuer, group)]
)
trade_border_data <- trade_data[
  trade_border_matches,
  on = .(state, seed_issuer)
]
trade_border_data <- trade_border_data[!is.na(cusip) & year > 2004]
trade_border_data[, state_year := interaction(state, year, drop = TRUE)]

trade_controls <- c(
  'low_state_tax_privilege', 'disclosure_control',
  'ln_amount', 'ln_maturity_mths', 'callable', 'sinkable', 'insured',
  'ln_gdp', 'ln_pop', 'ln_pers_inc'
)
trade_outcomes <- data.table(
  column = 1:3,
  outcome = c('Trade', 'Retail Trade', 'Inst. Trade'),
  variable = c(
    'traded_before_maturity_raw',
    'retail_traded_before_maturity_raw',
    'institutional_traded_before_maturity_raw'
  )
)

trade_results <- rbindlist(lapply(seq_len(nrow(trade_outcomes)), function(i) {
  estimate_specification(
    data = trade_border_data,
    panel = 'C',
    column = trade_outcomes$column[i],
    outcome_label = trade_outcomes$outcome[i],
    outcome = trade_outcomes$variable[i],
    controls = trade_controls,
    fixed_effects = c('year', 'purp_broad', 'group', 'rating_fe'),
    family = 'linear',
    baseline_cluster = 'state_year'
  )
}))


# ==============================================================================
# Results and compact four-panel LaTeX table
# ==============================================================================

results <- rbindlist(
  list(website_results, media_results, point_results, trade_results),
  fill = TRUE
)
setorder(results, panel, column)
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
