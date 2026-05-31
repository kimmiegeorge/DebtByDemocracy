# Descriptive Statistics by high_articles_12_0
# This script creates descriptive statistics tables after loading data from 
# "Investigate Media Tests 20250911.R"

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, car)

# Load the data (assuming the main script has been run up to line 41)
# If not, uncomment and run the data loading section from the main script

# Function to create descriptive statistics table
create_desc_stats <- function(data, title_suffix = "") {
  
  # Variables to analyze
  vars <- c("ln_amount", "ln_maturity_mths", "callable", "sinkable", "insured", "rated")
  
  # Initialize results data frame
  results <- data.frame(
    Variable = character(),
    High_Articles_0_Mean = numeric(),
    High_Articles_0_N = integer(),
    High_Articles_1_Mean = numeric(),
    High_Articles_1_N = integer(),
    Difference = numeric(),
    T_Statistic = numeric(),
    P_Value = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Calculate statistics for each variable
  for(var in vars) {
    # Remove missing values for this variable
    temp_data <- data[!is.na(get(var)) & !is.na(high_articles_12_0)]
    
    # Get means and counts by group
    group_0 <- temp_data[high_articles_12_0 == 0, get(var)]
    group_1 <- temp_data[high_articles_12_0 == 1, get(var)]
    
    mean_0 <- mean(group_0, na.rm = TRUE)
    mean_1 <- mean(group_1, na.rm = TRUE)
    n_0 <- length(group_0)
    n_1 <- length(group_1)
    
    # Calculate difference
    diff <- mean_1 - mean_0
    
    # Perform t-test
    t_test <- t.test(group_1, group_0, var.equal = FALSE)
    t_stat <- t_test$statistic
    p_val <- t_test$p.value
    
    # Add to results
    results <- rbind(results, data.frame(
      Variable = var,
      High_Articles_0_Mean = round(mean_0, 3),
      High_Articles_0_N = n_0,
      High_Articles_1_Mean = round(mean_1, 3),
      High_Articles_1_N = n_1,
      Difference = round(diff, 3),
      T_Statistic = round(t_stat, 3),
      P_Value = round(p_val, 3),
      stringsAsFactors = FALSE
    ))
  }
  
  # Print results
  cat("\n")
  cat("="*80, "\n")
  cat("DESCRIPTIVE STATISTICS BY high_articles_12_0", title_suffix, "\n")
  cat("="*80, "\n")
  print(results, row.names = FALSE)
  
  return(results)
}

# Generate tables for different samples
cat("Creating descriptive statistics tables...\n")

# 1. Full sample
full_sample_stats <- create_desc_stats(full_data, " - FULL SAMPLE")

# 2. city_go_vote = 0 subset
vote_0_stats <- create_desc_stats(full_data[city_go_vote == 0], " - CITY_GO_VOTE = 0")

# 3. city_go_vote = 1 subset  
vote_1_stats <- create_desc_stats(full_data[city_go_vote == 1], " - CITY_GO_VOTE = 1")

# Create formatted output for LaTeX/publication
create_latex_table <- function(stats_df, title) {
  cat("\n")
  cat("\\begin{table}[H]\n")
  cat("\\centering\n")
  cat("\\caption{", title, "}\n")
  cat("\\begin{tabular}{lcccccc}\n")
  cat("\\hline\\hline\n")
  cat("Variable & \\multicolumn{2}{c}{High Articles = 0} & \\multicolumn{2}{c}{High Articles = 1} & Difference & t-statistic \\\\\n")
  cat(" & Mean & N & Mean & N & (1)-(0) &  \\\\\n")
  cat("\\hline\n")
  
  for(i in 1:nrow(stats_df)) {
    row <- stats_df[i,]
    cat(sprintf("%s & %.3f & %d & %.3f & %d & %.3f & %.3f \\\\\n",
               row$Variable,
               row$High_Articles_0_Mean,
               row$High_Articles_0_N,
               row$High_Articles_1_Mean,
               row$High_Articles_1_N,
               row$Difference,
               row$T_Statistic))
  }
  
  cat("\\hline\\hline\n")
  cat("\\end{tabular}\n")
  cat("\\end{table}\n")
}

# Generate LaTeX tables
cat("\n\nLATEX FORMATTED TABLES:\n")
create_latex_table(full_sample_stats, "Descriptive Statistics by Media Coverage - Full Sample")
create_latex_table(vote_0_stats, "Descriptive Statistics by Media Coverage - No Vote Required")
create_latex_table(vote_1_stats, "Descriptive Statistics by Media Coverage - Vote Required")

# Summary statistics about the high_articles_12_0 variable itself
cat("\n")
cat("="*60, "\n")
cat("SUMMARY OF high_articles_12_0 VARIABLE\n")
cat("="*60, "\n")

# Full sample
cat("\nFull Sample:\n")
table_full <- table(full_data$high_articles_12_0, useNA = "always")
print(table_full)
cat("Proportion with high_articles_12_0 = 1:", round(prop.table(table_full)[2], 3), "\n")

# By city_go_vote
cat("\nBy city_go_vote:\n")
print(table(full_data$city_go_vote, full_data$high_articles_12_0, useNA = "always"))

cat("\nDescriptive statistics creation completed!\n")
