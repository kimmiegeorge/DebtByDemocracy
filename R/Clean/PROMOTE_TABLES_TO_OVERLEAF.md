# Promote Clean Tables through the Overleaf Git Repository

Use this only after reviewing the clean outputs in:

`Code/R/Clean/output/revision_tables`

The promotion script copies `.tex` table files into the local Overleaf Git
clone:

`~/Repos/overleaf-voting-on-bonds/tables/clean/raw`

The Dropbox Apps folder is only a synchronized mirror and is not a promotion
target. Using the Git clone gives every approved table update a reviewable diff,
commit, and rollback point.

Before beginning, update the clone and require a clean worktree:

```sh
git -C ~/Repos/overleaf-voting-on-bonds pull --ff-only
git -C ~/Repos/overleaf-voting-on-bonds status --short
```

## Dry run

Preview what would be copied without changing Overleaf:

```sh
Rscript R/Clean/99_promote_tables_to_overleaf.R
```

## Copy new tables only

Copy tables that do not already exist in Overleaf:

```sh
Rscript R/Clean/99_promote_tables_to_overleaf.R --apply
```

## Replace Overleaf clean/raw tables

Overwrite existing Overleaf clean/raw table files with the clean outputs:

```sh
Rscript R/Clean/99_promote_tables_to_overleaf.R --apply --overwrite
```

The script refuses to apply a promotion when the paper worktree is already
dirty. It only copies `.tex` files from the clean revision-table output folder
into `tables/clean/raw`; it does not copy files from the removed
robustness-output folder.

## Review, compile, and publish

After copying the approved raw tables, separately copy any reviewed generated
wrappers and figures to their exact tracked paths. Then:

```sh
git -C ~/Repos/overleaf-voting-on-bonds diff --check
git -C ~/Repos/overleaf-voting-on-bonds diff --stat
git -C ~/Repos/overleaf-voting-on-bonds diff -- tables/clean figures
```

Compile `main.tex` and visually inspect every changed table and figure before
committing. Stage only the approved generated artifacts, commit them as one
coherent promotion, and push to the Overleaf remote:

```sh
git -C ~/Repos/overleaf-voting-on-bonds add -- tables/clean figures
git -C ~/Repos/overleaf-voting-on-bonds commit -m "Promote regenerated analysis tables"
git -C ~/Repos/overleaf-voting-on-bonds push origin main
```

Record the commit hash in the rerun notes. Do not include unrelated manuscript
text edits in the promotion commit.
