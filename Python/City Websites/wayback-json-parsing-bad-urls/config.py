"""
Configuration for Bad URLs Recovery Pipeline
"""

from pathlib import Path
from dataclasses import dataclass
from typing import List

# =============================================================================
# Paths Configuration
# =============================================================================

@dataclass
class PathConfig:
    """File paths for the recovery pipeline"""
    
    # Input: bad URLs CSV
    bad_urls_file: str = "~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/bad_urls_251105.csv"
    
    # Original scraping output directory
    base_path: str = "~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Updated Scraping 202509/"
    
    # Collection files directory
    collection_files_path: str = "~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/"
    
    # Output directory for recovery results
    recovery_output_path: str = "~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Recovery 202511/"
    
    # Reports directory
    reports_dir: str = "./reports"
    
    def __post_init__(self):
        # Expand home directory paths
        self.bad_urls_file = str(Path(self.bad_urls_file).expanduser())
        self.base_path = str(Path(self.base_path).expanduser())
        self.collection_files_path = str(Path(self.collection_files_path).expanduser())
        self.recovery_output_path = str(Path(self.recovery_output_path).expanduser())
        self.reports_dir = str(Path(self.reports_dir).expanduser())
        
        # Create directories if they don't exist
        Path(self.recovery_output_path).mkdir(parents=True, exist_ok=True)
        Path(self.reports_dir).mkdir(parents=True, exist_ok=True)


# =============================================================================
# Investigation Configuration
# =============================================================================

@dataclass
class InvestigationConfig:
    """Settings for investigating bad URLs"""
    
    # Number of snapshots to test per URL-year pair
    sample_size: int = 10
    
    # Request timeout in seconds
    timeout: int = 30
    
    # Minimum sub-URLs to consider a snapshot successful
    min_suburls_threshold: int = 5
    
    # Maximum number of bad URLs to process in one run (0 = all)
    max_to_process: int = 0
    
    # Rate limit delay between requests (seconds)
    rate_limit_delay: float = 2.0
    
    # Prioritize testing snapshots by file size
    prioritize_by_size: bool = True
    
    # Skip if a good alternative was already found
    skip_if_found: bool = True


# =============================================================================
# Scraping Configuration
# =============================================================================

@dataclass
class ScrapingConfig:
    """Settings for re-scraping with better snapshots"""
    
    # Maximum URLs to scrape per tree
    max_urls: int = 50
    
    # Maximum sub-URL depth
    max_sub_levels: int = 3
    
    # Rate limit delay (seconds)
    rate_limit_delay: float = 8.0
    
    # Request timeout (seconds)
    timeout: int = 45
    
    # Max retries for failed requests
    max_retries: int = 3
    
    # Valid HTTP status codes
    valid_status_codes: List[str] = None
    
    # Valid MIME types
    valid_mime_types: List[str] = None
    
    # Parser for BeautifulSoup
    parser: str = "lxml"
    
    # Include raw HTML in results
    include_raw_html: bool = False
    
    def __post_init__(self):
        if self.valid_status_codes is None:
            self.valid_status_codes = ["200"]
        if self.valid_mime_types is None:
            self.valid_mime_types = ["text/html"]


# =============================================================================
# Network Configuration
# =============================================================================

@dataclass
class NetworkConfig:
    """Network request configuration"""
    
    contact_email: str = "munevar.santiago@gmail.com"
    user_agent: str = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/91.0.4472.124 Safari/537.36"
    )
    
    @property
    def headers(self):
        return {
            "User-Agent": self.user_agent,
            "From": self.contact_email
        }


# =============================================================================
# Logging Configuration
# =============================================================================

@dataclass
class LoggingConfig:
    """Logging configuration"""
    
    log_level: str = "INFO"
    log_to_file: bool = True
    log_file: str = "recovery_pipeline.log"
    console_log_level: str = "INFO"


# =============================================================================
# Main Configuration
# =============================================================================

@dataclass
class Config:
    """Main configuration combining all components"""
    
    paths: PathConfig = None
    investigation: InvestigationConfig = None
    scraping: ScrapingConfig = None
    network: NetworkConfig = None
    logging: LoggingConfig = None
    
    def __post_init__(self):
        if self.paths is None:
            self.paths = PathConfig()
        if self.investigation is None:
            self.investigation = InvestigationConfig()
        if self.scraping is None:
            self.scraping = ScrapingConfig()
        if self.network is None:
            self.network = NetworkConfig()
        if self.logging is None:
            self.logging = LoggingConfig()


# =============================================================================
# Default Configuration Instance
# =============================================================================

config = Config()
