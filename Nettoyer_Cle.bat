@echo off
setlocal enabledelayedexpansion
title Constructo AI portable - Nettoyage de la cle

rem ==================================================================
rem  Nettoyer_Cle.bat
rem  Efface l'etat d'execution accumule sur la cle : jeton Claude,
rem  blobs d'identite Microsoft, profil Chrome, journaux MCP, sessions.
rem
rem  A PASSER OBLIGATOIREMENT avant de confier la cle a quelqu'un.
rem
rem  Ne touche PAS a .claude\ (la charge utile), ni a claude\, python\,
rem  git\ (le moteur). Seul data\ est jetable : il ne contient que de
rem  l'etat d'execution, recree au prochain lancement.
rem
rem  Une gracieusete de Sylvain Leduc - Constructo AI inc.
rem ------------------------------------------------------------------
rem  NE PAS ecrire [!] dans un echo : sous enabledelayedexpansion, cmd
rem  lit le point d'exclamation comme un debut de variable et le mange.
rem  Mesure du 2026-08-30 : "[!] jeton Claude" s'affichait "[] jeton
rem  Claude". On ecrit [x].
rem ==================================================================

set "CLE=%~dp0"
set "DATA=%CLE%data"

echo.
echo   =========================================================
echo     Nettoyage de la cle
echo   =========================================================
echo.
echo     Cle : %CLE%
echo.

if not exist "%DATA%" goto rien_a_faire

echo     Contenu sensible detecte :
echo.
if exist "%DATA%\claude\.credentials.json" echo       [x] jeton Claude          data\claude\.credentials.json
if exist "%DATA%\home\AppData\Local\Microsoft\OneAuth" echo       [x] identite Microsoft    data\home\...\OneAuth
if exist "%DATA%\home\AppData\Local\Microsoft\IdentityCache" echo       [x] cache d'identite      data\home\...\IdentityCache
if exist "%DATA%\local_app_data\Google\Chrome" echo       [x] profil Chrome         data\local_app_data\Google\Chrome
if exist "%DATA%\local_app_data\claude-cli-nodejs" echo       [x] journaux MCP          data\local_app_data\claude-cli-nodejs
if exist "%DATA%\claude\sessions" echo       [x] historique de session data\claude\sessions
echo.
echo     Tout le dossier data\ va etre supprime. Il ne contient que de
echo     l'etat d'execution : la charge utile .claude\ n'est pas touchee.
echo.

rem ------------------------------------------------------------------
rem  CE QUI VERROUILLE : CHROME, D'ABORD.
rem  La session a redirige LOCALAPPDATA vers la cle ; le navigateur
rem  ouvert pour la connexion n'y a trouve aucun profil et s'en est
rem  fabrique un. Tant que cette fenetre vit, des dizaines de fichiers
rem  restent ouverts et rmdir echoue en plein milieu.
rem  Mesure du 2026-08-30 : ~130 fichiers verrouilles, tous sous
rem  data\local_app_data\Google\Chrome.
rem ------------------------------------------------------------------
echo     AVANT DE CONTINUER, fermez :
echo       1. Chrome      ^(il tient le profil cree sur la cle^)
echo       2. Claude Code ^(toute session lancee depuis cette cle^)
echo       3. Outlook     ^(si le mode complet a servi^)
echo.

set "REP="
set /p "REP=  Confirmer la suppression ? (o/N) : "
if /I not "!REP!"=="o" goto annule

:tenter
echo.
echo     Suppression...
rmdir /s /q "%DATA%" 2>nul
if not exist "%DATA%" goto supprime

rem  Encore la : quelque chose tient des fichiers ouverts.
echo.
echo     Suppression incomplete : des fichiers sont verrouilles.
echo.
set "NB_CHROME="
for /f %%N in ('tasklist /fi "IMAGENAME eq chrome.exe" /nh 2^>nul ^| find /c "chrome.exe"') do set "NB_CHROME=%%N"
if "!NB_CHROME!"=="0" goto pas_chrome
echo     Chrome tourne encore ^(!NB_CHROME! processus^). C'est le coupable
echo     le plus probable : il tient le profil cree sur la cle.
echo.
set "REP2="
set /p "REP2=  Fermer Chrome maintenant et reessayer ? (o/N) : "
if /I not "!REP2!"=="o" goto abandon
echo     Fermeture de Chrome...
taskkill /F /IM chrome.exe >nul 2>&1
rem  Laisser Windows relacher les descripteurs avant de reessayer.
ping -n 3 127.0.0.1 >nul
goto tenter

:pas_chrome
echo     Chrome ne tourne pas. Un autre programme tient donc ces fichiers.
echo     Fermez Claude Code et Outlook, puis relancez ce script.
echo.
pause
exit /b 1

:abandon
echo.
echo     Abandonne. data\ est partiellement supprime : la cle n'est PAS
echo     propre. Relancez ce script apres avoir ferme Chrome.
echo.
pause
exit /b 1

:supprime
echo     [OK] data\ supprime.
echo.
echo     Verification :
rem ------------------------------------------------------------------
rem  Motifs LITTERAUX (/C:) et non des mots isoles. Sans /C:, findstr
rem  traite chaque mot comme un motif independant : "credentials" seul
rem  matchait git\mingw64\share\doc\git-doc\gitcredentials.html - de la
rem  DOCUMENTATION - et le script annoncait une fuite inexistante.
rem  Mesure du 2026-08-30 : fausse alerte sur une cle propre.
rem ------------------------------------------------------------------
dir /s /b "%CLE%" 2>nul | findstr /I /C:".credentials.json" /C:"\OneAuth\" /C:"\IdentityCache\" /C:"\Google\Chrome\User Data" >"%TEMP%\cle_reste.txt"
for %%Z in ("%TEMP%\cle_reste.txt") do if not %%~zZ==0 goto reste_qqchose
del "%TEMP%\cle_reste.txt" >nul 2>&1
echo     [OK] plus aucune trace d'identifiant sur la cle.
echo.
echo     La cle est prete a etre confiee. Au prochain lancement,
echo     Claude Code redemandera une connexion.
echo.
pause
exit /b 0

:reste_qqchose
echo     [x] Des fichiers d'identifiant subsistent HORS de data\ :
echo.
type "%TEMP%\cle_reste.txt"
del "%TEMP%\cle_reste.txt" >nul 2>&1
echo.
echo         Supprimez-les a la main avant de confier la cle.
echo.
pause
exit /b 1

:rien_a_faire
echo     [OK] Aucun dossier data\ : la cle est deja propre.
echo.
pause
exit /b 0

:annule
echo.
echo     Annule. Rien n'a ete supprime.
echo.
pause
exit /b 0
