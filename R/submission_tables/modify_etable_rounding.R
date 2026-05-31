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
format_table <- function(tex, cluster_level = "FIPS", fixed_width = TRUE, width = "0.95\\textwidth") {
  # Collapse to single string if it's a vector
  if (length(tex) > 1) {
    tex <- paste(tex, collapse = "\n")
  }
  
  # Split into lines
  lines <- strsplit(tex, "\n", fixed = TRUE)[[1]]
  
  # 0. Convert tabular to tabular* with @{\extracolsep{\fill}}
  for (i in seq_along(lines)) {
    if (grepl("\\\\begin\\{tabular\\}", lines[i])) {
      # Extract column specification
      col_spec <- gsub(".*\\\\begin\\{tabular\\}\\{([^}]+)\\}.*", "\\1", lines[i])
      
      # Replace \begin{tabular}{spec} with \begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}spec}
      lines[i] <- gsub(
        "\\\\begin\\{tabular\\}\\{[^}]+\\}",
        paste0("\\\\begin{tabular*}{\\\\textwidth}{@{\\\\extracolsep{\\\\fill}}", col_spec, "}"),
        lines[i]
      )
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
    
    # Create cluster row with the specified level in all columns
    cluster_values <- paste(rep(cluster_level, n_cols - 1), collapse = " & ")
    cluster_row <- paste0("   Cluster              & ", cluster_values, "\\\\  ")
    
    lines <- append(lines, cluster_row, after = bottomrule_idx - 1)
  }
  
  # Return as vector
  lines
}


add_panel <- function(tex, panel_title = "Panel B: Only UTGO vote required", ncols = NULL) {
  
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
  
  # Create panel lines to insert after the tabular declaration
  panel_lines <- c(
    paste0("\\multicolumn{", ncols, "}{l}{\\textbf{", panel_title, "}}\\\\\n"),
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
