'''
Pull DPC bond-election articles linked to control-state issuances.

Control states are defined as issuance observations with city_go_vote == 0.
The article window matches the DPC media table outcome:
    dpc_bond_election_articles_12_0 = months -12 through 0 relative to issuance.
'''

#%%
from pathlib import Path

import pandas as pd
import polars as pl


project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
data_dir = project_dir / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'

dpc_news_dir = data_dir / 'DPC Data' / 'News'
dpc_linking_dir = dpc_news_dir / 'Linking Files'

dpc_issuance_input = clean_data_dir / 'DPC Data' / 'News' / 'Issuance_Lvl_DPC_News.gzip'
mergent_input = data_dir / 'Mergent' / 'Clean' / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'

output_dir = clean_data_dir / 'DPC Data' / 'News' / 'Control State Bond Election Articles'
output_dir.mkdir(parents=True, exist_ok=True)


#%%
def add_year_month_id(df: pl.DataFrame, year_col: str = 'year', month_col: str = 'month') -> pl.DataFrame:
    '''Convert calendar year/month to an arithmetic month index.'''
    return df.with_columns(
        ((pl.col(year_col).cast(pl.Int64) * 12) + pl.col(month_col).cast(pl.Int64)).alias('year_month_id')
    )


def load_dpc_article_metadata(path: Path) -> pl.DataFrame:
    '''
    Load NewsArticles.txt despite embedded tabs in NewsContent.

    The file is logically tab-delimited, but NewsContent can contain extra tabs.
    Parse the stable fields around NewsContent, then rebuild the content field.
    '''
    rows = []

    with path.open('r', encoding='utf-8', errors='replace') as fh:
        header = fh.readline().rstrip('\n').split('\t')
        first_cols = header[:9]
        last_cols = header[-3:]

        for line in fh:
            parts = line.rstrip('\n').split('\t')
            if len(parts) < 13:
                continue

            first_values = parts[:9]
            news_content = '\t'.join(parts[9:-3])
            last_values = parts[-3:]
            row = dict(zip(first_cols + last_cols, first_values + last_values))
            row['NewsContent'] = news_content
            rows.append(row)

    return (
        pl.DataFrame(rows)
        .select([
            pl.col('StoryID').cast(pl.Utf8),
            pl.col('FILENAME').cast(pl.Utf8),
            pl.col('StoryDate').str.strptime(pl.Datetime, strict=False),
            pl.col('NewsSource').cast(pl.Utf8),
            pl.col('Category').cast(pl.Utf8),
            pl.col('Headline').cast(pl.Utf8),
            pl.col('NewsContent').cast(pl.Utf8),
            pl.col('ObligorID').cast(pl.Int64, strict=False),
            pl.col('ObligorState').cast(pl.Utf8),
            pl.col('Obligor').cast(pl.Utf8)
        ])
        .with_columns(
            pl.col('StoryDate').dt.year().cast(pl.Int64).alias('article_year'),
            pl.col('StoryDate').dt.month().cast(pl.Int64).alias('article_month')
        )
        .filter(pl.col('StoryDate').is_not_null())
        .filter(pl.col('ObligorID').is_not_null())
    )


def add_bond_election_flag(df: pl.DataFrame) -> pl.DataFrame:
    '''Apply the same broad bond-election keyword rule used in the DPC builder.'''
    bond_terms = r'\b(bond|bonds|bonded|bonding|general obligation|go bond|go bonds|revenue bond|revenue bonds)\b'
    election_terms = r'\b(election|elections|elector|electors|voter|voters|vote|votes|voted|voting|ballot|referendum|measure|proposition|prop\.?|approved|rejected|passed|defeated)\b'

    article_text = pl.concat_str([
        pl.col('Headline').fill_null(''),
        pl.lit(' '),
        pl.col('Category').fill_null(''),
        pl.lit(' '),
        pl.col('NewsContent').fill_null('')
    ]).str.to_lowercase()

    return df.with_columns(
        (
            article_text.str.contains(bond_terms)
            & article_text.str.contains(election_terms)
        )
        .cast(pl.Int64)
        .alias('dpc_bond_election_article')
    )


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load control-state issuances
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
issuance_dpc = pl.read_parquet(dpc_issuance_input).with_columns(
    pl.col('seed_issuer_id').cast(pl.Float64).round(1),
    pl.col('year').cast(pl.Int64),
    pl.col('month').cast(pl.Int64),
    pl.col('issuance_year_month_id').cast(pl.Int64),
    pl.col('dpc_issuance_year_month_id').cast(pl.Int64)
)

control_issuances = (
    issuance_dpc
    .filter(pl.col('go_unlim_bond_issuance').eq(1))
    .filter(pl.col('city_go_vote').eq(0))
    .filter(pl.col('dpc_issuer_has_any_articles').eq(1))
    .filter(pl.col('dpc_bond_election_articles_12_0').gt(0))
    .select([
        'seed_issuer_id',
        'year',
        'month',
        'state',
        'fips',
        'city_go_vote',
        'go_unlim_bond_issuance',
        'dpc_issuance_year_month_id',
        'dpc_bond_election_articles_12_0',
        'dpc_total_articles_12_0'
    ])
    .unique()
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
attach issuance-month CUSIP6 values
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
mergent_cols = ['seed_issuer_id', 'year', 'month', 'cusip6', 'cusip', 'issue_id', 'issuer_long_name']
mergent = pl.DataFrame(pd.read_stata(mergent_input, columns=mergent_cols))

mergent = (
    mergent
    .select(mergent_cols)
    .with_columns(
        pl.col('seed_issuer_id').cast(pl.Float64).round(1),
        pl.col('year').cast(pl.Int64),
        pl.col('month').cast(pl.Int64),
        pl.col('cusip6').cast(pl.Utf8).str.strip_chars().str.slice(0, 6).alias('cusip6'),
        pl.col('cusip').cast(pl.Utf8).str.strip_chars().str.slice(0, 6).alias('cusip6_from_cusip'),
        pl.col('issuer_long_name').cast(pl.Utf8)
    )
    .with_columns(pl.coalesce(['cusip6', 'cusip6_from_cusip']).alias('cusip6'))
    .drop('cusip6_from_cusip')
    .filter(pl.col('cusip6').is_not_null())
)

mergent = add_year_month_id(mergent)

control_issuance_cusip6 = (
    control_issuances
    .join(
        mergent
        .select(['seed_issuer_id', 'year_month_id', 'cusip6', 'issuer_long_name'])
        .rename({'year_month_id': 'dpc_issuance_year_month_id'})
        .unique(),
        on=['seed_issuer_id', 'dpc_issuance_year_month_id'],
        how='left'
    )
    .filter(pl.col('cusip6').is_not_null())
    .unique()
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load and classify DPC articles
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
dpc_articles = load_dpc_article_metadata(dpc_linking_dir / 'NewsArticles.txt').lazy()

dpc_cusips = (
    pl.scan_csv(
        dpc_linking_dir / 'NewsArticlesCUSIPs.txt',
        separator='\t',
        encoding='utf8-lossy',
        infer_schema_length=1000,
        null_values=['']
    )
    .select([
        pl.col('OBLIGORID').cast(pl.Int64).alias('ObligorID'),
        pl.col('CUSIP').cast(pl.Utf8).str.strip_chars().str.slice(0, 6).alias('cusip6')
    ])
    .filter(pl.col('cusip6').is_not_null())
    .unique()
)

dpc_article_cusip6 = (
    dpc_articles
    .join(dpc_cusips, on='ObligorID', how='inner')
    .select([
        'cusip6',
        'StoryID',
        'FILENAME',
        'StoryDate',
        'article_year',
        'article_month',
        'NewsSource',
        'Category',
        'Headline',
        'NewsContent',
        'ObligorID',
        'ObligorState',
        'Obligor'
    ])
    .unique(subset=['cusip6', 'StoryID'])
    .collect(engine='streaming')
)

dpc_article_cusip6 = (
    add_year_month_id(dpc_article_cusip6, 'article_year', 'article_month')
    .rename({'year_month_id': 'article_year_month_id'})
)
dpc_article_cusip6 = add_bond_election_flag(dpc_article_cusip6)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
pull control-state articles in the -12 through 0 month window
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
window_rows = pl.concat([
    control_issuance_cusip6.with_columns(
        (pl.col('dpc_issuance_year_month_id') + lag).alias('article_year_month_id'),
        pl.lit(lag).alias('relative_month')
    )
    for lag in range(-12, 1)
])

matched_articles = (
    window_rows
    .join(
        dpc_article_cusip6.filter(pl.col('dpc_bond_election_article').eq(1)),
        on=['cusip6', 'article_year_month_id'],
        how='inner'
    )
    .with_columns(
        pl.col('StoryDate').dt.strftime('%Y-%m-%d').alias('StoryDateString'),
        pl.col('NewsContent').str.slice(0, 1500).alias('NewsContentSnippet')
    )
    .with_columns(
        pl.concat_str([
            pl.col('Headline').fill_null(''),
            pl.lit(' '),
            pl.col('NewsContentSnippet').fill_null('')
        ])
        .str.to_lowercase()
        .str.contains(
            r'\b(voter|voters|election|election day|ballot|referendum|warrant article|town warrant|take to the polls|residents to decide|polling residents)\b'
        )
        .cast(pl.Int64)
        .alias('likely_voter_bond_election_article')
    )
    .select([
        'seed_issuer_id',
        'issuer_long_name',
        'state',
        'fips',
        'year',
        'month',
        'dpc_issuance_year_month_id',
        'relative_month',
        'cusip6',
        'StoryID',
        'FILENAME',
        'StoryDateString',
        'NewsSource',
        'Category',
        'Headline',
        'likely_voter_bond_election_article',
        'NewsContentSnippet',
        'NewsContent',
        'ObligorID',
        'ObligorState',
        'Obligor',
        'dpc_bond_election_articles_12_0',
        'dpc_total_articles_12_0'
    ])
    .sort(['state', 'seed_issuer_id', 'dpc_issuance_year_month_id', 'StoryDateString', 'StoryID'])
)

unique_stories = (
    matched_articles
    .group_by(['StoryID'])
    .agg(
        pl.col('FILENAME').first(),
        pl.col('StoryDateString').first(),
        pl.col('NewsSource').first(),
        pl.col('Category').first(),
        pl.col('Headline').first(),
        pl.col('likely_voter_bond_election_article').max(),
        pl.col('NewsContentSnippet').first(),
        pl.col('NewsContent').first(),
        pl.col('state').drop_nulls().unique().sort().alias('control_states_matched'),
        pl.col('seed_issuer_id').drop_nulls().n_unique().alias('matched_control_issuers'),
        pl.col('dpc_issuance_year_month_id').drop_nulls().n_unique().alias('matched_control_issuances')
    )
    .sort(['StoryDateString', 'StoryID'])
    .with_columns(
        pl.col('control_states_matched').list.join(', ').alias('control_states_matched')
    )
)

summary_by_state = (
    matched_articles
    .group_by('state')
    .agg(
        pl.col('seed_issuer_id').n_unique().alias('control_issuers'),
        pl.col('dpc_issuance_year_month_id').n_unique().alias('control_issuance_months'),
        pl.col('StoryID').n_unique().alias('unique_stories'),
        pl.col('StoryID').filter(pl.col('likely_voter_bond_election_article').eq(1)).n_unique().alias('likely_voter_election_stories'),
        pl.len().alias('matched_issuance_article_rows')
    )
    .sort('unique_stories', descending=True)
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save outputs
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
article_output = output_dir / 'Control_State_Bond_Election_Articles.csv'
unique_story_output = output_dir / 'Control_State_Bond_Election_Unique_Stories.csv'
summary_output = output_dir / 'Control_State_Bond_Election_Summary.csv'

matched_articles.write_csv(article_output)
unique_stories.write_csv(unique_story_output)
summary_by_state.write_csv(summary_output)

print(f'Wrote {article_output}')
print(f'Wrote {unique_story_output}')
print(f'Wrote {summary_output}')
print(summary_by_state)
