#!/usr/bin/env python3
"""Create city-level EMMA routing hints from Mergent CUSIPs and CD filings.

The resulting CSV is deliberately a routing file, not a CAFR file: it contains
only disclosure filings whose category suggests audited statements/ACFR.  EMMA
document URLs are not present in the source data and must still be verified by
the collection agent.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import duckdb
import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
DEFAULT_MANIFEST = ROOT / 'Data/CAFR Collection/2017_point_in_time_cafr_collection_manifest.csv'
DEFAULT_MERGENT = ROOT / 'Data/Mergent/Clean/260917_city_cusiplevel_finsample_allbonds.dta'
DEFAULT_DISCLOSURES = ROOT / 'Data/Continuing Disclosure/cleaned_daily_disclosure_data.csv'
DEFAULT_OUTPUT = ROOT / 'Data/CAFR Collection/continuing_disclosure_emma_hints.csv'


def build_city_cusip_map(manifest_path: Path, mergent_path: Path) -> pd.DataFrame:
    manifest = pd.read_csv(manifest_path, dtype={'record_id': 'string', 'state': 'string', 'mergent_issuer': 'string'})
    required = {'record_id', 'state', 'mergent_issuer'}
    missing = required.difference(manifest.columns)
    if missing:
        raise ValueError(f'Manifest is missing required fields: {sorted(missing)}')
    manifest = manifest[['record_id', 'state', 'mergent_issuer']].copy()
    manifest['state'] = manifest['state'].str.strip().str.upper()
    manifest['mergent_issuer'] = manifest['mergent_issuer'].str.strip().str.upper()

    mergent = pd.read_stata(
        mergent_path,
        columns=['state', 'seed_issuer', 'cusip'],
        convert_categoricals=False,
    )
    mergent = mergent.dropna(subset=['state', 'seed_issuer', 'cusip']).copy()
    mergent['state'] = mergent['state'].astype(str).str.strip().str.upper()
    mergent['seed_issuer'] = mergent['seed_issuer'].astype(str).str.strip().str.upper()
    mergent['cusip_c'] = mergent['cusip'].astype(str).str.strip().str.upper()
    mergent = mergent[mergent['cusip_c'].str.fullmatch(r'[0-9A-Z]{9}', na=False)]

    mapping = manifest.merge(
        mergent[['state', 'seed_issuer', 'cusip_c']],
        left_on=['state', 'mergent_issuer'],
        right_on=['state', 'seed_issuer'],
        how='left',
        validate='one_to_many',
    )
    unmatched = mapping.loc[mapping['cusip_c'].isna(), 'record_id'].nunique()
    if unmatched:
        raise ValueError(f'{unmatched:,} manifest cities could not be matched to a Mergent CUSIP.')
    return mapping[['record_id', 'cusip_c']].drop_duplicates().reset_index(drop=True)


def main() -> None:
    parser = argparse.ArgumentParser(description='Prepare EMMA routing hints for CAFR collection.')
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument('--mergent', type=Path, default=DEFAULT_MERGENT)
    parser.add_argument('--disclosures', type=Path, default=DEFAULT_DISCLOSURES)
    parser.add_argument('--output', type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    for path in (args.manifest, args.mergent, args.disclosures):
        if not path.exists():
            raise FileNotFoundError(path)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    city_cusips = build_city_cusip_map(args.manifest, args.mergent)
    print(f'Mapped {city_cusips.record_id.nunique():,} cities to {len(city_cusips):,} distinct city-CUSIP links.')

    con = duckdb.connect()
    con.register('city_cusips', city_cusips)
    # Filings can be repeated for every maturity CUSIP.  One row per city,
    # submission, date, and category preserves the routing information while
    # retaining a representative CUSIP and the number of matched CUSIPs.
    query = """
        SELECT
            m.record_id,
            MIN(d.cusip_c) AS cusip,
            d.submissionidentifier AS submission_identifier,
            CAST(d.disclosure_event_date AS VARCHAR) AS disclosure_event_date,
            d.financialoperatingdisclosurecategory AS disclosure_category,
            COUNT(DISTINCT d.cusip_c) AS matched_cusip_count,
            MAX(d.machine_readable) AS machine_readable,
            MAX(d.pdf_filesize) AS pdf_filesize
        FROM read_csv_auto(?, header = true, nullstr = 'NA') AS d
        INNER JOIN city_cusips AS m ON d.cusip_c = m.cusip_c
        WHERE
            lower(coalesce(d.financialoperatingdisclosurecategory, '')) LIKE '%audited%'
            OR lower(coalesce(d.financialoperatingdisclosurecategory, '')) LIKE '%acfr%'
            OR lower(coalesce(d.financialoperatingdisclosurecategory, '')) LIKE '%cafr%'
        GROUP BY
            m.record_id,
            d.submissionidentifier,
            d.disclosure_event_date,
            d.financialoperatingdisclosurecategory
        ORDER BY m.record_id, d.disclosure_event_date DESC, d.submissionidentifier
    """
    hints = con.execute(query, [str(args.disclosures)]).fetchdf()
    if hints.empty:
        raise RuntimeError('No audited/ACFR-type Continuing Disclosure hints matched the CAFR manifest.')
    hints.to_csv(args.output, index=False)

    covered = hints.record_id.nunique()
    print(
        f'Wrote {len(hints):,} deduplicated audited/ACFR-type filing hints for '
        f'{covered:,} of {city_cusips.record_id.nunique():,} cities to {args.output}'
    )


if __name__ == '__main__':
    main()
