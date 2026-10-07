'''
Process OpenAI Batch API classifications for DPC bond-election candidates.

This script is safe to rerun while batches are still completing. It:
  1. reads every completed batch output JSONL chunk currently on disk,
  2. parses the model JSON response into article-level classifications,
  3. joins classifications to the DPC candidate article file,
  4. joins classified stories to control-state issuance/article matches,
  5. saves summaries and examples of control-state stories classified as true
     voter bond referenda.

Control states are inherited from:
  Pull Control State Bond Election Articles.py
where control issuances are city_go_vote == 0 and the window is -12 through 0.
'''

#%%
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import polars as pl


output_date = '260605'

project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
data_dir = project_dir / 'Data'

dpc_news_dir = data_dir / 'DPC Data' / 'News'
classification_dir = dpc_news_dir / 'OpenAI Bond Election Classification'
chunk_dir = classification_dir / 'batch_chunks'
control_dir = dpc_news_dir / 'Control State Bond Election Articles'

candidate_csv = classification_dir / f'DPC_Bond_Election_Candidate_Articles_{output_date}.csv'
combined_output_jsonl = classification_dir / f'DPC_Bond_Election_OpenAI_Batch_Output_All_Chunks_{output_date}.jsonl'

all_classifications_csv = classification_dir / f'DPC_Bond_Election_OpenAI_Classifications_Processed_{output_date}.csv'
classification_summary_csv = classification_dir / f'DPC_Bond_Election_OpenAI_Classification_Summary_{output_date}.csv'

control_articles_csv = control_dir / f'Control_State_Bond_Election_Articles_{output_date}.csv'
control_ai_joined_csv = classification_dir / f'Control_State_OpenAI_Bond_Election_Classifications_{output_date}.csv'
control_summary_csv = classification_dir / f'Control_State_OpenAI_Bond_Election_Summary_{output_date}.csv'
control_voter_examples_csv = classification_dir / f'Control_State_OpenAI_Voter_Bond_Referendum_Examples_{output_date}.csv'
control_non_education_referendum_csv = (
    classification_dir / f'Control_State_OpenAI_Non_Education_Voter_Bond_Referendum_Articles_{output_date}.csv'
)


#%%
def parse_model_content(raw_content: str | None) -> dict[str, Any]:
    '''Parse one model JSON response, returning a parse_error row if needed.'''
    if raw_content is None:
        return {
            'classification': 'parse_error',
            'mentions_bond_debt': None,
            'mentions_voter_election_or_referendum': None,
            'mentions_city_leader_vote': None,
            'confidence': 'low',
            'reason': 'No model content returned.'
        }

    try:
        return json.loads(raw_content)
    except json.JSONDecodeError as exc:
        return {
            'classification': 'parse_error',
            'mentions_bond_debt': None,
            'mentions_voter_election_or_referendum': None,
            'mentions_city_leader_vote': None,
            'confidence': 'low',
            'reason': f'Could not parse model output: {type(exc).__name__}'
        }


def parse_batch_output_jsonl(path: Path) -> list[dict[str, Any]]:
    '''Parse an OpenAI Batch API output JSONL file.'''
    rows = []
    with path.open('r', encoding='utf-8') as fh:
        for line in fh:
            if not line.strip():
                continue

            item = json.loads(line)
            custom_id = item.get('custom_id', '')
            story_id = custom_id.removeprefix('dpc-story-')
            error = item.get('error')
            response = item.get('response') or {}
            body = response.get('body') or {}

            raw_content = None
            try:
                raw_content = body['choices'][0]['message']['content']
            except (KeyError, IndexError, TypeError):
                raw_content = None

            parsed = parse_model_content(raw_content)
            rows.append({
                'StoryID': story_id,
                'custom_id': custom_id,
                'source_output_file': path.name,
                'batch_error': json.dumps(error) if error else None,
                'raw_model_content': raw_content,
                'classification': parsed.get('classification'),
                'mentions_bond_debt': parsed.get('mentions_bond_debt'),
                'mentions_voter_election_or_referendum': parsed.get('mentions_voter_election_or_referendum'),
                'mentions_city_leader_vote': parsed.get('mentions_city_leader_vote'),
                'confidence': parsed.get('confidence'),
                'reason': parsed.get('reason')
            })

    return rows


def get_completed_output_files() -> list[Path]:
    '''Return completed chunk output files, plus combined output if chunks are absent.'''
    chunk_outputs = sorted(chunk_dir.glob(f'DPC_Bond_Election_OpenAI_Batch_Output_{output_date}_part*.jsonl'))
    if chunk_outputs:
        return chunk_outputs
    if combined_output_jsonl.exists():
        return [combined_output_jsonl]
    return []


def parse_all_available_outputs() -> pl.DataFrame:
    '''Parse all available OpenAI output JSONL files into one classification frame.'''
    output_files = get_completed_output_files()
    if not output_files:
        raise FileNotFoundError(
            f'No completed batch output JSONL files found in {chunk_dir}. '
            'Wait for a chunk to complete or run the monitor.'
        )

    rows = []
    for path in output_files:
        rows.extend(parse_batch_output_jsonl(path))

    classifications = (
        pl.DataFrame(rows)
        .unique(subset=['StoryID'], keep='first')
        .sort(['classification', 'StoryID'])
    )
    return classifications


def add_article_metadata(classifications: pl.DataFrame) -> pl.DataFrame:
    '''Join model classifications to DPC candidate article metadata.'''
    candidates = pl.read_csv(candidate_csv)
    return (
        candidates
        .join(classifications, on='StoryID', how='inner')
        .sort(['classification', 'StoryDateString', 'StoryID'])
    )


def summarize_classifications(classified_articles: pl.DataFrame) -> pl.DataFrame:
    '''Summarize model classifications and confidence levels.'''
    return (
        classified_articles
        .group_by(['classification', 'confidence'])
        .agg(pl.len().alias('articles'))
        .sort(['classification', 'confidence'])
    )


def process_control_state_examples(classified_articles: pl.DataFrame) -> tuple[pl.DataFrame, pl.DataFrame, pl.DataFrame]:
    '''
    Join classifications to control-state article matches and isolate voter
    bond referendum examples.
    '''
    if not control_articles_csv.exists():
        raise FileNotFoundError(
            f'Missing {control_articles_csv}. Run Pull Control State Bond Election Articles.py first.'
        )

    control_articles = pl.read_csv(control_articles_csv)
    model_cols = [
        'StoryID',
        'classification',
        'mentions_bond_debt',
        'mentions_voter_election_or_referendum',
        'mentions_city_leader_vote',
        'confidence',
        'reason',
        'raw_model_content'
    ]

    joined = (
        control_articles
        .join(classified_articles.select(model_cols), on='StoryID', how='inner')
        .with_columns(
            pl.concat_str([
                pl.col('Headline').fill_null(''),
                pl.lit(' '),
                pl.col('NewsContentSnippet').fill_null('')
            ])
            .str.replace_all(r'\s+', ' ')
            .str.slice(0, 900)
            .alias('inspection_text')
        )
        .sort(['classification', 'state', 'StoryDateString', 'StoryID'])
    )

    summary = (
        joined
        .group_by(['state', 'classification', 'confidence'])
        .agg(
            pl.col('StoryID').n_unique().alias('unique_stories'),
            pl.col('seed_issuer_id').n_unique().alias('control_issuers'),
            pl.col('dpc_issuance_year_month_id').n_unique().alias('control_issuance_months'),
            pl.len().alias('matched_issuance_article_rows')
        )
        .sort(['state', 'classification', 'confidence'])
    )

    voter_examples = (
        joined
        .filter(pl.col('classification').eq('voter_bond_referendum'))
        .select([
            'state',
            'issuer_long_name',
            'seed_issuer_id',
            'year',
            'month',
            'relative_month',
            'StoryID',
            'StoryDateString',
            'NewsSource',
            'Headline',
            'confidence',
            'reason',
            'mentions_voter_election_or_referendum',
            'mentions_city_leader_vote',
            'inspection_text',
            'NewsContentSnippet'
        ])
        .unique(subset=['state', 'issuer_long_name', 'StoryID'])
        .sort(['state', 'StoryDateString', 'StoryID'])
    )

    return joined, summary, voter_examples


def print_control_voter_examples(voter_examples: pl.DataFrame, max_examples: int = 20) -> None:
    '''Print compact examples to the terminal for inspection.'''
    if voter_examples.height == 0:
        print('No control-state articles classified as voter_bond_referendum in available completed chunks.')
        return

    print(f'\nControl-state articles classified as voter_bond_referendum: {voter_examples.height} story-state examples')
    for row in voter_examples.head(max_examples).iter_rows(named=True):
        print('\n---')
        print(
            f"{row['state']} | {row['StoryDateString']} | "
            f"{row['issuer_long_name']} | {row['StoryID']} | confidence={row['confidence']}"
        )
        print(row['Headline'])
        print(f"Model reason: {row['reason']}")
        print((row['inspection_text'] or '')[:900])


def save_control_state_non_education_referenda(classified_articles: pl.DataFrame) -> pl.DataFrame:
    '''
    Save all voter-bond-referendum articles whose DPC obligor state is a control
    state and whose obligor/headline is not education-related.

    This is article-state level: a multi-state article can appear once per
    control state it mentions.
    '''
    issuance_dpc = pl.read_parquet(dpc_news_dir / f'Issuance_Lvl_DPC_News_{output_date}.gzip')
    control_states = (
        issuance_dpc
        .filter(pl.col('go_unlim_bond_issuance').eq(1))
        .filter(pl.col('city_go_vote').eq(0))
        .select('state')
        .unique()
        .sort('state')
        .get_column('state')
        .to_list()
    )

    education_pattern = (
        r'(?i)(SCH|SCHOOL|BRD OF ED|BOARD OF ED|EDUCATION|UNION SCH|COOP SCH|'
        r'REGIONAL HIGH|COLLEGE|UNIV|UNIVERSITY|HIGHER EDUCATION|COMMUNITY '
        r'COLLEGE|COMNTY COLLEGE|RUTGERS|ROWAN|STOCKTON|WILLIAM PATERSON|'
        r'MONTCLAIR|NEW JERSEY INSTITUTE OF TECHNOLOGY)'
    )

    non_education = (
        classified_articles
        .filter(pl.col('classification').eq('voter_bond_referendum'))
        .with_columns(pl.col('ObligorStates').fill_null('').str.split(', ').alias('control_state'))
        .explode('control_state')
        .filter(pl.col('control_state').is_in(control_states))
        .unique(subset=['StoryID', 'control_state'])
        .with_columns(
            pl.concat_str([
                pl.col('Obligors').fill_null(''),
                pl.lit(' '),
                pl.col('Headline').fill_null('')
            ])
            .str.contains(education_pattern)
            .alias('education_related')
        )
        .filter(~pl.col('education_related'))
        .select([
            'control_state',
            'StoryID',
            'StoryDateString',
            'NewsSource',
            'Headline',
            'ObligorStates',
            'Obligors',
            'cusip6_list',
            'classification',
            'confidence',
            'reason',
            'mentions_bond_debt',
            'mentions_voter_election_or_referendum',
            'mentions_city_leader_vote',
            'NewsContentForModel',
            'NewsContent'
        ])
        .sort(['control_state', 'StoryDateString', 'Headline'])
    )

    non_education.write_csv(control_non_education_referendum_csv)
    return non_education


def main() -> None:
    classifications = parse_all_available_outputs()
    classified_articles = add_article_metadata(classifications)
    classification_summary = summarize_classifications(classified_articles)

    classified_articles.write_csv(all_classifications_csv)
    classification_summary.write_csv(classification_summary_csv)

    control_joined, control_summary, voter_examples = process_control_state_examples(classified_articles)
    control_non_education = save_control_state_non_education_referenda(classified_articles)
    control_joined.write_csv(control_ai_joined_csv)
    control_summary.write_csv(control_summary_csv)
    voter_examples.write_csv(control_voter_examples_csv)

    print(f'Parsed classified stories: {classified_articles.height}')
    print(f'Wrote {all_classifications_csv}')
    print(f'Wrote {classification_summary_csv}')
    print(f'Wrote {control_ai_joined_csv}')
    print(f'Wrote {control_summary_csv}')
    print(f'Wrote {control_voter_examples_csv}')
    print(f'Wrote {control_non_education_referendum_csv}')

    print('\nClassification summary:')
    print(classification_summary)

    print('\nControl-state classification summary:')
    print(control_summary)

    print('\nControl-state non-education voter referendum articles by state:')
    print(
        control_non_education
        .group_by('control_state')
        .agg(pl.col('StoryID').n_unique().alias('articles'))
        .sort('control_state')
    )

    print_control_voter_examples(voter_examples)


if __name__ == '__main__':
    main()
