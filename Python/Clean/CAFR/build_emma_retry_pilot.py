#!/usr/bin/env python3
"""Build a balanced, CD-hint-covered pilot for the bounded EMMA retry."""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
DEFAULT_RESULTS = ROOT / 'Data/CAFR Collection/API Runs/cafr_full_20260922/results/2017_point_in_time_cafr_collection_results.csv'
DEFAULT_HINTS = ROOT / 'Data/CAFR Collection/continuing_disclosure_emma_hints.csv'
DEFAULT_EXCLUDE = ROOT / 'Data/CAFR Collection/API Runs/cafr_missing_retry_pilot_20260923/results/2017_point_in_time_cafr_collection_results.csv'
DEFAULT_OUTPUT_DIR = ROOT / 'Data/CAFR Collection/Pilot 2 EMMA Retry'


def main() -> None:
    parser = argparse.ArgumentParser(description='Create a stratified CAFR retry pilot with EMMA routing hints.')
    parser.add_argument('--results', type=Path, default=DEFAULT_RESULTS)
    parser.add_argument('--hints', type=Path, default=DEFAULT_HINTS)
    parser.add_argument('--exclude', type=Path, default=DEFAULT_EXCLUDE)
    parser.add_argument('--output-dir', type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument('--seed', type=int, default=20260927)
    parser.add_argument('--cities-per-population-stratum', type=int, default=4)
    args = parser.parse_args()

    results = pd.read_csv(args.results, dtype={'record_id': 'string', 'state': 'string'})
    hints = pd.read_csv(args.hints, usecols=['record_id'], dtype={'record_id': 'string'}).drop_duplicates()
    exclude = pd.read_csv(args.exclude, usecols=['record_id'], dtype={'record_id': 'string'}).drop_duplicates()

    candidates = results.loc[results['report_found'].fillna('').str.lower().eq('no')].copy()
    candidates = candidates.merge(hints.assign(has_cd_hint=True), on='record_id', how='inner')
    candidates = candidates.loc[~candidates['record_id'].isin(exclude['record_id'])].copy()
    candidates['census_population'] = pd.to_numeric(candidates['census_population'], errors='coerce')
    candidates = candidates.dropna(subset=['census_population', 'state'])
    candidates['population_stratum'] = pd.qcut(
        candidates['census_population'], q=5, labels=['Q1', 'Q2', 'Q3', 'Q4', 'Q5'], duplicates='drop'
    )

    selected = []
    used_states: set[str] = set()
    for stratum in ['Q1', 'Q2', 'Q3', 'Q4', 'Q5']:
        pool = candidates.loc[candidates['population_stratum'].astype(str).eq(stratum)].sample(
            frac=1, random_state=args.seed + len(selected)
        )
        available = pool.loc[~pool['state'].isin(used_states)]
        chosen = available.groupby('state', sort=False, as_index=False).head(1).head(args.cities_per_population_stratum)
        if len(chosen) < args.cities_per_population_stratum:
            chosen = pool.groupby('state', sort=False, as_index=False).head(1).head(args.cities_per_population_stratum)
        selected.append(chosen)
        used_states.update(chosen['state'].tolist())

    pilot = pd.concat(selected, ignore_index=True)
    if pilot['record_id'].duplicated().any():
        raise RuntimeError('Pilot selection unexpectedly contains duplicate cities.')
    expected = args.cities_per_population_stratum * 5
    if len(pilot) != expected:
        raise RuntimeError(f'Expected {expected} cities but selected {len(pilot)}.')

    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output_dir / '2017_cafr_emma_retry_pilot_manifest.csv'
    summary_path = args.output_dir / 'selection_summary.csv'
    pilot.drop(columns=['has_cd_hint', 'population_stratum']).to_csv(manifest_path, index=False)
    (
        pilot.groupby('population_stratum', observed=False)
        .agg(cities=('record_id', 'size'), states=('state', 'nunique'), min_population=('census_population', 'min'),
             median_population=('census_population', 'median'), max_population=('census_population', 'max'))
        .reset_index()
        .to_csv(summary_path, index=False)
    )
    print(f'Wrote {len(pilot)} cities to {manifest_path}')
    print(pilot[['record_id', 'city_name', 'state', 'census_population', 'population_stratum']].to_string(index=False))


if __name__ == '__main__':
    main()
