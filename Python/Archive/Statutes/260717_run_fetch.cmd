@echo off
REM Detached runner for the 260717 targeted dependency fetch (Task Scheduler).
REM Tees stdout+stderr to the log the session watches.
cd /d "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
"Code\Python\venv\Scripts\python.exe" "Code\Python\Statutes\260717_fetch_dependencies.py" > "Data\Statutes\260717_fetch_log.txt" 2>&1
