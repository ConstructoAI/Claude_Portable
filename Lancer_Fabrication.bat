@echo off
setlocal
cd /d "%~dp0"
title Claude Portable - Fabrication

set "ZIP=%USERPROFILE%\Downloads\gestionnaire-ia.zip"
set "SRC=%USERPROFILE%\Downloads\Gestionnaire-IA-main"
set "CIBLE=C:\test_cle"

echo.
echo =========================================================
echo   Claude Portable - Gestionnaire IA : fabrication
echo =========================================================

echo.
echo === 1/4  Source Gestionnaire IA ===
if exist "%SRC%\.claude\CLAUDE.md" goto source_ok
if exist "%ZIP%" goto extraire

echo     Telechargement depuis GitHub...
curl -L -o "%ZIP%" https://github.com/ConstructoAI/Gestionnaire-IA/archive/refs/heads/main.zip
if errorlevel 1 goto err_dl

:extraire
echo     Extraction...
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%USERPROFILE%\Downloads' -Force"
if not exist "%SRC%\.claude\CLAUDE.md" goto err_extract

:source_ok
echo     OK : %SRC%

echo.
echo === 2/4  Deblocage des scripts telecharges ===
if not exist ".\Fabriquer_Cle.ps1" goto err_ps1
if not exist ".\Constructo_AI.bat" goto err_bat
powershell -NoProfile -Command "Unblock-File '.\Fabriquer_Cle.ps1','.\Constructo_AI.bat'"
echo     OK

echo.
echo === 3/4  Dossier cible ===
if not exist "%CIBLE%" mkdir "%CIBLE%"
echo     OK : %CIBLE%

echo.
echo === 4/4  Fabrication ===
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Fabriquer_Cle.ps1" -Cle "%CIBLE%" -Profil personnelle -SourceGestionnaire "%SRC%"

echo.
echo =========================================================
echo   Termine. Copiez tout le texte ci-dessus et envoyez-le.
echo =========================================================
pause
exit /b

:err_dl
echo   ERREUR : telechargement impossible depuis GitHub.
pause
exit /b 1

:err_extract
echo   ERREUR : extraction incomplete.
echo            .claude\CLAUDE.md est absent sous %SRC%
pause
exit /b 1

:err_ps1
echo   ERREUR : Fabriquer_Cle.ps1 est absent de ce dossier.
echo            Les trois fichiers doivent etre cote a cote.
pause
exit /b 1

:err_bat
echo   ERREUR : Constructo_AI.bat est absent de ce dossier.
echo            Les trois fichiers doivent etre cote a cote.
pause
exit /b 1
