'''
Research FY2017 municipal CAFR/ACFRs and inventory all available city-archive CAFR/ACFRs with the OpenAI Batch API.

This is intentionally a two-stage workflow.  OpenAI web-search agents research
10 cities at a time and return a strict JSON result.  The local collector then
downloads only qualifying CAFR/ACFR PDFs, verifies that each downloaded file is
a PDF, and writes the manifest and document-inventory outputs.  It never uses
EMMA programmatically.

Commands
--------
prepare  Split the controlled full manifest into durable 10-city agent jobs.
submit   Upload the JSONL and create one OpenAI Batch API job (explicit opt-in).
status   Refresh and display aggregate Batch API progress.
collect  Retrieve completed or cancelled outputs, update CSVs, and download qualifying PDFs.

The Batch API is asynchronous: a submitted job may take up to 24 hours.  It
reports aggregate request counts while running; city-level results become
available when the batch output is complete.
'''

#%%
from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import ssl
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import polars as pl


project_dir = Path('~/Dropbox/Voting on Bonds').expanduser()
cafr_dir = project_dir / 'Data' / 'CAFR Collection'
default_manifest_path = cafr_dir / '2017_point_in_time_cafr_collection_manifest.csv'
default_cd_hints_path = cafr_dir / 'continuing_disclosure_emma_hints.csv'
default_runs_dir = cafr_dir / 'API Runs'

API_BASE_URL = os.environ.get('OPENAI_BASE_URL', 'https://api.openai.com/v1').rstrip('/')
DEFAULT_MODEL = os.environ.get('CAFR_OPENAI_MODEL', 'gpt-5.5')
ACTIVE_STATUSES = {'validating', 'in_progress', 'finalizing', 'cancelling'}
TERMINAL_STATUSES = {'completed', 'failed', 'expired', 'cancelled'}
QUALIFYING_DOCUMENT_TYPES = {'CAFR', 'ACFR'}


#%%
def now_utc() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def log(message: str) -> None:
    print(f'[{now_utc()}] {message}', flush=True)


def require_api_key() -> str:
    api_key = os.environ.get('OPENAI_API_KEY')
    if not api_key:
        raise RuntimeError('OPENAI_API_KEY is not set. Export it in your terminal; do not place it in a script or CSV.')
    return api_key


def verified_ssl_context() -> ssl.SSLContext:
    '''Use certifi when this Python installation has no configured CA bundle.'''
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def api_request(
    method: str,
    path: str,
    *,
    api_key: str,
    payload: dict[str, Any] | None = None,
    body: bytes | None = None,
    content_type: str | None = 'application/json'
) -> dict[str, Any] | bytes:
    '''Make a minimal OpenAI API request without writing credentials to disk.'''
    if payload is not None:
        body = json.dumps(payload).encode('utf-8')

    headers = {'Authorization': f'Bearer {api_key}'}
    if content_type:
        headers['Content-Type'] = content_type

    request = Request(f'{API_BASE_URL}{path}', data=body, headers=headers, method=method)
    try:
        with urlopen(request, timeout=120, context=verified_ssl_context()) as response:
            data = response.read()
            response_type = response.headers.get_content_type()
    except HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise RuntimeError(f'OpenAI API {method} {path} failed ({exc.code}): {detail}') from exc
    except URLError as exc:
        raise RuntimeError(f'Could not reach the OpenAI API: {exc.reason}') from exc

    if response_type == 'application/json':
        return json.loads(data.decode('utf-8'))
    return data


def upload_batch_input(path: Path, api_key: str) -> dict[str, Any]:
    '''Upload a JSONL file using multipart/form-data for the Batch API.'''
    boundary = f'----cafrbatch{uuid.uuid4().hex}'
    chunks = [
        f'--{boundary}\r\n'.encode(),
        b'Content-Disposition: form-data; name="purpose"\r\n\r\n',
        b'batch\r\n',
        f'--{boundary}\r\n'.encode(),
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'.encode(),
        b'Content-Type: application/jsonl\r\n\r\n',
        path.read_bytes(),
        b'\r\n',
        f'--{boundary}--\r\n'.encode()
    ]
    response = api_request(
        'POST',
        '/files',
        api_key=api_key,
        body=b''.join(chunks),
        content_type=f'multipart/form-data; boundary={boundary}'
    )
    return dict(response)


def run_dir_from_args(args: argparse.Namespace) -> Path:
    return Path(args.runs_dir).expanduser() / args.run_id


def state_path(run_dir: Path) -> Path:
    return run_dir / 'run_state.json'


def load_state(run_dir: Path) -> dict[str, Any]:
    path = state_path(run_dir)
    if not path.exists():
        raise FileNotFoundError(f'No run state at {path}. Run prepare first.')
    return json.loads(path.read_text(encoding='utf-8'))


def save_state(run_dir: Path, state: dict[str, Any]) -> None:
    state['updated_at'] = now_utc()
    state_path(run_dir).write_text(json.dumps(state, indent=2, sort_keys=True), encoding='utf-8')


#%%
def schema() -> dict[str, Any]:
    '''The strict response schema keeps Batch results machine-readable.'''
    document = {
        'type': 'object',
        'additionalProperties': False,
        'properties': {
            'fiscal_year': {'type': 'string'},
            'title': {'type': 'string'},
            'document_type': {'type': 'string', 'enum': ['CAFR', 'ACFR']},
            'document_url': {'type': 'string'},
            'source_type': {
                'type': 'string',
                'enum': [
                    'city_website', 'city_document_portal', 'state_repository', 'emma', 'other_official',
                    'other_nonofficial'
                ]
            },
            'is_fy2017_target': {'type': 'boolean'},
            'is_later_year_fallback': {'type': 'boolean'},
            'is_other_available_report': {'type': 'boolean'},
            'verification_status': {'type': 'string'},
            'notes': {'type': 'string'}
        },
        'required': [
            'fiscal_year', 'title', 'document_type', 'document_url', 'source_type',
            'is_fy2017_target', 'is_later_year_fallback', 'is_other_available_report',
            'verification_status', 'notes'
        ]
    }
    record = {
        'type': 'object',
        'additionalProperties': False,
        'properties': {
            'record_id': {'type': 'string'},
            'collection_outcome': {'type': 'string', 'enum': ['found_2017', 'later_years_only', 'not_found', 'needs_review']},
            'city_official_website_url': {'type': 'string'},
            'city_official_domain': {'type': 'string'},
            'landing_page_url': {'type': 'string'},
            'landing_page_domain': {'type': 'string'},
            'landing_page_title': {'type': 'string'},
            'landing_page_financial_document_count': {'type': 'string'},
            'landing_page_count_scope': {'type': 'string'},
            'landing_page_count_notes': {'type': 'string'},
            'report_found': {'type': 'string', 'enum': ['yes', 'no']},
            'report_source_type': {
                'type': 'string',
                'enum': [
                    '', 'city_website', 'city_document_portal', 'state_repository', 'emma', 'other_official',
                    'other_nonofficial'
                ]
            },
            'report_document_type': {'type': 'string', 'enum': ['', 'CAFR', 'ACFR']},
            'report_title': {'type': 'string'},
            'report_fiscal_year_end': {'type': 'string'},
            'report_url': {'type': 'string'},
            'verification_status': {'type': 'string'},
            'search_queries_used': {'type': 'string'},
            'collection_notes': {'type': 'string'},
            'source_citations': {'type': 'array', 'items': {'type': 'string'}},
            'qualifying_documents': {'type': 'array', 'items': document}
        },
        'required': [
            'record_id', 'collection_outcome', 'city_official_website_url', 'city_official_domain',
            'landing_page_url', 'landing_page_domain', 'landing_page_title',
            'landing_page_financial_document_count', 'landing_page_count_scope',
            'landing_page_count_notes', 'report_found', 'report_source_type', 'report_document_type', 'report_title',
            'report_fiscal_year_end', 'report_url', 'verification_status', 'search_queries_used',
            'collection_notes', 'source_citations', 'qualifying_documents'
        ]
    }
    return {
        'type': 'object',
        'additionalProperties': False,
        'properties': {'records': {'type': 'array', 'items': record}},
        'required': ['records']
    }


def developer_prompt(max_tool_calls: int | None) -> str:
    action_budget = (
        'No explicit cap was supplied.' if max_tool_calls is None
        else f'This request is capped at {max_tool_calls} web-tool call(s).'
    )
    return f'''You are a careful municipal-finance research agent. Research every assigned city independently using web search. Your task is to identify the FY2017 city-government CAFR/ACFR target and inventory every qualifying CAFR/ACFR available on the official city financial-report archive reached. Return only the supplied strict JSON schema.

Scope and source rules
- Start with city-government websites and city-authorized document portals. A qualifying document must be explicitly titled CAFR, ACFR, Comprehensive Annual Financial Report, or Annual Comprehensive Financial Report. An Annual Financial Report/AFR is qualifying only when the official city page or report itself explicitly identifies it as the city's comprehensive report. Do not treat budgets, single audits, audit reports, financial-statement packages, popular annual reports, or debt documents as qualifying.
- Locate the official municipal website and an official financial-documents/annual-reports page where possible. Record both URLs/domains.
- Count the financial documents visibly listed on the specific landing page reached. Include nonqualifying financial documents in that count. If page content cannot be inspected reliably, return an empty count and explain why rather than guessing.
- Do not conclude an archive is empty solely because a page is dynamic, oversized, or opaque. Follow its report links, document-center filters, and official-domain search results. Only after the city archive has no qualifying CAFR/ACFR, use individual EMMA research for the FY2017 target. Never conduct systematic EMMA collection.

Archive-discovery, target, and inventory rules
- Do not begin with a year-filtered search. First find the official financial-report archive using CAFR, ACFR, comprehensive annual financial report, annual financial report, finance, transparency, and document-center terms.
- Inventory every qualifying report available from that official archive, regardless of fiscal year. Do not conduct a separate open-web hunt for non-target years. Mark FY2017 reports with is_fy2017_target=true; later reports with is_later_year_fallback=true; and earlier reports with is_other_available_report=true. Return all of them in qualifying_documents even when FY2017 was found.
- After archive discovery, target FY2017 using 2017, FY 2016-17, the fiscal-year end date, GFOA, annual audit report, filed separately, and EMMA queries as needed. `cd_audited_filing_hints`, if supplied in an assigned record, are project data with CUSIPs, filing identifiers, dates, and EMMA disclosure categories—not document URLs or proof of a CAFR. For the EMMA fallback, open the security/CUSIP page, select Continuing Disclosure, and inspect Audited Financial Statements or ACFR first. Also inspect Annual Financial Information and Operating Data because CAFRs may be classified there. The EMMA category alone does not qualify a document: verify a CAFR/ACFR title, cover, or contents. Record the CUSIP, submission identifier, filing date, and direct EMMA document URL in notes when visible. If EMMA presents a CAPTCHA, do not bypass or repeatedly retry it; return needs_review and record that CAPTCHA blocked access, with the CUSIP/page URL if available. If an official source confirms the report existed but neither the city archive nor an individual EMMA lookup yields it, use needs_review and explain the evidence.

Bounded web-search procedure
- {action_budget} Treat this as a research budget, not a target to exhaust.
- First use one focused search to locate and assess the official city finance/archive page. Do not spend repeated calls reformulating broad CAFR queries.
- If the city archive yields a qualifying report, use any remaining call only to verify the direct PDF or archive coverage; do not open EMMA.
- If the city archive has no qualifying report and at least one call remains, use one supplied CD hint to go directly to that CUSIP's EMMA Continuing Disclosure record. Prioritize a hint dated closest to FY2017 and labeled Audited Financial Statements or ACFR.
- If a third call remains, use it only to verify a specific candidate PDF, resolve a specific city/entity ambiguity, or inspect the identified EMMA disclosure category. Do not repeat a CAPTCHA or conduct an open-ended EMMA search.
- A fiscal year label such as "Fiscal year ended June 30, 2017" is FY2017. Use a four-digit fiscal_year value.
- For the FY2017 target, use an ISO date in report_fiscal_year_end when the exact date is stated; otherwise use "2017".

Quality rules
- Return a direct PDF URL only when the page/search result supports it. A landing-page URL is not a PDF URL.
- For every result, cite the official URL(s) used in source_citations and explain uncertainty in collection_notes.
- report_* fields describe the FY2017 target only. When it was not found, leave report title/year/url/source type empty.
- For a city with no qualifying report, return an empty qualifying_documents array and a truthful not_found or needs_review outcome.
- Do not invent website counts, URLs, years, or titles. Keep every string concise.'''


def load_cd_hints(path: Path, max_per_city: int) -> dict[str, list[dict[str, str]]]:
    '''Load compact audited/ACFR filing hints keyed by CAFR manifest record_id.'''
    if not path.exists():
        log(f'Continuing Disclosure hint file not found; proceeding without EMMA hints: {path}')
        return {}
    required = {
        'record_id', 'cusip', 'submission_identifier', 'disclosure_event_date', 'disclosure_category'
    }
    with path.open(newline='', encoding='utf-8-sig') as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None or not required.issubset(reader.fieldnames):
            raise RuntimeError(f'CD hint file is missing required columns: {path}')
        grouped: dict[str, list[dict[str, str]]] = {}
        for row in reader:
            record_id = str(row.get('record_id', '') or '')
            if not record_id:
                continue
            grouped.setdefault(record_id, []).append({
                'cusip': str(row.get('cusip', '') or ''),
                'submission_identifier': str(row.get('submission_identifier', '') or ''),
                'disclosure_event_date': str(row.get('disclosure_event_date', '') or ''),
                'disclosure_category': str(row.get('disclosure_category', '') or ''),
            })

    def priority(hint: dict[str, str]) -> tuple[int, str, str]:
        date = hint['disclosure_event_date']
        try:
            distance_from_target = abs(int(date[:4]) - 2017)
        except (TypeError, ValueError):
            distance_from_target = 9999
        return distance_from_target, date, hint['submission_identifier']

    compact: dict[str, list[dict[str, str]]] = {}
    for record_id, hints in grouped.items():
        # The closest filing dates are most useful for the FY2017 target; a
        # CUSIP page still exposes the surrounding disclosure history.
        compact[record_id] = sorted(hints, key=priority)[:max_per_city]
    return compact


def user_prompt(records: list[dict[str, Any]], cd_hints: dict[str, list[dict[str, str]]]) -> str:
    assigned = []
    fields = [
        'record_id', 'city_name', 'state', 'census_name', 'mergent_issuer', 'fiscal_year_end_date',
        'city_official_website_url', 'city_official_domain', 'landing_page_url', 'landing_page_domain',
        'landing_page_title', 'collection_notes'
    ]
    for record in records:
        assigned_record = {field: str(record.get(field, '') or '') for field in fields}
        assigned_record['cd_audited_filing_hints'] = cd_hints.get(str(record.get('record_id', '') or ''), [])
        assigned.append(assigned_record)
    return (
        'Research these assigned manifest records. Return one result for each record_id and no other records. '
        'The expected fiscal year is included only as a clue; the controlling target is a fiscal year ending in calendar year 2017.\n\n'
        + json.dumps(assigned, indent=2)
    )


def make_batch_request(
    job: dict[str, Any], model: str, max_tool_calls: int | None,
    search_context_size: str, reasoning_effort: str | None, cd_hints: dict[str, list[dict[str, str]]]
) -> dict[str, Any]:
    body: dict[str, Any] = {
        'model': model,
        'input': [
            {'role': 'developer', 'content': developer_prompt(max_tool_calls)},
            {'role': 'user', 'content': user_prompt(job['records'], cd_hints)}
        ],
        'tools': [{'type': 'web_search', 'search_context_size': search_context_size}],
        'tool_choice': 'required',
        'text': {
            'format': {
                'type': 'json_schema',
                'name': 'cafr_collection_results',
                'strict': True,
                'schema': schema()
            }
        }
    }
    if max_tool_calls is not None:
        body['max_tool_calls'] = max_tool_calls
    if reasoning_effort is not None:
        body['reasoning'] = {'effort': reasoning_effort}
    return {
        'custom_id': job['job_id'],
        'method': 'POST',
        'url': '/v1/responses',
        'body': body
    }


#%%
def command_prepare(args: argparse.Namespace) -> None:
    manifest_path = Path(args.manifest).expanduser()
    run_dir = run_dir_from_args(args)
    if run_dir.exists():
        raise FileExistsError(f'Run directory already exists: {run_dir}. Choose a new --run-id; existing runs are preserved.')
    if not manifest_path.exists():
        raise FileNotFoundError(f'Manifest not found: {manifest_path}')

    manifest = pl.read_csv(manifest_path, infer_schema_length=10000, null_values=[''])
    if args.only_missing_report:
        if 'report_found' not in manifest.columns:
            raise RuntimeError('--only-missing-report requires a manifest with a report_found column.')
        manifest = manifest.filter(
            pl.col('report_found').cast(pl.Utf8).fill_null('').str.to_lowercase() == 'no'
        )
    if args.limit:
        manifest = manifest.head(args.limit)
    if manifest.height == 0:
        raise RuntimeError('The selected manifest has no rows.')
    if 'record_id' not in manifest.columns:
        raise RuntimeError('The manifest must contain record_id.')
    cd_hints_path = Path(args.cd_hints).expanduser()
    cd_hints = load_cd_hints(cd_hints_path, args.max_cd_hints_per_city)
    hinted_records = len(set(manifest.get_column('record_id').cast(pl.Utf8).to_list()).intersection(cd_hints))
    log(f'Loaded EMMA routing hints for {hinted_records:,} of {manifest.height:,} selected cities.')

    run_dir.mkdir(parents=True)
    (run_dir / 'batch_manifests').mkdir()
    (run_dir / 'raw_outputs').mkdir()
    (run_dir / 'results').mkdir()
    (run_dir / 'PDFs').mkdir()

    rows = manifest.to_dicts()
    jobs = []
    requests_path = run_dir / 'openai_batch_requests.jsonl'
    with requests_path.open('w', encoding='utf-8') as fh:
        for job_index, start in enumerate(range(0, len(rows), args.cities_per_job), start=1):
            batch_rows = rows[start:start + args.cities_per_job]
            job_id = f'cafr-job-{job_index:04d}'
            batch_path = run_dir / 'batch_manifests' / f'2017_cafr_batch_{job_index:04d}.csv'
            pl.DataFrame(batch_rows, schema=manifest.schema).write_csv(batch_path)
            job = {
                'job_id': job_id,
                'job_index': job_index,
                'record_ids': [str(row['record_id']) for row in batch_rows],
                'records': batch_rows,
                'manifest_path': str(batch_path),
                'result_path': str(run_dir / 'results' / f'2017_cafr_batch_{job_index:04d}_collected.csv'),
                'inventory_path': str(run_dir / 'results' / f'2017_cafr_batch_{job_index:04d}_document_inventory.csv'),
                'status': 'pending'
            }
            fh.write(json.dumps(
                make_batch_request(
                    job, args.model, args.max_tool_calls, args.search_context_size, args.reasoning_effort, cd_hints
                ),
                separators=(',', ':')
            ) + '\n')
            del job['records']
            jobs.append(job)

    state = {
        'created_at': now_utc(),
        'updated_at': now_utc(),
        'run_id': args.run_id,
        'manifest_path': str(manifest_path),
        'cd_hints_path': str(cd_hints_path),
        'max_cd_hints_per_city': args.max_cd_hints_per_city,
        'run_dir': str(run_dir),
        'model': args.model,
        'cities_per_job': args.cities_per_job,
        'max_tool_calls': args.max_tool_calls,
        'search_context_size': args.search_context_size,
        'reasoning_effort': args.reasoning_effort,
        'only_missing_report': args.only_missing_report,
        'records_total': manifest.height,
        'jobs_total': len(jobs),
        'batch_request_path': str(requests_path),
        'openai_input_file_id': None,
        'openai_batch_id': None,
        'openai_batch_status': 'not_submitted',
        'openai_request_counts': {},
        'output_file_id': None,
        'error_file_id': None,
        'jobs': jobs
    }
    save_state(run_dir, state)
    log(
        f'Prepared {manifest.height:,} cities as {len(jobs):,} agent jobs '
        f'({args.cities_per_job} cities per job) in {run_dir}'
    )
    log(f'Batch input: {requests_path}')
    log('Review the generated inputs. Submission requires --confirm-submit and OPENAI_API_KEY.')


def update_batch_state(run_dir: Path, state: dict[str, Any], api_key: str) -> dict[str, Any]:
    batch_id = state.get('openai_batch_id')
    if not batch_id:
        return state
    batch = dict(api_request('GET', f'/batches/{batch_id}', api_key=api_key, content_type=None))
    state['openai_batch_status'] = batch.get('status', 'unknown')
    state['openai_request_counts'] = batch.get('request_counts') or {}
    state['output_file_id'] = batch.get('output_file_id')
    state['error_file_id'] = batch.get('error_file_id')
    state['last_batch_response'] = batch
    save_state(run_dir, state)
    return state


def command_submit(args: argparse.Namespace) -> None:
    if not args.confirm_submit:
        raise RuntimeError('Refusing to incur API charges without --confirm-submit. Run status/local checks first.')
    run_dir = run_dir_from_args(args)
    state = load_state(run_dir)
    if state.get('openai_batch_id'):
        raise RuntimeError(f"This run has already been submitted: {state['openai_batch_id']}. Use status or collect.")
    api_key = require_api_key()
    request_path = Path(state['batch_request_path'])
    log(f"Uploading {state['jobs_total']:,} agent jobs for {state['records_total']:,} cities...")
    uploaded = upload_batch_input(request_path, api_key)
    batch = dict(api_request(
        'POST',
        '/batches',
        api_key=api_key,
        payload={
            'input_file_id': uploaded['id'],
            'endpoint': '/v1/responses',
            'completion_window': '24h',
            'metadata': {'description': f"CAFR collection run {state['run_id']}"}
        }
    ))
    state['openai_input_file_id'] = uploaded['id']
    state['openai_batch_id'] = batch['id']
    state['openai_batch_status'] = batch.get('status', 'validating')
    state['openai_request_counts'] = batch.get('request_counts') or {}
    state['submitted_at'] = now_utc()
    state['last_batch_response'] = batch
    save_state(run_dir, state)
    log(f"Submitted Batch API job {batch['id']} (status: {state['openai_batch_status']}).")


def progress_summary(state: dict[str, Any]) -> str:
    counts = state.get('openai_request_counts') or {}
    completed = counts.get('completed', 0)
    failed = counts.get('failed', 0)
    total = counts.get('total') or state.get('jobs_total', 0)
    local_done = sum(job.get('status') == 'collected' for job in state.get('jobs', []))
    return (
        f"run={state['run_id']} | batch={state.get('openai_batch_status')} | "
        f"agent jobs={completed}/{total} completed, {failed} failed | "
        f"local batch manifests={local_done}/{state.get('jobs_total', 0)} collected"
    )


def command_status(args: argparse.Namespace) -> None:
    run_dir = run_dir_from_args(args)
    state = load_state(run_dir)
    if state.get('openai_batch_id') and not args.local:
        state = update_batch_state(run_dir, state, require_api_key())
    log(progress_summary(state))
    if state.get('openai_batch_id'):
        log(f"OpenAI batch id: {state['openai_batch_id']}")
    else:
        log('Not yet submitted. This is a local preparation state.')


def command_watch(args: argparse.Namespace) -> None:
    while True:
        command_status(args)
        state = load_state(run_dir_from_args(args))
        if state.get('openai_batch_status') in TERMINAL_STATUSES:
            return
        time.sleep(args.sleep_seconds)


#%%
def response_text(response_body: dict[str, Any]) -> str:
    '''Extract the JSON string from a Responses API result without SDK assumptions.'''
    texts = []
    for output in response_body.get('output', []) or []:
        for content in output.get('content', []) or []:
            if content.get('type') in {'output_text', 'text'} and content.get('text'):
                texts.append(content['text'])
    if not texts and response_body.get('output_text'):
        texts.append(response_body['output_text'])
    return ''.join(texts)


def load_batch_results(output_path: Path) -> tuple[dict[str, dict[str, Any]], list[dict[str, Any]]]:
    results = {}
    errors = []
    for line in output_path.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        job_id = item.get('custom_id', '')
        response = item.get('response') or {}
        if response.get('status_code') != 200:
            errors.append({'job_id': job_id, 'error': item.get('error') or response})
            continue
        try:
            parsed = json.loads(response_text(response.get('body') or {}))
            results[job_id] = parsed
        except Exception as exc:
            errors.append({'job_id': job_id, 'error': f'Could not parse structured result: {type(exc).__name__}: {exc}'})
    return results, errors


def tool_usage_by_job(output_path: Path, jobs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    '''Extract actual per-request web-search actions and token usage from raw Batch output.'''
    job_lookup = {str(job['job_id']): job for job in jobs}
    rows = []
    for line in output_path.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        job_id = str(item.get('custom_id', ''))
        body = (item.get('response') or {}).get('body') or {}
        usage = body.get('usage') or {}
        input_details = usage.get('input_tokens_details') or {}
        output_details = usage.get('output_tokens_details') or {}
        web_calls = [entry for entry in (body.get('output') or []) if entry.get('type') == 'web_search_call']
        action_counts: dict[str, int] = {}
        for entry in web_calls:
            action_type = str((entry.get('action') or {}).get('type') or 'unknown')
            action_counts[action_type] = action_counts.get(action_type, 0) + 1
        query_count = sum(
            len((entry.get('action') or {}).get('queries') or [])
            for entry in web_calls
        )
        job = job_lookup.get(job_id, {})
        rows.append({
            'job_id': job_id,
            'record_ids': ';'.join(str(x) for x in job.get('record_ids', [])),
            'record_count': str(len(job.get('record_ids', []))),
            'response_status': str(body.get('status', '')),
            'web_tool_output_count': str(len(web_calls)),
            'web_search_action_count': str(action_counts.get('search', 0)),
            'web_open_page_action_count': str(action_counts.get('open_page', 0)),
            'web_find_in_page_action_count': str(action_counts.get('find_in_page', 0)),
            'embedded_search_query_count': str(query_count),
            'input_tokens': str(usage.get('input_tokens', '')),
            'cached_input_tokens': str(input_details.get('cached_tokens', '')),
            'output_tokens': str(usage.get('output_tokens', '')),
            'reasoning_tokens': str(output_details.get('reasoning_tokens', '')),
            'total_tokens': str(usage.get('total_tokens', '')),
        })
    return rows


def safe_filename_part(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9_.-]+', '_', value).strip('_') or 'unknown'


def pdf_details(path: Path) -> tuple[str, str]:
    '''Return page count and a modest text-searchability check when pypdf is installed.'''
    try:
        from pypdf import PdfReader
        reader = PdfReader(str(path))
        page_count = str(len(reader.pages))
        sample = ''.join((page.extract_text() or '') for page in reader.pages[:3])
        return page_count, 'yes' if sample.strip() else 'no'
    except Exception:
        return '', ''


def download_pdf(url: str, destination: Path, max_bytes: int = 150_000_000) -> tuple[bool, str]:
    '''Download only a valid PDF and never overwrite a prior file.'''
    if destination.exists():
        return True, 'already_present'
    request = Request(url, headers={'User-Agent': 'CAFR-research/1.0 (academic research)'})
    try:
        with urlopen(request, timeout=120) as response:
            payload = response.read(max_bytes + 1)
    except (HTTPError, URLError, TimeoutError) as exc:
        return False, f'download_error:{type(exc).__name__}'
    if len(payload) > max_bytes:
        return False, 'download_error:file_too_large'
    if not payload.lstrip().startswith(b'%PDF-'):
        return False, 'download_error:not_a_pdf'
    destination.write_bytes(payload)
    return True, 'downloaded'


def blank_if_none(value: Any) -> str:
    if value is None:
        return ''
    return str(value)


def make_inventory_row(
    record: dict[str, Any], document: dict[str, Any], local_path: str, page_count: str,
    text_searchable: str, downloaded_at: str, verification: str, note: str
) -> dict[str, str]:
    return {
        'record_id': blank_if_none(record.get('record_id')),
        'pilot_batch_id': '',
        'city_name': blank_if_none(record.get('city_name')),
        'state': blank_if_none(record.get('state')),
        'document_fiscal_year_end': blank_if_none(document.get('fiscal_year')),
        'document_title': blank_if_none(document.get('title')),
        'document_type': blank_if_none(document.get('document_type')),
        'document_url': blank_if_none(document.get('document_url')),
        'report_source_type': blank_if_none(document.get('source_type')),
        'source_landing_page_url': blank_if_none(record.get('landing_page_url')),
        'local_pdf_path': local_path,
        'pdf_page_count': page_count,
        'pdf_text_searchable': text_searchable,
        'downloaded_at': downloaded_at,
        'verification_status': verification,
        'is_fy2017_target': str(bool(document.get('is_fy2017_target'))).lower(),
        'is_later_year_fallback': str(bool(document.get('is_later_year_fallback'))).lower(),
        'is_other_available_report': str(bool(document.get('is_other_available_report'))).lower(),
        'inventory_notes': note
    }


def apply_result(
    manifest_record: dict[str, Any], result: dict[str, Any], run_dir: Path,
    download: bool
) -> tuple[dict[str, Any], list[dict[str, str]]]:
    row = dict(manifest_record)
    row['collection_status'] = 'completed'
    row['collection_agent'] = 'openai_batch_api'
    row['collection_completed_at'] = now_utc()
    for field in [
        'city_official_website_url', 'city_official_domain', 'landing_page_url', 'landing_page_domain',
        'landing_page_title', 'landing_page_financial_document_count', 'landing_page_count_scope',
        'landing_page_count_notes', 'report_found', 'report_source_type', 'report_document_type', 'report_title',
        'report_fiscal_year_end', 'report_url', 'verification_status', 'search_queries_used', 'collection_notes'
    ]:
        if field in result:
            row[field] = blank_if_none(result[field])
    docs = result.get('qualifying_documents') or []
    downloaded_later_years = []
    row['later_cafr_download_count'] = '0'
    row['later_cafr_downloaded_years'] = ''
    row['collection_notes'] = (row.get('collection_notes') or '') + (
        (' | citations: ' + '; '.join(result.get('source_citations') or [])) if result.get('source_citations') else ''
    )

    inventory = []
    for document in docs:
        if document.get('document_type') not in QUALIFYING_DOCUMENT_TYPES:
            continue
        if not (
            document.get('is_fy2017_target')
            or document.get('is_later_year_fallback')
            or document.get('is_other_available_report')
        ):
            continue
        year = safe_filename_part(blank_if_none(document.get('fiscal_year')))
        destination = run_dir / 'PDFs' / f"{safe_filename_part(blank_if_none(row['record_id']))}_FY{year}.pdf"
        downloaded_at = ''
        local_path = ''
        page_count = ''
        text_searchable = ''
        verification = blank_if_none(document.get('verification_status'))
        note = blank_if_none(document.get('notes'))
        if download:
            ok, status = download_pdf(blank_if_none(document.get('document_url')), destination)
            note = f'{note} | {status}'.strip(' |')
            if ok:
                local_path = str(destination)
                downloaded_at = now_utc()
                page_count, text_searchable = pdf_details(destination)
                if document.get('is_fy2017_target'):
                    row['local_pdf_path'] = local_path
                    row['pdf_page_count'] = page_count
                    row['pdf_text_searchable'] = text_searchable
                if document.get('is_later_year_fallback'):
                    downloaded_later_years.append(blank_if_none(document.get('fiscal_year')))
        inventory.append(make_inventory_row(
            row, document, local_path, page_count, text_searchable, downloaded_at, verification, note
        ))
    row['later_cafr_download_count'] = str(len(downloaded_later_years))
    row['later_cafr_downloaded_years'] = ';'.join(year for year in downloaded_later_years if year)
    return row, inventory


def write_csv_rows(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    with path.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)


def command_collect(args: argparse.Namespace) -> None:
    run_dir = run_dir_from_args(args)
    state = load_state(run_dir)
    api_key = require_api_key()
    state = update_batch_state(run_dir, state, api_key)
    if state.get('openai_batch_status') not in {'completed', 'cancelled', 'expired'}:
        raise RuntimeError(
            f"Batch status is {state.get('openai_batch_status')}; collection is available after completed, cancelled, or expired."
        )
    if not state.get('output_file_id'):
        raise RuntimeError('Completed batch has no output_file_id.')

    output_path = run_dir / 'raw_outputs' / 'openai_batch_output.jsonl'
    if not output_path.exists():
        output = api_request('GET', f"/files/{state['output_file_id']}/content", api_key=api_key, content_type=None)
        if not isinstance(output, bytes):
            raise RuntimeError('Expected bytes when downloading Batch output.')
        output_path.write_bytes(output)
    if state.get('error_file_id'):
        error_path = run_dir / 'raw_outputs' / 'openai_batch_errors.jsonl'
        if not error_path.exists():
            errors = api_request('GET', f"/files/{state['error_file_id']}/content", api_key=api_key, content_type=None)
            if isinstance(errors, bytes):
                error_path.write_bytes(errors)

    parsed, parse_errors = load_batch_results(output_path)
    if parse_errors:
        (run_dir / 'raw_outputs' / 'parse_errors.json').write_text(json.dumps(parse_errors, indent=2), encoding='utf-8')
        log(f'Warning: {len(parse_errors)} agent-job outputs could not be parsed; see raw_outputs/parse_errors.json')

    full_manifest = pl.read_csv(state['manifest_path'], infer_schema_length=10000, null_values=[''])
    source_records = {str(row['record_id']): row for row in full_manifest.to_dicts()}
    all_rows = []
    all_inventory = []
    for job in state['jobs']:
        if job['job_id'] not in parsed:
            job['status'] = 'error' if any(error.get('job_id') == job['job_id'] for error in parse_errors) else 'missing_output'
            continue
        returned = {str(item.get('record_id', '')): item for item in parsed[job['job_id']].get('records', [])}
        batch_rows = []
        batch_inventory = []
        for record_id in job['record_ids']:
            source = source_records[record_id]
            result = returned.get(record_id)
            if not result:
                missing = dict(source)
                missing['collection_status'] = 'needs_review'
                missing['collection_agent'] = 'openai_batch_api'
                missing['collection_notes'] = 'No structured result returned for this record.'
                batch_rows.append(missing)
                continue
            collected_row, inventory_rows = apply_result(source, result, run_dir, download=not args.no_download)
            batch_rows.append(collected_row)
            batch_inventory.extend(inventory_rows)
        write_csv_rows(Path(job['result_path']), batch_rows, full_manifest.columns)
        inventory_fields = list(make_inventory_row({}, {}, '', '', '', '', '', '').keys())
        write_csv_rows(Path(job['inventory_path']), batch_inventory, inventory_fields)
        all_rows.extend(batch_rows)
        all_inventory.extend(batch_inventory)
        job['status'] = 'collected'

    write_csv_rows(run_dir / 'results' / '2017_point_in_time_cafr_collection_results.csv', all_rows, full_manifest.columns)
    inventory_fields = list(make_inventory_row({}, {}, '', '', '', '', '', '').keys())
    write_csv_rows(run_dir / 'results' / 'cafr_document_inventory.csv', all_inventory, inventory_fields)
    usage_rows = tool_usage_by_job(output_path, state['jobs'])
    usage_fields = [
        'job_id', 'record_ids', 'record_count', 'response_status', 'web_tool_output_count',
        'web_search_action_count', 'web_open_page_action_count', 'web_find_in_page_action_count',
        'embedded_search_query_count', 'input_tokens', 'cached_input_tokens', 'output_tokens',
        'reasoning_tokens', 'total_tokens'
    ]
    write_csv_rows(run_dir / 'results' / 'web_tool_usage_by_job.csv', usage_rows, usage_fields)
    state['collected_at'] = now_utc()
    save_state(run_dir, state)
    log(progress_summary(state))
    log(
        f"Wrote {len(all_rows):,} collected manifest rows, {len(all_inventory):,} qualifying document-inventory rows, "
        f"and {len(usage_rows):,} per-job web-tool usage rows."
    )


#%%
def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description='OpenAI Batch API CAFR/ACFR collection runner.')
    parser.add_argument('--run-id', required=True, help='New/existing run directory name below Data/CAFR Collection/API Runs.')
    parser.add_argument('--runs-dir', default=str(default_runs_dir), help='Directory holding run folders.')
    subparsers = parser.add_subparsers(dest='command', required=True)

    prepare = subparsers.add_parser('prepare', help='Create city batches and Batch API JSONL input.')
    prepare.add_argument('--manifest', default=str(default_manifest_path))
    prepare.add_argument(
        '--cd-hints', default=str(default_cd_hints_path),
        help='City-level audited/ACFR Continuing Disclosure routing-hints CSV supplied to agents for conditional EMMA lookup.'
    )
    prepare.add_argument(
        '--max-cd-hints-per-city', type=int, default=12,
        help='Maximum audited/ACFR Continuing Disclosure filing hints attached to each city request (default: 12).'
    )
    prepare.add_argument('--cities-per-job', type=int, default=10)
    prepare.add_argument('--limit', type=int, help='Prepare only the first N rows for a small test run.')
    prepare.add_argument(
        '--only-missing-report', action='store_true',
        help='Keep only rows whose report_found value is no; use with a prior collected-results CSV for a retry.'
    )
    prepare.add_argument('--model', default=DEFAULT_MODEL, help=f'OpenAI model to use (default: {DEFAULT_MODEL}).')
    prepare.add_argument(
        '--max-tool-calls', type=int,
        help='Maximum built-in tool calls per Responses request (1-20). Use one city per job to make this a per-city cap.'
    )
    prepare.add_argument(
        '--search-context-size', choices=['low', 'medium', 'high'], default='medium',
        help='Amount of search-result context supplied to the model (default: medium).'
    )
    prepare.add_argument(
        '--reasoning-effort', choices=['low', 'medium', 'high'],
        help='Optional reasoning depth; low is appropriate for a tightly bounded retry.'
    )

    submit = subparsers.add_parser('submit', help='Upload the prepared JSONL and create the Batch API job.')
    submit.add_argument('--confirm-submit', action='store_true', help='Required acknowledgement that this creates paid API work.')

    status = subparsers.add_parser('status', help='Display progress and, by default, refresh it from OpenAI.')
    status.add_argument('--local', action='store_true', help='Do not call OpenAI; display the last saved state only.')

    watch = subparsers.add_parser('watch', help='Poll until the Batch API job reaches a terminal state.')
    watch.add_argument('--local', action='store_true', help='Invalid for useful watching; retained for command symmetry.')
    watch.add_argument('--sleep-seconds', type=int, default=300)

    collect = subparsers.add_parser('collect', help='Download completed output, write manifests, and retrieve qualifying PDFs.')
    collect.add_argument('--no-download', action='store_true', help='Write research results but do not download PDFs.')
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.command == 'prepare':
        if args.cities_per_job < 1:
            raise SystemExit('--cities-per-job must be at least 1.')
        if args.max_tool_calls is not None and not 1 <= args.max_tool_calls <= 20:
            raise SystemExit('--max-tool-calls must be between 1 and 20.')
        if args.max_cd_hints_per_city < 1:
            raise SystemExit('--max-cd-hints-per-city must be at least 1.')
        command_prepare(args)
    elif args.command == 'submit':
        command_submit(args)
    elif args.command == 'status':
        command_status(args)
    elif args.command == 'watch':
        if args.local:
            raise SystemExit('watch requires the OpenAI API; omit --local.')
        command_watch(args)
    elif args.command == 'collect':
        command_collect(args)


if __name__ == '__main__':
    main()
