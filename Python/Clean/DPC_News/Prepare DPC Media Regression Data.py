"""Attach prior-year county demographics for R/Clean/08_media_coverage_dpc.R."""

#%% Paths and inputs
import os
from pathlib import Path

import polars as pl
import pyreadstat

code_dir = Path(__file__).resolve().parents[3]
data_dir = code_dir.parent / 'Data'
clean_data_dir = data_dir / 'Clean_Intermediate'
output_dir = Path(os.getenv(
    'DPC_MEDIA_REGRESSION_DIR', str(clean_data_dir / 'DPC Data/News')
)).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)

issuance_lvl = pl.read_parquet(
    clean_data_dir / 'DPC Data/News/Issuance_Lvl_DPC_News.gzip'
)

#%% Recover missing county identifiers using the existing step-08 convention
# pyreadstat only reads Stata; transformations and joins use Polars.
bond_raw, _ = pyreadstat.read_dta(
    data_dir / 'Mergent/Clean/260716_city_cusiplevel_statereq_purpose_yieldspread.dta',
    usecols=['seed_issuer_id', 'fips'], output_format='dict'
)
issuers = pl.DataFrame(bond_raw).group_by('seed_issuer_id', maintain_order=True).agg(
    pl.col('fips').first().alias('fips_from_mergent')
)
issuance_lvl = issuance_lvl.join(
    issuers, on='seed_issuer_id', how='left', validate='m:1',
    nulls_equal=True, maintain_order='left'
).with_columns(
    pl.coalesce(
        pl.col('fips').cast(pl.Float64, strict=False),
        pl.col('fips_from_mergent').cast(pl.Float64, strict=False)
    ).cast(pl.Int64).alias('fips')
).drop('fips_from_mergent')

#%% Match BEA demographics to the year before each issuance
county_raw, _ = pyreadstat.read_dta(
    data_dir / 'BEA/countydemos_1999_2026.dta',
    usecols=['fips', 'year', 'gdp', 'pop', 'pers_inc'], output_format='dict'
)
county_controls = pl.DataFrame(county_raw).select(
    pl.col('fips').cast(pl.Int64),
    pl.col('year').cast(pl.Int64).alias('county_control_year'),
    pl.when(pl.col('gdp') > 0).then(pl.col('gdp').log()).alias('ln_gdp'),
    pl.when(pl.col('pop') > 0).then(pl.col('pop').log()).alias('ln_pop'),
    pl.when(pl.col('pers_inc') > 0).then(pl.col('pers_inc').log()).alias('ln_pers_inc')
)
issuance_lvl = issuance_lvl.drop('ln_gdp', 'ln_pop', 'ln_pers_inc').with_columns(
    (pl.col('year').cast(pl.Int64) - 1).alias('county_control_year')
).join(county_controls, on=['fips', 'county_control_year'],
       how='left', validate='m:1', maintain_order='left')
# Preserve rows, outcomes, coverage flags, and the employment screen used in R.
# Missing/nonpositive BEA levels stay missing; no other-year fallback is used.

#%% Save the input consumed by step 08
output_file = output_dir / 'dpc_media_regression_data.csv'
issuance_lvl.write_csv(output_file)
print(f'Wrote {issuance_lvl.height:,} issuance rows to {output_file}')
