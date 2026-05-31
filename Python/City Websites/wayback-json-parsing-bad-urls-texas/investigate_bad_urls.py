#!/usr/bin/env python3
"""
Investigation Script for Bad URLs
Analyzes URL-year pairs with only 1 snapshot to find better alternatives
"""

import argparse
import json
import time
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime

import pandas as pd
import requests
from bs4 import BeautifulSoup

from config import Config


class BadURLInvestigator:
    """Investigate bad URLs to find better snapshots"""
    
    def __init__(self, config: Config):
        self.config = config
        self.session = self._create_session()
        
    def _create_session(self) -> requests.Session:
        """Create requests session"""
        session = requests.Session()
        session.headers.update(self.config.network.headers)
        return session
    
    def load_bad_urls(self) -> pd.DataFrame:
        """Load bad URLs CSV"""
        df = pd.read_csv(self.config.paths.bad_urls_file)
        print(f"✅ Loaded {len(df)} bad URL-year pairs")
        return df
    
    def get_cdx_data(self, host: str, year: int) -> Optional[pd.DataFrame]:
        """Load CDX file for a given host and year"""
        year_path = Path(self.config.paths.base_path) / "Annual Files" / f"JSON_{year}"
        cdx_file = year_path / f"cdx[{host}].csv"
        
        if not cdx_file.exists():
            return None
        
        try:
            df = pd.read_csv(cdx_file)
            df['datetime'] = pd.to_datetime(df['datetime'])
            return df
        except Exception as e:
            print(f"❌ Error reading CDX file: {e}")
            return None
    
    def get_result_data(self, host: str, year: int) -> Optional[Dict]:
        """Load result JSON for a given host and year"""
        year_path = Path(self.config.paths.base_path) / "Annual Files" / f"JSON_{year}"
        res_file = year_path / f"res[{host}].json"
        
        if not res_file.exists():
            return None
        
        try:
            with open(res_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Error reading result file: {e}")
            return None
    
    def test_snapshot(self, url: str) -> Tuple[int, int]:
        """
        Test a snapshot to count sub-URLs.
        Returns (status_code, sub_url_count)
        """
        try:
            response = self.session.get(
                url, 
                timeout=self.config.investigation.timeout,
                allow_redirects=True
            )
            
            if response.status_code != 200:
                return response.status_code, 0
            
            # Check content type
            content_type = response.headers.get('Content-Type', '')
            if 'text/html' not in content_type:
                return response.status_code, 0
            
            # Parse HTML and count links
            soup = BeautifulSoup(response.text, 'lxml')
            links = soup.find_all('a', href=True)
            sub_urls = [link['href'] for link in links if link['href']]
            
            # Count unique non-empty links
            unique_suburls = len(set([url for url in sub_urls if url.strip()]))
            
            return response.status_code, unique_suburls
            
        except requests.exceptions.Timeout:
            return -1, 0
        except Exception as e:
            return -2, 0
    
    def investigate_url_year(self, host: str, year: int) -> Dict:
        """Investigate a specific URL-year pair"""
        print(f"\n{'='*80}")
        print(f"🔍 Investigating: {host}, {year}")
        print(f"{'='*80}")
        
        result = {
            'host': host,
            'year': year,
            'total_snapshots': 0,
            'valid_snapshots': 0,
            'tested_snapshots': 0,
            'original_scraped': 1,
            'best_snapshot': None,
            'alternative_snapshots': [],
            'recommendation': 'UNKNOWN',
            'status': 'PENDING'
        }
        
        # Get CDX data
        cdx_df = self.get_cdx_data(host, year)
        if cdx_df is None:
            print(f"❌ No CDX file found")
            result['status'] = 'NO_CDX'
            result['recommendation'] = 'UNRECOVERABLE'
            return result
        
        result['total_snapshots'] = len(cdx_df)
        print(f"📊 Total snapshots in CDX: {len(cdx_df)}")
        
        # Filter for specific year
        year_df = cdx_df[cdx_df['datetime'].dt.year == year].copy()
        print(f"📊 Snapshots in {year}: {len(year_df)}")
        
        if len(year_df) == 0:
            print(f"❌ No snapshots for year {year}")
            result['status'] = 'NO_YEAR_SNAPSHOTS'
            result['recommendation'] = 'UNRECOVERABLE'
            return result
        
        # Get current results
        res_data = self.get_result_data(host, year)
        if res_data:
            scraped_count = sum(len(v) for v in res_data.values())
            result['original_scraped'] = scraped_count
            print(f"📌 Originally scraped: {scraped_count} URLs")
        
        # Analyze status codes
        print(f"\n📈 Snapshot status codes:")
        status_counts = year_df['statuscode'].value_counts()
        for status, count in status_counts.items():
            print(f"   {status}: {count} snapshots")
        
        # Filter to status 200 only
        valid_snapshots = year_df[year_df['statuscode'] == '200'].copy()
        result['valid_snapshots'] = len(valid_snapshots)
        print(f"\n✅ Valid snapshots (status 200): {len(valid_snapshots)}")
        
        if len(valid_snapshots) == 0:
            print(f"❌ No valid snapshots available")
            result['status'] = 'NO_VALID_SNAPSHOTS'
            result['recommendation'] = 'UNRECOVERABLE'
            return result
        
        # Sample snapshots to test
        sample_size = min(self.config.investigation.sample_size, len(valid_snapshots))
        
        if self.config.investigation.prioritize_by_size:
            valid_snapshots['length_num'] = pd.to_numeric(valid_snapshots['length'], errors='coerce')
            sample_snapshots = valid_snapshots.nlargest(sample_size, 'length_num')
        else:
            sample_snapshots = valid_snapshots.sample(n=sample_size)
        
        print(f"\n🔍 Testing {sample_size} snapshots:")
        tested_results = []
        
        for idx, row in sample_snapshots.iterrows():
            url = row['url']
            timestamp = row['timestamp']
            length = row['length']
            
            print(f"\n  Testing: {timestamp} (size: {length})")
            
            # Rate limit
            time.sleep(self.config.investigation.rate_limit_delay)
            
            status, sub_url_count = self.test_snapshot(url)
            
            snapshot_info = {
                'timestamp': timestamp,
                'url': url,
                'status': status,
                'sub_url_count': sub_url_count,
                'file_size': int(length)
            }
            
            if status == 200:
                print(f"  ✅ Status: {status}, Sub-URLs: {sub_url_count}")
                tested_results.append(snapshot_info)
            else:
                print(f"  ❌ Status: {status}")
        
        result['tested_snapshots'] = len(tested_results)
        result['alternative_snapshots'] = tested_results
        
        # Find best snapshot
        if tested_results:
            best = max(tested_results, key=lambda x: x['sub_url_count'])
            result['best_snapshot'] = best
            
            threshold = self.config.investigation.min_suburls_threshold
            
            if best['sub_url_count'] >= threshold:
                result['recommendation'] = 'RECOVERABLE'
                result['status'] = 'SUCCESS'
                print(f"\n✨ BEST SNAPSHOT FOUND:")
                print(f"   Timestamp: {best['timestamp']}")
                print(f"   Sub-URLs: {best['sub_url_count']}")
                print(f"   💡 RECOMMENDATION: RECOVERABLE - Re-scrape with this snapshot")
            else:
                result['recommendation'] = 'MARGINAL'
                result['status'] = 'MARGINAL'
                print(f"\n⚠️  MARGINAL IMPROVEMENT:")
                print(f"   Best snapshot has {best['sub_url_count']} sub-URLs (threshold: {threshold})")
                print(f"   💡 RECOMMENDATION: May not be worth re-scraping")
        else:
            result['recommendation'] = 'UNRECOVERABLE'
            result['status'] = 'NO_GOOD_SNAPSHOTS'
            print(f"\n❌ No better snapshots found")
            print(f"   💡 RECOMMENDATION: UNRECOVERABLE")
        
        return result
    
    def run_investigation(self, limit: Optional[int] = None) -> Dict:
        """Run investigation on all bad URLs"""
        print("="*80)
        print("Bad URLs Investigation")
        print("="*80)
        
        # Load bad URLs
        bad_urls_df = self.load_bad_urls()
        
        if limit and limit > 0:
            bad_urls_df = bad_urls_df.head(limit)
            print(f"🔬 Investigating first {limit} URL-year pairs\n")
        
        # Process each URL-year pair
        results = {}
        start_time = time.time()
        
        for idx, row in bad_urls_df.iterrows():
            host = row['original_url']
            year = int(row['year'])
            
            result = self.investigate_url_year(host, year)
            results[f"{host}_{year}"] = result
        
        # Generate summary
        duration = time.time() - start_time
        summary = self._generate_summary(results, duration)
        
        # Save results
        self._save_results(results, summary)
        
        return {'results': results, 'summary': summary}
    
    def _generate_summary(self, results: Dict, duration: float) -> Dict:
        """Generate summary statistics"""
        total = len(results)
        recoverable = sum(1 for r in results.values() if r['recommendation'] == 'RECOVERABLE')
        marginal = sum(1 for r in results.values() if r['recommendation'] == 'MARGINAL')
        unrecoverable = sum(1 for r in results.values() if r['recommendation'] == 'UNRECOVERABLE')
        
        summary = {
            'total_investigated': total,
            'recoverable': recoverable,
            'marginal': marginal,
            'unrecoverable': unrecoverable,
            'recovery_rate': (recoverable / total * 100) if total > 0 else 0,
            'duration_seconds': duration,
            'timestamp': datetime.now().isoformat()
        }
        
        print(f"\n{'='*80}")
        print(f"INVESTIGATION SUMMARY")
        print(f"{'='*80}")
        print(f"Total investigated: {total}")
        print(f"✅ Recoverable: {recoverable} ({summary['recovery_rate']:.1f}%)")
        print(f"⚠️  Marginal: {marginal}")
        print(f"❌ Unrecoverable: {unrecoverable}")
        print(f"⏱️  Duration: {duration:.1f}s")
        print(f"{'='*80}\n")
        
        return summary
    
    def _save_results(self, results: Dict, summary: Dict):
        """Save investigation results"""
        reports_dir = Path(self.config.paths.reports_dir)
        reports_dir.mkdir(parents=True, exist_ok=True)
        
        # Save detailed results
        results_file = reports_dir / "investigation_results.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"💾 Detailed results saved to: {results_file}")
        
        # Save summary
        summary_file = reports_dir / "investigation_summary.json"
        with open(summary_file, 'w') as f:
            json.dump(summary, f, indent=2)
        print(f"💾 Summary saved to: {summary_file}")
        
        # Save recoverable URLs as CSV for easy re-scraping
        recoverable = []
        for key, result in results.items():
            if result['recommendation'] == 'RECOVERABLE' and result['best_snapshot']:
                recoverable.append({
                    'host': result['host'],
                    'year': result['year'],
                    'timestamp': result['best_snapshot']['timestamp'],
                    'url': result['best_snapshot']['url'],
                    'sub_url_count': result['best_snapshot']['sub_url_count']
                })
        
        if recoverable:
            recoverable_df = pd.DataFrame(recoverable)
            recoverable_file = reports_dir / "recoverable_urls.csv"
            recoverable_df.to_csv(recoverable_file, index=False)
            print(f"💾 Recoverable URLs saved to: {recoverable_file}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Investigate bad URLs to find better snapshots")
    parser.add_argument('--limit', type=int, default=None,
                      help='Limit number of URLs to investigate (default: all)')
    parser.add_argument('--sample-size', type=int, default=10,
                      help='Number of snapshots to test per URL (default: 10)')
    
    args = parser.parse_args()
    
    # Load config
    config = Config()
    
    # Override sample size if provided
    if args.sample_size:
        config.investigation.sample_size = args.sample_size
    
    # Run investigation
    investigator = BadURLInvestigator(config)
    investigator.run_investigation(limit=args.limit)


if __name__ == "__main__":
    main()
