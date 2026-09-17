# Canonical state-border pair definitions used by every active paper regression.
# The CSV is also read by the Python border-sample builder, making it the
# cross-language source of truth for pair inclusion.

border_pair_config_file <- file.path(
  '/Users/kmunevar/Dropbox/Voting on Bonds',
  'Code/Config/border_state_pairs.csv'
)

border_pair_config <- data.table::fread(border_pair_config_file)
paper_border_pairs <- border_pair_config[
  include_in_paper == 1L,
  as.character(group)
]
debt_yield_border_pairs <- border_pair_config[
  include_debt_yield == 1L,
  as.character(group)
]
point_2017_border_pairs <- debt_yield_border_pairs

filter_paper_border_pairs <- function(data, group_column = 'group') {
  if (!data.table::is.data.table(data)) {
    data <- data.table::as.data.table(data)
  }
  if (!group_column %in% names(data)) {
    stop(sprintf('Missing border-pair column: %s', group_column))
  }
  data[get(group_column) %chin% paper_border_pairs]
}

filter_debt_yield_border_pairs <- function(data, group_column = 'group') {
  if (!data.table::is.data.table(data)) {
    data <- data.table::as.data.table(data)
  }
  if (!group_column %in% names(data)) {
    stop(sprintf('Missing border-pair column: %s', group_column))
  }
  data[get(group_column) %chin% debt_yield_border_pairs]
}

filter_point_2017_border_pairs <- function(data, group_column = 'border_group') {
  filter_debt_yield_border_pairs(data, group_column)
}

assert_paper_border_pairs <- function(data, group_column = 'group') {
  observed <- unique(as.character(data[[group_column]]))
  unexpected <- setdiff(observed[!is.na(observed)], paper_border_pairs)
  if (length(unexpected) > 0L) {
    stop(sprintf(
      'Non-paper border pairs remain in the estimation sample: %s',
      paste(sort(unexpected), collapse = ', ')
    ))
  }
  invisible(TRUE)
}

assert_debt_yield_border_pairs <- function(data, group_column = 'group') {
  observed <- unique(as.character(data[[group_column]]))
  unexpected <- setdiff(observed[!is.na(observed)], debt_yield_border_pairs)
  if (length(unexpected) > 0L) {
    stop(sprintf(
      'Non-debt/yield border pairs remain in the estimation sample: %s',
      paste(sort(unexpected), collapse = ', ')
    ))
  }
  invisible(TRUE)
}
