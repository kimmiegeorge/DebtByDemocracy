# Texas overlapping-ISD failure exposure: validation regressions
#
# This script estimates two diagnostic associations before using the new
# exposure to study city election timing or website disclosure:
#   1. Does an ISD's own prior failure predict its later bond failures?
#   2. Does a prior failure in a high-overlap ISD predict later city failures?
#
# The treatment is constructed in:
# Code/Python/Clean/TX_Election_Exposure/03_build_tx_isd_failure_exposure.py

library(data.table)
library(fixest)

# %% Set paths
project_dir <- normalizePath(getwd(), mustWork = TRUE)
exposure_dir <- file.path(project_dir, "Data", "Clean_Intermediate", "TX", "Election_Exposure")
results_dir <- file.path(project_dir, "Results", "TX ISD Overlap Failure Validation")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

# %% Load the two proposition-level diagnostic samples
isd <- fread(file.path(exposure_dir, "isd_proposition_failure_persistence_sample.csv"))
city <- fread(file.path(exposure_dir, "city_propositions_high_overlap_isd_failure_exposure.csv"))

# %% Keep actual pass/fail propositions and create common controls
isd <- isd[Result %in% c("Carried", "Defeated")]
city <- city[
  Result %in% c("Carried", "Defeated") &
    !is.na(seed_key) & seed_key != "" &
    !is.na(fips)
]
isd[, ln_amount := log(as.numeric(Amount) + 1)]
city[, ln_amount := log(as.numeric(Amount) + 1)]

# %% Define the primary 36-month high-overlap exposure
# Same-day failures are excluded during the Python construction.  Therefore
# each indicator only uses an earlier election date.
exposure_variable <- "prior_failure_any_36m"

# %% Validation 1: persistence in the same ISD
# ISD FE compare later propositions within the same district; year FE absorb
# statewide election-cycle changes. Standard errors are clustered by ISD.
isd_raw_rates <- isd[, .(
  propositions = .N,
  failure_rate = mean(failed)
), by = prior_failure_any_36m]

isd_persistence_model <- feols(
  failed ~ prior_failure_any_36m + ln_amount + i(Purpose) | isd_geoid + year,
  data = isd,
  cluster = ~isd_geoid
)

# %% Validation 2: spillover from a high-overlap ISD to a city proposition
# This is the direct shared-jurisdiction diagnostic. Only cities with a Census
# place match are included; city FE compare a city to itself over time.
city_raw_rates <- city[, .(
  propositions = .N,
  failure_rate = mean(failed)
), by = prior_failure_any_36m]

city_spillover_model <- feols(
  failed ~ prior_failure_any_36m + ln_amount + i(Purpose) | seed_key + year,
  data = city,
  cluster = ~fips
)

# %% Save a compact model output
extract_exposure_result <- function(model, test_name) {
  coefficients <- as.data.table(coeftable(model), keep.rownames = "term")
  estimate <- coefficients[term == exposure_variable]
  data.table(
    test = test_name,
    exposure = exposure_variable,
    estimate = estimate$Estimate,
    std_error = estimate$`Std. Error`,
    p_value = estimate$`Pr(>|t|)`,
    observations = nobs(model)
  )
}

model_results <- rbindlist(list(
  extract_exposure_result(isd_persistence_model, "Later failure by same ISD"),
  extract_exposure_result(city_spillover_model, "Later failure by high-overlap city")
))

fwrite(model_results, file.path(results_dir, "isd_overlap_failure_validation_models.csv"))
fwrite(isd_raw_rates, file.path(results_dir, "isd_persistence_raw_failure_rates.csv"))
fwrite(city_raw_rates, file.path(results_dir, "city_spillover_raw_failure_rates.csv"))

# %% Write a short, readable result note
rate_text <- function(rates, exposure) {
  rate <- rates[prior_failure_any_36m == exposure, failure_rate]
  if (length(rate) == 0L) return("no observations")
  sprintf("%.3f", rate)
}

note <- c(
  "# Texas overlapping-ISD failure validation",
  "",
  "Primary treatment: a defeated ISD proposition in the prior 36 months where the failed ISD covered at least 80 percent of the city's Census-place area in the applicable historical boundary vintage.",
  "",
  "## Same-ISD persistence",
  sprintf("- Raw later-proposition failure rates: %s without a prior ISD failure and %s with one.",
          rate_text(isd_raw_rates, 0L), rate_text(isd_raw_rates, 1L)),
  sprintf("- ISD and year FE association, with log amount and purpose: %.4f (SE %.4f; p = %.4f; N = %s).",
          model_results[1]$estimate, model_results[1]$std_error,
          model_results[1]$p_value, format(model_results[1]$observations, big.mark = ",")),
  "",
  "## City spillover validation",
  sprintf("- Raw city-proposition failure rates: %s without prior high-overlap ISD failure and %s with one.",
          rate_text(city_raw_rates, 0L), rate_text(city_raw_rates, 1L)),
  sprintf("- City and year FE association, with log amount and purpose: %.4f (SE %.4f; p = %.4f; N = %s).",
          model_results[2]$estimate, model_results[2]$std_error,
          model_results[2]$p_value, format(model_results[2]$observations, big.mark = ",")),
  "",
  "These are descriptive validation tests. The geographic treatment is an area-overlap proxy, not observed voter overlap."
)
writeLines(note, file.path(results_dir, "README.md"))

print(model_results)
print(isd_raw_rates)
print(city_raw_rates)
