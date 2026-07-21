# Babina et al. (2021, RFS), Table 2. "Low tax privilege" is defined as
# membership in the fourth or bottom quintile of average state tax privilege.
babina_fourth_privilege_quintile_states <- c(
  'MD', 'AL', 'MS', 'NH', 'AZ', 'CO', 'MI', 'UT', 'PA', 'FL'
)

babina_bottom_privilege_quintile_states <- c(
  'IN', 'AK', 'DC', 'IA', 'IL', 'NV', 'OK', 'TX', 'WA', 'WI'
)

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
