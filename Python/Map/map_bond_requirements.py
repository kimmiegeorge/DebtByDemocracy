#!/usr/bin/env python3
"""
Bond Referendum Requirements Map – US Cities by State
Data source: GO and Revenue columns from the Output tab of
             2026-07-12_City laws by state.xlsx

State categories
----------------
NO_VOTE    : GO=None  AND Revenue=None                   → white
ONLY_GO    : GO=specific (non-UTGO), Revenue=None        → light green
ONLY_UTGO  : GO contains 'UTGO', Revenue=None            → light green + gray diagonal stripes
GO_REVENUE : GO=specific, Revenue exists (incl. Depends) → dark green
DEPENDS    : GO=Depends                                   → pale gray (no pattern)

Changes from 2026-02-28 map
----------------------------
  • ND  – moved from GO+Revenue (dark green) → DEPENDS (pale gray)
  • ME  – moved from GO+Revenue (dark green) → DEPENDS (pale gray)
  • AR  – moved from GO+Revenue (dark green) → ONLY_GO  (light green)
  • DEPENDS states: pale gray, no dot pattern (was dotted blue)
"""

import io
import os
import urllib.request
import zipfile
from datetime import date

import matplotlib
matplotlib.use('Agg')          # non-interactive backend
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
import geopandas as gpd

# Thinner hatch lines for UTGO diagonal stripes
matplotlib.rcParams['hatch.linewidth'] = 0.4

# ─── Paths ────────────────────────────────────────────────────────────────────
CACHE_DIR  = r'C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Code\Python\Map'
OUTPUT_DIR = r'C:\Users\juneh\Dropbox (Personal)\Voting on Bonds\Descriptives\Figures'
os.makedirs(CACHE_DIR,  exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)

TODAY       = date.today().strftime('%Y-%m-%d')
OUTPUT_PATH = os.path.join(OUTPUT_DIR, f'{TODAY}_map_output.png')

# ─── State classifications ────────────────────────────────────────────────────
NO_VOTE    = frozenset({'KY', 'MA', 'MS', 'NH', 'NJ', 'TN', 'WI'})           # 7 states
ONLY_GO    = frozenset({'AK', 'AR', 'CA', 'FL', 'GA', 'LA', 'MT', 'NC',     # 15 states
                         'NE', 'NM', 'OR', 'TX', 'UT', 'WV', 'WY'})
ONLY_UTGO  = frozenset({'MI', 'OH', 'WA'})                                     # 3 states
GO_REVENUE = frozenset({'AL', 'AZ', 'CO', 'ID', 'MO', 'OK', 'SD', 'VT'})    # 8 states
DEPENDS    = frozenset({'CT', 'DE', 'IL', 'IN', 'IA', 'KS', 'ME', 'MD',     # 16 states
                         'MN', 'ND', 'NV', 'NY', 'PA', 'RI', 'SC', 'VA'})

# ─── Colors ───────────────────────────────────────────────────────────────────
C_WHITE   = '#ffffff'   # no vote required
C_LT_GRN  = '#a6dba0'  # only GO (and UTGO base)
C_DK_GRN  = '#006d2c'  # GO + revenue
C_GRAY    = '#d0d0d0'  # depends / varies within-state  (pale gray)
C_BORDER  = '#000000'  # state borders
C_HATCH   = '#252525'  # diagonal stripe color on UTGO states

CAT_COLORS = {
    'no_vote':    C_WHITE,
    'only_go':    C_LT_GRN,
    'only_utgo':  C_LT_GRN,   # same fill; hatch added in second pass
    'go_revenue': C_DK_GRN,
    'depends':    C_GRAY,
}

# ─── Download / cache Census TIGER state shapefile ───────────────────────────
SHP_DIR  = os.path.join(CACHE_DIR, 'tl_2023_us_state')
SHP_PATH = os.path.join(SHP_DIR, 'tl_2023_us_state.shp')

if not os.path.exists(SHP_PATH):
    url = 'https://www2.census.gov/geo/tiger/TIGER2023/STATE/tl_2023_us_state.zip'
    print('Downloading Census TIGER state boundaries …')
    with urllib.request.urlopen(url) as resp:
        with zipfile.ZipFile(io.BytesIO(resp.read())) as z:
            z.extractall(SHP_DIR)
    print('Download complete.')

states = gpd.read_file(SHP_PATH)

# Drop overseas territories, Hawaii, and DC
EXCLUDE = {'HI', 'DC', 'PR', 'GU', 'VI', 'AS', 'MP'}
states  = states[~states['STUSPS'].isin(EXCLUDE)].copy()

# Assign category
def classify(abbr: str) -> str:
    if abbr in NO_VOTE:    return 'no_vote'
    if abbr in ONLY_GO:    return 'only_go'
    if abbr in ONLY_UTGO:  return 'only_utgo'
    if abbr in GO_REVENUE: return 'go_revenue'
    if abbr in DEPENDS:    return 'depends'
    return 'unknown'

states['cat'] = states['STUSPS'].apply(classify)

# Reproject: CONUS to Albers Equal Area (EPSG:5070), AK to Alaska Albers (EPSG:3338)
conus = states[states['STUSPS'] != 'AK'].copy().to_crs('EPSG:5070')
ak    = states[states['STUSPS'] == 'AK'].copy().to_crs('EPSG:3338')

# ─── Drawing helper ───────────────────────────────────────────────────────────
def draw_states(ax: plt.Axes, gdf: gpd.GeoDataFrame, lw: float = 0.5) -> None:
    """Fill states by category; overlay gray diagonal hatch for UTGO states."""
    for cat, color in CAT_COLORS.items():
        sub = gdf[gdf['cat'] == cat]
        if not sub.empty:
            sub.plot(ax=ax, facecolor=color, edgecolor=C_BORDER,
                     linewidth=lw, zorder=2)
    # Second pass: overlay hatch on UTGO states (facecolor='none' preserves fill)
    utgo = gdf[gdf['cat'] == 'only_utgo']
    if not utgo.empty:
        utgo.plot(ax=ax, facecolor='none', edgecolor=C_HATCH,
                  linewidth=0, hatch='//', zorder=3)

# ─── Figure layout ────────────────────────────────────────────────────────────
fig = plt.figure(figsize=(13.5, 8.5), dpi=200, facecolor='white')

# Main CONUS axes (bottom 16 % reserved for legend + AK)
ax = fig.add_axes([0.01, 0.16, 0.88, 0.83])
draw_states(ax, conus)
ax.set_axis_off()

# Alaska inset (lower-left, overlaid on blank CONUS space)
ax_ak = fig.add_axes([0.02, 0.14, 0.17, 0.15])
draw_states(ax_ak, ak, lw=0.4)
ax_ak.set_axis_off()
ax_ak.set_aspect('equal')

# ─── State labels ─────────────────────────────────────────────────────────────
def lbl_color(cat: str) -> str:
    """White label on dark-green states; black everywhere else."""
    return '#ffffff' if cat == 'go_revenue' else '#000000'

# representative_point() is always strictly inside the polygon (handles multi-part states)
conus['rx'] = conus.geometry.representative_point().x
conus['ry'] = conus.geometry.representative_point().y

# Fine-tune specific states (dx, dy in projected metres from representative_point)
# Positive dx → east; positive dy → north
OFFSETS: dict = {
    'ID': ( +53_000, -234_000),  # panhandle → lower body centre
    'MI': (      0,  -330_000),  # Upper Peninsula → Lower Peninsula centre
    'LA': ( -55_000, +160_000),  # coastal marshes → northern body
    'FL': ( -54_000, +190_000),  # southern tip → mid-peninsula
    'NY': (-148_000,  -34_000),  # eastern bias → western main body
    'VA': (-124_000,  -10_000),  # Chesapeake notch → central body
    'WV': (      0,   -40_000),  # minor south adjustment
    'ME': ( -30_000,  -30_000),  # minor adjustment
    'WA': (      0,   -30_000),  # minor south adjustment
}

# Small northeast states rendered with off-map labels + leader lines
OFFMAP = frozenset({'NH', 'MA', 'RI', 'CT', 'NJ', 'DE', 'MD'})

# ── Alaska label ──────────────────────────────────────────────────────────────
ak_rp = ak.geometry.representative_point().iloc[0]
ax_ak.text(ak_rp.x, ak_rp.y, 'AK',
           fontsize=7.5, fontfamily='Arial',
           color=lbl_color('only_go'),
           ha='center', va='center', zorder=10)

# ── On-map labels ─────────────────────────────────────────────────────────────
LBL_KW = dict(fontsize=9, fontfamily='Arial', ha='center', va='center', zorder=10)

for _, row in conus.iterrows():
    abbr = row['STUSPS']
    if abbr in OFFMAP:
        continue
    dx, dy = OFFSETS.get(abbr, (0.0, 0.0))
    ax.text(row['rx'] + dx, row['ry'] + dy, abbr,
            color=lbl_color(row['cat']), **LBL_KW)

# ── Off-map labels for small NE states ────────────────────────────────────────
xmin, ymin, xmax, ymax = conus.total_bounds

off_gdf = (conus[conus['STUSPS'].isin(OFFMAP)]
           .copy()
           .sort_values('ry', ascending=False))   # north → south

COL_X   = xmax + 70_000                                    # label column x (close to map)
Y_TOP   = off_gdf['ry'].max() + 80_000
Y_BOT   = off_gdf['ry'].min() - 60_000
label_ys = np.linspace(Y_TOP, Y_BOT, len(off_gdf))

for i, (_, row) in enumerate(off_gdf.iterrows()):
    rx, ry = row['rx'], row['ry']
    lx, ly = COL_X, label_ys[i]

    # Thin leader line from state interior to label
    ax.plot([rx, lx - 5_000], [ry, ly],
            color='#555555', linewidth=0.35, zorder=5, solid_capstyle='round')
    # Off-map label is always black (floats on white background)
    ax.text(lx + 3_000, ly, row['STUSPS'],
            color='#000000', ha='left',
            fontsize=9, fontfamily='Arial', va='center', zorder=10)

# Fix axes limits to show full CONUS + off-map labels
ax.set_xlim(xmin - 200_000, COL_X + 220_000)
ax.set_ylim(ymin -  50_000, ymax +  80_000)

# ─── Legend ───────────────────────────────────────────────────────────────────
legend_handles = [
    mpatches.Patch(facecolor=C_WHITE,  edgecolor=C_BORDER, linewidth=0.5,
                   label='No vote required'),
    mpatches.Patch(facecolor=C_LT_GRN, edgecolor=C_BORDER, linewidth=0.5,
                   label='Only GO vote required'),
    mpatches.Patch(facecolor=C_LT_GRN, edgecolor=C_HATCH,  linewidth=0.5,
                   hatch='//', label='Only GO vote required (limited-tax exempt)'),
    mpatches.Patch(facecolor=C_DK_GRN, edgecolor=C_BORDER, linewidth=0.5,
                   label='GO and revenue votes required'),
    mpatches.Patch(facecolor=C_GRAY,   edgecolor=C_BORDER, linewidth=0.5,
                   label='Vote requirements vary within-state'),
]

fig.legend(
    handles=legend_handles,
    loc='lower center',
    bbox_to_anchor=(0.43, 0.015),
    ncol=1,
    fontsize=8.5,
    frameon=False,
    handleheight=1.4,
    handlelength=2.2,
    handletextpad=0.8,
    labelspacing=0.4,
)

# ─── Save ─────────────────────────────────────────────────────────────────────
plt.savefig(OUTPUT_PATH, dpi=200, bbox_inches='tight',
            facecolor='white', edgecolor='none')
print(f'Saved → {OUTPUT_PATH}')
plt.close(fig)
