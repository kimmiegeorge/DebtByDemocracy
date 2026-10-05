"""
Utility functions for the improved Wayback Machine Scraper
Includes logging, error handling, performance monitoring, and data validation
"""

import os
import re
import time
import json
import shutil
import logging
import functools
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Tuple, Callable
from logging.handlers import RotatingFileHandler
import pandas as pd
from urllib.parse import urlparse, urljoin


class ScrapingLogger:
    """Enhanced logging functionality for the scraper"""
    
    def __init__(self, log_config):
        self.config = log_config
        self.logger = self._setup_logger()
        
    def _setup_logger(self) -> logging.Logger:
        """Set up logger with both file and console handlers"""
        logger = logging.getLogger("wayback_scraper")
        logger.setLevel(getattr(logging, self.config.log_level))
        
        # Clear existing handlers to avoid duplicates
        logger.handlers.clear()
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_formatter = logging.Formatter(
            '%(asctime)s - %(levelname)s - %(message)s'
        )
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)
        
        # File handler (if enabled)
        if self.config.log_to_file:
            file_handler = RotatingFileHandler(
                self.config.log_file_path,
                maxBytes=self.config.max_log_size_mb * 1024 * 1024,
                backupCount=self.config.backup_count
            )
            file_formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s'
            )
            file_handler.setFormatter(file_formatter)
            logger.addHandler(file_handler)
            
        return logger
    
    def info(self, message: str, **kwargs):
        """Log info message with optional context"""
        context = " | ".join([f"{k}={v}" for k, v in kwargs.items()])
        full_message = f"{message} | {context}" if context else message
        self.logger.info(full_message)
    
    def error(self, message: str, exception: Optional[Exception] = None, **kwargs):
        """Log error message with optional exception and context"""
        context = " | ".join([f"{k}={v}" for k, v in kwargs.items()])
        full_message = f"{message} | {context}" if context else message
        if exception:
            self.logger.error(f"{full_message} | Exception: {str(exception)}")
        else:
            self.logger.error(full_message)
    
    def warning(self, message: str, **kwargs):
        """Log warning message with optional context"""
        context = " | ".join([f"{k}={v}" for k, v in kwargs.items()])
        full_message = f"{message} | {context}" if context else message
        self.logger.warning(full_message)


class PerformanceMonitor:
    """Monitor and track performance metrics"""
    
    def __init__(self):
        self.metrics = {}
        self.start_times = {}
    
    def start_timer(self, operation: str):
        """Start timing an operation"""
        self.start_times[operation] = time.time()
    
    def end_timer(self, operation: str) -> float:
        """End timing an operation and return duration"""
        if operation not in self.start_times:
            return 0.0
        
        duration = time.time() - self.start_times[operation]
        if operation not in self.metrics:
            self.metrics[operation] = []
        self.metrics[operation].append(duration)
        return duration
    
    def get_stats(self, operation: str) -> Dict[str, float]:
        """Get performance statistics for an operation"""
        if operation not in self.metrics or not self.metrics[operation]:
            return {}
        
        times = self.metrics[operation]
        return {
            "count": len(times),
            "total": sum(times),
            "average": sum(times) / len(times),
            "min": min(times),
            "max": max(times)
        }
    
    def get_all_stats(self) -> Dict[str, Dict[str, float]]:
        """Get performance statistics for all tracked operations"""
        return {op: self.get_stats(op) for op in self.metrics.keys()}


def retry_on_failure(max_attempts: int = 3, delay: float = 1.0, exponential_backoff: bool = True):
    """Decorator for retrying functions on failure"""
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            last_exception = None
            
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_exception = e
                    if attempt == max_attempts - 1:
                        break
                    
                    wait_time = delay * (2 ** attempt) if exponential_backoff else delay
                    time.sleep(wait_time)
            
            raise last_exception
        return wrapper
    return decorator


class DataValidator:
    """Validate scraped data and URL formats"""
    
    @staticmethod
    def is_valid_url(url: str) -> bool:
        """Check if a URL is valid"""
        try:
            result = urlparse(url)
            return all([result.scheme, result.netloc])
        except Exception:
            return False
    
    @staticmethod
    def is_wayback_url(url: str) -> bool:
        """Check if URL is a Wayback Machine URL"""
        wayback_patterns = [
            r"https://web\.archive\.org/web/\d{14}/",
            r"https://.*\.execute-api\..*\.amazonaws\.com/.*/web/\d{14}/"
        ]
        return any(re.search(pattern, url) for pattern in wayback_patterns)
    
    @staticmethod
    def extract_original_url(wayback_url: str) -> Optional[str]:
        """Extract original URL from Wayback Machine URL"""
        patterns = [
            r"https://web\.archive\.org/web/\d{14}/(.*)",
            r"https://.*\.execute-api\..*\.amazonaws\.com/.*/web/\d{14}/(.*)"
        ]
        
        for pattern in patterns:
            match = re.search(pattern, wayback_url)
            if match:
                return match.group(1)
        return None
    
    @staticmethod
    def validate_dataframe(df: pd.DataFrame, required_columns: List[str]) -> bool:
        """Validate that DataFrame has required columns"""
        return all(col in df.columns for col in required_columns)


class FileManager:
    """Handle file operations with backup and error handling"""
    
    def __init__(self, backup_enabled: bool = True):
        self.backup_enabled = backup_enabled
    
    def safe_save_json(self, data: Dict[str, Any], filepath: str, backup_suffix: str = ".bak") -> bool:
        """Safely save JSON data with backup option"""
        try:
            filepath = Path(filepath)
            
            # Create backup if file exists and backup is enabled
            if self.backup_enabled and filepath.exists():
                backup_path = filepath.with_suffix(filepath.suffix + backup_suffix)
                shutil.copy2(filepath, backup_path)
            
            # Create directory if it doesn't exist
            filepath.parent.mkdir(parents=True, exist_ok=True)
            
            # Write data
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            return True
            
        except Exception as e:
            print(f"Error saving JSON to {filepath}: {e}")
            return False
    
    def safe_save_csv(self, df: pd.DataFrame, filepath: str, backup_suffix: str = ".bak") -> bool:
        """Safely save CSV data with backup option"""
        try:
            filepath = Path(filepath)
            
            # Create backup if file exists and backup is enabled
            if self.backup_enabled and filepath.exists():
                backup_path = filepath.with_suffix(filepath.suffix + backup_suffix)
                shutil.copy2(filepath, backup_path)
            
            # Create directory if it doesn't exist
            filepath.parent.mkdir(parents=True, exist_ok=True)
            
            # Write data
            df.to_csv(filepath, index=False)
            
            return True
            
        except Exception as e:
            print(f"Error saving CSV to {filepath}: {e}")
            return False
    
    def safe_load_json(self, filepath: str) -> Optional[Dict[str, Any]]:
        """Safely load JSON data with error handling"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading JSON from {filepath}: {e}")
            return None


class URLFilter:
    """Advanced URL filtering and prioritization"""
    
    def __init__(self, config):
        self.config = config
        self.social_media = config.social_media_domains
        self.language_specifiers = config.language_specifiers
        self.exclude_keywords = config.exclude_keywords
        self.priority_keywords = config.priority_keywords
        self.general_priority_keywords = config.general_priority_keywords
    
    def should_skip_url(self, url: str, host: str) -> Tuple[bool, str]:
        """
        Check if URL should be skipped
        Returns (should_skip: bool, reason: str)
        """
        if not url or not isinstance(url, str):
            return True, "Invalid URL"
        
        # Remove fragments
        clean_url = url.split("#")[0]
        
        # Extract original URL if it's a Wayback URL
        original_url = DataValidator.extract_original_url(clean_url)
        if original_url is None and DataValidator.is_wayback_url(clean_url):
            return True, "Could not extract original URL"
        
        check_url = original_url or clean_url
        check_url_lower = check_url.lower()
        
        # Check if host is in the URL (normalize by removing www prefix for comparison)
        # This handles cases where host has www. but archived URLs don't (or vice versa)
        host_normalized = host.lower().replace('www.', '')
        check_url_normalized = check_url_lower.replace('www.', '')
        if host_normalized not in check_url_normalized:
            return True, "Host not in URL"
        
        # Skip social media
        if any(site in check_url_lower for site in self.social_media):
            return True, "Social media site"
        
        # Skip different languages
        if any(lang in check_url_lower for lang in self.language_specifiers):
            return True, "Non-English language"
        
        # Skip excluded keywords
        if any(keyword in check_url_lower for keyword in self.exclude_keywords):
            return True, "Contains excluded keyword"
        
        return False, "Passed filters"
    
    def calculate_priority(self, url: str) -> int:
        """Calculate priority score for URL based on keywords"""
        if not url or not isinstance(url, str):
            return 0
        
        url_lower = url.lower()
        
        priority_score = sum(
            keyword in url_lower for keyword in self.priority_keywords
        ) * 2
        
        general_score = sum(
            keyword in url_lower for keyword in self.general_priority_keywords
        )
        
        return priority_score + general_score


class RateLimiter:
    """Rate limiting for API requests"""
    
    def __init__(self, delay: float = 6.0):
        self.delay = delay
        self.last_request = 0.0
    
    def wait_if_needed(self):
        """Wait if necessary to respect rate limits"""
        current_time = time.time()
        time_since_last = current_time - self.last_request
        
        if time_since_last < self.delay:
            sleep_time = self.delay - time_since_last
            time.sleep(sleep_time)
        
        self.last_request = time.time()


def sanitize_filename(text: str) -> str:
    """Sanitize text for use in filenames"""
    # Replace invalid characters with underscores
    return re.sub(r'[^\w\s\-.]', '_', text)


def create_progress_callback(total: int, description: str = "Processing"):
    """Create a progress tracking callback function"""
    def callback(current: int, extra_info: str = ""):
        progress = (current / total) * 100 if total > 0 else 0
        status = f"{description}: {current}/{total} ({progress:.1f}%)"
        if extra_info:
            status += f" - {extra_info}"
        print(f"\r{status}", end="", flush=True)
        if current >= total:
            print()  # New line at completion
    
    return callback


def format_duration(seconds: float) -> str:
    """Format duration in seconds to human readable string"""
    if seconds < 60:
        return f"{seconds:.1f}s"
    elif seconds < 3600:
        minutes = int(seconds // 60)
        secs = seconds % 60
        return f"{minutes}m {secs:.1f}s"
    else:
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        secs = seconds % 60
        return f"{hours}h {minutes}m {secs:.1f}s"


class SessionManager:
    """Manage scraping session state and recovery"""
    
    def __init__(self, session_file: str = "session_state.json"):
        self.session_file = session_file
        self.state = self.load_session()
    
    def load_session(self) -> Dict[str, Any]:
        """Load session state from file"""
        try:
            if os.path.exists(self.session_file):
                with open(self.session_file, 'r') as f:
                    return json.load(f)
        except Exception as e:
            print(f"Could not load session: {e}")
        
        return {
            "completed_urls": [],
            "failed_urls": [],
            "last_processed": None,
            "start_time": None
        }
    
    def save_session(self):
        """Save current session state to file"""
        try:
            with open(self.session_file, 'w') as f:
                json.dump(self.state, f, indent=2, default=str)
        except Exception as e:
            print(f"Could not save session: {e}")
    
    def mark_url_completed(self, url: str):
        """Mark URL as completed"""
        if url not in self.state["completed_urls"]:
            self.state["completed_urls"].append(url)
        if url in self.state["failed_urls"]:
            self.state["failed_urls"].remove(url)
        self.state["last_processed"] = url
        self.save_session()
    
    def mark_url_failed(self, url: str):
        """Mark URL as failed"""
        if url not in self.state["failed_urls"]:
            self.state["failed_urls"].append(url)
        self.save_session()
    
    def is_url_completed(self, url: str) -> bool:
        """Check if URL has been completed"""
        return url in self.state["completed_urls"]
    
    def get_remaining_urls(self, all_urls: List[str]) -> List[str]:
        """Get list of URLs that still need processing"""
        return [url for url in all_urls if not self.is_url_completed(url)]
    
    def clear_session(self):
        """Clear session state"""
        self.state = {
            "completed_urls": [],
            "failed_urls": [],
            "last_processed": None,
            "start_time": None
        }
        self.save_session()
