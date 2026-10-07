'''
Process JSONS from WBM into data frames
'''

import polars as pl
import os
import json
#output_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Processed')
#input_dir = os.path.expanduser('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM/Annual Files')

output_dir = os.path.expanduser('/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Processed')
input_dir = os.path.expanduser('/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/WBM/Annual Files')


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
    # Old file (139 URLs): sample_issuers = pl.read_csv('~/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/Collection Files/Issuers in GO Unlim Sample.csv')
    # New file used by updated-wayback-json-parsing scripts (265 URLs):
    sample_issuers = pl.read_csv('/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Texas/City Website Collection.csv')
    sample_issuers = sample_issuers.rename({'City Website': 'URL'})
    print(sample_issuers.shape[0])
    files = os.listdir(f'{input_dir}/JSON_{year}')
    res_files = [file for file in files if file[:3] == 'res']
    for file in res_files:
        # check first if file is in sample
        url = file.split('[')[1].split(']')[0].replace('_', '.')
        if url not in sample_issuers['URL']:
            continue
        file_df = json_to_python_res(f'{input_dir}/JSON_{year}/{file}')
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
    print("Done with res files")

    bow_files = [file for file in files if file[:3] == 'bow']
    for file in bow_files:
        # check first if file is in sample
        url = file.split('[')[1].split(']')[0].replace('_', '.')
        if url not in sample_issuers['URL']:
            continue
        file_df = json_to_python_bow(f'{input_dir}/JSON_{year}/{file}')
        file_df = (file_df
                   .with_columns(original_url = pl.lit(url)))
        fname = file.split('[')[1].split(']')[0]
        file_df.write_csv(f'{output_dir}/bow/{fname}_{year}.csv')

def main_processing():
    for year in range(2000, 2021):
        print(f'Processing year {year}')
        run_json_processing_for_year(year)

main_processing()