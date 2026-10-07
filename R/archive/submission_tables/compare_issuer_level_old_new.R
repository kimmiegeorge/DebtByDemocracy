# Compare state-level vote/sample coding in old and new issuer-level files
# -----------------------------------------------------------------------
rm(list = ls())

library(pacman)
p_load(data.table, haven)

data_wd <- "~/Dropbox/Voting on Bonds/Data/"
out_wd <- "~/Dropbox/Voting on Bonds/Results/"

old_file <- paste0(data_wd, "Mergent/Clean/260324_city_issuerlevel_yieldspread.dta")
new_file <- paste0(data_wd, "Mergent/Clean/260611_city_issuerlevel_yieldspread.dta")
out_file <- paste0(out_wd, "260611_issuer_level_state_vote_sample_compare.csv")

vars_keep <- c("state", "city_go_vote", "city_rev_vote", "insample")

collapse_values <- function(x) {
  vals <- sort(unique(x[!is.na(x)]))
  if (length(vals) == 0) {
    return(NA_character_)
  }
  paste(vals, collapse = ",")
}

load_state_vars <- function(path, suffix) {
  dt <- as.data.table(read_stata(path))
  missing_vars <- setdiff(vars_keep, names(dt))
  if (length(missing_vars) > 0) {
    stop("Missing variables in ", path, ": ", paste(missing_vars, collapse = ", "))
  }

  dt <- dt[, ..vars_keep]

  # Match the recoding used in debt_choice.r before comparison.
  dt[, city_rev_vote := ifelse(state == "MO", 1, city_rev_vote)]
  dt[, city_go_vote := ifelse(state == "RI", NA, city_go_vote)]

  state_dt <- dt[, .(
    issuer_rows = .N,
    city_go_vote = collapse_values(city_go_vote),
    city_rev_vote = collapse_values(city_rev_vote),
    insample = collapse_values(insample),
    n_city_go_vote_values = uniqueN(city_go_vote, na.rm = TRUE),
    n_city_rev_vote_values = uniqueN(city_rev_vote, na.rm = TRUE),
    n_insample_values = uniqueN(insample, na.rm = TRUE)
  ), by = state]

  setnames(
    state_dt,
    setdiff(names(state_dt), "state"),
    paste0(setdiff(names(state_dt), "state"), "_", suffix)
  )

  return(state_dt)
}

old_state <- load_state_vars(old_file, "old")
new_state <- load_state_vars(new_file, "new")

compare <- merge(old_state, new_state, by = "state", all = TRUE)

compare[, in_old := !is.na(issuer_rows_old)]
compare[, in_new := !is.na(issuer_rows_new)]

for (v in c("city_go_vote", "city_rev_vote", "insample")) {
  old_v <- paste0(v, "_old")
  new_v <- paste0(v, "_new")
  diff_v <- paste0(v, "_changed")

  compare[, (diff_v) := fifelse(
    in_old & in_new,
    fifelse(is.na(get(old_v)) & is.na(get(new_v)), FALSE, get(old_v) != get(new_v)),
    NA
  )]
}

compare[, any_changed := fifelse(
  in_old & in_new,
  city_go_vote_changed | city_rev_vote_changed | insample_changed,
  NA
)]

compare[, issuer_rows_delta := issuer_rows_new - issuer_rows_old]

setcolorder(compare, c(
  "state",
  "in_old",
  "in_new",
  "any_changed",
  "city_go_vote_changed",
  "city_rev_vote_changed",
  "insample_changed",
  setdiff(
    names(compare),
    c("state", "in_old", "in_new", "any_changed",
      "city_go_vote_changed", "city_rev_vote_changed", "insample_changed")
  )
))

setorder(compare, state)

fwrite(compare, out_file)

cat("Wrote state-level old/new comparison to:\n")
cat(out_file, "\n\n")

cat("Summary:\n")
print(compare[, .(
  states = .N,
  old_only = sum(in_old & !in_new),
  new_only = sum(!in_old & in_new),
  common = sum(in_old & in_new),
  changed_common_states = sum(any_changed, na.rm = TRUE)
)])

cat("\nChanged states:\n")
print(compare[any_changed == TRUE | in_old != in_new])
