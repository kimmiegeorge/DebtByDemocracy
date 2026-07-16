# Diagnostics for bond-level yield-spread sign changes with time fixed effects
rm(list = ls())

library(pacman)
p_load(data.table, fixest, haven)

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
out_dir <- file.path(root, 'Results/Bond Level Yield Spread Diagnostics')
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

mergent_file <- file.path(root, 'Data/Mergent/Clean/260709_city_cusiplevel_statereq_purpose_yieldspread.dta')
dpc_file <- file.path(root, 'Data/DPC Data/Use Of Proceeds/260223_dpcdata_cusip_purpose.csv')
underwriter_file <- file.path(root, 'Data/Mergent/Underwriters/issue_underwriter_measures.csv')

high_state_tax_privilege_states <- c(
  'CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN',
  'NC', 'ID', 'NY', 'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE'
)

standard_controls <- c(
  'ln_gdp',
  'ln_pop',
  'ln_pers_inc',
  'glm_proactive',
  'state_ltgo_allowed',
  'state_go_vote',
  'high_state_tax_privilege'
)

bond_controls <- c(
  'ln_amount',
  'ln_maturity_mths',
  'callable',
  'sinkable',
  'insured',
  'rated'
)

dpc_controls <- c(
  'dpc_matched',
  'dpc_education',
  'dpc_transportation',
  'dpc_utilities',
  'dpc_public_safety',
  'dpc_recreation',
  'dpc_economic_development',
  'dpc_other_public_buildings',
  'dpc_other',
  'dpc_refunding'
)

underwriter_controls <- c(
  'has_primary_underwriter',
  'has_lead_underwriter',
  'has_placement_agent',
  'ln_1p_n_co_managers',
  'ln_1p_n_syndicate_members',
  'primary_underwriter_national_top10',
  'primary_underwriter_state_top10',
  'primary_underwriter_national_amount_share_max',
  'primary_underwriter_state_amount_share_max'
)

all_controls <- c(standard_controls, bond_controls, dpc_controls, underwriter_controls)
rhs_controls <- paste(all_controls, collapse = ' + ')

#----------------------------
# Load and prepare same sample as bond_level_yield_spreads.R
#----------------------------
bonds <- as.data.table(read_dta(mergent_file))
setnames(bonds, names(bonds), tolower(names(bonds)))
bonds[, cusip := toupper(trimws(cusip))]

bonds[, city_rev_vote := fifelse(state == 'MO', 1, city_rev_vote)]
bonds[, city_go_vote := fifelse(state == 'RI', NA_real_, city_go_vote)]
bonds[, high_state_tax_privilege := as.integer(state %in% high_state_tax_privilege_states)]

if (!('rev' %in% names(bonds))) {
  if ('bond_type' %in% names(bonds)) {
    bonds[, rev := as.integer(grepl('REV|REVENUE', toupper(bond_type)))]
  } else {
    stop('No rev or bond_type variable found in Mergent file.')
  }
}

if (!('yrmonth' %in% names(bonds))) {
  bonds[, yrmonth := format(as.IDate(offering_date), '%Y-%m')]
}

if (!('ln_maturity_mths' %in% names(bonds))) {
  bonds[, maturity_mths := as.numeric(as.IDate(maturity_date) - as.IDate(offering_date)) / 30.4375]
  bonds[, ln_maturity_mths := log(maturity_mths)]
}

if (!('ln_amount' %in% names(bonds))) {
  bonds[, ln_amount := log(amount)]
}

bonds[, `:=`(
  utgo = as.integer(fifelse(is.na(go_unlim), 0, go_unlim) == 1),
  ltgo = as.integer(fifelse(is.na(go_lim), 0, go_lim) == 1),
  revenue = as.integer(fifelse(is.na(rev), 0, rev) == 1)
)]

p1 <- quantile(bonds$offering_yield_spread, 0.01, na.rm = TRUE)
p99 <- quantile(bonds$offering_yield_spread, 0.99, na.rm = TRUE)
bonds[, offering_yield_spread_tr := fifelse(
  offering_yield_spread < p1 | offering_yield_spread > p99,
  NA_real_,
  offering_yield_spread
)]

dpc <- fread(dpc_file)
setnames(dpc, names(dpc), tolower(names(dpc)))
dpc[, cusip := toupper(trimws(cusip))]
dpc_flag_vars <- setdiff(names(dpc), c('docid', 'cusip'))
dpc[, (dpc_flag_vars) := lapply(.SD, as.integer), .SDcols = dpc_flag_vars]

dpc_cusip <- dpc[
  ,
  lapply(.SD, max, na.rm = TRUE),
  by = cusip,
  .SDcols = dpc_flag_vars
]

dpc_cusip[, `:=`(
  dpc_education = educ,
  dpc_transportation = as.integer(pubtransit == 1 | street == 1),
  dpc_utilities = as.integer(wtrswr == 1 | elec == 1 | waste == 1 | gas == 1),
  dpc_public_safety = as.integer(fire == 1 | police == 1),
  dpc_recreation = as.integer(parksrec == 1 | sport == 1 | libarts == 1),
  dpc_economic_development = econdev,
  dpc_other_public_buildings = otherpubbldg,
  dpc_other = as.integer(health == 1 | other == 1),
  dpc_refunding = refund,
  dpc_matched = 1L
)]
dpc_cusip <- dpc_cusip[, unique(c('cusip', dpc_controls)), with = FALSE]

bonds <- dpc_cusip[bonds, on = .(cusip)]
bonds[is.na(dpc_matched), dpc_matched := 0L]
bonds[, (dpc_controls) := lapply(.SD, function(x) fifelse(is.na(x), 0L, x)), .SDcols = dpc_controls]

underwriters <- fread(underwriter_file)
setnames(underwriters, names(underwriters), tolower(names(underwriters)))
underwriters <- underwriters[
  ,
  .(
    issue_id,
    has_primary_underwriter,
    has_lead_underwriter,
    has_placement_agent,
    n_co_managers,
    n_syndicate_members,
    primary_underwriter_national_top10,
    primary_underwriter_state_top10,
    primary_underwriter_national_amount_share_max,
    primary_underwriter_state_amount_share_max
  )
]

bonds <- underwriters[bonds, on = .(issue_id)]
underwriter_flag_controls <- c(
  'has_primary_underwriter',
  'has_lead_underwriter',
  'has_placement_agent',
  'primary_underwriter_national_top10',
  'primary_underwriter_state_top10'
)
bonds[, (underwriter_flag_controls) := lapply(.SD, function(x) fifelse(is.na(x), 0L, x)), .SDcols = underwriter_flag_controls]
bonds[, n_co_managers := fifelse(is.na(n_co_managers), 0, n_co_managers)]
bonds[, n_syndicate_members := fifelse(is.na(n_syndicate_members), 0, n_syndicate_members)]
bonds[, ln_1p_n_co_managers := log1p(n_co_managers)]
bonds[, ln_1p_n_syndicate_members := log1p(n_syndicate_members)]
bonds[is.na(primary_underwriter_national_amount_share_max), primary_underwriter_national_amount_share_max := 0]
bonds[is.na(primary_underwriter_state_amount_share_max), primary_underwriter_state_amount_share_max := 0]

sample_controls <- c('city_go_vote', all_controls)
bonds <- bonds[
  !is.na(offering_yield_spread_tr) &
    !is.na(city_go_vote) &
    complete.cases(bonds[, ..sample_controls])
]

full_sample <- bonds[insample == 1]

#----------------------------
# Fixed-effects ladder
#----------------------------
extract_city_go <- function(model, label, sample_name) {
  coefs <- as.data.table(coeftable(model), keep.rownames = 'term')
  row <- coefs[term == 'city_go_vote']
  data.table(
    sample = sample_name,
    specification = label,
    estimate = row[['Estimate']],
    se = row[['Std. Error']],
    t_stat = row[['t value']],
    p_value = row[['Pr(>|t|)']],
    n = nobs(model),
    adj_r2 = fitstat(model, 'ar2')[[1]]
  )
}

run_ladder <- function(dt, sample_name) {
  r_no_fe <- feols(
    as.formula(paste0('offering_yield_spread_tr ~ city_go_vote + ', rhs_controls)),
    data = dt,
    vcov = vcov_cluster(~issue_id)
  )
  r_purpose_fe <- feols(
    as.formula(paste0('offering_yield_spread_tr ~ city_go_vote + ', rhs_controls, ' | purp_broad')),
    data = dt,
    vcov = vcov_cluster(~issue_id)
  )
  r_year_fe <- feols(
    as.formula(paste0('offering_yield_spread_tr ~ city_go_vote + ', rhs_controls, ' | year + purp_broad')),
    data = dt,
    vcov = vcov_cluster(~issue_id)
  )
  r_yrmonth_fe <- feols(
    as.formula(paste0('offering_yield_spread_tr ~ city_go_vote + ', rhs_controls, ' | yrmonth + purp_broad')),
    data = dt,
    vcov = vcov_cluster(~issue_id)
  )
  r_state_year_fe <- feols(
    as.formula(paste0('offering_yield_spread_tr ~ city_go_vote + ', rhs_controls, ' | state^year + purp_broad')),
    data = dt,
    vcov = vcov_cluster(~issue_id)
  )

  rbindlist(list(
    extract_city_go(r_no_fe, 'No FE', sample_name),
    extract_city_go(r_purpose_fe, 'Purpose FE', sample_name),
    extract_city_go(r_year_fe, 'Year + purpose FE', sample_name),
    extract_city_go(r_yrmonth_fe, 'Year-month + purpose FE', sample_name),
    extract_city_go(r_state_year_fe, 'State-year + purpose FE', sample_name)
  ))
}

coef_ladder <- rbindlist(list(
  run_ladder(full_sample, 'All bonds'),
  run_ladder(full_sample[utgo == 1], 'UTGO'),
  run_ladder(full_sample[ltgo == 1], 'LTGO'),
  run_ladder(full_sample[revenue == 1], 'Revenue')
))

fwrite(coef_ladder, file.path(out_dir, 'city_go_vote_time_fe_ladder.csv'))

#----------------------------
# Time-composition summaries
#----------------------------
year_summary <- full_sample[
  ,
  .(
    n_bonds = .N,
    go_vote_share = mean(city_go_vote, na.rm = TRUE),
    mean_yield_spread = mean(offering_yield_spread_tr, na.rm = TRUE),
    mean_yield_spread_go_vote = mean(offering_yield_spread_tr[city_go_vote == 1], na.rm = TRUE),
    mean_yield_spread_no_go_vote = mean(offering_yield_spread_tr[city_go_vote == 0], na.rm = TRUE),
    amount = sum(amount, na.rm = TRUE),
    go_vote_amount_share = sum(amount[city_go_vote == 1], na.rm = TRUE) / sum(amount, na.rm = TRUE)
  ),
  by = year
][order(year)]
year_summary[, raw_go_minus_no_go_spread :=
               mean_yield_spread_go_vote - mean_yield_spread_no_go_vote]
fwrite(year_summary, file.path(out_dir, 'yearly_go_vote_yield_spread_composition.csv'))

yrmonth_summary <- full_sample[
  ,
  .(
    n_bonds = .N,
    go_vote_share = mean(city_go_vote, na.rm = TRUE),
    mean_yield_spread = mean(offering_yield_spread_tr, na.rm = TRUE),
    mean_yield_spread_go_vote = mean(offering_yield_spread_tr[city_go_vote == 1], na.rm = TRUE),
    mean_yield_spread_no_go_vote = mean(offering_yield_spread_tr[city_go_vote == 0], na.rm = TRUE),
    amount = sum(amount, na.rm = TRUE),
    go_vote_amount_share = sum(amount[city_go_vote == 1], na.rm = TRUE) / sum(amount, na.rm = TRUE)
  ),
  by = yrmonth
][order(yrmonth)]
yrmonth_summary[, raw_go_minus_no_go_spread :=
                  mean_yield_spread_go_vote - mean_yield_spread_no_go_vote]
fwrite(yrmonth_summary, file.path(out_dir, 'monthly_go_vote_yield_spread_composition.csv'))

state_year_summary <- full_sample[
  ,
  .(
    n_bonds = .N,
    go_vote_share = mean(city_go_vote, na.rm = TRUE),
    mean_yield_spread = mean(offering_yield_spread_tr, na.rm = TRUE),
    amount = sum(amount, na.rm = TRUE)
  ),
  by = .(state, year)
][order(state, year)]
fwrite(state_year_summary, file.path(out_dir, 'state_year_go_vote_yield_spread_composition.csv'))

#----------------------------
# Residualized relationship with and without time fixed effects
#----------------------------
resid_sample <- copy(full_sample)

y_no_time <- feols(
  as.formula(paste0('offering_yield_spread_tr ~ ', rhs_controls, ' | purp_broad')),
  data = resid_sample
)
d_no_time <- feols(
  as.formula(paste0('city_go_vote ~ ', rhs_controls, ' | purp_broad')),
  data = resid_sample
)
y_time <- feols(
  as.formula(paste0('offering_yield_spread_tr ~ ', rhs_controls, ' | yrmonth + purp_broad')),
  data = resid_sample
)
d_time <- feols(
  as.formula(paste0('city_go_vote ~ ', rhs_controls, ' | yrmonth + purp_broad')),
  data = resid_sample
)

resid_sample[, `:=`(
  y_resid_no_time = resid(y_no_time),
  d_resid_no_time = resid(d_no_time),
  y_resid_time = resid(y_time),
  d_resid_time = resid(d_time)
)]

resid_summary <- data.table(
  relationship = c('Controls + purpose FE', 'Controls + year-month + purpose FE'),
  residual_correlation = c(
    cor(resid_sample$y_resid_no_time, resid_sample$d_resid_no_time, use = 'complete.obs'),
    cor(resid_sample$y_resid_time, resid_sample$d_resid_time, use = 'complete.obs')
  )
)
fwrite(resid_summary, file.path(out_dir, 'residualized_city_go_vote_correlations.csv'))

resid_bins <- resid_sample[
  ,
  .(
    y_resid_no_time = mean(y_resid_no_time, na.rm = TRUE),
    d_resid_no_time = mean(d_resid_no_time, na.rm = TRUE),
    y_resid_time = mean(y_resid_time, na.rm = TRUE),
    d_resid_time = mean(d_resid_time, na.rm = TRUE),
    n_bonds = .N
  ),
  by = .(state, year)
][order(year, state)]
fwrite(resid_bins, file.path(out_dir, 'state_year_residualized_city_go_vote_relationship.csv'))

message('Wrote diagnostics to: ', out_dir)

