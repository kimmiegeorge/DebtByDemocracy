"""
Test financial keyword detection in URLs using CSV res files
This script analyzes how well our FINANCIAL_KEYWORDS identify financial documents
"""

import os
import csv
from pathlib import Path
from collections import Counter, defaultdict
import random

# Financial-related keywords (from analyze_financial_docs.py)
FINANCIAL_KEYWORDS = [
    'budget', 'finance', 'financial', 'bond', 'debt', 'revenue', 'expenditure',
    'treasury', 'audit', 'fiscal', 'tax', 'cafr', 'acfr', 'comprehensive',
    'annual', 'report', 'statement', 'appropriation', 'transparency'
]

def is_financial_url(url: str) -> bool:
    """Check if URL contains financial-related keywords"""
    url_lower = url.lower()
    return any(keyword in url_lower for keyword in FINANCIAL_KEYWORDS)

def get_matching_keywords(url: str) -> list:
    """Get list of keywords that match in the URL"""
    url_lower = url.lower()
    return [keyword for keyword in FINANCIAL_KEYWORDS if keyword in url_lower]

def is_pdf_url(url: str) -> bool:
    """Check if URL appears to be a PDF"""
    url_clean = url.split('?')[0]
    return url_clean.lower().endswith('.pdf')

def analyze_res_file(file_path: str):
    """Analyze a single res CSV file"""
    try:
        # Read the CSV file
        with open(file_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            
            all_urls = []
            financial_urls = []
            financial_pdfs = []
            keyword_counter = Counter()
            keyword_in_pdfs = Counter()
            
            for row in reader:
                url = row.get('URL', '')
                if not url:
                    continue
                
                all_urls.append(url)
                
                # Check if it's financial
                matching_keywords = get_matching_keywords(url)
                if matching_keywords:
                    financial_urls.append((url, matching_keywords))
                    for keyword in matching_keywords:
                        keyword_counter[keyword] += 1
                    
                    # Check if it's also a PDF
                    if is_pdf_url(url):
                        financial_pdfs.append((url, matching_keywords))
                        for keyword in matching_keywords:
                            keyword_in_pdfs[keyword] += 1
            
            return {
                'file_name': Path(file_path).name,
                'all_urls': all_urls,
                'financial_urls': financial_urls,
                'financial_pdfs': financial_pdfs,
                'keyword_counter': keyword_counter,
                'keyword_in_pdfs': keyword_in_pdfs
            }
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None

def main():
    # Find res files
    res_dir = Path(os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Updated Scraping 202509/Processed/res/'))
    
    if not res_dir.exists():
        print(f"Directory not found: {res_dir}")
        return
    
    all_res_files = list(res_dir.glob("*.csv"))
    
    if not all_res_files:
        print("No res CSV files found!")
        return
    
    print(f"Found {len(all_res_files)} total res files")
    
    # Sample files for analysis
    sample_size = min(50, len(all_res_files))
    res_files = random.sample(all_res_files, sample_size)
    print(f"Analyzing a random sample of {sample_size} files\n")
    print("="*80)
    
    # Aggregate statistics
    total_keyword_counter = Counter()
    total_keyword_in_pdfs = Counter()
    total_urls = 0
    total_financial_urls = 0
    total_financial_pdfs = 0
    
    all_results = []
    
    # Analyze each file
    for i, res_file in enumerate(res_files, 1):
        if i % 10 == 0:
            print(f"\n  Processing file {i}/{sample_size}...")
        
        result = analyze_res_file(res_file)
        
        if result is None or len(result['all_urls']) == 0:
            continue
        
        all_results.append(result)
        
        # Update totals
        total_urls += len(result['all_urls'])
        total_financial_urls += len(result['financial_urls'])
        total_financial_pdfs += len(result['financial_pdfs'])
        total_keyword_counter.update(result['keyword_counter'])
        total_keyword_in_pdfs.update(result['keyword_in_pdfs'])
    
    # Print overall summary
    print("\n" + "="*80)
    print("\n📊 OVERALL SUMMARY")
    print("="*80)
    print(f"\nFiles analyzed: {len(all_results)}")
    print(f"Total URLs analyzed: {total_urls:,}")
    print(f"Financial URLs found: {total_financial_urls:,} ({total_financial_urls/total_urls*100:.1f}%)")
    print(f"Financial PDFs found: {total_financial_pdfs:,}")
    if total_financial_urls > 0:
        print(f"  PDFs as % of financial URLs: {total_financial_pdfs/total_financial_urls*100:.1f}%")
    
    print(f"\n🔑 KEYWORD FREQUENCY (All Financial URLs)")
    print("-"*80)
    if total_keyword_counter:
        for keyword, count in total_keyword_counter.most_common():
            pct = count / total_financial_urls * 100
            print(f"  {keyword:20s}: {count:5d} ({pct:5.1f}% of financial URLs)")
    else:
        print("  No financial keywords found")
    
    print(f"\n📑 KEYWORD FREQUENCY (Financial PDFs Only)")
    print("-"*80)
    if total_keyword_in_pdfs:
        for keyword, count in total_keyword_in_pdfs.most_common():
            pct = count / total_financial_pdfs * 100 if total_financial_pdfs > 0 else 0
            print(f"  {keyword:20s}: {count:5d} ({pct:5.1f}% of financial PDFs)")
    else:
        print("  No financial PDFs found")
    
    # Sample URLs for most common keywords
    print(f"\n📋 EXAMPLE URLs FOR TOP KEYWORDS")
    print("-"*80)
    top_keywords = [kw for kw, _ in total_keyword_counter.most_common(5)]
    
    for keyword in top_keywords:
        print(f"\n  Keyword: '{keyword}'")
        examples_shown = 0
        for result in all_results:
            for url, keywords in result['financial_urls']:
                if keyword in keywords and examples_shown < 3:
                    print(f"    - {url}")
                    print(f"      [Keywords: {', '.join(keywords)}]")
                    examples_shown += 1
                if examples_shown >= 3:
                    break
            if examples_shown >= 3:
                break
    
    # Show example financial PDFs
    if total_financial_pdfs > 0:
        print(f"\n📄 EXAMPLE FINANCIAL PDFs")
        print("-"*80)
        pdf_examples_shown = 0
        for result in all_results:
            for url, keywords in result['financial_pdfs']:
                if pdf_examples_shown < 5:
                    print(f"\n  {url}")
                    print(f"  Keywords: {', '.join(keywords)}")
                    pdf_examples_shown += 1
                if pdf_examples_shown >= 5:
                    break
            if pdf_examples_shown >= 5:
                break

if __name__ == "__main__":
    main()
