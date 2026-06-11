#!/usr/bin/env python3
"""
Improved Wayback Machine Scraper
Enhanced with better error handling, performance monitoring, and recovery capabilities
"""

import sys
import os
import re
import json
import time
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple
from datetime import datetime

import polars as pl
import pandas as pd
from collections import Counter

from config import Config
from scraper import (
    WaybackAPIClient, TreeScraper, TextProcessor, wayback_urlparse
)
from utils import (
    ScrapingLogger, PerformanceMonitor, FileManager, SessionManager,
    sanitize_filename, create_progress_callback, format_duration
)


class ImprovedWaybackScraper:
    """
    Enhanced Wayback Machine Scraper with improved functionality
    """
    
    def __init__(self, config: Optional[Config] = None):
        self.config = config or Config()
        self.logger = ScrapingLogger(self.config.logging)
        self.performance_monitor = PerformanceMonitor()
        self.file_manager = FileManager(self.config.paths.backup_enabled)
        
        # Initialize core components
        self.wayback_client = WaybackAPIClient(self.config)
        self.tree_scraper = TreeScraper(self.config)
        self.text_processor = TextProcessor(self.config)
        
        self.logger.info("ImprovedWaybackScraper initialized")
    
    def scrape_host(
        self,
        host: str,
        frequency: str = "YE",
        output_path: str = None,
        date_range: Optional[Tuple[str, str]] = None,
        max_urls: Optional[int] = None,
        max_sub_levels: Optional[int] = None,
        resume_session: bool = True
    ) -> bool:
        """
        Main scraping function for a single host
        
        Args:
            host: Host/domain to scrape
            frequency: Temporal frequency for filtering (YE, M, D)
            output_path: Directory for output files
            date_range: Optional date range filter (start_date, end_date)
            max_urls: Maximum URLs to scrape per year
            max_sub_levels: Maximum sub-URL depth
            resume_session: Whether to resume from previous session
            
        Returns:
            True if successful, False otherwise
        """
        start_time = time.time()
        self.performance_monitor.start_timer("total_scrape")
        
        # Set default output path
        if output_path is None:
            output_path = self.config.paths.base_path
        
        output_path = Path(output_path)
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Initialize session manager
        session_file = output_path / f"session_{sanitize_filename(host)}.json"
        session_manager = SessionManager(str(session_file))
        
        if not resume_session:
            session_manager.clear_session()
        
        self.logger.info(
            f"Starting scraping process",
            host=host,
            frequency=frequency,
            output_path=str(output_path),
            date_range=date_range,
            max_urls=max_urls,
            max_sub_levels=max_sub_levels
        )
        
        try:
            # Step 1: Query Wayback Machine API
            df = self._get_or_load_wayback_data(host, output_path)
            if df is None:
                return False
            
            # Step 2: Filter results by frequency and date range
            filtered_df = self._filter_wayback_results(df, frequency, date_range)
            if filtered_df.empty:
                self.logger.warning(f"No URLs remaining after filtering", host=host)
                return False
            
            # Step 3: Scrape URLs and their trees
            all_results = self._scrape_url_trees(
                filtered_df, host, output_path, session_manager, max_urls, max_sub_levels
            )
            
            if not all_results:
                self.logger.warning(f"No scraping results obtained", host=host)
                return False
            
            # Step 4: Process text and create bag of words
            self._process_and_save_results(all_results, host, output_path)
            
            # Step 5: Clean up session
            if resume_session:
                session_manager.clear_session()
            
            total_duration = self.performance_monitor.end_timer("total_scrape")
            
            self.logger.info(
                f"Scraping completed successfully",
                host=host,
                total_duration=format_duration(total_duration),
                urls_processed=len(all_results)
            )
            
            # Log performance statistics
            self._log_performance_stats()
            
            return True
            
        except Exception as e:
            self.logger.error(f"Scraping failed for host", host=host, exception=e)
            return False
    
    def _get_or_load_wayback_data(self, host: str, output_path: Path) -> Optional[pd.DataFrame]:
        """Get Wayback data from API or load from existing CSV"""
        csv_filename = output_path / f"cdx[{sanitize_filename(host)}].csv"
        
        try:
            # Try to load existing data
            if csv_filename.exists():
                df = pd.read_csv(csv_filename)
                df["datetime"] = pd.to_datetime(df["datetime"])
                self.logger.info(f"Loaded existing Wayback data", host=host, records=len(df))
                return df
        except Exception as e:
            self.logger.warning(f"Could not load existing CSV", file=str(csv_filename), exception=e)
        
        # Query API for new data
        self.logger.info(f"Querying Wayback Machine API", host=host)
        df = self.wayback_client.query_wayback(host)
        
        if df is not None:
            # Save the results
            if self.file_manager.safe_save_csv(df, str(csv_filename)):
                self.logger.info(f"Saved Wayback query results", file=str(csv_filename))
            else:
                self.logger.error(f"Failed to save Wayback query results", file=str(csv_filename))
        
        return df
    
    def _filter_wayback_results(
        self, 
        df: pd.DataFrame, 
        frequency: str, 
        date_range: Optional[Tuple[str, str]]
    ) -> pd.DataFrame:
        """Filter Wayback results by frequency and date range"""
        self.logger.info(f"Filtering Wayback results", original_count=len(df))
        
        # Apply date range filter
        if date_range:
            start_date, end_date = date_range
            date_mask = (
                (df["datetime"] >= pd.to_datetime(start_date)) &
                (df["datetime"] <= pd.to_datetime(end_date))
            )
            df = df[date_mask].copy()
            self.logger.info(f"After date range filter", count=len(df), date_range=date_range)
        
        if df.empty:
            return df
        
        # Reset index
        df = df.reset_index(drop=True)
        
        # Convert length to numeric
        df["length"] = pd.to_numeric(df["length"], errors="coerce")
        
        # Map frequency for different operations
        resample_freq = frequency
        period_freq = 'Y' if frequency == 'YE' else frequency
        
        # Resample by frequency and get average length
        df_resampled = (
            df.set_index("datetime")
            .dropna()
            .resample(resample_freq)["length"]
            .mean()
            .to_frame()
            .reset_index()
        )
        df_resampled.columns = ["agg_datetime", "avg_length"]
        
        # Create period columns for merging (Period still uses 'Y')
        df_resampled["period"] = df_resampled["agg_datetime"].dt.to_period(period_freq)
        df["period"] = df["datetime"].dt.to_period(period_freq)
        
        # Merge and keep largest file per period
        df_merged = pd.merge(df, df_resampled, on="period", how="inner")
        df_filtered = (
            df_merged
            .sort_values("length", ascending=False)
            .drop_duplicates("period", keep="first")
        )
        
        self.logger.info(f"After frequency filtering", count=len(df_filtered), frequency=frequency)
        
        return df_filtered
    
    def _scrape_url_trees(
        self,
        df: pd.DataFrame,
        host: str,
        output_path: Path,
        session_manager: SessionManager,
        max_urls: Optional[int],
        max_sub_levels: Optional[int]
    ) -> Dict[str, List[Dict[str, Any]]]:
        """Scrape tree of URLs for each filtered result"""
        all_results = {}
        urls_to_process = df["url"].tolist()
        
        # Check for resumable URLs
        remaining_urls = session_manager.get_remaining_urls(urls_to_process)
        if len(remaining_urls) < len(urls_to_process):
            self.logger.info(
                f"Resuming from previous session",
                total_urls=len(urls_to_process),
                remaining_urls=len(remaining_urls)
            )
        
        progress_callback = create_progress_callback(len(remaining_urls), "Scraping URLs")
        
        for i, url in enumerate(remaining_urls):
            try:
                self.logger.info(f"Processing URL", url=url, progress=f"{i+1}/{len(remaining_urls)}")
                
                # Scrape the tree
                tree_results = self.tree_scraper.scrape_tree(
                    url, host, max_urls, max_sub_levels
                )
                
                all_results[url] = tree_results
                session_manager.mark_url_completed(url)
                
                progress_callback(i + 1, f"Completed: {url}")
                
                # Save intermediate results periodically
                if (i + 1) % 5 == 0:
                    self._save_intermediate_results(all_results, host, output_path)
                
            except Exception as e:
                self.logger.error(f"Error processing URL", url=url, exception=e)
                session_manager.mark_url_failed(url)
                continue
        
        return all_results
    
    def _process_and_save_results(
        self, 
        all_results: Dict[str, List[Dict[str, Any]]], 
        host: str, 
        output_path: Path
    ):
        """Process scraping results and save to files"""
        self.logger.info(f"Processing and saving results", host=host)
        
        sanitized_host = sanitize_filename(host)
        
        # Save raw scraping results
        results_file = output_path / f"res[{sanitized_host}].json"
        if self.file_manager.safe_save_json(all_results, str(results_file)):
            self.logger.info(f"Saved scraping results", file=str(results_file))
        
        # Process text and create bag of words
        all_bow = {}
        for url, tree_results in all_results.items():
            try:
                bow = self.text_processor.create_bag_of_words(tree_results)
                # Convert Counter to dict for JSON serialization
                all_bow[url] = dict(bow)
            except Exception as e:
                self.logger.error(f"Error creating bag of words", url=url, exception=e)
                all_bow[url] = {}
        
        # Save bag of words
        bow_file = output_path / f"bow[{sanitized_host}].json"
        if self.file_manager.safe_save_json(all_bow, str(bow_file)):
            self.logger.info(f"Saved bag of words", file=str(bow_file))
    
    def _save_intermediate_results(
        self, 
        results: Dict[str, List[Dict[str, Any]]], 
        host: str, 
        output_path: Path
    ):
        """Save intermediate results during processing"""
        if not results:
            return
        
        sanitized_host = sanitize_filename(host)
        temp_file = output_path / f"temp_res[{sanitized_host}].json"
        
        try:
            self.file_manager.safe_save_json(results, str(temp_file))
        except Exception as e:
            self.logger.warning(f"Could not save intermediate results", exception=e)
    
    def _log_performance_stats(self):
        """Log performance statistics"""
        stats = self.performance_monitor.get_all_stats()
        for operation, metrics in stats.items():
            if metrics:
                self.logger.info(
                    f"Performance stats for {operation}",
                    count=metrics["count"],
                    total_time=f"{metrics['total']:.2f}s",
                    avg_time=f"{metrics['average']:.2f}s",
                    min_time=f"{metrics['min']:.2f}s",
                    max_time=f"{metrics['max']:.2f}s"
                )


def process_urls_from_file(
    filename: str,
    config: Optional[Config] = None,
    year_range: Optional[Tuple[int, int]] = None
):
    """
    Process URLs from a CSV file across multiple years
    
    Args:
        filename: CSV file containing URLs
        config: Configuration object
        year_range: Tuple of (start_year, end_year) for processing
    """
    config = config or Config()
    scraper = ImprovedWaybackScraper(config)
    logger = ScrapingLogger(config.logging)
    
    # Load URLs from file
    try:
        urls_df = pl.read_csv(f"{config.paths.collection_files_path}{filename}")
        url_list = urls_df['URL'].to_list()
        print(f"📁 Loaded {len(url_list)} URLs from {filename}")
    except Exception as e:
        print(f"❌ Could not load URLs file {filename}: {e}")
        return
    
    # Set default year range
    if year_range is None:
        year_range = (2000, 2024)
    
    start_year, end_year = year_range
    total_years = end_year - start_year + 1
    
    print(f"📅 Processing years {start_year}-{end_year} ({total_years} years)")
    
    # Track overall progress
    overall_start_time = time.time()
    completed_year_url_pairs = 0
    total_year_url_pairs = 0
    
    # Calculate total work
    for year in range(start_year, end_year + 1):
        year_path = Path(config.paths.base_path) / "Annual Files" / f"JSON_{year}"
        processed_hosts = set()
        if year_path.exists():
            for file in year_path.glob("cdx*.csv"):
                if file.name.startswith('cdx[') and file.name.endswith('].csv'):
                    match = re.search(r'cdx\[(.*?)\]\.csv', file.name)
                    if match:
                        host = match.group(1).replace('_', '.')
                        processed_hosts.add(host)
        urls_to_process = [url for url in url_list if url not in processed_hosts]
        total_year_url_pairs += len(urls_to_process)
    
    print(f"🎯 Total work: {total_year_url_pairs} URL-year combinations to process")
    
    # Process each year in reverse order (newest to oldest)
    years_to_process = list(range(start_year, end_year + 1))
    years_to_process.reverse()  # Process from end_year down to start_year
    
    for year_idx, year in enumerate(years_to_process):
        year_path = Path(config.paths.base_path) / "Annual Files" / f"JSON_{year}"
        
        # Check which URLs have already been processed
        processed_hosts = set()
        if year_path.exists():
            for file in year_path.glob("cdx*.csv"):
                if file.name.startswith('cdx[') and file.name.endswith('].csv'):
                    match = re.search(r'cdx\[(.*?)\]\.csv', file.name)
                    if match:
                        host = match.group(1).replace('_', '.')
                        processed_hosts.add(host)
        
        urls_to_process = [url for url in url_list if url not in processed_hosts]
        
        if not urls_to_process:
            print(f"✅ Year {year}: All {len(url_list)} URLs already processed")
            continue
        
        print(f"\n📊 Year {year} ({year_idx+1}/{total_years}): Processing {len(urls_to_process)} URLs (skipping {len(processed_hosts)} already done)")
        
        year_start_time = time.time()
        date_range = (f'{year}-01-01', f'{year}-12-31')
        
        for i, url in enumerate(urls_to_process):
            url_start_time = time.time()
            
            # Show which URL we're starting
            print(f"🔄 [{completed_year_url_pairs+1}/{total_year_url_pairs}] Processing {url}...", end="", flush=True)
            
            try:
                success = scraper.scrape_host(
                    host=url,
                    frequency='YE',
                    date_range=date_range,
                    output_path=str(year_path)
                )
                
                url_duration = time.time() - url_start_time
                completed_year_url_pairs += 1
                
                # Calculate time estimates
                if completed_year_url_pairs > 0:
                    elapsed_total = time.time() - overall_start_time
                    avg_time_per_url = elapsed_total / completed_year_url_pairs
                    remaining_urls = total_year_url_pairs - completed_year_url_pairs
                    eta_seconds = remaining_urls * avg_time_per_url
                    eta_str = format_duration(eta_seconds)
                else:
                    eta_str = "calculating..."
                
                status = "✅" if success else "⚠️"
                # Clear the "Processing..." line and show result
                print(f"\r{status} [{completed_year_url_pairs}/{total_year_url_pairs}] {url} ({format_duration(url_duration)}) - ETA: {eta_str}")
                
            except Exception as e:
                completed_year_url_pairs += 1
                error_msg = str(e)[:80] + "..." if len(str(e)) > 80 else str(e)
                # Clear the "Processing..." line and show error
                print(f"\r❌ [{completed_year_url_pairs}/{total_year_url_pairs}] {url} - ERROR: {error_msg}")
                continue
        
        year_duration = time.time() - year_start_time
        print(f"✅ Year {year} completed in {format_duration(year_duration)}")
    
    total_duration = time.time() - overall_start_time
    print(f"\n🎉 All processing completed in {format_duration(total_duration)}!")
    print(f"📈 Processed {completed_year_url_pairs} URL-year combinations")


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python run_wbm.py <urls_filename> [start_year] [end_year]")
        sys.exit(1)
    
    filename = sys.argv[1]
    
    # Parse year range if provided
    year_range = None
    if len(sys.argv) >= 4:
        try:
            start_year = int(sys.argv[2])
            end_year = int(sys.argv[3])
            year_range = (start_year, end_year)
        except ValueError:
            print("Error: Year arguments must be integers")
            sys.exit(1)
    
    # Initialize configuration
    config = Config()
    
    # Process URLs
    process_urls_from_file(filename, config, year_range)


if __name__ == "__main__":
    main()
