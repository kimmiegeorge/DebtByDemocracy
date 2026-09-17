# Texas Republican presidential vote share

`260917_pull_merge_analyze_tx_republican_vote_share.py` creates a county-level
Republican presidential vote-share measure and tests whether it predicts
rejection of Texas city bond propositions.

## Sources

- 2000-2024 county returns: MIT Election Data and Science Lab, County
  Presidential Election Returns 2000-2024, DOI `10.7910/DVN/VOQCHQ`.
- 1992 and 1996 county returns: official Texas Secretary of State historical
  county result pages.

The script resolves the current MIT Dataverse file through its API instead of
hard-coding a temporary Dataverse file identifier. Because Harvard Dataverse
requires an interactive guestbook response for the file download, the script
downloads a public GitHub mirror of the original MIT CSV. The script saves the
current Dataverse metadata, including the file identifier and checksum, beside
the raw download under `Data/TX/Republican Vote Share/raw`.

## Measure

Each bond proposition receives the Republican two-party share from the most
recent presidential election strictly before its election year. This prevents
same-year presidential turnout from mechanically determining the measure.

For project observations labeled with multiple counties, component-county
Republican and Democratic votes are summed before calculating the share.

## Analysis

The script estimates five main linear-probability models of bond rejection:

1. Republican share only.
2. Bond controls plus election-year and purpose fixed effects.
3. Specification 2 in the sample with nonmissing county controls.
4. County population and per-capita-income controls added.
5. City fixed effects added to specification 2.

Two further sensitivity tests exclude multi-county geography labels and limit
the sample to bond elections after 2000.

Republican share is standardized within the bond-election sample. Standard
errors are clustered by the project's county-geography label.

## Run

From the project root:

```bash
python3 "Code/Python/Texas Republican Vote Share/260917_pull_merge_analyze_tx_republican_vote_share.py"
```

The script requires `polars`, `pandas`, `requests`, `beautifulsoup4`,
`matplotlib`, and `statsmodels`.
