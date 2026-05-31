# Create Vars - Combined with Recovered URLs

## Overview

The updated `3b. Create Vars - Combined with Recovered.py` script extends the original `3. Create Vars.py` to:

1. **Combine data from two sources:**
   - Original scraping: `~/Dropbox/.../WBM/Updated Scraping 202509/Processed`
   - Recovered URLs: `~/Dropbox/.../WBM/Recovered URLs From Bad URLs Investigation/Processed`

2. **Add financial document variables** (PDFs, spreadsheets, documents) based on URL analysis

3. **Handle duplicates intelligently** by keeping the best quality data when the same URL-year was scraped multiple times

## New Features

### 1. Duplicate Detection & Resolution

When the same URL-year pair exists in both original and recovered data, the script:

- **For RES files:** Keeps the pull with the **most sub-URLs scraped**
- **For BOW files:** Keeps the pull with the **most total word counts**

This ensures you always use the highest-quality data available.

Example output:
```
🔍 Checking for duplicate URL-year pairs...
  ⚠️  Found duplicates: Removed 150 rows from lower-quality pulls
  📋 12 URL-year pairs had multiple pulls
```

### 2. Financial Document Variables

The script now analyzes URLs to identify and count financial documents:

#### Document Count Variables
- `pdf_urls` - Total PDF files found in URLs
- `spreadsheet_urls` - Total spreadsheet files (XLS, XLSX, CSV)
- `document_urls` - Total Word documents (DOC, DOCX)
- `total_document_urls` - All documents combined

#### Financial Document Variables
- `financial_pdf_urls` - PDFs with financial keywords in URL
- `financial_spreadsheet_urls` - Spreadsheets with financial keywords
- `financial_document_urls` - Word docs with financial keywords
- `total_financial_document_urls` - All financial documents combined

#### Ratio Variables
- `pct_financial_pdfs` - % of PDFs that are financial-related
- `pct_financial_spreadsheets` - % of spreadsheets that are financial
- `pct_financial_documents` - % of all documents that are financial
- `pct_urls_are_documents` - % of scraped URLs that are documents

#### Financial Keywords Used
The script identifies financial URLs based on these keywords:
- budget, finance, financial
- bond, debt
- revenue, expenditure
- treasury, audit
- fiscal, tax
- cafr, acfr (Comprehensive Annual Financial Report)
- annual report, statement
- appropriation, transparency

## Usage

### Prerequisites

1. **Process recovered URLs JSONs first:**
   ```bash
   python3 "1b. Process JSONs from WBM - Recovered URLs.py"
   ```
   This creates the processed CSVs in the `Recovered URLs.../Processed` directory.

2. **Ensure original data is processed:**
   The original processed data should already exist from running the original pipeline.

### Run the Combined Script

```bash
python3 "3b. Create Vars - Combined with Recovered.py"
```

### Output

The script generates:
```
~/Dropbox/Voting on Bonds/Data/Websites/border_state_website_data_251111_with_recovered.csv
```

This CSV includes:
- All original variables from `3. Create Vars.py`
- New financial document variables
- Data from both original and recovered URL scraping
- Deduplicated to ensure best quality data

## Processing Flow

```
1. Load RES files
   ├── Original processed res/*.csv
   └── Recovered processed res/*.csv
   
2. Combine & deduplicate RES
   └── Keep pull with most sub-URLs per URL-year pair
   
3. Load BOW files
   ├── Original processed bow/*.csv
   └── Recovered processed bow/*.csv
   
4. Combine & deduplicate BOW
   └── Keep pull with most word counts per URL-year pair
   
5. Compute financial word frequencies
   └── Same as original (bond, debt, finance, etc.)
   
6. Analyze financial documents
   └── Count PDFs, spreadsheets, documents by URL patterns
   
7. Merge with external data
   ├── Mergent bond data
   ├── BEA economic data
   └── Sample issuer files
   
8. Compute log-adjusted variables
   
9. Save combined dataset
```

## Key Differences from Original Script

| Feature | Original (3. Create Vars.py) | Updated (3b.) |
|---------|------------------------------|---------------|
| Data sources | Original scraping only | Original + Recovered |
| Duplicate handling | N/A (no duplicates) | Keeps best quality pull |
| Financial documents | Not included | 13 new variables |
| Output filename | `border_state_website_data_251014.csv` | `..._251111_with_recovered.csv` |

## Variables Summary

The final dataset includes:

### Original Variables (from 3. Create Vars.py)
- URL-based counts: `bond_url`, `debt_url`, `tax_url`, etc.
- Percentages: `percent_bond_url`, `percent_debt_url`, etc.
- Word frequencies: `bond_count`, `debt_count`, `finance_count`, etc.
- Word percentages: `percent_bond`, `percent_debt`, etc.
- Rank percentages: `rank_percent_bond`, etc.
- Log-adjusted: `ln_bond_count`, `ln_debt_count`, etc.
- External data: Employment, GDP, population, bond issuance counts

### New Variables (added in 3b.)
- Document counts (13 variables)
- Financial document indicators
- Document type ratios

### Total Variables
Approximately **100+ variables** combining website content analysis, financial documents, and economic indicators.

## Troubleshooting

### "Recovered res directory not found"
```
⚠️  Recovered res directory not found
```
→ Run `1b. Process JSONs from WBM - Recovered URLs.py` first to create the processed recovered files.

### Unexpected duplicate counts
If you see many duplicates, this is expected and good! It means the bad URLs recovery successfully re-scraped URL-years that had poor data originally, and the script is now using the better data.

### Memory issues with large datasets
The script uses Polars with streaming where possible. If you encounter memory issues:
1. Ensure you have sufficient RAM (8GB+ recommended)
2. Close other applications
3. Process years separately if needed

## Notes

- The script automatically handles missing recovered data (proceeds with original only)
- Duplicate detection is conservative: keeps data if there's any ambiguity
- Financial keyword matching is case-insensitive
- Document detection is based on file extensions in URLs (not MIME types from errors)
