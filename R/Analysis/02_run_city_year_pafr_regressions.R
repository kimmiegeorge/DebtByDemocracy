#!/usr/bin/env Rscript

# Run year-fixed-effects PAFR regressions from the finished city-year panel.
# The panel is constructed upstream; this script only reads it and estimates
# the specified models.

suppressPackageStartupMessages({
  library(dplyr)
  library(fixest)
})

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
analysis_dir <- file.path(root, "Data/GFOA Awards/analysis/city_year_pafr")
panel_file <- file.path(analysis_dir, "city_year_gfoa_awards_panel.csv")

panel <- read.csv(panel_file, stringsAsFactors = FALSE, check.names = FALSE)
panel <- panel %>%
  mutate(
    across(
      c(
        fiscal_year, pafr_award, city_go_vote, city_rev_vote, state_go_vote,
        state_utgo_allowed, glm_proactive, supermajority,
        low_state_tax_privilege, municipal_debt_limit,
        lincoln_property_tax_rate_cap_2024, municipal_tel_index,
        state_monitor, gasb_municipal_gaap_required_any,
        nasact_audits_cities_towns_villages, ln_county_employment_l1,
        ln_county_gdp_l1, ln_county_percap_inc_l1, ln_county_pop_l1
      ),
      as.numeric
    )
  )

analysis <- panel %>%
  filter(!is.na(pafr_award), !is.na(city_go_vote), !is.na(fiscal_year), !is.na(state)) %>%
  mutate(
    city_rev_vote_source_missing = as.integer(is.na(city_rev_vote)),
    city_rev_vote = coalesce(city_rev_vote, 0),
    municipal_debt_limit_source_missing = as.integer(is.na(municipal_debt_limit)),
    municipal_debt_limit = coalesce(municipal_debt_limit, 0),
    nasact_audits_cities_towns_villages_source_missing = as.integer(is.na(nasact_audits_cities_towns_villages)),
    nasact_audits_cities_towns_villages = coalesce(nasact_audits_cities_towns_villages, 0)
  )

# Baseline: city GO-vote requirement with fiscal-year fixed effects.
model_baseline <- feols(
  coa_award ~ city_go_vote  | fiscal_year,
  data = analysis,
  vcov = ~state,
  notes = FALSE
)

# Bond-data policy controls.
model_bond_policies <- feols(
  coa_award ~ city_go_vote  + ln_county_gdp_l1 +
    ln_county_percap_inc_l1 + ln_county_pop_l1 | fiscal_year,
  data = analysis,
  vcov = ~state,
  notes = FALSE
)

# Expanded controls: fiscal monitoring, municipal GAAP, city-auditor coverage,
# debt limits, property-tax cap, TEL severity, tax privilege, and BEA t-1 data.
model_expanded <- feols(
  coa_award ~ city_go_vote + bond_issued_current_year + ln_county_gdp_l1 +
    ln_county_percap_inc_l1 + ln_county_pop_l1 + 
    gasb_municipal_gaap_required_any + state_monitor + nasact_audits_cities_towns_villages | fiscal_year,
  data = analysis,
  vcov = ~state,
  notes = FALSE
)

# All supermajority states have city_go_vote = 1 in this panel, so the
# identified supermajority comparison is estimated within GO-vote states.
model_supermajority_among_go_vote <- feols(
  pafr_award ~ supermajority + city_rev_vote + state_go_vote +
    state_utgo_allowed + glm_proactive + low_state_tax_privilege +
    municipal_debt_limit + municipal_debt_limit_source_missing +
    lincoln_property_tax_rate_cap_2024 + municipal_tel_index +
    state_monitor + gasb_municipal_gaap_required_any +
    nasact_audits_cities_towns_villages +
    nasact_audits_cities_towns_villages_source_missing +
    ln_county_employment_l1 + ln_county_gdp_l1 +
    ln_county_percap_inc_l1 + ln_county_pop_l1 | fiscal_year,
  data = filter(analysis, city_go_vote == 1),
  vcov = ~state,
  notes = FALSE
)

models <- list(
  baseline_year_fe = model_baseline,
  bond_policy_year_fe = model_bond_policies,
  expanded_policy_year_fe = model_expanded,
  supermajority_among_go_vote_year_fe = model_supermajority_among_go_vote
)

capture.output(
  etable(
    models,
    se.below = TRUE,
    digits = 4,
    dict = c(
      city_go_vote = "City GO vote required",
      supermajority = "Supermajority state",
      state_monitor = "State fiscal monitor",
      gasb_municipal_gaap_required_any = "Municipal GAAP required",
      nasact_audits_cities_towns_villages = "State auditor audits cities/towns/villages"
    )
  ),
  file = file.path(analysis_dir, "pafr_city_year_models.txt")
)

tidy_baseline <- as.data.frame(coeftable(model_baseline))
tidy_baseline <- data.frame(model = "baseline_year_fe", term = rownames(tidy_baseline), tidy_baseline, row.names = NULL)

tidy_bond_policies <- as.data.frame(coeftable(model_bond_policies))
tidy_bond_policies <- data.frame(model = "bond_policy_year_fe", term = rownames(tidy_bond_policies), tidy_bond_policies, row.names = NULL)

tidy_expanded <- as.data.frame(coeftable(model_expanded))
tidy_expanded <- data.frame(model = "expanded_policy_year_fe", term = rownames(tidy_expanded), tidy_expanded, row.names = NULL)

tidy_supermajority <- as.data.frame(coeftable(model_supermajority_among_go_vote))
tidy_supermajority <- data.frame(model = "supermajority_among_go_vote_year_fe", term = rownames(tidy_supermajority), tidy_supermajority, row.names = NULL)

tidy_models <- bind_rows(tidy_baseline, tidy_bond_policies, tidy_expanded, tidy_supermajority)
write.csv(tidy_models, file.path(analysis_dir, "pafr_city_year_model_coefficients.csv"), row.names = FALSE)
