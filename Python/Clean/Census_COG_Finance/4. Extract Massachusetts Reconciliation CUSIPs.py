"""Extract underlying CUSIPs for the largest Massachusetts 2017 share changes.

This is a companion to ``3. Audit Legacy Updated 2017 Debt Composition.py``.
It writes a side-by-side legacy/current CUSIP file for the 20 Massachusetts
control cities with the largest decline in UTGO share.  Current amounts use
the same redemption ledger as the updated cross-section builder. Mergent's
``new_money == 0`` is an issuance-level non-new-money designation and can
include mixed refunding/new-money issues.
"""

from datetime import date
import importlib.util
import os
from pathlib import Path

import pandas as pd
import polars as pl


ROOT = Path(os.path.expanduser('~/Dropbox/Voting on Bonds'))
CODE_DIR = ROOT / 'Code' / 'Python' / 'Clean' / 'Census_COG_Finance'
OUT_DIR = ROOT / 'Data' / 'Census CAFR Validation'
AS_OF = date(2017, 12, 31)

spec = importlib.util.spec_from_file_location(
    'reconciliation_audit', CODE_DIR / '3. Audit Legacy Updated 2017 Debt Composition.py'
)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def type_label(frame, prefix):
    return frame.with_columns(
        pl.when(pl.col('utgo')).then(pl.lit('UTGO'))
        .when(pl.col('all_go')).then(pl.lit('LTGO'))
        .when(pl.col('revenue')).then(pl.lit('Revenue'))
        .otherwise(pl.lit('Other'))
        .alias(f'{prefix}_type')
    )


def main():
    reconciliation = pd.read_csv(OUT_DIR / 'legacy_updated_2017_cusip_reconciliation_by_city.csv')
    focus = reconciliation[
        reconciliation.state.eq('MA') & reconciliation.city_go_vote.eq(0)
    ].copy()
    focus['utgo_share_change'] = focus.frac_utgo_updated - focus.frac_utgo_legacy
    focus = focus.nsmallest(20, 'utgo_share_change')
    focus_ids = focus[['gov_id', 'census_name', 'utgo_share_change']]

    legacy_cross = pl.read_csv(audit.LEGACY_CROSS).select([
        pl.col('gov_id').cast(pl.Int64), pl.col('seed_issuer_id').cast(pl.Float64).round(1),
    ]).unique(subset=['seed_issuer_id'])
    updated_cross = audit.issuer_key(pl.read_csv(audit.UPDATED_CROSS).select([
        pl.col('gov_id').cast(pl.Int64), 'seed_issuer_id', 'seed_issuer', 'state',
    ])).unique(subset=['issuer_key'])
    focus_pl = pl.from_pandas(focus_ids)

    old = (
        audit.read_dta(audit.CLEAN / '260709_city_cusiplevel_statereq_purpose_yieldspread.dta', [
            'cusip', 'issue_id', 'issuer_long_name', 'issue_description', 'series',
            'security_code', 'seed_issuer_id', 'offering_date', 'maturity_date',
            'amount', 'go_unlim', 'go_lim', 'rev',
        ])
        .with_columns([
            pl.col('seed_issuer_id').cast(pl.Float64).round(1),
            pl.col('issue_id').cast(pl.Int64, strict=False),
            pl.col('cusip').cast(pl.Utf8).str.to_uppercase(),
            pl.col('amount').cast(pl.Float64),
            pl.col('offering_date').cast(pl.Date), pl.col('maturity_date').cast(pl.Date),
        ])
        .filter(
            pl.col('seed_issuer_id').is_not_null() & pl.col('rev').is_not_null()
            & (pl.col('offering_date') <= AS_OF) & (pl.col('maturity_date') > AS_OF)
        )
        .pipe(audit.classification).pipe(type_label, 'legacy')
        .join(legacy_cross, on='seed_issuer_id', how='inner')
        .join(focus_pl, on='gov_id', how='inner')
        .select([
            'gov_id', pl.col('census_name').alias('current_census_name'), 'utgo_share_change', 'cusip',
            pl.col('issuer_long_name').alias('legacy_issuer_long_name'),
            pl.col('issue_id').alias('legacy_issue_id'),
            pl.col('issue_description').alias('legacy_issue_description'),
            pl.col('series').alias('legacy_series'),
            pl.col('security_code').alias('legacy_security_code'),
            pl.col('offering_date').alias('legacy_offering_date'),
            pl.col('maturity_date').alias('legacy_maturity_date'),
            pl.col('amount').alias('legacy_amount'), 'legacy_type',
        ])
    )

    current = (
        audit.read_dta(audit.CLEAN / '260923_cusiplevel_allbonds_inclrefund.dta', [
            'cusip', 'issue_id', 'maturity_id', 'issuer_long_name', 'issue_description',
            'series', 'security_code', 'seed_issuer_id', 'seed_issuer', 'state',
            'offering_date', 'maturity_date', 'amount', 'new_money',
            'total_mat_amt_outstanding', 'total_mat_amt_outstanding_date',
            'go_unlim', 'go_lim', 'rev', 'use_proceeds', 'taxexempt_federal', 'coupon_code',
        ])
        .pipe(audit.city_scope).pipe(audit.issuer_key)
        .with_columns([
            pl.col('cusip').cast(pl.Utf8).str.to_uppercase(),
            pl.col('issue_id').cast(pl.Int64, strict=False), pl.col('maturity_id').cast(pl.Int64, strict=False),
            pl.col('amount').cast(pl.Float64), pl.col('new_money').cast(pl.Int8, strict=False),
            pl.col('offering_date').cast(pl.Date), pl.col('maturity_date').cast(pl.Date),
            pl.col('total_mat_amt_outstanding').cast(pl.Float64, strict=False),
            pl.col('total_mat_amt_outstanding_date').cast(pl.Int64, strict=False).cast(pl.Utf8)
            .str.strptime(pl.Date, '%Y%m%d', strict=False).alias('total_mat_amt_outstanding_date'),
        ])
        .pipe(audit.classification).pipe(type_label, 'current')
        .filter((pl.col('offering_date') <= AS_OF) & (pl.col('maturity_date') > AS_OF))
        .join(updated_cross, on='issuer_key', how='inner')
        .join(focus_pl, on='gov_id', how='inner')
        .join(audit.redemption_ledger(), on=['issue_id', 'maturity_id'], how='left')
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
            ).alias('current_post_amount')
        )
        .select([
            'gov_id', 'census_name', 'utgo_share_change', 'cusip',
            pl.col('issuer_long_name').alias('current_issuer_long_name'),
            pl.col('issue_id').alias('current_issue_id'),
            pl.col('maturity_id').alias('current_maturity_id'),
            pl.col('issue_description').alias('current_issue_description'),
            pl.col('series').alias('current_series'),
            pl.col('security_code').alias('current_security_code'),
            pl.col('offering_date').alias('current_offering_date'),
            pl.col('maturity_date').alias('current_maturity_date'),
            pl.col('amount').alias('current_pre_ledger_amount'),
            'current_post_amount', 'new_money', 'redeemed_principal',
            'unknown_full_redemption', 'total_mat_amt_outstanding',
            'total_mat_amt_outstanding_date', 'current_type',
        ])
    )

    detail = old.join(
        current.drop(['utgo_share_change']), on=['gov_id', 'cusip'], how='full', coalesce=True,
    ).with_columns([
        pl.coalesce(['census_name', 'current_census_name']).alias('census_name'),
        pl.when(pl.col('legacy_amount').is_null()).then(
            pl.when(pl.col('new_money').eq(0)).then(pl.lit('current-only Mergent non-new-money'))
            .otherwise(pl.lit('current-only new money'))
        ).when(pl.col('current_pre_ledger_amount').is_null()).then(pl.lit('legacy-only'))
        .otherwise(pl.lit('shared CUSIP')).alias('source_status')
    ]).sort(['census_name', 'source_status', 'cusip'])

    output = OUT_DIR / 'massachusetts_2017_largest_utgo_changes_cusip_detail.csv'
    detail.write_csv(output)
    print(f'Wrote {detail.height:,} CUSIP rows for {len(focus):,} Massachusetts cities to {output}')
    print(detail.group_by('source_status').len().sort('source_status'))


if __name__ == '__main__':
    main()
