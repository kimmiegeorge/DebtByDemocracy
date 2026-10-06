# 00: Shared descriptive-table and media-header helpers.
# Load after data.table in the analysis scripts.

# Summarize a descriptive panel while keeping its unit and variable labels.
summarize_desc_cols <- function(dt, unit, labels) {
  desc_col <- dt[, lapply(.SD, function(col) {
    stats <- c(Unit = unit,
               Mean = mean(col, na.rm = TRUE),
               Std = sd(col, na.rm = TRUE),
               Min = min(col, na.rm = TRUE),
               p1 = quantile(col, probs = 0.01, na.rm = TRUE),
               Median = median(col, na.rm = TRUE),
               p99 = quantile(col, probs = 0.99, na.rm = TRUE),
               Max = max(col, na.rm = TRUE),
               N = sum(!is.na(col)))
    return(stats)
  }), .SDcols = colnames(dt)]
  desc_col <- data.table::transpose(desc_col, keep.names = "variable")
  colnames(desc_col) <- c("Variable", "Unit", "Mean", "Std", "Min", "P1", "Median", "P99", "Max", "N")
  desc_col[, Variable := labels]
  return(desc_col)
}

diff_table <- function(dt, group_var, vars) {
  out <- lapply(vars, function(v) {
    # t-test for difference
    ttest <- t.test(get(v) ~ get(group_var), data = dt)

    # compute group means
    means <- dt[, .(
      mean_0 = mean(get(v)[get(group_var) == 0], na.rm = TRUE),
      mean_1 = mean(get(v)[get(group_var) == 1], na.rm = TRUE)
    )]

    # extract stats
    pval <- ttest$p.value
    tstat <- round(ttest$statistic, 2)

    # significance stars
    stars <- if (pval < 0.01) "***"
    else if (pval < 0.05) "**"
    else if (pval < 0.1) "*"
    else ""

    data.table(
      variable = v,
      mean_0 = means$mean_0,
      mean_1 = means$mean_1,
      diff = round(means$mean_1 - means$mean_0, 2),
      tstat = tstat,
      pval = pval,
      n_0 = sum(!is.na(dt[get(group_var) == 0, get(v)])),
      n_1 = sum(!is.na(dt[get(group_var) == 1, get(v)])),
      stars = stars
    )
  })

  res <- rbindlist(out)

  # format columns
  res[, mean_0 := round(mean_0, 2)]
  res[, mean_1 := round(mean_1, 2)]
  res[, diff_fmt := sprintf("%.2f%s (%.2f)", get("diff"), stars, abs(tstat))]


  return(res)
}


add_media_sample_headers <- function(tex) {
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]

  lines <- lines[!grepl("^\\s*Full Sample\\s*&\\s*\\\\multicolumn\\{4\\}\\{c\\}\\{2\\}", lines)]
  lines <- lines[!grepl("^\\s*Border-State Sample\\s*&\\s*\\\\multicolumn\\{4\\}\\{c\\}\\{2\\}", lines)]

  dep_header_idx <- grep("\\\\multicolumn\\{4\\}\\{c\\}\\{Total Articles - 12mo\\}", lines)
  if (length(dep_header_idx) == 0) {
    return(lines)
  }

  insert_idx <- dep_header_idx[1] + 1
  if (insert_idx <= length(lines) && grepl("\\\\cmidrule\\(lr\\)\\{2-5\\}", lines[insert_idx])) {
    new_header <- c(
      "    & \\multicolumn{2}{c}{Full Sample} & \\multicolumn{2}{c}{Border-State Sample}\\\\",
      "   \\cmidrule(lr){2-3}\\cmidrule(lr){4-5}"
    )
    lines <- append(lines, new_header, after = insert_idx)
  }

  return(lines)
}

add_media_border_sample_header <- function(tex) {
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]

  lines <- lines[!grepl(
    "^\\s*&\\s*\\\\multicolumn\\{2\\}\\{c\\}\\{Border-State Sample: Drop Dark Green\\}",
    lines
  )]

  dep_header_idx <- grep("\\\\multicolumn\\{2\\}\\{c\\}\\{Total Articles - 12mo\\}", lines)
  if (length(dep_header_idx) == 0) {
    return(lines)
  }

  insert_idx <- dep_header_idx[1] + 1
  if (insert_idx <= length(lines) && grepl("\\\\cmidrule\\(lr\\)\\{2-3\\}", lines[insert_idx])) {
    new_header <- c(
      "    & \\multicolumn{2}{c}{Border-State Sample: Drop Dark Green}\\\\",
      "   \\cmidrule(lr){2-3}"
    )
    lines <- append(lines, new_header, after = insert_idx)
  }

  return(lines)
}
