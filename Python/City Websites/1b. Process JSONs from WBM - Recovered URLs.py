'''
Process JSONS from WBM into data frames - RECOVERED URLs VERSION
This script processes the res and bow files from the "Recovered URLs From Bad URLs Investigation"
directory and saves them to a "Processed - Recovered" subdirectory
'''

import polars as pl
import os
import json

# Input directory: where the recovered URLs were scraped to
input_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Recovered URLs From Bad URLs Investigation')

# Output directory: new subdirectory for processed recovered URLs
output_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Recovered URLs From Bad URLs Investigation/Processed')

# Create output directories if they don't exist
os.makedirs(f'{output_dir}/res', exist_ok=True)
os.makedirs(f'{output_dir}/bow', exist_ok=True)


def json_to_python_res(file_name):
    # Load the JSON data into a Python dictionary
    with open(file_name, "r") as file:
        data = json.load(file)
        # since the json structure is a dictionary with urls as keys and lists of dictionaries as values,
        # we need to flatten it into a list of dictionaries suitable for dataframe conversion.
        flattened_data = []
        count = 0
        for url, entries in data.items():
            for entry in entries:
                # add the 'parent url' to each entry
                entry["parent url"] = url
                flattened_data.append(entry)
        # convert the list of dictionaries into a dataframe
        df = pl.DataFrame(flattened_data, infer_schema_length = 1000)
        if df.shape[0] == 0:
            return df

        # Display the DataFrame
        return df

def json_to_python_bow(file_name):
    # Load the JSON data into a Python dictionary
    with open(file_name, "r") as file:
        data = json.load(file)
        # since the json structure is a dictionary with urls as keys and lists of dictionaries as values,
        # we need to flatten it into a list of dictionaries suitable for dataframe conversion.
        word_counts = []
        for url, word_count_dict in data.items():
            for word, count in word_count_dict.items():
                word_counts.append({"url": url, "word": word, "count": count})
                # convert the list of dictionaries into a dataframe
        df = pl.DataFrame(word_counts)
        # Display the DataFrame
        return df

def run_json_processing_for_year(year):
    # Load sample issuers to filter - same as original script
    sample_issuers1 = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/Border_Matches_URLs_20250903.csv')
    sample_issuers2 = pl.read_csv(
        '~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files 20251009/Border_Matches_URLs_20251009.csv')
    sample_issuers = pl.concat([sample_issuers1, sample_issuers2]).unique()
    print(f"  Sample issuers: {sample_issuers.shape[0]}")
    
    # Check if JSON_year directory exists
    year_dir = f'{input_dir}/JSON_{year}'
    if not os.path.exists(year_dir):
        print(f"  ⚠️  JSON_{year} directory not found, skipping")
        return
    
    files = os.listdir(year_dir)
    res_files = [file for file in files if file[:3] == 'res']
    
    print(f"  Found {len(res_files)} res files")
    
    processed_res = 0
    for file in res_files:
        # check first if file is in sample
        url = file.split('[')[1].split(']')[0].replace('_', '.')
        if url not in sample_issuers['URL']:
            continue
        
        file_path = f'{year_dir}/{file}'
        try:
            file_df = json_to_python_res(file_path)
            if file_df.is_empty():
                continue
            file_df = (file_df
                       .with_columns(original_url=pl.lit(url)))
            fname = file.split('[')[1].split(']')[0]
            # Drop columns that exist - 'info' column might not be present in all files
            columns_to_drop = ['subURLs']
            if 'info' in file_df.columns:
                columns_to_drop.append('info')
            file_df.drop(columns_to_drop).write_csv(f'{output_dir}/res/{fname}_{year}.csv')
            processed_res += 1
        except Exception as e:
            print(f"    ⚠️  Error processing {file}: {e}")
    
    print(f"  ✅ Processed {processed_res} res files")

    bow_files = [file for file in files if file[:3] == 'bow']
    print(f"  Found {len(bow_files)} bow files")
    
    processed_bow = 0
    for file in bow_files:
        # check first if file is in sample
        url = file.split('[')[1].split(']')[0].replace('_', '.')
        if url not in sample_issuers['URL']:
            continue
        
        file_path = f'{year_dir}/{file}'
        try:
            file_df = json_to_python_bow(file_path)
            file_df = (file_df
                       .with_columns(original_url = pl.lit(url)))
            fname = file.split('[')[1].split(']')[0]
            file_df.write_csv(f'{output_dir}/bow/{fname}_{year}.csv')
            processed_bow += 1
        except Exception as e:
            print(f"    ⚠️  Error processing {file}: {e}")
    
    print(f"  ✅ Processed {processed_bow} bow files")

def main_processing():
    print("="*70)
    print("Processing Recovered URLs JSONs from WBM")
    print("="*70)
    print(f"\nInput directory:  {input_dir}")
    print(f"Output directory: {output_dir}\n")
    
    for year in range(2015, 2021):
        print(f'📅 Processing year {year}')
        run_json_processing_for_year(year)
        print()
    
    print("="*70)
    print("✅ Processing complete!")
    print("="*70)
    print(f"\nProcessed files saved to:")
    print(f"  - {output_dir}/res/")
    print(f"  - {output_dir}/bow/")

if __name__ == "__main__":
    main_processing()
