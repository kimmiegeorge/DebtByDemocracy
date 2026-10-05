"""Create shareable CSV source extracts for the additional state-policy data.

The aggregation script deliberately reads the CSVs produced here, rather than
reading the supplied PDF and workbook.  This makes the hand transcription from
the GASB municipal table and the workbook conversion easy to inspect or share.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[4]
SOURCE_DIR = ROOT / "Data" / "Addnl State Policy Data"
SCRIPT_DIR = Path(__file__).resolve().parent

AUDIT_WORKBOOK = SOURCE_DIR / "Table-4.29-2023-BOS.xlsx_"
TEL_SOURCE = SCRIPT_DIR / "wen_municipal_tel_index.csv"
LINCOLN_SOURCE = SCRIPT_DIR / "lincoln_tax_limit_features.csv"
LINCOLN_RATE_CAP_SOURCE = SCRIPT_DIR / "lincoln_property_tax_rate_cap_2024.csv"

STATE_ABBRS = {
    "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
    "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
    "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
    "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
    "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
    "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
    "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
    "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
    "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
    "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
    "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
    "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
    "Wisconsin": "WI", "Wyoming": "WY",
}

# Transcribed from Waymire (2025), GASB Staff Working Paper, Table I.c,
# "Summary of Requirements for Municipalities" (PDF p. 33).  The coding
# follows the source's five mutually exclusive requirement categories exactly.
GASB_MUNICIPAL_CATEGORIES = """Alabama,GAAP required with exception
Alaska,No requirement
Arizona,GAAP required
Arkansas,Non-GAAP required with exception
California,GAAP required with exception
Colorado,GAAP required with exception
Connecticut,GAAP required with exception
Delaware,No requirement
Florida,GAAP required with exception
Georgia,GAAP required with exception
Hawaii,No requirement
Idaho,No requirement
Illinois,GAAP required with exception
Indiana,GAAP required with exception
Iowa,No requirement
Kansas,GAAP required with exception
Kentucky,GAAP required
Louisiana,GAAP required with exception
Maine,GAAP required
Maryland,GAAP required
Massachusetts,GAAP required with exception
Michigan,GAAP required
Minnesota,GAAP required with exception
Mississippi,No requirement
Missouri,No requirement
Montana,No requirement
Nebraska,No requirement
Nevada,GAAP required
New Hampshire,GAAP required
New Jersey,Non-GAAP required
New Mexico,GAAP required
New York,No requirement
North Carolina,GAAP required
North Dakota,No requirement
Ohio,No requirement
Oklahoma,No requirement
Oregon,No requirement
Pennsylvania,No requirement
Rhode Island,GAAP required
South Carolina,No requirement
South Dakota,No requirement
Tennessee,GAAP required
Texas,No requirement
Utah,GAAP required with exception
Vermont,No requirement
Virginia,GAAP required with exception
Washington,No requirement
West Virginia,GAAP required
Wisconsin,GAAP required with exception
Wyoming,GAAP required"""


def make_gasb_extract() -> pd.DataFrame:
    rows = [line.split(",", maxsplit=1) for line in GASB_MUNICIPAL_CATEGORIES.splitlines()]
    gasb = pd.DataFrame(rows, columns=["state_name", "gasb_municipal_gaap_requirement_category"])
    gasb["state_abbr"] = gasb["state_name"].map(STATE_ABBRS)
    gasb["gasb_municipal_gaap_required_any"] = gasb[
        "gasb_municipal_gaap_requirement_category"
    ].isin(["GAAP required", "GAAP required with exception"]).astype("Int64")
    gasb["gasb_municipal_gaap_required_no_exception"] = gasb[
        "gasb_municipal_gaap_requirement_category"
    ].eq("GAAP required").astype("Int64")
    gasb["gasb_source_document"] = "Waymire (2025), GASB Staff Working Paper"
    gasb["gasb_source_location"] = "Table I.c, Summary of Requirements for Municipalities, PDF p. 33"
    return gasb[[
        "state_abbr", "state_name", "gasb_municipal_gaap_requirement_category",
        "gasb_municipal_gaap_required_any", "gasb_municipal_gaap_required_no_exception",
        "gasb_source_document", "gasb_source_location",
    ]]


def make_audit_extract() -> pd.DataFrame:
    audit = pd.read_excel(AUDIT_WORKBOOK, header=6, keep_default_na=False)
    audit = audit.rename(columns={audit.columns[0]: "state_name"})
    audit["state_name"] = audit["state_name"].astype(str).str.strip()
    audit = audit.loc[audit["state_name"].isin(STATE_ABBRS)].copy()
    audit["state_abbr"] = audit["state_name"].map(STATE_ABBRS)
    audit.columns = [
        "state_name" if col == "state_name" else str(col).strip().lower()
        .replace(" ", "_").replace(",", "").replace("/", "_")
        for col in audit.columns
    ]
    audit["audit_source_document"] = "NASACT, Auditing in the States: A Summary (2023 edition)"
    audit["audit_source_location"] = "Table 4.29, State Auditors: Audits of Local Governments"
    ordered = ["state_abbr", "state_name"] + [
        column for column in audit.columns
        if column not in {"state_abbr", "state_name"}
    ]
    return audit[ordered]


def make_lincoln_extract() -> pd.DataFrame:
    lincoln = pd.read_csv(LINCOLN_SOURCE)
    rate_cap = pd.read_csv(LINCOLN_RATE_CAP_SOURCE)
    lincoln = lincoln.merge(rate_cap, on="state_abbr", how="left", validate="one_to_one")
    override_counts = (
        lincoln.loc[lincoln["lincoln_property_tax_levy_cap_2024"].eq(1)]
        ["lincoln_property_tax_levy_override_method_2024"]
        .value_counts()
        .to_dict()
    )
    expected_override_counts = {
        "referendum": 16,
        "referendum_or_governing_body": 3,
        "governing_body": 2,
        "none": 6,
    }
    if override_counts != expected_override_counts:
        raise ValueError(
            "Lincoln levy-limit override categories do not reproduce Figure 9 "
            "after excluding the District of Columbia."
        )
    expected_voter_approval = lincoln[
        "lincoln_property_tax_levy_override_method_2024"
    ].eq("referendum").astype("Int64")
    if not expected_voter_approval.equals(
        lincoln[
            "lincoln_property_tax_levy_override_requires_voter_approval_2024"
        ].astype("Int64")
    ):
        raise ValueError("Lincoln referendum-only override indicator is inconsistent with its category.")
    lincoln["lincoln_source_document"] = "Langley, Paquin, and Um (2025), Understanding State Property Tax Limits"
    lincoln["lincoln_source_locations"] = (
        "Figure 2 (2024 rate-limit presence); Table 1 (2022 maximum rate); "
        "Table 2; Figure 9 (2024 levy-limit override method); Table 3; Figure 10"
    )
    return lincoln


def make_tel_extract() -> pd.DataFrame:
    tel = pd.read_csv(TEL_SOURCE).rename(columns={"state": "state_abbr"})
    tel["tel_source_document"] = "Wen, Xu, Kim, and Warner (2020)"
    tel["tel_source_location"] = "Appendix 2 (municipal TEL severity index)"
    return tel


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "gasb_municipal_gaap_requirements_2025.csv": make_gasb_extract(),
        "nasact_state_audit_requirements_2023.csv": make_audit_extract(),
        "lincoln_property_tax_limit_features_2024.csv": make_lincoln_extract(),
        "wen_municipal_tel_index_2020.csv": make_tel_extract(),
    }
    manifest = pd.DataFrame([
        {
            "csv_file": "gasb_municipal_gaap_requirements_2025.csv",
            "source_file": "GASB Reporting Paper.pdf",
            "source_description": "Municipal GAAP reporting-framework requirement categories",
            "source_location": "Waymire (2025), Table I.c, PDF p. 33",
        },
        {
            "csv_file": "nasact_state_audit_requirements_2023.csv",
            "source_file": "Table-4.29-2023-BOS.xlsx_",
            "source_description": "State auditor and local-government audit requirements",
            "source_location": "NASACT (2023), Table 4.29",
        },
        {
            "csv_file": "lincoln_property_tax_limit_features_2024.csv",
            "source_file": "property_tax_limits_pd_rev.pdf",
            "source_description": "Property-tax rate and levy caps, levy-limit override methods, Truth-in-Taxation, and municipal budget caps",
            "source_location": "Langley, Paquin, and Um (2025), Figure 2; Tables 1--3; Figures 9--10; underlying 2024 database records",
        },
        {
            "csv_file": "wen_municipal_tel_index_2020.csv",
            "source_file": "Wen Xu Kim Warner paper (Data/Literature)",
            "source_description": "Municipal tax and expenditure limit severity index",
            "source_location": "Wen et al. (2020), Appendix 2",
        },
    ])
    outputs["state_policy_source_manifest.csv"] = manifest
    for name, frame in outputs.items():
        path = SOURCE_DIR / name
        frame.to_csv(path, index=False)
        print(f"Wrote {path}")

    if len(outputs["gasb_municipal_gaap_requirements_2025.csv"]) != 50:
        raise ValueError("GASB municipal extract does not contain 50 states.")
    if len(outputs["nasact_state_audit_requirements_2023.csv"]) != 50:
        raise ValueError("NASACT audit extract does not contain 50 states.")


if __name__ == "__main__":
    main()
