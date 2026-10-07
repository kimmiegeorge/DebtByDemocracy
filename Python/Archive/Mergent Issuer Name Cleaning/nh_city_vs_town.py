"""
Classify New Hampshire bond observations as issued by CITIES vs TOWNS.

Efficiency choices (from a computing perspective):
1. Read ONLY the 2 needed columns (state, issuer_long_name) out of 229 via
   pandas.read_stata(columns=...). Avoids materializing the full 328k x 229 frame.
2. Filter to NH a single time.
3. Vectorized classification: one regex to extract the municipality name, then
   set-membership (.isin) + np.where -- no per-row Python loop.

Note: `seed_issuer` is NOT usable -- it is built with substring matching, so
"CHESTER N H" wrongly absorbs MANCHESTER/ROCHESTER and "DERRY N H" absorbs
LONDONDERRY. We use `issuer_long_name`, the true issuer name.
"""
import numpy as np
import pandas as pd

DTA = "251027_city_cusiplevel_statereq_purpose_yieldspread.dta"

# The 13 incorporated cities of New Hampshire; every other municipality is a town.
NH_CITIES = {
    "BERLIN", "CLAREMONT", "CONCORD", "DOVER", "FRANKLIN", "KEENE",
    "LACONIA", "LEBANON", "MANCHESTER", "NASHUA", "PORTSMOUTH",
    "ROCHESTER", "SOMERSWORTH",
}

# 1. Read only the columns we need.
df = pd.read_stata(DTA, columns=["state", "issuer_long_name"])

# 2. Keep New Hampshire.
nh = df.loc[df["state"] == "NH"].copy()
nh["issuer_long_name"] = nh["issuer_long_name"].astype(str)

# 3. Municipality name = text before the " N H" state tag. This collapses revenue
#    variants ("MANCHESTER N H ARPT REV" -> "MANCHESTER"). Non-municipal conduit
#    issuers ("NEW HAMPSHIRE MUN BD BK") have no " N H" tag -> NaN -> "Other".
nh["muni"] = nh["issuer_long_name"].str.extract(r"^(.*?)\s+N\s+H(?:\s|$)")[0]

nh["category"] = np.where(
    nh["muni"].isna(), "Other",
    np.where(nh["muni"].isin(NH_CITIES), "City", "Town"),
)

# --- Verification: distinct issuer -> muni -> category ---
chk = (nh.groupby(["category", "issuer_long_name", "muni"], dropna=False)
         .size().reset_index(name="n")
         .sort_values(["category", "n"], ascending=[True, False]))
print("=== Issuer mapping (verification) ===")
print(chk.to_string(index=False))

# --- Counts ---
counts = nh["category"].value_counts()
n_total = len(nh)
n_city = int(counts.get("City", 0))
n_town = int(counts.get("Town", 0))
n_other = int(counts.get("Other", 0))
muni = n_city + n_town

print("\n=== NH bond counts ===")
print(f"City            : {n_city}")
print(f"Town            : {n_town}")
print(f"Other (BondBank): {n_other}")
print(f"Total NH        : {n_total}")

print("\n=== City vs Town (municipal issuers only, excludes bond bank) ===")
print(f"City: {n_city}/{muni} = {100*n_city/muni:.1f}%")
print(f"Town: {n_town}/{muni} = {100*n_town/muni:.1f}%")

print("\n=== Share of ALL NH bonds ===")
print(f"City : {100*n_city/n_total:.1f}%")
print(f"Town : {100*n_town/n_total:.1f}%")
print(f"Other: {100*n_other/n_total:.1f}%")
