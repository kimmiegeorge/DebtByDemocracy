'''
Classify DPC bond-election candidate articles with the OpenAI Batch API.

Workflow
--------
1. prepare
   Pull all DPC articles that match a broad bond-election keyword screen and
   write:
     - candidate article CSV
     - OpenAI Batch API JSONL input file

2. submit
   Upload the JSONL file and create a Batch API job. Requires OPENAI_API_KEY.

3. status
   Check a submitted batch ID. Requires OPENAI_API_KEY.

4. download
   Download a completed batch's output file and parse article classifications.
   Requires OPENAI_API_KEY unless --output-jsonl already exists locally.

The model classifies each article into:
  - voter_bond_referendum: voters/electorate/town meeting/warrant article decide
    whether to authorize bond debt.
  - city_leader_vote: council/commission/board/aldermen or other officials vote
    to issue/approve bonds, with no voter referendum.
  - neither: bond article, election article, or finance article, but not a vote
    on authorizing bond debt.
  - ambiguous: insufficient information.
'''

#%%
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

import polars as pl


project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
data_dir = project_dir / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'

dpc_news_dir = data_dir / 'DPC Data' / 'News'
dpc_linking_dir = dpc_news_dir / 'Linking Files'

output_dir = clean_data_dir / 'DPC Data' / 'News' / 'OpenAI Bond Election Classification'
output_dir.mkdir(parents=True, exist_ok=True)

candidate_csv = output_dir / 'DPC_Bond_Election_Candidate_Articles.csv'
batch_input_jsonl = output_dir / 'DPC_Bond_Election_OpenAI_Batch_Input.jsonl'
batch_metadata_json = output_dir / 'DPC_Bond_Election_OpenAI_Batch_Metadata.json'
batch_output_jsonl = output_dir / 'DPC_Bond_Election_OpenAI_Batch_Output.jsonl'
classification_csv = output_dir / 'DPC_Bond_Election_OpenAI_Classifications.csv'
chunk_dir = output_dir / 'batch_chunks'
chunk_dir.mkdir(parents=True, exist_ok=True)


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


def add_candidate_flag(df: pl.DataFrame) -> pl.DataFrame:
    '''
    Broad first-pass candidate screen.

    This intentionally errs on inclusion. The OpenAI classification step then
    separates true voter bond referenda from city-leader votes and false
    positives.
    '''
    bond_terms = (
        r'\b(bond|bonds|bonded|bonding|general obligation|go bond|go bonds|'
        r'revenue bond|revenue bonds|bond issue|bond issues)\b'
    )
    election_or_vote_terms = (
        r'\b(election|elections|elector|electors|voter|voters|vote|votes|'
        r'voted|voting|ballot|referendum|measure|proposition|prop\.?|'
        r'warrant article|town warrant|approved|rejected|passed|defeated|'
        r'council|commission|board|aldermen|selectmen)\b'
    )

    text = pl.concat_str([
        pl.col('Headline').fill_null(''),
        pl.lit(' '),
        pl.col('Category').fill_null(''),
        pl.lit(' '),
        pl.col('NewsContent').fill_null('')
    ]).str.to_lowercase()

    return df.with_columns(
        (
            text.str.contains(bond_terms)
            & text.str.contains(election_or_vote_terms)
        )
        .cast(pl.Int64)
        .alias('candidate_bond_election_article')
    )


def get_candidate_articles(max_chars: int) -> pl.DataFrame:
    '''
    Pull unique DPC stories matching the broad bond-election candidate screen.

    Link to CUSIP6 first so the candidate set is limited to stories that can be
    used in the issuer-level DPC pipeline.
    '''
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

    article_cusip6 = (
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

    article_cusip6 = add_year_month_id(article_cusip6, 'article_year', 'article_month')
    article_cusip6 = add_candidate_flag(article_cusip6)

    return (
        article_cusip6
        .filter(pl.col('candidate_bond_election_article').eq(1))
        .group_by('StoryID')
        .agg(
            pl.col('FILENAME').first(),
            pl.col('StoryDate').first(),
            pl.col('NewsSource').first(),
            pl.col('Category').first(),
            pl.col('Headline').first(),
            pl.col('NewsContent').first(),
            pl.col('ObligorState').drop_nulls().unique().sort().alias('ObligorStates'),
            pl.col('Obligor').drop_nulls().unique().sort().alias('Obligors'),
            pl.col('cusip6').drop_nulls().unique().sort().alias('cusip6_list'),
            pl.col('cusip6').drop_nulls().n_unique().alias('num_cusip6')
        )
        .with_columns(
            pl.col('ObligorStates').list.join(', ').alias('ObligorStates'),
            pl.col('Obligors').list.join(' | ').alias('Obligors'),
            pl.col('cusip6_list').list.join(', ').alias('cusip6_list'),
            pl.col('StoryDate').dt.strftime('%Y-%m-%d').alias('StoryDateString'),
            pl.col('NewsContent').str.replace_all(r'\s+', ' ').str.slice(0, max_chars).alias('NewsContentForModel')
        )
        .select([
            'StoryID',
            'FILENAME',
            'StoryDateString',
            'NewsSource',
            'Category',
            'Headline',
            'ObligorStates',
            'Obligors',
            'cusip6_list',
            'num_cusip6',
            'NewsContentForModel',
            'NewsContent'
        ])
        .sort(['StoryDateString', 'StoryID'])
    )


SYSTEM_PROMPT = '''You classify municipal finance news articles.

Return only valid JSON with this schema:
{
  "classification": "voter_bond_referendum" | "city_leader_vote" | "neither" | "ambiguous",
  "mentions_bond_debt": true | false,
  "mentions_voter_election_or_referendum": true | false,
  "mentions_city_leader_vote": true | false,
  "confidence": "high" | "medium" | "low",
  "reason": "short explanation, 35 words or fewer"
}

Definitions:
- voter_bond_referendum: voters/electorate/residents at an election,
  referendum, or ballot measure decide whether to authorize bond debt or debt
  financing.
- city_leader_vote: city council, county commission, school board, aldermen,
  selectmen, fiscal court, or other officials vote/approve/pass a bond issue,
  ordinance, resolution, borrowing plan, or bond financing, with no voter
  referendum described.
- neither: the article is about bonds, elections, budgets, approval, or public
  finance, but not a vote on authorizing bond debt.
- ambiguous: the article may involve a voter referendum or official bond vote,
  but the provided text is insufficient or unclear.

Important distinctions:
- "Council voted", "board approved", "commission passed", or "aldermen voted"
  is city_leader_vote, not voter_bond_referendum.
- "Residents/voters approved", "on the ballot", "referendum", or
  "Election Day" is voter_bond_referendum when bond debt is being authorized.
- A town meeting or warrant article reference is not enough on its own to count
  as voter_bond_referendum unless the article also clearly says voters or the
  electorate decide the bond authorization.
- A past or upcoming voter bond referendum still counts as voter_bond_referendum
  if the article is about that referendum.
'''


def make_user_prompt(row: dict[str, Any]) -> str:
    '''Create one classification prompt.'''
    return f'''Classify this article.

StoryID: {row.get('StoryID', '')}
Date: {row.get('StoryDateString', '')}
Source: {row.get('NewsSource', '')}
Category: {row.get('Category', '')}
Headline: {row.get('Headline', '')}
Obligor states: {row.get('ObligorStates', '')}
Obligors: {row.get('Obligors', '')}

Article text:
{row.get('NewsContentForModel', '')}
'''


def write_batch_jsonl(candidates: pl.DataFrame, model: str, max_tokens: int) -> None:
    '''Write Batch API request JSONL using Chat Completions.'''
    with batch_input_jsonl.open('w', encoding='utf-8') as fh:
        for row in candidates.iter_rows(named=True):
            request = {
                'custom_id': f"dpc-story-{row['StoryID']}",
                'method': 'POST',
                'url': '/v1/chat/completions',
                'body': {
                    'model': model,
                    'temperature': 0,
                    'max_tokens': max_tokens,
                    'response_format': {'type': 'json_object'},
                    'messages': [
                        {'role': 'system', 'content': SYSTEM_PROMPT},
                        {'role': 'user', 'content': make_user_prompt(row)}
                    ]
                }
            }
            fh.write(json.dumps(request, ensure_ascii=False) + '\n')


def estimate_request_tokens(request: dict[str, Any]) -> int:
    '''
    Conservative token estimate for chunking.

    This avoids adding a tokenizer dependency. Dividing by 3 instead of 4
    intentionally overestimates for English text and JSON overhead.
    '''
    return max(1, len(json.dumps(request, ensure_ascii=False)) // 3)


def split_jsonl(args: argparse.Namespace) -> None:
    '''
    Split a prepared Batch API JSONL file into smaller estimated-token chunks.

    The org/model enqueued-token limit applies to active batches. Keep chunks
    below that cap and submit them one at a time or in very small groups.
    '''
    input_path = Path(args.input_jsonl or batch_input_jsonl)
    chunk_dir.mkdir(parents=True, exist_ok=True)

    chunk_paths = []
    current_lines = []
    current_estimated_tokens = 0
    current_requests = 0
    chunk_index = 1

    def flush_chunk() -> None:
        nonlocal current_lines, current_estimated_tokens, current_requests, chunk_index
        if not current_lines:
            return
        chunk_path = chunk_dir / f'DPC_Bond_Election_OpenAI_Batch_Input_part{chunk_index:03d}.jsonl'
        chunk_path.write_text(''.join(current_lines), encoding='utf-8')
        chunk_paths.append({
            'chunk_index': chunk_index,
            'path': str(chunk_path),
            'requests': current_requests,
            'estimated_tokens': current_estimated_tokens,
            'size_mb': round(chunk_path.stat().st_size / 1024 / 1024, 3)
        })
        current_lines = []
        current_estimated_tokens = 0
        current_requests = 0
        chunk_index += 1

    with input_path.open('r', encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue
            request = json.loads(line)
            request_tokens = estimate_request_tokens(request)

            would_exceed_tokens = current_estimated_tokens + request_tokens > args.max_estimated_tokens
            would_exceed_requests = current_requests + 1 > args.max_requests
            if current_lines and (would_exceed_tokens or would_exceed_requests):
                flush_chunk()

            current_lines.append(line)
            current_estimated_tokens += request_tokens
            current_requests += 1

        flush_chunk()

    manifest_path = chunk_dir / 'DPC_Bond_Election_OpenAI_Batch_Chunks.json'
    manifest = {
        'source_jsonl': str(input_path),
        'max_estimated_tokens': args.max_estimated_tokens,
        'max_requests': args.max_requests,
        'chunks': chunk_paths
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')

    print(f'Wrote {len(chunk_paths)} chunks to {chunk_dir}')
    print(f'Wrote {manifest_path}')
    for chunk in chunk_paths:
        print(
            f"part{chunk['chunk_index']:03d}: "
            f"{chunk['requests']} requests, "
            f"{chunk['estimated_tokens']} estimated tokens, "
            f"{chunk['size_mb']} MB"
        )


def prepare(args: argparse.Namespace) -> None:
    candidates = get_candidate_articles(max_chars=args.max_chars)
    candidates.write_csv(candidate_csv)
    write_batch_jsonl(candidates, model=args.model, max_tokens=args.max_tokens)

    print(f'Candidate stories: {candidates.height}')
    print(f'Wrote {candidate_csv}')
    print(f'Wrote {batch_input_jsonl}')


def get_openai_client():
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise RuntimeError('The openai Python package is not installed.') from exc

    if not os.environ.get('OPENAI_API_KEY'):
        raise RuntimeError('OPENAI_API_KEY is not set.')

    return OpenAI()


def object_to_jsonable(obj: Any) -> Any:
    '''Convert OpenAI SDK objects to plain JSON-compatible values.'''
    if hasattr(obj, 'model_dump'):
        return obj.model_dump()
    if hasattr(obj, 'dict'):
        return obj.dict()
    return obj


def submit(args: argparse.Namespace) -> None:
    client = get_openai_client()
    input_path = Path(args.input_jsonl or batch_input_jsonl)

    uploaded_file = client.files.create(file=input_path.open('rb'), purpose='batch')
    batch = client.batches.create(
        input_file_id=uploaded_file.id,
        endpoint='/v1/chat/completions',
        completion_window='24h',
        metadata={'description': 'DPC bond election article classification'}
    )

    metadata = {
        'input_jsonl': str(input_path),
        'uploaded_file': object_to_jsonable(uploaded_file),
        'batch': object_to_jsonable(batch)
    }
    batch_metadata_json.write_text(json.dumps(metadata, indent=2, default=str), encoding='utf-8')

    print(f'Uploaded file id: {uploaded_file.id}')
    print(f'Batch id: {batch.id}')
    print(f'Wrote {batch_metadata_json}')


def status(args: argparse.Namespace) -> None:
    client = get_openai_client()
    batch = client.batches.retrieve(args.batch_id)
    print(json.dumps(object_to_jsonable(batch), indent=2, default=str))


def get_file_text(client: Any, file_id: str) -> str:
    '''Download an OpenAI file as text across SDK versions.'''
    content = client.files.content(file_id)
    if hasattr(content, 'text'):
        return content.text
    if hasattr(content, 'read'):
        data = content.read()
        if isinstance(data, bytes):
            return data.decode('utf-8')
        return data
    if isinstance(content, bytes):
        return content.decode('utf-8')
    return str(content)


def parse_batch_output(output_path: Path) -> pl.DataFrame:
    '''Parse Batch API JSONL output to one row per StoryID.'''
    rows = []
    with output_path.open('r', encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue
            item = json.loads(line)
            custom_id = item.get('custom_id', '')
            story_id = custom_id.removeprefix('dpc-story-')
            error = item.get('error')
            response = item.get('response') or {}
            body = response.get('body') or {}

            parsed = {}
            raw_content = None
            try:
                raw_content = body['choices'][0]['message']['content']
                parsed = json.loads(raw_content)
            except Exception as exc:
                parsed = {
                    'classification': 'parse_error',
                    'mentions_bond_debt': None,
                    'mentions_voter_election_or_referendum': None,
                    'mentions_city_leader_vote': None,
                    'confidence': 'low',
                    'reason': f'Could not parse model output: {type(exc).__name__}'
                }

            rows.append({
                'StoryID': story_id,
                'custom_id': custom_id,
                'batch_error': json.dumps(error) if error else None,
                'raw_model_content': raw_content,
                **parsed
            })

    return pl.DataFrame(rows)


def download(args: argparse.Namespace) -> None:
    output_path = Path(args.output_jsonl or batch_output_jsonl)

    if args.output_jsonl is None:
        client = get_openai_client()
        batch = client.batches.retrieve(args.batch_id)
        if not batch.output_file_id:
            raise RuntimeError(f'Batch {args.batch_id} has no output_file_id yet. Status: {batch.status}')
        output_path.write_text(get_file_text(client, batch.output_file_id), encoding='utf-8')
        print(f'Wrote {output_path}')

    classifications = parse_batch_output(output_path)
    candidates = pl.read_csv(candidate_csv)
    joined = (
        candidates
        .join(classifications, on='StoryID', how='left')
        .sort(['classification', 'StoryDateString', 'StoryID'])
    )
    joined.write_csv(classification_csv)

    summary = (
        joined
        .group_by('classification')
        .agg(
            pl.len().alias('articles'),
            pl.col('confidence').value_counts().alias('confidence_counts')
        )
        .sort('articles', descending=True)
    )

    print(f'Wrote {classification_csv}')
    print(summary)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='Classify DPC bond-election articles with OpenAI Batch API.')
    subparsers = parser.add_subparsers(dest='command', required=True)

    prepare_parser = subparsers.add_parser('prepare', help='Write candidate CSV and Batch API JSONL.')
    prepare_parser.add_argument('--model', default='gpt-4o-mini', help='OpenAI model for batch classification.')
    prepare_parser.add_argument('--max-chars', type=int, default=4000, help='Max article text characters sent per request.')
    prepare_parser.add_argument('--max-tokens', type=int, default=180, help='Max output tokens per classification.')
    prepare_parser.set_defaults(func=prepare)

    split_parser = subparsers.add_parser('split', help='Split prepared JSONL into smaller estimated-token chunks.')
    split_parser.add_argument('--input-jsonl', default=None, help='Optional JSONL path. Defaults to prepared output.')
    split_parser.add_argument('--max-estimated-tokens', type=int, default=1500000,
                              help='Conservative estimated token cap per chunk.')
    split_parser.add_argument('--max-requests', type=int, default=5000,
                              help='Max requests per chunk.')
    split_parser.set_defaults(func=split_jsonl)

    submit_parser = subparsers.add_parser('submit', help='Upload JSONL and create an OpenAI batch.')
    submit_parser.add_argument('--input-jsonl', default=None, help='Optional JSONL path. Defaults to prepared output.')
    submit_parser.set_defaults(func=submit)

    status_parser = subparsers.add_parser('status', help='Retrieve batch status.')
    status_parser.add_argument('batch_id')
    status_parser.set_defaults(func=status)

    download_parser = subparsers.add_parser('download', help='Download and parse completed batch output.')
    download_parser.add_argument('batch_id', help='Batch ID. Used to find output_file_id unless --output-jsonl is set.')
    download_parser.add_argument('--output-jsonl', default=None, help='Parse an already downloaded output JSONL.')
    download_parser.set_defaults(func=download)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
