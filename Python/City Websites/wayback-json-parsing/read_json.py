import os

import pandas as pd
import json
import polars as pl

path = "/Users/kmunevar/Dropbox/Voting on Bonds/Data/Websites/Border States Website Data/WBM"
all_files = os.listdir(path)

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
        df = df.with_columns(pl.col('sub').struct.unnest())
        # Display the DataFrame
        return df

res_files = [file for file in all_files if file[:3] == 'res']
for file in res_files:
    file_df = json_to_python_res(f'{path}/{file}')
    file_df.select(['parent url', 'URL', 'sub', 'priority']).write_csv(f'{path}/Processed JSON/{file[:-5]}.csv')

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

bow_files = [file for file in all_files if file[:3] == 'bow']
for file in bow_files:
    file_df = json_to_python_bow(f'{path}/{file}')
    file_df = (file_df
               .group_by('url')
               .agg(pl.col('count').sum().alias('total_word_count'),
                    pl.col('count').filter(pl.col('word').eq(pl.lit('bond'))).sum().alias('bond_count'),
                    pl.col('count').filter(pl.col('word').eq(pl.lit('budget'))).sum().alias('budget_count'),
                    pl.col('count').filter(pl.col('word').eq(pl.lit('cafr'))).sum().alias('cafr_count'),
                    pl.col('count').filter(pl.col('word').eq(pl.lit('debt'))).sum().alias('debt_count'),
                    pl.col('count').filter(pl.col('word').is_in(['financi', 'financ'])).sum().alias('finance_count'))
               .with_columns(pl.col('bond_count').truediv(pl.col('total_word_count')).alias('bond_perc'),
                             pl.col('budget_count').truediv(pl.col('total_word_count')).alias('budget_perc'),
                                pl.col('cafr_count').truediv(pl.col('total_word_count')).alias('cafr_perc'),
                                pl.col('debt_count').truediv(pl.col('total_word_count')).alias('debt_perc'),
                                pl.col('finance_count').truediv(pl.col('total_word_count')).alias('finance_perc')))

    file_df.write_csv(f'{path}/Processed JSON/{file[:-5]}.csv')

file_name = f'{path}bow[www_caldwelltx_gov].json'
file_df = json_to_python_bow(file_name)
file_df.write_csv(f'{path}caldwelltx_2024Q1_pull_bow.csv')