'''
Monitor and submit DPC OpenAI Batch API chunks sequentially.

This script is designed to avoid the organization/model enqueued-token limit by
keeping at most one chunk active at a time. It:
  1. reads the chunk manifest created by the classification script,
  2. checks active batch status,
  3. downloads and parses completed outputs,
  4. submits the next pending chunk,
  5. optionally repeats until all chunks are complete.

Run once:
  python3 "Code/Python/DPC News/Monitor OpenAI Batch Chunks.py" --once

Run continuously:
  python3 "Code/Python/DPC News/Monitor OpenAI Batch Chunks.py" --watch --sleep-seconds 300
'''

from __future__ import annotations

import argparse
import json
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import polars as pl


project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
data_dir = project_dir / 'Data'

output_date = '260605'
base_dir = data_dir / 'DPC Data' / 'News' / 'OpenAI Bond Election Classification'
chunk_dir = base_dir / 'batch_chunks'

manifest_path = chunk_dir / f'DPC_Bond_Election_OpenAI_Batch_Chunks_{output_date}.json'
state_path = chunk_dir / f'DPC_Bond_Election_OpenAI_Batch_Chunk_State_{output_date}.json'
combined_output_jsonl = base_dir / f'DPC_Bond_Election_OpenAI_Batch_Output_All_Chunks_{output_date}.jsonl'
candidate_csv = base_dir / f'DPC_Bond_Election_Candidate_Articles_{output_date}.csv'
combined_classification_csv = base_dir / f'DPC_Bond_Election_OpenAI_Classifications_{output_date}.csv'
pid_path = chunk_dir / f'DPC_Bond_Election_OpenAI_Batch_Monitor_{output_date}.pid'

ACTIVE_STATUSES = {'validating', 'in_progress', 'finalizing', 'cancelling'}
TERMINAL_STATUSES = {'completed', 'failed', 'expired', 'cancelled'}


def now_string() -> str:
    return datetime.now().strftime('%Y-%m-%d %H:%M:%S')


def log(message: str) -> None:
    print(f'[{now_string()}] {message}', flush=True)


def get_openai_client():
    try:
        from openai import OpenAI
    except ImportError as exc:
        raise RuntimeError('The openai Python package is not installed.') from exc

    if not os.environ.get('OPENAI_API_KEY'):
        raise RuntimeError('OPENAI_API_KEY is not set.')

    return OpenAI()


def object_to_jsonable(obj: Any) -> Any:
    if hasattr(obj, 'model_dump'):
        return obj.model_dump()
    if hasattr(obj, 'dict'):
        return obj.dict()
    return obj


def get_file_text(client: Any, file_id: str) -> str:
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


def load_manifest() -> dict[str, Any]:
    if not manifest_path.exists():
        raise FileNotFoundError(f'Missing chunk manifest: {manifest_path}')
    return json.loads(manifest_path.read_text(encoding='utf-8'))


def initial_state(manifest: dict[str, Any]) -> dict[str, Any]:
    return {
        'created_at': now_string(),
        'updated_at': now_string(),
        'chunks': [
            {
                'chunk_index': chunk['chunk_index'],
                'path': chunk['path'],
                'requests': chunk['requests'],
                'estimated_tokens': chunk['estimated_tokens'],
                'size_mb': chunk['size_mb'],
                'status': 'pending',
                'file_id': None,
                'batch_id': None,
                'output_file_id': None,
                'error_file_id': None,
                'submitted_at': None,
                'completed_at': None,
                'downloaded_at': None,
                'output_jsonl': str(chunk_dir / f"DPC_Bond_Election_OpenAI_Batch_Output_{output_date}_part{chunk['chunk_index']:03d}.jsonl")
            }
            for chunk in manifest['chunks']
        ]
    }


def load_state() -> dict[str, Any]:
    manifest = load_manifest()
    if not state_path.exists():
        state = initial_state(manifest)
        save_state(state)
        return state

    state = json.loads(state_path.read_text(encoding='utf-8'))
    known = {chunk['chunk_index'] for chunk in state['chunks']}
    for chunk in manifest['chunks']:
        if chunk['chunk_index'] not in known:
            state['chunks'].append(initial_state({'chunks': [chunk]})['chunks'][0])
    return state


def save_state(state: dict[str, Any]) -> None:
    state['updated_at'] = now_string()
    state_path.write_text(json.dumps(state, indent=2), encoding='utf-8')


def parse_batch_output(output_path: Path) -> pl.DataFrame:
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


def rebuild_combined_outputs(state: dict[str, Any]) -> None:
    output_paths = [
        Path(chunk['output_jsonl'])
        for chunk in state['chunks']
        if chunk.get('downloaded_at') and Path(chunk['output_jsonl']).exists()
    ]
    if not output_paths:
        return

    with combined_output_jsonl.open('w', encoding='utf-8') as out_fh:
        for path in output_paths:
            out_fh.write(path.read_text(encoding='utf-8'))

    classifications = parse_batch_output(combined_output_jsonl)
    if candidate_csv.exists():
        candidates = pl.read_csv(candidate_csv)
        classifications = (
            candidates
            .join(classifications, on='StoryID', how='inner')
            .sort(['classification', 'StoryDateString', 'StoryID'])
        )

    classifications.write_csv(combined_classification_csv)
    log(f'Updated combined classifications: {combined_classification_csv}')


def refresh_active_batches(client: Any, state: dict[str, Any]) -> None:
    changed = False
    for chunk in state['chunks']:
        batch_id = chunk.get('batch_id')
        if not batch_id:
            continue
        if chunk.get('status') in TERMINAL_STATUSES and chunk.get('downloaded_at'):
            continue

        batch = client.batches.retrieve(batch_id)
        batch_json = object_to_jsonable(batch)
        status = batch_json.get('status')
        if status != chunk.get('status'):
            log(f"Chunk {chunk['chunk_index']:03d}: {chunk.get('status')} -> {status}")
            changed = True

        chunk['status'] = status
        chunk['output_file_id'] = batch_json.get('output_file_id')
        chunk['error_file_id'] = batch_json.get('error_file_id')
        chunk['last_batch_response'] = batch_json
        if status == 'completed' and not chunk.get('completed_at'):
            chunk['completed_at'] = now_string()
        if status in {'failed', 'expired', 'cancelled'}:
            chunk['terminal_error'] = batch_json.get('errors')

        if status == 'completed' and chunk.get('output_file_id') and not chunk.get('downloaded_at'):
            output_path = Path(chunk['output_jsonl'])
            output_path.write_text(get_file_text(client, chunk['output_file_id']), encoding='utf-8')
            chunk['downloaded_at'] = now_string()
            log(f"Chunk {chunk['chunk_index']:03d}: downloaded output to {output_path}")
            changed = True

    if changed:
        save_state(state)
        rebuild_combined_outputs(state)


def active_chunks(state: dict[str, Any]) -> list[dict[str, Any]]:
    return [chunk for chunk in state['chunks'] if chunk.get('status') in ACTIVE_STATUSES]


def pending_chunks(state: dict[str, Any]) -> list[dict[str, Any]]:
    return [chunk for chunk in state['chunks'] if chunk.get('status') == 'pending']


def submit_next_chunk(client: Any, state: dict[str, Any]) -> bool:
    if active_chunks(state):
        active = ', '.join(f"part{chunk['chunk_index']:03d}:{chunk['status']}" for chunk in active_chunks(state))
        log(f'Active chunk exists; not submitting another: {active}')
        return False

    pending = pending_chunks(state)
    if not pending:
        log('No pending chunks to submit.')
        return False

    chunk = pending[0]
    chunk_path = Path(chunk['path'])
    log(f"Submitting chunk {chunk['chunk_index']:03d}: {chunk['requests']} requests, {chunk['estimated_tokens']} estimated tokens")
    uploaded_file = client.files.create(file=chunk_path.open('rb'), purpose='batch')
    batch = client.batches.create(
        input_file_id=uploaded_file.id,
        endpoint='/v1/chat/completions',
        completion_window='24h',
        metadata={'description': f"DPC bond election classification part {chunk['chunk_index']:03d}"}
    )
    batch_json = object_to_jsonable(batch)

    chunk['file_id'] = uploaded_file.id
    chunk['batch_id'] = batch.id
    chunk['status'] = batch_json.get('status')
    chunk['submitted_at'] = now_string()
    chunk['last_batch_response'] = batch_json
    save_state(state)
    log(f"Submitted chunk {chunk['chunk_index']:03d}: batch_id={batch.id}, file_id={uploaded_file.id}, status={chunk['status']}")
    return True


def print_summary(state: dict[str, Any]) -> None:
    counts = {}
    for chunk in state['chunks']:
        counts[chunk.get('status', 'unknown')] = counts.get(chunk.get('status', 'unknown'), 0) + 1
    count_text = ', '.join(f'{k}={v}' for k, v in sorted(counts.items()))
    log(f'Chunk status summary: {count_text}')


def monitor_once(submit: bool) -> bool:
    client = get_openai_client()
    state = load_state()
    refresh_active_batches(client, state)
    did_submit = False
    if submit:
        did_submit = submit_next_chunk(client, state)
    print_summary(state)
    save_state(state)

    done = all(chunk.get('status') in TERMINAL_STATUSES for chunk in state['chunks'])
    if done:
        rebuild_combined_outputs(state)
        log('All chunks have reached terminal status.')
    return done or did_submit


def write_pid_file() -> None:
    pid_path.write_text(str(os.getpid()), encoding='utf-8')
    log(f'Wrote PID file: {pid_path}')


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='Monitor and submit OpenAI Batch API chunks sequentially.')
    parser.add_argument('--once', action='store_true', help='Run one monitor iteration and exit.')
    parser.add_argument('--watch', action='store_true', help='Loop until all chunks finish.')
    parser.add_argument('--sleep-seconds', type=int, default=300, help='Seconds between watch iterations.')
    parser.add_argument('--no-submit', action='store_true', help='Only monitor/download; do not submit pending chunks.')
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if not args.once and not args.watch:
        raise SystemExit('Specify --once or --watch.')

    if args.watch:
        write_pid_file()
        while True:
            done_or_submitted = monitor_once(submit=not args.no_submit)
            state = load_state()
            if all(chunk.get('status') in TERMINAL_STATUSES for chunk in state['chunks']):
                break
            if done_or_submitted:
                # Give newly submitted batches time to validate before polling again.
                time.sleep(args.sleep_seconds)
            else:
                time.sleep(args.sleep_seconds)
    else:
        monitor_once(submit=not args.no_submit)


if __name__ == '__main__':
    main()

