library(data.table)
library(haven)

data_dir <- "Data"

rp <- fread(
  file.path(data_dir, "News/Ravenpack_Cities_With_FIPS.csv"),
  colClasses = list(character = "fips")
)

mergent <- as.data.table(read_dta(
  file.path(data_dir, "Mergent/Clean/260610_city_cusiplevel_statereq_purpose_yieldspread.dta")
))

mergent <- unique(
  mergent[
    issuer_type == "city",
    .(state, seed_issuer, seed_issuer_id, city_go_vote, city_rev_vote, fips)
  ]
)

mergent[, fips := sprintf("%05s", fips)]
rp[, fips := sprintf("%05s", fips)]

clean_name <- function(x) {
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}

state_tokens <- c(
  AL = "ala", AK = "alaska", AZ = "ariz", AR = "ark", CA = "calif",
  CO = "colo", CT = "conn", DE = "del", FL = "fla", GA = "ga",
  HI = "hawaii", ID = "idaho", IL = "ill", IN = "ind", IA = "iowa",
  KS = "kans", KY = "ky", LA = "la", ME = "me", MD = "md", MA = "mass",
  MI = "mich", MN = "minn", MS = "miss", MO = "mo", MT = "mont",
  NE = "neb", NV = "nev", NH = "n h", NJ = "n j", NM = "n mex",
  NY = "n y", NC = "n c", ND = "n d", OH = "ohio", OK = "okla",
  OR = "ore", PA = "pa", RI = "r i", SC = "s c", SD = "s d",
  TN = "tenn", TX = "tex", UT = "utah", VT = "vt", VA = "va",
  WA = "wash", WI = "wis", WV = "w va", WY = "wyo"
)

strip_state_token <- function(seed_issuer, state) {
  out <- clean_name(seed_issuer)
  token <- unname(state_tokens[state])
  if (!is.na(token) && length(token) == 1) {
    out <- trimws(gsub(paste0("\\b", token, "\\b"), " ", out))
  }
  trimws(gsub("\\s+", " ", out))
}

escape_regex <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
}

phrase_in_text <- function(phrase, text) {
  phrase <- clean_name(phrase)
  text <- clean_name(text)
  if (is.na(phrase) || is.na(text) || phrase == "" || text == "") {
    return(FALSE)
  }
  grepl(paste0("(^| )", escape_regex(phrase), "( |$)"), text, perl = TRUE)
}

# Original matching style: same county FIPS and RavenPack city phrase appears
# as a complete word/phrase in the Mergent seed issuer.
fips_join <- merge(rp, mergent, by = "fips", allow.cartesian = TRUE)
fips_join[, seed_clean := clean_name(seed_issuer)]
fips_join[, city_clean := clean_name(city)]
fips_join[, city_in_issuer := mapply(phrase_in_text, city_clean, seed_clean)]

map_fips <- fips_join[
  city_in_issuer == TRUE,
  .(
    rp_entity_id,
    seed_issuer = tolower(seed_issuer),
    seed_issuer_id,
    match_method = "fips_city_phrase"
  )
]

# Conservative update pass: for issuers not captured by the FIPS match, allow a
# same-state match when the cleaned seed issuer equals a RavenPack city after
# removing the state token. This captures updated Mergent issuer ids and FIPS
# corrections without allowing substring matches or ambiguous partial names.
matched_seed_ids <- unique(map_fips$seed_issuer_id)
mergent_unmatched <- copy(mergent[!(seed_issuer_id %in% matched_seed_ids)])
mergent_unmatched[, seed_base := mapply(strip_state_token, seed_issuer, state)]

rp_state <- copy(rp[, .(rp_entity_id, city, state)])
rp_state[, city_clean := clean_name(city)]

state_join <- merge(
  rp_state,
  mergent_unmatched,
  by.x = c("state", "city_clean"),
  by.y = c("state", "seed_base"),
  allow.cartesian = TRUE
)

map_state <- state_join[
  ,
  .(
    rp_entity_id,
    seed_issuer = tolower(seed_issuer),
    seed_issuer_id,
    match_method = "state_city_phrase"
  )
]

old <- fread(file.path(data_dir, "News/RP_Mergent_Mapping.csv"))
old[, seed_issuer := tolower(seed_issuer)]
old_key <- unique(old[, .(rp_entity_id, seed_issuer_id)])

updated_candidates <- unique(rbindlist(list(map_fips, map_state), use.names = TRUE))
setorder(updated_candidates, rp_entity_id, seed_issuer_id)
updated_candidates[
  ,
  old_match := paste(rp_entity_id, seed_issuer_id) %in%
    paste(old_key$rp_entity_id, old_key$seed_issuer_id)
]

new_pairs <- updated_candidates[old_match == FALSE]
final_mapping <- unique(rbindlist(
  list(
    old[, .(rp_entity_id, seed_issuer, seed_issuer_id)],
    new_pairs[, .(rp_entity_id, seed_issuer, seed_issuer_id)]
  ),
  use.names = TRUE
))
setorder(final_mapping, rp_entity_id, seed_issuer_id)

cat("old rows", nrow(old), "old seed issuers", uniqueN(old$seed_issuer_id), "\n")
cat(
  "candidate rows", nrow(updated_candidates),
  "candidate seed issuers", uniqueN(updated_candidates$seed_issuer_id), "\n"
)
cat(
  "new pairs", nrow(new_pairs),
  "new seed issuers", uniqueN(new_pairs$seed_issuer_id), "\n"
)
cat(
  "final rows", nrow(final_mapping),
  "final seed issuers", uniqueN(final_mapping$seed_issuer_id), "\n"
)
print(updated_candidates[, .N, by = match_method])

fwrite(
  updated_candidates,
  "/private/tmp/RP_Mergent_Mapping_updated_candidate_with_method.csv"
)
fwrite(
  final_mapping,
  "/private/tmp/RP_Mergent_Mapping_updated_candidate.csv"
)
fwrite(
  new_pairs,
  "/private/tmp/RP_Mergent_Mapping_new_pairs_audit.csv"
)

cat("wrote candidate/audit files in /private/tmp\n")
