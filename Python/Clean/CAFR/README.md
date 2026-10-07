# CAFR/ACFR OpenAI Batch runner

`run_cafr_openai_batch.py` turns the 2,031-city CAFR manifest into 10-city web-research jobs, submits those jobs through the OpenAI Batch API, monitors the aggregate job, and materializes the completed research into CSVs and qualifying CAFR/ACFR PDFs.

It starts with official city websites and document portals. It does not programmatically query or download from EMMA/MSRB, but an agent may use an individual EMMA lookup for a FY2017 target when official city material shows that the report was filed there. It downloads a file only when the research result labels it as a CAFR or ACFR and the local downloader verifies PDF bytes.

The API key is read only from `OPENAI_API_KEY`; it is never written to the run state, manifest, JSONL, or log.

## First run

From the project root, prepare a full run. This is free and creates 204 ten-city agent jobs:

```zsh
python3 Code/Python/Clean/CAFR/run_cafr_openai_batch.py \
  --run-id cafr_full_20260922 prepare
```

Inspect the generated JSONL under `Data/CAFR Collection/API Runs/cafr_full_20260922/`. A small paid pilot can instead use `--limit 20` (and a new run ID).

## Low-cost retry of missing reports

The first run had no tool-call cap and used medium search context. For a bounded retry, use the collected-results CSV as the manifest, retain only `report_found = no` rows, give each city its own request, allow at most one web-search action, use low search context, and use low reasoning. `max_tool_calls` is per API request, so `--cities-per-job 1` is what makes the cap apply per city.

```zsh
python3 Code/Python/Clean/CAFR/run_cafr_openai_batch.py \
  --run-id cafr_missing_retry_lowcost_20260923 prepare \
  --manifest 'Data/CAFR Collection/API Runs/cafr_full_20260922/results/2017_point_in_time_cafr_collection_results.csv' \
  --only-missing-report \
  --cities-per-job 1 \
  --max-tool-calls 1 \
  --search-context-size low \
  --reasoning-effort low
```

This only prepares local files. Inspect the job count and a few JSONL requests before any paid submission. A second, more thorough pass can then be limited to the `needs_review` cases from this retry, using two or three tool calls per city.

In a terminal where your API key is available, submit the prepared work. The explicit confirmation prevents an accidental paid submission:

```zsh
export OPENAI_API_KEY='...'
python3 Code/Python/Clean/CAFR/run_cafr_openai_batch.py \
  --run-id cafr_full_20260922 submit --confirm-submit
```

## Monitor and collect

The Batch API has a 24-hour completion window. While running it exposes aggregate request counts, rather than city-level results.

```zsh
python3 Code/Python/Clean/CAFR/run_cafr_openai_batch.py \
  --run-id cafr_full_20260922 status

# Optional: poll every five minutes until it completes.
python3 Code/Python/Clean/CAFR/run_cafr_openai_batch.py \
  --run-id cafr_full_20260922 watch --sleep-seconds 300
```

When the status is `completed`, collect results and PDFs:

```zsh
python3 Code/Python/Clean/CAFR/run_cafr_openai_batch.py \
  --run-id cafr_full_20260922 collect
```

Use `collect --no-download` first when you want to inspect the research results before any website downloads.

If you cancel a batch to cap spending, wait until its status becomes `cancelled` and then use the same `collect` command. The runner will materialize the request outputs that finished before cancellation and mark the remaining batch manifests as missing output.

Outputs remain isolated below the run folder:

- `batch_manifests/`: one original-manifest copy per 10-city agent job.
- `raw_outputs/`: returned Batch JSONL and any parsing errors.
- `results/2017_point_in_time_cafr_collection_results.csv`: combined collection results.
- `results/cafr_document_inventory.csv`: one row per qualifying CAFR/ACFR available on the official archive, including reports before and after FY2017.
- `PDFs/`: successfully validated PDFs, named `<record_id>_FY<year>.pdf`.

The original `2017_point_in_time_cafr_collection_manifest.csv` is never changed.

## Important limitation

This is a web-search research pipeline, not a browser-controlled Codex agent. It can locate official webpages and report/direct-download candidate PDFs, but a dynamic website can make a landing-page document count uncertain. The prompt requires the agent to leave uncertain counts blank and explain why, rather than invent a number. Review `needs_review`, `not_found`, and failed-download cases before analysis.
