#!/usr/bin/env python3
"""
Example Usage of the Improved Wayback Machine Scraper
Demonstrates various ways to use the enhanced scraper
"""

import os
from pathlib import Path
from config import Config
from run_wbm import ImprovedWaybackScraper
from utils import ScrapingLogger


def example_basic_usage():
    """Basic example of scraping a single website"""
    print("=== Basic Usage Example ===")
    
    # Initialize scraper with default configuration
    scraper = ImprovedWaybackScraper()
    
    # Scrape a single host for a specific year
    success = scraper.scrape_host(
        host="www.example-city.gov",
        frequency="Y",  # Yearly frequency
        date_range=("2023-01-01", "2023-12-31"),
        output_path="./example_output/basic/"
    )
    
    if success:
        print("✅ Basic scraping completed successfully!")
    else:
        print("❌ Basic scraping failed.")


def example_custom_configuration():
    """Example with custom configuration"""
    print("\n=== Custom Configuration Example ===")
    
    # Create custom configuration
    config = Config()
    
    # Customize network settings
    config.network.rate_limit_delay = 3.0  # Faster rate (be careful with API limits)
    config.network.max_retries = 3
    config.network.timeout_seconds = 120
    
    # Customize scraping behavior
    config.scraping.max_urls = 30
    config.scraping.max_sub_levels = 2
    config.scraping.priority_keywords.extend(["budget", "treasury", "audit"])
    
    # Customize text processing
    config.text_processing.use_stemmer = False  # Disable stemming
    config.text_processing.word_length_range = (2, 15)  # Shorter max word length
    
    # Customize logging
    config.logging.log_level = "DEBUG"
    config.logging.log_file_path = "./example_custom.log"
    
    # Initialize scraper with custom config
    scraper = ImprovedWaybackScraper(config)
    
    # Scrape with custom settings
    success = scraper.scrape_host(
        host="www.finance-city.gov",
        frequency="Y",
        date_range=("2022-01-01", "2022-12-31"),
        output_path="./example_output/custom/",
        max_urls=25,  # Override config setting
        max_sub_levels=1  # Override config setting
    )
    
    if success:
        print("✅ Custom configuration scraping completed successfully!")
    else:
        print("❌ Custom configuration scraping failed.")


def example_multi_year_processing():
    """Example of processing multiple years"""
    print("\n=== Multi-Year Processing Example ===")
    
    config = Config()
    scraper = ImprovedWaybackScraper(config)
    
    host = "www.multi-year-city.gov"
    base_path = "./example_output/multi_year/"
    
    years = [2020, 2021, 2022, 2023]
    
    for year in years:
        print(f"\n📅 Processing year {year}...")
        
        year_path = Path(base_path) / f"year_{year}"
        date_range = (f"{year}-01-01", f"{year}-12-31")
        
        success = scraper.scrape_host(
            host=host,
            frequency="Y",
            date_range=date_range,
            output_path=str(year_path),
            resume_session=True  # Enable session resumption
        )
        
        if success:
            print(f"✅ Year {year} completed successfully!")
        else:
            print(f"❌ Year {year} failed.")


def example_error_handling_and_monitoring():
    """Example demonstrating error handling and monitoring features"""
    print("\n=== Error Handling and Monitoring Example ===")
    
    # Configure for detailed logging and monitoring
    config = Config()
    config.logging.log_level = "INFO"
    config.logging.log_to_file = True
    config.logging.log_file_path = "./example_monitoring.log"
    
    # Enable backups for safety
    config.paths.backup_enabled = True
    
    scraper = ImprovedWaybackScraper(config)
    
    # List of hosts (some may fail intentionally for demonstration)
    test_hosts = [
        "www.valid-city.gov",
        "www.invalid-city-that-does-not-exist.gov",  # This should fail
        "www.another-city.gov"
    ]
    
    results = []
    
    for i, host in enumerate(test_hosts):
        print(f"\n📊 Processing host {i+1}/{len(test_hosts)}: {host}")
        
        try:
            success = scraper.scrape_host(
                host=host,
                frequency="Y",
                date_range=("2023-01-01", "2023-12-31"),
                output_path="./example_output/monitoring/",
                resume_session=True
            )
            
            results.append((host, success))
            
            if success:
                print(f"✅ {host} completed successfully!")
            else:
                print(f"⚠️ {host} completed with issues.")
                
        except Exception as e:
            print(f"❌ {host} failed with error: {e}")
            results.append((host, False))
    
    # Summary
    print(f"\n📋 Results Summary:")
    successful = sum(1 for _, success in results if success)
    total = len(results)
    print(f"Successful: {successful}/{total}")
    
    for host, success in results:
        status = "✅" if success else "❌"
        print(f"  {status} {host}")


def example_resume_session():
    """Example of session resumption after interruption"""
    print("\n=== Session Resumption Example ===")
    
    config = Config()
    scraper = ImprovedWaybackScraper(config)
    
    host = "www.resume-test-city.gov"
    output_path = "./example_output/resume/"
    
    print("🔄 Starting initial scraping session...")
    
    # Start scraping (this might be interrupted)
    success = scraper.scrape_host(
        host=host,
        frequency="Y",
        date_range=("2023-01-01", "2023-12-31"),
        output_path=output_path,
        resume_session=True,  # Enable session management
        max_urls=50  # Large number to demonstrate resumption
    )
    
    if success:
        print("✅ Initial session completed successfully!")
    else:
        print("⚠️ Initial session may have been interrupted.")
    
    print("\n🔄 Attempting to resume session...")
    
    # Resume the session (will skip already completed URLs)
    success = scraper.scrape_host(
        host=host,
        frequency="Y",
        date_range=("2023-01-01", "2023-12-31"),
        output_path=output_path,
        resume_session=True  # This will resume from where it left off
    )
    
    if success:
        print("✅ Session resumption completed successfully!")
    else:
        print("❌ Session resumption failed.")


def cleanup_examples():
    """Clean up example output directories"""
    print("\n🧹 Cleaning up example outputs...")
    
    import shutil
    
    example_dirs = [
        "./example_output/",
        "./example_custom.log",
        "./example_monitoring.log"
    ]
    
    for path in example_dirs:
        try:
            if os.path.exists(path):
                if os.path.isdir(path):
                    shutil.rmtree(path)
                else:
                    os.remove(path)
                print(f"🗑️ Removed: {path}")
        except Exception as e:
            print(f"⚠️ Could not remove {path}: {e}")


def main():
    """Run all examples"""
    print("🚀 Improved Wayback Machine Scraper - Examples")
    print("=" * 50)
    
    try:
        # Run examples
        example_basic_usage()
        example_custom_configuration()
        example_multi_year_processing()
        example_error_handling_and_monitoring()
        example_resume_session()
        
        print("\n" + "=" * 50)
        print("✅ All examples completed!")
        
        # Ask about cleanup
        response = input("\n🧹 Would you like to clean up example outputs? (y/n): ").strip().lower()
        if response in ['y', 'yes']:
            cleanup_examples()
            print("✅ Cleanup completed!")
        else:
            print("📁 Example outputs preserved for your review.")
            print("You can find them in the './example_output/' directory.")
            
    except KeyboardInterrupt:
        print("\n\n⚠️ Examples interrupted by user.")
    except Exception as e:
        print(f"\n\n❌ An error occurred: {e}")


if __name__ == "__main__":
    main()
