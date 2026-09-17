#!/usr/bin/env Rscript

# R2-01: Leave-one-out sensitivity analyses requested in the second-round review.
#
# Analyses:
#   1a. Website disclosure: omit one of the 14 state-border pairs at a time.
#   1b. Website disclosure: omit all pairs linked to one control state at a time.
#   2. Media coverage (full sample): omit one control state at a time.
#   3. Secondary-market retail trading (full sample): omit one control state.
#   4. Fraction UTGO (2017 point-in-time, combined treatment sample): omit one
#      control state at a time.
#   5. Total weighted-average yield spread (2017 point-in-time, full sample):
#      omit one control state at a time.
#
# The script mirrors the controlled specifications in the production scripts.
# It writes the response-ready summary table. Only the Vote coefficient is
# displayed.

required_packages <- c('data.table', 'fixest', 'DescTools', 'haven')
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop('Missing required R packages: ', paste(missing_packages, collapse = ', '))
}

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
  library(DescTools)
  library(haven)
})

find_project_root <- function() {
  file_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
  start <- if (length(file_arg) > 0L) {
    dirname(normalizePath(sub('^--file=', '', file_arg[[1L]]), mustWork = TRUE))
  } else {
    normalizePath(getwd(), mustWork = TRUE)
  }

  candidate <- start
  for (i in seq_len(8L)) {
    if (dir.exists(file.path(candidate, 'Code')) &&
        dir.exists(file.path(candidate, 'Data'))) {
      return(normalizePath(candidate, mustWork = TRUE))
    }
    parent <- dirname(candidate)
    if (identical(parent, candidate)) break
    candidate <- parent
  }
  stop('Could not locate the project root from: ', start)
}

root <- find_project_root()
output_dir <- file.path(root, 'Code', 'R', 'Clean', 'output', 'leave_one_out')
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, 'Code', 'R', 'Clean', '00_tax_privilege_definitions.R'))
source(file.path(root, 'Code', 'R', 'Clean', '00_border_pair_definitions.R'))

# These are the seven no-referendum states used as controls throughout the
# full-sample analyses. Keeping an explicit canonical list makes the requested
# exercise auditable and prevents sample-specific missingness from silently
# changing which states are tested.
control_states <- c('KY', 'MA', 'MS', 'NH', 'NJ', 'TN', 'WI')
state_names <- setNames(state.name, state.abb)
control_state_labels <- setNames(
  paste0(state_names[control_states], ' (', control_states, ')'),
  control_states
)

assert_control_states <- function(data, analysis_label) {
  observed <- sort(unique(data[city_go_vote == 0, as.character(state)]))
  missing <- setdiff(control_states, observed)
  unexpected <- setdiff(observed, control_states)
  if (length(missing) > 0L || length(unexpected) > 0L) {
    stop(
      analysis_label, ' has a different control-state set. Missing: ',
      paste(missing, collapse = ', '), '; unexpected: ',
      paste(unexpected, collapse = ', ')
    )
  }
  invisible(TRUE)
}

extract_vote_result <- function(
  model,
  analysis,
  outcome,
  outcome_short,
  omission_type,
  omitted_unit,
  omitted_label,
  baseline
) {
  coefficient_table <- fixest::coeftable(model)
  if (!'city_go_vote' %in% rownames(coefficient_table)) {
    stop('Vote coefficient is absent from ', analysis, ' / ', outcome)
  }
  vote_row <- coefficient_table['city_go_vote', ]
  estimate <- unname(vote_row[[1L]])
  std_error <- unname(vote_row[[2L]])
  statistic <- unname(vote_row[[3L]])
  p_value <- unname(vote_row[[4L]])

  data.table(
    analysis = analysis,
    outcome = outcome,
    outcome_short = outcome_short,
    omission_type = omission_type,
    omitted_unit = omitted_unit,
    omitted_label = omitted_label,
    baseline = baseline,
    estimate = estimate,
    std_error = std_error,
    statistic = statistic,
    p_value = p_value,
    conf_low = estimate - qnorm(0.975) * std_error,
    conf_high = estimate + qnorm(0.975) * std_error,
    n = as.integer(nobs(model)),
    status = 'ok'
  )
}

run_leave_one_out <- function(
  data,
  omit_units,
  omit_column,
  omit_labels,
  fit_model,
  analysis,
  outcome,
  outcome_short,
  omission_type
) {
  specifications <- c(NA_character_, omit_units)

  rbindlist(lapply(specifications, function(omitted) {
    is_baseline <- is.na(omitted)
    model_data <- if (is_baseline) {
      copy(data)
    } else {
      data[as.character(get(omit_column)) != omitted]
    }

    omitted_label <- if (is_baseline) {
      'None (baseline)'
    } else {
      unname(omit_labels[[omitted]])
    }

    tryCatch({
      model <- fit_model(model_data)
      extract_vote_result(
        model = model,
        analysis = analysis,
        outcome = outcome,
        outcome_short = outcome_short,
        omission_type = omission_type,
        omitted_unit = if (is_baseline) 'baseline' else omitted,
        omitted_label = omitted_label,
        baseline = is_baseline
      )
    }, error = function(error) {
      data.table(
        analysis = analysis,
        outcome = outcome,
        outcome_short = outcome_short,
        omission_type = omission_type,
        omitted_unit = if (is_baseline) 'baseline' else omitted,
        omitted_label = omitted_label,
        baseline = is_baseline,
        estimate = NA_real_, std_error = NA_real_, statistic = NA_real_,
        p_value = NA_real_, conf_low = NA_real_, conf_high = NA_real_,
        n = nrow(model_data), status = conditionMessage(error)
      )
    })
  }), use.names = TRUE, fill = TRUE)
}

stars <- function(p_value) {
  fifelse(
    is.na(p_value), '',
    fifelse(p_value < 0.01, '***', fifelse(p_value < 0.05, '**',
      fifelse(p_value < 0.10, '*', '')))
  )
}

format_coefficient <- function(estimate, p_value) {
  ifelse(
    is.na(estimate), '--',
    paste0(sprintf('%.3f', estimate), ifelse(nzchar(stars(p_value)),
      paste0('$^{', stars(p_value), '}$'), ''))
  )
}

escape_latex <- function(x) {
  x <- gsub('\\\\', '\\\\textbackslash{}', x)
  x <- gsub('([&%$#_{}])', '\\\\\\1', x, perl = TRUE)
  x
}

make_summary <- function(results) {
  successful <- results[status == 'ok']
  successful[, {
    baseline_estimate <- estimate[baseline == TRUE][[1L]]
    baseline_p <- p_value[baseline == TRUE][[1L]]
    loo_estimate <- estimate[baseline == FALSE]
    loo_p <- p_value[baseline == FALSE]
    loo_label <- omitted_label[baseline == FALSE]

    list(
      baseline_estimate = baseline_estimate,
      baseline_p = baseline_p,
      min_estimate = min(loo_estimate),
      max_estimate = max(loo_estimate),
      min_omission = loo_label[which.min(loo_estimate)],
      max_omission = loo_label[which.max(loo_estimate)],
      n_omissions = length(loo_estimate),
      n_same_sign = sum(sign(loo_estimate) == sign(baseline_estimate)),
      n_p_lt_10 = sum(loo_p < 0.10),
      n_p_lt_05 = sum(loo_p < 0.05),
      n_p_lt_01 = sum(loo_p < 0.01),
      max_p_value = max(loo_p),
      max_p_omission = loo_label[which.max(loo_p)]
    )
  }, by = .(analysis, outcome, outcome_short, omission_type)]
}

write_summary_table <- function(summary, raw_output_file, processed_output_file) {
  ordered <- copy(summary)
  ordered[, baseline_cell := format_coefficient(baseline_estimate, baseline_p)]
  ordered[, range_cell := sprintf('[%.3f, %.3f]', min_estimate, max_estimate)]
  ordered[, sign_cell := paste0(n_same_sign, '/', n_omissions)]
  ordered[, sig10_cell := paste0(n_p_lt_10, '/', n_omissions)]
  ordered[, sig05_cell := paste0(n_p_lt_05, '/', n_omissions)]
  ordered[, max_p_cell := fifelse(
    max_p_value < 0.001, '$<0.001$', sprintf('%.3f', max_p_value)
  )]

  body <- vapply(seq_len(nrow(ordered)), function(i) {
    row <- ordered[i]
    paste0(
      escape_latex(row$analysis), ' & ', escape_latex(row$outcome_short), ' & ',
      row$baseline_cell, ' & ', row$range_cell, ' & ', row$sign_cell, ' & ',
      row$sig10_cell, ' & ', row$sig05_cell, ' & ', row$max_p_cell, '\\\\'
    )
  }, character(1))

  raw_lines <- c(
    '\\begingroup',
    '\\centering',
    '\\small',
    '\\resizebox{\\textwidth}{!}{%',
    '\\begin{tabular}{llcccccc}',
    '\\toprule',
    paste0(
      'Analysis & Outcome & Baseline & LOO range & Same sign & $p<0.10$ & ',
      '$p<0.05$ & Max. $p$-value\\\\'
    ),
    '\\midrule',
    body,
    '\\bottomrule',
    '\\end{tabular}%',
    '}',
    '\\par\\endgroup'
  )

  note_text <- paste0(
    'This table summarizes the coefficient on \\textit{Vote} from the controlled ',
    'specification for each outcome. The website analyses separately omit one ',
    'state-border pair and all pairs linked to one represented control state at ',
    'a time; all other analyses omit one of the seven full-sample control states ',
    'at a time. LOO range is the minimum and maximum coefficient across omissions. ',
    'Same sign and significance columns report the number of omissions satisfying ',
    'each criterion. Max. $p$-value is the largest p-value across the leave-one-out ',
    'estimates. Standard errors retain the clustering used in the main tables. ',
    '$^{*}$, $^{**}$, and $^{***}$ indicate significance at the 10\\%, 5\\%, ',
    'and 1\\% levels.'
  )

  processed_lines <- c(
    '\\begin{table}[H]\\centering',
    '\\caption{\\textbf{Leave-one-out sensitivity summary}}',
    '\\label{tab:leave_one_out_summary}',
    paste0(
      '\\parbox{\\textwidth}{', note_text, '}'
    ),
    '\\end{table}',
    '\\input{tables/clean/raw/leave_one_out_summary}'
  )
  writeLines(raw_lines, raw_output_file)
  writeLines(processed_lines, processed_output_file)
}

# -----------------------------------------------------------------------------
# 1. Website disclosure: leave one state-border pair out
# -----------------------------------------------------------------------------

website <- fread(file.path(
  root, 'Data', 'Clean_Intermediate', 'Websites',
  'border_state_website_data_with_recovered.csv'
))
website <- filter_paper_border_pairs(website)
website[, state_year := interaction(state, year, drop = TRUE)]
website <- website[
  !is.na(total_subs) & !is.na(city_go_vote) & total_subs == 50 &
    seed_issuer != 'BONDUEL WIS'
]
website[, year_int := as.integer(year)]
website[, issuer_key := paste(
  sprintf('%.0f', round(as.numeric(seed_issuer_id) * 10)),
  toupper(trimws(state)),
  toupper(gsub('\\s+', ' ', trimws(seed_issuer))),
  sep = '|'
)]

website_debt <- fread(
  file.path(
    root, 'Data', 'Clean_Intermediate', 'Mergent', 'Outstanding Debt',
    'full_mergent_issuer_year_outstanding_debt.csv'
  ),
  select = c('issuer_key', 'year', 'total_outstanding_debt',
    'ln_1p_total_outstanding_debt')
)
website_debt[, year_int := as.integer(year) + 1L]
website_debt[, year := NULL]
setnames(
  website_debt,
  c('total_outstanding_debt', 'ln_1p_total_outstanding_debt'),
  c('total_outstanding_debt_lag1', 'ln_1p_outstanding_debt_lag1')
)
website <- website_debt[website, on = .(issuer_key, year_int)]
if (website[is.na(ln_1p_outstanding_debt_lag1), .N] > 0L) {
  stop('Website debt-panel merge left missing prior-year debt values.')
}

state_policy <- fread(file.path(
  root, 'Data', 'State Monitoring Policy',
  'state_enforcement_adoption_years.csv'
))
state_policy[AdoptionYear == 'before_sample', AdoptionYear := '2009']
state_policy[, AdoptionYear := as.numeric(AdoptionYear)]
setnames(state_policy, 'Abbreviation', 'state')
website <- state_policy[website, on = .(state)]
website[, state_monitor := as.integer(
  !is.na(AdoptionYear) & year_int >= AdoptionYear
)]

website_count_variables <- c(
  'fiscal_url', 'fiscal_count', 'bond_url', 'bond_count',
  'financial_pdf_urls'
)
for (variable in website_count_variables) {
  caps <- quantile(
    website[[variable]], probs = c(0.01, 0.99), na.rm = TRUE, type = 1
  )
  set(
    website,
    j = variable,
    value = DescTools::Winsorize(website[[variable]], val = caps)
  )
}

# Also identify the control state associated with each border pair. This permits
# a second website exercise that removes all pairs linked to a control state
# (for example, all five Tennessee pairs), directly matching the reviewer's
# motivating example while retaining the requested pair-by-pair exercise.
website_pair_control <- copy(border_pair_config[include_in_paper == 1L])
website_pair_control[, control_state := fifelse(
  state1 %chin% control_states, state1,
  fifelse(state2 %chin% control_states, state2, NA_character_)
)]
website_pair_control[, n_control_states :=
  as.integer(state1 %chin% control_states) + as.integer(state2 %chin% control_states)]
if (website_pair_control[n_control_states != 1L, .N] > 0L) {
  stop('Each paper border pair must contain exactly one canonical control state.')
}
website <- website_pair_control[, .(group, control_state)][
  website,
  on = .(group)
]
if (website[is.na(control_state), .N] > 0L) {
  stop('Some website observations could not be assigned to a control state.')
}
website_control_states <- control_states[
  control_states %chin% unique(website_pair_control$control_state)
]
website[, `:=`(group = as.factor(group), year = as.factor(year))]

website_outcomes <- data.table(
  outcome = c('bond_url', 'bond_count', 'fiscal_url', 'fiscal_count',
    'financial_pdf_urls'),
  outcome_label = c('Bond URLs', 'Bond Count', 'Fiscal URLs', 'Fiscal Count',
    'Financial Docs')
)
website_pair_labels <- setNames(
  gsub('Tennesee', 'Tennessee', paper_border_pairs, fixed = TRUE),
  paper_border_pairs
)

website_results <- rbindlist(lapply(seq_len(nrow(website_outcomes)), function(i) {
  dependent_variable <- website_outcomes$outcome[[i]]
  fit_website <- function(model_data) {
    fepois(
      as.formula(paste0(
        dependent_variable,
        ' ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ',
        'ln_gdp + ln_pop + ln_pers_inc | group + year'
      )),
      data = model_data,
      vcov = vcov_cluster(~state_year)
    )
  }
  run_leave_one_out(
    data = website,
    omit_units = paper_border_pairs,
    omit_column = 'group',
    omit_labels = website_pair_labels,
    fit_model = fit_website,
    analysis = 'Website disclosure: pair LOO',
    outcome = dependent_variable,
    outcome_short = website_outcomes$outcome_label[[i]],
    omission_type = 'State-border pair'
  )
}), use.names = TRUE, fill = TRUE)

website_state_results <- rbindlist(lapply(seq_len(nrow(website_outcomes)), function(i) {
  dependent_variable <- website_outcomes$outcome[[i]]
  fit_website <- function(model_data) {
    fepois(
      as.formula(paste0(
        dependent_variable,
        ' ~ city_go_vote + ln_1p_outstanding_debt_lag1 + state_monitor + ',
        'ln_gdp + ln_pop + ln_pers_inc | group + year'
      )),
      data = model_data,
      vcov = vcov_cluster(~state_year)
    )
  }
  run_leave_one_out(
    data = website,
    omit_units = website_control_states,
    omit_column = 'control_state',
    omit_labels = control_state_labels,
    fit_model = fit_website,
    analysis = 'Website disclosure: state LOO',
    outcome = dependent_variable,
    outcome_short = website_outcomes$outcome_label[[i]],
    omission_type = 'Control state and linked border pairs'
  )
}), use.names = TRUE, fill = TRUE)

# -----------------------------------------------------------------------------
# 2. Media coverage: full sample, leave one control state out
# -----------------------------------------------------------------------------

media <- fread(file.path(
  root, 'Data', 'Clean_Intermediate', 'News',
  'Issuance_Lvl_News_With_Lagged_News.csv'
))
media[state == 'MO', city_rev_vote := 1]
media[state == 'RI', city_go_vote := NA_real_]
media <- media[!is.na(city_go_vote) & !is.na(ln_employment)]
setorder(media, seed_issuer_id, issuance_year_month_id)
media[, lag_issuance_ym_id := shift(issuance_year_month_id, 1L),
  by = seed_issuer_id]
media[, diff := issuance_year_month_id - lag_issuance_ym_id]
media[, bond_prior_12 := as.integer(!is.na(diff) & diff <= 12)]
media[, log_sources := log1p(unique_sources_12)]

media_sample_filter <- media[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]
media_caps <- quantile(
  media_sample_filter$total_rp_articles_12_0,
  probs = c(0.01, 0.99), na.rm = TRUE, type = 1
)
media[, total_articles_12_0_win := DescTools::Winsorize(
  total_rp_articles_12_0, val = media_caps
)]
media_analysis <- media[
  go_unlim_bond_issuance == 1 & rolling_sum_monthly_article_count_12 > 0
]
assert_control_states(media_analysis, 'Media coverage')

fit_media <- function(model_data) {
  fepois(
    total_articles_12_0_win ~ city_go_vote + bond_prior_12 + log_sources +
      ln_amount + ln_gdp + ln_pop + ln_pers_inc |
      issuance_year_month_id + purp_broad,
    data = model_data,
    vcov = vcov_cluster(~state)
  )
}
media_results <- run_leave_one_out(
  data = media_analysis,
  omit_units = control_states,
  omit_column = 'state',
  omit_labels = control_state_labels,
  fit_model = fit_media,
  analysis = 'Media coverage',
  outcome = 'total_articles_12_0_win',
  outcome_short = 'Total Articles - 12mo',
  omission_type = 'Control state'
)

# -----------------------------------------------------------------------------
# 3. Secondary-market retail trade: full sample, leave one control state out
# -----------------------------------------------------------------------------

trade <- fread(file.path(
  root, 'Data', 'Clean_Intermediate', 'MSRB', 'Processed',
  'Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv'
))
trade[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
trade[state == 'MO', city_rev_vote := 1]
trade[state == 'RI', city_go_vote := NA_real_]
trade <- trade[
  city == 1 & !is.na(city_go_vote) & go_unlim == 1 & !is.na(callable)
]
add_low_state_tax_privilege(trade)

required_trade_columns <- c(
  'retail_traded_before_maturity_raw', 'rating_fe',
  'disclosed_before_maturity'
)
missing_trade_columns <- setdiff(required_trade_columns, names(trade))
if (length(missing_trade_columns) > 0L) {
  stop('Trade data are missing: ', paste(missing_trade_columns, collapse = ', '))
}
trade[, retail_traded_before_maturity := retail_traded_before_maturity_raw]
trade[, disclosure_control := disclosed_before_maturity]
trade_analysis <- trade[year > 2004 & !is.na(rating_fe)]
assert_control_states(trade_analysis, 'Secondary-market retail trade')

fit_trade <- function(model_data) {
  feols(
    retail_traded_before_maturity ~ city_go_vote + low_state_tax_privilege +
      disclosure_control + ln_amount + ln_maturity_mths + callable + sinkable +
      insured + ln_gdp + ln_pop + ln_pers_inc |
      year + purp_broad + rating_fe,
    data = model_data,
    vcov = vcov_cluster(~state)
  )
}
trade_results <- run_leave_one_out(
  data = trade_analysis,
  omit_units = control_states,
  omit_column = 'state',
  omit_labels = control_state_labels,
  fit_model = fit_trade,
  analysis = 'Secondary-market trading',
  outcome = 'retail_traded_before_maturity',
  outcome_short = 'Retail Trade',
  omission_type = 'Control state'
)

# -----------------------------------------------------------------------------
# 4-5. Fraction UTGO and total weighted-average yield spread, 2017 point-in-time
# -----------------------------------------------------------------------------

point <- fread(file.path(
  root, 'Data', 'Clean_Intermediate', 'Census COG Finance', 'processed',
  'census_mergent_debt_cross_section_2017.csv'
))
point[, fips := as.character(fips)]
if ('nh_city' %in% names(point)) {
  point <- point[!(state == 'NH' & nh_city == 0)]
} else {
  point <- point[!(state == 'NH' & government_type_label == 'township')]
}
point <- point[!is.na(city_go_vote)]
add_low_state_tax_privilege(point)
point[, frac_utgo_outstanding :=
  mergent_utgo_outstanding_debt / mergent_go_revenue_outstanding_debt]
point[mergent_go_revenue_outstanding_debt <= 0,
  frac_utgo_outstanding := NA_real_]
point[, ln_census_population := log(census_population)]

point <- point[
  insample == 1 &
    !is.na(ln_gdp) &
    !is.na(ln_census_population) &
    !is.na(ln_pers_inc) &
    !is.na(ln_1p_county_nonmunicipal_total_debt) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege) &
    !is.na(mergent_go_revenue_bonds_outstanding) &
    mergent_go_revenue_bonds_outstanding >= 2
]
assert_control_states(point, '2017 point-in-time sample')

fit_fraction_utgo <- function(model_data) {
  feols(
    frac_utgo_outstanding ~ city_go_vote + ln_gdp + ln_census_population +
      ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
      state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
    data = model_data,
    vcov = vcov_cluster(~state)
  )
}

fraction_utgo_results <- run_leave_one_out(
  data = point,
  omit_units = control_states,
  omit_column = 'state',
  omit_labels = control_state_labels,
  fit_model = fit_fraction_utgo,
  analysis = 'Debt substitution',
  outcome = 'frac_utgo_outstanding',
  outcome_short = 'Pct UTGO',
  omission_type = 'Control state'
)

yield_data <- copy(point)
yield_data[, wavg_rating := mergent_wavg_rating_go_revenue_zero_unrated]
yield_data[, wavg_original_maturity :=
  mergent_wavg_original_maturity_years_go_revenue]
yield_data[, `:=`(
  any_insured = mergent_any_insured_go_revenue,
  any_callable = mergent_any_callable_go_revenue,
  any_sinkable = mergent_any_sinkable_go_revenue
)]

fit_yield <- function(model_data) {
  feols(
    mergent_wavg_yield_spread_go_revenue ~ city_go_vote + ln_gdp +
      ln_census_population + ln_pers_inc +
      ln_1p_county_nonmunicipal_total_debt + wavg_rating +
      wavg_original_maturity + any_insured + any_callable + any_sinkable +
      glm_proactive + state_ltgo_allowed + state_go_vote +
      low_state_tax_privilege,
    data = model_data,
    vcov = vcov_cluster(~state)
  )
}

yield_results <- run_leave_one_out(
  data = yield_data,
  omit_units = control_states,
  omit_column = 'state',
  omit_labels = control_state_labels,
  fit_model = fit_yield,
  analysis = 'Aggregate borrowing cost',
  outcome = 'mergent_wavg_yield_spread_go_revenue',
  outcome_short = 'Wtd. Avg. Yield Spread',
  omission_type = 'Control state'
)

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------

all_results <- rbindlist(list(
  website_results,
  website_state_results,
  media_results,
  trade_results,
  fraction_utgo_results,
  yield_results
), use.names = TRUE, fill = TRUE)

summary_results <- make_summary(all_results)

write_summary_table(
  summary_results,
  file.path(output_dir, 'leave_one_out_summary_raw.tex'),
  file.path(output_dir, 'leave_one_out_summary_processed.tex')
)
