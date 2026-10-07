# Exploratory only: website-disclosure heterogeneity in the border-state
# trade-before-maturity regressions.
#
# This script deliberately does not source or modify an official analysis script.
# It reproduces the media-coverage heterogeneity procedure in the current clean
# trade-before-maturity analysis:
#   1. define High disclosure as measure > pooled median;
#   2. interact city_go_vote with that High indicator;
#   3. retain the main bond controls, county controls, year FE, and purpose FE.
# For the border sample, it also retains the paper's state-border FE and
# state-year clustering, exactly as in the current clean border specification.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

project_dir <- "/Users/kmunevar/Dropbox/Voting on Bonds"
output_dir <- file.path(project_dir, "Results", "Website Disclosure Heterogeneity")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(project_dir, "Code", "R", "Clean", "border_pair_definitions.R"))

# -----------------------------------------------------------------------------
# Rebuild the current clean border-state trade sample without writing elsewhere.
# -----------------------------------------------------------------------------

trade_file <- file.path(
  project_dir,
  "Data", "Clean_Intermediate", "MSRB", "Processed",
  "Bond_Level_Any_Trade_Before_Maturity_with_CD_Data.csv"
)

trade_columns <- c(
  "seed_issuer_id", "seed_issuer", "state", "cusip", "year", "city",
  "city_go_vote", "go_unlim", "callable", "traded_before_maturity",
  "retail_traded_before_maturity", "institutional_traded_before_maturity",
  "disclosed_before_maturity", "ln_amount", "ln_maturity_mths", "sinkable",
  "insured", "rating_num", "ln_gdp", "ln_pop", "ln_pers_inc", "purp_broad"
)

trade_data <- fread(trade_file, select = trade_columns)
trade_data[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
trade_data[state == "RI", city_go_vote := NA_real_]
trade_data <- trade_data[
  city == 1 & !is.na(city_go_vote) & go_unlim == 1 & !is.na(callable)
]

border_file <- file.path(
  project_dir,
  "Data", "Clean_Intermediate", "Border States",
  "Border Matches All Mergent Data Expanded Set Buffer 100000.csv"
)

border_map <- fread(border_file, select = c("state", "seed_issuer", "group", "go_unlim"))
border_map <- filter_paper_border_pairs(border_map)
border_map <- border_map[go_unlim == 1]
border_map <- unique(border_map[, .(state, seed_issuer, group)])

border_data <- trade_data[border_map, on = .(state, seed_issuer)]
border_data <- border_data[!is.na(cusip)]
border_data[, state_year := interaction(state, year, drop = TRUE)]
assert_paper_border_pairs(border_data)

# -----------------------------------------------------------------------------
# Attach annual website measures using the same issuer-year match as the clean
# script. These are the five measures reported in the main website table.
# -----------------------------------------------------------------------------

website_measures <- c(
  "bond_count", "bond_url", "fiscal_count", "fiscal_url",
  "financial_pdf_urls"
)

website_file <- file.path(
  project_dir,
  "Data", "Clean_Intermediate", "Websites",
  "border_state_website_data_with_recovered.csv"
)

website_data <- fread(
  website_file,
  select = c(
    "seed_issuer_id", "seed_issuer", "year", "total_subs",
    website_measures
  )
)
website_data[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
website_data <- website_data[total_subs == 50 & !is.na(seed_issuer_id)]

website_key <- c("seed_issuer_id", "seed_issuer", "year")
duplicate_check <- website_data[, .N, by = website_key][N > 1]
if (nrow(duplicate_check) > 0L) {
  stop("Website data have duplicate issuer-year keys after the total_subs filter.")
}

# Match the media procedure exactly: the cutoff is computed in the disclosure
# source before merging to the regression sample, and High means strictly above
# the pooled median (not at-or-above).
cutoff_table <- rbindlist(lapply(website_measures, function(measure) {
  cutoff <- median(website_data[[measure]], na.rm = TRUE)
  high_name <- paste0("high_", measure)
  website_data[, (high_name) := fifelse(
    is.na(get(measure)), NA_integer_, as.integer(get(measure) > cutoff)
  )]
  data.table(
    measure = measure,
    pooled_median = cutoff,
    website_city_years = sum(!is.na(website_data[[measure]])),
    share_high_website_city_years = mean(website_data[[high_name]], na.rm = TRUE)
  )
}))

website_join_columns <- c(website_key, website_measures, paste0("high_", website_measures))
border_data <- website_data[, ..website_join_columns][
  border_data,
  on = .(seed_issuer_id, seed_issuer, year)
]

# -----------------------------------------------------------------------------
# Exact media-style interaction regressions.
# -----------------------------------------------------------------------------

outcomes <- c(
  traded_before_maturity = "Trade",
  retail_traded_before_maturity = "Retail Trade",
  institutional_traded_before_maturity = "Institutional Trade"
)

controls <- paste(
  "disclosed_before_maturity + ln_amount + ln_maturity_mths +",
  "callable + sinkable + insured + rating_num + ln_gdp + ln_pop + ln_pers_inc"
)

linear_combination <- function(model, terms) {
  beta <- coef(model)
  variance <- vcov(model)
  missing_terms <- setdiff(terms, names(beta))
  if (length(missing_terms) > 0L) {
    stop(sprintf("Missing coefficient(s): %s", paste(missing_terms, collapse = ", ")))
  }
  weights <- rep(0, length(beta))
  names(weights) <- names(beta)
  weights[terms] <- 1
  estimate <- sum(weights * beta)
  std_error <- sqrt(as.numeric(t(weights) %*% variance %*% weights))
  t_stat <- estimate / std_error
  df_t <- degrees_freedom(model, type = "t")
  p_value <- 2 * pt(abs(t_stat), df = df_t, lower.tail = FALSE)
  list(
    estimate = estimate,
    std_error = std_error,
    t_stat = t_stat,
    p_value = p_value
  )
}

models <- list()
results <- list()
sample_counts <- list()
result_index <- 0L

for (measure in website_measures) {
  high_name <- paste0("high_", measure)
  regression_data <- border_data[year > 2004 & !is.na(get(high_name))]

  sample_counts[[measure]] <- regression_data[, .(
    bonds = .N,
    issuers = uniqueN(paste(state, seed_issuer)),
    states = uniqueN(state),
    state_year_clusters = uniqueN(state_year),
    low_bonds = sum(get(high_name) == 0L),
    high_bonds = sum(get(high_name) == 1L),
    low_issuers = uniqueN(paste(state[get(high_name) == 0L], seed_issuer[get(high_name) == 0L])),
    high_issuers = uniqueN(paste(state[get(high_name) == 1L], seed_issuer[get(high_name) == 1L]))
  )][, measure := measure]

  for (outcome in names(outcomes)) {
    model_formula <- as.formula(sprintf(
      "%s ~ city_go_vote * %s + %s | year + purp_broad + group",
      outcome, high_name, controls
    ))

    model <- feols(
      model_formula,
      cluster = ~state_year,
      data = regression_data,
      notes = FALSE
    )
    models[[paste(measure, outcome, sep = "__")]] <- model

    interaction_candidates <- c(
      paste0("city_go_vote:", high_name),
      paste0(high_name, ":city_go_vote")
    )
    interaction_term <- intersect(interaction_candidates, names(coef(model)))
    if (length(interaction_term) != 1L) {
      stop(sprintf("Could not identify interaction coefficient for %s.", measure))
    }

    coefficient_table <- coeftable(model)
    low <- linear_combination(model, "city_go_vote")
    high <- linear_combination(model, c("city_go_vote", interaction_term))
    difference <- linear_combination(model, interaction_term)

    result_index <- result_index + 1L
    results[[result_index]] <- data.table(
      measure = measure,
      outcome = unname(outcomes[[outcome]]),
      pooled_median = cutoff_table$pooled_median[cutoff_table$measure == measure],
      n = nobs(model),
      vote_low = low$estimate,
      se_vote_low = low$std_error,
      p_vote_low = low$p_value,
      vote_high = high$estimate,
      se_vote_high = high$std_error,
      p_vote_high = high$p_value,
      high_minus_low = difference$estimate,
      se_high_minus_low = difference$std_error,
      p_high_minus_low = difference$p_value,
      stronger_in_high = difference$estimate > 0,
      adj_r2 = fitstat(model, "ar2")[[1]]
    )
  }
}

results <- rbindlist(results)
sample_counts <- rbindlist(sample_counts, use.names = TRUE)
setcolorder(sample_counts, c("measure", setdiff(names(sample_counts), "measure")))

# The bond-count regression should reproduce the existing clean exploratory table.
reproduction <- results[measure == "bond_count"]
expected_interactions <- c(
  "Trade" = -0.219,
  "Retail Trade" = -0.216,
  "Institutional Trade" = -0.140
)
reproduction[, existing_rounded_interaction := expected_interactions[outcome]]
reproduction[, reproduces_existing_table :=
  round(high_minus_low, 3) == existing_rounded_interaction]
if (!all(reproduction$reproduces_existing_table)) {
  warning("The bond-count interaction does not reproduce the existing clean table.")
}

fwrite(
  cutoff_table,
  file.path(output_dir, "website_disclosure_cutoffs.csv")
)
fwrite(
  sample_counts,
  file.path(output_dir, "website_disclosure_trade_sample_counts.csv")
)
fwrite(
  results,
  file.path(output_dir, "website_disclosure_trade_heterogeneity_results.csv")
)
fwrite(
  reproduction,
  file.path(output_dir, "bond_count_existing_table_reproduction.csv")
)

capture.output(
  lapply(models, summary),
  file = file.path(output_dir, "website_disclosure_trade_heterogeneity_model_summaries.txt")
)

cat("\nExact media-style website heterogeneity results\n")
print(results[, .(
  measure, outcome, n,
  vote_low = round(vote_low, 3),
  vote_high = round(vote_high, 3),
  high_minus_low = round(high_minus_low, 3),
  p_difference = round(p_high_minus_low, 4),
  stronger_in_high
)])

cat("\nOutputs written to:\n", output_dir, "\n", sep = "")
