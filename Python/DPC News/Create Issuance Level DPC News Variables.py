'''
Create Issuance-Level DPC News Variables

This script links DPC news articles to Mergent issuances by issuer CUSIP6 and
aggregates article coverage in the months before each issuance.
'''

# SET DATE FOR OUTPUT FILES
output_date = '260611'

#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
setup
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
from pathlib import Path

import pandas as pd
import polars as pl


project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
data_dir = project_dir / 'Data'

dpc_news_dir = data_dir / 'DPC Data' / 'News'
dpc_linking_dir = dpc_news_dir / 'Linking Files'

issuance_input = data_dir / 'News' / 'Issuance_Lvl_AbnormalNews_HeadlineFilter_260611.gzip'
mergent_input = data_dir / 'Mergent' / 'Clean' / '260610_city_cusiplevel_statereq_purpose_yieldspread.dta'

output_dir = data_dir / 'DPC Data' / 'News'
output_dir.mkdir(parents=True, exist_ok=True)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
helper functions
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
def add_year_month_id(df: pl.DataFrame, year_col: str = 'year', month_col: str = 'month') -> pl.DataFrame:
    '''
    Convert calendar year/month to a monotonically increasing month index.

    The index is arithmetic rather than sample-specific, so offsets like -12 and
    -1 can be used safely even when some months are absent from an input file.
    '''
    return df.with_columns(
        ((pl.col(year_col).cast(pl.Int64) * 12) + pl.col(month_col).cast(pl.Int64)).alias('year_month_id')
    )


def aggregate_event_window(
        issuance_cusip6: pl.DataFrame,
        dpc_articles_by_cusip6: pl.DataFrame,
        start_lag: int,
        end_lag: int,
        output_col: str,
        filter_col: str | None = None
) -> pl.DataFrame:
    '''
    Count unique DPC stories in a relative month window around an issuance.

    Example: start_lag=-12 and end_lag=-1 means the 12 calendar months before
    the issuance month, excluding the issuance month itself.
    '''
    story_count = pl.col('StoryID')
    if filter_col is not None:
        story_count = story_count.filter(pl.col(filter_col).eq(1))

    window_rows = pl.concat([
        issuance_cusip6.with_columns(
            (pl.col('dpc_issuance_year_month_id') + lag).alias('article_year_month_id')
        )
        for lag in range(start_lag, end_lag + 1)
    ])

    return (
        window_rows
        .join(
            dpc_articles_by_cusip6,
            on=['cusip6', 'article_year_month_id'],
            how='left'
        )
        .group_by(['seed_issuer_id', 'dpc_issuance_year_month_id'])
        .agg(
            # Drop nulls before n_unique so issuances with no matched stories get zero.
            story_count.drop_nulls().n_unique().alias(output_col)
        )
    )


def load_dpc_article_metadata(path: Path) -> pl.DataFrame:
    '''
    Load NewsArticles.txt despite embedded tabs in NewsContent.

    The file is logically tab-delimited, but the NewsContent field can contain
    extra tab characters. A normal CSV reader may therefore see too many columns.
    The fields around NewsContent have stable positions, so parse the first
    fields and final obligor fields explicitly, then rebuild NewsContent from
    the variable-width middle.
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
            pl.col('ObligorID').cast(pl.Int64, strict=False)
        ])
        .with_columns(
            pl.col('StoryDate').dt.year().cast(pl.Int64).alias('article_year'),
            pl.col('StoryDate').dt.month().cast(pl.Int64).alias('article_month')
        )
        .filter(pl.col('StoryDate').is_not_null())
        .filter(pl.col('ObligorID').is_not_null())
    )


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load issuance-level sample
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# This is the issuance-level file used by the RavenPack news pipeline. It does
# not include CUSIPs, so we attach issuance-month CUSIP6 values from Mergent
# below.
issuance_dta = (
    pl.read_parquet(issuance_input)
    .with_columns(
        pl.col('seed_issuer_id').cast(pl.Int64),
        pl.col('year').cast(pl.Int64),
        pl.col('month').cast(pl.Int64)
    )
)

if 'issuance_year_month_id' in issuance_dta.columns:
    issuance_dta = issuance_dta.with_columns(pl.col('issuance_year_month_id').cast(pl.Int64))

issuance_dta = (
    add_year_month_id(issuance_dta)
    .rename({'year_month_id': 'dpc_issuance_year_month_id'})
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load Mergent CUSIP6 values for each issuance month
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# Polars does not read Stata files directly, so pandas is used only for this
# import. The rest of the pipeline is Polars.
mergent_cols = ['seed_issuer_id', 'year', 'month', 'cusip6', 'cusip', 'issue_id']
mergent = pl.DataFrame(pd.read_stata(mergent_input, columns=mergent_cols))

mergent = (
    mergent
    .select(mergent_cols)
    .with_columns(
        pl.col('seed_issuer_id').cast(pl.Int64),
        pl.col('year').cast(pl.Int64),
        pl.col('month').cast(pl.Int64),
        pl.col('cusip6').cast(pl.Utf8).str.strip_chars().str.slice(0, 6).alias('cusip6'),
        pl.col('cusip').cast(pl.Utf8).str.strip_chars().str.slice(0, 6).alias('cusip6_from_cusip')
    )
    .with_columns(
        pl.coalesce(['cusip6', 'cusip6_from_cusip']).alias('cusip6')
    )
    .drop('cusip6_from_cusip')
    .filter(pl.col('cusip6').is_not_null())
)

mergent = add_year_month_id(mergent)

# Keep one row per issuer-month-CUSIP6. If an issuer has multiple CUSIP6 values
# in the same issuance month, the event-window counts below use the union of
# articles across those CUSIP6 values and deduplicate stories.
issuance_cusip6 = (
    issuance_dta
    .select(['seed_issuer_id', 'dpc_issuance_year_month_id'])
    .join(
        mergent.select(['seed_issuer_id', 'year_month_id', 'cusip6'])
        .rename({'year_month_id': 'dpc_issuance_year_month_id'})
        .unique(),
        on=['seed_issuer_id', 'dpc_issuance_year_month_id'],
        how='left'
    )
    .filter(pl.col('cusip6').is_not_null())
    .unique()
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
load DPC article metadata and CUSIP links
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# NewsArticles.txt is article-level metadata. NewsArticlesCUSIPs.txt maps the
# DPC obligor ID to security CUSIPs. We reduce those security CUSIPs to CUSIP6
# to match issuers.
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
        'NewsContent'
    ])
    # DPC can map one obligor to many full CUSIPs inside the same CUSIP6. Count
    # each story once per CUSIP6.
    .unique(subset=['cusip6', 'StoryID'])
    .collect(engine='streaming')
)

dpc_article_cusip6 = (
    add_year_month_id(dpc_article_cusip6, 'article_year', 'article_month')
    .rename({'year_month_id': 'article_year_month_id'})
)

# Flag stories that look like bond-election articles. The flag requires at
# least one bond-finance term and one election/voting term in the DPC headline,
# category, or article text.
bond_terms = r'\b(bond|bonds|bonded|bonding|general obligation|go bond|go bonds|revenue bond|revenue bonds)\b'
election_terms = r'\b(election|elections|elector|electors|voter|voters|vote|votes|voted|voting|ballot|referendum|measure|proposition|prop\.?|approved|rejected|passed|defeated)\b'

dpc_article_text = pl.concat_str([
    pl.col('Headline').fill_null(''),
    pl.lit(' '),
    pl.col('Category').fill_null(''),
    pl.lit(' '),
    pl.col('NewsContent').fill_null('')
]).str.to_lowercase()

dpc_article_cusip6 = dpc_article_cusip6.with_columns(
    (
        dpc_article_text.str.contains(bond_terms)
        & dpc_article_text.str.contains(election_terms)
    )
    .cast(pl.Int64)
    .alias('dpc_bond_election_article')
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
aggregate DPC articles to CUSIP6-month level
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
dpc_monthly = (
    dpc_article_cusip6
    .group_by(['cusip6', 'article_year', 'article_month', 'article_year_month_id'])
    .agg(
        pl.col('StoryID').n_unique().alias('dpc_article_count'),
        pl.col('NewsSource').drop_nulls().n_unique().alias('dpc_unique_sources'),
        pl.col('StoryID').alias('StoryID')
    )
    .rename({
        'article_year': 'year',
        'article_month': 'month',
        'article_year_month_id': 'year_month_id'
    })
)

# Indicator requested by the user: even if an issuance has zero articles in the
# 12 months before issuance, flag whether any of its issuer CUSIP6 values ever
# appears in the DPC news data.
dpc_cusip6_ever = (
    dpc_article_cusip6
    .group_by('cusip6')
    .agg(
        pl.col('StoryID').n_unique().alias('dpc_lifetime_article_count')
    )
)

# For each issuance issuer, count unique sources that ever cover any of its
# issuance-month CUSIP6 values in the DPC sample period.
issuance_dpc_sources = (
    issuance_cusip6
    .join(
        dpc_article_cusip6.select(['cusip6', 'NewsSource']),
        on='cusip6',
        how='left'
    )
    .group_by(['seed_issuer_id', 'dpc_issuance_year_month_id'])
    .agg(
        pl.col('NewsSource').drop_nulls().n_unique().alias('dpc_lifetime_source_count')
    )
)

issuance_any_dpc = (
    issuance_cusip6
    .join(dpc_cusip6_ever, on='cusip6', how='left')
    .group_by(['seed_issuer_id', 'dpc_issuance_year_month_id'])
    .agg(
        pl.col('cusip6').n_unique().alias('dpc_num_issuance_cusip6'),
        pl.col('dpc_lifetime_article_count').fill_null(0).sum().alias('dpc_lifetime_article_count'),
        pl.col('dpc_lifetime_article_count').is_not_null().max().cast(pl.Int64).alias('dpc_issuer_has_any_articles')
    )
    .join(
        issuance_dpc_sources,
        on=['seed_issuer_id', 'dpc_issuance_year_month_id'],
        how='left'
    )
    .with_columns(
        pl.col('dpc_lifetime_source_count').fill_null(0).cast(pl.Int64)
    )
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
create issuance-level DPC event-window counts
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
# Negative windows exclude the issuance month. The 12-month prior window
# requested in the prompt is dpc_total_articles_12_neg1.
window_specs = [
    (-1, -1, 'dpc_total_articles_1_neg1'),
    (-3, -1, 'dpc_total_articles_3_neg1'),
    (-6, -1, 'dpc_total_articles_6_neg1'),
    (-12, -1, 'dpc_total_articles_12_neg1'),
    (-12, 0, 'dpc_total_articles_12_0'),
    (-24, -1, 'dpc_total_articles_24_neg1'),
]

bond_election_window_specs = [
    (start_lag, end_lag, output_col.replace('dpc_total_articles', 'dpc_bond_election_articles'))
    for start_lag, end_lag, output_col in window_specs
]

window_aggs = [
    aggregate_event_window(issuance_cusip6, dpc_article_cusip6, start_lag, end_lag, output_col)
    for start_lag, end_lag, output_col in window_specs
] + [
    aggregate_event_window(
        issuance_cusip6,
        dpc_article_cusip6,
        start_lag,
        end_lag,
        output_col,
        filter_col='dpc_bond_election_article'
    )
    for start_lag, end_lag, output_col in bond_election_window_specs
]

dpc_issuance_windows = issuance_any_dpc
for window_agg in window_aggs:
    dpc_issuance_windows = dpc_issuance_windows.join(
        window_agg,
        on=['seed_issuer_id', 'dpc_issuance_year_month_id'],
        how='full',
        coalesce=True
    )

dpc_count_cols = [name for _, _, name in window_specs + bond_election_window_specs]
dpc_issuance_windows = (
    dpc_issuance_windows
    .with_columns([
        pl.col(col).fill_null(0).cast(pl.Int64)
        for col in dpc_count_cols
    ])
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
merge DPC variables onto issuance-level data
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
issuance_with_dpc_news = (
    issuance_dta
    .join(
        dpc_issuance_windows,
        on=['seed_issuer_id', 'dpc_issuance_year_month_id'],
        how='left'
    )
    .with_columns(
        pl.col('dpc_num_issuance_cusip6').fill_null(0).cast(pl.Int64),
        pl.col('dpc_lifetime_article_count').fill_null(0).cast(pl.Int64),
        pl.col('dpc_lifetime_source_count').fill_null(0).cast(pl.Int64),
        pl.col('dpc_issuer_has_any_articles').fill_null(0).cast(pl.Int64),
        *[pl.col(col).fill_null(0).cast(pl.Int64) for col in dpc_count_cols]
    )
)


#%%
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
save outputs and diagnostics
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
output_csv = output_dir / f'Issuance_Lvl_DPC_News_{output_date}.csv'
output_parquet = output_dir / f'Issuance_Lvl_DPC_News_{output_date}.gzip'
diagnostics_csv = output_dir / f'DPC_News_Issuance_Diagnostics_{output_date}.csv'

issuance_with_dpc_news.write_csv(output_csv)
issuance_with_dpc_news.write_parquet(output_parquet, compression='gzip')

diagnostics = pl.DataFrame({
    'metric': [
        'issuance_rows',
        'issuance_rows_with_cusip6',
        'dpc_cusip6_with_articles',
        'dpc_bond_election_story_cusip6_rows',
        'dpc_bond_election_unique_stories',
        'issuance_rows_with_any_dpc_sources',
        'issuance_rows_with_any_dpc_articles',
        'issuance_rows_with_prior_12m_dpc_articles',
        'issuance_rows_with_prior_12m_dpc_bond_election_articles'
    ],
    'value': [
        issuance_with_dpc_news.height,
        issuance_cusip6.select(['seed_issuer_id', 'dpc_issuance_year_month_id']).unique().height,
        dpc_cusip6_ever.height,
        dpc_article_cusip6.filter(pl.col('dpc_bond_election_article').eq(1)).height,
        dpc_article_cusip6
        .filter(pl.col('dpc_bond_election_article').eq(1))
        .select('StoryID')
        .n_unique(),
        issuance_with_dpc_news.filter(pl.col('dpc_lifetime_source_count').gt(0)).height,
        issuance_with_dpc_news.filter(pl.col('dpc_issuer_has_any_articles').eq(1)).height,
        issuance_with_dpc_news.filter(pl.col('dpc_total_articles_12_neg1').gt(0)).height,
        issuance_with_dpc_news.filter(pl.col('dpc_bond_election_articles_12_neg1').gt(0)).height
    ]
})
diagnostics.write_csv(diagnostics_csv)

print(f'Wrote {output_csv}')
print(f'Wrote {output_parquet}')
print(f'Wrote {diagnostics_csv}')
print(diagnostics)
