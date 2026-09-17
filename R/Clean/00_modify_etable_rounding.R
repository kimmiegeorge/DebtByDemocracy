# 00: Helpers for applying fixed decimal places to etable output. fixest treats a
# numeric `digits` argument as significant digits, so `digits = 3` prints 2.35
# rather than the fixed-decimal value 2.346.

# All Clean table scripts source this file before calling etable(). Normalize a
# numeric digits argument to fixest's fixed-decimal "r" form *before* etable
# reads the full-precision model coefficients. This obtains the true third
# decimal; it does not pad an already rounded value with a zero.
etable <- function(..., digits = "r3") {
  digits_value <- eval(substitute(digits), envir = parent.frame())
  if (is.numeric(digits_value) && length(digits_value) == 1L) {
    digits_value <- paste0("r", digits_value)
  }

  etable_call <- match.call(expand.dots = TRUE)
  etable_call[[1L]] <- quote(fixest::etable)
  etable_call$digits <- digits_value
  eval(etable_call, envir = parent.frame())
}

format_fixed_number <- function(value, digits) {
  sprintf(paste0("%.", digits, "f"), as.numeric(value))
}

format_tstat_line <- function(line, digits) {
  tstat_pattern <- "\\(([+-]?[0-9]*\\.[0-9]+)\\)"
  matches <- gregexpr(tstat_pattern, line, perl = TRUE)
  matched_text <- regmatches(line, matches)[[1]]

  if (length(matched_text) == 0 || identical(matched_text, character(0))) {
    return(line)
  }

  starts <- as.integer(matches[[1]])
  lengths <- attr(matches[[1]], "match.length")
  pieces <- character(0)
  cursor <- 1L

  for (j in seq_along(starts)) {
    pieces <- c(pieces, substr(line, cursor, starts[j] - 1L))
    value <- sub(tstat_pattern, "\\1", matched_text[j], perl = TRUE)
    pieces <- c(pieces, paste0("(", format_fixed_number(value, digits), ")"))
    cursor <- starts[j] + lengths[j]
  }

  paste0(c(pieces, substr(line, cursor, nchar(line))), collapse = "")
}

# Coefficients have already been rendered from the model at fixed precision by
# the etable wrapper above. Only t-statistics need post-processing from three to
# two decimal places.

modify_etable_rounding <- function(etable_call, coef_digits = 3, tstat_digits = 2) {
  etable_output <- capture.output(eval(etable_call))
  modified_output <- etable_output

  # Require a blank first cell so model numbers and parenthesized text in labels
  # are not mistaken for t-statistics.
  tstat_pattern <- "\\([+-]?[0-9]*\\.[0-9]+\\)"
  is_tstat_line <- grepl(
    paste0("^[[:space:]]*&.*", tstat_pattern),
    etable_output,
    perl = TRUE
  )
  if (any(is_tstat_line)) {
    modified_output[is_tstat_line] <- vapply(
      etable_output[is_tstat_line],
      format_tstat_line,
      FUN.VALUE = character(1),
      digits = tstat_digits
    )
  }

  modified_output
}

# Alternative function that works with the tex output directly
modify_etable_tex_rounding <- function(..., coef_digits = 3, tstat_digits = 2, file = NULL, replace = TRUE) {
  # Capture the etable arguments
  etable_args <- list(...)
  
  # "r" requests fixed decimal places instead of significant digits.
  etable_args$digits <- paste0("r", coef_digits)
  
  # Generate the table to a temporary location first
  temp_file <- tempfile(fileext = ".tex")
  etable_args$file <- temp_file
  etable_args$replace <- TRUE
  
  # do.call evaluates model arguments before fixest can inspect `...`. Bundle
  # those evaluated models into one list and keep recognized etable options as
  # named arguments.
  argument_names <- names(etable_args)
  if (is.null(argument_names)) {
    argument_names <- rep("", length(etable_args))
  }
  etable_option_names <- setdiff(names(formals(fixest::etable)), "...")
  is_etable_option <- nzchar(argument_names) & argument_names %in% etable_option_names
  model_args <- etable_args[!is_etable_option]
  option_args <- etable_args[is_etable_option]
  do.call(fixest::etable, c(list(model_args), option_args))
  
  # Read the generated tex file
  tex_content <- readLines(temp_file)
  
  # Modify t-statistics in the tex content
  modified_content <- character(length(tex_content))
  
  for (i in seq_along(tex_content)) {
    line <- tex_content[i]
    
    # Look for t-statistics in parentheses (common in LaTeX tables)
    if (grepl("\\([^)]*[0-9]+\\.[0-9]+[^)]*\\)", line)) {
      # Extract all numbers in parentheses
      tstat_pattern <- "\\(([+-]?[0-9]*\\.?[0-9]+)\\)"
      
      matches <- gregexpr(tstat_pattern, line, perl = TRUE)
      match_data <- regmatches(line, matches)[[1]]
      
      if (length(match_data) > 0) {
        new_line <- line
        for (match in match_data) {
          # Extract numeric value
          numeric_val <- as.numeric(gsub("\\(|\\)", "", match))
          # Round to specified digits
          rounded_val <- round(numeric_val, tstat_digits)
          # Format consistently
          formatted_val <- sprintf(paste0("%.", tstat_digits, "f"), rounded_val)
          # Replace in line
          new_match <- paste0("(", formatted_val, ")")
          new_line <- sub(gsub("\\(", "\\\\(", gsub("\\)", "\\\\)", match)), new_match, new_line, fixed = FALSE)
        }
        modified_content[i] <- new_line
      } else {
        modified_content[i] <- line
      }
    } else {
      modified_content[i] <- line
    }
  }
  
  # Write to final destination if specified
  if (!is.null(file)) {
    writeLines(modified_content, file)
  }
  
  # Clean up temp file
  unlink(temp_file)
  
  # Return the modified content invisibly
  invisible(modified_content)
}
# Format table with custom styling
format_table <- function(tex, cluster_level = "FIPS", fixed_width = TRUE, width = "\\textwidth",
                         drop_covariance = FALSE) {
  # Collapse to single string if it's a vector
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  
  # Split into lines
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]

  # etable adds a Co-variance row when models use different vcov formulas.
  # The Cluster row below reports this information more clearly, so drop the
  # redundant automatically generated row.
  if (isTRUE(drop_covariance)) {
    covariance_idx <- grep("^[[:space:]]*Co-variance[[:space:]]*&", lines)
    if (length(covariance_idx) > 0) {
      lines <- lines[-covariance_idx]
    }
  }
  
  # 0. Convert tabular to tabular* with @{\extracolsep{\fill}}
  for (i in seq_along(lines)) {
    if (grepl("\\\\begin\\{tabular\\}", lines[i])) {
      # Extract column specification
      col_spec <- gsub(".*\\\\begin\\{tabular\\}\\{([^}]+)\\}.*", "\\1", lines[i])
      
      # Replace \begin{tabular}{spec} with a fixed-width tabular*.
      lines[i] <- paste0("\\begin{tabular*}{", width, "}{@{\\extracolsep{\\fill}}", col_spec, "}")
      break
    }
  }
  
  # Replace \end{tabular} with \end{tabular*}
  for (i in seq_along(lines)) {
    if (grepl("\\\\end\\{tabular\\}", lines[i])) {
      lines[i] <- gsub("\\\\end\\{tabular\\}", "\\\\end{tabular*}", lines[i])
      break
    }
  }
  
  # 1. Replace scientific notation with 0.000 or -0.000
  for (i in seq_along(lines)) {
    # Match scientific notation patterns like $1.71\times 10^{-5}$ or $-6.54\times 10^{-5}$
    lines[i] <- gsub("\\$-[0-9.]+\\\\times 10\\^\\{-[0-9]+\\}\\$", "$-0.000$", lines[i])
    lines[i] <- gsub("\\$[0-9.]+\\\\times 10\\^\\{-[0-9]+\\}\\$", "$0.000$", lines[i])
  }
  
  # Rowcolor formatting has been removed
  
  # 2. Change "Observations" to "N"
  obs_idx <- grep("^[[:space:]]*Observations[[:space:]]*&", lines)
  if (length(obs_idx) > 0) {
    lines[obs_idx] <- gsub("Observations", "N", lines[obs_idx])
  }
  
  # 3. Remove empty line before Observations/N (lines with just "\\")
  # Find the line before N
  if (length(obs_idx) > 0 && obs_idx > 1) {
    prev_idx <- obs_idx - 1
    if (grepl("^[[:space:]]*\\\\\\\\[[:space:]]*$", lines[prev_idx])) {
      lines <- lines[-prev_idx]
      obs_idx <- obs_idx - 1  # Update index after deletion
    }
  }
  
  # 4. Add \hline before N
  if (length(obs_idx) > 0) {
    lines <- append(lines, "   \\hline", after = obs_idx - 1)
    obs_idx <- obs_idx + 1  # Update index after insertion
  }
  
  # 5. Remove empty line between R2 and fixed effects
  r2_idx <- grep("(Pseudo R\\$\\^2\\$|Adjusted R\\$\\^2\\$)", lines)
  if (length(r2_idx) > 0 && r2_idx < length(lines)) {
    next_idx <- r2_idx + 1
    if (grepl("^[[:space:]]*\\\\\\\\[[:space:]]*$", lines[next_idx])) {
      lines <- lines[-next_idx]
    }
  }
  
  # 5a. Replace "Adjusted R^2" with "Adj. R^2"
  for (i in seq_along(lines)) {
    lines[i] <- gsub("Adjusted R\\$\\^2\\$", "Adj. R\\$\\^2\\$", lines[i])
  }
  
  # 5b. Add \cmidrule beneath multicolumn headers (spanning variable names)
  # Find all multicolumn headers and add rules beneath them
  for (i in seq_along(lines)) {
    if (grepl("\\\\multicolumn\\{[0-9]+\\}", lines[i])) {
      line <- lines[i]
      
      # Skip panel labels (multicolumn with {l} alignment that spans all columns)
      # Panel labels are typically \multicolumn{n}{l}{\textbf{...}}
      if (grepl("\\\\multicolumn\\{[0-9]+\\}\\{l\\}\\{\\\\textbf\\{", line)) {
        next
      }
      
      # Find all multicolumn declarations
      mc_pattern <- "\\\\multicolumn\\{([0-9]+)\\}\\{[^}]*\\}\\{[^}]*\\}"
      
      # Split by & and track positions
      parts <- strsplit(line, "&")[[1]]
      
      cmidrules <- c()
      current_col <- 2  # Start at column 2 (first column after row label)
      
      # Process each part (except the first which is the row label)
      for (j in 2:length(parts)) {
        part <- parts[j]
        
        # Check if this part contains a multicolumn
        if (grepl(mc_pattern, part)) {
          # Extract the span
          span <- as.numeric(gsub(paste0(".*", mc_pattern, ".*"), "\\1", part))
          
          # Add cmidrule for any multicolumn (even span of 1)
          end_col <- current_col + span - 1
          cmidrules <- c(cmidrules, paste0("\\cmidrule(lr){", current_col, "-", end_col, "}"))
          current_col <- end_col + 1
        } else {
          # Regular column (not multicolumn) - still add a cmidrule
          # Check if this part has actual content (not just whitespace/newline)
          if (grepl("[A-Za-z0-9]", part)) {
            cmidrules <- c(cmidrules, paste0("\\cmidrule(lr){", current_col, "-", current_col, "}"))
          }
          current_col <- current_col + 1
        }
      }
      
      # Insert cmidrules after the header line if any were found
      if (length(cmidrules) > 0 && i < length(lines)) {
        cmidrule_line <- paste0("   ", paste(cmidrules, collapse = ""))
        lines <- append(lines, cmidrule_line, after = i)
        # Skip the newly inserted line in the loop by breaking
        break
      }
    }
  }
  
  # 5c. Replace blank fixed effects cells with "No"
  # Find fixed effects rows (lines containing "FE" followed by whitespace and &)
  for (i in seq_along(lines)) {
    if (grepl("FE[[:space:]]*&", lines[i]) && grepl("&", lines[i])) {
      # Split by & to process each cell
      parts <- strsplit(lines[i], "&", fixed = TRUE)[[1]]
      
      # Process each part (skip first which is the label)
      for (j in 2:length(parts)) {
        # Check if cell contains only whitespace (no alphanumeric characters before \\ or end)
        if (grepl("^[[:space:]]*($|\\\\\\\\)", parts[j])) {
          # Replace with "No" followed by original spacing
          parts[j] <- sub("^[[:space:]]*", " No           ", parts[j])
        }
      }
      
      # Rejoin the line
      lines[i] <- paste(parts, collapse = "&")
    }
  }
  
  # 6. Add Cluster row after fixed effects (before \bottomrule)
  bottomrule_idx <- grep("\\\\bottomrule", lines)
  if (length(bottomrule_idx) > 0) {
    # Count the number of columns from the first data row after \midrule
    midrule_idx <- grep("\\\\midrule", lines)
    if (length(midrule_idx) > 0) {
      # Find first row with data after midrule
      for (i in (midrule_idx[1] + 1):length(lines)) {
        if (grepl("&", lines[i]) && !grepl("multicolumn", lines[i])) {
          sample_row <- lines[i]
          break
        }
      }
    } else {
      # Fallback: use any row with & that's not multicolumn
      sample_row <- lines[grep("&", lines)[1]]
    }
    
    n_cols <- length(gregexpr("&", sample_row)[[1]]) + 1
    
    # Accept either one label for every model or one label per model.
    n_models <- n_cols - 1
    if (length(cluster_level) == 1) {
      cluster_levels <- rep(cluster_level, n_models)
    } else if (length(cluster_level) == n_models) {
      cluster_levels <- cluster_level
    } else {
      stop("cluster_level must contain either one label or one label per model")
    }
    cluster_values <- paste(cluster_levels, collapse = " & ")
    cluster_row <- paste0("   Cluster              & ", cluster_values, "\\\\  ")
    
    lines <- append(lines, cluster_row, after = bottomrule_idx - 1)
  }
  
  # Return as vector
  lines
}


add_panel <- function(
  tex,
  panel_title = "Panel B: Only UTGO vote required",
  ncols = NULL,
  zero_width = FALSE
) {
  
  # Work with lines if it's a vector, or split if it's a single string
  if (length(tex) == 1) {
    lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]
    was_string <- TRUE
  } else {
    lines <- tex
    was_string <- FALSE
  }
  
  # Find the line with \begin{tabular*} or \begin{tabular}
  tabular_idx <- grep("\\\\begin\\{tabular\\*?\\}", lines)
  
  if (length(tabular_idx) == 0) {
    return(tex)  # No tabular found, return unchanged
  }
  
  tabular_idx <- tabular_idx[1]  # Use first match
  
  # If ncols not specified, detect from the tabular line
  if (is.null(ncols)) {
    tabular_line <- lines[tabular_idx]
    # Extract column spec - now handles both tabular and tabular* with multiple brace groups
    col_match <- regexpr("\\\\begin\\{tabular\\*?\\}(\\{[^}]+\\})+", tabular_line, perl = TRUE)
    if (col_match[1] > 0) {
      full_match <- regmatches(tabular_line, col_match)[[1]]
      # Extract the last brace group which contains the column spec
      col_spec <- gsub(".*\\{([^}]+)\\}$", "\\1", full_match)
      # Remove @{\extracolsep{\fill}} prefix if present (match actual backslashes in string)
      col_spec <- gsub("^@\\{\\\\extracolsep\\{\\\\fill\\}\\}", "", col_spec)
      # Also try without doubled backslashes
      col_spec <- gsub("^@\\{\\extracolsep\\{\\fill\\}\\}", "", col_spec)
      ncols <- nchar(col_spec)  # Count columns
    } else {
      ncols <- 6  # Default fallback
    }
  }
  
  # Escape characters that would break LaTeX (minimal set)
  panel_title <- gsub("([%&#_{}$])", "\\\\\\1", panel_title)
  
  # A zero-width box keeps a long spanning panel title inside the tabular
  # without allowing it to distort the underlying model-column widths.
  panel_contents <- paste0("\\textbf{", panel_title, "}")
  if (isTRUE(zero_width)) {
    panel_contents <- paste0("\\makebox[0pt][l]{", panel_contents, "}")
  }

  # Create panel lines to insert after the tabular declaration
  panel_lines <- c(
    paste0("\\multicolumn{", ncols, "}{l}{", panel_contents, "}\\\\\n"),
    "\\addlinespace"
  )
  
  # Insert panel lines after the tabular declaration
  lines <- append(lines, panel_lines, after = tabular_idx)
  
  # Return in the same format as input
  if (was_string) {
    return(paste(lines, collapse = "\n"))
  } else {
    return(lines)
  }
}
