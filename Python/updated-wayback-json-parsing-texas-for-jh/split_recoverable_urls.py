#!/usr/bin/env python3
"""
Split Recoverable URLs into Sets
Divides the recoverable_urls.csv into multiple sets for parallel processing on different computers
"""

import pandas as pd
from pathlib import Path
import sys

def split_recoverable_urls(input_file: str, num_sets: int = 3, output_dir: str = None):
    """
    Split recoverable URLs into multiple sets
    
    Args:
        input_file: Path to recoverable_urls.csv
        num_sets: Number of sets to split into (default: 3)
        output_dir: Directory to save output files (default: same as input)
    """
    # Load the data
    df = pd.read_csv(input_file)
    total_pairs = len(df)
    
    print(f"📁 Loaded {total_pairs} recoverable URL-year pairs")
    print(f"📊 Splitting into {num_sets} sets...")
    print()
    
    # Calculate pairs per set
    pairs_per_set = total_pairs // num_sets
    remainder = total_pairs % num_sets
    
    # Determine output directory
    if output_dir is None:
        output_dir = Path(input_file).parent
    else:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
    
    # Split and save
    start_idx = 0
    for set_num in range(1, num_sets + 1):
        # Calculate end index (distribute remainder across first sets)
        set_size = pairs_per_set + (1 if set_num <= remainder else 0)
        end_idx = start_idx + set_size
        
        # Extract subset
        subset = df.iloc[start_idx:end_idx]
        
        # Generate output filename
        output_file = output_dir / f"recoverable_urls_set{set_num}.csv"
        
        # Save subset
        subset.to_csv(output_file, index=False)
        
        print(f"✅ Set {set_num}: {len(subset)} pairs saved to {output_file.name}")
        print(f"   Unique URLs: {subset['host'].nunique()}")
        print(f"   Years: {sorted(subset['year'].unique())}")
        print()
        
        start_idx = end_idx
    
    print("=" * 70)
    print("✅ Splitting complete!")
    print("=" * 70)
    print()
    print("To process each set, run:")
    for set_num in range(1, num_sets + 1):
        print(f"  python3 process_recoverable_urls.py --set {set_num}")
    print()


def main():
    """Main execution"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Split recoverable URLs into sets')
    parser.add_argument('--input', 
                       default='/Users/kmunevar/Repos/VotingOnBonds/City Websites/wayback-json-parsing-bad-urls-texas/reports/recoverable_urls.csv',
                       help='Input recoverable_urls.csv file')
    parser.add_argument('--sets', type=int, default=3,
                       help='Number of sets to create (default: 3)')
    parser.add_argument('--output-dir',
                       default='/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/',
                       help='Output directory for set files')
    
    args = parser.parse_args()
    
    split_recoverable_urls(args.input, args.sets, args.output_dir)


if __name__ == "__main__":
    main()

