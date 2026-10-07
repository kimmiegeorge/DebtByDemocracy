# Bond-level offering yield spread regressions
rm(list = ls())

library(pacman)
p_load(data.table, fixest, haven)

source('/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/submission_tables/modify_etable_rounding.R')

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables'

mergent_file <- file.path(root, 'Data/Mergent/Clean/260709_city_cusiplevel_statereq_purpose_yieldspread.dta')
dpc_file <- file.path(root, 'Data/DPC Data/Use Of Proceeds/260223_dpcdata_cusip_purpose.csv')
underwriter_file <- file.path(root, 'Data/Mergent/Underwriters/issue_underwriter_measures.csv')

super_majority_states <- c('CA', 'ID', 'MO', 'ND', 'SD', 'WA')
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

#----------------------------
# Load and clean Mergent bonds
#----------------------------
bonds <- as.data.table(read_dta(mergent_file))
setnames(bonds, names(bonds), tolower(names(bonds)))
bonds[, cusip := toupper(trimws(cusip))]

bonds[, city_rev_vote := fifelse(state == 'MO', 1, city_rev_vote)]
bonds[, city_go_vote := fifelse(state == 'RI', NA_real_, city_go_vote)]
bonds[, super_majority := as.integer(state %in% super_majority_states)]
bonds[, high_state_tax_privilege := as.integer(state %in% high_state_tax_privilege_states)]

if (!('rev' %in% names(bonds))) {
  if ('bond_type' %in% names(bonds)) {
    bonds[, rev := as.integer(grepl('REV|REVENUE', toupper(bond_type)))]
  } else {
    stop('No rev or bond_type variable found in Mergent file.')
  }
}

if (!('go_unlim' %in% names(bonds)) || !('go_lim' %in% names(bonds))) {
  stop('Expected go_unlim and go_lim variables in Mergent file.')
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
  go_any = as.integer(fifelse(is.na(go_unlim), 0, go_unlim) == 1 |
                        fifelse(is.na(go_lim), 0, go_lim) == 1),
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

#----------------------------
# Merge DPC purpose flags by CUSIP, when available
#----------------------------
dpc <- fread(dpc_file)
setnames(dpc, names(dpc), tolower(names(dpc)))
setnames(dpc, 'cusip', 'cusip', skip_absent = TRUE)
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

#----------------------------
# Merge Mergent underwriter measures by issue
#----------------------------
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

sample_controls <- c('city_go_vote', standard_controls, bond_controls, dpc_controls, underwriter_controls)
bonds <- bonds[
  !is.na(offering_yield_spread_tr) &
    !is.na(city_go_vote) &
    complete.cases(bonds[, ..sample_controls])
]

full_sample <- bonds[insample == 1]

#----------------------------
# Regressions
#----------------------------
r_all <- feols(
  offering_yield_spread_tr ~ city_go_vote +
    ln_gdp + ln_pop + ln_pers_inc +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege +
    ln_amount + ln_maturity_mths + callable + sinkable + insured + rated +
    dpc_matched + dpc_education + dpc_transportation + dpc_utilities +
    dpc_public_safety + dpc_recreation + dpc_economic_development +
    dpc_other_public_buildings + dpc_other + dpc_refunding +
    has_primary_underwriter + has_lead_underwriter + has_placement_agent +
    ln_1p_n_co_managers + ln_1p_n_syndicate_members +
    primary_underwriter_national_top10 + primary_underwriter_state_top10 +
    primary_underwriter_national_amount_share_max +
    primary_underwriter_state_amount_share_max |
    yrmonth + purp_broad,
  data = full_sample,
  vcov = vcov_cluster(~issue_id)
)

r_utgo <- feols(
  offering_yield_spread_tr ~ city_go_vote +
    ln_gdp + ln_pop + ln_pers_inc +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege +
    ln_amount + ln_maturity_mths + callable + sinkable + insured + rated +
    dpc_matched + dpc_education + dpc_transportation + dpc_utilities +
    dpc_public_safety + dpc_recreation + dpc_economic_development +
    dpc_other_public_buildings + dpc_other + dpc_refunding +
    has_primary_underwriter + has_lead_underwriter + has_placement_agent +
    ln_1p_n_co_managers + ln_1p_n_syndicate_members +
    primary_underwriter_national_top10 + primary_underwriter_state_top10 +
    primary_underwriter_national_amount_share_max +
    primary_underwriter_state_amount_share_max |
    yrmonth + purp_broad,
  data = full_sample[utgo == 1],
  vcov = vcov_cluster(~issue_id)
)

r_ltgo <- feols(
  offering_yield_spread_tr ~ city_go_vote +
    ln_gdp + ln_pop + ln_pers_inc +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege +
    ln_amount + ln_maturity_mths + callable + sinkable + insured + rated +
    dpc_matched + dpc_education + dpc_transportation + dpc_utilities +
    dpc_public_safety + dpc_recreation + dpc_economic_development +
    dpc_other_public_buildings + dpc_other + dpc_refunding +
    has_primary_underwriter + has_lead_underwriter + has_placement_agent +
    ln_1p_n_co_managers + ln_1p_n_syndicate_members +
    primary_underwriter_national_top10 + primary_underwriter_state_top10 +
    primary_underwriter_national_amount_share_max +
    primary_underwriter_state_amount_share_max |
    yrmonth + purp_broad,
  data = full_sample[ltgo == 1],
  vcov = vcov_cluster(~issue_id)
)

r_revenue <- feols(
  offering_yield_spread_tr ~ city_go_vote +
    ln_gdp + ln_pop + ln_pers_inc +
    glm_proactive + state_ltgo_allowed + state_go_vote + high_state_tax_privilege +
    ln_amount + ln_maturity_mths + callable + sinkable + insured + rated +
    dpc_matched + dpc_education + dpc_transportation + dpc_utilities +
    dpc_public_safety + dpc_recreation + dpc_economic_development +
    dpc_other_public_buildings + dpc_other + dpc_refunding +
    has_primary_underwriter + has_lead_underwriter + has_placement_agent +
    ln_1p_n_co_managers + ln_1p_n_syndicate_members +
    primary_underwriter_national_top10 + primary_underwriter_state_top10 +
    primary_underwriter_national_amount_share_max +
    primary_underwriter_state_amount_share_max |
    yrmonth + purp_broad,
  data = full_sample[revenue == 1],
  vcov = vcov_cluster(~issue_id)
)

table_call <- etable(
  r_all,
  r_utgo,
  r_ltgo,
  r_revenue,
  headers = c('All bonds', 'UTGO', 'LTGO', 'Revenue'),
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c('Yes', 'No')),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = c(
    offering_yield_spread_tr = 'Yield Spread',
    city_go_vote = 'GO Vote',
    ln_amount = 'ln(Amount)',
    ln_maturity_mths = 'ln(Maturity)',
    callable = 'Callable',
    sinkable = 'Sinkable',
    insured = 'Insured',
    rated = 'Rated',
    ln_gdp = 'County ln(GDP)',
    ln_pop = 'County ln(Pop)',
    ln_pers_inc = 'County ln(Pers. Inc)',
    glm_proactive = 'Proactive State',
    state_ltgo_allowed = 'LTGO Allowed',
    state_go_vote = 'State GO Vote',
    high_state_tax_privilege = 'High Tax Priv.',
    dpc_matched = 'DPC Matched',
    dpc_education = 'DPC Education',
    dpc_transportation = 'DPC Transportation',
    dpc_utilities = 'DPC Utilities',
    dpc_public_safety = 'DPC Public Safety',
    dpc_recreation = 'DPC Recreation',
    dpc_economic_development = 'DPC Econ. Dev.',
    dpc_other_public_buildings = 'DPC Public Bldg.',
    dpc_other = 'DPC Other',
    dpc_refunding = 'DPC Refunding',
    has_primary_underwriter = 'Primary Underwriter',
    has_lead_underwriter = 'Lead Underwriter',
    has_placement_agent = 'Placement Agent',
    ln_1p_n_co_managers = 'ln(1 + Co-Managers)',
    ln_1p_n_syndicate_members = 'ln(1 + Syndicate Members)',
    primary_underwriter_national_top10 = 'National Top 10 Underwriter',
    primary_underwriter_state_top10 = 'State Top 10 Underwriter',
    primary_underwriter_national_amount_share_max = 'National UW Amt. Share',
    primary_underwriter_state_amount_share_max = 'State UW Amt. Share',
    yrmonth = 'YM',
    purp_broad = 'Purpose',
    issue_id = 'Issue'
  ),
  placement = 'H'
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)

modified_output <- format_table(modified_output, cluster_level = 'Issue')
modified_output <- add_panel(modified_output, 'Panel A: Bond-level offering yield spreads')

writeLines(modified_output, file.path(tbl_dir, 'bond_level_yield_spreads.tex'))
