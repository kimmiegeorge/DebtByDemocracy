@echo off
REM Detached runner for the 260914 tax-limits content crawl (Task Scheduler).
REM Tees stdout+stderr to the log the session watches. Append (>>) so resumes keep history.
cd /d "C:\Users\juneh\Dropbox (Personal)\Voting on Bonds"
echo ==== RUN START %DATE% %TIME% ==== >> "Data\Statutes\260914_fetch_log.txt"
"Code\Python\venv\Scripts\python.exe" "Code\Python\Statutes\260914_fetch_taxlimits.py" >> "Data\Statutes\260914_fetch_log.txt" 2>&1
echo ==== RUN EXIT %ERRORLEVEL% %DATE% %TIME% ==== >> "Data\Statutes\260914_fetch_log.txt"
