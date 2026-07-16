"""
Build issue-level underwriter measures from raw Mergent agent tables.

Inputs:
    Data/Mergent/Raw/ISSUAGNT.DLM
    Data/Mergent/Raw/AGENT.DLM
    Data/Mergent/Raw/ISSUINFO.DLM

Outputs:
    Data/Mergent/Underwriters/issue_underwriter_measures.csv
    Data/Mergent/Underwriters/underwriter_year_rankings.csv
    Data/Mergent/Underwriters/underwriter_state_year_rankings.csv
    Data/Mergent/Underwriters/underwriter_build_diagnostics.csv

The main issue-level file is intended to merge onto clean Mergent files by
issue_id. Ranking variables are based on primary underwriters: lead underwriters
when Mergent has LEADU, otherwise UNDER roles.
"""

from pathlib import Path
from typing import Optional, Union

import numpy as np
import pandas as pd


ROOT = Path('/Users/kmunevar/Dropbox/Voting on Bonds')
RAW_DIR = ROOT / 'Data' / 'Mergent' / 'Raw'
OUT_DIR = ROOT / 'Data' / 'Mergent' / 'Underwriters'
OUT_DIR.mkdir(parents=True, exist_ok=True)

ISSUAGNT_FILE = RAW_DIR / 'ISSUAGNT.DLM'
AGENT_FILE = RAW_DIR / 'AGENT.DLM'
ISSUINFO_FILE = RAW_DIR / 'ISSUINFO.DLM'

ISSUE_OUTPUT = OUT_DIR / 'issue_underwriter_measures.csv'
NATIONAL_RANKING_OUTPUT = OUT_DIR / 'underwriter_year_rankings.csv'
STATE_RANKING_OUTPUT = OUT_DIR / 'underwriter_state_year_rankings.csv'
DIAGNOSTICS_OUTPUT = OUT_DIR / 'underwriter_build_diagnostics.csv'

ROLE_LABELS = {
    'LEADU': 'Lead Underwriter',
    'UNDER': 'Underwriter',
    'PLACE': 'Placement Agent',
    'COMG1': 'Co Manager-1',
    'COMG2': 'Co Manager-2',
    'COMG3': 'Co Manager-3',
    'COMG4': 'Co Manager-4',
    'COMG5': 'Co Manager-5',
    'COMG6': 'Co Manager-6',
    'COMG7': 'Co Manager-7',
    'COMG8': 'Co Manager-8',
    'SYNME': 'Syndicate Member',
}

UNDERWRITER_ROLES = set(ROLE_LABELS)
CO_MANAGER_ROLES = {f'COMG{i}' for i in range(1, 9)}


def read_pipe(path: Path, usecols: Optional[list[str]] = None) -> pd.DataFrame:
    with path.open('r', encoding='utf-8', errors='replace') as file:
        header = file.readline().rstrip('\n\r').split('|')

    header_positions = {
        name: position
        for position, name in enumerate(header)
        if name
    }
    selected_cols = usecols if usecols is not None else list(header_positions)
    missing_cols = [col for col in selected_cols if col not in header_positions]
    if missing_cols:
        raise ValueError(f'{path} is missing expected columns: {missing_cols}')

    selected_positions = [header_positions[col] for col in selected_cols]

    return pd.read_csv(
        path,
        sep='|',
        dtype=str,
        header=0,
        usecols=selected_positions,
        keep_default_na=False,
        na_values=[''],
        engine='python',
        on_bad_lines='warn',
    )


def normalize_text(series: pd.Series) -> pd.Series:
    return (
        series.fillna('')
        .astype(str)
        .str.upper()
        .str.replace(r'\s+', ' ', regex=True)
        .str.strip()
        .replace('', np.nan)
    )


def join_unique(values: pd.Series) -> Union[str, float]:
    clean = sorted({str(value) for value in values.dropna() if str(value).strip()})
    if not clean:
        return np.nan
    return '; '.join(clean)


def grouped_join(df: pd.DataFrame, mask_col: str, value_col: str, output_col: str) -> pd.DataFrame:
    subset = df.loc[df[mask_col], ['issue_id', value_col]].dropna(subset=[value_col])
    if subset.empty:
        return pd.DataFrame(columns=['issue_id', output_col])
    return (
        subset.groupby('issue_id', as_index=False)[value_col]
        .agg(join_unique)
        .rename(columns={value_col: output_col})
    )


def grouped_nunique(df: pd.DataFrame, mask_col: str, value_col: str, output_col: str) -> pd.DataFrame:
    subset = df.loc[df[mask_col], ['issue_id', value_col]].dropna(subset=[value_col])
    if subset.empty:
        return pd.DataFrame(columns=['issue_id', output_col])
    return (
        subset.groupby('issue_id', as_index=False)[value_col]
        .nunique()
        .rename(columns={value_col: output_col})
    )


def add_rank_flags(df: pd.DataFrame, prefix: str) -> pd.DataFrame:
    out = df.copy()
    out[f'{prefix}_top3_underwriter'] = out[f'{prefix}_amount_rank'].le(3).astype('int8')
    out[f'{prefix}_top5_underwriter'] = out[f'{prefix}_amount_rank'].le(5).astype('int8')
    out[f'{prefix}_top10_underwriter'] = out[f'{prefix}_amount_rank'].le(10).astype('int8')
    return out


def main() -> None:
    print('Loading raw Mergent issue-agent links...')
    issue_agents = read_pipe(ISSUAGNT_FILE)
    issue_agents = issue_agents.rename(
        columns={
            'issue_id_l': 'issue_id',
            'agent_id_l': 'agent_id',
            'agent_role_c': 'agent_role',
        }
    )
    issue_agents['issue_id'] = pd.to_numeric(issue_agents['issue_id'], errors='coerce').astype('Int64')
    issue_agents['agent_id'] = pd.to_numeric(issue_agents['agent_id'], errors='coerce').astype('Int64')
    issue_agents['agent_role'] = normalize_text(issue_agents['agent_role'])
    issue_agents = issue_agents.dropna(subset=['issue_id', 'agent_id', 'agent_role'])

    print('Loading raw Mergent agent names...')
    agents = read_pipe(AGENT_FILE)
    agents = agents.rename(columns={'agent_id_l': 'agent_id', 'legal_name_c': 'agent_name'})
    agents['agent_id'] = pd.to_numeric(agents['agent_id'], errors='coerce').astype('Int64')
    agents['agent_name'] = normalize_text(agents['agent_name'])
    agents = agents.dropna(subset=['agent_id']).drop_duplicates('agent_id', keep='first')

    print('Loading raw Mergent issue information...')
    issues = read_pipe(
        ISSUINFO_FILE,
        usecols=[
            'issue_id_l',
            'issuer_long_name_c',
            'state_c',
            'issue_description_c',
            'offering_type_c',
            'total_offering_amount_f',
            'offering_date_d',
            'gross_spread_f',
        ],
    )
    issues = issues.rename(
        columns={
            'issue_id_l': 'issue_id',
            'issuer_long_name_c': 'issuer_long_name',
            'state_c': 'state',
            'issue_description_c': 'issue_description',
            'offering_type_c': 'offering_type',
            'total_offering_amount_f': 'issue_offering_amount',
            'offering_date_d': 'offering_date',
            'gross_spread_f': 'gross_spread',
        }
    )
    issues['issue_id'] = pd.to_numeric(issues['issue_id'], errors='coerce').astype('Int64')
    issues['state'] = normalize_text(issues['state'])
    issues['issuer_long_name'] = normalize_text(issues['issuer_long_name'])
    issues['issue_description'] = normalize_text(issues['issue_description'])
    issues['offering_type'] = normalize_text(issues['offering_type'])
    issues['issue_offering_amount'] = pd.to_numeric(issues['issue_offering_amount'], errors='coerce')
    issues['gross_spread'] = pd.to_numeric(issues['gross_spread'], errors='coerce')
    issues['offering_date'] = pd.to_datetime(issues['offering_date'], format='%Y%m%d', errors='coerce')
    issues['offering_year'] = issues['offering_date'].dt.year.astype('Int64')
    issues = issues.dropna(subset=['issue_id']).drop_duplicates('issue_id', keep='first')

    print('Merging agent names...')
    issue_agents = issue_agents.merge(agents, on='agent_id', how='left')
    issue_agents['agent_role_label'] = issue_agents['agent_role'].map(ROLE_LABELS)

    print('Filtering underwriter roles...')
    underwriters = issue_agents.loc[
        issue_agents['agent_role'].isin(UNDERWRITER_ROLES)
    ].copy()

    issue_has_lead = (
        underwriters.loc[underwriters['agent_role'].eq('LEADU'), ['issue_id']]
        .drop_duplicates()
        .assign(has_lead_underwriter=1)
    )
    underwriters = underwriters.merge(issue_has_lead, on='issue_id', how='left')
    underwriters['has_lead_underwriter'] = underwriters['has_lead_underwriter'].fillna(0).astype('int8')
    underwriters['primary_underwriter'] = (
        underwriters['agent_role'].eq('LEADU')
        | (underwriters['agent_role'].eq('UNDER') & underwriters['has_lead_underwriter'].eq(0))
    )
    underwriters['is_lead_underwriter'] = underwriters['agent_role'].eq('LEADU')
    underwriters['is_primary_underwriter'] = underwriters['primary_underwriter']
    underwriters['is_co_manager'] = underwriters['agent_role'].isin(CO_MANAGER_ROLES)
    underwriters['is_syndicate_member'] = underwriters['agent_role'].eq('SYNME')
    underwriters['is_placement_agent'] = underwriters['agent_role'].eq('PLACE')
    underwriters['is_underwriter_role'] = True

    print('Aggregating issue-level underwriter names and counts...')
    issue_underwriter_summary = underwriters[['issue_id']].drop_duplicates()
    for piece in [
        grouped_join(underwriters, 'is_lead_underwriter', 'agent_id', 'lead_underwriter_ids'),
        grouped_join(underwriters, 'is_lead_underwriter', 'agent_name', 'lead_underwriter_names'),
        grouped_join(underwriters, 'is_underwriter_role', 'agent_id', 'underwriter_ids'),
        grouped_join(underwriters, 'is_underwriter_role', 'agent_name', 'underwriter_names'),
        grouped_join(underwriters, 'is_primary_underwriter', 'agent_id', 'primary_underwriter_ids'),
        grouped_join(underwriters, 'is_primary_underwriter', 'agent_name', 'primary_underwriter_names'),
        grouped_nunique(underwriters, 'is_underwriter_role', 'agent_id', 'n_underwriter_agents'),
        grouped_nunique(underwriters, 'is_lead_underwriter', 'agent_id', 'n_lead_underwriters'),
        grouped_nunique(underwriters, 'is_primary_underwriter', 'agent_id', 'n_primary_underwriters'),
        grouped_nunique(underwriters, 'is_co_manager', 'agent_id', 'n_co_managers'),
        grouped_nunique(underwriters, 'is_syndicate_member', 'agent_id', 'n_syndicate_members'),
    ]:
        issue_underwriter_summary = issue_underwriter_summary.merge(piece, on='issue_id', how='left')

    issue_role_flags = (
        underwriters.groupby('issue_id', as_index=False)
        .agg(
            has_lead_underwriter=('is_lead_underwriter', 'max'),
            has_placement_agent=('is_placement_agent', 'max'),
        )
    )
    issue_underwriter_summary = issue_underwriter_summary.merge(issue_role_flags, on='issue_id', how='left')

    issue_level = issues.merge(issue_underwriter_summary, on='issue_id', how='left')
    count_cols = [
        'n_underwriter_agents',
        'n_lead_underwriters',
        'n_primary_underwriters',
        'n_co_managers',
        'n_syndicate_members',
        'has_lead_underwriter',
        'has_placement_agent',
    ]
    issue_level[count_cols] = issue_level[count_cols].fillna(0).astype('int64')
    issue_level['has_primary_underwriter'] = issue_level['n_primary_underwriters'].gt(0).astype('int8')

    print('Computing annual national and state-year underwriter rankings...')
    primary = underwriters.loc[underwriters['primary_underwriter']].copy()
    primary = primary.merge(
        issues[['issue_id', 'state', 'offering_year', 'issue_offering_amount']],
        on='issue_id',
        how='left',
    )
    primary = primary.dropna(subset=['offering_year', 'agent_id'])
    primary['n_primary_underwriters'] = primary.groupby('issue_id')['agent_id'].transform('nunique')
    primary['underwriter_issue_credit'] = 1 / primary['n_primary_underwriters']
    primary['underwriter_amount_credit'] = (
        primary['issue_offering_amount'].fillna(0) / primary['n_primary_underwriters']
    )

    annual_totals = (
        issues.dropna(subset=['offering_year'])
        .groupby('offering_year', as_index=False)
        .agg(
            national_total_issues=('issue_id', 'nunique'),
            national_total_amount=('issue_offering_amount', 'sum'),
        )
    )
    national_rankings = (
        primary.groupby(['offering_year', 'agent_id', 'agent_name'], as_index=False)
        .agg(
            national_underwriter_issue_credit=('underwriter_issue_credit', 'sum'),
            national_underwriter_amount_credit=('underwriter_amount_credit', 'sum'),
            national_underwriter_issues=('issue_id', 'nunique'),
        )
        .merge(annual_totals, on='offering_year', how='left')
    )
    national_rankings['national_underwriter_amount_share'] = (
        national_rankings['national_underwriter_amount_credit']
        / national_rankings['national_total_amount'].replace({0: np.nan})
    )
    national_rankings['national_underwriter_issue_share'] = (
        national_rankings['national_underwriter_issue_credit']
        / national_rankings['national_total_issues'].replace({0: np.nan})
    )
    national_rankings['national_amount_rank'] = (
        national_rankings.groupby('offering_year')['national_underwriter_amount_credit']
        .rank(method='min', ascending=False)
        .astype('Int64')
    )
    national_rankings = add_rank_flags(national_rankings, 'national')

    state_totals = (
        issues.dropna(subset=['offering_year', 'state'])
        .groupby(['offering_year', 'state'], as_index=False)
        .agg(
            state_total_issues=('issue_id', 'nunique'),
            state_total_amount=('issue_offering_amount', 'sum'),
        )
    )
    state_rankings = (
        primary.dropna(subset=['state'])
        .groupby(['offering_year', 'state', 'agent_id', 'agent_name'], as_index=False)
        .agg(
            state_underwriter_issue_credit=('underwriter_issue_credit', 'sum'),
            state_underwriter_amount_credit=('underwriter_amount_credit', 'sum'),
            state_underwriter_issues=('issue_id', 'nunique'),
        )
        .merge(state_totals, on=['offering_year', 'state'], how='left')
    )
    state_rankings['state_underwriter_amount_share'] = (
        state_rankings['state_underwriter_amount_credit']
        / state_rankings['state_total_amount'].replace({0: np.nan})
    )
    state_rankings['state_underwriter_issue_share'] = (
        state_rankings['state_underwriter_issue_credit']
        / state_rankings['state_total_issues'].replace({0: np.nan})
    )
    state_rankings['state_amount_rank'] = (
        state_rankings.groupby(['offering_year', 'state'])['state_underwriter_amount_credit']
        .rank(method='min', ascending=False)
        .astype('Int64')
    )
    state_rankings = add_rank_flags(state_rankings, 'state')

    issue_primary_agents = (
        primary[['issue_id', 'agent_id', 'offering_year', 'state']]
        .drop_duplicates()
        .merge(
            national_rankings[
                [
                    'offering_year',
                    'agent_id',
                    'national_underwriter_amount_share',
                    'national_underwriter_issue_share',
                    'national_amount_rank',
                    'national_top3_underwriter',
                    'national_top5_underwriter',
                    'national_top10_underwriter',
                ]
            ],
            on=['offering_year', 'agent_id'],
            how='left',
        )
        .merge(
            state_rankings[
                [
                    'offering_year',
                    'state',
                    'agent_id',
                    'state_underwriter_amount_share',
                    'state_underwriter_issue_share',
                    'state_amount_rank',
                    'state_top3_underwriter',
                    'state_top5_underwriter',
                    'state_top10_underwriter',
                ]
            ],
            on=['offering_year', 'state', 'agent_id'],
            how='left',
        )
    )

    issue_rank_measures = (
        issue_primary_agents.groupby('issue_id', as_index=False)
        .agg(
            primary_underwriter_national_amount_share_max=('national_underwriter_amount_share', 'max'),
            primary_underwriter_national_issue_share_max=('national_underwriter_issue_share', 'max'),
            primary_underwriter_national_best_rank=('national_amount_rank', 'min'),
            primary_underwriter_national_top3=('national_top3_underwriter', 'max'),
            primary_underwriter_national_top5=('national_top5_underwriter', 'max'),
            primary_underwriter_national_top10=('national_top10_underwriter', 'max'),
            primary_underwriter_state_amount_share_max=('state_underwriter_amount_share', 'max'),
            primary_underwriter_state_issue_share_max=('state_underwriter_issue_share', 'max'),
            primary_underwriter_state_best_rank=('state_amount_rank', 'min'),
            primary_underwriter_state_top3=('state_top3_underwriter', 'max'),
            primary_underwriter_state_top5=('state_top5_underwriter', 'max'),
            primary_underwriter_state_top10=('state_top10_underwriter', 'max'),
        )
    )

    issue_level = issue_level.merge(issue_rank_measures, on='issue_id', how='left')

    flag_cols = [
        'primary_underwriter_national_top3',
        'primary_underwriter_national_top5',
        'primary_underwriter_national_top10',
        'primary_underwriter_state_top3',
        'primary_underwriter_state_top5',
        'primary_underwriter_state_top10',
    ]
    issue_level[flag_cols] = issue_level[flag_cols].fillna(0).astype('int8')

    diagnostics = pd.DataFrame(
        [
            {'metric': 'raw_issue_agent_rows', 'value': len(issue_agents)},
            {'metric': 'raw_issue_rows', 'value': len(issues)},
            {'metric': 'issues_with_any_underwriter_role', 'value': int(issue_level['n_underwriter_agents'].gt(0).sum())},
            {'metric': 'issues_with_lead_underwriter', 'value': int(issue_level['has_lead_underwriter'].sum())},
            {'metric': 'issues_with_primary_underwriter', 'value': int(issue_level['has_primary_underwriter'].sum())},
            {'metric': 'primary_underwriter_issue_agent_rows', 'value': len(primary)},
            {'metric': 'national_underwriter_year_rows', 'value': len(national_rankings)},
            {'metric': 'state_underwriter_year_rows', 'value': len(state_rankings)},
            {'metric': 'min_offering_year', 'value': int(issues['offering_year'].min())},
            {'metric': 'max_offering_year', 'value': int(issues['offering_year'].max())},
        ]
    )

    print('Writing outputs...')
    issue_level.to_csv(ISSUE_OUTPUT, index=False)
    national_rankings.to_csv(NATIONAL_RANKING_OUTPUT, index=False)
    state_rankings.to_csv(STATE_RANKING_OUTPUT, index=False)
    diagnostics.to_csv(DIAGNOSTICS_OUTPUT, index=False)

    print(f'Wrote {ISSUE_OUTPUT}')
    print(f'Wrote {NATIONAL_RANKING_OUTPUT}')
    print(f'Wrote {STATE_RANKING_OUTPUT}')
    print(f'Wrote {DIAGNOSTICS_OUTPUT}')


if __name__ == '__main__':
    main()
