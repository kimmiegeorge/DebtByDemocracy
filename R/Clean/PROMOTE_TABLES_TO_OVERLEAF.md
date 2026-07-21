# Promote Clean Tables to Overleaf

Use this only after reviewing the clean outputs in:

`Code/R/Clean/output/revision_tables`

The promotion script copies `.tex` table files into:

`~/Dropbox/Apps/Overleaf/Voting on bonds/tables/clean/raw`

## Dry run

Preview what would be copied without changing Overleaf:

```sh
Rscript R/Clean/promote_tables_to_overleaf.R
```

## Copy new tables only

Copy tables that do not already exist in Overleaf:

```sh
Rscript R/Clean/promote_tables_to_overleaf.R --apply
```

## Replace Overleaf clean/raw tables

Overwrite existing Overleaf clean/raw table files with the clean outputs:

```sh
Rscript R/Clean/promote_tables_to_overleaf.R --apply --overwrite
```

The script only copies `.tex` files from the clean revision-table output folder into the Overleaf clean/raw folder. It does not copy files from the removed robustness-output folder.
