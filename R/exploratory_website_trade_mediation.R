# Exploratory mediation decomposition for Vote -> website bond text ->
# trade before maturity. Official scripts and tables are not modified.
#
# The mediator is the same binary measure used in the website interaction table:
# High Bond Text = 1 when bond_count is above its pooled median. Because the
# pooled median is zero, this is an any-bond-text indicator.
#
# The mediator path is estimated once per issuer-year-state-border observation,
# avoiding mechanical replication of one website snapshot across multiple bonds.
# The outcome paths remain bond-level and use the exact controls/fixed effects in
# the existing website heterogeneity regression. Inference for decomposed effects
# uses a state-year cluster bootstrap.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

project_dir <- "/Users/kmunevar/Dropbox/Voting on Bonds"
heterogeneity_script <- file.path(
  project_dir, "Code", "R", "exploratory_website_disclosure_trade_heterogeneity.R"
)

# Reuse the already-audited exploratory sample construction. Suppress its printed
# regression summary; it only writes within the exploratory Results directory.
invisible(capture.output(source(heterogeneity_script, local = FALSE)))

output_dir <- file.path(project_dir, "Results", "Website Disclosure Mediation")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Samples and formulas
# -----------------------------------------------------------------------------

outcomes <- c(
  traded_before_maturity = "Trade",
  retail_traded_before_maturity = "Retail Trade",
  institutional_traded_before_maturity = "Institutional Trade"
)

outcome_controls <- paste(
  "disclosed_before_maturity + ln_amount + ln_maturity_mths +",
  "callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc"
)

required_outcome <- c(
  names(outcomes), "city_go_vote", "high_bond_count",
  "disclosed_before_maturity", "ln_amount", "ln_maturity_mths", "callable",
  "sinkable", "insured", "rating_num", "ln_gdp", "ln_pop", "ln_pers_inc",
  "year", "purp_broad", "group", "state_year", "state", "seed_issuer"
)

outcome_data <- border_data[
  year > 2004 & !is.na(high_bond_count)
]
outcome_data <- outcome_data[complete.cases(outcome_data[, ..required_outcome])]
outcome_data[, state_year_boot := as.character(state_year)]
outcome_data[, analysis_weight := 1]

# The mediator path uses a unique website observation. County controls, year FE,
# and state-border FE are shared with the outcome equation. Bond-level controls
# are intentionally excluded from the mediator equation because they vary within
# an issuer-year and are downstream of the city-year website snapshot.
mediator_data <- unique(outcome_data[, .(
  state, seed_issuer, year, group, state_year_boot,
  city_go_vote, high_bond_count, ln_gdp, ln_pop, ln_pers_inc
)])
bond_weights <- outcome_data[, .(
  bond_weight = .N
), by = .(state, seed_issuer, year, group, state_year_boot)]
mediator_data <- bond_weights[
  mediator_data,
  on = .(state, seed_issuer, year, group, state_year_boot)
]
mediator_data[, analysis_weight := 1]

mediator_formula <- high_bond_count ~ city_go_vote + ln_gdp + ln_pop + ln_pers_inc |
  year + group

total_formulas <- lapply(names(outcomes), function(outcome) {
  as.formula(sprintf(
    "%s ~ city_go_vote + %s | year + purp_broad + group",
    outcome, outcome_controls
  ))
})
names(total_formulas) <- names(outcomes)

conditional_formulas <- lapply(names(outcomes), function(outcome) {
  as.formula(sprintf(
    "%s ~ city_go_vote + high_bond_count + %s | year + purp_broad + group",
    outcome, outcome_controls
  ))
})
names(conditional_formulas) <- names(outcomes)

interaction_formulas <- lapply(names(outcomes), function(outcome) {
  as.formula(sprintf(
    "%s ~ city_go_vote * high_bond_count + %s | year + purp_broad + group",
    outcome, outcome_controls
  ))
})
names(interaction_formulas) <- names(outcomes)

coefficient_name <- function(model, candidates) {
  found <- intersect(candidates, names(coef(model)))
  if (length(found) != 1L) {
    stop(sprintf("Expected one coefficient among: %s", paste(candidates, collapse = ", ")))
  }
  found
}

weighted_mean <- function(x, w) {
  sum(x * w) / sum(w)
}

estimate_decomposition <- function(mediator_dt, outcome_dt, use_cluster_vcov = FALSE) {
  vcov_spec <- if (use_cluster_vcov) ~state_year_boot else "iid"

  mediator_model <- feols(
    mediator_formula,
    data = mediator_dt,
    weights = ~analysis_weight,
    vcov = vcov_spec,
    fixef.rm = "none",
    notes = FALSE
  )

  output <- list()
  fitted_models <- list(mediator = mediator_model)

  for (outcome in names(outcomes)) {
    total_model <- feols(
      total_formulas[[outcome]], data = outcome_dt,
      weights = ~analysis_weight, vcov = vcov_spec, fixef.rm = "none", notes = FALSE
    )
    conditional_model <- feols(
      conditional_formulas[[outcome]], data = outcome_dt,
      weights = ~analysis_weight, vcov = vcov_spec, fixef.rm = "none", notes = FALSE
    )
    interaction_model <- feols(
      interaction_formulas[[outcome]], data = outcome_dt,
      weights = ~analysis_weight, vcov = vcov_spec, fixef.rm = "none", notes = FALSE
    )

    interaction_term <- coefficient_name(
      interaction_model,
      c(
        "city_go_vote:high_bond_count",
        "high_bond_count:city_go_vote"
      )
    )

    # Counterfactual mediator means. The linear probability mediator model makes
    # their difference the a path, but explicit predictions make the natural
    # direct effects with treatment-mediator interaction transparent.
    a_path <- unname(coef(mediator_model)["city_go_vote"])
    # For the LPM mediator equation, M(0) equals the fitted value net of the
    # observed treatment contribution, and M(1)-M(0) equals the a path. Average
    # over the bond population using each unique mediator row's bond count. This
    # avoids extrapolating fixed-effect labels in bootstrap samples.
    mediator_0 <- fitted(mediator_model) - a_path * mediator_dt$city_go_vote
    target_weights <- mediator_dt$analysis_weight * mediator_dt$bond_weight
    mean_mediator_0 <- weighted_mean(mediator_0, target_weights)
    mean_mediator_1 <- mean_mediator_0 + a_path
    delta_mediator <- a_path

    total_vote <- unname(coef(total_model)["city_go_vote"])
    direct_no_interaction <- unname(coef(conditional_model)["city_go_vote"])
    b_no_interaction <- unname(coef(conditional_model)["high_bond_count"])
    indirect_no_interaction <- a_path * b_no_interaction

    direct_interaction <- unname(coef(interaction_model)["city_go_vote"])
    mediator_effect_control <- unname(coef(interaction_model)["high_bond_count"])
    interaction <- unname(coef(interaction_model)[interaction_term])

    # Linear-model natural effects with treatment-mediator interaction:
    # NIE(t) = E[M(1)-M(0)] * (beta_M + t * beta_TM)
    # NDE(t') = beta_T + beta_TM * E[M(t')]
    nie_control <- delta_mediator * mediator_effect_control
    nie_treated <- delta_mediator * (mediator_effect_control + interaction)
    nde_m0 <- direct_interaction + interaction * mean_mediator_0
    nde_m1 <- direct_interaction + interaction * mean_mediator_1
    model_total_1 <- nde_m0 + nie_treated
    model_total_2 <- nde_m1 + nie_control

    output[[outcome]] <- c(
      a_vote_to_high_text = a_path,
      mean_high_text_m0 = mean_mediator_0,
      mean_high_text_m1 = mean_mediator_1,
      delta_high_text = delta_mediator,
      reduced_form_total = total_vote,
      b_high_text_no_interaction = b_no_interaction,
      direct_no_interaction = direct_no_interaction,
      indirect_no_interaction = indirect_no_interaction,
      model_total_no_interaction = direct_no_interaction + indirect_no_interaction,
      vote_x_high_text = interaction,
      nie_when_vote_0 = nie_control,
      nie_when_vote_1 = nie_treated,
      nde_under_m0 = nde_m0,
      nde_under_m1 = nde_m1,
      model_total_interaction = mean(c(model_total_1, model_total_2)),
      decomposition_identity_gap = model_total_1 - model_total_2
    )

    fitted_models[[paste0(outcome, "_total")]] <- total_model
    fitted_models[[paste0(outcome, "_conditional")]] <- conditional_model
    fitted_models[[paste0(outcome, "_interaction")]] <- interaction_model
  }

  list(effects = output, models = fitted_models)
}

# -----------------------------------------------------------------------------
# Point estimates with the paper's state-year clustered covariance convention.
# -----------------------------------------------------------------------------

point <- estimate_decomposition(mediator_data, outcome_data, use_cluster_vcov = TRUE)

point_results <- rbindlist(lapply(names(point$effects), function(outcome) {
  data.table(
    outcome = unname(outcomes[[outcome]]),
    metric = names(point$effects[[outcome]]),
    estimate = as.numeric(point$effects[[outcome]])
  )
}))

# -----------------------------------------------------------------------------
# State-year cluster bootstrap. One draw weight is applied to all bonds and the
# corresponding unique issuer-year mediator observation in each selected cluster.
# -----------------------------------------------------------------------------

bootstrap_reps <- as.integer(Sys.getenv("MEDIATION_BOOT_REPS", unset = "499"))
if (is.na(bootstrap_reps) || bootstrap_reps < 99L) {
  stop("MEDIATION_BOOT_REPS must be an integer of at least 99.")
}

set.seed(20260721)
clusters <- sort(unique(outcome_data$state_year_boot))
bootstrap_results <- vector("list", bootstrap_reps)

for (bootstrap_index in seq_len(bootstrap_reps)) {
  sampled_clusters <- sample(clusters, length(clusters), replace = TRUE)
  cluster_weights <- table(sampled_clusters)

  mediator_boot <- copy(mediator_data)
  outcome_boot <- copy(outcome_data)
  mediator_boot[, analysis_weight := as.numeric(cluster_weights[state_year_boot])]
  outcome_boot[, analysis_weight := as.numeric(cluster_weights[state_year_boot])]
  mediator_boot[is.na(analysis_weight), analysis_weight := 0]
  outcome_boot[is.na(analysis_weight), analysis_weight := 0]
  mediator_boot <- mediator_boot[analysis_weight > 0]
  outcome_boot <- outcome_boot[analysis_weight > 0]

  boot_fit <- tryCatch(
    estimate_decomposition(mediator_boot, outcome_boot, use_cluster_vcov = FALSE),
    error = function(error) NULL
  )
  if (is.null(boot_fit)) {
    next
  }

  bootstrap_results[[bootstrap_index]] <- rbindlist(lapply(names(boot_fit$effects), function(outcome) {
    data.table(
      bootstrap_index = bootstrap_index,
      outcome = unname(outcomes[[outcome]]),
      metric = names(boot_fit$effects[[outcome]]),
      bootstrap_estimate = as.numeric(boot_fit$effects[[outcome]])
    )
  }))
}

bootstrap_results <- rbindlist(bootstrap_results, use.names = TRUE, fill = TRUE)
successful_reps <- uniqueN(bootstrap_results$bootstrap_index)
if (successful_reps < 0.9 * bootstrap_reps) {
  warning(sprintf(
    "Only %s of %s bootstrap draws succeeded.", successful_reps, bootstrap_reps
  ))
}

bootstrap_summary <- bootstrap_results[, {
  estimates <- bootstrap_estimate[is.finite(bootstrap_estimate)]
  lower_tail <- (sum(estimates <= 0) + 1) / (length(estimates) + 1)
  upper_tail <- (sum(estimates >= 0) + 1) / (length(estimates) + 1)
  .(
    bootstrap_reps = length(estimates),
    bootstrap_se = sd(estimates),
    ci_95_low = quantile(estimates, 0.025, names = FALSE),
    ci_95_high = quantile(estimates, 0.975, names = FALSE),
    bootstrap_p = min(1, 2 * min(lower_tail, upper_tail))
  )
}, by = .(outcome, metric)]

final_results <- bootstrap_summary[
  point_results,
  on = .(outcome, metric)
]
setcolorder(
  final_results,
  c(
    "outcome", "metric", "estimate", "bootstrap_se", "ci_95_low",
    "ci_95_high", "bootstrap_p", "bootstrap_reps"
  )
)

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

sample_support <- outcome_data[, .(
  bonds = .N,
  issuers = uniqueN(paste(state, seed_issuer)),
  issuer_years = uniqueN(paste(state, seed_issuer, year, group))
), by = .(city_go_vote, high_bond_count)][order(city_go_vote, high_bond_count)]

fwrite(
  final_results,
  file.path(output_dir, "website_trade_mediation_effects.csv")
)
fwrite(
  bootstrap_results,
  file.path(output_dir, "website_trade_mediation_bootstrap_draws.csv")
)
fwrite(
  sample_support,
  file.path(output_dir, "website_trade_mediation_support.csv")
)

capture.output(
  lapply(point$models, summary),
  file = file.path(output_dir, "website_trade_mediation_model_summaries.txt")
)

display_metrics <- c(
  "a_vote_to_high_text",
  "reduced_form_total",
  "indirect_no_interaction",
  "direct_no_interaction",
  "nie_when_vote_0",
  "nie_when_vote_1",
  "nde_under_m0",
  "nde_under_m1",
  "model_total_interaction"
)

display <- final_results[metric %chin% display_metrics]
display[, metric_order := match(metric, display_metrics)]
setorder(display, outcome, metric_order)

cat("\nWebsite-disclosure mediation decomposition\n")
cat(sprintf(
  "Outcome bonds: %s; mediator issuer-years: %s; state-year clusters: %s\n",
  format(nrow(outcome_data), big.mark = ","),
  format(nrow(mediator_data), big.mark = ","),
  uniqueN(outcome_data$state_year_boot)
))
cat(sprintf("Successful cluster bootstrap draws: %s/%s\n\n", successful_reps, bootstrap_reps))
print(display[, .(
  outcome,
  metric,
  estimate = round(estimate, 4),
  ci_95 = sprintf("[%.4f, %.4f]", ci_95_low, ci_95_high),
  p = round(bootstrap_p, 4)
)])

cat("\nOutputs written to:\n", output_dir, "\n", sep = "")
