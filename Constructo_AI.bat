@echo off
setlocal enabledelayedexpansion
title Constructo AI - version portable (cle USB)

rem ---------------------------------------------------------------------------
rem  OU DOIT VIVRE CE FICHIER
rem  A la RACINE de la cle, a cote de .claude, claude\, python\ et git\.
rem  On accepte aussi qu'il ait ete depose DANS .claude : le bloc ci-dessous
rem  detecte les deux cas. Le dossier de travail doit etre le PARENT de .claude,
rem  sinon Claude Code chercherait sa configuration dans .claude\.claude\.
rem ---------------------------------------------------------------------------
cd /d "%~dp0"
for %%I in ("%CD%") do set "NOMDOSSIER=%%~nxI"
if /I "%NOMDOSSIER%"==".claude" cd ..

rem  Dossier courant NORMALISE, avec un antislash final garanti.
set "CLE=%CD%"
if not "%CLE:~-1%"=="\" set "CLE=%CLE%\"

rem  NE JAMAIS ecrire %VAR% NON QUOTEE a l'interieur d'un bloc ( ... ).
rem  cmd developpe a l'ANALYSE, avant d'executer : si la valeur contient une
rem  parenthese fermante - et Windows nomme le 2e telechargement d'un ZIP
rem  "... (1)" - le bloc se termine la et tout le fichier devient faux.
rem  Ce fichier n'utilise donc que !VAR!, developpee a l'execution, et des
rem  sauts vers des etiquettes plutot que des blocs.

set "MOTEUR=%CLE%claude\claude.exe"
set "PY=%CLE%python\python.exe"
set "GITDIR=%CLE%git"
set "GITBASH=%GITDIR%\bin\bash.exe"
set "DATA=%CLE%data"
set "CFG=%CLE%.claude"

rem ---------------------------------------------------------------------------
rem  LE POSTE HOTE, PHOTOGRAPHIE AVANT TOUTE REDIRECTION
rem  Plus bas, USERPROFILE / APPDATA / LOCALAPPDATA sont detournes vers la cle
rem  pour ne rien laisser sur la machine. Mais les dossiers REELS de
rem  l'utilisateur - ses documents, ses profils Outlook, son .ost - vivent sous
rem  les valeurs D'ORIGINE. Sans cette photo, une recherche sous %LOCALAPPDATA%
rem  pointerait sur la cle et ne trouverait rien : un faux zero parfait, qui a
rem  l'air d'une boite vide.
rem ---------------------------------------------------------------------------
set "HOTE_USERPROFILE=%USERPROFILE%"
set "HOTE_APPDATA=%APPDATA%"
set "HOTE_LOCALAPPDATA=%LOCALAPPDATA%"
set "HOTE_NOM=%COMPUTERNAME%"

rem  Chemins complets pour powershell.exe : sur un poste avec WSL, `bash` du
rem  PATH resout vers WSL et `pwsh` est souvent absent - voir CLAUDE.md
rem  section 8.
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

echo.
echo   ============================================================
echo                      C O N S T R U C T O   A I
echo.
echo      Courriels Outlook, calendrier, projets, comptabilite.
echo      Claude lit, mesure, classe et redige.
echo.
echo      Une gracieusete de Sylvain Leduc, president
echo      Ecosysteme intelligent pour la construction au Quebec
echo      www.constructoai.ca
echo   ============================================================
echo.
echo                    - - -  VERSION PORTABLE  - - -
echo      Tout est deja sur la cle. Rien ne s'installe sur ce poste,
echo      rien ne se telecharge.
echo.

rem ===========================================================================
rem  [1/4] INVENTAIRE - on regarde AVANT de lancer quoi que ce soit.
rem        Ce fichier ne repare rien et ne telecharge rien, par conception :
rem        une cle incomplete est une cle a refabriquer, pas a rafistoler.
rem ===========================================================================
echo   [1/4] Inventaire de la cle...

set "MANQUE="
if not exist "%MOTEUR%" set "MANQUE=!MANQUE! claude\claude.exe"
if not exist "%PY%" set "MANQUE=!MANQUE! python\python.exe"
if not exist "%GITBASH%" set "MANQUE=!MANQUE! git\bin\bash.exe"
if not exist "%CFG%\CLAUDE.md" set "MANQUE=!MANQUE! .claude\CLAUDE.md"
if defined MANQUE goto cle_incomplete

rem  Un fichier present n'est pas un interpreteur qui fonctionne. Windows livre
rem  un raccourci de 0 octet vers le Microsoft Store qui REPOND aux deux tests
rem  habituels. Le seul qui ne mente pas est de faire EXECUTER du Python.
"%PY%" -c "import sys; sys.exit(0)" >nul 2>&1
if errorlevel 1 goto python_muet

echo         OK - moteur, Python, Git et la couche .claude sont la.

rem ===========================================================================
rem  [2/4] ENVIRONNEMENT PORTABLE - rien ne s'ecrit sur le poste hote.
rem ===========================================================================
echo   [2/4] Environnement portable...

set "CLAUDE_CONFIG_DIR=%DATA%\claude"
set "HOME=%DATA%\home"
set "USERPROFILE=%DATA%\home"
set "APPDATA=%DATA%\app_data"
set "LOCALAPPDATA=%DATA%\local_app_data"
set "XDG_CONFIG_HOME=%DATA%\config"
set "XDG_DATA_HOME=%DATA%\app_data"
set "XDG_CACHE_HOME=%DATA%\cache"

if not exist "%CLAUDE_CONFIG_DIR%" mkdir "%CLAUDE_CONFIG_DIR%"
if not exist "%HOME%" mkdir "%HOME%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%XDG_CONFIG_HOME%" mkdir "%XDG_CONFIG_HOME%"
if not exist "%XDG_CACHE_HOME%" mkdir "%XDG_CACHE_HOME%"

rem  Claude Code exige Git Bash sur Windows pour son outil Bash.
set "CLAUDE_CODE_GIT_BASH_PATH=%GITBASH%"
set "PATH=%GITDIR%\cmd;%GITDIR%\bin;%GITDIR%\usr\bin;%CLE%python;%PATH%"

rem  Le moteur est fige sur la cle : pas d'auto-mise a jour, elle ecrirait
rem  dans un dossier qui n'est pas le sien.
set "DISABLE_AUTOUPDATER=1"

echo         OK - donnees confinees dans data\ sur la cle.

rem ===========================================================================
rem  [3/4] MODE - on ne DEDUIT pas, on TENTE.
rem        La version Microsoft Store d'Outlook est presente et n'expose PAS
rem        MAPI/COM : chercher un .exe repondrait "oui" pour une installation
rem        inutilisable. Le seul test honnete est d'instancier l'objet COM.
rem ===========================================================================
echo   [3/4] Test de l'acces Outlook (MAPI/COM)...

"%PS_EXE%" -NoProfile -NonInteractive -Command "try { $o = New-Object -ComObject Outlook.Application; $null = $o.GetNamespace('MAPI'); exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 goto mode_sans_outlook

rem  Outlook repond. Mais TOUS les scripts MAPI passent par pywin32 : sans lui,
rem  annoncer "mode complet" serait une promesse fausse. On ne se fie pas a la
rem  presence du module, on le fait IMPORTER.
"%PY%" -c "import win32com.client" >nul 2>&1
if errorlevel 1 goto mode_sans_pywin32

set "GIA_MODE=complet"
set "GIA_MODE_TXT=COMPLET - courriels, calendrier, dossiers, comptabilite."
goto mode_affiche

:mode_sans_pywin32
set "GIA_MODE=inventaire"
set "GIA_MODE_TXT=INVENTAIRE - Outlook repond, mais pywin32 est absent de la cle."
goto mode_affiche

:mode_sans_outlook
set "GIA_MODE=inventaire"
set "GIA_MODE_TXT=INVENTAIRE - pas d'Outlook classique sur ce poste."

:mode_affiche
echo         %GIA_MODE_TXT%
if /I "%GIA_MODE%"=="inventaire" echo         Lecture seule : ost_reader + factures. Ni corps de message, ni envoi.
echo.
echo   ------------------------------------------------------------
echo      Poste   : %HOTE_NOM%
echo      Cle     : %CLE%
echo      Mode    : %GIA_MODE%
echo      Donnees : portable - rien ne s'ecrit sur ce poste
echo   ------------------------------------------------------------
echo.

rem ===========================================================================
rem  [4/4] LANCEMENT
rem ===========================================================================
echo   [4/4] Demarrage de Claude Code...
echo.

call "%MOTEUR%" --model "claude-opus-5[1m]" --fallback-model "claude-sonnet-5" --effort max
goto fin

:cle_incomplete
echo.
echo   INCOMPLETE : il manque sur la cle :!MANQUE!
echo.
echo   Ce lanceur ne repare rien et ne telecharge rien, par conception.
echo   Refabriquez la cle avec Fabriquer_Cle.ps1 sur un poste connecte.
echo.
pause
exit /b 1

:python_muet
echo.
echo   python.exe est present mais ne s'execute pas.
echo   Un fichier present n'est pas un interpreteur qui fonctionne.
echo.
echo   Detail de l'erreur :
echo.
"%PY%" -c "import sys; sys.exit(0)"
echo.
echo   Refabriquez la cle avec Fabriquer_Cle.ps1.
echo.
pause
exit /b 1

:fin
endlocal
