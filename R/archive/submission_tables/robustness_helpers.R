write_website_robustness_table <- function(models, output_file, cluster_label = "County") {
  table_call <- etable(models[[1]], models[[2]], models[[3]], models[[4]], models[[5]],
                       coefstat = 'tstat',
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'pr2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       dict = c(bond_url = 'Bond URLs',
                                bond_count = 'Bond Count',
                                fiscal_url = 'Fiscal URLs',
                                fiscal_count = 'Fiscal Count',
                                financial_pdf_urls = 'Financial Docs',
                                city_go_vote = 'Vote',
                                state_monitor = 'State Fiscal Monitor',
                                ln_cum_num_issues_all = 'Num Issuances',
                                ln_gdp = 'County ln(GDP)',
                                ln_pop = 'County ln(Pop)',
                                ln_pers_inc = 'County ln(Pers. Inc)',
                                group = 'State-Border',
                                year = 'Year'),
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = cluster_label)
  modified_output <- add_panel(modified_output, 'Panel B: Regression analyses', ncols = 6)
  writeLines(modified_output, output_file)
}

write_media_coverage_robustness_table <- function(models, output_file, cluster_note) {
  table_call <- etable(models[[1]], models[[2]], models[[3]], models[[4]],
                       coefstat = 'tstat',
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'pr2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       dict = c(total_articles_12_0_win = 'Total Articles - 12mo',
                                city_go_vote = 'Vote',
                                city_rev_vote = "Rev Vote",
                                bond_prior_12 = 'Bond Issuance - 12mo',
                                ln_amount = 'Amount',
                                ln_gdp = 'County ln(GDP)',
                                ln_pop = 'County ln(Pop)',
                                ln_pers_inc = 'County ln(Pers. Inc)',
                                log_sources = 'Num Sources',
                                group = 'State-Border',
                                purp_broad = 'Purpose',
                                issuance_year_month_id = 'Year-Month'),
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = cluster_note)
  modified_output <- add_media_sample_headers(modified_output)
  modified_output <- add_panel(modified_output, 'Panel B: Regression analyses')
  writeLines(modified_output, output_file)
}

write_media_supermajority_robustness_table <- function(models, output_file, cluster_label) {
  table_call <- etable(models[[1]], models[[2]],
                       coefstat = 'tstat',
                       keep_raw = c("^city_go_vote$", "^super_majority$"),
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'pr2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       dict = c(total_articles_12_0_win = 'Total Articles - 12mo',
                                city_go_vote = 'Vote',
                                super_majority = 'Vote * Supermajority State',
                                bond_prior_12 = 'Bond Issuance - 12mo',
                                ln_amount = 'Amount',
                                ln_gdp = 'County ln(GDP)',
                                ln_pop = 'County ln(Pop)',
                                ln_pers_inc = 'County ln(Pers. Inc)',
                                log_sources = 'Num Sources',
                                purp_broad = 'Purpose',
                                issuance_year_month_id = 'Year-Month'),
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = cluster_label)
  modified_output <- add_media_sample_headers(modified_output)
  pseudo_r2_idx <- grep("^[[:space:]]*Pseudo R\\$\\^2\\$[[:space:]]*&", modified_output)
  if (length(pseudo_r2_idx) > 0) {
    modified_output <- append(
      modified_output,
      c("   City Controls              & Yes           & Yes\\\\",
        "   County Controls            & No            & Yes\\\\"),
      after = pseudo_r2_idx[1]
    )
  }
  modified_output <- add_panel(modified_output, 'Panel C: Supermajority split')
  writeLines(modified_output, output_file)
}

write_dpc_media_robustness_table <- function(models, output_file, cluster_label) {
  table_call <- etable(
    models[[1]], models[[2]],
    headers = list("Total Articles (DPC) - 12mo" = 2),
    coefstat = 'tstat',
    style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
    fitstat = c('n', 'pr2'),
    se.below = TRUE,
    digits = 3,
    digits.stats = 3,
    signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
    tex = TRUE,
    dict = c(
      dpc_total_articles_12_0_win = 'Total Articles (DPC) - 12mo',
      city_go_vote = 'Vote',
      dpc_log_lifetime_articles = 'Total DPC Coverage',
      bond_prior_12 = 'Bond Issuance - 12mo',
      ln_amount = 'Amount',
      ln_gdp = 'County ln(GDP)',
      ln_pop = 'County ln(Pop)',
      ln_pers_inc = 'County ln(Pers. Inc)',
      purp_broad = 'Purpose',
      issuance_year_month_id = 'Year-Month'
    ),
    placement = 'H',
    replace = TRUE
  )

  panel_c <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  panel_c <- format_table(panel_c, cluster_level = cluster_label)
  panel_c <- panel_c[!grepl(
    "^[[:space:]]*Total Articles \\(DPC\\) - 12mo[[:space:]]*&[[:space:]]*\\\\multicolumn\\{2\\}\\{c\\}\\{2\\}",
    panel_c
  )]
  panel_c <- add_panel(panel_c, 'Panel C: Regression analyses', ncols = 3)
  writeLines(panel_c, output_file)
}

write_debt_choice_robustness_table <- function(models, output_file, treatment_label, panel_label, cluster_label) {
  dict <- debt_choice_dict
  dict["city_go_vote"] <- treatment_label
  table_call <- etable(models[[1]], models[[2]], models[[3]], models[[4]],
                       coefstat = 'tstat',
                       drop = "Constant",
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'ar2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       order = c("%city_go_vote"),
                       dict = dict,
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = cluster_label)
  modified_output <- add_panel(modified_output, panel_label)
  writeLines(modified_output, output_file)
}

write_yield_robustness_table <- function(models, output_file, treatment_label, panel_label, cluster_label) {
  dict <- debt_choice_dict
  dict["city_go_vote"] <- treatment_label
  table_call <- etable(models[[1]], models[[2]],
                       coefstat = 'tstat',
                       drop = "Constant",
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'ar2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       order = c("%city_go_vote"),
                       dict = dict,
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = cluster_label)
  modified_output <- add_panel(modified_output, panel_label)
  writeLines(modified_output, output_file)
}

write_debt_choice_supermajority_robustness_table <- function(models, output_file, cluster_label) {
  table_call <- etable(models[[1]], models[[2]],
                       coefstat = 'tstat',
                       keep_raw = c("^city_go_vote$", "^super_majority$"),
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'ar2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       dict = debt_choice_dict,
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = cluster_label)
  adj_r2_idx <- grep("^[[:space:]]*Adj\\. R\\$\\^2\\$[[:space:]]*&", modified_output)
  if (length(adj_r2_idx) > 0) {
    modified_output <- append(modified_output, "   Controls                   & Yes            & Yes\\\\", after = adj_r2_idx[1])
  }
  modified_output <- add_panel(modified_output, 'Panel C: Full sample - supermajority split')
  writeLines(modified_output, output_file)
}

write_debt_choice_border_robustness_table <- function(models, output_file) {
  dict <- debt_choice_dict
  dict["city_go_vote"] <- "Vote"
  table_call <- etable(models[[1]], models[[2]],
                       coefstat = 'tstat',
                       style.tex = style.tex(main = 'aer', fixef.suffix = ' FE', yesNo = c("Yes", "No")),
                       fitstat = c('n', 'ar2'),
                       se.below = TRUE,
                       digits = 3,
                       digits.stats = 3,
                       signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
                       tex = TRUE,
                       dict = dict,
                       placement = 'H',
                       replace = TRUE)

  modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
  modified_output <- format_table(modified_output, cluster_level = "County")
  writeLines(modified_output, output_file)
}
