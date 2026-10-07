# Issuer-month market timing tests
rm(list = ls())

library(pacman)
p_load(data.table, fixest, haven)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
out_dir <- file.path(root, 'Results/Bond Level Yield Spread Diagnostics')
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables'
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

mergent_file <- file.path(root, 'Data/Mergent/Clean/260709_city_cusiplevel_statereq_purpose_yieldspread.dta')

#----------------------------
# Load bond issuance data
#----------------------------
bonds <- as.data.table(read_dta(mergent_file))
setnames(bonds, names(bonds), tolower(names(bonds)))

bonds[, city_rev_vote := fifelse(state == 'MO', 1, city_rev_vote)]
bonds[, city_go_vote := fifelse(state == 'RI', NA_real_, city_go_vote)]
bonds[, offering_date := as.IDate(offering_date)]
bonds[, issue_month := as.IDate(paste0(format(offering_date, '%Y-%m'), '-01'))]

p1 <- quantile(bonds$offering_yield_spread, 0.01, na.rm = TRUE)
p99 <- quantile(bonds$offering_yield_spread, 0.99, na.rm = TRUE)
bonds[, offering_yield_spread_tr := fifelse(
  offering_yield_spread < p1 | offering_yield_spread > p99,
  NA_real_,
  offering_yield_spread
)]

bonds <- bonds[
  insample == 1 &
    !is.na(seed_issuer_id) &
    !is.na(issue_month) &
    !is.na(city_go_vote) &
    !is.na(state)
]

#----------------------------
# Market-wide spread conditions
#----------------------------
# National and leave-state monthly spread conditions are computed from all bonds
# in the regression sample, then lagged so current issuance does not mechanically
# enter the market-condition regressor.
market_bonds <- bonds[!is.na(offering_yield_spread_tr)]

monthly_market <- market_bonds[
  ,
  .(
    market_spread = mean(offering_yield_spread_tr, na.rm = TRUE),
    market_spread_n = .N
  ),
  by = issue_month
][order(issue_month)]

monthly_market_sum <- market_bonds[
  ,
  .(
    market_spread_sum = sum(offering_yield_spread_tr, na.rm = TRUE),
    market_spread_n = .N
  ),
  by = issue_month
]

state_month_market <- market_bonds[
  ,
  .(
    state_market_spread_sum = sum(offering_yield_spread_tr, na.rm = TRUE),
    state_market_spread_n = .N
  ),
  by = .(state, issue_month)
]

# Calendar-complete state-month grid. If a state has no issuance in a month,
# leave-state market conditions equal national market conditions for that month.
state_month_grid <- CJ(
  state = unique(bonds$state),
  issue_month = monthly_market_sum$issue_month
)

state_month_market <- state_month_market[
  state_month_grid,
  on = .(state, issue_month)
]
state_month_market[is.na(state_market_spread_sum), state_market_spread_sum := 0]
state_month_market[is.na(state_market_spread_n), state_market_spread_n := 0]
state_month_market <- monthly_market_sum[
  state_month_market,
  on = .(issue_month)
]
state_month_market[, leave_state_market_spread :=
                     fifelse(
                       market_spread_n - state_market_spread_n > 0,
                       (market_spread_sum - state_market_spread_sum) /
                         (market_spread_n - state_market_spread_n),
                       NA_real_
                     )]
state_month_market <- state_month_market[
  ,
  .(state, issue_month, leave_state_market_spread)
]

month_lags <- monthly_market[, .(issue_month, market_spread)]
setorder(month_lags, issue_month)
month_lags[, lag_market_spread := shift(market_spread, 1)]
month_lags[, lag2_market_spread := shift(market_spread, 2)]
month_lags <- month_lags[, .(issue_month, lag_market_spread, lag2_market_spread)]

state_month_lags <- state_month_market[order(state, issue_month)]
state_month_lags[
  ,
  `:=`(
    lag_leave_state_market_spread = shift(leave_state_market_spread, 1),
    lag2_leave_state_market_spread = shift(leave_state_market_spread, 2)
  ),
  by = state
]
state_month_lags <- state_month_lags[
  ,
  .(state, issue_month, lag_leave_state_market_spread, lag2_leave_state_market_spread)
]

#----------------------------
# Build issuer-month panel
#----------------------------
issuers <- unique(
  bonds[
    ,
    .(
      seed_issuer_id,
      seed_issuer,
      state,
      fips,
      city_go_vote,
      state_go_vote,
      state_ltgo_allowed,
      glm_proactive,
      ln_gdp,
      ln_pop,
      ln_pers_inc
    )
  ]
)

issuers <- issuers[
  ,
  lapply(.SD, function(x) x[which(!is.na(x))[1]]),
  by = seed_issuer_id,
  .SDcols = setdiff(names(issuers), 'seed_issuer_id')
]

issuer_month_bounds <- bonds[
  ,
  .(
    first_issue_month = min(issue_month, na.rm = TRUE),
    last_issue_month = max(issue_month, na.rm = TRUE)
  ),
  by = seed_issuer_id
]

issuers <- issuer_month_bounds[issuers, on = .(seed_issuer_id)]

all_months <- seq(min(bonds$issue_month), max(bonds$issue_month), by = 'month')
panel <- CJ(seed_issuer_id = issuers$seed_issuer_id, issue_month = all_months)
panel <- issuers[panel, on = .(seed_issuer_id)]

issuance <- bonds[
  ,
  .(
    any_issue = 1L,
    n_bonds = .N,
    n_issues = uniqueN(issue_id),
    amount_issued = sum(amount, na.rm = TRUE),
    mean_offering_yield_spread = mean(offering_yield_spread_tr, na.rm = TRUE)
  ),
  by = .(seed_issuer_id, issue_month)
]

panel <- issuance[panel, on = .(seed_issuer_id, issue_month)]
panel[is.na(any_issue), any_issue := 0L]
panel[is.na(n_bonds), n_bonds := 0L]
panel[is.na(n_issues), n_issues := 0L]
panel[is.na(amount_issued), amount_issued := 0]
panel[, ln_1p_amount_issued := log1p(amount_issued)]
panel[, ln_1p_n_bonds := log1p(n_bonds)]
panel[, ln_1p_n_issues := log1p(n_issues)]
panel[, year := as.integer(format(issue_month, '%Y'))]
panel[, yrmonth := format(issue_month, '%Y-%m')]

panel <- month_lags[panel, on = .(issue_month)]
panel <- state_month_lags[panel, on = .(state, issue_month)]

panel <- panel[
  !is.na(city_go_vote) &
    !is.na(lag_market_spread) &
    !is.na(lag_leave_state_market_spread)
]

# Standardize market conditions so coefficients are per one SD increase.
panel[, lag_market_spread_z := as.numeric(scale(lag_market_spread))]
panel[, lag2_market_spread_z := as.numeric(scale(lag2_market_spread))]
panel[, lag_leave_state_market_spread_z := as.numeric(scale(lag_leave_state_market_spread))]
panel[, lag2_leave_state_market_spread_z := as.numeric(scale(lag2_leave_state_market_spread))]

fwrite(
  panel[
    ,
    .(
      seed_issuer_id,
      issue_month,
      year,
      state,
      city_go_vote,
      any_issue,
      n_bonds,
      n_issues,
      amount_issued,
      lag_market_spread,
      lag_leave_state_market_spread
    )
  ],
  file.path(out_dir, 'issuer_month_market_timing_panel.csv')
)

#----------------------------
# Regressions
#----------------------------
# Negative interaction coefficients mean GO-vote issuers issue less when spreads
# are high, equivalently more when spreads are low.
r_any_nat <- feols(
  any_issue ~ city_go_vote:lag_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel,
  vcov = vcov_cluster(~seed_issuer_id)
)

r_amt_nat <- feols(
  ln_1p_amount_issued ~ city_go_vote:lag_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel,
  vcov = vcov_cluster(~seed_issuer_id)
)

r_num_nat <- feols(
  ln_1p_n_issues ~ city_go_vote:lag_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel,
  vcov = vcov_cluster(~seed_issuer_id)
)

r_any_leave_state <- feols(
  any_issue ~ city_go_vote:lag_leave_state_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel,
  vcov = vcov_cluster(~seed_issuer_id)
)

r_amt_leave_state <- feols(
  ln_1p_amount_issued ~ city_go_vote:lag_leave_state_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel,
  vcov = vcov_cluster(~seed_issuer_id)
)

r_num_leave_state <- feols(
  ln_1p_n_issues ~ city_go_vote:lag_leave_state_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel,
  vcov = vcov_cluster(~seed_issuer_id)
)

r_any_leave_state_lag2 <- feols(
  any_issue ~ city_go_vote:lag2_leave_state_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel[!is.na(lag2_leave_state_market_spread_z)],
  vcov = vcov_cluster(~seed_issuer_id)
)

r_amt_leave_state_lag2 <- feols(
  ln_1p_amount_issued ~ city_go_vote:lag2_leave_state_market_spread_z |
    seed_issuer_id + yrmonth,
  data = panel[!is.na(lag2_leave_state_market_spread_z)],
  vcov = vcov_cluster(~seed_issuer_id)
)

extract_timing_coef <- function(model, label, outcome, market_measure) {
  coefs <- as.data.table(coeftable(model), keep.rownames = 'term')
  row <- coefs[grepl('city_go_vote:', term)]
  data.table(
    specification = label,
    outcome = outcome,
    market_measure = market_measure,
    term = row[['term']],
    estimate = row[['Estimate']],
    se = row[['Std. Error']],
    t_stat = row[['t value']],
    p_value = row[['Pr(>|t|)']],
    n = nobs(model),
    adj_r2 = fitstat(model, 'ar2')[[1]]
  )
}

timing_coefs <- rbindlist(list(
  extract_timing_coef(r_any_nat, 'National lagged market spread', 'Any issuance', 'lag_market_spread_z'),
  extract_timing_coef(r_amt_nat, 'National lagged market spread', 'ln(1 + amount issued)', 'lag_market_spread_z'),
  extract_timing_coef(r_num_nat, 'National lagged market spread', 'ln(1 + issues)', 'lag_market_spread_z'),
  extract_timing_coef(r_any_leave_state, 'Leave-state lagged market spread', 'Any issuance', 'lag_leave_state_market_spread_z'),
  extract_timing_coef(r_amt_leave_state, 'Leave-state lagged market spread', 'ln(1 + amount issued)', 'lag_leave_state_market_spread_z'),
  extract_timing_coef(r_num_leave_state, 'Leave-state lagged market spread', 'ln(1 + issues)', 'lag_leave_state_market_spread_z'),
  extract_timing_coef(r_any_leave_state_lag2, 'Leave-state two-month lagged market spread', 'Any issuance', 'lag2_leave_state_market_spread_z'),
  extract_timing_coef(r_amt_leave_state_lag2, 'Leave-state two-month lagged market spread', 'ln(1 + amount issued)', 'lag2_leave_state_market_spread_z')
))

fwrite(timing_coefs, file.path(out_dir, 'issuer_month_market_timing_coefficients.csv'))

table_call <- etable(
  r_any_nat,
  r_amt_nat,
  r_num_nat,
  r_any_leave_state,
  r_amt_leave_state,
  r_num_leave_state,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  dict = c(
    any_issue = 'Any Issuance',
    ln_1p_amount_issued = 'ln(1 + Amount Issued)',
    ln_1p_n_issues = 'ln(1 + Issues)',
    'city_go_vote:lag_market_spread_z' = 'GO Vote x Lag Market Spread',
    'city_go_vote:lag_leave_state_market_spread_z' = 'GO Vote x Lag Leave-State Spread',
    seed_issuer_id = 'Issuer',
    yrmonth = 'Month'
  ),
  placement = 'H'
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output <- format_table(modified_output, cluster_level = 'Issuer')
modified_output <- add_panel(modified_output, 'Panel A: Issuer-month market timing')
writeLines(modified_output, file.path(tbl_dir, 'issuer_month_market_timing.tex'))

message('Wrote market timing diagnostics to: ', out_dir)
