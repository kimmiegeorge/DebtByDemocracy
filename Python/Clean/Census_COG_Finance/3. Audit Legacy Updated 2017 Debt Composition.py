"""Reconcile the paper-era and updated 2017 Mergent debt compositions.

The audit reconstructs the legacy 260709 stock and the current 260923 stock
at 12/31/2017, at the Census-government/CUSIP level.  It then decomposes each
city's change in GO-plus-revenue debt into:

* a revision to CUSIPs shared by both sources (including lost legacy CUSIPs),
* newly covered new-money CUSIPs,
* newly covered Mergent ``new_money == 0`` CUSIPs, and
* principal removed by the current redemption/outstanding-balance ledger.

Mergent assigns ``new_money`` at the issuance level. Its zero value can include
mixed refunding/new-money issues, so this audit does not interpret the field as
a pure-refunding indicator. The output is an accounting reconciliation, not a
causal decomposition: the
order used to calculate sequential UTGO-share changes is stated in the output
column names.  In particular, it makes clear whether a legacy-to-updated
change is caused by source coverage or by applying actual principal reductions.
"""

from datetime import date
from pathlib import Path
import os

import pandas as pd
import polars as pl


ROOT = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
MERGENT = ROOT / 'Data' / 'Mergent'
CLEAN = MERGENT / 'Clean'
RAW = MERGENT / 'Raw'
LEGACY_CROSS = ROOT / 'Data' / 'Census COG Finance' / 'processed' / 'census_mergent_debt_cross_section_2017.csv'
UPDATED_CROSS = ROOT / 'Data' / 'Clean_Intermediate' / 'Census COG Finance' / 'processed' / 'census_mergent_debt_cross_section_2017.csv'
OUT_DIR = ROOT / 'Data' / 'Census CAFR Validation'

AS_OF = date(2017, 12, 31)


def read_dta(path, columns):
    return pl.from_pandas(pd.read_stata(path, columns=columns, convert_categoricals=False))


def issuer_key(frame):
    return frame.with_columns([
        pl.col('seed_issuer_id').cast(pl.Float64).round(1),
        pl.col('seed_issuer').cast(pl.Utf8).str.strip_chars(),
        pl.col('state').cast(pl.Utf8).str.to_uppercase(),
    ]).with_columns(
        pl.concat_str([
            (pl.col('seed_issuer_id') * 10).round(0).cast(pl.Int64).cast(pl.Utf8),
            pl.col('state'),
            pl.col('seed_issuer').str.to_uppercase().str.replace_all(r'\s+', ' '),
        ], separator='|').alias('issuer_key')
    )


def city_scope(frame):
    """The scope screen used by the updated cross-section builder."""
    name = pl.col('issuer_long_name').cast(pl.Utf8).fill_null('').str.to_uppercase()
    purpose = pl.col('use_proceeds').cast(pl.Utf8).fill_null('').str.to_uppercase()
    coupon = pl.col('coupon_code').cast(pl.Utf8).fill_null('').str.to_uppercase()
    school = (
        name.str.contains('SCH DI', literal=True)
        | (name.str.contains('PUB', literal=True) & name.str.contains('SCH', literal=True))
        | (name.str.contains('SCH', literal=True) & name.str.contains('IND', literal=True))
        | (name.str.contains('REG', literal=True) & name.str.contains('SCH', literal=True))
        | (name.str.contains('SCHOOL', literal=True) & name.str.contains('DIST', literal=True))
        | name.str.contains('SCHS', literal=True)
        | name.str.contains('SCH SYS', literal=True)
        | name.str.contains('AREA SCH', literal=True)
    )
    state_issuer = name.str.ends_with(' ST') | name.str.contains(' ST ', literal=True)
    corporation = (
        name.str.contains('CORP', literal=True)
        & ~name.str.contains('CORPUS CHRISTI TEX', literal=True)
    ) | name.eq('CORPUS CHRISTI TEX BUSINESS & JOB DEV CORP SALES TAX RE')
    higher_ed = (name.str.contains('UNIV', literal=True) | name.str.contains('COLLEGE', literal=True)) & purpose.eq('HIED')
    return frame.filter(
        ~state_issuer
        & ~name.str.contains('AUTH', literal=True)
        & ~corporation
        & ~name.str.contains('AGY', literal=True)
        & ~name.str.contains('AGENCY', literal=True)
        & ~(name.str.contains('DIST', literal=True) & ~school)
        & ~higher_ed
        & pl.col('taxexempt_federal').cast(pl.Float64, strict=False).eq(1)
        & coupon.is_in(['FXD', 'OID', 'OIP'])
        & pl.col('seed_issuer_id').is_not_null()
        & pl.col('amount').is_not_null()
        & (pl.col('amount') > 0)
        & pl.col('offering_date').is_not_null()
        & pl.col('maturity_date').is_not_null()
    )


def classification(frame):
    """Apply the legacy flag definitions and six issuance-level corrections."""
    issue = pl.col('issue_id').cast(pl.Int64, strict=False)
    return frame.with_columns([
        pl.when(issue.is_in([766088, 1223949, 642811, 640435])).then(1)
        .when(issue.is_in([34328, 572223])).then(0).otherwise(pl.col('go_unlim')).alias('go_unlim'),
        pl.when(issue.is_in([34328, 572223])).then(1)
        .when(issue.is_in([766088, 642811, 640435])).then(0).otherwise(pl.col('go_lim')).alias('go_lim'),
        pl.when(issue.eq(1223949)).then(0).otherwise(pl.col('rev')).alias('rev'),
    ]).with_columns([
        (pl.col('go_unlim').eq(1) | pl.col('go_lim').eq(1)).alias('all_go'),
        pl.col('go_unlim').eq(1).alias('utgo'),
        pl.col('rev').fill_null(0).cast(pl.Int8, strict=False).eq(1).alias('revenue'),
    ]).with_columns((pl.col('all_go') | pl.col('revenue')).alias('go_revenue'))


def amount_by_type(amount, prefix):
    return [
        pl.when(pl.col('go_revenue')).then(pl.col(amount)).otherwise(0.0).sum().alias(f'{prefix}_go_revenue'),
        pl.when(pl.col('utgo')).then(pl.col(amount)).otherwise(0.0).sum().alias(f'{prefix}_utgo'),
        pl.when(pl.col('revenue')).then(pl.col(amount)).otherwise(0.0).sum().alias(f'{prefix}_revenue'),
    ]


def redemption_ledger():
    full_principal = ['A', 'B', 'C', 'D', 'E', 'F', 'H', 'L', 'O', 'P', 'Q']
    non_principal = ['G', 'J', 'N']
    full = (
        pl.scan_csv(RAW / 'REDEMPTN.DLM', separator='|', null_values=[''], infer_schema_length=10_000)
        .select([
            pl.col('issue_id_l').cast(pl.Int64, strict=False).alias('issue_id'),
            pl.col('maturity_id_l').cast(pl.Int64, strict=False).alias('maturity_id'),
            pl.col('redemption_date_d').cast(pl.Utf8).str.strptime(pl.Date, '%Y%m%d', strict=False).alias('event_date'),
            pl.col('redemption_amt_f').cast(pl.Float64, strict=False).alias('redemption_amount'),
            pl.col('redemption_type_i').cast(pl.Utf8).alias('redemption_type'),
        ])
        .filter(
            pl.col('issue_id').is_not_null() & pl.col('maturity_id').is_not_null()
            & pl.col('event_date').is_not_null() & ~pl.col('redemption_type').is_in(non_principal)
            & (pl.col('event_date') <= AS_OF)
        )
        .with_columns([
            pl.col('redemption_amount').fill_null(0.0),
            (pl.col('redemption_amount').is_null() & pl.col('redemption_type').is_in(full_principal))
            .cast(pl.Int8).alias('unknown_full_redemption'),
        ])
        .select(['issue_id', 'maturity_id', 'redemption_amount', 'unknown_full_redemption'])
    )
    partial = (
        pl.scan_csv(RAW / 'PARTREDM.DLM', separator='|', null_values=[''], infer_schema_length=10_000)
        .select([
            pl.col('issue_id_l').cast(pl.Int64, strict=False).alias('issue_id'),
            pl.col('maturity_id_l').cast(pl.Int64, strict=False).alias('maturity_id'),
            pl.col('partial_call_date_d').cast(pl.Utf8).str.strptime(pl.Date, '%Y%m%d', strict=False).alias('event_date'),
            pl.col('prtl_call_amt_f').cast(pl.Float64, strict=False).alias('redemption_amount'),
        ])
        .filter(
            pl.col('issue_id').is_not_null() & pl.col('maturity_id').is_not_null()
            & pl.col('event_date').is_not_null() & (pl.col('event_date') <= AS_OF)
            & pl.col('redemption_amount').is_not_null() & (pl.col('redemption_amount') > 0)
        )
        .with_columns(pl.lit(0).cast(pl.Int8).alias('unknown_full_redemption'))
        .select(['issue_id', 'maturity_id', 'redemption_amount', 'unknown_full_redemption'])
    )
    return pl.concat([full, partial]).collect().group_by(['issue_id', 'maturity_id']).agg([
        pl.col('redemption_amount').sum().alias('redeemed_principal'),
        pl.col('unknown_full_redemption').max().alias('unknown_full_redemption'),
    ])


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    legacy_city = pl.read_csv(LEGACY_CROSS).select([
        pl.col('gov_id').cast(pl.Int64), pl.col('seed_issuer_id').cast(pl.Float64).round(1),
    ]).unique(subset=['seed_issuer_id'])
    updated_city = issuer_key(pl.read_csv(UPDATED_CROSS).select([
        pl.col('gov_id').cast(pl.Int64), 'seed_issuer_id', 'seed_issuer', 'state',
        'city_go_vote', 'census_name', 'insample_allgo',
    ])).unique(subset=['issuer_key'])

    old = (
        read_dta(CLEAN / '260709_city_cusiplevel_statereq_purpose_yieldspread.dta', [
            'cusip', 'issue_id', 'seed_issuer_id', 'offering_date', 'maturity_date',
            'amount', 'go_unlim', 'go_lim', 'rev',
        ])
        .with_columns([
            pl.col('seed_issuer_id').cast(pl.Float64).round(1), pl.col('issue_id').cast(pl.Int64, strict=False),
            pl.col('cusip').cast(pl.Utf8).str.to_uppercase(), pl.col('amount').cast(pl.Float64),
            pl.col('offering_date').cast(pl.Date), pl.col('maturity_date').cast(pl.Date),
        ])
        .filter(
            pl.col('seed_issuer_id').is_not_null() & pl.col('rev').is_not_null()
            & (pl.col('offering_date') <= AS_OF) & (pl.col('maturity_date') > AS_OF)
        )
        .pipe(classification)
        .join(legacy_city, on='seed_issuer_id', how='inner')
        .group_by(['gov_id', 'cusip'])
        .agg(amount_by_type('amount', 'old'))
    )

    current_cols = [
        'cusip', 'issue_id', 'maturity_id', 'seed_issuer_id', 'seed_issuer', 'state',
        'issuer_long_name', 'offering_date', 'maturity_date', 'amount', 'new_money',
        'total_mat_amt_outstanding', 'total_mat_amt_outstanding_date', 'go_unlim', 'go_lim',
        'rev', 'use_proceeds', 'taxexempt_federal', 'coupon_code',
    ]
    current = (
        read_dta(CLEAN / '260923_cusiplevel_allbonds_inclrefund.dta', current_cols)
        .pipe(city_scope).pipe(issuer_key)
        .with_columns([
            pl.col('cusip').cast(pl.Utf8).str.to_uppercase(),
            pl.col('issue_id').cast(pl.Int64, strict=False), pl.col('maturity_id').cast(pl.Int64, strict=False),
            pl.col('amount').cast(pl.Float64), pl.col('new_money').cast(pl.Int8, strict=False),
            pl.col('offering_date').cast(pl.Date), pl.col('maturity_date').cast(pl.Date),
            pl.col('total_mat_amt_outstanding').cast(pl.Float64, strict=False),
            pl.col('total_mat_amt_outstanding_date').cast(pl.Int64, strict=False).cast(pl.Utf8)
            .str.strptime(pl.Date, '%Y%m%d', strict=False).alias('total_mat_amt_outstanding_date'),
        ])
        .pipe(classification)
        .filter((pl.col('offering_date') <= AS_OF) & (pl.col('maturity_date') > AS_OF))
        .join(updated_city, on='issuer_key', how='inner')
    )
    ledger = redemption_ledger()
    current = (
        current.join(ledger, on=['issue_id', 'maturity_id'], how='left')
        .with_columns([
            pl.col('redeemed_principal').fill_null(0.0),
            pl.col('unknown_full_redemption').fill_null(0).cast(pl.Int8),
        ])
        .with_columns(
            pl.when(pl.col('unknown_full_redemption').eq(1)).then(0.0).otherwise(
                pl.when(
                    pl.col('total_mat_amt_outstanding').is_not_null()
                    & pl.col('total_mat_amt_outstanding_date').is_not_null()
                    & (pl.col('total_mat_amt_outstanding_date') <= AS_OF)
                ).then(pl.min_horizontal(
                    (pl.col('amount') - pl.col('redeemed_principal')).clip(0.0, None),
                    pl.col('total_mat_amt_outstanding').clip(0.0, None),
                )).otherwise((pl.col('amount') - pl.col('redeemed_principal')).clip(0.0, None))
            ).alias('post_amount')
        )
        .group_by(['gov_id', 'cusip', 'new_money'])
        .agg([
            *amount_by_type('amount', 'current_pre'),
            *amount_by_type('post_amount', 'current_post'),
        ])
    )

    old_pd = old.to_pandas()
    current_pd = current.to_pandas()
    current_pd['new_money_group'] = current_pd['new_money'].map({0: 'mergent_non_new_money', 1: 'new_money'}).fillna('unknown')
    current_pd = current_pd.drop(columns='new_money').groupby(['gov_id', 'cusip', 'new_money_group'], as_index=False).sum(numeric_only=True)
    old_pd['old_present'] = 1
    merged = old_pd.merge(current_pd, on=['gov_id', 'cusip'], how='outer').fillna(0)
    for col in ['old_go_revenue', 'old_utgo', 'old_revenue', 'current_pre_go_revenue', 'current_pre_utgo', 'current_pre_revenue', 'current_post_go_revenue', 'current_post_utgo', 'current_post_revenue']:
        merged[col] = merged[col].astype(float)
    merged['is_shared'] = merged.old_present.eq(1) & merged.current_pre_go_revenue.gt(0)
    merged['is_new'] = merged.old_present.ne(1) & merged.current_pre_go_revenue.gt(0)

    def component(mask, prefix, pre='current_pre', post='current_post'):
        for typ in ['go_revenue', 'utgo', 'revenue']:
            merged[f'{prefix}_{typ}'] = np.where(mask, merged[f'{pre}_{typ}'], 0.0)
            if prefix.startswith('ledger'):
                merged[f'{prefix}_{typ}'] = np.where(mask, merged[f'{pre}_{typ}'] - merged[f'{post}_{typ}'], 0.0)

    import numpy as np
    # Shared-source revision includes the negative amount for a legacy CUSIP
    # absent from the current source, preserving an exact city accounting.
    for typ in ['go_revenue', 'utgo', 'revenue']:
        merged[f'shared_source_revision_{typ}'] = np.where(
            merged.old_present.eq(1), merged[f'current_pre_{typ}'] - merged[f'old_{typ}'], 0.0
        )
    component(merged.is_new & merged.new_money_group.eq('new_money'), 'added_new_money')
    component(merged.is_new & merged.new_money_group.eq('mergent_non_new_money'), 'added_refunding')
    component(merged.is_shared, 'ledger_shared')
    component(merged.is_new & merged.new_money_group.eq('new_money'), 'ledger_new_money')
    component(merged.is_new & merged.new_money_group.eq('mergent_non_new_money'), 'ledger_refunding')

    component_cols = [
        f'{part}_{typ}' for part in [
            'old', 'shared_source_revision', 'added_new_money', 'added_refunding',
            'ledger_shared', 'ledger_new_money', 'ledger_refunding', 'current_post',
        ] for typ in ['go_revenue', 'utgo', 'revenue']
    ]
    city = merged.groupby('gov_id', as_index=False)[component_cols].sum()
    city['reconciled_go_revenue'] = (
        city.old_go_revenue + city.shared_source_revision_go_revenue
        + city.added_new_money_go_revenue + city.added_refunding_go_revenue
        - city.ledger_shared_go_revenue - city.ledger_new_money_go_revenue - city.ledger_refunding_go_revenue
    )
    city['reconciled_utgo'] = (
        city.old_utgo + city.shared_source_revision_utgo + city.added_new_money_utgo + city.added_refunding_utgo
        - city.ledger_shared_utgo - city.ledger_new_money_utgo - city.ledger_refunding_utgo
    )
    city['reconciliation_error_go_revenue'] = city.reconciled_go_revenue - city.current_post_go_revenue
    city['reconciliation_error_utgo'] = city.reconciled_utgo - city.current_post_utgo

    def share(numer, denom):
        return np.where(denom > 0, numer / denom, np.nan)
    city['frac_utgo_legacy'] = share(city.old_utgo, city.old_go_revenue)
    stage_go = city.old_go_revenue + city.shared_source_revision_go_revenue
    stage_ut = city.old_utgo + city.shared_source_revision_utgo
    city['frac_utgo_after_shared_source_revision'] = share(stage_ut, stage_go)
    stage_go += city.added_new_money_go_revenue; stage_ut += city.added_new_money_utgo
    city['frac_utgo_after_added_new_money'] = share(stage_ut, stage_go)
    stage_go += city.added_refunding_go_revenue; stage_ut += city.added_refunding_utgo
    city['frac_utgo_after_added_refunding_preledger'] = share(stage_ut, stage_go)
    city['frac_utgo_updated'] = share(city.current_post_utgo, city.current_post_go_revenue)

    city = updated_city.to_pandas().merge(city, on='gov_id', how='right')
    city.to_csv(OUT_DIR / 'legacy_updated_2017_cusip_reconciliation_by_city.csv', index=False)

    allgo = city[(city.insample_allgo == 1) & city.city_go_vote.isin([0, 1])].copy()
    share_cols = [
        'frac_utgo_legacy', 'frac_utgo_after_shared_source_revision',
        'frac_utgo_after_added_new_money', 'frac_utgo_after_added_refunding_preledger',
        'frac_utgo_updated',
    ]
    amount_cols = [c for c in city.columns if c.endswith(('_go_revenue', '_utgo', '_revenue'))]
    summary = allgo.groupby('city_go_vote')[['gov_id', *share_cols, *amount_cols]].agg(
        {**{'gov_id': 'count'}, **{c: 'mean' for c in share_cols + amount_cols}}
    ).rename(columns={'gov_id': 'cities'}).reset_index()
    summary.to_csv(OUT_DIR / 'legacy_updated_2017_cusip_reconciliation_summary_by_vote.csv', index=False)

    # The broad All-GO universe above is useful descriptively, but the paper's
    # coefficient uses a narrower common-city/control screen. Save that exact
    # summary separately so it is not confused with the regression sample.
    control_cols = [
        'ln_gdp', 'ln_pers_inc', 'ln_1p_county_nonmunicipal_total_debt',
        'glm_proactive', 'state_ltgo_allowed', 'state_go_vote',
    ]
    low_privilege_states = {
        'MD', 'AL', 'MS', 'NH', 'AZ', 'CO', 'MI', 'UT', 'PA', 'FL',
        'IN', 'AK', 'DC', 'IA', 'IL', 'NV', 'OK', 'TX', 'WA', 'WI',
    }
    old_controls = pd.read_csv(LEGACY_CROSS)
    new_controls = pd.read_csv(UPDATED_CROSS)
    for frame in [old_controls, new_controls]:
        frame['ln_census_population'] = np.log(frame['census_population'])
        frame['low_state_tax_privilege'] = frame['state'].isin(low_privilege_states).astype(int)
    old_controls = old_controls[['gov_id', 'insample_allgo', 'mergent_go_revenue_bonds_outstanding', 'state', *control_cols, 'ln_census_population', 'low_state_tax_privilege']].add_prefix('old_').rename(columns={'old_gov_id': 'gov_id'})
    new_controls = new_controls[['gov_id', 'insample_allgo', 'mergent_go_revenue_bonds_outstanding', 'state', *control_cols, 'ln_census_population', 'low_state_tax_privilege']].add_prefix('new_').rename(columns={'new_gov_id': 'gov_id'})
    common = city.merge(old_controls, on='gov_id', how='inner').merge(new_controls, on='gov_id', how='inner')
    old_ok = common[[f'old_{col}' for col in control_cols + ['ln_census_population', 'low_state_tax_privilege']]].notna().all(axis=1)
    new_ok = common[[f'new_{col}' for col in control_cols + ['ln_census_population', 'low_state_tax_privilege']]].notna().all(axis=1)
    common = common[
        common.old_insample_allgo.eq(1)
        & common.new_insample_allgo.eq(1)
        & common.old_mergent_go_revenue_bonds_outstanding.ge(2)
        & common.new_mergent_go_revenue_bonds_outstanding.ge(2)
        & old_ok & new_ok
        & common.frac_utgo_legacy.notna() & common.frac_utgo_updated.notna()
    ]
    paper_summary = common.groupby('city_go_vote')[['gov_id', *share_cols]].agg(
        {**{'gov_id': 'count'}, **{col: 'mean' for col in share_cols}}
    ).rename(columns={'gov_id': 'cities'}).reset_index()
    paper_summary.to_csv(
        OUT_DIR / 'legacy_updated_2017_cusip_reconciliation_paper_common_summary_by_vote.csv',
        index=False,
    )

    print('Wrote city reconciliation and vote-status summary to', OUT_DIR)
    print('Maximum absolute reconciliation error ($):', city[['reconciliation_error_go_revenue', 'reconciliation_error_utgo']].abs().max().max())
    print(summary[['city_go_vote', 'cities', *share_cols]].to_string(index=False))
    print('Paper common-city/control-screened summary:')
    print(paper_summary.to_string(index=False))


if __name__ == '__main__':
    main()
