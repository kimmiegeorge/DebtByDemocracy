# Function to modify t-stat rounding in etable output
# Allows different rounding for coefficients and t-statistics

modify_etable_rounding <- function(etable_call, coef_digits = 3, tstat_digits = 2) {
  # First, capture the etable output as text
  etable_output <- capture.output(eval(etable_call))
  
  # Find lines that contain t-statistics (they come after coefficient lines)
  # In etable with se.below = TRUE and coefstat = 'tstat', 
  # t-stats appear in parentheses on lines following coefficient lines
  
  modified_output <- character(length(etable_output))
  
  for (i in seq_along(etable_output)) {
    line <- etable_output[i]
    
    # Check if this line contains t-statistics (look for parentheses with numbers)
    if (grepl("\\([^)]*[0-9]+\\.[0-9]+[^)]*\\)", line)) {
      # Extract all numbers in parentheses (t-stats)
      tstat_pattern <- "\\(([+-]?[0-9]*\\.?[0-9]+)\\)"
      
      # Find all matches
      matches <- gregexpr(tstat_pattern, line, perl = TRUE)
      match_data <- regmatches(line, matches)[[1]]
      
      if (length(match_data) > 0) {
        # Process each t-statistic
        new_line <- line
        for (match in match_data) {
          # Extract the numeric value
          numeric_val <- as.numeric(gsub("\\(|\\)", "", match))
          # Round to specified digits
          rounded_val <- round(numeric_val, tstat_digits)
          # Format to ensure consistent decimal places
          formatted_val <- sprintf(paste0("%.", tstat_digits, "f"), rounded_val)
          # Replace in the line
          new_match <- paste0("(", formatted_val, ")")
          new_line <- sub(gsub("\\(", "\\\\(", gsub("\\)", "\\\\)", match)), new_match, new_line, fixed = FALSE)
        }
        modified_output[i] <- new_line
      } else {
        modified_output[i] <- line
      }
    } else {
      modified_output[i] <- line
    }
  }
  
  # Return the modified output
  return(modified_output)
}

# Alternative function that works with the tex output directly
modify_etable_tex_rounding <- function(..., coef_digits = 3, tstat_digits = 2, file = NULL, replace = TRUE) {
  # Capture the etable arguments
  etable_args <- list(...)
  
  # Set coefficient digits
  etable_args$digits <- coef_digits
  
  # Generate the table to a temporary location first
  temp_file <- tempfile(fileext = ".tex")
  etable_args$file <- temp_file
  etable_args$replace <- TRUE
  
  # Call etable with original arguments
  do.call(etable, etable_args)
  
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
    cat("Modified table written to:", file, "\n")
  }
  
  # Clean up temp file
  unlink(temp_file)
  
  # Return the modified content invisibly
  invisible(modified_content)
}
# Format table with custom styling
format_table <- function(tex, cluster_level = "FIPS") {
  # Collapse to single string if it's a vector
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  
  # Split into lines
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]
  
  # 0. Replace scientific notation with 0.000 or -0.000
  for (i in seq_along(lines)) {
    # Match scientific notation patterns like $1.71\times 10^{-5}$ or $-6.54\times 10^{-5}$
    lines[i] <- gsub("\\$-[0-9.]+\\\\times 10\\^\\{-[0-9]+\\}\\$", "$-0.000$", lines[i])
    lines[i] <- gsub("\\$[0-9.]+\\\\times 10\\^\\{-[0-9]+\\}\\$", "$0.000$", lines[i])
  }
  
  # 1. Add rowcolor to Vote line (if exists) or first variable and their t-stat lines
  vote_idx <- grep("^[[:space:]]*Vote[[:space:]]*&", lines)
  
  if (length(vote_idx) > 0) {
    # Vote row exists - color it
    lines[vote_idx] <- paste0("\\rowcolor{ltblue}", lines[vote_idx])
    if (vote_idx < length(lines)) {
      lines[vote_idx + 1] <- paste0("\\rowcolor{ltblue}", lines[vote_idx + 1])
    }
  } else {
    # No Vote row - find first variable row after \midrule
    midrule_idx <- grep("\\\\midrule", lines)
    if (length(midrule_idx) > 0) {
      # Find first row with variable name (has & but not all empty/numbers, and not a header with multicolumn)
      for (i in (midrule_idx[1] + 1):length(lines)) {
        line <- lines[i]
        # Check if it's a data row (has &, not multicolumn, not empty cells, starts with text)
        if (grepl("&", line) && 
            !grepl("multicolumn", line) && 
            !grepl("^[[:space:]]*&", line) &&
            grepl("^[[:space:]]*[A-Za-z]", line)) {
          # This is the first variable row
          lines[i] <- paste0("\\rowcolor{ltblue}", lines[i])
          # Color the next line (t-stat row)
          if (i < length(lines)) {
            lines[i + 1] <- paste0("\\rowcolor{ltblue}", lines[i + 1])
          }
          break
        }
      }
    }
  }
  
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
    
    # Create cluster row with the specified level in all columns
    cluster_values <- paste(rep(cluster_level, n_cols - 1), collapse = " & ")
    cluster_row <- paste0("   Cluster              & ", cluster_values, "\\\\  ")
    
    lines <- append(lines, cluster_row, after = bottomrule_idx - 1)
  }
  
  # Return as vector
  lines
}


add_panel <- function(tex, panel_title = "Panel B: Only UTGO vote required", ncols = 6) {
  
  # Escape characters that would break LaTeX (minimal set)
  panel_title <- gsub("([%&#_{}$])", "\\\\\\1", panel_title)
  
  replacement <- paste0(
    "\\1\n",
    "\\\\multicolumn{", ncols, "}{l}{\\\\textbf{", panel_title, "}}\\\\\\\\\n",
    "\\\\addlinespace\n"
  )
  
  gsub(
    "(\\\\begin\\{tabular\\*?\\}\\{[^}]+\\})",
    replacement,
    tex
  )
}
