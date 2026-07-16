# Deeper Audit Findings

Audit date: 2026-07-16

Diagnostics output:

- `Data/Clean_Intermediate/deeper_audit_diagnostics.py`
- `Data/Clean_Intermediate/deeper_audit_diagnostics.csv`
- `Data/Clean_Intermediate/deeper_audit_diagnostics.md`

Scope: active R scripts that generate or feed the paper tables. I did not run full regressions because `Rscript` is not available in this shell; diagnostics use read-only Python row counts.

## Findings

### 1. `debt_choice.r` overwrites `yield_spread_utgo_only.tex`

File: `Code/R/submission_tables/debt_choice.r`

- Lines 324-385 build and write a five-column UTGO yield table.
- Lines 396-435 then build a two-column table and write the same filename, `yield_spread_utgo_only.tex`.

Impact: the second table silently replaces the first. The paper wrapper `processed/issuer_yields_full_sample.tex` inputs `tables/revision_tables/yield_spread_utgo_only`, so the final paper only sees the second version.

Recommended fix: give the two outputs separate filenames or remove the obsolete block. Then update the wrapper file intentionally.

### 2. Border-state issuer-level regressions may duplicate issuers

File: `Code/R/submission_tables/debt_choice.r`

- Lines 32-34 use `unique(border_state[, .(seed_issuer_id, group, category)])`.
- Lines 36-41 join that to issuer-level data by `seed_issuer_id`.

Diagnostics:

- `Border Matches All Mergent Data Expanded Set Buffer 100000 20260611.csv` has 813 unique `seed_issuer_id/group/category` rows for 634 issuers.
- After excluding `Rhode Island/Massachusetts`, there are 542 unique rows for 479 issuers.
- 58 non-RI issuers still appear multiple times after the deduplication used in the script, contributing 121 issuer-group-category rows.

Impact: issuer-level border regressions can weight issuers in multiple border groups more heavily. This may be intended if the estimand is border-pair exposure, but the current table note says "sample of issuers close to the borders" and does not disclose multiple entries per issuer.

Recommended fix: either collapse to one row per issuer before issuer-level regressions or state that the unit is issuer-border-pair.

### 3. RavenPack and DPC media tables use different prior-issuance definitions

Files:

- `Code/R/submission_tables/media_coverage.r`
- `Code/R/submission_tables/media_coverage_dpc.R`

Code:

- RavenPack uses `diff <= 12` for `bond_prior_12` (`media_coverage.r`, lines 78-85).
- DPC uses `diff < 12` (`media_coverage_dpc.R`, line 47).

Diagnostics:

- RavenPack file: 487 observations have prior issuance exactly 12 months earlier.
- DPC file: 487 observations also sit exactly at that cutoff.

Impact: the same named control differs across the RavenPack and DPC media specifications.

Recommended fix: choose one definition and apply it in both files.

### 4. DPC media table has a much narrower sample than the RavenPack media table

File: `Code/R/submission_tables/media_coverage_dpc.R`

Code:

- Lines 52-56 restrict to GO unlimited issuances from issuers with any DPC article coverage and positive DPC lifetime article count.
- Lines 81-108 then build a complete-case/model-observation sample used for Panels A-C.

Diagnostics:

- DPC GO unlimited rows: 3,791.
- After DPC lifetime coverage restriction: 2,203, or 58.1%.
- Complete cases remain 2,203.
- RavenPack GO unlimited rows after common filters: 3,919; with positive rolling article count: 3,621, or 92.4%.

Impact: the DPC table is not a simple replication of the RavenPack media table with another data source. It estimates on a substantially selected set of issuers with DPC presence.

Recommended fix: update the table note to state the DPC lifetime-coverage restriction, or run/specify an analogous coverage restriction in both data sources.

### 5. Texas media election outcome sample drops many elections

File: `Code/R/submission_tables/election_outcomes.R`

Code:

- Lines 211-213 restrict city-month and election-level media data to issuers/elections with `unique_sources_12m_prior > 0`.
- Lines 437-443 apply `election[unique_sources_12m_prior > 0]` again in the media election outcome regressions.

Diagnostics:

- Raw TX election media rows: 1,134.
- Rows with `unique_sources_12m_prior > 0`: 717, or 63.2%.
- Rows after source restriction and nonmissing prior county GDP: 700.

Impact: the media election outcome table is not run on all Texas elections. It excludes elections without prior source coverage. The paper wrapper text says the table examines "a sample of 872 city bond elections in Texas," which does not match the current diagnostic counts.

Recommended fix: reconcile the table note with current code/output, and consider whether zero-source elections should be coded as zero coverage rather than excluded.

### 6. Texas website election outcome sample uses `total_subs > 10`, not `total_subs == 50`

File: `Code/R/submission_tables/election_outcomes.R`

Code:

- Lines 543-546 load website election data and keep `total_subs > 10`.
- Lines 588-610 diagnostics in the script inspect `total_subs == 50`, but the later regression block does not restrict to `total_subs == 50`.
- Lines 764-770 run the website election outcome regressions.

Diagnostics:

- Raw website election rows: 1,492.
- `total_subs > 10`: 499 rows.
- `total_subs == 50`: 477 rows.

Impact: the website election-outcome sample differs from the main border website table, which uses `total_subs == 50`. This may be harmless, but it is inconsistent and should be justified.

Recommended fix: use the same threshold if the construct is meant to be comparable, or note why election-level websites use `> 10`.

### 7. Website border table drops a large group and imposes a strict scrape-completeness filter

File: `Code/R/submission_tables/websites.R`

Code:

- Line 13 drops `Rhode Island/Massachusetts`.
- Lines 15-17 require nonmissing `total_subs`, nonmissing `city_go_vote`, and `total_subs == 50`.
- Line 37 drops `BONDUEL WIS`.

Diagnostics:

- Raw border website rows: 3,618.
- After dropping `Rhode Island/Massachusetts`: 2,394.
- After nonmissing `total_subs`: 1,825.
- After nonmissing `city_go_vote`: 1,798.
- After `total_subs == 50`: 1,599.
- After dropping `BONDUEL WIS`: 1,597.

Impact: the table is based on 1,597 city-year observations after filters. If the table note implies all border city-years, it should mention the scrape-completeness and group exclusions.

Recommended fix: add filter counts to a table note or appendix, especially the `total_subs == 50` restriction.

### 8. Trade-before-maturity disclosure merges have duplicate keys, but values are identical for used measures

File: `Code/R/submission_tables/trade_before_maturity.R`

Code:

- Lines 42-47 use unique issuer-year website disclosure before merging to bond-level border data.
- Lines 53-63 use unique issuer-year-month media disclosure before merging to bond-level full-sample data.

Diagnostics:

- Media disclosure duplicate issuer-year-month keys: 376 keys, 2,216 rows.
- Duplicate media keys with varying `total_rp_articles_12_0`: 0.
- Website disclosure duplicate issuer-year keys after `total_subs == 50`: 18 keys, 36 rows.
- Duplicate website keys with varying `bond_count`: 0.

Impact: the merge collapse does not appear to change the used disclosure values, but it does imply multiple issuance rows can share the same issuer-month or issuer-year disclosure value.

Recommended fix: document that the disclosure heterogeneity variables are issuer-month and issuer-year measures, not bond-specific measures.

## Residual Risks

- I did not audit Stata scripts.
- I did not validate whether `insample`, `insample_allgo`, and `insample_utgo_only` are correctly constructed upstream because they come from Stata-generated issuer-level files.
- I did not compare model observation counts from `fixest::obs()` because R is unavailable in the current shell.
