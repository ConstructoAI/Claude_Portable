@echo off
setlocal
cd /d "%~dp0"
title Claude Portable - Fabrication

set "ZIP=%USERPROFILE%\Downloads\gestionnaire-ia.zip"
set "SRC=%USERPROFILE%\Downloads\Gestionnaire-IA-main"
set "CIBLE=C:\test_cle"
rem La cible se donne en argument : "Lancer_Fabrication.bat E:\".
rem Sans cette ligne, %1 etait ignore EN SILENCE et il fallait editer ce
rem fichier pour fabriquer ailleurs que sur C:\test_cle - dans une enveloppe
rem destinee a quelqu un qui n ouvre pas un editeur.
if not "%~1"=="" set "CIBLE=%~1"

echo.
echo =========================================================
echo   Claude Portable - Gestionnaire IA : fabrication
echo =========================================================

echo.
echo === 1/4  Source Gestionnaire IA ===
if exist "%SRC%\.claude\CLAUDE.md" goto source_ok
if exist "%ZIP%" goto extraire

echo     Telechargement depuis GitHub...
rem -f : sans lui, curl ecrit le corps d une page d erreur (404, portail
rem captif, 407 proxy) dans le .zip et sort en 0 - "if errorlevel 1" ne voit
rem alors RIEN, et l echec ne se revele qu a l extraction.
curl -fL -o "%ZIP%" https://github.com/ConstructoAI/Gestionnaire-IA/archive/refs/heads/main.zip
rem UN SEUL test : `del` REMET errorlevel A 0 quand il reussit, donc un
rem seconde "if errorlevel 1" apres lui ne partirait JAMAIS.
if errorlevel 1 (
    del /q "%ZIP%" 2>nul
    goto err_dl
)

:extraire
echo     Extraction...
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%USERPROFILE%\Downloads' -Force"
if exist "%SRC%\.claude\CLAUDE.md" goto source_ok
rem Le zip est inexploitable. Le SUPPRIMER : sinon le "if exist %ZIP%" plus
rem haut le reprend a chaque relance et l echec devient PERMANENT, sans que
rem le message ne dise jamais quel fichier effacer.
del /q "%ZIP%" 2>nul
goto err_extract

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
rem Le code de sortie du .ps1 etait IGNORE, et "Termine." s affichait meme
rem sous un "FABRICATION INCOMPLETE". Fabriquer_Cle.ps1 promet en tete de ne
rem jamais pretendre avoir installe ce qu il n a pas installe : son enveloppe
rem le pretendait pour lui. Les lignes 22 et 27 testaient pourtant deja
rem errorlevel - il manquait la ou ca comptait le plus.
if errorlevel 1 goto err_fab

echo.
echo =========================================================
echo   Termine. La cle est prete dans %CIBLE%.
echo =========================================================
pause
exit /b

:err_fab
echo.
echo =========================================================
echo   LA CLE N EST PAS UTILISABLE
echo =========================================================
echo   La fabrication s est arretee avant la fin.
echo   Le detail est dans le texte ci-dessus : copiez-le EN ENTIER
echo   et envoyez-le.
echo.
echo   Ne distribuez pas %CIBLE% en l etat.
pause
exit /b 1

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
