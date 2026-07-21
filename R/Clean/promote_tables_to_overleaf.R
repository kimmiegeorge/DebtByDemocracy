#!/usr/bin/env Rscript

# Copy clean table outputs into the Overleaf clean/raw table folder when ready.
# Dry-run is the default. Use --apply to copy, and --overwrite to replace files
# that already exist in Overleaf.

args <- commandArgs(trailingOnly = TRUE)

has_flag <- function(flag) flag %in% args
get_arg <- function(prefix, default) {
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) {
    return(default)
  }
  sub(prefix, '', hit[[length(hit)]], fixed = TRUE)
}

file_arg <- grep('^--file=', commandArgs(FALSE), value = TRUE)
script_path <- if (length(file_arg) > 0) {
  normalizePath(sub('^--file=', '', file_arg[[1]]), mustWork = FALSE)
} else {
  normalizePath(file.path(getwd(), 'R/Clean/promote_tables_to_overleaf.R'), mustWork = FALSE)
}
repo_root <- normalizePath(file.path(dirname(script_path), '..', '..'), mustWork = FALSE)
default_source <- file.path(repo_root, 'R/Clean/output/revision_tables')
default_dest <- path.expand('~/Dropbox/Apps/Overleaf/Voting on bonds/tables/clean/raw')

source_dir <- normalizePath(get_arg('--source=', default_source), mustWork = TRUE)
dest_dir <- normalizePath(get_arg('--dest=', default_dest), mustWork = FALSE)
apply_changes <- has_flag('--apply')
overwrite <- has_flag('--overwrite')
recursive <- has_flag('--recursive')

if (has_flag('--help') || has_flag('-h')) {
  cat(
    'Usage:\n',
    '  Rscript R/Clean/promote_tables_to_overleaf.R [--apply] [--overwrite] [--recursive]\n\n',
    'Defaults:\n',
    paste0('  --source=', default_source, '\n'),
    paste0('  --dest=', default_dest, '\n\n'),
    'Examples:\n',
    '  Rscript R/Clean/promote_tables_to_overleaf.R\n',
    '  Rscript R/Clean/promote_tables_to_overleaf.R --apply --overwrite\n',
    sep = ''
  )
  quit(status = 0)
}

if (!dir.exists(source_dir)) {
  stop('Source directory does not exist: ', source_dir)
}

table_files <- list.files(source_dir, pattern = '\\.tex$', recursive = recursive, full.names = TRUE)
table_files <- table_files[!grepl('/robustness/', table_files, fixed = TRUE)]
table_files <- sort(table_files)

if (length(table_files) == 0) {
  stop('No .tex files found in source directory: ', source_dir)
}

relative_paths <- substring(table_files, nchar(source_dir) + 2)
target_files <- file.path(dest_dir, relative_paths)

file_status <- data.frame(
  source = table_files,
  target = target_files,
  relative_path = relative_paths,
  target_exists = file.exists(target_files),
  stringsAsFactors = FALSE
)

source_hash <- tools::md5sum(file_status$source)
target_hash <- rep(NA_character_, nrow(file_status))
target_hash[file_status$target_exists] <- tools::md5sum(file_status$target[file_status$target_exists])
file_status$changed <- is.na(target_hash) | source_hash != target_hash
file_status$action <- ifelse(
  !file_status$changed,
  'unchanged',
  ifelse(file_status$target_exists & !overwrite, 'skip-existing', 'copy')
)

cat('Source: ', source_dir, '\n', sep = '')
cat('Destination: ', dest_dir, '\n', sep = '')
cat('Mode: ', if (apply_changes) 'apply' else 'dry-run', '\n', sep = '')
cat('Overwrite existing: ', overwrite, '\n\n', sep = '')

print(file_status[, c('relative_path', 'action')], row.names = FALSE)

if (!apply_changes) {
  cat('\nDry run only. Re-run with --apply to copy tables.\n')
  quit(status = 0)
}

to_copy <- file_status[file_status$action == 'copy', ]
if (nrow(to_copy) == 0) {
  cat('\nNo files to copy.\n')
  quit(status = 0)
}

target_dirs <- unique(dirname(to_copy$target))
missing_dirs <- target_dirs[!dir.exists(target_dirs)]
if (length(missing_dirs) > 0) {
  dir.create(missing_dirs, recursive = TRUE, showWarnings = FALSE)
}

copied <- file.copy(to_copy$source, to_copy$target, overwrite = overwrite)
if (!all(copied)) {
  failed <- to_copy$relative_path[!copied]
  stop('Failed to copy: ', paste(failed, collapse = ', '))
}

cat('\nCopied ', sum(copied), ' table file(s).\n', sep = '')
