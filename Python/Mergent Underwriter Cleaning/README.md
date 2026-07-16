# Mergent Underwriter Cleaning

`1. Build Underwriter Measures.py` builds issue-level underwriter measures from raw
Mergent agent tables.

Inputs:
- `Data/Mergent/Raw/ISSUAGNT.DLM`: issue-agent-role links
- `Data/Mergent/Raw/AGENT.DLM`: agent names
- `Data/Mergent/Raw/ISSUINFO.DLM`: issue date, state, amount, gross spread

Primary underwriter definition:
- Use `LEADU` lead underwriter roles when available.
- If an issue has no `LEADU`, use `UNDER` underwriter roles as the primary
  underwriter.
- If multiple primary underwriters appear on an issue, market-share credit is
  split equally across them.

Main output:
- `Data/Mergent/Underwriters/issue_underwriter_measures.csv`

Ranking outputs:
- `Data/Mergent/Underwriters/underwriter_year_rankings.csv`
- `Data/Mergent/Underwriters/underwriter_state_year_rankings.csv`

Issue-level measures include:
- lead/primary underwriter IDs and names
- counts of lead underwriters, co-managers, syndicate members, and placement agents
- national annual amount and issue-share measures for primary underwriters
- national top 3, top 5, and top 10 indicators
- state-year amount and issue-share measures for primary underwriters
- state-year top 3, top 5, and top 10 indicators

