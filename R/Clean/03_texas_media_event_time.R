# 03: Texas bond-election and issuance event-time media plot (associated with Table 4)
#
# This script compares the probability that a Texas city receives any
# bond-related RavenPack coverage around:
#   1. a city bond-election month; and
#   2. a city GO-bond offering month.
#
# Each bond proposition is a separate election observation. Propositions held
# in the same city-month share the same monthly media outcome but each receives
# its own weight in the election average. Multiple GO issues in the same
# city-offering month remain one issuance event. The default -18 to +18-month
# sample is balanced.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(haven)
})

# -----------------------------------------------------------------------------
# Configuration and paths
# -----------------------------------------------------------------------------

event_radius <- 18L
baseline_months <- -18L:-13L
winsor_upper_probability <- 0.99

# The upstream RavenPack builder keeps articles strictly after 2000-12-31 and
# strictly before 2021-01-01. Months outside this range appear as zero in the
# broader Texas panel and therefore must not enter this analysis.
news_start <- as.IDate('2001-01-01')
news_end <- as.IDate('2020-12-01')

find_project_root <- function(start_dir) {
  candidate <- normalizePath(start_dir, mustWork = TRUE)
  repeat {
    has_data <- file.exists(file.path(
      candidate,
      'Data/Clean_Intermediate/TX/City_Month_Elections_News_WithFailed.csv'
    ))
    has_code <- dir.exists(file.path(candidate, 'Code/R/Clean'))
    if (has_data && has_code) {
      return(candidate)
    }

    parent <- dirname(candidate)
    if (identical(parent, candidate)) {
      stop('Could not locate the Voting on Bonds project root.')
    }
    candidate <- parent
  }
}

script_arg <- grep('^--file=', commandArgs(trailingOnly = FALSE), value = TRUE)
start_dir <- if (length(script_arg) == 1L) {
  dirname(normalizePath(sub('^--file=', '', script_arg), mustWork = TRUE))
} else {
  getwd()
}

root <- find_project_root(start_dir)
panel_path <- file.path(
  root,
  'Data/Clean_Intermediate/TX/City_Month_Elections_News_WithFailed.csv'
)
election_level_path <- file.path(
  root,
  'Data/Clean_Intermediate/TX/News/Election_Level_With_News_WithFailed.csv'
)
issuance_path <- file.path(root, 'Data/TX/241120_tx_issue_level.dta')
fig_dir <- file.path(root, 'Code/R/Clean/output/revision_figures')
processed_dir <- file.path(root, 'Code/R/Clean/output/processed')

dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

assert_columns <- function(data, required, data_name) {
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns) > 0L) {
    stop(sprintf(
      '%s is missing required columns: %s',
      data_name,
      paste(missing_columns, collapse = ', ')
    ))
  }
}

normalize_issuer <- function(x) {
  tolower(gsub('\\s+', ' ', trimws(x)))
}

# -----------------------------------------------------------------------------
# City-month media panel and election events
# -----------------------------------------------------------------------------

city_month <- fread(panel_path)
assert_columns(
  city_month,
  c(
    'seed_issuer', 'year', 'month', 'rp_article_count',
    'has_bond_election', 'num_bond_elections',
    'ln_county_employment_prior'
  ),
  'Texas city-month media panel'
)

city_month[, seed_issuer := normalize_issuer(seed_issuer)]

# Match the issuer restriction used by the clean Texas city-month regression:
# retain issuers that have at least one election with a positive number of
# RavenPack sources in the prior 12 months, and require the city-month county
# employment control to be observed.
election_level <- fread(election_level_path)
assert_columns(
  election_level,
  c('seed_issuer', 'unique_sources_12m_prior'),
  'Texas election-level media data'
)
election_level[, seed_issuer := normalize_issuer(seed_issuer)]
regression_eligible_issuers <- unique(election_level[
  unique_sources_12m_prior > 0,
  seed_issuer
])
city_month <- city_month[
  seed_issuer %in% regression_eligible_issuers &
    !is.na(ln_county_employment_prior)
]

city_month[, month_date := as.IDate(sprintf('%04d-%02d-01', year, month))]
city_month <- city_month[month_date >= news_start & month_date <= news_end]
city_month[, year_month_id := year * 12L + month]
city_month[, any_bond_coverage := as.integer(rp_article_count > 0)]

# Winsorize before expanding event windows so the cutoff is calculated once
# per unique city-month rather than giving overlapping event windows extra
# weight. The lower 1st percentile is zero, so two-sided 1/99 winsorization is
# equivalent here to imposing only the upper cap.
article_count_winsor_cap <- as.numeric(quantile(
  city_month$rp_article_count,
  probs = winsor_upper_probability,
  na.rm = TRUE,
  type = 7
))
city_month[, rp_article_count_winsorized := pmin(
  rp_article_count,
  article_count_winsor_cap
)]

if (city_month[, anyDuplicated(paste(seed_issuer, year_month_id))] > 0L) {
  stop('The Texas media panel contains duplicate city-month keys.')
}
if (city_month[, any(is.na(rp_article_count))]) {
  stop('The Texas media panel contains missing bond-article counts.')
}

minimum_event_month <- min(city_month$year_month_id) + event_radius
maximum_event_month <- max(city_month$year_month_id) - event_radius

election_city_months <- unique(city_month[
  has_bond_election == 1L &
    year_month_id >= minimum_event_month &
    year_month_id <= maximum_event_month,
  .(
    seed_issuer,
    event_year_month_id = year_month_id,
    event_date = month_date,
    event_size = num_bond_elections
  )
])
if (election_city_months[, any(event_size < 1L | event_size != as.integer(event_size))]) {
  stop('Election event sizes must be positive integers.')
}

# Expand aggregated city-election months so each ballot proposition contributes
# one observation. Outcomes remain measured at the city-month level.
election_events <- election_city_months[
  , .(event_instance = seq_len(as.integer(event_size))),
  by = .(seed_issuer, event_year_month_id, event_date, event_size)
]
election_events[, event_type := 'Bond election']

# -----------------------------------------------------------------------------
# GO issuance events
# -----------------------------------------------------------------------------

# Offering dates are used instead of Texas BRB closing dates. Offering is the
# point at which an issue is marketed and public information is most likely to
# appear; closing can occur in the following month.
issuance <- as.data.table(read_dta(issuance_path))
assert_columns(
  issuance,
  c(
    'seed_issuer', 'offering_date', 'issue_id', 'city',
    'go_unlim', 'go_lim'
  ),
  'Texas issue-level data'
)

issuance[, seed_issuer := normalize_issuer(seed_issuer)]
issuance[, offering_date_clean := as.IDate(offering_date)]
issuance[, is_go :=
  fcoalesce(as.integer(go_unlim), 0L) == 1L |
    fcoalesce(as.integer(go_lim), 0L) == 1L]

go_issuance_sample <- issuance[
  city == 1L &
    is_go &
    !is.na(offering_date_clean) &
    seed_issuer %in% city_month$seed_issuer
]
go_issuance_sample[, event_year_month_id :=
  year(offering_date_clean) * 12L + month(offering_date_clean)]

issuance_events <- go_issuance_sample[
  event_year_month_id >= minimum_event_month &
    event_year_month_id <= maximum_event_month,
  .(
    event_date = min(as.IDate(format(offering_date_clean, '%Y-%m-01'))),
    event_size = uniqueN(issue_id)
  ),
  by = .(seed_issuer, event_year_month_id)
]
issuance_events[, event_instance := 1L]
issuance_events[, event_type := 'GO bond issuance']

if (nrow(election_events) == 0L || nrow(issuance_events) == 0L) {
  stop('At least one event sample is empty after applying the balanced window.')
}

# -----------------------------------------------------------------------------
# Expand each event to event time and merge media outcomes
# -----------------------------------------------------------------------------

expand_event_window <- function(events) {
  expanded <- events[
    , .(event_time = seq.int(-event_radius, event_radius)),
    by = .(
      seed_issuer, event_year_month_id, event_date, event_size,
      event_instance, event_type
    )
  ]
  expanded[, year_month_id := event_year_month_id + event_time]
  expanded[, event_id := paste(
    event_type,
    seed_issuer,
    event_year_month_id,
    event_instance,
    sep = '|'
  )]

  expanded <- merge(
    expanded,
    city_month[
      , .(
        seed_issuer, year_month_id, calendar_date = month_date,
        calendar_year = year, calendar_month = month,
        rp_article_count, rp_article_count_winsorized, any_bond_coverage
      )
    ],
    by = c('seed_issuer', 'year_month_id'),
    all.x = TRUE,
    sort = FALSE
  )

  expected_rows <- nrow(events) * (2L * event_radius + 1L)
  if (nrow(expanded) != expected_rows ||
      expanded[, any(is.na(any_bond_coverage))]) {
    stop(sprintf(
      'The %s event panel is not balanced after merging media outcomes.',
      unique(events$event_type)
    ))
  }

  expanded[]
}

event_panel <- rbindlist(list(
  expand_event_window(election_events),
  expand_event_window(issuance_events)
))

event_baselines <- event_panel[
  event_time %in% baseline_months,
  .(
    baseline_coverage = mean(any_bond_coverage),
    baseline_article_count = mean(rp_article_count)
  ),
  by = event_id
]
event_panel <- event_baselines[event_panel, on = 'event_id']
event_panel[, coverage_change_pp :=
  100 * (any_bond_coverage - baseline_coverage)]
event_panel[, article_count_change :=
  rp_article_count - baseline_article_count]

if (event_panel[, any(is.na(baseline_coverage) | is.na(baseline_article_count))]) {
  stop('An event is missing its pre-event baseline coverage rate.')
}

# -----------------------------------------------------------------------------
# Unbalanced three-month plot using the exact election-table sample
# -----------------------------------------------------------------------------

# Reproduce the election-level media table's estimation sample. fixest removes
# one fixed-effect singleton from the 700 complete positive-source observations,
# leaving the 699 propositions reported in tx_failed_and_margin.tex.
regression_election_candidates <- copy(election_level[
  unique_sources_12m_prior > 0 & !is.na(ln_county_gdp_prior)
])
regression_election_candidates[, coverage_3 := as.integer(
  articles_3m_before_to_election > 0
)]
regression_sample_model <- fixest::feols(
  failed ~ coverage_3 | year + purp_broad_new,
  data = regression_election_candidates,
  notes = FALSE
)
regression_election_sample <- regression_election_candidates[
  fixest::obs(regression_sample_model)
]
regression_election_sample[, event_date_clean := as.IDate(date_election)]
regression_election_sample[, event_year_month_id := year * 12L + month]

regression_election_events <- regression_election_sample[
  , .(
    event_instance = seq_len(.N),
    event_size = .N,
    event_date = min(as.IDate(format(event_date_clean, '%Y-%m-01')))
  ),
  by = .(seed_issuer, event_year_month_id)
]
regression_election_events[, event_type := 'Bond election']

# Keep every eligible GO offering month observed during the RavenPack window.
# Unlike the main event panel above, no +/-18-month balance restriction is
# imposed here.
unbalanced_issuance_events <- go_issuance_sample[
  event_year_month_id >= min(city_month$year_month_id) &
    event_year_month_id <= max(city_month$year_month_id),
  .(
    event_date = min(as.IDate(format(offering_date_clean, '%Y-%m-01'))),
    event_size = uniqueN(issue_id)
  ),
  by = .(seed_issuer, event_year_month_id)
]
unbalanced_issuance_events[, event_instance := 1L]
unbalanced_issuance_events[, event_type := 'GO bond issuance']

expand_unbalanced_count_window <- function(events) {
  expanded <- events[
    , .(event_time = -12L:11L),
    by = .(
      seed_issuer, event_year_month_id, event_date, event_size,
      event_instance, event_type
    )
  ]
  expanded[, year_month_id := event_year_month_id + event_time]
  expanded[, event_id := paste(
    event_type,
    seed_issuer,
    event_year_month_id,
    event_instance,
    sep = '|'
  )]

  expanded <- merge(
    expanded,
    city_month[
      , .(
        seed_issuer, year_month_id,
        rp_article_count_winsorized
      )
    ],
    by = c('seed_issuer', 'year_month_id'),
    all = FALSE,
    sort = FALSE
  )

  if (expanded[, uniqueN(event_id)] == 0L) {
    stop(sprintf(
      '%s events have no observed media months in the plotting window.',
      unique(events$event_type)
    ))
  }

  expanded[]
}

# -----------------------------------------------------------------------------
# City-clustered means and confidence intervals
# -----------------------------------------------------------------------------

# This is the CR1 city-clustered standard error for an intercept-only model.
# Clustering is important because cities can contribute multiple events.
clustered_mean <- function(outcome, cluster) {
  keep <- !is.na(outcome) & !is.na(cluster)
  outcome <- outcome[keep]
  cluster <- cluster[keep]
  estimate <- mean(outcome)
  n_obs <- length(outcome)

  scores <- data.table(cluster = cluster, residual = outcome - estimate)[
    , .(score = sum(residual)),
    by = cluster
  ]
  n_clusters <- nrow(scores)
  if (n_clusters < 2L) {
    stop('At least two city clusters are required for inference.')
  }

  standard_error <- sqrt(
    (n_clusters / (n_clusters - 1)) * sum(scores$score^2) / n_obs^2
  )

  list(
    estimate = estimate,
    standard_error = standard_error,
    conf_low = estimate - 1.96 * standard_error,
    conf_high = estimate + 1.96 * standard_error,
    observations = n_obs,
    cities = n_clusters
  )
}

summarize_clustered <- function(data, outcome_name, by_names) {
  data[
    , clustered_mean(get(outcome_name), seed_issuer),
    by = by_names
  ]
}

event_panel[, event_bin := fcase(
  event_time <= -16L, '-18 to -16',
  event_time <= -13L, '-15 to -13',
  event_time <= -10L, '-12 to -10',
  event_time <= -7L, '-9 to -7',
  event_time <= -4L, '-6 to -4',
  event_time <= -1L, '-3 to -1',
  event_time == 0L, '0',
  event_time <= 3L, '1 to 3',
  event_time <= 6L, '4 to 6',
  event_time <= 9L, '7 to 9',
  event_time <= 12L, '10 to 12',
  event_time <= 15L, '13 to 15',
  default = '16 to 18'
)]

bin_levels <- c(
  '-18 to -16', '-15 to -13', '-12 to -10', '-9 to -7',
  '-6 to -4', '-3 to -1', '0', '1 to 3', '4 to 6', '7 to 9',
  '10 to 12', '13 to 15', '16 to 18'
)
event_panel[, event_bin := factor(event_bin, levels = bin_levels)]

# First calculate one mean per city-event-bin. This prevents a three-month bin
# from receiving three times the weight of event month zero.
event_bin_panel <- event_panel[
  , .(bin_coverage = mean(any_bond_coverage)),
  by = .(event_type, event_id, seed_issuer, event_bin)
]
binned_summary <- summarize_clustered(
  event_bin_panel,
  'bin_coverage',
  c('event_type', 'event_bin')
)
# -----------------------------------------------------------------------------
# Figures
# -----------------------------------------------------------------------------

event_order <- c('Bond election', 'GO bond issuance')
binned_summary[, event_type := factor(event_type, levels = event_order)]

common_theme <- theme_minimal(base_size = 11, base_family = 'serif') +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    strip.text = element_text(face = 'bold'),
    legend.position = 'bottom',
    plot.title.position = 'plot',
    plot.caption = element_text(hjust = 0, size = 8.5),
    plot.caption.position = 'plot'
  )

binned_plot <- ggplot(
  binned_summary,
  aes(x = event_bin, y = estimate, linetype = event_type, group = event_type)
) +
  geom_line(linewidth = 1, color = 'black') +
  geom_point(size = 2, color = 'black') +
  scale_linetype_manual(
    values = c('Bond election' = 'solid', 'GO bond issuance' = 'dashed')
  ) +
  scale_y_continuous(
    labels = scales::label_number(accuracy = 0.01),
    expand = expansion(mult = c(0.02, 0.08))
  ) +
  labs(
    x = 'Months relative to event',
    y = expression(Mean~italic('Bond Coverage')),
    linetype = NULL
  ) +
  common_theme +
  theme(axis.text.x = element_text(angle = 35, hjust = 1))

save_figure <- function(plot, filename, width, height) {
  ggsave(
    file.path(fig_dir, paste0(filename, '.pdf')),
    plot = plot,
    width = width,
    height = height,
    units = 'in',
    bg = 'white'
  )
}

save_figure(binned_plot, 'texas_media_event_time_binned', 10, 5.7)
