#!/usr/bin/env Rscript

# R1-01: Build the response-only R3.b table from the reviewed media-coverage
# supermajority output. The underlying regression remains in 02_media_coverage.R;
# this script removes the old panel heading and creates a printable wrapper for
# response_1.tex.

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep('^--file=', args, value = TRUE)
script_path <- if (length(file_arg) > 0L) {
  normalizePath(sub('^--file=', '', file_arg[[1L]]), mustWork = TRUE)
} else {
  normalizePath('Code/R/Clean/r1_01_supermajority_response_table.R', mustWork = TRUE)
}

clean_dir <- dirname(script_path)
revision_dir <- file.path(clean_dir, 'output', 'revision_tables')
processed_dir <- file.path(clean_dir, 'output', 'processed')

media_source <- file.path(revision_dir, 'media_coverage_super_majority.tex')
media_output <- file.path(revision_dir, 'r3b_media_supermajority.tex')
wrapper_output <- file.path(processed_dir, 'supermajority_media_response.tex')

required_files <- c(media_source)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop(
    'Missing reviewed supermajority table output(s): ',
    paste(missing_files, collapse = ', '),
    '. Run 02_media_coverage.R first.'
  )
}

remove_panel_heading <- function(lines, old_heading, source_name) {
  hit <- which(grepl(old_heading, lines, fixed = TRUE))
  if (length(hit) != 1L) {
    stop(
      'Expected exactly one panel heading in ', source_name,
      '; found ', length(hit), '.'
    )
  }
  lines[-hit]
}

media_lines <- readLines(media_source, warn = FALSE)
media_lines <- remove_panel_heading(
  media_lines,
  'Panel C: Supermajority split',
  basename(media_source)
)

dir.create(revision_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(media_lines, media_output)

wrapper_lines <- c(
  '\\newpage',
  '\\begin{table}[H]\\centering',
  '\\caption*{\\textbf{Supermajority approval requirements and media coverage}}',
  '\\label{tab:super_media}',
  paste0(
    '\\parbox{\\textwidth}{This table tests whether a GO bond referendum ',
    'requirement is associated with media coverage of an issuance. ',
    "\\textit{Total Articles - 12mo} is a city's number of bond-related ",
    'articles in the 12 months leading up to the bond issuance. The table ',
    'reports specifications estimated using Poisson pseudo-maximum likelihood ',
    'regressions. This table adds the supermajority-state indicator to the ',
    'full-sample specification. All columns include fixed effects for the ',
    'issuance month and Mergent project purpose. z-statistics are reported in ',
    'parentheses, and standard errors are clustered by state. *, **, and *** ',
    'indicate statistical significance at the 10\\%, 5\\%, and 1\\% levels. ',
    'All variables are defined in \\textit{Appendix A}.}'
  ),
  '\\end{table}',
  '\\input{tables/clean/raw/r3b_media_supermajority}'
)

writeLines(wrapper_lines, wrapper_output)
