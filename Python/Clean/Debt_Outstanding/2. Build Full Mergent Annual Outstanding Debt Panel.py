"""Build annual end-of-year outstanding debt for every Mergent city issuer.

This panel is the shared source for analyses, such as the website and media
tests, that are not restricted to the debt-choice issuer sample. A CUSIP is
counted as outstanding at the end of year t when:

    offering_date <= December 31 of year t
    maturity_date > December 31 of year t

The measure sums original CUSIP par amounts. It therefore recognizes scheduled
CUSIP maturities but not interim sinking-fund redemptions or other principal
amortization that is not represented by a separate CUSIP maturity.
"""

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path('/Users/kmunevar/Dropbox/Voting on Bonds')
BOND_FILE = (
    ROOT
    / 'Data'
    / 'Mergent'
    / 'Clean'
    / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
)
OUT_DIR = ROOT / 'Data' / 'Clean_Intermediate' / 'Mergent' / 'Outstanding Debt'
OUT_DIR.mkdir(parents=True, exist_ok=True)

PANEL_FILE = OUT_DIR / 'full_mergent_issuer_year_outstanding_debt.csv'
DIAGNOSTICS_FILE = OUT_DIR / 'full_mergent_outstanding_debt_build_diagnostics.csv'


def add_issuer_keys(frame: pd.DataFrame) -> pd.DataFrame:
    """Create stable issuer and issuer-state keys from the Mergent fields."""
    frame = frame.copy()
    numeric_id = pd.to_numeric(frame['seed_issuer_id'], errors='coerce')
    issuer_name = (
        frame['seed_issuer']
        .astype('string')
        .str.strip()
        .str.upper()
        .str.replace(r'\s+', ' ', regex=True)
    )
    state = frame['state'].astype('string').str.strip().str.upper()

    missing_key = numeric_id.isna() | issuer_name.isna() | state.isna()
    if missing_key.any():
        raise ValueError(
            f'Cannot construct issuer keys for {int(missing_key.sum()):,} rows.'
        )

    id_tenths = np.rint(numeric_id * 10).astype('int64')
    frame['seed_issuer_id'] = id_tenths / 10
    frame['seed_issuer'] = issuer_name
    frame['state'] = state
    frame['issuer_state_key'] = id_tenths.astype(str) + '|' + state.astype(str)
    frame['issuer_key'] = (
        frame['issuer_state_key'] + '|' + issuer_name.astype(str)
    )
    return frame


def main() -> None:
    columns = [
        'cusip',
        'seed_issuer_id',
        'seed_issuer',
        'state',
        'year',
        'offering_date',
        'maturity_date',
        'amount',
    ]

    print(f'Loading {BOND_FILE}')
    bonds = pd.read_stata(
        BOND_FILE,
        columns=columns,
        convert_categoricals=False,
    )
    input_rows = len(bonds)
    bonds = bonds.dropna(subset=['seed_issuer_id', 'seed_issuer', 'state'])
    bonds = add_issuer_keys(bonds)

    issuer_columns = [
        'issuer_key',
        'issuer_state_key',
        'seed_issuer_id',
        'seed_issuer',
        'state',
    ]
    issuers = bonds[issuer_columns].drop_duplicates()
    if issuers['issuer_key'].duplicated().any():
        raise ValueError('issuer_key does not uniquely identify issuer metadata.')

    issuer_state_collisions = int(
        issuers.groupby('issuer_state_key')['issuer_key'].nunique().gt(1).sum()
    )

    source_year = pd.to_numeric(bonds['year'], errors='coerce').dropna()
    if source_year.empty:
        raise ValueError('The Mergent file has no valid source years.')
    min_year = int(source_year.min())
    max_year = int(source_year.max())

    bonds['offering_date'] = pd.to_datetime(bonds['offering_date'], errors='coerce')
    bonds['maturity_date'] = pd.to_datetime(bonds['maturity_date'], errors='coerce')
    bonds['amount'] = pd.to_numeric(bonds['amount'], errors='coerce')

    bonds = bonds.dropna(
        subset=['cusip', 'offering_date', 'maturity_date', 'amount']
    )
    bonds = bonds.loc[
        bonds['amount'].gt(0)
        & bonds['maturity_date'].gt(bonds['offering_date'])
    ].copy()

    duplicate_cusips = bonds.duplicated(['issuer_key', 'cusip'], keep=False)
    if duplicate_cusips.any():
        conflicts = (
            bonds.loc[duplicate_cusips]
            .groupby(['issuer_key', 'cusip'])[
                ['offering_date', 'maturity_date', 'amount']
            ]
            .nunique()
            .gt(1)
            .any(axis=1)
        )
        if conflicts.any():
            raise ValueError(
                f'{int(conflicts.sum()):,} issuer-CUSIP keys have conflicting data.'
            )
        bonds = bonds.drop_duplicates(['issuer_key', 'cusip'])

    usable_bonds = len(bonds)
    bonds['issue_year'] = bonds['offering_date'].dt.year.astype('int64')
    bonds['last_outstanding_year'] = (
        bonds['maturity_date'].dt.year.astype('int64') - 1
    )
    bonds = bonds.loc[
        bonds['last_outstanding_year'].ge(bonds['issue_year'])
    ].copy()
    bonds = bonds.loc[
        bonds['issue_year'].le(max_year)
        & bonds['last_outstanding_year'].ge(min_year)
    ].copy()
    bonds['panel_issue_year'] = bonds['issue_year'].clip(lower=min_year)
    bonds['panel_last_year'] = bonds['last_outstanding_year'].clip(upper=max_year)

    repeat_counts = bonds['panel_last_year'] - bonds['panel_issue_year'] + 1
    expanded = bonds.loc[bonds.index.repeat(repeat_counts)].copy()
    expanded['year'] = (
        expanded['panel_issue_year'].to_numpy()
        + expanded.groupby(level=0).cumcount().to_numpy()
    )

    issuer_year_stock = (
        expanded.groupby(['issuer_key', 'year'], as_index=False)
        .agg(
            total_outstanding_debt=('amount', 'sum'),
            bonds_outstanding=('cusip', 'nunique'),
        )
    )

    years = pd.DataFrame(
        {'year': np.arange(min_year, max_year + 1, dtype='int64')}
    )
    issuer_grid = issuers[['issuer_key']].merge(years, how='cross')
    panel = issuer_grid.merge(
        issuer_year_stock,
        on=['issuer_key', 'year'],
        how='left',
        validate='one_to_one',
    )
    panel[['total_outstanding_debt', 'bonds_outstanding']] = panel[
        ['total_outstanding_debt', 'bonds_outstanding']
    ].fillna(0)
    panel['bonds_outstanding'] = panel['bonds_outstanding'].astype('int64')
    panel['ln_1p_total_outstanding_debt'] = np.log1p(
        panel['total_outstanding_debt']
    )
    panel = panel.merge(
        issuers,
        on='issuer_key',
        how='left',
        validate='many_to_one',
    )
    panel = panel[
        [
            'issuer_key',
            'issuer_state_key',
            'seed_issuer_id',
            'seed_issuer',
            'state',
            'year',
            'total_outstanding_debt',
            'ln_1p_total_outstanding_debt',
            'bonds_outstanding',
        ]
    ].sort_values(['state', 'seed_issuer', 'year'])

    panel.to_csv(PANEL_FILE, index=False)

    diagnostics = pd.DataFrame(
        [
            {
                'input_bond_rows': input_rows,
                'usable_unique_bonds': usable_bonds,
                'bonds_overlapping_panel_years': len(bonds),
                'bond_year_rows': len(expanded),
                'panel_rows': len(panel),
                'issuers': len(issuers),
                'issuer_state_key_collisions': issuer_state_collisions,
                'min_year': min_year,
                'max_year': max_year,
                'zero_debt_issuer_years': int(
                    panel['total_outstanding_debt'].eq(0).sum()
                ),
            }
        ]
    )
    diagnostics.to_csv(DIAGNOSTICS_FILE, index=False)

    print(f'Wrote {PANEL_FILE}')
    print(f'Wrote {DIAGNOSTICS_FILE}')
    print(
        f'{len(issuers):,} issuers; {min_year}-{max_year}; '
        f'{len(panel):,} issuer-year rows.'
    )


if __name__ == '__main__':
    main()
