# Improved Wayback Machine Scraper

An enhanced version of the original Wayback Machine scraper with significant improvements in error handling, performance, modularity, and usability.

## Key Improvements

### 🚀 Performance Enhancements
- **Smarter Rate Limiting**: Configurable delays with intelligent backoff strategies
- **Session Recovery**: Resume interrupted scraping sessions automatically  
- **Batch Processing**: Periodic intermediate saves to prevent data loss
- **Performance Monitoring**: Detailed timing metrics and statistics
- **Memory Optimization**: Better handling of large datasets

### 🛡️ Enhanced Error Handling
- **Comprehensive Logging**: Detailed logs with configurable levels and rotation
- **Graceful Failures**: Continue processing other URLs when individual URLs fail
- **Retry Mechanisms**: Exponential backoff retry strategies for network requests
- **Data Validation**: Input validation and data integrity checks
- **Timeout Management**: Configurable timeouts to prevent hanging requests

### 🔧 Improved Architecture
- **Modular Design**: Clean separation of concerns with dedicated modules
- **Configuration Management**: Centralized, typed configuration system
- **Type Hints**: Full type annotations for better code maintainability
- **Class-Based Design**: Object-oriented architecture for better extensibility

### 📊 Better Data Management
- **Automatic Backups**: Optional backup creation before overwriting files
- **Progress Tracking**: Real-time progress indicators and status updates
- **Data Persistence**: Robust JSON and CSV file handling
- **Error Recovery**: Comprehensive error logging and recovery mechanisms

## Project Structure

```
updated-wayback-json-parsing/
├── config.py           # Configuration management
├── utils.py            # Utility functions and classes
├── scraper.py          # Core scraping functionality
├── run_wbm.py          # Main script and CLI interface
├── requirements.txt    # Dependencies
└── README.md          # This file
```

## Installation

1. **Create a virtual environment** (recommended):
```bash
python -m venv wayback_env
source wayback_env/bin/activate  # On Windows: wayback_env\Scripts\activate
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

3. **Download NLTK data** (if not already available):
```python
import nltk
nltk.download('punkt')
nltk.download('stopwords')
```

## Configuration

### Basic Configuration
The scraper uses a comprehensive configuration system. Key settings can be modified in `config.py`:

```python
# Network settings
contact_email = "your.email@example.com"
rate_limit_delay = 6.0  # seconds between requests
max_retries = 5
timeout_seconds = 180

# Scraping settings
max_urls = 50           # max URLs per tree
max_sub_levels = 3      # max depth of sub-URL traversal
```

### Advanced Configuration
For detailed configuration, modify the dataclass instances in `config.py`:

```python
# Example: Adjust logging settings
config.logging.log_level = "DEBUG"
config.logging.log_to_file = True

# Example: Modify scraping behavior
config.scraping.max_urls = 100
config.scraping.priority_keywords.extend(["budget", "treasury"])
```

## Usage

### Command Line Interface

**Basic usage:**
```bash
python run_wbm.py urls_file.csv
```

**With year range:**
```bash
python run_wbm.py urls_file.csv 2020 2024
```

### Programmatic Usage

```python
from config import Config
from run_wbm import ImprovedWaybackScraper

# Initialize with custom config
config = Config()
config.scraping.max_urls = 100
scraper = ImprovedWaybackScraper(config)

# Scrape a single host
success = scraper.scrape_host(
    host="example.gov",
    frequency="Y",
    date_range=("2020-01-01", "2020-12-31"),
    output_path="./output/"
)
```

## Key Features

### Session Management
- **Automatic Resume**: Interrupted sessions can be resumed automatically
- **Progress Tracking**: Monitor which URLs have been processed
- **Failure Handling**: Track and retry failed URLs

### Intelligent URL Filtering
- **Social Media Filtering**: Automatically skip social media links
- **Language Detection**: Skip non-English content based on URL patterns
- **Priority Scoring**: Process high-priority URLs (finance, bonds, etc.) first
- **Duplicate Detection**: Avoid processing the same URLs multiple times

### Robust Error Handling
- **Request Timeouts**: Configurable timeouts prevent hanging requests
- **Network Retries**: Exponential backoff for failed network requests
- **Data Validation**: Validate responses and data integrity
- **Graceful Degradation**: Continue processing when individual URLs fail

### Performance Monitoring
- **Timing Metrics**: Track processing time for different operations
- **Memory Usage**: Monitor resource consumption
- **Progress Reporting**: Real-time progress updates
- **Performance Statistics**: Detailed performance reports

## Output Files

The scraper generates several output files:

- **`cdx[hostname].csv`**: Wayback Machine query results
- **`res[hostname].json`**: Raw scraping results with full HTML content
- **`bow[hostname].json`**: Processed bag-of-words data
- **`session_hostname.json`**: Session state for resumption
- **`wayback_scraper.log`**: Detailed logging information

## Monitoring and Debugging

### Logging
The scraper provides comprehensive logging:
- **Console Output**: Real-time progress and status updates
- **File Logging**: Detailed logs saved to rotating log files
- **Performance Metrics**: Timing statistics and performance data

### Progress Tracking
- **Real-time Progress**: Visual progress bars and status updates
- **Session State**: Persistent session information
- **Error Reporting**: Detailed error messages and stack traces

## Migration from Original Version

The improved version maintains backward compatibility with the original configuration format while adding new features:

### Key Differences
1. **Modular Architecture**: Code is split into logical modules
2. **Enhanced Configuration**: More comprehensive and flexible configuration
3. **Better Error Handling**: Graceful failure handling and recovery
4. **Session Management**: Built-in session resumption capabilities
5. **Performance Monitoring**: Detailed performance metrics

### Migration Steps
1. Copy your URLs file to the new directory
2. Update file paths in `config.py` if needed
3. Run with the same command-line arguments
4. The improved version will automatically handle the rest

## Troubleshooting

### Common Issues

**ModuleNotFoundError**:
```bash
pip install -r requirements.txt
```

**NLTK Data Missing**:
```python
import nltk
nltk.download('punkt')
nltk.download('stopwords')
```

**Permission Errors**:
- Ensure write permissions for output directories
- Check file paths in configuration

**Network Issues**:
- Verify internet connectivity
- Check rate limiting settings
- Review proxy settings if applicable

### Performance Tuning

**For Faster Processing**:
- Reduce `rate_limit_delay` (but respect API limits)
- Increase `max_urls` for more parallel processing
- Use SSD storage for better I/O performance

**For Better Reliability**:
- Increase `max_retries` for unstable networks
- Use longer `timeout_seconds` for slow connections
- Enable `backup_enabled` for data safety

## Contributing

To contribute to this project:

1. Fork the repository
2. Create a feature branch
3. Make your changes with proper type hints and documentation
4. Add tests for new functionality
5. Submit a pull request

## License

This project maintains the same license as the original codebase.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review the log files for detailed error information
3. Create an issue with detailed information about your problem

---

**Note**: This improved version is designed to be a drop-in replacement for the original scraper while providing significant enhancements in reliability, performance, and usability.
