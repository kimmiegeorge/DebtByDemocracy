#!/usr/bin/env python3
"""
Script to prepare URLs file from Border Matches Issuers Website Collected data
Also splits the result into chunked CSVs for batch processing.
"""

import pandas as pd
import math
from pathlib import Path

INPUT_FILE = "/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/City Website Collection.csv"
OUTPUT_DIR = Path("/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/Collection Files/")
BASENAME = "Texas_URLs"
DEFAULT_CHUNK_SIZE = 100  # roughly matches existing URL_Set sizes


def prepare_and_split_urls_file(input_file: str = INPUT_FILE,
                                output_dir: Path = OUTPUT_DIR,
                                basename: str = BASENAME,
                                chunk_size: int = DEFAULT_CHUNK_SIZE) -> dict:
    """Extract URLs from Border Matches data and create files compatible with the scraper.

    Returns a dict with summary info and list of file paths created.
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Read the input file
    print(f"Reading input file: {input_file}")
    df = pd.read_csv(input_file)

    # Filter out rows where City Website is NA or empty
    df_filtered = df[df['City Website'].notna() & (df['City Website'] != 'NA') & (df['City Website'] != '')]

    # Remove duplicates based on City Website
    df_unique = df_filtered.drop_duplicates(subset=['City Website']).copy()

    # Create a new dataframe with just the URLs in the expected format
    urls_df = pd.DataFrame({'URL': df_unique['City Website']})

    # Clean URLs (normalize): remove protocols, trailing slashes, whitespace
    urls_df['URL'] = urls_df['URL'].astype(str).str.strip()
    urls_df['URL'] = urls_df['URL'].str.replace('^https://', '', regex=True)
    urls_df['URL'] = urls_df['URL'].str.replace('^http://', '', regex=True)
    urls_df['URL'] = urls_df['URL'].str.rstrip('/')

    # Save the full list
    full_file = output_dir / f"{basename}.csv"
    urls_df.to_csv(full_file, index=False)

    # Split into chunks
    total = len(urls_df)
    n_chunks = max(1, math.ceil(total / chunk_size))
    chunk_files = []

    for i in range(n_chunks):
        start = i * chunk_size
        end = min((i + 1) * chunk_size, total)
        chunk_df = urls_df.iloc[start:end]
        chunk_file = output_dir / f"{basename}_Set{i+1}.csv"
        chunk_df.to_csv(chunk_file, index=False)
        chunk_files.append(str(chunk_file))

    print(f"Processed {len(df)} total rows")
    print(f"Found {len(df_filtered)} rows with valid URLs")
    print(f"Created {len(urls_df)} unique, normalized URLs")
    print(f"Saved full list to: {full_file}")
    print(f"Split into {n_chunks} chunk(s) of up to {chunk_size} URLs each:")
    for f in chunk_files:
        print(f" - {f}")

    return {
        'input_rows': len(df),
        'valid_rows': len(df_filtered),
        'unique_urls': len(urls_df),
        'full_file': str(full_file),
        'chunk_size': chunk_size,
        'chunks': chunk_files,
    }


if __name__ == "__main__":
    prepare_and_split_urls_file()
