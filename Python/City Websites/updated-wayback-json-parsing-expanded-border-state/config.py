"""
Improved Wayback Machine Scraper Configuration
Enhanced with better error handling, performance settings, and modular design
"""

import os
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
from nltk.corpus import stopwords
from nltk.stem.porter import PorterStemmer

# %% Configuration Classes

@dataclass
class NetworkConfig:
    """Network and request configuration"""
    contact_email: str = "munevar.santiago@gmail.com"
    user_agent: str = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/91.0.4472.124 Safari/537.36"
    )
    max_retries: int = 3  # Reduced from 5 to fail faster
    backoff_factor: float = 2.0
    retry_status_codes: List[int] = None
    timeout_seconds: int = 45  # Much shorter timeout (was 180)
    rate_limit_delay: float = 8.0  # Increased from 6 to be more conservative 
    connection_timeout: float = 15.0  # Reduced from 30
    read_timeout: float = 30.0  # Reduced from 60
    
    def __post_init__(self):
        if self.retry_status_codes is None:
            self.retry_status_codes = [429, 500, 502, 503, 504]
    
    @property
    def headers(self) -> Dict[str, str]:
        return {"User-Agent": self.user_agent, "From": self.contact_email}


@dataclass
class ScrapingConfig:
    """Scraping behavior configuration"""
    max_urls: int = 50
    max_sub_levels: int = 3
    parser: str = "lxml"
    include_raw_html: bool = False
    valid_status_codes: List[str] = None
    valid_mime_types: List[str] = None
    collapse_time_hours: int = 10
    
    # URL filtering settings
    social_media_domains: List[str] = None
    language_specifiers: List[str] = None
    exclude_keywords: List[str] = None
    priority_keywords: List[str] = None
    general_priority_keywords: List[str] = None
    
    def __post_init__(self):
        if self.valid_status_codes is None:
            self.valid_status_codes = ["200"]
        if self.valid_mime_types is None:
            self.valid_mime_types = ["text/html"]
        if self.social_media_domains is None:
            self.social_media_domains = [
                "facebook.com", "instagram.com", "meta.com", "linkedin.com",
                "twitter.com", "x.com", "nextdoor.com", "youtube.com",
                "tiktok.com", "snapchat.com", "pinterest.com"
            ]
        if self.language_specifiers is None:
            self.language_specifiers = [
                '/es/', '/fr/', '/ja/', '/hi/', '/zh/', '/it/', 
                '/ar/', '/pt/', '/de/', '/ko/', '/ru/', '/nl/'
            ]
        if self.exclude_keywords is None:
            self.exclude_keywords = [
                "myaccount", "search", "civicalerts", "calendar.aspx", 
                "index.aspx", "login", "register", "admin", "wp-admin"
            ]
        if self.priority_keywords is None:
            self.priority_keywords = [
                "finance", "bond", "financial", "proposition", "debt",
                "credit", "fiscal", "capital", "budget", "treasury"
            ]
        if self.general_priority_keywords is None:
            self.general_priority_keywords = ["department"]


@dataclass
class TextProcessingConfig:
    """Text processing and tokenization configuration"""
    use_alpha_tokens: bool = True
    word_length_range: tuple = (1, 20)
    use_stopwords: bool = True
    use_stemmer: bool = True
    language: str = "english"
    
    def __post_init__(self):
        self._stopwords = stopwords.words(self.language) if self.use_stopwords else None
        self._stemmer = PorterStemmer() if self.use_stemmer else None
    
    @property
    def stopwords_list(self):
        return self._stopwords
    
    @property
    def stemmer(self):
        return self._stemmer
    
    @property
    def bow_options(self) -> Dict[str, Any]:
        return {
            "alpha_token": self.use_alpha_tokens,
            "word_len": self.word_length_range,
            "stop_words": self.stopwords_list,
            "stemmer": self.stemmer,
        }


@dataclass
class PathConfig:
    """File and directory path configuration"""
    base_path: str = "/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Updated Scraping 202509/"
    collection_files_path: str = "/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files 20251009/"
    backup_enabled: bool = True
    create_directories: bool = True
    
    def __post_init__(self):
        if self.create_directories:
            Path(self.base_path).mkdir(parents=True, exist_ok=True)
            Path(self.collection_files_path).mkdir(parents=True, exist_ok=True)


@dataclass
class LoggingConfig:
    """Logging configuration"""
    log_level: str = "WARNING"  # Reduced from INFO to WARNING for less verbose output
    log_to_file: bool = True
    log_file_path: Optional[str] = None
    max_log_size_mb: int = 10
    backup_count: int = 5
    console_log_level: str = "WARNING"  # Separate console logging level
    
    def __post_init__(self):
        if self.log_file_path is None:
            self.log_file_path = "wayback_scraper.log"


# %% Main Configuration Class

@dataclass
class Config:
    """Main configuration class combining all configuration components"""
    network: NetworkConfig = None
    scraping: ScrapingConfig = None
    text_processing: TextProcessingConfig = None
    paths: PathConfig = None
    logging: LoggingConfig = None
    
    def __post_init__(self):
        if self.network is None:
            self.network = NetworkConfig()
        if self.scraping is None:
            self.scraping = ScrapingConfig()
        if self.text_processing is None:
            self.text_processing = TextProcessingConfig()
        if self.paths is None:
            self.paths = PathConfig()
        if self.logging is None:
            self.logging = LoggingConfig()


# %% Default Configuration Instance
config = Config()

# %% Legacy compatibility (for backward compatibility with original code)
# These maintain the same names as the original config for drop-in replacement
status_code = config.scraping.valid_status_codes
mime_type = config.scraping.valid_mime_types
headers = config.network.headers
max_url = config.scraping.max_urls
max_sub = config.scraping.max_sub_levels
parser = config.scraping.parser
raw = config.scraping.include_raw_html
bow_options = config.text_processing.bow_options
path = config.paths.base_path
collection_files_path = config.paths.collection_files_path
