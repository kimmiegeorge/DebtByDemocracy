# 00: Babina et al. (2021, RFS), Table 2. "Low tax privilege" is defined as
# membership in the fourth or bottom quintile of average state tax privilege.
# Share the same definitions with Python regression-data preparation.
tax_privilege_config <- data.table::fread(
  '/Users/kmunevar/Dropbox/Voting on Bonds/Code/Config/low_state_tax_privilege_states.csv'
)
babina_fourth_privilege_quintile_states <- tax_privilege_config[
  quintile == 4L, state
]
babina_bottom_privilege_quintile_states <- tax_privilege_config[
  quintile == 5L, state
]

low_state_tax_privilege_states <- c(
  babina_fourth_privilege_quintile_states,
  babina_bottom_privilege_quintile_states
)

add_low_state_tax_privilege <- function(data, ...) {
  if (!data.table::is.data.table(data)) {
    stop('data must be a data.table.')
  }
  if (!('state' %in% names(data))) {
    stop('data must contain a state column.')
  }

  data[, low_state_tax_privilege := as.integer(
    state %in% low_state_tax_privilege_states
  )]

  invisible(data)
}
