# Complete Analysis: Load Data and Create Descriptive Statistics by high_articles_12_0
# Based on "Investigate Media Tests 20250911.R" with descriptive statistics

library(pacman)
p_load(data.table, dplyr, stargazer, DescTools, arrow, glue, lfe, ggplot2, gridExtra, sandwich, zoo, haven, car)

# Set working directories
tables_wd <- "~/Dropbox/Apps/Overleaf/Voting on bonds/tables/2509_mediaupdate"
data_wd <- "~/Dropbox/Voting on Bonds/Data/"

#_______________Data Loading________________

# Load Bonds Data
cat("Loading bond data...\n")
full_data <- read_dta('~/Dropbox/Voting on Bonds/Data/Mergent/Clean/250827_city_cusiplevel_statereq_purpose_yieldspread.dta')
full_data <- as.data.table(full_data)
issuers <- full_data[, list(fips = first(fips), issuer_long_name = first(issuer_long_name)), .(seed_issuer_id)]
full_data <- full_data[city == 1 &!is.na(city_go_vote) & city_rev_vote == 0]
full_data <- full_data[go_unlim == 1]

# Load Issuance Level News Data
cat("Loading news data...\n")
issuance_lvl = fread(paste0(data_wd, 'News/Issuance_Lvl_News_With_Lagged_News_250908.csv'))
issuance_lvl[, log_total_rp_articles_12_0 := log(1+total_rp_articles_12_0)]
issuance_lvl[, log_total_rp_articles_6_0 := log(1+total_rp_articles_6_0)]
issuance_lvl <- issuers[issuance_lvl, on = .(seed_issuer_id)]

# Merge data
issuance_lvl_merge <- issuance_lvl[, .(seed_issuer_id, year, month, unique_sources_12, total_rp_articles_6_0,rolling_sum_monthly_article_count_12,
                                       total_rp_articles_12_0, total_rp_articles_1_1, log_total_rp_articles_12_0, log_total_rp_articles_6_0)]

issuance_lvl[, go := ifelse(go_unlim_bond_issuance == 1 | go_lim_bond_issuance == 1, 1, 0)]
issuance_lvl <- issuance_lvl[!is.na(city_go_vote) & city_rev_vote == 0]

# Filter and merge
full_data <- full_data[seed_issuer_id %in% issuance_lvl_merge$seed_issuer_id]
full_data <- issuance_lvl_merge[full_data, on = .(seed_issuer_id, year, month)]
full_data[, log_rolling_sum_monthly_article_count_12 := log(1+rolling_sum_monthly_article_count_12)]

# Create indicators
cat("Creating indicators...\n")
full_data[, high_articles_6_0 := ifelse(total_rp_articles_6_0 > median(total_rp_articles_6_0, na.rm = T), 1, 0)]
full_data[, high_articles_12_0 := ifelse(total_rp_articles_12_0 > median(total_rp_articles_12_0, na.rm = T), 1, 0)]
full_data[, ym := paste0(year, month)]

cat("Data loading completed!\n")
cat("Sample size:", nrow(full_data), "\n")

#_______________Descriptive Statistics Functions________________

# Function to create descriptive statistics table
create_desc_stats <- function(data, title_suffix = "") {
  
  # Variables to analyze
  vars <- c("ln_amount", "ln_maturity_mths", "insured", "rated", "ln_pop", "ln_gdp", "offering_yield", "unique_sources_12")
  
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
  cat(paste(rep("=", 80), collapse = ""), "\n")
  cat("DESCRIPTIVE STATISTICS BY high_articles_12_0", title_suffix, "\n")
  cat(paste(rep("=", 80), collapse = ""), "\n")
  print(results, row.names = FALSE)
  cat("\n")
  
  return(results)
}

# Function to create LaTeX table and save to file
create_latex_table <- function(stats_df, title, filename) {
  # Create connection to output file
  file_path <- paste0(tables_wd, "/", filename)
  file_conn <- file(file_path, "w")
  
  # Write LaTeX table to file
  writeLines("\\begin{table}[H]", file_conn)
  writeLines("\\centering", file_conn)
  writeLines(paste0("\\caption{", title, "}"), file_conn)
  writeLines("\\begin{tabular}{lcccccc}", file_conn)
  writeLines("\\hline\\hline", file_conn)
  writeLines("Variable & \\multicolumn{2}{c}{High Articles = 0} & \\multicolumn{2}{c}{High Articles = 1} & Difference & t-statistic \\\\", file_conn)
  writeLines(" & Mean & N & Mean & N & (1)-(0) &  \\\\", file_conn)
  writeLines("\\hline", file_conn)
  
  for(i in 1:nrow(stats_df)) {
    row <- stats_df[i,]
    # Add significance stars
    stars <- ""
    if(row$P_Value <= 0.01) stars <- "***"
    else if(row$P_Value <= 0.05) stars <- "**"
    else if(row$P_Value <= 0.10) stars <- "*"
    
    # Clean variable names for display
    clean_var_name <- case_when(
      row$Variable == "ln_amount" ~ "Amount",
      row$Variable == "ln_maturity_mths" ~ "Maturity",
      row$Variable == "callable" ~ "Callable",
      row$Variable == "sinkable" ~ "Sinkable", 
      row$Variable == "insured" ~ "Insured",
      row$Variable == "rated" ~ "Rated",
      row$Variable == "ln_pop" ~ "Pop",
      row$Variable == "ln_gdp" ~ "GDP",
      row$Variable == "offering_yield" ~ "Offering Yield",
      TRUE ~ row$Variable
    )
    
    line <- sprintf("%s & %.3f & %d & %.3f & %d & %.3f & %.3f%s \\\\",
               clean_var_name,
               row$High_Articles_0_Mean,
               row$High_Articles_0_N,
               row$High_Articles_1_Mean,
               row$High_Articles_1_N,
               row$Difference,
               row$T_Statistic,
               stars)
    writeLines(line, file_conn)
  }
  
  writeLines("\\hline", file_conn)
  writeLines("\\multicolumn{7}{l}{\\footnotesize * p<0.10, ** p<0.05, *** p<0.01} \\\\", file_conn)
  writeLines("\\hline\\hline", file_conn)
  writeLines("\\end{tabular}", file_conn)
  writeLines("\\end{table}", file_conn)
  
  # Close the file connection
  close(file_conn)
  
  # Also print to console
  cat("LaTeX table saved to:", file_path, "\n\n")
  
  # Also display in console
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
    # Add significance stars
    stars <- ""
    if(row$P_Value <= 0.01) stars <- "***"
    else if(row$P_Value <= 0.05) stars <- "**"
    else if(row$P_Value <= 0.10) stars <- "*"
    
    # Clean variable names for display
    clean_var_name <- case_when(
      row$Variable == "ln_amount" ~ "Amount",
      row$Variable == "ln_maturity_mths" ~ "Maturity",
      row$Variable == "callable" ~ "Callable",
      row$Variable == "sinkable" ~ "Sinkable", 
      row$Variable == "insured" ~ "Insured",
      row$Variable == "rated" ~ "Rated",
      row$Variable == "ln_pop" ~ "Pop",
      row$Variable == "ln_gdp" ~ "GDP",
      row$Variable == "offering_yield" ~ "Offering Yield",
      TRUE ~ row$Variable
    )
    
    cat(sprintf("%s & %.3f & %d & %.3f & %d & %.3f & %.3f%s \\\\\n",
               clean_var_name,
               row$High_Articles_0_Mean,
               row$High_Articles_0_N,
               row$High_Articles_1_Mean,
               row$High_Articles_1_N,
               row$Difference,
               row$T_Statistic,
               stars))
  }
  
  cat("\\hline\n")
  cat("\\multicolumn{7}{l}{\\footnotesize * p<0.10, ** p<0.05, *** p<0.01} \\\\\n")
  cat("\\hline\\hline\n")
  cat("\\end{tabular}\n")
  cat("\\end{table}\n")
  cat("\n")
}

#_______________Generate Descriptive Statistics________________

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("GENERATING DESCRIPTIVE STATISTICS TABLES\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

# 1. Full sample
cat("1. Analyzing full sample...\n")
full_sample_stats <- create_desc_stats(full_data, " - FULL SAMPLE")

# 2. city_go_vote = 0 subset
cat("2. Analyzing city_go_vote = 0 subset...\n")
vote_0_data <- full_data[city_go_vote == 0]
cat("   Subset size:", nrow(vote_0_data), "\n")
vote_0_stats <- create_desc_stats(vote_0_data, " - CITY_GO_VOTE = 0")

# 3. city_go_vote = 1 subset  
cat("3. Analyzing city_go_vote = 1 subset...\n")
vote_1_data <- full_data[city_go_vote == 1]
cat("   Subset size:", nrow(vote_1_data), "\n")
vote_1_stats <- create_desc_stats(vote_1_data, " - CITY_GO_VOTE = 1")

#_______________LaTeX Output________________

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("LATEX FORMATTED TABLES\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

create_latex_table(full_sample_stats, "Descriptive Statistics by Media Coverage - Full Sample", "desc_stats_full_sample.tex")
create_latex_table(vote_0_stats, "Descriptive Statistics by Media Coverage - No Vote Required", "desc_stats_no_vote.tex")
create_latex_table(vote_1_stats, "Descriptive Statistics by Media Coverage - Vote Required", "desc_stats_vote_required.tex")

# Create a combined table with all results
cat("Creating combined LaTeX table...\n")
file_path <- paste0(tables_wd, "/desc_stats_combined.tex")
file_conn <- file(file_path, "w")

writeLines("\\begin{table}[H]", file_conn)
writeLines("\\centering", file_conn)
writeLines("\\caption{Descriptive Statistics by Media Coverage}", file_conn)
writeLines("\\begin{tabular}{lcccccc}", file_conn)
writeLines("\\hline\\hline", file_conn)
writeLines("\\multicolumn{7}{c}{\\textbf{Panel A: Full Sample}} \\\\", file_conn)
writeLines("Variable & \\multicolumn{2}{c}{High Articles = 0} & \\multicolumn{2}{c}{High Articles = 1} & Difference & t-statistic \\\\", file_conn)
writeLines(" & Mean & N & Mean & N & (1)-(0) &  \\\\", file_conn)
writeLines("\\hline", file_conn)

for(i in 1:nrow(full_sample_stats)) {
  row <- full_sample_stats[i,]
  stars <- ""
  if(row$P_Value <= 0.01) stars <- "***"
  else if(row$P_Value <= 0.05) stars <- "**"
  else if(row$P_Value <= 0.10) stars <- "*"
  
  # Clean variable names for display
  clean_var_name <- case_when(
    row$Variable == "ln_amount" ~ "Amount",
    row$Variable == "ln_maturity_mths" ~ "Maturity",
    row$Variable == "callable" ~ "Callable",
    row$Variable == "sinkable" ~ "Sinkable", 
    row$Variable == "insured" ~ "Insured",
    row$Variable == "rated" ~ "Rated",
    row$Variable == "ln_pop" ~ "Pop",
    row$Variable == "ln_gdp" ~ "GDP",
    row$Variable == "offering_yield" ~ "Offering Yield",
    TRUE ~ row$Variable
  )
  
  line <- sprintf("%s & %.3f & %d & %.3f & %d & %.3f & %.3f%s \\\\",
             clean_var_name,
             row$High_Articles_0_Mean,
             row$High_Articles_0_N,
             row$High_Articles_1_Mean,
             row$High_Articles_1_N,
             row$Difference,
             row$T_Statistic,
             stars)
  writeLines(line, file_conn)
}

writeLines("\\hline", file_conn)
writeLines("\\multicolumn{7}{c}{\\textbf{Panel B: No Vote Required (city\\textunderscore go\\textunderscore vote = 0)}} \\\\", file_conn)
writeLines("Variable & \\multicolumn{2}{c}{High Articles = 0} & \\multicolumn{2}{c}{High Articles = 1} & Difference & t-statistic \\\\", file_conn)
writeLines(" & Mean & N & Mean & N & (1)-(0) &  \\\\", file_conn)
writeLines("\\hline", file_conn)

for(i in 1:nrow(vote_0_stats)) {
  row <- vote_0_stats[i,]
  stars <- ""
  if(row$P_Value <= 0.01) stars <- "***"
  else if(row$P_Value <= 0.05) stars <- "**"
  else if(row$P_Value <= 0.10) stars <- "*"
  
  # Clean variable names for display
  clean_var_name <- case_when(
    row$Variable == "ln_amount" ~ "Amount",
    row$Variable == "ln_maturity_mths" ~ "Maturity",
    row$Variable == "callable" ~ "Callable",
    row$Variable == "sinkable" ~ "Sinkable", 
    row$Variable == "insured" ~ "Insured",
    row$Variable == "rated" ~ "Rated",
    row$Variable == "ln_pop" ~ "Pop",
    row$Variable == "ln_gdp" ~ "GDP",
    row$Variable == "offering_yield" ~ "Offering Yield",
    TRUE ~ row$Variable
  )
  
  line <- sprintf("%s & %.3f & %d & %.3f & %d & %.3f & %.3f%s \\\\",
             clean_var_name,
             row$High_Articles_0_Mean,
             row$High_Articles_0_N,
             row$High_Articles_1_Mean,
             row$High_Articles_1_N,
             row$Difference,
             row$T_Statistic,
             stars)
  writeLines(line, file_conn)
}

writeLines("\\hline", file_conn)
writeLines("\\multicolumn{7}{c}{\\textbf{Panel C: Vote Required (city\\textunderscore go\\textunderscore vote = 1)}} \\\\", file_conn)
writeLines("Variable & \\multicolumn{2}{c}{High Articles = 0} & \\multicolumn{2}{c}{High Articles = 1} & Difference & t-statistic \\\\", file_conn)
writeLines(" & Mean & N & Mean & N & (1)-(0) &  \\\\", file_conn)
writeLines("\\hline", file_conn)

for(i in 1:nrow(vote_1_stats)) {
  row <- vote_1_stats[i,]
  stars <- ""
  if(row$P_Value <= 0.01) stars <- "***"
  else if(row$P_Value <= 0.05) stars <- "**"
  else if(row$P_Value <= 0.10) stars <- "*"
  
  # Clean variable names for display
  clean_var_name <- case_when(
    row$Variable == "ln_amount" ~ "Amount",
    row$Variable == "ln_maturity_mths" ~ "Maturity",
    row$Variable == "callable" ~ "Callable",
    row$Variable == "sinkable" ~ "Sinkable", 
    row$Variable == "insured" ~ "Insured",
    row$Variable == "rated" ~ "Rated",
    row$Variable == "ln_pop" ~ "Pop",
    row$Variable == "ln_gdp" ~ "GDP",
    row$Variable == "offering_yield" ~ "Offering Yield",
    TRUE ~ row$Variable
  )
  
  line <- sprintf("%s & %.3f & %d & %.3f & %d & %.3f & %.3f%s \\\\",
             clean_var_name,
             row$High_Articles_0_Mean,
             row$High_Articles_0_N,
             row$High_Articles_1_Mean,
             row$High_Articles_1_N,
             row$Difference,
             row$T_Statistic,
             stars)
  writeLines(line, file_conn)
}

writeLines("\\hline", file_conn)
writeLines("\\multicolumn{7}{l}{\\footnotesize * p<0.10, ** p<0.05, *** p<0.01} \\\\", file_conn)
writeLines("\\hline\\hline", file_conn)
writeLines("\\end{tabular}", file_conn)
writeLines("\\end{table}", file_conn)

close(file_conn)
cat("Combined LaTeX table saved to:", file_path, "\n")

#_______________Summary Statistics________________

cat(paste(rep("=", 60), collapse = ""), "\n")
cat("SUMMARY OF high_articles_12_0 VARIABLE\n")
cat(paste(rep("=", 60), collapse = ""), "\n")

# Full sample distribution
cat("\nFull Sample Distribution:\n")
table_full <- table(full_data$high_articles_12_0, useNA = "always")
print(table_full)
cat("Proportion with high_articles_12_0 = 1:", round(prop.table(table_full)[2], 3), "\n")

# Cross-tabulation with city_go_vote
cat("\nCross-tabulation: city_go_vote vs high_articles_12_0:\n")
crosstab <- table(full_data$city_go_vote, full_data$high_articles_12_0, useNA = "always")
print(crosstab)

# Proportions within each city_go_vote group
cat("\nProportions within each city_go_vote group:\n")
prop_table <- prop.table(crosstab, margin = 1)
print(round(prop_table, 3))

# Media coverage statistics
cat("\nMedian article count (threshold for high_articles_12_0):\n")
median_articles <- median(full_data$total_rp_articles_12_0, na.rm = TRUE)
cat("Median total_rp_articles_12_0:", median_articles, "\n")

cat("\nSummary statistics for total_rp_articles_12_0:\n")
print(summary(full_data$total_rp_articles_12_0))

#_______________State-Level Media Sources Analysis________________

cat("\n")
cat(paste(rep("=", 80), collapse = ""), "\n")
cat("STATE-LEVEL MEDIA SOURCES ANALYSIS\n")
cat(paste(rep("=", 80), collapse = ""), "\n")

# Create state-level summary
cat("Creating state-level unique_sources_12 summary...\n")

# Calculate means by state and time period
state_summary <- full_data[!is.na(unique_sources_12) & !is.na(year), 
                          list(
                            Full_Sample_Mean = mean(unique_sources_12, na.rm = TRUE),
                            Full_Sample_N = .N,
                            Pre_2015_Mean = mean(unique_sources_12[year < 2015], na.rm = TRUE),
                            Pre_2015_N = sum(year < 2015, na.rm = TRUE),
                            Post_2015_Mean = mean(unique_sources_12[year >= 2015], na.rm = TRUE),
                            Post_2015_N = sum(year >= 2015, na.rm = TRUE)
                          ), 
                          by = state]

# Sort by state name
state_summary <- state_summary[order(state)]

# Round the means for cleaner display
state_summary[, Full_Sample_Mean := round(Full_Sample_Mean, 2)]
state_summary[, Pre_2015_Mean := round(Pre_2015_Mean, 2)]
state_summary[, Post_2015_Mean := round(Post_2015_Mean, 2)]

# Handle cases where there are no observations (NaN -> NA)
state_summary[is.nan(Pre_2015_Mean), Pre_2015_Mean := NA]
state_summary[is.nan(Post_2015_Mean), Post_2015_Mean := NA]

cat("\nState-Level Summary of unique_sources_12:\n")
print(state_summary, nrows = 100)

# Create LaTeX table for state summary
cat("\nCreating LaTeX table for state-level analysis...\n")
file_path <- paste0(tables_wd, "/state_media_sources_summary.tex")
file_conn <- file(file_path, "w")

writeLines("\\begin{table}[H]", file_conn)
writeLines("\\centering", file_conn)
writeLines("\\caption{Mean Number of Unique Media Sources by State and Time Period}", file_conn)
writeLines("\\begin{tabular}{lccc}", file_conn)
writeLines("\\hline\\hline", file_conn)
writeLines("State & Full Sample & Pre-2015 & 2015 Onward \\\\", file_conn)
writeLines("\\hline", file_conn)

for(i in 1:nrow(state_summary)) {
  row <- state_summary[i,]
  
  # Handle NA values for display
  pre_2015_mean <- ifelse(is.na(row$Pre_2015_Mean), "-", sprintf("%.2f", row$Pre_2015_Mean))
  post_2015_mean <- ifelse(is.na(row$Post_2015_Mean), "-", sprintf("%.2f", row$Post_2015_Mean))
  
  line <- sprintf("%s & %.2f & %s & %s \\\\",
             row$state,
             row$Full_Sample_Mean,
             pre_2015_mean,
             post_2015_mean)
  writeLines(line, file_conn)
}

writeLines("\\hline\\hline", file_conn)
writeLines("\\end{tabular}", file_conn)
writeLines("\\end{table}", file_conn)

close(file_conn)
cat("State-level LaTeX table saved to:", file_path, "\n")

# Summary statistics
cat("\n")
cat(paste(rep("-", 60), collapse = ""), "\n")
cat("SUMMARY STATISTICS FOR unique_sources_12\n")
cat(paste(rep("-", 60), collapse = ""), "\n")

cat("\nOverall summary statistics:\n")
overall_stats <- full_data[!is.na(unique_sources_12), list(
  Mean = mean(unique_sources_12),
  Median = median(unique_sources_12),
  SD = sd(unique_sources_12),
  Min = min(unique_sources_12),
  Max = max(unique_sources_12),
  N = .N
)]
print(overall_stats)

cat("\nBy time period:\n")
time_stats <- full_data[!is.na(unique_sources_12) & !is.na(year), list(
  Mean = mean(unique_sources_12),
  Median = median(unique_sources_12),
  N = .N
), by = list(Time_Period = ifelse(year < 2015, "Pre-2015", "2015 Onward"))]
print(time_stats)

cat("\nNumber of states in analysis:", nrow(state_summary), "\n")
cat("States with observations in both periods:", sum(!is.na(state_summary$Pre_2015_Mean) & !is.na(state_summary$Post_2015_Mean)), "\n")
cat("States with only pre-2015 data:", sum(!is.na(state_summary$Pre_2015_Mean) & is.na(state_summary$Post_2015_Mean)), "\n")
cat("States with only 2015+ data:", sum(is.na(state_summary$Pre_2015_Mean) & !is.na(state_summary$Post_2015_Mean)), "\n")

cat("\nDescriptive statistics analysis completed!\n")
