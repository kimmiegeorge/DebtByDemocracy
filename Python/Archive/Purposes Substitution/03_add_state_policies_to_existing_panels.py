"""Add expanded state policies to the existing point-in-time purpose panels."""

#%% Paths and the shared state-policy comparison
import os
from pathlib import Path

import polars as pl

code_dir = Path(__file__).resolve().parents[3]
data_dir = code_dir.parent / 'Data'
panel_dir = data_dir / 'DPC Data/Use Of Proceeds/Purposes Substitution'
output_dir = Path(os.getenv('PURPOSE_POLICY_OUTPUT_DIR', str(panel_dir))).expanduser()
output_dir.mkdir(parents=True, exist_ok=True)

state_policy = pl.read_csv(
    data_dir / 'State Policies/20260929_state_policy_comparison.csv',
    infer_schema_length=10000
).rename({'state_abbr': 'state'})
if (state_policy.height != 50 or state_policy['state'].null_count() > 0
        or state_policy['state'].n_unique() != 50):
    raise ValueError('State-policy comparison must contain one row for each of the 50 states.')

# Source text may contain line breaks that confuse R fread's type detection.
# Preserve the text while keeping each CSV record on a single line.
text_columns = [column for column, dtype in state_policy.schema.items()
                if dtype == pl.String]
state_policy = state_policy.with_columns(
    pl.col(text_columns).str.replace_all(r'[\r\n]+', ' ')
)
policy_columns = [column for column in state_policy.columns if column != 'state']

#%% Enrich the category panels and their wide counterparts without rebuilding stocks
# The 2017 files feed 06; the 2012 files feed the alternative-sample analysis.
# Reruns replace only the incoming policy fields, leaving analysis inputs intact.
for year in [2012, 2017]:
    for layout in ['panel', 'wide']:
        filename = (
            f'260719_dpc_point_in_time_purpose_substitution_{year}'
            f'_issuer_category_{layout}.csv'
        )
        data = pl.read_csv(panel_dir / filename, infer_schema_length=100000)
        missing_states = data.select('state').unique().join(
            state_policy.select('state'), on='state', how='anti'
        )
        if missing_states.height > 0:
            raise ValueError(f'{filename}: unmatched policy states: {missing_states}')
        existing_policy_columns = [column for column in policy_columns if column in data.columns]
        data = data.drop(existing_policy_columns).join(
            state_policy, on='state', how='left', validate='m:1', maintain_order='left'
        )
        data.write_csv(output_dir / filename)
        print(f'Wrote {filename}: {data.height:,} rows, {data.width} columns')
