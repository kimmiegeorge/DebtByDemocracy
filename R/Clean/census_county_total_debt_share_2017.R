# 2017 county-level city share of total Census debt outstanding
rm(list = ls())

library(data.table)
library(fixest)

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
processed_dir <- file.path(
  root,
  'Data/Clean_Intermediate/Census COG Finance/processed'
)
tbl_dir <- file.path(root, 'Code/R/Clean/output/revision_tables')

source(file.path(root, 'Code/R/Clean/modify_etable_rounding.R'))
source(file.path(root, 'Code/R/Clean/tax_privilege_definitions.R'))

# Aggregate total end-of-year Census debt for all city and township governments
# in each county. Total debt is long-term plus short-term debt outstanding.
city_panel <- fread(
  file.path(processed_dir, 'census_cog_city_debt_panel.csv')
)
city_county <- city_panel[
  year == 2017 & government_type %in% c(2, 3),
  .(
    city_governments = .N,
    city_total_debt_dollars = sum(
      as.numeric(total_end_debt_outstanding_dollars),
      na.rm = TRUE
    )
  ),
  by = .(year, state, county_fips)
]

# The existing Census summary contains total debt for county, special-district,
# and school-district governments in each county.
noncity_county <- fread(
  file.path(processed_dir, 'census_cog_county_nonmunicipal_debt_summary.csv')
)[
  year == 2017,
  .(
    year,
    state,
    county_fips,
    noncity_total_debt_dollars =
      as.numeric(county_nonmunicipal_total_end_debt_outstanding_dollars)
  )
]

# Reuse the county policy flags and BEA controls constructed for the county
# issuance analysis. Keep one observation per county.
county_controls <- fread(
  file.path(processed_dir, 'census_cog_county_debt_issuance_2017.csv')
)
county_controls <- unique(
  county_controls[, .(
    year,
    state,
    county_fips,
    insample_state,
    city_go_vote,
    state_go_vote,
    state_ltgo_allowed,
    glm_proactive,
    ln_county_gdp,
    ln_county_population,
    ln_county_pers_inc
  )],
  by = c('year', 'state', 'county_fips')
)

county_data <- merge(
  county_controls,
  city_county,
  by = c('year', 'state', 'county_fips'),
  all.x = TRUE
)
county_data <- merge(
  county_data,
  noncity_county,
  by = c('year', 'state', 'county_fips'),
  all.x = TRUE
)

county_data[is.na(city_governments), city_governments := 0L]
county_data[is.na(city_total_debt_dollars), city_total_debt_dollars := 0]
county_data[is.na(noncity_total_debt_dollars), noncity_total_debt_dollars := 0]
county_data[, all_local_total_debt_dollars :=
  city_total_debt_dollars + noncity_total_debt_dollars]
county_data[, city_total_debt_share := fifelse(
  all_local_total_debt_dollars > 0,
  city_total_debt_dollars / all_local_total_debt_dollars,
  NA_real_
)]

add_low_state_tax_privilege(county_data, year_value = 2017)

regression_data <- county_data[
  insample_state == 1 &
    city_governments > 0 &
    all_local_total_debt_dollars > 0 &
    !is.na(city_total_debt_share) &
    !is.na(ln_county_gdp) &
    !is.na(ln_county_population) &
    !is.na(ln_county_pers_inc) &
    !is.na(glm_proactive) &
    !is.na(state_ltgo_allowed) &
    !is.na(state_go_vote) &
    !is.na(low_state_tax_privilege)
]

r1_2017_county_total_share <- feols(
  city_total_debt_share ~ city_go_vote,
  data = regression_data,
  vcov = vcov_cluster(~state)
)

r2_2017_county_total_share <- feols(
  city_total_debt_share ~ city_go_vote +
    ln_county_gdp + ln_county_population + ln_county_pers_inc +
    glm_proactive + state_ltgo_allowed + state_go_vote + low_state_tax_privilege,
  data = regression_data,
  vcov = vcov_cluster(~state)
)

print(summary(r1_2017_county_total_share))
print(summary(r2_2017_county_total_share))

cat('\nOutcome summary by city GO vote requirement:\n')
print(
  regression_data[, .(
    counties = .N,
    mean_city_share = mean(city_total_debt_share),
    median_city_share = median(city_total_debt_share),
    total_city_debt_mil = sum(city_total_debt_dollars) / 1000000,
    total_noncity_debt_mil = sum(noncity_total_debt_dollars) / 1000000
  ), by = city_go_vote]
)

control_dict <- c(
  city_total_debt_share = 'Pct City Total Debt',
  city_go_vote = 'GO Vote',
  ln_county_gdp = 'County ln(GDP)',
  ln_county_population = 'County ln(Pop)',
  ln_county_pers_inc = 'County ln(Pers. Inc)',
  glm_proactive = 'Proactive State',
  state_ltgo_allowed = 'LTGO Allowed',
  state_go_vote = 'State GO Vote',
  low_state_tax_privilege = 'Low Tax Priv.'
)

table_call <- etable(
  r1_2017_county_total_share,
  r2_2017_county_total_share,
  coefstat = 'tstat',
  drop = 'Constant',
  style.tex = style.tex(
    main = 'aer',
    fixef.suffix = ' FE',
    yesNo = c('Yes', 'No')
  ),
  fitstat = c('n', 'ar2'),
  se.below = TRUE,
  digits = 3,
  digits.stats = 3,
  signif.code = c('***' = 0.01, '**' = 0.05, '*' = 0.10),
  tex = TRUE,
  order = c('%city_go_vote'),
  dict = control_dict,
  placement = 'H'
)

modified_output <- modify_etable_rounding(
  table_call,
  coef_digits = 3,
  tstat_digits = 2
)
modified_output <- format_table(modified_output, cluster_level = 'State')
modified_output <- add_panel(
  modified_output,
  'Panel A: 2017 city share of county total Census debt',
  ncols = 3
)

output_file <- file.path(
  tbl_dir,
  'point_in_time_county_city_total_debt_share_2017.tex'
)
writeLines(modified_output, output_file)
cat('\nWrote regression table to:', output_file, '\n')
