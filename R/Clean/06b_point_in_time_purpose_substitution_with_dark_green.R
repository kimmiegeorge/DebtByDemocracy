# Set up ----

# 06: Point-in-time DPC purpose substitution tests (Table 9 and associated Figure 4)
rm(list = ls())

library(pacman)
p_load(data.table, fixest, ggplot2)

source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_modify_etable_rounding.R")
source("/Users/kmunevar/Dropbox/Voting on Bonds/Code/R/Clean/00_tax_privilege_definitions.R")

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
panel_dir <- file.path(root, "Data/DPC Data/Use Of Proceeds/Purposes Substitution")
tbl_dir <- file.path(root, "Code/R/Clean/output/revision_tables")
fig_dir <- file.path(root, "Code/R/Clean/output/revision_figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# Purpose categories and table labels ----

categories <- c(
    "other_public_buildings",
    "public_safety",
    "recreation_amenities",
    "transportation",
    "utilities",
    "other"
)

category_headers <- c(
    "Public Bldg.",
    "Public Safety",
    "Recreation",
    "Transport.",
    "Utilities",
    "Other"
)

reported_categories <- rev(categories[categories != "other"])
reported_category_headers <- rev(category_headers[categories != "other"])

control_dict <- c(
    city_go_vote = "Vote",
    ln_gdp = "County ln(GDP)",
    ln_census_population = "City ln(Pop)",
    ln_pers_inc = "County ln(Pers. Inc)",
    ln_1p_census_total_debt = "ln(1 + Census Total Debt)",
    ln_1p_county_nonmunicipal_total_debt = "County Non-City Debt",
    glm_proactive = "Proactive State",
    state_ltgo_allowed = "LTGO Allowed",
    state_go_vote = "State GO Vote",
    low_state_tax_privilege = "Low Tax Priv.",
    strict_municipal_debt_limit = "Strict Municipal Debt Limit",
    category_amount_share_of_go_or_revenue = "Category Amt. Share",
    category_amount_mil = "Par of Outstanding Bonds (millions)",
    share_revenue_vs_go_amount = "Pct Revenue"
)


# 2017 point-in-time purpose substitution ----

purpose_2017 <- fread(
    file.path(panel_dir, "260719_dpc_point_in_time_purpose_substitution_2017_issuer_category_panel.csv")
)

add_low_state_tax_privilege(purpose_2017, year_value = 2017)

purpose_2017[, fips := as.character(fips)]

purpose_2017_full <- purpose_2017[
    !is.na(city_go_vote) &
        !is.na(ln_gdp) &
        !is.na(ln_census_population) &
        !is.na(ln_pers_inc) &
        !is.na(ln_1p_county_nonmunicipal_total_debt) &
        !is.na(glm_proactive) &
        !is.na(state_ltgo_allowed) &
        !is.na(state_go_vote) &
        !is.na(low_state_tax_privilege) &
        mergent_go_revenue_bonds_outstanding >= 2
]

purpose_2017_full[, category_amount_mil := category_amount / 1000000]


# 2017 par amount outstanding by purpose: full sample ----

ppml_amount_2017_utilities <- fepois(
    category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed + state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "utilities"],
    vcov = vcov_cluster(~state)
)

ppml_amount_2017_transportation <- fepois(
    category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed + state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "transportation"],
    vcov = vcov_cluster(~state)
)

ppml_amount_2017_recreation <- fepois(
    category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed + state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "recreation_amenities"],
    vcov = vcov_cluster(~state)
)

ppml_amount_2017_public_safety <- fepois(
    category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed + state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "public_safety"],
    vcov = vcov_cluster(~state)
)

ppml_amount_2017_public_buildings <- fepois(
    category_amount_mil ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed + state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "other_public_buildings"],
    vcov = vcov_cluster(~state)
)

table_call <- etable(
    ppml_amount_2017_utilities,
    ppml_amount_2017_transportation,
    ppml_amount_2017_recreation,
    ppml_amount_2017_public_safety,
    ppml_amount_2017_public_buildings,
    headers = reported_category_headers,
    coefstat = "tstat",
    drop = "Constant",
    style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
    fitstat = c("n", "pr2"),
    se.below = TRUE,
    digits = 3,
    digits.stats = 3,
    signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
    tex = TRUE,
    order = c("%city_go_vote"),
    keep = c("%city_go_vote"),
    dict = control_dict,
    placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(
    modified_output,
    "Panel X: Par amount outstanding by purpose",
    ncols = 6
)
writeLines(
    modified_output,
    file.path(tbl_dir, "panel_x_dg_levels_by_purpose.tex")
)

# 2017 revenue share: full sample ----

r_rev_2017_full_other <- feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed +
        state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "other"],
    vcov = vcov_cluster(~state)
)

r_rev_2017_full_pub_build <- feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed +
        state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "other_public_buildings"],
    vcov = vcov_cluster(~state)
)

r_rev_2017_full_safety <- feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed +
        state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "public_safety"],
    vcov = vcov_cluster(~state)
)

r_rev_2017_full_rec <- feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed +
        state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "recreation_amenities"],
    vcov = vcov_cluster(~state)
)

r_rev_2017_full_trans <- feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed +
        state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "transportation"],
    vcov = vcov_cluster(~state)
)

r_rev_2017_full_util <- feols(
    share_revenue_vs_go_amount ~ city_go_vote + ln_gdp + ln_census_population +
        ln_pers_inc + ln_1p_county_nonmunicipal_total_debt + glm_proactive +
        state_ltgo_allowed +
        state_go_vote + low_state_tax_privilege + strict_municipal_debt_limit,
    data = purpose_2017_full[purpose_category == "utilities"],
    vcov = vcov_cluster(~state)
)

table_call <- etable(
    r_rev_2017_full_util, r_rev_2017_full_trans, r_rev_2017_full_rec,
    r_rev_2017_full_safety, r_rev_2017_full_pub_build,
    headers = reported_category_headers,
    coefstat = "tstat",
    drop = "Constant",
    style.tex = style.tex(main = "aer", fixef.suffix = " FE", yesNo = c("Yes", "No")),
    fitstat = c("n", "ar2"),
    se.below = TRUE,
    digits = 3,
    digits.stats = 3,
    signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.10),
    tex = TRUE,
    order = c("%city_go_vote"),
    keep = c("%city_go_vote"),
    dict = control_dict,
    placement = "H"
)

modified_output <- modify_etable_rounding(table_call, coef_digits = 3, tstat_digits = 2)
modified_output <- format_table(modified_output, cluster_level = "State")
modified_output <- add_panel(modified_output, "Panel C: Pct Revenue by purpose")
writeLines(modified_output, file.path(tbl_dir, "panel_c_dg_pct_rev_purpose.tex"))
