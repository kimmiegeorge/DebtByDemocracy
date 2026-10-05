"""
Improved Wayback Machine Scraper Package
Enhanced with better error handling, performance monitoring, and recovery capabilities
"""

__version__ = "2.0.0"
__author__ = "Enhanced by AI Assistant"
__description__ = "An improved version of the Wayback Machine scraper with enhanced functionality"

from .config import Config
from .scraper import WaybackAPIClient, TreeScraper, URLScraper, TextProcessor
from .run_wbm import ImprovedWaybackScraper, process_urls_from_file
from .utils import (
    ScrapingLogger, PerformanceMonitor, FileManager, SessionManager,
    DataValidator, URLFilter, RateLimiter
)

__all__ = [
    # Main classes
    "ImprovedWaybackScraper",
    "Config",
    
    # Core scraping components
    "WaybackAPIClient",
    "TreeScraper", 
    "URLScraper",
    "TextProcessor",
    
    # Utility classes
    "ScrapingLogger",
    "PerformanceMonitor", 
    "FileManager",
    "SessionManager",
    "DataValidator",
    "URLFilter",
    "RateLimiter",
    
    # Functions
    "process_urls_from_file",
]
