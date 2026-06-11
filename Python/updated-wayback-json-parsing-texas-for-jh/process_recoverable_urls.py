#!/usr/bin/env python3
"""
Process Recoverable URL-Year Pairs
Scrapes specific URL-year combinations identified as recoverable from bad URLs investigation
Saves to a separate output directory from regular Texas scraping
"""

import sys
import os
import pandas as pd
from pathlib import Path
from typing import Dict, Any
import time

from config import Config
from run_wbm import ImprovedWaybackScraper
from utils import format_duration, sanitize_filename

def setup_config_for_recovered_urls() -> Config:
    """
    Create custom configuration for recovered URLs processing
    Uses separate output directory
    """
    config = Config()
    
    # Set separate output path for recovered URLs
    config.paths.base_path = "/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Recovered URLs From Bad URLs Investigation/"
    config.paths.collection_files_path = "/Users/kmunevar/Repos/VotingOnBonds/City Websites/wayback-json-parsing-bad-urls-texas/reports/"
    
    # Ensure directories exist
    Path(config.paths.base_path).mkdir(parents=True, exist_ok=True)
    
    return config


def load_recoverable_urls(filepath: str) -> pd.DataFrame:
    """Load and process the recoverable URLs CSV"""
    df = pd.read_csv(filepath)
    print(f"📁 Loaded {len(df)} recoverable URL-year pairs")
    print(f"📊 Unique URLs: {df['host'].nunique()}")
    print(f"📅 Years: {sorted(df['year'].unique())}")
    return df


def process_url_year_pair(
    scraper: ImprovedWaybackScraper,
    host: str,
    year: int,
    output_path: Path,
    pair_index: int,
    total_pairs: int
) -> bool:
    """
    Process a single URL-year combination
    
    Args:
        scraper: ImprovedWaybackScraper instance
        host: Website host to scrape
        year: Year to scrape
        output_path: Base output directory
        pair_index: Current pair number (for progress tracking)
        total_pairs: Total number of pairs to process
        
    Returns:
        True if successful, False otherwise
    """
    # Create year-specific output directory
    year_path = output_path / f"JSON_{year}"
    
    # Check if already processed
    cdx_file = year_path / f"cdx[{sanitize_filename(host)}].csv"
    if cdx_file.exists():
        print(f"✅ [{pair_index}/{total_pairs}] {host} ({year}) - Already processed, skipping")
        return True
    
    print(f"🔄 [{pair_index}/{total_pairs}] Processing {host} ({year})...")
    
    start_time = time.time()
    date_range = (f'{year}-01-01', f'{year}-12-31')
    
    try:
        success = scraper.scrape_host(
            host=host,
            frequency='YE',
            date_range=date_range,
            output_path=str(year_path),
            max_urls=50,  # Scrape up to 50 sub-URLs from each snapshot
            max_sub_levels=3,  # Crawl 3 levels deep
            resume_session=True
        )
        
        duration = time.time() - start_time
        
        if success:
            print(f"✅ [{pair_index}/{total_pairs}] {host} ({year}) - Completed in {format_duration(duration)}")
            return True
        else:
            print(f"⚠️ [{pair_index}/{total_pairs}] {host} ({year}) - Failed after {format_duration(duration)}")
            return False
            
    except Exception as e:
        duration = time.time() - start_time
        error_msg = str(e)[:80] + "..." if len(str(e)) > 80 else str(e)
        print(f"❌ [{pair_index}/{total_pairs}] {host} ({year}) - ERROR: {error_msg}")
        return False


def main():
    """Main execution function"""
    import argparse
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Process recoverable URL-year pairs')
    parser.add_argument('--set', type=int, default=None,
                       help='Set number to process (e.g., 1, 2, 3). If not provided, processes all URLs.')
    parser.add_argument('--input-dir',
                       default='/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/',
                       help='Directory containing recoverable URLs files')
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("Recoverable URLs Scraping Pipeline")
    print("=" * 70)
    print()
    
    # Determine which file to load
    if args.set is not None:
        recoverable_csv = os.path.join(args.input_dir, f"recoverable_urls_set{args.set}.csv")
        print(f"📦 Processing Set {args.set}")
    else:
        recoverable_csv = os.path.join(args.input_dir, "recoverable_urls.csv")
        print(f"📦 Processing all recoverable URLs")
    
    if not os.path.exists(recoverable_csv):
        print(f"❌ Error: Could not find file at {recoverable_csv}")
        if args.set is not None:
            print(f"\nHint: Did you run 'python3 split_recoverable_urls.py' first?")
        sys.exit(1)
    
    print(f"📁 Input file: {os.path.basename(recoverable_csv)}")
    print()
    
    df = load_recoverable_urls(recoverable_csv)
    
    # Setup configuration with separate output directory
    config = setup_config_for_recovered_urls()
    print(f"📂 Output directory: {config.paths.base_path}")
    print()
    
    # Initialize scraper
    scraper = ImprovedWaybackScraper(config)
    
    # Track progress
    overall_start_time = time.time()
    total_pairs = len(df)
    successful = 0
    failed = 0
    skipped = 0
    
    # Process each URL-year pair
    for idx, row in df.iterrows():
        pair_num = idx + 1
        host = row['host']
        year = int(row['year'])
        
        result = process_url_year_pair(
            scraper=scraper,
            host=host,
            year=year,
            output_path=Path(config.paths.base_path),
            pair_index=pair_num,
            total_pairs=total_pairs
        )
        
        if result:
            successful += 1
        else:
            failed += 1
        
        # Print progress summary every 10 pairs
        if pair_num % 10 == 0:
            elapsed = time.time() - overall_start_time
            avg_time = elapsed / pair_num
            remaining = total_pairs - pair_num
            eta = remaining * avg_time
            
            print()
            print(f"📊 Progress: {pair_num}/{total_pairs} ({pair_num/total_pairs*100:.1f}%)")
            print(f"   ✅ Successful: {successful}")
            print(f"   ❌ Failed: {failed}")
            print(f"   ⏱️  ETA: {format_duration(eta)}")
            print()
    
    # Final summary
    total_duration = time.time() - overall_start_time
    
    print()
    print("=" * 70)
    print("Processing Complete!")
    print("=" * 70)
    print(f"📈 Total pairs processed: {total_pairs}")
    print(f"✅ Successful: {successful}")
    print(f"❌ Failed: {failed}")
    print(f"⏱️  Total time: {format_duration(total_duration)}")
    print(f"📂 Results saved to: {config.paths.base_path}")
    print("=" * 70)


if __name__ == "__main__":
    main()
