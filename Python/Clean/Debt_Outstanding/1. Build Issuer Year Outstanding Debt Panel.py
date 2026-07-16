"""
Build an issuer-year panel of end-of-year outstanding municipal debt.

The stock measure uses CUSIP-level Mergent issuance data. A bond is counted as
outstanding at the end of year t if:

    offering_date <= December 31 of year t
    maturity_date > December 31 of year t

The script restricts to issuers in the issuer-level debt-choice file, creates a
balanced issuer-year grid, fills years with no outstanding debt as zero, and
adds issuer-level vote variables and controls from the debt-choice sample.
"""

from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path('/Users/kmunevar/Dropbox/Voting on Bonds')
DATA_DIR = ROOT / 'Data'
CLEAN_DATA_DIR = DATA_DIR / 'Clean_Intermediate'
MERGENT_DIR = DATA_DIR / 'Mergent' / 'clean'
BEA_DIR = DATA_DIR / 'BEA'
OUT_DIR = CLEAN_DATA_DIR / 'Mergent' / 'Outstanding Debt'
OUT_DIR.mkdir(parents=True, exist_ok=True)

BOND_FILE = MERGENT_DIR / '260716_city_cusiplevel_statereq_purpose_yieldspread.dta'
ISSUER_FILE = MERGENT_DIR / '260716_city_issuerlevel_yieldspread.dta'
BEA_COUNTY_DEMOS_FILE = BEA_DIR / 'countydemos_1999_2026.dta'

ISSUER_YEAR_PANEL = OUT_DIR / 'issuer_year_outstanding_debt.csv'
ANNUAL_SUMMARY = OUT_DIR / 'annual_outstanding_debt_by_vote_status.csv'
POOLED_REGRESSIONS = OUT_DIR / 'pooled_outstanding_debt_year_fe_regressions.csv'
DIAGNOSTICS = OUT_DIR / 'outstanding_debt_build_diagnostics.csv'

HIGH_STATE_TAX_PRIVILEGE_STATES = {
    'CA', 'OR', 'HI', 'VT', 'RI', 'MT', 'ME', 'NJ', 'MN', 'NC', 'ID', 'NY',
    'AR', 'SC', 'NE', 'OH', 'WV', 'NM', 'DE',
}


def read_stata_columns(path: Path, columns: list[str]) -> pd.DataFrame:
    """Read selected Stata columns using pyreadstat through pandas."""
    return pd.read_stata(path, columns=columns, convert_categoricals=False)


def main() -> None:
    print('Loading issuer-level debt-choice sample...')
    issuer_cols = [
        'seed_issuer_id',
        'seed_issuer',
        'fips',
        'state',
        'state_name',
        'city_go_vote',
        'city_rev_vote',
        'state_go_vote',
        'state_utgo_allowed',
        'state_ltgo_allowed',
        'insample',
        'insample_allgo',
        'insample_utgo_only',
        'ln_gdp',
        'ln_pop',
        'ln_pers_inc',
        'ln_county_debt_other',
        'glm_proactive',
        'pop',
    ]
    issuers = read_stata_columns(ISSUER_FILE, issuer_cols)
    issuers = issuers.dropna(subset=['seed_issuer_id'])
    issuers['seed_issuer_id'] = issuers['seed_issuer_id'].astype('int64')
    issuers['fips'] = issuers['fips'].astype(str).str.replace(r'\.0$', '', regex=True).str.zfill(5)
    issuers = issuers.drop_duplicates('seed_issuer_id', keep='first')
    issuers = issuers.rename(columns={'pop': 'issuer_file_pop', 'ln_pop': 'issuer_file_ln_pop'})
    issuers['high_state_tax_privilege'] = (
        issuers['state'].astype(str).str.upper().isin(HIGH_STATE_TAX_PRIVILEGE_STATES)
    ).astype('int8')

    sample_issuers = issuers.loc[
        issuers['insample'].eq(1),
        ['seed_issuer_id'],
    ].drop_duplicates('seed_issuer_id')

    print(f'Issuer-level rows: {len(issuers):,}')
    print(f'Full debt-choice sample issuers: {len(sample_issuers):,}')

    print('Loading annual BEA county demographics...')
    bea = read_stata_columns(
        BEA_COUNTY_DEMOS_FILE,
        ['fips', 'year', 'geoname', 'employment', 'gdp', 'percap_inc', 'pers_inc', 'pop'],
    )
    bea['fips'] = bea['fips'].astype(str).str.replace(r'\.0$', '', regex=True).str.zfill(5)
    bea['year'] = bea['year'].astype('int64')
    bea = bea.loc[bea['fips'].ne('00000')].copy()
    bea = bea.rename(
        columns={
            'geoname': 'bea_geoname',
            'employment': 'annual_employment',
            'gdp': 'annual_gdp',
            'percap_inc': 'annual_percap_inc',
            'pers_inc': 'annual_pers_inc',
            'pop': 'annual_pop',
        }
    )
    bea = bea.drop_duplicates(['fips', 'year'], keep='first')
    bea_year_min = int(bea['year'].min())
    bea_year_max = int(bea['year'].max())
    print(f'Annual BEA county years: {bea_year_min}-{bea_year_max}')

    print('Loading CUSIP-level Mergent issuance data...')
    bond_cols = [
        'cusip',
        'issue_id',
        'seed_issuer_id',
        'seed_issuer',
        'state',
        'offering_date',
        'maturity_date',
        'amount',
        'go_unlim',
        'go_lim',
        'rev',
        'security_code',
        'source_of_repayment',
    ]
    bonds = read_stata_columns(BOND_FILE, bond_cols)
    bonds = bonds.dropna(subset=['seed_issuer_id'])
    bonds['seed_issuer_id'] = bonds['seed_issuer_id'].astype('int64')
    bonds = bonds.merge(sample_issuers, on='seed_issuer_id', how='inner')

    bonds['offering_date'] = pd.to_datetime(bonds['offering_date'], errors='coerce')
    bonds['maturity_date'] = pd.to_datetime(bonds['maturity_date'], errors='coerce')
    bonds['amount'] = pd.to_numeric(bonds['amount'], errors='coerce')

    initial_bonds = len(bonds)
    bonds = bonds.dropna(subset=['cusip', 'offering_date', 'maturity_date', 'amount'])
    bonds = bonds.loc[bonds['amount'].gt(0)].copy()
    bonds = bonds.loc[bonds['maturity_date'].gt(bonds['offering_date'])].copy()
    usable_bonds = len(bonds)

    bonds['go_any'] = (
        bonds['go_unlim'].fillna(0).eq(1) | bonds['go_lim'].fillna(0).eq(1)
    ).astype('int8')
    bonds['revenue_bond'] = bonds['rev'].fillna(0).eq(1).astype('int8')
    bonds['strict_gg_revenue_bond'] = (
        bonds['security_code'].astype(str).str.strip().str.upper().eq('G')
        & bonds['source_of_repayment'].astype(str).str.strip().str.upper().eq('G')
    ).astype('int8')

    bonds['issue_year'] = bonds['offering_date'].dt.year.astype('int64')
    bonds['maturity_year'] = bonds['maturity_date'].dt.year.astype('int64')
    bonds['last_outstanding_year'] = bonds['maturity_year'] - 1
    bonds = bonds.loc[bonds['last_outstanding_year'].ge(bonds['issue_year'])].copy()

    min_year = int(max(bonds['issue_year'].min(), bea_year_min))
    max_year = int(min(bonds['last_outstanding_year'].max(), bea_year_max))
    bonds = bonds.loc[
        bonds['issue_year'].le(max_year) & bonds['last_outstanding_year'].ge(min_year)
    ].copy()
    bonds['issue_year_for_panel'] = bonds['issue_year'].clip(lower=min_year)
    bonds['last_outstanding_year_for_panel'] = bonds['last_outstanding_year'].clip(upper=max_year)
    print(f'Usable bonds: {usable_bonds:,} of {initial_bonds:,}')
    print(f'Outstanding-debt year range: {min_year}-{max_year}')

    print('Expanding bonds to end-of-year outstanding observations...')
    repeat_counts = (
        bonds['last_outstanding_year_for_panel'] - bonds['issue_year_for_panel'] + 1
    )
    expanded = bonds.loc[bonds.index.repeat(repeat_counts)].copy()
    expanded['year'] = (
        expanded['issue_year_for_panel'].to_numpy()
        + expanded.groupby(level=0).cumcount().to_numpy()
    )

    expanded['go_amount'] = expanded['amount'] * expanded['go_any']
    expanded['revenue_amount'] = expanded['amount'] * expanded['revenue_bond']
    expanded['strict_gg_revenue_amount'] = (
        expanded['amount'] * expanded['strict_gg_revenue_bond']
    )

    print(f'Bond-year rows: {len(expanded):,}')

    print('Aggregating to issuer-year...')
    issuer_year_stock = (
        expanded.groupby(['seed_issuer_id', 'year'], as_index=False)
        .agg(
            total_outstanding_debt=('amount', 'sum'),
            go_outstanding_debt=('go_amount', 'sum'),
            revenue_outstanding_debt=('revenue_amount', 'sum'),
            strict_gg_revenue_outstanding_debt=('strict_gg_revenue_amount', 'sum'),
            bonds_outstanding=('cusip', 'nunique'),
            go_bonds_outstanding=('go_any', 'sum'),
            revenue_bonds_outstanding=('revenue_bond', 'sum'),
            strict_gg_revenue_bonds_outstanding=('strict_gg_revenue_bond', 'sum'),
        )
    )

    years = pd.DataFrame({'year': np.arange(min_year, max_year + 1, dtype='int64')})
    issuer_grid = sample_issuers.assign(_merge_key=1).merge(
        years.assign(_merge_key=1), on='_merge_key', how='outer'
    ).drop(columns='_merge_key')

    panel = issuer_grid.merge(
        issuer_year_stock, on=['seed_issuer_id', 'year'], how='left'
    )

    amount_cols = [
        'total_outstanding_debt',
        'go_outstanding_debt',
        'revenue_outstanding_debt',
        'strict_gg_revenue_outstanding_debt',
    ]
    count_cols = [
        'bonds_outstanding',
        'go_bonds_outstanding',
        'revenue_bonds_outstanding',
        'strict_gg_revenue_bonds_outstanding',
    ]
    panel[amount_cols + count_cols] = panel[amount_cols + count_cols].fillna(0)

    panel = panel.merge(issuers, on='seed_issuer_id', how='left')
    panel = panel.merge(bea, on=['fips', 'year'], how='left')
    panel['vote_required'] = panel['city_go_vote']

    panel['ln_pop'] = np.where(
        panel['annual_pop'].gt(0),
        np.log(panel['annual_pop']),
        np.nan,
    )
    panel['ln_gdp'] = np.where(
        panel['annual_gdp'].gt(0),
        np.log(panel['annual_gdp']),
        np.nan,
    )
    panel['ln_pers_inc'] = np.where(
        panel['annual_pers_inc'].gt(0),
        np.log(panel['annual_pers_inc']),
        np.nan,
    )
    panel['ln_employment'] = np.where(
        panel['annual_employment'].gt(0),
        np.log(panel['annual_employment']),
        np.nan,
    )

    for col in amount_cols:
        panel[f'{col}_per_capita'] = panel[col] / panel['annual_pop']
        panel[f'ln_1p_{col}'] = np.log1p(panel[col])

    panel['strict_gg_revenue_share_outstanding'] = np.where(
        panel['go_outstanding_debt'].add(panel['strict_gg_revenue_outstanding_debt']).gt(0),
        panel['strict_gg_revenue_outstanding_debt']
        / (
            panel['go_outstanding_debt']
            + panel['strict_gg_revenue_outstanding_debt']
        ),
        np.nan,
    )

    panel = panel.sort_values(['seed_issuer_id', 'year'])
    panel.to_csv(ISSUER_YEAR_PANEL, index=False)
    print(f'Wrote {ISSUER_YEAR_PANEL}')

    print('Writing annual vote-status summaries...')
    summary = (
        panel.groupby(['year', 'vote_required'], dropna=False)
        .agg(
            issuers=('seed_issuer_id', 'nunique'),
            mean_total_outstanding_debt_pc=(
                'total_outstanding_debt_per_capita',
                'mean',
            ),
            median_total_outstanding_debt_pc=(
                'total_outstanding_debt_per_capita',
                'median',
            ),
            mean_go_outstanding_debt_pc=('go_outstanding_debt_per_capita', 'mean'),
            mean_revenue_outstanding_debt_pc=(
                'revenue_outstanding_debt_per_capita',
                'mean',
            ),
            mean_strict_gg_revenue_outstanding_debt_pc=(
                'strict_gg_revenue_outstanding_debt_per_capita',
                'mean',
            ),
            mean_strict_gg_revenue_share_outstanding=(
                'strict_gg_revenue_share_outstanding',
                'mean',
            ),
            mean_annual_pop=('annual_pop', 'mean'),
        )
        .reset_index()
    )
    summary.to_csv(ANNUAL_SUMMARY, index=False)
    print(f'Wrote {ANNUAL_SUMMARY}')

    print('Writing pooled issuer-year regressions with year fixed effects...')
    controls = [
        'ln_gdp',
        'ln_pop',
        'ln_pers_inc',
        'ln_county_debt_other',
        'glm_proactive',
        'state_ltgo_allowed',
        'state_go_vote',
        'high_state_tax_privilege',
    ]
    outcomes = [
        'total_outstanding_debt_per_capita',
        'go_outstanding_debt_per_capita',
        'strict_gg_revenue_outstanding_debt_per_capita',
        'ln_1p_total_outstanding_debt',
        'ln_1p_go_outstanding_debt',
        'ln_1p_strict_gg_revenue_outstanding_debt',
        'strict_gg_revenue_share_outstanding',
    ]
    regression_rows = []
    try:
        import statsmodels.api as sm
        import statsmodels.formula.api as smf

        for outcome in outcomes:
            reg_df = panel[['fips', 'year', 'vote_required', outcome, *controls]].dropna()
            if reg_df['vote_required'].nunique() < 2 or len(reg_df) < 25:
                continue
            rhs = 'vote_required + ' + ' + '.join(controls) + ' + C(year)'
            fit = smf.ols(f'{outcome} ~ {rhs}', data=reg_df).fit(
                cov_type='cluster',
                cov_kwds={'groups': reg_df['fips']},
            )
            regression_rows.append(
                {
                    'outcome': outcome,
                    'estimate_vote_required': fit.params.get('vote_required', np.nan),
                    'se_vote_required': fit.bse.get('vote_required', np.nan),
                    't_vote_required': fit.tvalues.get('vote_required', np.nan),
                    'p_vote_required': fit.pvalues.get('vote_required', np.nan),
                    'estimate_ln_pop': fit.params.get('ln_pop', np.nan),
                    'se_ln_pop': fit.bse.get('ln_pop', np.nan),
                    't_ln_pop': fit.tvalues.get('ln_pop', np.nan),
                    'p_ln_pop': fit.pvalues.get('ln_pop', np.nan),
                    'n': int(fit.nobs),
                    'r2': fit.rsquared,
                    'year_fixed_effects': 1,
                    'cluster': 'fips',
                }
            )
    except ImportError:
        print('statsmodels not available; skipping pooled regressions.')

    pd.DataFrame(regression_rows).to_csv(POOLED_REGRESSIONS, index=False)
    print(f'Wrote {POOLED_REGRESSIONS}')

    diagnostics = pd.DataFrame(
        [
            {
                'input_bonds_in_sample_issuers': initial_bonds,
                'usable_bonds_with_dates_and_amount': usable_bonds,
                'bonds_after_end_of_year_filter': len(bonds),
                'bond_year_rows': len(expanded),
                'issuer_year_rows': len(panel),
                'sample_issuers': panel['seed_issuer_id'].nunique(),
                'min_year': min_year,
                'max_year': max_year,
                'bea_min_year': bea_year_min,
                'bea_max_year': bea_year_max,
                'issuer_year_rows_missing_annual_pop': int(panel['annual_pop'].isna().sum()),
                'missing_or_invalid_bonds_removed': initial_bonds - usable_bonds,
            }
        ]
    )
    diagnostics.to_csv(DIAGNOSTICS, index=False)
    print(f'Wrote {DIAGNOSTICS}')


if __name__ == '__main__':
    main()
