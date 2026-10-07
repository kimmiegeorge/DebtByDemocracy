# Financial Document Variables from Wayback Machine Scraping

## Overview

This document describes the variables that can be constructed from the Wayback Machine scraping data (res and bow files) to measure financial document availability on city websites.

## Analysis Results

Based on the analysis of 8 res files from the Trial directory:

- **Total URLs scraped**: 376
- **Total URLs with content**: 284 (75.5%)
- **Total errors**: 92 (24.5%)
- **PDF URLs found**: 12 (all had errors - meaning they were encountered but not scraped as HTML)
- **Spreadsheet URLs found**: 2 (both had errors)
- **Financial-related URLs**: 133 (35.4% of all URLs)
- **Financial PDFs**: 6
- **Financial spreadsheets**: 2

## Available Variables

### 1. Document Count Variables

These variables count the number of different document types encountered during scraping:

- **`pdf_urls`**: Total number of PDF files encountered
- **`pdf_urls_with_error`**: PDFs that couldn't be scraped (typically all PDFs, as the scraper is designed for HTML)
- **`spreadsheet_urls`**: Total number of spreadsheet files (XLS, XLSX, CSV)
- **`spreadsheet_urls_with_error`**: Spreadsheets that couldn't be scraped
- **`document_urls`**: Total number of Word documents (DOC, DOCX)
- **`document_urls_with_error`**: Word documents that couldn't be scraped

### 2. Financial Document Variables

These variables focus specifically on finance-related content:

- **`financial_keyword_urls`**: URLs containing financial keywords (budget, finance, bond, debt, revenue, audit, fiscal, tax, etc.)
- **`financial_pdf_urls`**: PDFs with financial-related keywords in the URL
- **`financial_spreadsheet_urls`**: Spreadsheets with financial-related keywords in the URL

### 3. General Scraping Variables

Context variables about the scraping process:

- **`total_urls_scraped`**: Total URLs attempted during scraping
- **`total_urls_with_content`**: URLs that returned HTML content successfully
- **`total_errors`**: URLs that resulted in errors (404s, wrong MIME types, etc.)

## Financial Keywords Used

The analysis identifies financial-related documents based on these keywords in URLs:
- budget
- finance / financial
- bond
- debt
- revenue / expenditure
- treasury
- audit
- fiscal
- tax
- cafr / acfr (Comprehensive Annual Financial Report)
- annual report
- statement
- appropriation
- transparency

## How Documents are Identified

### By File Extension
The script extracts file extensions from URLs (e.g., `.pdf`, `.xlsx`, `.csv`)

### By MIME Type
When the scraper encounters non-HTML files, it logs an error with the MIME type. The script parses these errors to identify:
- PDFs: `application/pdf`
- Excel files: `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- CSV files: `text/csv`
- Word docs: `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`

## Output Files

The analysis script generates three files:

1. **`financial_docs_analysis.csv`**: Summary statistics by hostname
   - One row per hostname (city website)
   - Columns for all the variables described above

2. **`financial_docs_analysis_detailed.json`**: Detailed results including:
   - Complete lists of all PDF URLs
   - Complete lists of all financial PDF URLs
   - Complete lists of all financial URLs
   - MIME type counts
   - Error type counts

3. **Analysis summary** (printed to console): Overall statistics across all cities

## Using These Variables

### Example Research Questions

1. **Document availability**: How many financial documents (PDFs, spreadsheets) are available on each city's website?

2. **Financial transparency**: What percentage of URLs on finance-related pages actually contain documents?
   ```
   financial_docs_ratio = (financial_pdf_urls + financial_spreadsheet_urls) / financial_keyword_urls
   ```

3. **Document accessibility**: What percentage of encountered documents were successfully accessible?
   ```
   pdf_success_rate = (pdf_urls - pdf_urls_with_error) / pdf_urls
   ```

4. **Financial content density**: How much financial content exists relative to total content?
   ```
   financial_density = financial_keyword_urls / total_urls_scraped
   ```

### Merging with Other Data

The `hostname` field can be used as a key to merge this data with:
- City demographic data
- Bond issuance records
- Municipal finance data
- Geographic information

## Running the Analysis

To analyze your own res files:

```bash
python3 analyze_financial_docs.py /path/to/directory/with/res/files --output my_analysis.csv
```

The script will:
1. Recursively search for all `res*.json` files
2. Analyze each file for financial documents
3. Generate summary CSV and detailed JSON files
4. Print summary statistics

## Interpreting "Errors"

Note: In this context, "errors" for PDF/spreadsheet URLs are actually **positive findings**. The scraper is designed to extract text from HTML pages, so when it encounters a PDF/Excel file, it logs an "Invalid MIME type" error. This error actually indicates that a document was found at that URL.

Therefore:
- `pdf_urls_with_error = pdf_urls` is expected (all PDFs will have errors)
- These "errors" are valuable data points showing document availability

## Limitations

1. **Document content not analyzed**: The scraper only identifies that documents exist; it doesn't analyze their contents
2. **Broken links included**: URLs that returned 404 errors are counted as errors
3. **Dynamic content**: JavaScript-generated content may not be captured
4. **Archive completeness**: Wayback Machine may not have archived all pages

## Next Steps

Potential extensions:
1. Actually download and analyze PDF contents (would require separate scraping)
2. Track temporal availability (when documents appeared/disappeared)
3. Classify document types more granularly (budget vs. CAFR vs. bond reports)
4. Analyze bow (bag-of-words) files for financial term frequency on pages
