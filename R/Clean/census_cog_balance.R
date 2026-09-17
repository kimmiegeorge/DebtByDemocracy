# Census of Governments municipal debt balance table
rm(list = ls())

library(data.table)

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
source(file.path(root, 'Code/R/Clean/border_pair_definitions.R'))
census_dir <- file.path(root, 'Data/Clean_Intermediate/Census COG Finance')
out_dir <- file.path(root, 'Results/R5 Balance')
overleaf_tbl_dir <- '/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/output/revision_tables'

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

panel_file <- file.path(census_dir, 'processed/census_cog_city_debt_panel.csv')
match_file <- file.path(census_dir, 'diagnostics/census_cog_2022_mergent_exact_matches.csv')
border_file <- file.path(
  root,
  'Data/Clean_Intermediate/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000.csv'
)

format_num <- function(x, digits = 2) {
  ifelse(
    is.na(x),
    '',
    formatC(x, format = 'f', digits = digits, big.mark = ',')
  )
}

stars <- function(p) {
  fifelse(
    is.na(p),
    '',
    fifelse(p < 0.01, '***', fifelse(p < 0.05, '**', fifelse(p < 0.10, '*', '')))
  )
}

mean_diff_p <- function(dt, var) {
  treat <- dt[city_go_vote == 1, get(var)]
  control <- dt[city_go_vote == 0, get(var)]
  treat <- treat[!is.na(treat)]
  control <- control[!is.na(control)]

  p_value <- NA_real_
  if (length(treat) > 1 && length(control) > 1) {
    p_value <- tryCatch(
      t.test(treat, control)$p.value,
      error = function(e) NA_real_
    )
  }

  data.table(
    control_mean = mean(control, na.rm = TRUE),
    treat_mean = mean(treat, na.rm = TRUE),
    diff = mean(treat, na.rm = TRUE) - mean(control, na.rm = TRUE),
    p_value = p_value,
    n_control = length(control),
    n_treat = length(treat)
  )
}

panel <- fread(panel_file)
matches <- fread(match_file)

matches[, city_go_vote := as.integer(as.numeric(city_go_vote))]
matches <- matches[
  !is.na(city_go_vote),
  .(
    seed_issuer_id = round(as.numeric(seed_issuer_id), 1),
    seed_issuer,
    state,
    county_fips = as.character(county_fips),
    issuer_city_clean,
    city_go_vote,
    insample = as.integer(insample),
    insample_allgo = as.integer(insample_allgo),
    insample_utgo_only = as.integer(insample_utgo_only),
    gov_id,
    match_type
  )
]
matches <- unique(matches, by = c('seed_issuer_id', 'state', 'seed_issuer'))

panel[, census_city_clean := as.character(census_city_clean)]
panel[, state := as.character(state)]
panel[, county_fips := as.character(county_fips)]

county_matches <- matches[
  match_type == 'state_county_name',
  .(
    seed_issuer_id,
    seed_issuer,
    state,
    county_fips,
    census_city_clean = issuer_city_clean,
    city_go_vote,
    insample,
    insample_allgo,
    insample_utgo_only,
    match_type
  )
]

state_matches <- matches[
  match_type == 'state_name',
  .(
    seed_issuer_id,
    seed_issuer,
    state,
    census_city_clean = issuer_city_clean,
    city_go_vote,
    insample,
    insample_allgo,
    insample_utgo_only,
    match_type
  )
]

balance_county <- county_matches[
  panel,
  on = .(state, county_fips, census_city_clean),
  nomatch = 0,
  allow.cartesian = TRUE
]

matched_keys <- unique(balance_county[, .(year, gov_id)])
remaining_panel <- panel[
  !matched_keys,
  on = .(year, gov_id)
]

balance_state <- state_matches[
  remaining_panel,
  on = .(state, census_city_clean),
  nomatch = 0,
  allow.cartesian = TRUE
]

balance_data <- rbindlist(
  list(balance_county, balance_state),
  fill = TRUE
)
balance_data <- unique(balance_data, by = c('year', 'seed_issuer_id', 'state', 'seed_issuer'))
balance_data <- balance_data[!is.na(city_go_vote)]
balance_data[, lt_outstanding_debt_mil := end_lt_debt_outstanding_dollars / 1e6]
balance_data[, outstanding_debt_mil := total_end_debt_outstanding_dollars / 1e6]
balance_data[, population_thou := population / 1e3]

border <- fread(border_file)
border <- filter_paper_border_pairs(border)
border[, seed_issuer_id := round(as.numeric(seed_issuer_id), 1)]
border <- unique(border[, .(state, seed_issuer, border_sample = 1L)])
balance_data <- border[
  balance_data,
  on = .(state, seed_issuer)
]
balance_data[is.na(border_sample), border_sample := 0L]

fwrite(
  balance_data,
  file.path(out_dir, 'census_cog_city_debt_balance_data.csv')
)

vars <- c(
  'lt_outstanding_debt_mil',
  'outstanding_debt_mil',
  'total_end_debt_per_capita',
  'population_thou'
)
labels <- c(
  'Long-term debt outstanding',
  'Total outstanding debt',
  'Total outstanding debt per capita',
  'Population'
)

write_balance_table <- function(dt, slug, caption, note_sample) {
  rows <- rbindlist(
    lapply(sort(unique(dt$year)), function(y) {
      year_data <- dt[year == y]
      out <- rbindlist(lapply(vars, function(v) mean_diff_p(year_data, v)), idcol = 'row_id')
      out[, year := y]
      out[, variable := labels[row_id]]
      out
    })
  )

  fwrite(
    rows[, .(year, variable, control_mean, treat_mean, diff, p_value, n_control, n_treat)],
    file.path(out_dir, paste0(slug, '_table.csv'))
  )

  table_lines <- c(
    '\\begin{table}[H]',
    '\\centering',
    paste0('\\caption{', caption, '}'),
    '\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}llccc}',
    '\\toprule',
    'Year & Variable & Control & Treat & Difference \\\\',
    '\\midrule'
  )

  for (y in sort(unique(rows$year))) {
    y_rows <- rows[year == y]
    for (i in seq_len(nrow(y_rows))) {
      year_label <- ifelse(i == 1, as.character(y), '')
      table_lines <- c(
        table_lines,
        paste0(
          year_label, ' & ',
          y_rows[i, variable], ' & ',
          format_num(y_rows[i, control_mean]), ' & ',
          format_num(y_rows[i, treat_mean]), ' & ',
          format_num(y_rows[i, diff]), stars(y_rows[i, p_value]), ' \\\\'
        )
      )
    }
    if (y != max(rows$year)) {
      table_lines <- c(table_lines, '\\addlinespace')
    }
  }

  n_rows <- dt[
    ,
    .(
      control = sum(city_go_vote == 0),
      treat = sum(city_go_vote == 1),
      control_issuers = uniqueN(seed_issuer_id[city_go_vote == 0]),
      treat_issuers = uniqueN(seed_issuer_id[city_go_vote == 1])
    ),
    by = year
  ]

  table_lines <- c(table_lines, '\\midrule')

  for (y in sort(unique(n_rows$year))) {
    table_lines <- c(
      table_lines,
      paste0(
        y, ' municipalities &  & ',
        format(n_rows[year == y, control], big.mark = ','), ' & ',
        format(n_rows[year == y, treat], big.mark = ','), ' &  \\\\'
      )
    )
  }

  table_lines <- c(
    table_lines,
    '\\bottomrule',
    '\\end{tabular*}',
    '\\begin{minipage}{\\textwidth}',
    paste0(
      '\\footnotesize Notes: This table reports means for Census of Governments municipal units ',
      note_sample,
      '. Treat equals one when the Mergent issuer is in a state requiring city GO bond referendums. Difference is treated minus control. Stars denote Welch two-sample t-tests: * $p<0.10$, ** $p<0.05$, *** $p<0.01$. Long-term debt outstanding is Census item 49U. Total outstanding debt is end-of-year long-term plus short-term debt, in millions of dollars. Population is in thousands.'
    ),
    '\\end{minipage}',
    '\\end{table}'
  )

  tex_file <- file.path(out_dir, paste0('260713_', slug, '.tex'))
  writeLines(table_lines, tex_file)

  if (dir.exists(overleaf_tbl_dir)) {
    file.copy(
      tex_file,
      file.path(overleaf_tbl_dir, paste0(slug, '.tex')),
      overwrite = TRUE
    )
  }
}

write_balance_table(
  balance_data,
  'census_cog_city_debt_balance',
  'Census of Governments municipal debt balance',
  'matched to the Mergent issuer-level sample'
)

write_balance_table(
  balance_data[border_sample == 1],
  'census_cog_city_debt_balance_border_sample',
  'Census of Governments municipal debt balance: border sample',
  'matched to the Mergent border-city sample'
)
