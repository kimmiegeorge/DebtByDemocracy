#!/usr/bin/env Rscript

# City-year GFOA award panel
#
# Universe: all cities with at least one GO issuance in the project's financial
# sample (Mergent, FY2000--2020), observed annually for FY2014--2020. The
# start date is deliberate: the public GFOA PAFR archive begins in FY2014.
#
# Matching policy: only conservative exact normalized name-and-state matches
# are coded as award positives. All other recipient records are written to an
# audit file (with within-state approximate candidates); they are NOT silently
# accepted.  Consequently, this first-release outcome is a lower bound pending
# human review of the candidate-match file.

suppressPackageStartupMessages({
  library(dplyr)
  library(haven)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) {
  normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE)
} else {
  normalizePath("Code/R/Analysis/01_city_year_pafr_awards.R", mustWork = TRUE)
}
root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."), mustWork = TRUE)

bond_file <- file.path(root, "Data/Mergent/Clean/260917_city_cusiplevel_finsample_allbonds.dta")
bond_policy_file <- file.path(root, "Data/Mergent/Clean/260611_city_issuerlevel.dta")
pafr_file <- file.path(root, "Data/GFOA Awards/processed/gfoa_award_observations_long.csv")
bea_file <- file.path(root, "Data/BEA/countydemos_1999_2026.dta")
state_policy_file <- file.path(root, "Data/State Policies/20260929_state_policy_comparison.csv")
monitor_file <- file.path(root, "Data/State Monitoring Policy/state_enforcement_adoption_years.csv")
debt_file <- file.path(root, "Data/Clean_Intermediate/Mergent/Outstanding Debt/full_mergent_issuer_year_outstanding_debt.csv")
tax_privilege_file <- file.path(root, "Code/R/Clean/00_tax_privilege_definitions.R")
supermajority_file <- file.path(root, "Code/R/Clean/00_state_policy_definitions.R")
output_dir <- file.path(root, "Data/GFOA Awards/analysis/city_year_pafr")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

required_files <- c(bond_file, bond_policy_file, pafr_file, bea_file,
                    state_policy_file, monitor_file, debt_file,
                    tax_privilege_file, supermajority_file)
if (any(!file.exists(required_files))) {
  stop("Missing required input(s): ", paste(required_files[!file.exists(required_files)], collapse = ", "))
}

source(tax_privilege_file)
source(supermajority_file)

as_binary <- function(x) {
  x <- trimws(toupper(as.character(x)))
  out <- as.integer(x %in% c("1", "YES", "Y", "TRUE", "✓"))
  out[is.na(x) | x %in% c("", "NA", "N/A")] <- NA_integer_
  out
}

mode_one <- function(x) {
  x <- x[!is.na(x) & x != ""]
  if (!length(x)) return(NA_character_)
  tab <- sort(table(x), decreasing = TRUE)
  names(tab)[[1]]
}

pad_fips <- function(x) {
  x <- suppressWarnings(as.integer(as.character(x)))
  ifelse(is.na(x), NA_character_, sprintf("%05d", x))
}

# Mergent's seed_issuer field frequently appends an old-style state suffix
# (e.g., "AURORA ILL" or "PITTSBURGH PA"). These are stripped only when the
# suffix belongs to the record's actual state. The GFOA recipient string does
# not use this step, which avoids confusing a city name with a state name.
state_suffix_aliases <- list(
  AL = c("AL", "ALA", "ALABAMA"), AK = c("AK", "ALASKA"), AZ = c("AZ", "ARIZ", "ARIZONA"),
  AR = c("AR", "ARK", "ARKANSAS"), CA = c("CA", "CAL", "CALIF", "CALIFORNIA"), CO = c("CO", "COLO", "COLORADO"),
  CT = c("CT", "CONN", "CONNECTICUT"), DE = c("DE", "DEL", "DELAWARE"), FL = c("FL", "FLA", "FLORIDA"),
  GA = c("GA", "GEORGIA"), HI = c("HI", "HAW", "HAWAII"), ID = c("ID", "IDAHO"),
  IL = c("IL", "ILL", "ILLINOIS"), IN = c("IN", "IND", "INDIANA"), IA = c("IA", "IOWA"),
  KS = c("KS", "KANS", "KANSAS"), KY = c("KY", "KENTUCKY"), LA = c("LA", "LOUISIANA"),
  ME = c("ME", "MAINE"), MD = c("MD", "MARYLAND"), MA = c("MA", "MASS", "MASSACHUSETTS"),
  MI = c("MI", "MICH", "MICHIGAN"), MN = c("MN", "MINN", "MINNESOTA"), MS = c("MS", "MISS", "MISSISSIPPI"),
  MO = c("MO", "MISSOURI"), MT = c("MT", "MONT", "MONTANA"), NE = c("NE", "NEBR", "NEBRASKA"),
  NV = c("NV", "NEV", "NEVADA"), NH = c("NH", "N H", "NEW HAMPSHIRE"), NJ = c("NJ", "N J", "NEW JERSEY"),
  NM = c("NM", "N M", "NEW MEXICO"), NY = c("NY", "N Y", "NEW YORK"), NC = c("NC", "N C", "NORTH CAROLINA"),
  ND = c("ND", "N D", "NORTH DAKOTA"), OH = c("OH", "OHIO"), OK = c("OK", "OKLA", "OKLAHOMA"),
  OR = c("OR", "ORE", "OREGON"), PA = c("PA", "PENN", "PENNSYLVANIA"), RI = c("RI", "R I", "RHODE ISLAND"),
  SC = c("SC", "S C", "SOUTH CAROLINA"), SD = c("SD", "S D", "SOUTH DAKOTA"), TN = c("TN", "TENN", "TENNESSEE"),
  TX = c("TX", "TEX", "TEXAS"), UT = c("UT", "UTAH"), VT = c("VT", "VERMONT"),
  VA = c("VA", "VIRGINIA"), WA = c("WA", "WASH", "WASHINGTON"), WV = c("WV", "W V", "WEST VIRGINIA"),
  WI = c("WI", "WIS", "WISCONSIN"), WY = c("WY", "WYO", "WYOMING")
)

normalize_city_name <- function(x, state = NA_character_, strip_state_suffix = FALSE) {
  x <- iconv(as.character(x), to = "ASCII//TRANSLIT")
  x <- toupper(x)
  x <- gsub("[^A-Z0-9]+", " ", x)
  x <- trimws(gsub(" +", " ", x))
  if (strip_state_suffix && !is.na(state) && state %in% names(state_suffix_aliases)) {
    aliases <- state_suffix_aliases[[state]]
    aliases <- aliases[order(nchar(aliases), decreasing = TRUE)]
    for (alias in aliases) {
      if (identical(x, alias)) next
      if (endsWith(x, paste0(" ", alias))) {
        x <- sub(paste0(" ", alias, "$"), "", x)
        break
      }
    }
  }
  x <- gsub("\\b(THE|CITY|TOWN|VILLAGE|BOROUGH|MUNICIPALITY|OF|GOVERNMENT|METROPOLITAN|MUNICIPAL|CORPORATION|AND)\\b", " ", x)
  trimws(gsub(" +", " ", x))
}

# Records with an unknown legacy GFOA type are allowed only if their name does
# not visibly identify a non-city government. This admits FY2014 city awards,
# whose archive type is blank, without equating school/county awards to cities.
looks_noncity <- function(x) {
  grepl("\\b(COUNTY|SCHOOL|DISTRICT|RETIREMENT|PENSION|AUTHORITY|COMMISSION|UNIVERSITY|COLLEGE|FUND|SYSTEM|BOARD|AGENCY|TOWNSHIP|UTILITY|UTILITIES|AIRPORT|HOUSING|WATER|SEWER|FIRE|LIBRARY|HOSPITAL|TRANSIT)\\b", x, ignore.case = TRUE)
}

state_policy_raw <- read.csv(state_policy_file, stringsAsFactors = FALSE, check.names = FALSE)
state_lookup <- state_policy_raw %>%
  transmute(state = state_abbr, state_name = state_name)
state_lookup_extra <- data.frame(
  state = c("DC", "DC"),
  state_name = c("DISTRICT OF COLUMBIA", "WASHINGTON, DC"),
  stringsAsFactors = FALSE
)
state_lookup_all <- bind_rows(
  state_lookup %>% transmute(state, state_name = toupper(state_name)),
  state_lookup %>% transmute(state, state_name = toupper(state)),
  state_lookup_extra
) %>% distinct(state_name, .keep_all = TRUE)

# 1. GO-city universe and fixed city attributes from the project bond data.
bond_data <- read_dta(
  bond_file,
  col_select = c(seed_issuer, seed_issuer_id, issuer_long_name, state, year,
                 fips, finsample, go_unlim, go_lim, city_go_vote, city_rev_vote)
)
bond_data <- bond_data %>%
  mutate(
    city_id = format(seed_issuer_id, scientific = FALSE, trim = TRUE),
    fips = pad_fips(fips),
    city_go_vote = as_binary(city_go_vote),
    city_rev_vote = as_binary(city_rev_vote)
  )

# GO issuance defines the city universe. All financial-sample city bonds—not
# only GO bonds—define the annual issuance controls below.
bonds <- bond_data %>%
  filter(finsample == 1, go_unlim == 1 | go_lim == 1, !is.na(seed_issuer_id)) %>%
  filter(city_id != "NA")

city_universe <- bonds %>%
  group_by(city_id) %>%
  summarise(
    state = mode_one(state),
    seed_issuer = mode_one(seed_issuer),
    issuer_long_name = mode_one(issuer_long_name),
    fips = mode_one(fips),
    city_go_vote = suppressWarnings(as.integer(mode_one(as.character(city_go_vote)))),
    city_rev_vote = suppressWarnings(as.integer(mode_one(as.character(city_rev_vote)))),
    .groups = "drop"
  ) %>%
  mutate(
    city_name_normalized = mapply(
      normalize_city_name, seed_issuer, state,
      MoreArgs = list(strip_state_suffix = TRUE), USE.NAMES = FALSE
    )
  )

if (anyDuplicated(city_universe$city_id)) stop("City universe is not unique by city_id.")
city_fips_conflicts <- bonds %>%
  distinct(city_id, fips) %>% count(city_id, name = "n_fips") %>% filter(n_fips > 1)
write.csv(city_fips_conflicts, file.path(output_dir, "city_fips_conflicts.csv"), row.names = FALSE)

# 2. State policy variables from the bond pipeline.
bond_policy <- read_dta(
  bond_policy_file,
  col_select = c(state, state_go_vote, state_utgo_allowed, glm_proactive)
) %>%
  mutate(across(-state, as.numeric)) %>%
  distinct()
state_bond_policy <- bond_policy %>%
  group_by(state) %>%
  summarise(
    state_go_vote = mode_one(as.character(state_go_vote)),
    state_utgo_allowed = mode_one(as.character(state_utgo_allowed)),
    glm_proactive = mode_one(as.character(glm_proactive)),
    .groups = "drop"
  ) %>%
  mutate(across(-state, ~ suppressWarnings(as.integer(.x))))

# 3. Newly collected debt-limit, property-tax, TEL, audit, and monitoring data.
state_policy_vars <- c(
  "state_abbr", "municipal_debt_limit", "strict_municipal_debt_limit",
  "debt_limit_can_be_exceeded", "debt_limit_exempts_revenue_bonds",
  "debt_limit_vote_to_exceed", "debt_limit_voter_override",
  "lincoln_property_tax_levy_cap_2024", "lincoln_property_tax_rate_cap_2024",
  "lincoln_truth_in_taxation_2024", "lincoln_broad_municipal_budget_limit_2022",
  "municipal_tel_any_2012", "municipal_tel_index",
  "state_fiscal_monitor_2017", "state_fiscal_monitor_2020",
  "gasb_municipal_gaap_required_any", "nasact_audits_cities_towns_villages",
  "go_vote_required"
)
missing_policy_vars <- setdiff(state_policy_vars, names(state_policy_raw))
if (length(missing_policy_vars)) stop("State-policy fields missing: ", paste(missing_policy_vars, collapse = ", "))
state_policy <- state_policy_raw %>%
  select(all_of(state_policy_vars)) %>%
  rename(state = state_abbr) %>%
  mutate(
    across(-c(state, municipal_tel_index), as_binary),
    municipal_tel_index = suppressWarnings(as.numeric(municipal_tel_index)),
    supermajority = as.integer(state %in% super_majority_states),
    low_state_tax_privilege = as.integer(state %in% low_state_tax_privilege_states)
  )

# 4. COA and PAFR recipient records, restricted to overlapping observed years.
award_raw <- read.csv(pafr_file, stringsAsFactors = FALSE, check.names = FALSE) %>%
  filter(award_program %in% c("COA", "PAFR")) %>%
  mutate(fiscal_year = as.integer(fiscal_year))
panel_years <- sort(intersect(
  seq.int(min(bonds$year), max(bonds$year)),
  unique(award_raw$fiscal_year[award_raw$award_program == "PAFR"])
))
if (!identical(panel_years, 2014:2020)) {
  warning("The observed PAFR/bond overlap is ", paste(panel_years, collapse = ", "), "; expected FY2014--2020.")
}

award_eligible <- award_raw %>%
  filter(fiscal_year %in% panel_years) %>%
  mutate(
    state_lookup_key = toupper(state_raw),
    recipient_name_normalized = normalize_city_name(recipient_name_raw),
    city_eligible = !looks_noncity(recipient_name_raw) &
      (government_type %in% c("MS", "Municipality") | is.na(government_type) | government_type == "")
  ) %>%
  left_join(state_lookup_all, by = c("state_lookup_key" = "state_name")) %>%
  filter(city_eligible, !is.na(state), recipient_name_normalized != "")

# An exact candidate is accepted only where the normalized state-name key maps
# to exactly one GO-city issuer ID. Ambiguous keys are kept for review.
city_keys <- city_universe %>%
  count(state, city_name_normalized, name = "n_city_key") %>%
  right_join(city_universe, by = c("state", "city_name_normalized"))
unique_city_keys <- city_keys %>% filter(n_city_key == 1) %>%
  select(state, recipient_name_normalized = city_name_normalized, city_id)

award_matches <- award_eligible %>%
  inner_join(unique_city_keys, by = c("state", "recipient_name_normalized")) %>%
  transmute(
    award_program, city_id, fiscal_year, recipient_name_raw,
    state_raw, government_type, gfoa_recipient_id,
    document_url, match_method = "exact_normalized_state_name"
  ) %>% distinct()

pafr_matches <- award_matches %>%
  filter(award_program == "PAFR") %>%
  transmute(
    city_id, fiscal_year, pafr_recipient_name_raw = recipient_name_raw,
    pafr_state_raw = state_raw, pafr_government_type = government_type,
    pafr_gfoa_recipient_id = gfoa_recipient_id,
    pafr_document_url = document_url, match_method
  )
coa_matches <- award_matches %>%
  filter(award_program == "COA") %>%
  transmute(
    city_id, fiscal_year, coa_recipient_name_raw = recipient_name_raw,
    coa_state_raw = state_raw, coa_government_type = government_type,
    coa_gfoa_recipient_id = gfoa_recipient_id,
    coa_document_url = document_url, match_method
  )
write.csv(pafr_matches, file.path(output_dir, "pafr_exact_matches.csv"), row.names = FALSE)
write.csv(coa_matches, file.path(output_dir, "coa_exact_matches.csv"), row.names = FALSE)

# Review file: unmatched but city-eligible award records with their three
# closest GO-city candidates in the same state. It is not used to create positives.
matched_recipient_keys <- award_matches %>%
  transmute(award_program, fiscal_year, recipient_name_raw, state_raw) %>% distinct()
award_unmatched <- award_eligible %>%
  anti_join(
    matched_recipient_keys,
    by = c("award_program", "fiscal_year", "recipient_name_raw", "state_raw")
  )
approximate_candidates <- lapply(seq_len(nrow(award_unmatched)), function(i) {
  recipient <- award_unmatched[i, ]
  candidates <- city_universe %>% filter(state == recipient$state)
  if (!nrow(candidates)) return(NULL)
  distance <- as.integer(adist(recipient$recipient_name_normalized, candidates$city_name_normalized))
  keep <- order(distance)[seq_len(min(3L, length(distance)))]
  data.frame(
    award_program = recipient$award_program,
    fiscal_year = recipient$fiscal_year,
    state = recipient$state,
    recipient_name_raw = recipient$recipient_name_raw,
    recipient_name_normalized = recipient$recipient_name_normalized,
    government_type = recipient$government_type,
    city_id_candidate = candidates$city_id[keep],
    seed_issuer_candidate = candidates$seed_issuer[keep],
    candidate_normalized = candidates$city_name_normalized[keep],
    edit_distance = distance[keep],
    stringsAsFactors = FALSE
  )
})
approximate_candidates <- bind_rows(approximate_candidates)
write.csv(approximate_candidates, file.path(output_dir, "gfoa_award_unmatched_candidate_review.csv"), row.names = FALSE)
write.csv(
  approximate_candidates %>% filter(award_program == "PAFR") %>% select(-award_program),
  file.path(output_dir, "pafr_unmatched_candidate_review.csv"), row.names = FALSE
)
write.csv(
  approximate_candidates %>% filter(award_program == "COA") %>% select(-award_program),
  file.path(output_dir, "coa_unmatched_candidate_review.csv"), row.names = FALSE
)

# 5. Construct the requested balanced city-year panel. Zero means no accepted
# match in the GFOA recipient data, conditional on this GO-city universe.
panel <- expand.grid(
  city_id = city_universe$city_id,
  fiscal_year = panel_years,
  stringsAsFactors = FALSE
) %>%
  left_join(city_universe, by = "city_id") %>%
  left_join(
    coa_matches %>% distinct(city_id, fiscal_year) %>% mutate(coa_award = 1L),
    by = c("city_id", "fiscal_year")
  ) %>%
  left_join(
    pafr_matches %>% distinct(city_id, fiscal_year) %>% mutate(pafr_award = 1L),
    by = c("city_id", "fiscal_year")
  ) %>%
  mutate(
    # The public COA archive/AMS transition leaves FY2019 far below adjacent
    # years (1,589 records versus roughly 4,100). Preserve matched positives,
    # but leave all unmatched FY2019 COA outcomes missing rather than false zero.
    coa_award = case_when(
      !is.na(coa_award) ~ 1L,
      fiscal_year == 2019L ~ NA_integer_,
      TRUE ~ 0L
    ),
    coa_award_coverage = ifelse(
      fiscal_year == 2019L,
      "partial_public_GFOA_coverage_archive_AMS_transition",
      "public_GFOA_source_collected"
    ),
    pafr_award = ifelse(is.na(pafr_award), 0L, pafr_award),
    either_gfoa_award = case_when(
      pafr_award == 1L | coa_award == 1L ~ 1L,
      is.na(coa_award) ~ NA_integer_,
      TRUE ~ 0L
    )
  ) %>%
  left_join(state_bond_policy, by = "state") %>%
  left_join(state_policy, by = "state")

# Fiscal monitoring turns on in the adoption year, matching the website
# analysis. Pre-sample adoption is coded 2009; unlisted states remain zero.
monitor_adoption <- read.csv(monitor_file, stringsAsFactors = FALSE) %>%
  transmute(
    state = Abbreviation,
    fiscal_monitor_adoption_year = as.integer(ifelse(AdoptionYear == "before_sample", "2009", AdoptionYear))
  )
if (anyDuplicated(monitor_adoption$state)) stop("Monitoring adoption data are not unique by state.")
panel <- panel %>%
  left_join(monitor_adoption, by = "state") %>%
  mutate(state_monitor = as.integer(coalesce(fiscal_year >= fiscal_monitor_adoption_year, FALSE)))

# Match the website analysis's composite issuer key and t-1 year-end debt.
# The shared debt measure sums original par amounts of outstanding CUSIPs;
# its logged measure is log(1 + total_outstanding_debt).
panel <- panel %>%
  mutate(issuer_key = paste(
    sprintf("%.0f", round(as.numeric(city_id) * 10)),
    toupper(trimws(state)),
    toupper(gsub("\\s+", " ", trimws(seed_issuer))), sep = "|"
  ))
debt_controls <- read.csv(debt_file, stringsAsFactors = FALSE) %>%
  transmute(
    issuer_key, fiscal_year = as.integer(year) + 1L,
    total_outstanding_debt_lag1 = total_outstanding_debt,
    ln_1p_outstanding_debt_lag1 = ln_1p_total_outstanding_debt
  )
if (anyDuplicated(debt_controls[c("issuer_key", "fiscal_year")])) stop("Debt data are not unique by issuer-year.")
panel <- panel %>%
  left_join(debt_controls, by = c("issuer_key", "fiscal_year"))
if (anyNA(panel$ln_1p_outstanding_debt_lag1)) stop("Shared debt panel is missing award issuer-years.")

# Annual bond-issuance indicators. `bond_issued_current_year` equals one if
# the city issued any financial-sample bond in the calendar year corresponding
# to the PAFR fiscal year. `bond_issued_current_or_prior_year` is one if the
# city issued in that year or in the immediately preceding year.
bond_issuance <- bond_data %>%
  filter(finsample == 1, !is.na(seed_issuer_id), city_id != "NA") %>%
  transmute(city_id, fiscal_year = as.integer(year)) %>%
  filter(fiscal_year %in% panel_years) %>%
  distinct() %>%
  mutate(bond_issued_current_year = 1L)
panel <- panel %>%
  left_join(bond_issuance, by = c("city_id", "fiscal_year")) %>%
  mutate(bond_issued_current_year = ifelse(is.na(bond_issued_current_year), 0L, bond_issued_current_year)) %>%
  arrange(city_id, fiscal_year) %>%
  group_by(city_id) %>%
  mutate(
    bond_issued_current_or_prior_year = as.integer(
      bond_issued_current_year == 1L |
        dplyr::lag(bond_issued_current_year, default = 0L) == 1L
    )
  ) %>%
  ungroup()

# County characteristics are lagged one year relative to the award FY.
county_controls <- read_dta(
  bea_file,
  col_select = c(fips, year, employment, gdp, percap_inc, pers_inc, pop)
) %>%
  transmute(
    fips = pad_fips(fips), fiscal_year = as.integer(year) + 1L,
    county_employment_l1 = as.numeric(employment),
    county_gdp_l1 = as.numeric(gdp),
    county_percap_inc_l1 = as.numeric(percap_inc),
    county_pers_inc_l1 = as.numeric(pers_inc),
    county_pop_l1 = as.numeric(pop)
  ) %>% distinct(fips, fiscal_year, .keep_all = TRUE)
panel <- panel %>%
  left_join(county_controls, by = c("fips", "fiscal_year")) %>%
  mutate(
    ln_county_employment_l1 = log1p(county_employment_l1),
    ln_county_gdp_l1 = log1p(county_gdp_l1),
    ln_county_percap_inc_l1 = log(county_percap_inc_l1),
    ln_county_pers_inc_l1 = log1p(county_pers_inc_l1),
    ln_county_pop_l1 = log1p(county_pop_l1)
  ) %>% arrange(fiscal_year, state, seed_issuer)

if (anyDuplicated(panel[c("city_id", "fiscal_year")])) stop("Final panel is not unique by city-year.")
write.csv(panel, file.path(output_dir, "city_year_gfoa_awards_panel.csv"), row.names = FALSE, na = "")

match_diagnostics <- data.frame(
  metric = c(
    "GO-city universe", "City-years", "Eligible COA recipient-year records",
    "Accepted exact COA matches", "COA-positive city-years (excluding FY2019 missing)",
    "Eligible PAFR recipient-year records", "Accepted exact PAFR matches",
    "PAFR-positive city-years", "FY range"
  ),
  value = c(
    nrow(city_universe), nrow(panel),
    sum(award_eligible$award_program == "COA"), nrow(coa_matches), sum(panel$coa_award, na.rm = TRUE),
    sum(award_eligible$award_program == "PAFR"), nrow(pafr_matches), sum(panel$pafr_award),
    paste(range(panel_years), collapse = "-")
  ),
  stringsAsFactors = FALSE
)
write.csv(match_diagnostics, file.path(output_dir, "build_diagnostics.csv"), row.names = FALSE)

writeLines(c(
  "City-year GFOA award panel build",
  "",
  "The primary panel is city_year_gfoa_awards_panel.csv. It contains coa_award, pafr_award, and either_gfoa_award for the GO-city universe.",
  "A value of 1 is a conservative exact normalized GFOA-to-city match. A value of 0 is no accepted match within the GO-city universe.",
  "COA FY2019 unmatched observations are coded missing, not zero, because the public GFOA archive/AMS transition has only 1,589 COA records versus roughly 4,100 in adjacent years.",
  "Fiscal years are 2014-2020: PAFR is not publicly observed before 2014 and the current city bond file ends in 2020.",
  "bond_issued_current_year indicates any financial-sample city bond issuance in year t; bond_issued_current_or_prior_year indicates an issuance in t or t-1.",
  "County BEA measures are merged at t-1. State policy fields preserve source N/A values.",
  "state_monitor equals one from the fiscal-monitoring adoption year onward, using the website analysis adoption source; before_sample is coded 2009 and unlisted states are zero. Dated monitoring snapshots are retained separately.",
  "total_outstanding_debt_lag1 and ln_1p_outstanding_debt_lag1 are shared Mergent year-end debt at t-1 and log(1 + debt), merged by composite issuer_key and year, as in the website analysis.",
  "All unmatched city-eligible recipient records and their closest same-state candidates are in gfoa_award_unmatched_candidate_review.csv."
), file.path(output_dir, "README.txt"))
