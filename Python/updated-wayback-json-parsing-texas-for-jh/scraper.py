"""
Improved Wayback Machine Scraper Core Module
Enhanced with better error handling, performance monitoring, and modular design
"""

import re
import time
import json
import string
import itertools
from io import BytesIO
from typing import Dict, Any, Optional, List, Tuple
from collections import Counter
from urllib.parse import urljoin

import nltk
import requests
import pandas as pd
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from concurrent.futures import ThreadPoolExecutor, as_completed

from config import Config
from utils import (
    ScrapingLogger, PerformanceMonitor, DataValidator, FileManager,
    URLFilter, RateLimiter, retry_on_failure, sanitize_filename
)


class WaybackAPIClient:
    """Enhanced Wayback Machine API client with better error handling"""
    
    def __init__(self, config: Config):
        self.config = config
        self.logger = ScrapingLogger(config.logging)
        self.session = self._create_session()
        self.rate_limiter = RateLimiter(config.network.rate_limit_delay)
    
    def _create_session(self) -> requests.Session:
        """Create requests session with retry strategy"""
        session = requests.Session()
        
        retry_strategy = Retry(
            total=self.config.network.max_retries,
            backoff_factor=self.config.network.backoff_factor,
            status_forcelist=self.config.network.retry_status_codes,
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount('http://', adapter)
        session.mount('https://', adapter)
        
        return session
    
    @retry_on_failure(max_attempts=3, delay=2.0)
    def query_wayback(self, host: str, match_type: str = "exact") -> Optional[pd.DataFrame]:
        """
        Query Wayback Machine API for archived URLs
        
        Args:
            host: The host/domain to search for
            match_type: Type of URL matching (exact, prefix, host, domain)
            
        Returns:
            DataFrame with query results or None if no results
        """
        self.rate_limiter.wait_if_needed()
        
        # Build query URL
        query_url = (
            f"http://web.archive.org/cdx/search/cdx?"
            f"url={host}&"
            f"matchType={match_type}&"
            f"collapse=timestamp:{self.config.scraping.collapse_time_hours}&"
            f"output=json"
        )
        
        self.logger.info(f"Querying Wayback API", host=host, match_type=match_type)
        
        try:
            response = self.session.get(
                query_url, 
                headers=self.config.network.headers,
                timeout=(
                    self.config.network.connection_timeout,
                    self.config.network.read_timeout
                ),
                allow_redirects=True
            )
            response.raise_for_status()
            
            # Parse JSON response
            df = pd.read_json(BytesIO(response.content))
            
            if df.empty:
                self.logger.warning(f"No archived URLs found", host=host)
                return None
            
            # Process response
            df = self._process_wayback_response(df, host)
            
            if df is not None and not df.empty:
                self.logger.info(
                    f"Found archived URLs", 
                    host=host, 
                    count=len(df)
                )
            
            return df
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Request failed for Wayback API", exception=e, host=host)
            raise
        except Exception as e:
            self.logger.error(f"Unexpected error in Wayback API query", exception=e, host=host)
            raise
    
    def _process_wayback_response(self, df: pd.DataFrame, host: str) -> Optional[pd.DataFrame]:
        """Process and clean Wayback Machine API response"""
        try:
            # First row contains column headers
            if df.shape[0] == 0:
                return None
                
            df.columns = df.iloc[0]
            df = df.drop(df.index[0]).reset_index(drop=True)
            
            # Validate required columns
            required_cols = ["timestamp", "original", "urlkey", "statuscode", "mimetype", "length"]
            if not DataValidator.validate_dataframe(df, required_cols):
                self.logger.warning(f"Response missing required columns", host=host)
                return None
            
            # Clean timestamps
            df["datetime"] = pd.to_datetime(
                df["timestamp"], 
                format="%Y%m%d%H%M%S", 
                errors="coerce"
            )
            
            # Remove invalid timestamps
            valid_mask = df["datetime"].notnull()
            if not valid_mask.all():
                invalid_count = (~valid_mask).sum()
                self.logger.warning(
                    f"Removed entries with invalid timestamps", 
                    host=host, 
                    count=invalid_count
                )
                df = df[valid_mask]
            
            # Handle multiple urlkeys (keep shortest)
            if df["urlkey"].nunique() > 1:
                shortest_urlkey = sorted(df["urlkey"].values, key=len)[0]
                df = df[df["urlkey"] == shortest_urlkey]
                self.logger.info(
                    f"Multiple urlkeys found, kept shortest", 
                    host=host, 
                    urlkey=shortest_urlkey
                )
            
            # Create full archive URLs
            df["url"] = [
                f"https://web.archive.org/web/{timestamp}/{original}"
                for timestamp, original in zip(df["timestamp"], df["original"])
            ]
            
            # Sort by URL key and datetime
            df = df.sort_values(["urlkey", "datetime"]).reset_index(drop=True)
            
            return df
            
        except Exception as e:
            self.logger.error(f"Error processing Wayback response", exception=e, host=host)
            return None


class URLScraper:
    """Enhanced URL scraping with better error handling and performance"""
    
    def __init__(self, config: Config):
        self.config = config
        self.logger = ScrapingLogger(config.logging)
        self.session = self._create_session()
        self.rate_limiter = RateLimiter(config.network.rate_limit_delay)
        self.performance_monitor = PerformanceMonitor()
    
    def _create_session(self) -> requests.Session:
        """Create requests session with retry strategy"""
        session = requests.Session()
        
        retry_strategy = Retry(
            total=self.config.network.max_retries,
            backoff_factor=self.config.network.backoff_factor,
            status_forcelist=self.config.network.retry_status_codes,
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy)
        session.mount('http://', adapter)
        session.mount('https://', adapter)
        
        return session
    
    def scrape_url(self, url: str) -> Dict[str, Any]:
        """
        Scrape a single URL with comprehensive error handling
        
        Args:
            url: URL to scrape
            
        Returns:
            Dictionary with scraping results
        """
        self.performance_monitor.start_timer("url_scrape")
        
        # Initialize result dictionary
        result = {
            "URL": url,
            "cURL": url,
            "error": None,
            "subURLs": [],
            "text": "",
            "status_code": None,
            "content_type": None,
            "content_length": None
        }
        
        if self.config.scraping.include_raw_html:
            result["raw"] = ""
        
        self.rate_limiter.wait_if_needed()
        
        try:
            # Make request
            response = self.session.get(
                url,
                headers=self.config.network.headers,
                timeout=(
                    self.config.network.connection_timeout,
                    self.config.network.read_timeout
                ),
                allow_redirects=True
            )
            
            # Update result with response info
            result["cURL"] = response.url
            result["status_code"] = response.status_code
            result["content_type"] = response.headers.get("Content-Type", "")
            result["content_length"] = len(response.content) if response.content else 0
            
            # Validate response
            validation_error = self._validate_response(response)
            if validation_error:
                result["error"] = validation_error
                return result
            
            # Process content
            html_content = response.text
            if self.config.scraping.include_raw_html:
                result["raw"] = html_content
            
            # Parse HTML
            soup = BeautifulSoup(html_content, self.config.scraping.parser)
            
            # Clean soup (remove scripts, styles, wayback elements)
            self._clean_soup(soup)
            
            # Extract text
            try:
                if soup.body:
                    result["text"] = soup.body.get_text(separator=" ", strip=True)
                else:
                    result["text"] = soup.get_text(separator=" ", strip=True)
            except Exception as e:
                self.logger.warning(f"Error extracting text", url=url, exception=e)
                result["text"] = ""
            
            # Extract sub-URLs
            result["subURLs"] = self._extract_sub_urls(soup, response.url)
            
        except requests.exceptions.Timeout:
            result["error"] = "Request timeout"
            self.logger.warning(f"Request timeout", url=url)
        except requests.exceptions.RequestException as e:
            result["error"] = f"Request failed: {str(e)}"
            self.logger.warning(f"Request failed", url=url, exception=e)
        except Exception as e:
            result["error"] = f"Unexpected error: {str(e)}"
            self.logger.error(f"Unexpected error in URL scraping", url=url, exception=e)
        
        duration = self.performance_monitor.end_timer("url_scrape")
        self.logger.info(f"URL scraped", url=url, duration=f"{duration:.2f}s", error=result["error"])
        
        return result
    
    def _validate_response(self, response: requests.Response) -> Optional[str]:
        """Validate HTTP response"""
        # Check status code
        if str(response.status_code) not in self.config.scraping.valid_status_codes:
            return f"Invalid status code: {response.status_code}"
        
        # Check content type
        content_type = response.headers.get("Content-Type", "")
        if not any(mime_type in content_type for mime_type in self.config.scraping.valid_mime_types):
            return f"Invalid content type: {content_type}"
        
        return None
    
    def _clean_soup(self, soup: BeautifulSoup):
        """Remove unwanted elements from BeautifulSoup object"""
        # Remove scripts and styles
        for element in soup(["script", "style"]):
            element.decompose()
        
        # Remove Wayback Machine elements
        wayback_ids = ["wm-ipp-base", "wm-ipp-print", "donato"]
        for div_id in wayback_ids:
            for div in soup.find_all("div", id=div_id):
                div.decompose()
    
    def _extract_sub_urls(self, soup: BeautifulSoup, base_url: str) -> List[str]:
        """Extract and normalize sub-URLs from HTML"""
        sub_urls = []
        
        for tag in soup.find_all("a", href=True):
            try:
                href = tag["href"]
                if href:
                    # Join with base URL to handle relative links
                    full_url = urljoin(base_url, href)
                    if DataValidator.is_valid_url(full_url):
                        sub_urls.append(full_url)
            except Exception as e:
                # Skip problematic URLs
                continue
        
        return sub_urls


class TreeScraper:
    """Enhanced tree scraping with priority-based traversal and filtering"""
    
    def __init__(self, config: Config):
        self.config = config
        self.logger = ScrapingLogger(config.logging)
        self.url_scraper = URLScraper(config)
        self.url_filter = URLFilter(config.scraping)
        self.performance_monitor = PerformanceMonitor()
    
    def scrape_tree(
        self, 
        root_url: str, 
        host: str, 
        max_urls: Optional[int] = None, 
        max_sub_levels: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        Scrape a tree of URLs starting from root_url
        
        Args:
            root_url: Starting URL for tree traversal
            host: Host domain to filter URLs
            max_urls: Maximum number of URLs to scrape
            max_sub_levels: Maximum depth of sub-URL traversal
            
        Returns:
            List of scraping results
        """
        max_urls = max_urls or self.config.scraping.max_urls
        max_sub_levels = max_sub_levels or self.config.scraping.max_sub_levels
        
        self.performance_monitor.start_timer("tree_scrape")
        self.logger.info(
            f"Starting tree scrape", 
            root_url=root_url, 
            host=host,
            max_urls=max_urls,
            max_sub_levels=max_sub_levels
        )
        
        # Initialize tracking structures
        results = []
        urls_to_process = [(root_url, 0, 0)]  # (url, level, priority)
        seen_urls = {root_url}
        
        urls_scraped = 0
        current_level = 0
        
        while urls_to_process and urls_scraped < max_urls and current_level <= max_sub_levels:
            # Sort by priority (higher first) then by level (lower first)
            urls_to_process.sort(key=lambda x: (-x[2], x[1]))
            
            current_url, level, priority = urls_to_process.pop(0)
            current_level = max(current_level, level)
            
            # Skip if we've exceeded level limit
            if level > max_sub_levels:
                continue
            
            self.logger.info(
                f"Scraping URL", 
                url=current_url, 
                level=level, 
                priority=priority,
                progress=f"{urls_scraped+1}/{max_urls}"
            )
            
            # Scrape the URL
            try:
                scrape_result = self.url_scraper.scrape_url(current_url)
                scrape_result["sub_level"] = level
                scrape_result["priority"] = priority
                results.append(scrape_result)
                urls_scraped += 1
                
                # Process sub-URLs if scraping was successful
                if not scrape_result["error"] and level < max_sub_levels:
                    new_urls = self._process_sub_urls(
                        scrape_result["subURLs"], 
                        host, 
                        level + 1, 
                        seen_urls
                    )
                    urls_to_process.extend(new_urls)
                
            except Exception as e:
                self.logger.error(f"Error scraping URL", url=current_url, exception=e)
                # Add error result
                results.append({
                    "URL": current_url,
                    "cURL": current_url,
                    "error": f"Scraping failed: {str(e)}",
                    "subURLs": [],
                    "text": "",
                    "sub_level": level,
                    "priority": priority
                })
                urls_scraped += 1
        
        duration = self.performance_monitor.end_timer("tree_scrape")
        
        self.logger.info(
            f"Tree scraping completed",
            root_url=root_url,
            urls_seen=len(seen_urls),
            urls_scraped=len(results),
            urls_with_errors=sum(1 for r in results if r.get("error")),
            final_level=current_level,
            duration=f"{duration:.2f}s"
        )
        
        return results
    
    def _process_sub_urls(
        self, 
        sub_urls: List[str], 
        host: str, 
        level: int, 
        seen_urls: set
    ) -> List[Tuple[str, int, int]]:
        """
        Process and filter sub-URLs for further scraping
        
        Returns:
            List of tuples (url, level, priority)
        """
        new_urls = []
        
        for url in sub_urls:
            # Basic cleanup
            clean_url = url.split("#")[0] if url else ""
            if not clean_url or clean_url in seen_urls:
                continue
            
            # Apply filters
            should_skip, reason = self.url_filter.should_skip_url(clean_url, host)
            if should_skip:
                continue
            
            # Calculate priority
            priority = self.url_filter.calculate_priority(clean_url)
            
            # Add to processing queue
            new_urls.append((clean_url, level, priority))
            seen_urls.add(clean_url)
        
        return new_urls


class TextProcessor:
    """Enhanced text processing and tokenization"""
    
    def __init__(self, config: Config):
        self.config = config
        self.bow_options = config.text_processing.bow_options
    
    def tokenize_text(self, text: str) -> List[str]:
        """
        Enhanced text tokenization with configurable options
        
        Args:
            text: Text to tokenize
            
        Returns:
            List of processed tokens
        """
        if not text or not isinstance(text, str):
            return []
        
        try:
            # Define punctuation translator
            translator = str.maketrans("", "", string.punctuation)
            
            # Tokenize into words
            words = nltk.word_tokenize(text)
            
            # Basic cleaning
            words = [word.lower().translate(translator) for word in words]
            words = [word for word in words if word]
            
            # Apply configured filters
            if self.bow_options.get("alpha_token", False):
                words = [word for word in words if word.isalpha()]
            
            word_len = self.bow_options.get("word_len")
            if word_len and isinstance(word_len, (list, tuple)) and len(word_len) == 2:
                min_len, max_len = word_len
                words = [word for word in words if min_len <= len(word) <= max_len]
            
            stop_words = self.bow_options.get("stop_words")
            if stop_words:
                words = [word for word in words if word not in stop_words]
            
            stemmer = self.bow_options.get("stemmer")
            if stemmer:
                words = [stemmer.stem(word) for word in words]
            
            return words
            
        except Exception as e:
            print(f"Error tokenizing text: {e}")
            return []
    
    def create_bag_of_words(self, tree_results: List[Dict[str, Any]]) -> Counter:
        """
        Create bag of words from tree scraping results
        
        Args:
            tree_results: List of scraping results
            
        Returns:
            Counter object with word frequencies
        """
        all_words = []
        
        for result in tree_results:
            if result.get("text") and not result.get("error"):
                words = self.tokenize_text(result["text"])
                all_words.extend(words)
        
        return Counter(all_words)


def wayback_urlparse(url: str) -> Tuple[Optional[str], Optional[str]]:
    """
    Parse Wayback Machine URL to extract timestamp and original URL
    Enhanced with better pattern matching
    
    Args:
        url: Wayback Machine URL
        
    Returns:
        Tuple of (timestamp, original_url) or (None, None) if not a Wayback URL
    """
    patterns = [
        r"https://web\.archive\.org/web/(\d{14})/(.*)",
        r"https://.*\.execute-api\..*\.amazonaws\.com/.*/web/(\d{14})/(.*)"
    ]
    
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1), match.group(2)
    
    return None, None
