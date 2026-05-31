"""
Analyze res/bow files to create variables for financial-related documents
This script processes the scraped data to count PDFs and other financial documents
"""

import json
import re
import os
from pathlib import Path
from collections import Counter, defaultdict
import pandas as pd
from typing import Dict, List, Any


class FinancialDocumentAnalyzer:
    """Analyze scraped data for financial documents and PDFs"""
    
    # Financial-related keywords
    FINANCIAL_KEYWORDS = [
        'budget', 'finance', 'financial', 'bond', 'debt', 'revenue', 'expenditure',
        'treasury', 'audit', 'fiscal', 'tax', 'cafr', 'acfr', 'comprehensive',
        'annual', 'report', 'statement', 'appropriation', 'transparency'
    ]
    
    # Document file extensions of interest
    DOCUMENT_EXTENSIONS = [
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'csv'
    ]
    
    # MIME types of interest
    PDF_MIME_TYPES = [
        'application/pdf',
        'application/x-pdf'
    ]
    
    SPREADSHEET_MIME_TYPES = [
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/csv'
    ]
    
    DOCUMENT_MIME_TYPES = [
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ]
    
    def __init__(self):
        self.results = defaultdict(lambda: {
            'hostname': '',
            'total_urls_scraped': 0,
            'total_urls_with_content': 0,
            'total_errors': 0,
            'pdf_urls': 0,
            'pdf_urls_with_error': 0,
            'spreadsheet_urls': 0,
            'spreadsheet_urls_with_error': 0,
            'document_urls': 0,
            'document_urls_with_error': 0,
            'financial_keyword_urls': 0,
            'financial_pdf_urls': 0,
            'financial_spreadsheet_urls': 0,
            'url_list': []
        })
    
    def is_financial_url(self, url: str) -> bool:
        """Check if URL contains financial-related keywords"""
        url_lower = url.lower()
        return any(keyword in url_lower for keyword in self.FINANCIAL_KEYWORDS)
    
    def get_file_extension(self, url: str) -> str:
        """Extract file extension from URL"""
        # Remove query parameters
        url_clean = url.split('?')[0]
        # Get extension
        if '.' in url_clean:
            ext = url_clean.split('.')[-1].lower()
            # Check if it's a valid extension (not too long)
            if len(ext) <= 5:
                return ext
        return ''
    
    def classify_mime_type(self, error_msg: str) -> str:
        """Extract MIME type from error message if present"""
        if not error_msg:
            return None
        
        # Pattern to match MIME type in error messages
        mime_pattern = r'Invalid MIME type: ([\w\-/\.+]+)'
        match = re.search(mime_pattern, error_msg)
        if match:
            return match.group(1)
        return None
    
    def analyze_res_file(self, file_path: str) -> Dict[str, Any]:
        """Analyze a single res file"""
        hostname = Path(file_path).stem.replace('res[', '').replace(']', '')
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"Error reading {file_path}: {e}")
            return None
        
        result = {
            'hostname': hostname,
            'total_urls_scraped': 0,
            'total_urls_with_content': 0,
            'total_errors': 0,
            'pdf_urls': 0,
            'pdf_urls_with_error': 0,
            'spreadsheet_urls': 0,
            'spreadsheet_urls_with_error': 0,
            'document_urls': 0,
            'document_urls_with_error': 0,
            'financial_keyword_urls': 0,
            'financial_pdf_urls': 0,
            'financial_spreadsheet_urls': 0,
            'pdf_url_list': [],
            'financial_pdf_url_list': [],
            'financial_url_list': [],
            'mime_type_counts': Counter(),
            'error_type_counts': Counter()
        }
        
        # Process each archived page
        for archive_url, pages in data.items():
            if not isinstance(pages, list):
                continue
            
            for page in pages:
                url = page.get('URL', '')
                error = page.get('error')
                text = page.get('text', '')
                
                result['total_urls_scraped'] += 1
                
                # Check if there's content
                if text and len(text) > 0:
                    result['total_urls_with_content'] += 1
                
                # Track errors
                if error:
                    result['total_errors'] += 1
                    result['error_type_counts'][error] += 1
                    
                    # Check for MIME type in error
                    mime_type = self.classify_mime_type(error)
                    if mime_type:
                        result['mime_type_counts'][mime_type] += 1
                
                # Get file extension
                file_ext = self.get_file_extension(url)
                
                # Check if URL is financial-related
                is_financial = self.is_financial_url(url)
                if is_financial:
                    result['financial_keyword_urls'] += 1
                    result['financial_url_list'].append(url)
                
                # Check for PDF
                is_pdf = False
                if file_ext == 'pdf':
                    is_pdf = True
                elif error:
                    mime_type = self.classify_mime_type(error)
                    if mime_type in self.PDF_MIME_TYPES:
                        is_pdf = True
                
                if is_pdf:
                    result['pdf_urls'] += 1
                    result['pdf_url_list'].append(url)
                    if error:
                        result['pdf_urls_with_error'] += 1
                    if is_financial:
                        result['financial_pdf_urls'] += 1
                        result['financial_pdf_url_list'].append(url)
                
                # Check for spreadsheets
                is_spreadsheet = False
                if file_ext in ['xls', 'xlsx', 'csv']:
                    is_spreadsheet = True
                elif error:
                    mime_type = self.classify_mime_type(error)
                    if mime_type in self.SPREADSHEET_MIME_TYPES:
                        is_spreadsheet = True
                
                if is_spreadsheet:
                    result['spreadsheet_urls'] += 1
                    if error:
                        result['spreadsheet_urls_with_error'] += 1
                    if is_financial:
                        result['financial_spreadsheet_urls'] += 1
                
                # Check for other documents
                is_document = False
                if file_ext in ['doc', 'docx']:
                    is_document = True
                elif error:
                    mime_type = self.classify_mime_type(error)
                    if mime_type in self.DOCUMENT_MIME_TYPES:
                        is_document = True
                
                if is_document:
                    result['document_urls'] += 1
                    if error:
                        result['document_urls_with_error'] += 1
        
        return result
    
    def analyze_directory(self, directory: str, output_file: str = None) -> pd.DataFrame:
        """Analyze all res files in a directory"""
        res_files = list(Path(directory).rglob('res*.json'))
        
        print(f"Found {len(res_files)} res files to analyze")
        
        results_list = []
        for res_file in res_files:
            print(f"Analyzing {res_file.name}...")
            result = self.analyze_res_file(str(res_file))
            if result:
                results_list.append(result)
        
        # Create DataFrame
        summary_data = []
        for result in results_list:
            summary_data.append({
                'hostname': result['hostname'],
                'total_urls_scraped': result['total_urls_scraped'],
                'total_urls_with_content': result['total_urls_with_content'],
                'total_errors': result['total_errors'],
                'pdf_urls': result['pdf_urls'],
                'pdf_urls_with_error': result['pdf_urls_with_error'],
                'spreadsheet_urls': result['spreadsheet_urls'],
                'spreadsheet_urls_with_error': result['spreadsheet_urls_with_error'],
                'document_urls': result['document_urls'],
                'document_urls_with_error': result['document_urls_with_error'],
                'financial_keyword_urls': result['financial_keyword_urls'],
                'financial_pdf_urls': result['financial_pdf_urls'],
                'financial_spreadsheet_urls': result['financial_spreadsheet_urls'],
            })
        
        df = pd.DataFrame(summary_data)
        
        # Save to CSV if output file specified
        if output_file:
            df.to_csv(output_file, index=False)
            print(f"\nSummary saved to {output_file}")
        
        # Print summary statistics
        print("\n" + "="*80)
        print("SUMMARY STATISTICS")
        print("="*80)
        print(f"\nTotal hostnames analyzed: {len(df)}")
        print(f"Total URLs scraped: {df['total_urls_scraped'].sum()}")
        print(f"Total URLs with content: {df['total_urls_with_content'].sum()}")
        print(f"Total errors: {df['total_errors'].sum()}")
        print(f"\nDocument counts:")
        print(f"  PDF URLs: {df['pdf_urls'].sum()}")
        print(f"  PDF URLs with errors: {df['pdf_urls_with_error'].sum()}")
        print(f"  Spreadsheet URLs: {df['spreadsheet_urls'].sum()}")
        print(f"  Spreadsheet URLs with errors: {df['spreadsheet_urls_with_error'].sum()}")
        print(f"  Document URLs: {df['document_urls'].sum()}")
        print(f"  Document URLs with errors: {df['document_urls_with_error'].sum()}")
        print(f"\nFinancial-related:")
        print(f"  URLs with financial keywords: {df['financial_keyword_urls'].sum()}")
        print(f"  Financial PDFs: {df['financial_pdf_urls'].sum()}")
        print(f"  Financial spreadsheets: {df['financial_spreadsheet_urls'].sum()}")
        
        # Save detailed results with URL lists
        if output_file:
            detailed_file = output_file.replace('.csv', '_detailed.json')
            with open(detailed_file, 'w', encoding='utf-8') as f:
                # Convert Counter objects to dicts for JSON serialization
                for result in results_list:
                    result['mime_type_counts'] = dict(result['mime_type_counts'])
                    result['error_type_counts'] = dict(result['error_type_counts'])
                json.dump(results_list, f, indent=2)
            print(f"Detailed results with URL lists saved to {detailed_file}")
        
        return df


def main():
    """Main execution function"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Analyze Wayback Machine scraping results for financial documents'
    )
    parser.add_argument(
        'directory',
        help='Directory containing res*.json files (will search recursively)'
    )
    parser.add_argument(
        '--output', '-o',
        default='financial_docs_analysis.csv',
        help='Output CSV file name (default: financial_docs_analysis.csv)'
    )
    
    args = parser.parse_args()
    
    analyzer = FinancialDocumentAnalyzer()
    df = analyzer.analyze_directory(args.directory, args.output)
    
    print("\n" + "="*80)
    print("Analysis complete!")
    print("="*80)


if __name__ == '__main__':
    main()
