# Project Instructions for Agents

Read these instructions before beginning work in this repository.

## Project locations

- All project code lives in this `Code` repository.
- Active development is in the `Python/` and `R/` directories. Keep new code in the appropriate one of those two directories unless the task explicitly requires another location.
- The paper and revision materials live outside this repository at `/Users/kmunevar/Dropbox/Apps/Overleaf/Voting on Bonds`.
  - `main.tex` is the most recent paper draft.
  - `response_1.tex` is the first-round review response.
  - `response_2.tex` is the second-round review response currently in progress.

## General coding style

- Before editing or adding code, read the nearby scripts and follow their existing organization, naming, formatting, and output conventions.
- Write analysis code step by step, with intermediate objects that make the workflow easy to inspect. Do not unnecessarily refactor analysis code into functions or otherwise make it more abstract than the surrounding files.
- Add clear comments that explain the purpose of each substantive step.
- Keep paths, variable names, table names, and output locations consistent with the existing project.

## Python

- Use Polars for dataframe and tabular-data work, consistent with the existing Python scripts.
- Write the workflow as clear, sequential analysis steps rather than in a heavily functional style.
- Match the import style, expressions, naming, and formatting of the Python files nearest to the work.

## R

- Write every regression specification explicitly.
- Do not generate, run, or store regressions in loops or functions.
- For regression tables, use the same `etable` construction and output format used by the existing R tables. Find the closest comparable table in `R/` and mirror its model ordering, labels, notes, formatting, and file-output pattern.

## Version control

- Commit work in small, coherent increments as it progresses.
- Preserve unrelated changes already present in the working tree; stage only the files that belong to the current task.
- Write concise commit messages that identify the substantive change.
- Push completed commits to the configured GitHub remote on the current branch, unless the user asks otherwise.
