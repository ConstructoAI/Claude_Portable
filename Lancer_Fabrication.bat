@echo off
setlocal
cd /d "%~dp0"
title Claude Portable - Fabrication

set "ZIP=%USERPROFILE%\Downloads\gestionnaire-ia.zip"
set "SRC=%USERPROFILE%\Downloads\Gestionnaire-IA-main"
set "CIBLE=C:\test_cle"
rem La cible se donne en argument : Lancer_Fabrication.bat E:
rem ⚠️ SANS BARRE OBLIQUE FINALE. Mesure du 2026-08-31 : "E:\" fait lire \" comme
rem un guillemet litteral par le parseur, et TOUTE la fin de la ligne de
rem commande s effondre dans -Cle -- -SourceGestionnaire est avale. La forme que
rem ce commentaire enseignait etait celle qui casse.
rem Sans cette ligne, %1 etait ignore EN SILENCE et il fallait editer ce fichier
rem pour fabriquer ailleurs que sur C:\test_cle - dans une enveloppe destinee a
rem quelqu un qui n ouvre pas un editeur.
if not "%~1"=="" set "CIBLE=%~1"
rem 🔴 Retirer une barre oblique finale : elle casse la citation en aval.
if defined CIBLE if "%CIBLE:~-1%"=="\" set "CIBLE=%CIBLE:~0,-1%"

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
echo     OK : "%CIBLE%"

echo.
echo === 4/4  Fabrication ===
powershell -ExecutionPolicy Bypass -NoProfile -File ".\Fabriquer_Cle.ps1" -Cle "%CIBLE%" -Profil personnelle -SourceGestionnaire "%SRC%"
rem Le code de sortie du .ps1 etait IGNORE, et "Termine." s affichait meme
rem sous un "FABRICATION INCOMPLETE". Fabriquer_Cle.ps1 promet en tete de ne
rem jamais pretendre avoir installe ce qu il n a pas installe : son enveloppe
rem le pretendait pour lui. Les lignes 22 et 27 testaient pourtant deja
rem errorlevel - il manquait la ou ca comptait le plus.
rem 🔴 PAS `if errorlevel 1` : il teste « superieur ou egal a 1 » et rate TOUS
rem les codes NEGATIFS. Mesure du 2026-08-31 : -1073741510 (Ctrl+C),
rem -1073741819 (violation d acces), -1073741502 (echec init DLL) passent tous
rem pour un succes -- et « Termine. La cle est prete » s affiche sur un plantage.
rem Un Ctrl+C pendant un telechargement de 1,5 Go est le scenario le plus
rem probable de toute la chaine. NEQ 0 est le seul test qui les couvre.
if %ERRORLEVEL% NEQ 0 goto err_fab

echo.
echo =========================================================
echo   Termine. La cle est prete dans "%CIBLE%".
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
echo   Ne distribuez pas "%CIBLE%" en l etat.
pause
exit /b 1

:err_dl
echo   ERREUR : telechargement impossible depuis GitHub.
pause
exit /b 1

rem Le zip vient d etre supprime juste au-dessus : le dire, sinon l utilisateur
rem ne sait pas qu une simple relance suffit a retelecharger.
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
