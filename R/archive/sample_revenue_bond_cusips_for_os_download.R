rm(list = ls())

library(data.table)

root <- "/Users/kmunevar/Dropbox/Voting on Bonds"
out_dir <- file.path(root, "Data/DPC Data/Use Of Proceeds/revenue_bond_os_samples")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

merged_file <- file.path(root, "Data/DPC Data/Use Of Proceeds/260622_dpc_use_proceeds_merged_debt_choice_bonds.csv")
summary_file <- file.path(root, "Data/DPC Data/Use Of Proceeds/260622_dpc_use_proceeds_vote_group_by_bond_type_summary_long.csv")
documents_file <- file.path(root, "Data/DPC Data/Use Of Proceeds/UT_Dallas - Documents.txt")
uop_file <- file.path(root, "Data/DPC Data/Use Of Proceeds/UT_Dallas - Use_Of_Proceeds.txt")

purpose_vars <- c(
  "educ", "wtrswr", "fire", "police", "parksrec", "pubtransit", "street",
  "elec", "waste", "sport", "health", "gas", "libarts", "econdev",
  "refund", "otherpubbldg", "other"
)
summary_purpose_vars <- c(setdiff(purpose_vars, c("pubtransit", "street")), "transport")

summary_dt <- fread(summary_file)
revenue <- summary_dt[
  bond_universe == "revenue_only",
  .(vote_group, purpose, purpose_label, pct_dpc_matched_bonds, n_bonds_with_purpose, n_dpc_matched_bonds)
]
wide <- dcast(
  revenue,
  purpose + purpose_label ~ vote_group,
  value.var = c("pct_dpc_matched_bonds", "n_bonds_with_purpose", "n_dpc_matched_bonds")
)
setnames(wide, make.names(names(wide)))
wide[, diff_go_vs_control := pct_dpc_matched_bonds_GO.vote - pct_dpc_matched_bonds_No.vote]
wide[, diff_utgo_vs_control := pct_dpc_matched_bonds_UTGO.only.vote - pct_dpc_matched_bonds_No.vote]
target_categories <- wide[
  diff_go_vs_control >= 2 | diff_utgo_vs_control >= 2
][order(-pmax(diff_go_vs_control, diff_utgo_vs_control))]

merged <- fread(merged_file)
merged <- merged[rev == 1 & dpc_match == 1 & vote_group %in% c("GO vote", "UTGO-only vote")]
merged[, transport := as.integer(pubtransit == 1 | street == 1)]

uop <- fread(uop_file, sep = "|", quote = "")
uop <- uop[, .(
  cusip = CUSIP,
  docid_uop = DOCID,
  issuername_dpc = trimws(ISSUERNAME),
  issue_desc_dpc = trimws(ISSUE_DESC_1),
  dated_date_dpc = DATED_DATE,
  use_of_proceeds_1 = UseOfProceeds_1,
  use_of_proceeds_2 = UseOfProceeds_2,
  use_of_proceeds_3 = UseOfProceeds_3
)]

docs <- fread(documents_file, sep = "|")
setnames(docs, c("DOCID", "CUSIP", "Link"), c("docid_docs", "cusip", "dpc_pdf_link"))

set.seed(260624)
sample_rows <- rbindlist(lapply(target_categories$purpose, function(p) {
  dt <- merged[get(p) == 1]
  dt <- unique(dt, by = c("vote_group", "cusip"))
  out <- dt[, .SD[sample(.N, min(.N, 5L))], by = vote_group]
  out[, purpose := p]
  out
}), use.names = TRUE)

sample_rows <- target_categories[, .(
  purpose,
  purpose_label,
  pct_revenue_go_vote = pct_dpc_matched_bonds_GO.vote,
  pct_revenue_no_vote = pct_dpc_matched_bonds_No.vote,
  pct_revenue_utgo_only_vote = pct_dpc_matched_bonds_UTGO.only.vote,
  diff_go_vs_control,
  diff_utgo_vs_control
)][sample_rows, on = "purpose"]

sample_rows <- uop[sample_rows, on = "cusip"]
sample_rows <- docs[sample_rows, on = "cusip"]
setcolorder(sample_rows, c(
  "purpose", "purpose_label", "vote_group", "cusip", "state", "seed_issuer",
  "year", "issue_id", "offering_date", "amount", "purp_broad",
  "pct_revenue_no_vote", "pct_revenue_go_vote", "pct_revenue_utgo_only_vote",
  "diff_go_vs_control", "diff_utgo_vs_control",
  "docid_docs", "docid_uop", "dpc_pdf_link", "issuername_dpc", "issue_desc_dpc",
  "dated_date_dpc", "use_of_proceeds_1", "use_of_proceeds_2", "use_of_proceeds_3"
))

fwrite(target_categories, file.path(out_dir, "revenue_bond_categories_above_control.csv"))
fwrite(sample_rows, file.path(out_dir, "sample_revenue_bond_cusips_for_os_download.csv"))

message("Wrote sample files to: ", out_dir)
