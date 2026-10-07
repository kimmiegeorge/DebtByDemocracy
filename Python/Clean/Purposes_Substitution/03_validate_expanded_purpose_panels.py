"""Check purpose coverage, stable outcomes, and updated prior-year controls."""

import os
from pathlib import Path

import polars as pl
from polars.testing import assert_frame_equal

code_dir = Path(__file__).resolve().parents[3]
data_dir = code_dir.parent / 'Data'
default_panel_dir = data_dir / 'DPC Data/Use Of Proceeds/Purposes Substitution'
panel_dir = Path(os.getenv('PURPOSE_REGRESSION_DIR', str(default_panel_dir))).expanduser()
baseline_dir = Path(os.getenv(
    'PURPOSE_BASELINE_DIR', str(default_panel_dir / 'legacy_before_expansion')
)).expanduser()
validation_dir = Path(os.getenv(
    'PURPOSE_VALIDATION_DIR', str(panel_dir / 'diagnostics')
)).expanduser()
validation_dir.mkdir(parents=True, exist_ok=True)

state_policy = pl.read_csv(
    data_dir / 'State Policies/20260929_state_policy_comparison.csv',
    infer_schema_length=100000
).rename({'state_abbr': 'state'})
updated_columns = {'ln_gdp', 'ln_pers_inc', 'demographic_year', *state_policy.columns}

validation_rows = []
for year in [2012, 2017]:
    issuer_cross_section = pl.read_csv(
        data_dir / 'Clean_Intermediate/Census COG Finance/processed/no_refundings'
        / f'census_mergent_debt_cross_section_{year}.csv',
        infer_schema_length=100000
    ).with_columns(pl.concat_str(
        pl.col('state').str.strip_chars().str.to_uppercase(), pl.lit('|'),
        pl.col('seed_issuer').str.strip_chars().str.to_uppercase()
    ).alias('issuer_match_key'))
    for layout in ['panel', 'wide']:
        filename = (
            f'260719_dpc_point_in_time_purpose_substitution_{year}'
            f'_issuer_category_{layout}.csv'
        )
        old = pl.read_csv(baseline_dir / filename, infer_schema_length=100000)
        new = pl.read_csv(panel_dir / filename, infer_schema_length=100000)
        keys = ['issuer_match_key'] + (['purpose_category'] if layout == 'panel' else [])
        if new.select(keys).is_duplicated().any():
            raise ValueError(f'Duplicate observation keys: {filename}')
        lost = old.select(keys).join(new.select(keys), on=keys, how='anti')
        if lost.height:
            raise ValueError(f'{filename}: {lost.height} original observations were lost.')
        stable_columns = [column for column in old.columns if column not in updated_columns]
        overlap = new.join(old.select(keys), on=keys, how='semi').select(stable_columns)
        # Purpose outcomes, sample flags, and bond measures must remain identical.
        # Added null rows can widen integer column types without changing values.
        assert_frame_equal(
            old.select(stable_columns).sort(keys), overlap.sort(keys), check_dtypes=False,
            check_exact=True
        )
        actual_issuers = new.select('issuer_match_key').unique()
        assert_frame_equal(
            actual_issuers.sort('issuer_match_key'),
            issuer_cross_section.select('issuer_match_key').sort('issuer_match_key')
        )
        # Check the new demographic values independently against the Census input.
        demo_cols = ['demographic_year', 'ln_gdp', 'ln_pers_inc']
        actual_controls = new.select('issuer_match_key', *demo_cols).unique()
        assert_frame_equal(
            actual_controls.sort('issuer_match_key'),
            issuer_cross_section.select('issuer_match_key', *demo_cols).sort('issuer_match_key'),
            check_dtypes=False, check_exact=True
        )
        if actual_controls['demographic_year'].drop_nulls().unique().to_list() != [year - 1]:
            raise ValueError(f'Wrong demographic year: {filename}')
        strict = new.select('state', 'strict_municipal_debt_limit').unique()
        expected_strict = state_policy.select('state', 'strict_municipal_debt_limit').join(
            strict.select('state'), on='state', how='semi'
        )
        assert_frame_equal(strict.sort('state'), expected_strict.sort('state'),
                           check_dtypes=False, check_exact=True)
        if layout == 'panel':
            missing_coverage = new.filter(pl.col('dpc_purpose_observed') == 0)
            if missing_coverage['category_amount'].null_count() != missing_coverage.height:
                raise ValueError('Unobserved DPC purposes must have missing category outcomes.')
        validation_rows.append({
            'year': year, 'layout': layout, 'baseline_rows': old.height,
            'expanded_rows': new.height, 'overlapping_rows': overlap.height,
            'added_rows': new.height - overlap.height,
            'expanded_issuers': actual_issuers.height,
            'original_fields_checked': len(stable_columns),
            'all_stable_fields_match': True, 'prior_year_controls_match': True
        })
        print(f'{filename}: {old.height:,} original outcomes and flags match; '
              f'{actual_issuers.height:,} expanded issuers retained.')

new_2017 = pl.read_csv(
    panel_dir / '260719_dpc_point_in_time_purpose_substitution_2017_issuer_category_panel.csv',
    infer_schema_length=100000
)
for state in ['AL', 'SD', 'ID']:
    if new_2017.filter(pl.col('state') == state).is_empty():
        raise ValueError(f'{state} is absent from the expanded 2017 panel.')
state_coverage = new_2017.group_by('state', 'city_rev_vote').agg(
    pl.col('issuer_match_key').n_unique().alias('issuers'),
    pl.col('issuer_match_key').filter(pl.col('dpc_purpose_observed') == 1)
    .n_unique().alias('issuers_with_observed_dpc_purposes')
).sort('state', 'city_rev_vote')
pl.DataFrame(validation_rows).write_csv(validation_dir / 'purpose_overlap_validation.csv')
state_coverage.write_csv(validation_dir / 'purpose_2017_state_coverage.csv')
print(state_coverage.filter(pl.col('state').is_in(['AL', 'SD', 'ID'])))
