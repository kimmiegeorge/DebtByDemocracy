dpc_purpose_cols <- c(
  "educ", "wtrswr", "fire", "police", "parksrec", "pubtransit", "street",
  "elec", "waste", "sport", "health", "gas", "libarts", "econdev",
  "refund", "otherpubbldg", "other"
)

make_dpc_purpose_labels <- function(dt, prefix = "dpc_") {
  flag_cols <- paste0(prefix, dpc_purpose_cols)
  missing_cols <- setdiff(flag_cols, names(dt))
  if (length(missing_cols) > 0) {
    stop("Missing DPC purpose columns: ", paste(missing_cols, collapse = ", "))
  }

  dt[, dpc_num_purposes := rowSums(.SD == 1, na.rm = TRUE), .SDcols = flag_cols]
  dt[, dpc_purpose := apply(.SD, 1, function(x) {
    active <- dpc_purpose_cols[which(x == 1)]
    if (length(active) == 0) return(NA_character_)
    paste(active, collapse = "+")
  }), .SDcols = flag_cols]

  dt
}

load_dpc_purpose <- function(data_wd) {
  dpc <- fread(paste0(data_wd, "DPC Data/Use of Proceeds/260223_dpcdata_cusip_purpose.csv"))
  setnames(dpc, old = c("CUSIP", dpc_purpose_cols), new = c("cusip", paste0("dpc_", dpc_purpose_cols)))
  dpc[, cusip := toupper(cusip)]
  dpc[, DOCID := NULL]

  dpc <- dpc[, lapply(.SD, max, na.rm = TRUE), by = .(cusip), .SDcols = paste0("dpc_", dpc_purpose_cols)]
  make_dpc_purpose_labels(dpc)
}

add_dpc_purpose_by_cusip <- function(dt, dpc_purpose, cusip_col = "cusip") {
  dt[, (cusip_col) := toupper(get(cusip_col))]
  dpc_purpose[dt, on = setNames(cusip_col, "cusip")]
}

build_dpc_purpose_lookup <- function(bond_data, dpc_purpose, by_cols) {
  bonds <- as.data.table(bond_data)
  bonds <- add_dpc_purpose_by_cusip(bonds, dpc_purpose)

  flag_cols <- paste0("dpc_", dpc_purpose_cols)
  lookup <- bonds[, lapply(.SD, max, na.rm = TRUE), by = by_cols, .SDcols = flag_cols]
  for (col in flag_cols) {
    lookup[is.infinite(get(col)), (col) := NA_real_]
  }
  make_dpc_purpose_labels(lookup)
}
