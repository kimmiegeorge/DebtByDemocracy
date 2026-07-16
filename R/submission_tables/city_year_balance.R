# City-year balance table for reviewer response R5
rm(list = ls())

library(data.table)

root <- '/Users/kmunevar/Dropbox/Voting on Bonds'
overleaf_tbl_dir <- '/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on bonds/tables/revision_tables'

panel_file <- file.path(
  root,
  'Data/Mergent/Outstanding Debt/260709_issuer_year_outstanding_debt.csv'
)
border_file <- file.path(
  root,
  'Data/Border States/Border Matches All Mergent Data Expanded Set Buffer 100000 20260611.csv'
)
out_dir <- file.path(root, 'Results/R5 Balance')
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

as_num <- function(x) {
  as.numeric(x)
}

format_num <- function(x, digits = 2) {
  ifelse(
    is.na(x),
    '',
    formatC(x, format = 'f', digits = digits, big.mark = ',')
  )
}

stars <- function(p) {
  fifelse(
    is.na(p), '',
    fifelse(p < 0.01, '***', fifelse(p < 0.05, '**', fifelse(p < 0.10, '*', '')))
  )
}

escape_latex <- function(x) {
  x <- gsub('\\\\', '\\\\textbackslash{}', x)
  x <- gsub('&', '\\\\&', x)
  x <- gsub('%', '\\\\%', x)
  x <- gsub('_', '\\\\_', x)
  x
}

mean_diff_p <- function(dt, var) {
  x_treat <- dt[city_go_vote == 1, get(var)]
  x_control <- dt[city_go_vote == 0, get(var)]
  x_treat <- x_treat[!is.na(x_treat)]
  x_control <- x_control[!is.na(x_control)]

  p_val <- NA_real_
  if (length(x_treat) > 1 && length(x_control) > 1) {
    p_val <- tryCatch(
      t.test(x_treat, x_control)$p.value,
      error = function(e) NA_real_
    )
  }

  data.table(
    control_mean = mean(x_control, na.rm = TRUE),
    treat_mean = mean(x_treat, na.rm = TRUE),
    diff = mean(x_treat, na.rm = TRUE) - mean(x_control, na.rm = TRUE),
    p_value = p_val,
    n_control = length(x_control),
    n_treat = length(x_treat)
  )
}

make_balance_table <- function(dt, vars, labels, output_file, caption = NULL) {
  rows <- rbindlist(lapply(vars, function(v) mean_diff_p(dt, v)), idcol = 'row_id')
  rows[, variable := labels[row_id]]
  rows[, diff_stars := paste0(format_num(diff), stars(p_value))]

  table_rows <- rows[, paste0(
    escape_latex(variable), ' & ',
    format_num(control_mean), ' & ',
    format_num(treat_mean), ' & ',
    diff_stars, ' \\\\'
  )]

  n_control_city_year <- dt[city_go_vote == 0, .N]
  n_treat_city_year <- dt[city_go_vote == 1, .N]
  n_control_city <- uniqueN(dt[city_go_vote == 0, seed_issuer_id])
  n_treat_city <- uniqueN(dt[city_go_vote == 1, seed_issuer_id])

  lines <- c(
    '\\begin{table}[H]',
    '\\centering',
    if (!is.null(caption)) paste0('\\caption{', caption, '}') else NULL,
    '\\begin{tabular*}{\\textwidth}{@{\\extracolsep{\\fill}}lccc}',
    '\\toprule',
    ' & Control & Treat & Difference \\\\',
    '\\midrule',
    table_rows,
    '\\midrule',
    paste0('City-years & ', format(n_control_city_year, big.mark = ','), ' & ',
           format(n_treat_city_year, big.mark = ','), ' &  \\\\'),
    paste0('Cities & ', format(n_control_city, big.mark = ','), ' & ',
           format(n_treat_city, big.mark = ','), ' &  \\\\'),
    '\\bottomrule',
    '\\end{tabular*}',
    '\\begin{minipage}{\\textwidth}',
    '\\footnotesize Notes: This table reports city-year means by whether the city is in a state requiring city GO bond referendums. The difference column reports the treated-city mean minus the control-city mean. Stars denote significance from Welch two-sample t-tests: * $p<0.10$, ** $p<0.05$, *** $p<0.01$. Outstanding debt, GDP, and personal income are measured in millions of dollars; population is measured in thousands.',
    '\\end{minipage}',
    '\\end{table}'
  )

  writeLines(lines, output_file)
  rows[, .(variable, control_mean, treat_mean, diff, p_value, n_control, n_treat)]
}

#----------------------------
# Build city-year panel
#----------------------------
panel <- fread(panel_file)
panel[, seed_issuer_id := as.integer(as.numeric(seed_issuer_id))]
panel[, year := as.integer(as.numeric(year))]
panel[, city_go_vote := as.integer(as.numeric(city_go_vote))]
panel[, state_go_vote := as.integer(as.numeric(state_go_vote))]

num_cols <- intersect(
  names(panel),
  c(
    'total_outstanding_debt',
    'total_outstanding_debt_per_capita',
    'go_outstanding_debt',
    'strict_gg_revenue_outstanding_debt',
    'annual_pop',
    'annual_gdp',
    'annual_pers_inc',
    'annual_percap_inc',
    'ln_pop',
    'ln_gdp',
    'ln_pers_inc'
  )
)
panel[, (num_cols) := lapply(.SD, as_num), .SDcols = num_cols]

panel[, population := fifelse(!is.na(annual_pop), annual_pop, exp(ln_pop))]
panel[, gdp := fifelse(!is.na(annual_gdp), annual_gdp, exp(ln_gdp))]
panel[, personal_income := fifelse(!is.na(annual_pers_inc), annual_pers_inc, exp(ln_pers_inc))]

panel[, total_outstanding_debt_mil := total_outstanding_debt / 1e6]
panel[, total_outstanding_debt_pc := total_outstanding_debt_per_capita]
panel[, go_outstanding_debt_mil := go_outstanding_debt / 1e6]
panel[, strict_gg_revenue_outstanding_debt_mil := strict_gg_revenue_outstanding_debt / 1e6]
panel[, population_thou := population / 1e3]
panel[, gdp_mil := gdp / 1e3]
panel[, personal_income_mil := personal_income / 1e3]

city_year_panel <- panel[
  !is.na(city_go_vote),
  .(
    seed_issuer_id,
    seed_issuer,
    fips,
    state,
    state_name,
    year,
    city_go_vote,
    state_go_vote,
    total_outstanding_debt,
    total_outstanding_debt_mil,
    total_outstanding_debt_pc,
    go_outstanding_debt,
    go_outstanding_debt_mil,
    strict_gg_revenue_outstanding_debt,
    strict_gg_revenue_outstanding_debt_mil,
    population,
    population_thou,
    gdp,
    gdp_mil,
    personal_income,
    personal_income_mil
  )
]

border <- fread(border_file)
border[, seed_issuer_id := as.integer(as.numeric(seed_issuer_id))]
border <- border[
  ,
  .(
    group = paste(sort(unique(group)), collapse = '; '),
    category = paste(sort(unique(category)), collapse = '; ')
  ),
  by = seed_issuer_id
]
border[, border_sample := 1L]

city_year_panel <- border[
  city_year_panel,
  on = 'seed_issuer_id'
]
city_year_panel[is.na(border_sample), border_sample := 0L]

fwrite(
  city_year_panel,
  file.path(out_dir, '260713_city_year_balance_panel.csv')
)

#----------------------------
# Balance tables
#----------------------------
balance_vars <- c(
  'total_outstanding_debt_mil',
  'total_outstanding_debt_pc',
  'go_outstanding_debt_mil',
  'strict_gg_revenue_outstanding_debt_mil',
  'population_thou',
  'gdp_mil',
  'personal_income_mil'
)

balance_labels <- c(
  'Outstanding debt',
  'Outstanding debt per capita',
  'GO outstanding debt',
  'Strict revenue outstanding debt',
  'Population',
  'GDP',
  'Personal income'
)

border_table_data <- city_year_panel[
  border_sample == 1 &
    !is.na(group) &
    group != 'Rhode Island/Massachusetts'
]
full_table_data <- city_year_panel

border_stats <- make_balance_table(
  border_table_data,
  balance_vars,
  balance_labels,
  file.path(out_dir, '260713_city_year_balance_border_sample.tex'),
  caption = 'City-year balance: border sample'
)
fwrite(
  border_stats,
  file.path(out_dir, '260713_city_year_balance_border_sample.csv')
)

full_stats <- make_balance_table(
  full_table_data,
  balance_vars,
  balance_labels,
  file.path(out_dir, '260713_city_year_balance_full_sample.tex'),
  caption = 'City-year balance: full sample'
)
fwrite(
  full_stats,
  file.path(out_dir, '260713_city_year_balance_full_sample.csv')
)

if (dir.exists(overleaf_tbl_dir)) {
  file.copy(
    file.path(out_dir, '260713_city_year_balance_border_sample.tex'),
    file.path(overleaf_tbl_dir, 'city_year_balance_border_sample.tex'),
    overwrite = TRUE
  )
  file.copy(
    file.path(out_dir, '260713_city_year_balance_full_sample.tex'),
    file.path(overleaf_tbl_dir, 'city_year_balance_full_sample.tex'),
    overwrite = TRUE
  )
}
