"""Validate the Mergent data contracts used by the active paper pipeline."""

from pathlib import Path


CODE = Path(__file__).resolve().parents[2]
PROJECT = CODE.parent
MERGENT = PROJECT / "Data" / "Mergent" / "Clean"

CANONICAL_BOND = "260716_city_cusiplevel_statereq_purpose_yieldspread.dta"
CANONICAL_ISSUER = "260716_city_issuerlevel_yieldspread.dta"
SHARED_DEBT = "full_mergent_issuer_year_outstanding_debt.csv"

EXPECTED_REFERENCES = {
    "Python/Clean/Border_States/Identify Counties in Border States Wider Sample.py": CANONICAL_BOND,
    "Python/Clean/City_Websites/Border_States/01_create_border_state_website_analysis_data.py": CANONICAL_BOND,
    "Python/Clean/City_Websites/Border_States/02_prepare_border_state_website_regression_data.py": CANONICAL_BOND,
    "Python/Clean/City_Websites/Texas/create_texas_website_analysis_data.py": CANONICAL_BOND,
    "Python/Clean/Continuing_Disclosure/create_issuer_year_panel.py": CANONICAL_BOND,
    "Python/Clean/Census_COG_Finance/1. Clean Census COG City Debt.py": CANONICAL_BOND,
    "Python/Clean/Census_COG_Finance/2b. Build Census Mergent Debt Cross Sections No Refundings.py": CANONICAL_BOND,
    "Python/Clean/Debt_Outstanding/1. Build Issuer Year Outstanding Debt Panel.py": (
        CANONICAL_BOND,
        CANONICAL_ISSUER,
    ),
    "Python/Clean/Debt_Outstanding/2. Build Full Mergent Annual Outstanding Debt Panel.py": CANONICAL_BOND,
    "Python/Clean/DPC_News/Create Issuance Level DPC News Variables.py": CANONICAL_BOND,
    "Python/Clean/DPC_News/Prepare DPC Media Regression Data.py": CANONICAL_BOND,
    "Python/Clean/DPC_News/Pull Control State Bond Election Articles.py": CANONICAL_BOND,
    "Python/Clean/Election_Outcomes/05_prepare_tx_regression_inputs.py": CANONICAL_BOND,
    "Python/Clean/MSRB/01_build_trade_before_maturity.py": CANONICAL_BOND,
    "Python/Clean/News/3. Merge RP IDs with Mergent Data.py": CANONICAL_BOND,
    "Python/Clean/News/4. Pull Time Series of Articles.py": CANONICAL_BOND,
    "Python/Clean/News/6. Prepare Media Coverage Regression Data.py": CANONICAL_BOND,
    "Python/Clean/Purposes_Substitution/01_merge_dpc_purposes_all_issuers.py": CANONICAL_BOND,
    "Python/Clean/Purposes_Substitution/02_build_point_in_time_purpose_panels.py": CANONICAL_BOND,
    "Python/Clean/State_Policy_Comparison/aggregate_state_policies.py": CANONICAL_ISSUER,
    "Python/Clean/TX_Rejection_Risk/01_prepare_tx_rejection_risk.py": (
        SHARED_DEBT,
        CANONICAL_BOND,
        CANONICAL_ISSUER,
    ),
    "R/Clean/03_texas_media_event_time.R": CANONICAL_BOND,
    "R/Clean/07_alternative_sample_robustness.R": CANONICAL_ISSUER,
}

EXCLUDED_REFERENCES = (
    "260610_city_cusiplevel_statereq_purpose_yieldspread.dta",
    "260709_city_cusiplevel_statereq_purpose_yieldspread.dta",
    "260709_issuer_year_outstanding_debt.csv",
    "241120_tx_issue_level.dta",
    "261013_mergent_raw.dta",
)


errors = []
for relative_path, expected in EXPECTED_REFERENCES.items():
    source_path = CODE / relative_path
    if not source_path.exists():
        errors.append(f"Missing active pipeline file: {relative_path}")
        continue
    source = source_path.read_text()
    expected_names = (expected,) if isinstance(expected, str) else expected
    for expected_name in expected_names:
        if expected_name not in source:
            errors.append(f"{relative_path} does not reference {expected_name}")
    forbidden = [name for name in EXCLUDED_REFERENCES if name in source]
    if forbidden:
        errors.append(
            f"{relative_path} contains excluded paper input(s): {', '.join(forbidden)}"
        )

for filename in [CANONICAL_BOND, CANONICAL_ISSUER]:
    if not (MERGENT / filename).exists():
        errors.append(f"Missing canonical Mergent input: {MERGENT / filename}")

shared_debt_path = (
    PROJECT
    / "Data"
    / "Clean_Intermediate"
    / "Mergent"
    / "Outstanding Debt"
    / SHARED_DEBT
)
if not shared_debt_path.exists():
    errors.append(f"Missing shared outstanding-debt input: {shared_debt_path}")

if errors:
    raise SystemExit("\n".join(errors))

print(
    f"Validated {len(EXPECTED_REFERENCES)} active consumers against the "
    "canonical 260716 paper-sample contract."
)
