"""
Test financial keyword detection in URLs
This script analyzes how well our FINANCIAL_KEYWORDS identify financial documents
"""

import json
import re
from pathlib import Path
from collections import Counter, defaultdict
import pandas as pd

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
    """Analyze a single res file"""
    hostname = Path(file_path).stem.replace('res[', '').replace(']', '')
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None
    
    all_urls = []
    financial_urls = []
    financial_pdfs = []
    keyword_counter = Counter()
    keyword_in_pdfs = Counter()
    
    # Process each archived page
    for archive_url, pages in data.items():
        if not isinstance(pages, list):
            continue
        
        for page in pages:
            url = page.get('URL', '')
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
        'hostname': hostname,
        'all_urls': all_urls,
        'financial_urls': financial_urls,
        'financial_pdfs': financial_pdfs,
        'keyword_counter': keyword_counter,
        'keyword_in_pdfs': keyword_in_pdfs
    }

def main():
    # Find res files
    res_dir = Path("/Users/kmunevar/Repos/VotingonBonds/City Websites/wayback-json-parsing/Trial/")
    res_files = list(res_dir.glob("res[*.json"))
    
    if not res_files:
        print("No res files found!")
        return
    
    print(f"Found {len(res_files)} res files\n")
    print("="*80)
    
    # Aggregate statistics
    total_keyword_counter = Counter()
    total_keyword_in_pdfs = Counter()
    total_urls = 0
    total_financial_urls = 0
    total_financial_pdfs = 0
    
    all_results = []
    
    # Analyze each file
    for res_file in res_files:
        print(f"\n📄 Analyzing: {res_file.name}")
        result = analyze_res_file(res_file)
        
        if result is None:
            continue
        
        all_results.append(result)
        
        # Update totals
        total_urls += len(result['all_urls'])
        total_financial_urls += len(result['financial_urls'])
        total_financial_pdfs += len(result['financial_pdfs'])
        total_keyword_counter.update(result['keyword_counter'])
        total_keyword_in_pdfs.update(result['keyword_in_pdfs'])
        
        # Print statistics for this file
        print(f"  Total URLs: {len(result['all_urls'])}")
        print(f"  Financial URLs: {len(result['financial_urls'])} ({len(result['financial_urls'])/len(result['all_urls'])*100:.1f}%)")
        print(f"  Financial PDFs: {len(result['financial_pdfs'])}")
        
        # Show top keywords for this file
        if result['keyword_counter']:
            print(f"\n  Top keywords in this file:")
            for keyword, count in result['keyword_counter'].most_common(5):
                print(f"    - {keyword}: {count}")
        
        # Show example URLs (first 3)
        if result['financial_urls']:
            print(f"\n  Example financial URLs:")
            for url, keywords in result['financial_urls'][:3]:
                print(f"    - {url}")
                print(f"      Keywords: {', '.join(keywords)}")
    
    # Print overall summary
    print("\n" + "="*80)
    print("\n📊 OVERALL SUMMARY")
    print("="*80)
    print(f"\nTotal URLs analyzed: {total_urls:,}")
    print(f"Financial URLs found: {total_financial_urls:,} ({total_financial_urls/total_urls*100:.1f}%)")
    print(f"Financial PDFs found: {total_financial_pdfs:,}")
    
    print(f"\n🔑 KEYWORD FREQUENCY (All Financial URLs)")
    print("-"*80)
    for keyword, count in total_keyword_counter.most_common():
        pct = count / total_financial_urls * 100
        print(f"  {keyword:20s}: {count:5d} ({pct:5.1f}% of financial URLs)")
    
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
                if keyword in keywords and examples_shown < 2:
                    print(f"    - {url}")
                    examples_shown += 1
                if examples_shown >= 2:
                    break
            if examples_shown >= 2:
                break

if __name__ == "__main__":
    main()
