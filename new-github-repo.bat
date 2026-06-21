@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  Google Code Archive (SVN snapshot) -> new GitHub repo.
rem  Creates repo via API, no history. Run from FAR Manager.
rem  Save as .bat
rem ============================================================

rem --- SETTINGS ---
set "GH_USER=dmitri-desh"
set "REPO=moservices"
set "SRC=E:\Downloads\moservices\trunk\repository"
set "BRANCH=main"
set "PRIVATE=false"
set "COMMIT_MSG=Import from Google Code Archive (moservices)"

set "RESP=%TEMP%\gh_resp.json"
set "CODE=%TEMP%\gh_code.txt"

echo.
echo === User   : %GH_USER%
echo === Repo   : %REPO%  (private=%PRIVATE%)
echo === Source : %SRC%
echo.

rem --- Checks ---
where git  >nul 2>&1 || (echo [ERROR] git not found in PATH  & goto :fail)
where curl >nul 2>&1 || (echo [ERROR] curl not found in PATH & goto :fail)
if not exist "%SRC%" (echo [ERROR] Source folder not found  & goto :fail)
if exist "%SRC%\.git" (echo [ERROR] .git already exists in source. Aborting. & goto :fail)

rem --- Token input (hidden) ---
echo Paste your GitHub Personal Access Token and press Enter (input is hidden):
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "$s=Read-Host -AsSecureString; [System.Net.NetworkCredential]::new('',$s).Password"`) do set "TOKEN=%%T"
if not defined TOKEN (echo [ERROR] No token entered & goto :fail)

rem --- Create repo via GitHub API ---
echo [1/8] Creating repository on GitHub...
curl -s -o "%RESP%" -w "%%{http_code}" ^
  -X POST ^
  -H "Accept: application/vnd.github+json" ^
  -H "Authorization: Bearer %TOKEN%" ^
  -H "X-GitHub-Api-Version: 2022-11-28" ^
  "https://api.github.com/user/repos" ^
  -d "{\"name\":\"%REPO%\",\"private\":%PRIVATE%}" > "%CODE%"
set /p HTTP=<"%CODE%"

if "%HTTP%"=="201" (
    echo       [OK] Repository created.
) else if "%HTTP%"=="422" (
    echo       [WARN] Repo may already exist ^(HTTP 422^). Trying to push anyway.
) else if "%HTTP%"=="401" (
    echo [ERROR] 401 Unauthorized - bad or expired token. & goto :fail
) else if "%HTTP%"=="403" (
    echo [ERROR] 403 Forbidden - token missing 'repo' scope. & goto :fail
) else (
    echo [ERROR] Repo creation failed. HTTP=%HTTP%
    type "%RESP%"
    goto :fail
)

cd /d "%SRC%" || goto :fail

rem --- Remove all .svn folders ---
echo [2/8] Removing .svn folders...
for /d /r "%SRC%" %%D in (.svn) do (
    if exist "%%D" rd /s /q "%%D"
)

echo [3/8] git init...
git init >nul || goto :fail

echo [4/8] git add...
git add -A || goto :fail

echo [5/8] git commit...
git commit -m "%COMMIT_MSG%" || goto :fail

echo [6/8] set branch...
git branch -M %BRANCH%

echo [7/8] add remote and push (token used inline, then scrubbed)...
git remote add origin "https://%GH_USER%:%TOKEN%@github.com/%GH_USER%/%REPO%.git" || goto :fail
git push -u origin %BRANCH% || goto :fail

echo [8/8] scrubbing token from git config...
git remote set-url origin "https://github.com/%GH_USER%/%REPO%.git"

echo.
echo === DONE ===
echo Repo: https://github.com/%GH_USER%/%REPO%
goto :end

:fail
echo.
echo === FAILED. See message above. ===

:end
if exist "%RESP%" del /q "%RESP%"
if exist "%CODE%" del /q "%CODE%"
set "TOKEN="
endlocal
pause